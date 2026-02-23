# Execution Kernel

> **Execution Layer: MSBuild Integration, NuGet Management, and Build Operations**
>
> **Parent Document:** [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md)
>
> **Related:** [FilesystemSandbox.md](./FilesystemSandbox.md) — Workspace isolation

---

## Table of Contents

1. [Purpose](#1-purpose)
2. [Key Responsibilities](#2-key-responsibilities)
3. [Implementation](#3-implementation)
4. [Structured Logger](#4-structured-logger)
5. [Embedded Subsystems](#5-embedded-subsystems)

---

## 1. Purpose

The Execution Kernel wraps the .NET SDK tools (MSBuild, NuGet) into a managed API. It **never** launches `dotnet.exe` processes, preferring in-process libraries for speed, reliability, and structured error handling.

---

## 2. Key Responsibilities

- **MSBuild Localization**: Uses `Microsoft.Build.Locator` to find the correct SDK without user PATH configuration.
- **NuGet Cache Management**: Maintains a local package cache to avoid redownloading common packages.
- **Build Logger**: Implementation of `ILogger` that captures MSBuild events and converts them into structured definitions.

---

## 3. Implementation

```csharp
public class ExecutionKernel
{
    private readonly ILogger<ExecutionKernel> _logger;
    private readonly FileSystemSandbox _sandbox;
    private static bool _isInitialized;

    public ExecutionKernel(ILogger<ExecutionKernel> logger, FileSystemSandbox sandbox)
    {
        _logger = logger;
        _sandbox = sandbox;
        InitializeMSBuild();
    }

    /// <summary>
    /// One-time initialization of MSBuild Locator
    /// </summary>
    private static void InitializeMSBuild()
    {
        if (!_isInitialized)
        {
            // Locate the embedded SDK/MSBuild instance
            MSBuildLocator.RegisterDefaults();
            _isInitialized = true;
        }
    }

    /// <summary>
    /// Builds project in an ISOLATED workspace copy to prevent mutation race conditions
    /// </summary>
    public async Task<BuildResult> BuildAsync(
        string projectPath,
        string configuration = "Debug")
    {
        // ISOLATION STEP: Copy source to %USERPROFILE%\.syncai\Temp\{BuildId} before build
        var isolatedPath = await _sandbox.CreateIsolatedCopyAsync(projectPath);

        return await Task.Run(() =>
        {
            var projectCollection = new ProjectCollection();
            var buildLogger = new StructuredLogger();

            try
            {
                // Load project into memory
                var project = projectCollection.LoadProject(Path.Combine(isolatedPath, "SyncAIAppBuilder.csproj"));

                // Set properties
                project.SetProperty("Configuration", configuration);
                project.SetProperty("Platform", "Any CPU");

                // Configure logger
                var buildParameters = new BuildParameters(projectCollection)
                {
                    Loggers = new[] { buildLogger },
                    MaxNodeCount = Environment.ProcessorCount // Parallel build
                };

                // Create build request
                var buildRequest = new BuildRequestData(
                    project.CreateProjectInstance(),
                    new[] { "Restore", "Build" } // Run Restore then Build
                );

                // Execute Build
                var result = BuildManager.DefaultBuildManager
                    .Build(buildParameters, buildRequest);

                return new BuildResult
                {
                    Success = result.OverallResult == BuildResultCode.Success,
                    Output = buildLogger.Output,
                    Errors = buildLogger.Errors,
                    ExitCode = result.OverallResult == BuildResultCode.Success ? 0 : 1
                };
            }
            finally
            {
                projectCollection.Dispose();
            }
        });
    }

    /// <summary>
    /// Builds with timeout and cancellation support
    /// </summary>
    public async Task<BuildResult> BuildWithTimeoutAsync(
        string projectPath,
        TimeSpan timeout,
        CancellationToken cancellationToken = default)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        cts.CancelAfter(timeout);

        try
        {
            return await BuildAsync(projectPath, "Debug");
        }
        catch (OperationCanceledException)
        {
            return new BuildResult
            {
                Success = false,
                Errors = $"Build timed out after {timeout.TotalSeconds} seconds",
                TimedOut = true
            };
        }
    }
}
```

---

## 4. Structured Logger

```csharp
private class StructuredLogger : ILogger
{
    public string Output { get; private set; } = string.Empty;
    public string Errors { get; private set; } = string.Empty;
    public string FullLog { get; private set; } = string.Empty;

    public void Initialize(IEventSource eventSource)
    {
        eventSource.ErrorRaised += (s, e) => Errors += $"{e.File}:{e.LineNumber}: error {e.Code}: {e.Message}\n";
        eventSource.WarningRaised += (s, e) => Output += $"{e.File}:{e.LineNumber}: warning {e.Code}: {e.Message}\n";
        eventSource.MessageRaised += (s, e) => FullLog += e.Message + "\n";
    }

    public void Shutdown() { }
    public LoggerVerbosity Verbosity { get; set; }
    public string? Parameters { get; set; }
}
```

---

## 5. Embedded Subsystems

### Why "Embedded"?

| Component         | Traditional Approach          | Sync AI Embedded Approach                           |
| ----------------- | ----------------------------- | --------------------------------------------------- |
| **Build**         | Shell out to `dotnet CLI`     | `Microsoft.Build.Execution.BuildManager` in-process |
| **NuGet**         | Shell out to `dotnet CLI`     | `NuGet.Commands.RestoreCommand` in-process          |
| **Code Analysis** | External linter               | `Microsoft.CodeAnalysis` (Roslyn) in-process        |
| **Database**      | External DB server            | `Microsoft.Data.Sqlite` embedded                    |
| **Preview**       | External browser              | WinUI 3 `WebView2` or XAML renderer                 |

### The 6 Embedded Subsystems

1. **Filesystem Sandbox**: Manages isolated workspaces, enforcing security boundaries
2. **Execution Kernel**: The "engine room" that manages .NET SDK, MSBuild, and NuGet operations
3. **Roslyn Code Intelligence**: Parses code into ASTs, maintains symbol graph
4. **Transactional Patch Engine**: Performs safe, reversible code mutations
5. **SQLite Project Graph**: Persists project structure, symbols, dependencies
6. **Process Sandbox**: Manages isolated execution with resource limits
7. **AI Mini Service**: Managed child process for AI capabilities

### AI Mini Service Process

The AI Mini Service is treated as a managed child process.

- Started at application boot.
- Bound to 127.0.0.1 only.
- Restarted on config changes.
- Terminated on SYSTEM_RESET.
- Monitored for crash recovery.

The AI Mini Service does NOT persist configuration to disk.
All configuration is pushed at runtime via POST /api/config.

### Architecture Diagram

```text
┌─────────────────────────────────────────────────────────┐
│ SyncAI Process                                          │
│                                                         │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│ │ Execution    │ │ Code         │ │ Patch        │     │
│ │ Kernel       │ │ Intelligence │ │ Engine       │     │
│ │              │ │              │ │              │     │
│ │ MSBuild API  │ │ Roslyn AST   │ │ Transactional│     │
│ │ NuGet API    │ │ Symbol Graph │ │ Writes       │     │
│ │ Process Mgr  │ │ Dep. Anal.   │ │ Rollback     │     │
│ └──────────────┘ └──────────────┘ └──────────────┘     │
│                                                         │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│ │ Filesystem   │ │ SQLite       │ │ Snapshot     │     │
│ │ Sandbox      │ │ Graph DB     │ │ Manager      │     │
│ │              │ │              │ │              │     │
│ │ Isolation    │ │ Symbols      │ │ Versioning   │     │
│ │ Path Safety  │ │ Deps         │ │ Diff/Patch   │     │
│ │ Workspace    │ │ Errors       │ │ Rollback     │     │
│ └──────────────┘ └──────────────┘ └──────────────┘     │
└─────────────────────────────────────────────────────────┘
```

---

## References

- [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md) — Parent document
- [FilesystemSandbox.md](./FilesystemSandbox.md) — Workspace isolation
- [ProcessIsolation.md](./ProcessIsolation.md) — Job Objects and ACL enforcement
- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Build pipeline integration

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from EXECUTION_ENVIRONMENT.md as part of documentation reorganization |