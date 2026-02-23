# Architecture & Rules

> **UI Layer: WinUI 3 Architectural Constraints & Dependency Injection**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)
>
> **Related:** [DesignPhilosophy.md](./DesignPhilosophy.md) | [OrchestratorContract.md](./OrchestratorContract.md)

---

## Table of Contents

1. [Core Principles](#1-core-principles)
2. [Dependency Injection Setup](#2-dependency-injection-setup)
3. [What the UI May and May Not Do](#3-what-the-ui-may-and-may-not-do)

---

## 1. Core Principles

| Rule | Rationale |
|------|-----------|
| **WinUI 3** (Windows App SDK) | Modern Windows UI framework — Fluent Design built in |
| **MVVM mandatory** | ViewModels handle all UI logic; code-behind stays thin |
| **UI is thin** | No business logic in `.xaml.cs` files |
| **No direct file writes** | All file operations go through services |
| **No direct build calls** | All actions go through the Orchestrator |
| **All long operations async** | Never block the UI thread |
| **Fluent Design System** | Follow Microsoft's Fluent Design language throughout |

---

## 2. Dependency Injection Setup

All ViewModels and Services are registered in `App.ConfigureServices()`. No service is instantiated directly with `new`.

```csharp
public partial class App : Application
{
    private readonly IServiceProvider _services;

    public App()
    {
        _services = ConfigureServices();
    }

    private IServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();

        // ViewModels — Transient (new instance per navigation)
        services.AddTransient<MainViewModel>();
        services.AddTransient<EditorViewModel>();
        services.AddTransient<ProjectsViewModel>();
        services.AddTransient<BuildMonitorViewModel>();

        // Core Services — Singleton (shared state)
        services.AddSingleton<IProjectService, ProjectService>();

        // Scoped Services — per-project-session
        services.AddScoped<IOrchestrator, OrchestratorService>();
        services.AddScoped<IPreviewService, PreviewService>();
        services.AddScoped<IRoslynIndexer, RoslynIndexerService>();

        return services.BuildServiceProvider();
    }

    public static T GetService<T>() =>
        ((App)Current)._services.GetService<T>();
}
```

---

## 3. What the UI May and May Not Do

### ❌ UI NEVER

- Calls kernel or Code Intelligence services directly
- Modifies workspace files
- Handles retry logic
- Executes build commands
- Manages state machine transitions

### ✅ UI ALWAYS

- Sends commands to the Orchestrator
- Subscribes to Orchestrator events
- Updates all bindings on the dispatcher thread
- Validates user input before sending
- Shows appropriate loading states during async operations

---

## References

- [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md) — Parent document (section 2)
- [OrchestratorContract.md](./OrchestratorContract.md) — Command pattern and event subscriptions
- [DesignPhilosophy.md](./DesignPhilosophy.md) — Why these constraints exist
- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Backend state machine

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from UI_IMPLEMENTATION.md §2 as part of documentation reorganization |
