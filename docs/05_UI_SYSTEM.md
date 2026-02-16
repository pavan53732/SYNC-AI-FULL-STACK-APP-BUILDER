# UI System

> **Authority**: This document defines UI states, user experience, advanced mode, conversational refinement, timeline, and export flow.
> **Status**: User interface layer

---

## Part 1: UI Architecture Rules

### Core Principles
- **WinUI 3** (Windows App SDK) - Modern Windows UI framework
- **MVVM pattern mandatory** - ViewModels handle all UI logic
- **UI is thin** - No business logic in code-behind
- **No direct file writes** - All file operations through services
- **No direct build calls** - All actions go through Orchestrator
- **All long operations async** - Never block UI thread

### Dependency Injection
```csharp
public class App : Application
{
    private readonly IServiceProvider _services;
    
    private IServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();
        
        // ViewModels
        services.AddTransient<MainViewModel>();
        services.AddTransient<EditorViewModel>();
        services.AddTransient<ProjectsViewModel>();
        
        // Services
        services.AddSingleton<IProjectService, ProjectService>();
        services.AddScoped<IOrchestrator, OrchestratorService>();
        
        return services.BuildServiceProvider();
    }
}
```

---

## Part 2: UI States

### Orchestrator State → UI Mapping

| Orchestrator State | UI Indicator | Icon | Color |
|--------------------|--------------|------|-------|
| IDLE | "Ready" | ✅ | Green |
| SPEC_PARSING | "Analyzing..." | 🔄 | Blue |
| TASK_GRAPH_READY | "Planning..." | 📋 | Blue |
| TASK_EXECUTING | "Building..." | 🔨 | Orange |
| VALIDATING | "Validating..." | ✓ | Blue |
| RETRYING | "Retrying..." | ↻ | Yellow |
| COMPLETED | "Success" | ✅ | Green |
| FAILED | "Failed" | ❌ | Red |

---

## Part 3: Main Application Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Title Bar                                                    │
│  [App Icon] SyncAI Explorer    [Project: MyApp ▼] [⚙] [−][□][×]│
├─────────────────────────────────────────────────────────────┤
│ Navigation Bar                                               │
│  [Projects] [Editor] [Preview] [Build Monitor] [Settings]   │
├──────────────────┬──────────────────────────────────────────┤
│ Left Panel       │ Main Content Area                        │
│ (200-300px)     │                                          │
│                  │                                          │
│ Project Explorer │ Dynamic content based on selected tab     │
│ or File Tree     │                                          │
│                  │                                          │
├──────────────────┴──────────────────────────────────────────┤
│ Status Bar                                                   │
│ [Orchestrator: IDLE] [SDK: ✓] [Last Build: 2.3s] [Errors: 0]│
└─────────────────────────────────────────────────────────────┘
```

---

## Part 4: Progressive Disclosure Pattern

### Philosophy

> **"Powerful internal system, minimal visible complexity"**

### Default View (Simple Mode)

**Always Visible**:
- ✅ Prompt input (EditorPage)
- ✅ Generate button
- ✅ Preview tabs
- ✅ Export button
- ✅ Status bar (minimal)

**Hidden by Default**:
- ❌ Build Monitor panel
- ❌ Task graph visualization
- ❌ Raw build logs
- ❌ Retry attempt details
- ❌ Advanced build settings

### Developer Mode Toggle

Users can enable **"Developer Mode"** in Settings to reveal advanced features.

---

## Part 5: Error Display Strategy

### Tier 1: Silent Auto-Recovery
- No error message shown
- Spinner continues smoothly
- No UI change whatsoever
- Only logged internally

### Tier 2: Recoverable Failure
```
⚠️ Build Issue Detected
We encountered an issue while building your app. Retrying with adjustments…
```

### Tier 3: Hard Failure
```
❌ Build Could Not Complete
We couldn't complete this build.

[Retry] [Modify Prompt] [Cancel]
```

---

## Part 6: First-Time User Experience

### Empty State (First Launch)

**Layout** (Centered, 720px max width):
```
┌─────────────────────────────────────┐
│  What would you like to build?     │
│                                     │
│  [Describe your app...]             │
│                                     │
│  [Generate Application]             │
│                                     │
│  Suggestions:                       │
│  [Inventory] [CRM] [Task Manager]  │
└─────────────────────────────────────┘
```

### No Tutorial Wizard
- ❌ No multi-step onboarding
- ❌ No feature tour
- ✅ Immediate prompt input
- ✅ Contextual tooltips only when needed

---

## Part 7: Micro-Interactions

### Generate Button Behavior

**Idle → Hover → Click → Building**
```csharp
// Click Animation (80ms shrink)
var scaleAnimation = compositor.CreateVector3KeyFrameAnimation();
scaleAnimation.InsertKeyFrame(0.0f, new Vector3(1.0f, 1.0f, 1.0f));
scaleAnimation.InsertKeyFrame(1.0f, new Vector3(0.96f, 0.96f, 1.0f));
scaleAnimation.Duration = TimeSpan.FromMilliseconds(80);
GenerateButton.StartAnimation("Scale", scaleAnimation);
```

### Status Dot Pulse

Building state: 1.5s pulse cycle with color change
- Scale: 1.0 → 1.15 → 1.0
- Color: Gray → Blue (pulsing)

---

## Part 8: Theme System

### Light/Dark Mode Support

```xaml
<Application.Resources>
    <ResourceDictionary.ThemeDictionaries>
        <ResourceDictionary x:Key="Light">
            <SolidColorBrush x:Key="AppBackgroundBrush" Color="#FFFFFF"/>
        </ResourceDictionary>
        <ResourceDictionary x:Key="Dark">
            <SolidColorBrush x:Key="AppBackgroundBrush" Color="#1E1E1E"/>
        </ResourceDictionary>
    </ResourceDictionary.ThemeDictionaries>
</Application.Resources>
```

---

## Part 9: UI → Orchestrator Contract

### Command Pattern

```csharp
// ViewModel sends command
public async Task GenerateApp()
{
    var command = new GenerateProjectCommand
    {
        Prompt = this.Prompt,
        ProjectPath = this.CurrentProjectPath,
        GenerationMode = this.SelectedMode
    };
    
    await _orchestrator.SubmitCommandAsync(command);
}
```

### Event Subscription

```csharp
// UI receives events from Orchestrator
_orchestrator.StateChanged += OnOrchestratorStateChanged;
_orchestrator.TaskProgress += OnTaskProgress;
_orchestrator.BuildResult += OnBuildResult;
```

### UI Never Directly:
- ❌ Calls kernel services
- ❌ Modifies workspace files
- ❌ Handles retry logic

---

## Related Documents

- [00_CANONICAL_AUTHORITY.md](./00_CANONICAL_AUTHORITY.md) - System invariants
- [02_ORCHESTRATION_AND_EXECUTION.md](./02_ORCHESTRATION_AND_EXECUTION.md) - State machine

---

**End of UI System**
