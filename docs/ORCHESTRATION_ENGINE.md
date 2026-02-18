# ORCHESTRATION ENGINE

> **The Logic Brain: State Machine, Task Lifecycle, Build System, Retry Logic & Concurrency Safety**
>
> _Merged from: ORCHESTRATOR_SPECIFICATION.md, BUILD_SYSTEM_SPECIFICATION.md, ERROR_HANDLING_SPECIFICATION.md, API_CONTRACTS.md_

---

## Table of Contents

1. [Core Challenge & Positioning](#1-core-challenge--positioning)
2. [Task Schema](#2-task-schema)
3. [State Machine](#3-state-machine)
4. [State Container & Event Log](#4-state-container--event-log)
5. [State Reducer](#5-state-reducer)
6. [Retry Controller](#6-retry-controller)
7. [Concurrency Rules](#7-concurrency-rules)
8. [Build System](#8-build-system)
9. [Error Handling](#9-error-handling)
10. [API Contracts](#10-api-contracts)
11. [Implementation Sequence](#11-implementation-sequence)

---

## 1. Core Challenge & Positioning

### Why the Orchestrator Must Come First

**Priority**: 🔴 **FIRST DELIVERABLE** — Must implement before all other components.

Without a deterministic orchestrator:

- Roslyn patch engine can produce cascading corruption
- Retry loops become nondeterministic
- Memory layer tracking becomes unreliable
- State debugging becomes impossible
- Silent error fixing can perpetuate failures

**Solution**: Control layer MUST exist BEFORE mutation layer.

### Architectural Position

```
┌──────────────────────────┐
│   WinUI 3 UI Layer       │
│   (User Input/Output)    │
└────────────┬─────────────┘
             │ (Command Request)
             ↓
┌──────────────────────────┐
│   ORCHESTRATOR ENGINE    │ ← CONTROL LAYER (This Spec)
│   • State Machine        │
│   • Task Queue           │
│   • Retry Controller     │
│   • Event Log            │
└────────────┬─────────────┘
             │ (Execute Task)
             ↓
┌──────────────────────────┐
│   Execution Kernel       │
│   • Roslyn Indexer       │
│   • Patch Engine         │
│   • MSBuild Runner       │
│   • Sandbox FS           │
└────────────┬─────────────┘
             │ (Result)
             ↓
┌──────────────────────────┐
│   SQLite (Graph + Logs)  │
└──────────────────────────┘
```

**Key Rules**:

- Orchestrator sits **BETWEEN** UI and kernel, NOT embedded in either
- UI submits commands to orchestrator → Orchestrator validates, queues, dispatches
- Kernel executes work → Orchestrator monitors result and decides retry or failure
- **Never**: UI directly calls kernel. Always through orchestrator.

### Core Principles

```
✓ No implicit transitions
✓ No uncontrolled parallel mutation
✓ One active task at a time (strict serialization)
✓ Strict retry budget (no infinite loops)
✓ Immutable state transitions (functional programming)
✓ Full event log for replay/debug (deterministic replay)
```

---

## 2. Task Schema

### Task Types (Versioned & Typed)

```csharp
public enum TaskType
{
    /// Project-level operations
    CREATE_PROJECT,
    MIGRATE_SCHEMA,
    ADD_DEPENDENCY,

    /// Architectural-level operations
    ADD_VIEW,
    ADD_VIEWMODEL,
    ADD_SERVICE,

    /// File-level operations
    MODIFY_FILE,
    PATCH_FILE,
    ADD_FILE,
    DELETE_FILE,
    REFACTOR_FILE
}

public enum ValidationStrategy
{
    DOTNET_BUILD,        // Run full dotnet build
    XAML_COMPILE,        // Compile XAML only
    NUGET_RESTORE,       // Restore packages
    SYNTAX_CHECK_ONLY,   // Parse syntax without build
    NONE                 // No validation
}

public enum TaskStatus
{
    PENDING,             // Queued, awaiting execution
    RUNNING,             // Currently executing
    VALIDATING,          // Build/validation phase
    RETRYING,            // Failed, attempting retry
    COMPLETED,           // Success
    FAILED               // Exhausted retries
}

public enum ErrorType
{
    BUILD_ERROR,         // C# compiler error (CSxxxx)
    XAML_ERROR,          // XAML compiler error (XDGxxxx)
    NUGET_ERROR,         // NuGet restore error (NUxxxx)
    PATCH_CONFLICT,      // Roslyn patch failed to apply
    VALIDATION_TIMEOUT   // Build took too long
}
```

### Task Class

```csharp
public class Task
{
    public string Id { get; }                          // Unique task ID
    public int Version { get; } = 1;                   // Schema version
    public TaskType Type { get; }                      // Task type (strictly typed)
    public string Description { get; }                 // Human-readable description

    // Dependencies
    public List<string> DependsOnTaskIds { get; }     // Must complete these first
    public List<string> TargetFiles { get; }          // Files this task touches

    // Validation configuration
    public ValidationStrategy Validation { get; }      // How to validate success
    public TimeSpan ValidationTimeout { get; }        // Max time for validation

    // Retry configuration
    public int RetryCount { get; set; }               // Current attempt number
    public int MaxRetries { get; set; } = 5;          // Absolute max attempts

    // State
    public TaskStatus Status { get; set; }            // Current status
    public ErrorType? LastError { get; set; }         // Last error encountered
    public string? ErrorMessage { get; set; }         // Error details
    public int RetryBudget { get; set; } = 5;         // Remaining retries

    // Audit trail
    public DateTime CreatedAt { get; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public List<string> ActionLog { get; } = new();   // What was attempted
}
```

**Key Design Decision**: No free-form tasks. Only structured, enumerated task types prevent undefined behavior.

---

## 3. State Machine

### Builder States

```csharp
public enum OrchestratorState
{
    IDLE,
    AI_PLANNING,
    SPEC_PARSED,
    TASK_GRAPH_READY,
    TASK_EXECUTING,
    VALIDATING,
    RETRYING,
    COMPLETED,
    FAILED
}

```

### State Diagram

```
IDLE
  ↓ (prompt submitted)
AI_PLANNING
  ↓ (planning complete)
SPEC_PARSED
  ↓ (graph generated)
TASK_GRAPH_READY
  ↓ (dispatch task)
TASK_EXECUTING
  ↓ (patch applied & indexed)
VALIDATING
  ↓ (validation succeeds)    ↓ (validation fails)
COMPLETED                  RETRYING
                              ↓ (retry < maxRetries)
                           TASK_EXECUTING
                              ↓ (retry >= maxRetries)
                           FAILED
```

---

## 4. State Container & Event Log

### BuilderContext (Single Source of Truth)

```csharp
public class BuilderContext
{
    public OrchestratorState State { get; set; }

    // Task execution
    public List<Task> AllTasks { get; } = new();
    public string? CurrentTaskId { get; set; }
    public Dictionary<string, Task> TaskMap { get; } = new();

    // Event log (replayable)
    public List<BuilderEvent> EventLog { get; } = new();

    // Budget/limits
    public int TotalRetryBudget { get; set; } = 50;   // System-wide retry budget
    public int UsedRetry { get; set; } = 0;

    // Project metadata
    public string ProjectName { get; set; }
    public string ProjectPath { get; set; }
    public Dictionary<string, object> ProjectMetadata { get; } = new();

    // Debug info
    public List<string> DebugLog { get; } = new();
    public DateTime StartTime { get; } = DateTime.Now;
}
```

**Principle**: BuilderContext is the **single source of truth**. All components read from it, only the reducer writes to it.

### Event Types (Replayable & Debuggable)

```csharp
public abstract record BuilderEvent
{
    public DateTime Timestamp { get; init; } = DateTime.Now;
    public int EventSequence { get; init; } // Monotonic counter
}

// Parsing events
public record SpecParsedEvent : BuilderEvent
{
    public string SpecJson { get; init; }
    public List<string> ExtractedFeatures { get; init; }
}

// Task execution events
public record TaskStartedEvent : BuilderEvent { public string TaskId { get; init; }; public TaskType TaskType { get; init; } }
public record TaskGuardPassedEvent : BuilderEvent { public string TaskId { get; init; }; public string ImpactAnalysis { get; init; } }
public record TaskPatchedEvent : BuilderEvent { public string TaskId { get; init; }; public List<string> ModifiedFiles { get; init; } }
public record TaskIndexedEvent : BuilderEvent { public string TaskId { get; init; }; public int NodesIndexed { get; init; } }
public record TaskValidatingEvent : BuilderEvent { public string TaskId { get; init; }; public ValidationStrategy Strategy { get; init; } }
public record TaskCompletedEvent : BuilderEvent { public string TaskId { get; init; }; public TimeSpan Duration { get; init; } }

// Failure events
public record TaskFailedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public ErrorType ErrorType { get; init; }
    public string ErrorMessage { get; init; }
    public int CurrentRetry { get; init; }
    public int MaxRetries { get; init; }
}

// System-level events
public record BuildCompletedEvent : BuilderEvent { public int TasksCompleted { get; init; }; public TimeSpan TotalDuration { get; init; }; public List<string> GeneratedFiles { get; init; } }
public record BuildFailedEvent : BuilderEvent { public string FailureReason { get; init; }; public string TaskIdThatFailed { get; init; } }
public record RetryStartedEvent : BuilderEvent { public string TaskId { get; init; }; public int CurrentRetry { get; init; }; public ErrorType PreviousError { get; init; } }
```

**Design**: Events are immutable records. Full event log enables perfect replay for debugging or audit.

---

## 5. State Reducer

The reducer is a **pure function** that takes (state, event) → new state.

```csharp
public class BuilderReducer
{
    public static BuilderContext Reduce(
        BuilderContext context,
        BuilderEvent @event)
    {
        return (context.State, @event) switch
        {
            // === SPEC PARSING ===
            (OrchestratorState.IDLE, SpecParsedEvent e) => context with
            {
                State = OrchestratorState.SPEC_PARSED,
                EventLog = [..context.EventLog, @event],
                ProjectMetadata = e.ExtractedFeatures.ToDictionary(f => f, f => (object)true)
            },

            // === TASK GRAPH BUILDING ===
            (OrchestratorState.SPEC_PARSED, var e) when @event is TaskStartedEvent te && te.TaskId == "graph-builder" =>
                context with { State = OrchestratorState.AI_PLANNING, EventLog = [..context.EventLog, @event] },

            (OrchestratorState.AI_PLANNING, var e) when @event is TaskCompletedEvent te && te.TaskId == "graph-builder" =>
                context with { State = OrchestratorState.TASK_GRAPH_READY, EventLog = [..context.EventLog, @event] },

            // === TASK EXECUTION PHASES ===
            (OrchestratorState.TASK_GRAPH_READY, TaskStartedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, OrchestratorState.TASK_EXECUTING, @event),

            (OrchestratorState.TASK_EXECUTING, TaskGuardPassedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, OrchestratorState.TASK_EXECUTING, @event),

            (OrchestratorState.TASK_EXECUTING, TaskPatchedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, OrchestratorState.TASK_EXECUTING, @event),

            (OrchestratorState.TASK_EXECUTING, TaskIndexedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, OrchestratorState.VALIDATING, @event),

            (OrchestratorState.VALIDATING, TaskValidatingEvent e) =>
                context with { State = OrchestratorState.VALIDATING, EventLog = [..context.EventLog, @event] },

            // === SUCCESS PATH ===
            (OrchestratorState.VALIDATING, TaskCompletedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, OrchestratorState.TASK_GRAPH_READY, @event),

            // === FAILURE & RETRY PATH ===
            (OrchestratorState.VALIDATING, TaskFailedEvent e) when e.CurrentRetry < e.MaxRetries =>
                context with { State = OrchestratorState.RETRYING, EventLog = [..context.EventLog, @event] },

            (OrchestratorState.RETRYING, TaskStartedEvent e) =>
                context with { State = OrchestratorState.TASK_EXECUTING, EventLog = [..context.EventLog, @event] },

            (OrchestratorState.VALIDATING, TaskFailedEvent e) when e.CurrentRetry >= e.MaxRetries =>
                context with { State = OrchestratorState.FAILED, EventLog = [..context.EventLog, @event] },

            // === COMPLETION ===
            (OrchestratorState.TASK_GRAPH_READY, BuildCompletedEvent e) =>
                context with { State = OrchestratorState.COMPLETED, EventLog = [..context.EventLog, @event] },

            // === INVALID TRANSITION ===
            _ => throw new InvalidOperationException(
                $"Invalid transition: {context.State} + {(@event.GetType().Name)} not allowed")
        };
    }

    private static BuilderContext UpdateTaskAndTransition(
        BuilderContext context,
        string taskId,
        OrchestratorState newState,
        BuilderEvent @event)
    {
        if (context.TaskMap.TryGetValue(taskId, out var task))
        {
            task.Status = newState switch
            {
                OrchestratorState.TASK_EXECUTING => TaskStatus.RUNNING,
                OrchestratorState.VALIDATING => TaskStatus.VALIDATING,
                OrchestratorState.TASK_GRAPH_READY => TaskStatus.COMPLETED,
                _ => task.Status
            };
        }

        return context with
        {
            State = newState,
            CurrentTaskId = newState == OrchestratorState.TASK_GRAPH_READY ? null : taskId,
            EventLog = [..context.EventLog, @event]
        };
    }
}
```

**Key Property**: The reducer is **pure** (no side effects). Given the same input, it always produces the same output. This enables perfect replay, time-travel debugging, and deterministic state reconstruction.

---

## 6. Retry Controller

```csharp
public class RetryController
{
    public static bool ShouldRetry(Task task, BuilderContext context) =>
        task.RetryCount < task.MaxRetries &&
        context.UsedRetry < context.TotalRetryBudget;

    public static BuilderContext ExecuteRetry(
        BuilderContext context,
        Task failedTask,
        ErrorClassification errorClassification)
    {
        if (!ShouldRetry(failedTask, context))
        {
            return new BuilderReducer().Reduce(context,
                new TaskFailedEvent
                {
                    TaskId = failedTask.Id,
                    ErrorType = errorClassification.Type,
                    ErrorMessage = $"Exhausted retries ({failedTask.RetryCount}/{failedTask.MaxRetries})",
                    CurrentRetry = failedTask.RetryCount,
                    MaxRetries = failedTask.MaxRetries
                });
        }

        failedTask.RetryCount++;
        context.UsedRetry++;

        return context with
        {
            State = OrchestratorState.RETRYING,
            EventLog = [..context.EventLog, new RetryStartedEvent
            {
                TaskId = failedTask.Id,
                CurrentRetry = failedTask.RetryCount,
                PreviousError = errorClassification.Type
            }]
        };
    }
}
```

### Retry Rules

1. No task retries more than its `MaxRetries` value
2. No system retries beyond total `TotalRetryBudget`
3. Each retry must be explicitly logged
4. Retry must re-run: patch → validation → error classification

### Retry Policy (Exponential Backoff)

```csharp
public class RetryPolicy
{
    public int MaxRetries { get; set; } = 3;
    public TimeSpan InitialDelay { get; set; } = TimeSpan.FromSeconds(1);
    public double BackoffMultiplier { get; set; } = 2.0;
    public TimeSpan MaxDelay { get; set; } = TimeSpan.FromSeconds(30);

    public async Task<T> ExecuteAsync<T>(
        Func<Task<T>> operation,
        Func<Exception, bool> shouldRetry)
    {
        var attempt = 0;
        var delay = InitialDelay;

        while (true)
        {
            try { return await operation(); }
            catch (Exception ex) when (shouldRetry(ex) && attempt < MaxRetries)
            {
                attempt++;
                await Task.Delay(delay);
                delay = TimeSpan.FromMilliseconds(
                    Math.Min(delay.TotalMilliseconds * BackoffMultiplier, MaxDelay.TotalMilliseconds));
            }
        }
    }
}
```

### Retry Decision Matrix

| Error Type          | Retry? | Max Retries | Strategy             |
| ------------------- | ------ | ----------- | -------------------- |
| **Network Errors**  | ✅ Yes | 3           | Exponential backoff  |
| **API Rate Limit**  | ✅ Yes | 5           | Fixed delay (60s)    |
| **Syntax Errors**   | ✅ Yes | 3           | AI re-generation     |
| **Build Timeout**   | ✅ Yes | 1           | Increase timeout     |
| **SDK Not Found**   | ❌ No  | 0           | User must install    |
| **API Key Invalid** | ❌ No  | 0           | User must fix        |
| **Disk Full**       | ❌ No  | 0           | User must free space |

---

## 7. Concurrency Rules

### Strict Serialization

```csharp
public class ConcurrencyPolicy
{
    /// Only ONE mutation task can be active at a time.
    /// This prevents Roslyn patch conflicts and state corruption.
    public static bool IsMutationTask(TaskType type) => type switch
    {
        TaskType.CREATE_PROJECT or
        TaskType.ADD_VIEW or
        TaskType.ADD_VIEWMODEL or
        TaskType.ADD_SERVICE or
        TaskType.MODIFY_FILE or
        TaskType.PATCH_FILE or
        TaskType.ADD_FILE or
        TaskType.DELETE_FILE or
        TaskType.REFACTOR_FILE => true,
        _ => false
    };

    public static bool IsReadOnlyTask(TaskType type) => type switch
    {
        TaskType.MIGRATE_SCHEMA or TaskType.ADD_DEPENDENCY => false,
        _ => false
    };

    public static void ValidateConcurrency(
        BuilderContext context,
        Task incomingTask)
    {
        if (context.State == OrchestratorState.TASK_EXECUTING && IsMutationTask(incomingTask.Type))
        {
            throw new InvalidOperationException(
                "Cannot start mutation task while another task is executing. " +
                "Maintain serialization to prevent Roslyn conflicts.");
        }
    }
}
```

**Iron Law**: Only 1 mutation task at a time. No parallel Roslyn patching.

---

## 8. Build System

### Responsibilities

The Build System is responsible for:

- **Execute In-Process Restore** - Restore NuGet packages via MSBuild API
- **Execute In-Process Build** - Compile C# and XAML via `BuildManager`
- **Capture Structured Logs** - Collect errors/warnings directly from `ILogger`
- **Enforce timeout** - Prevent infinite builds
- **Enforce process isolation** - Build in isolated `ProjectCollection` context
- **Classify errors** - Categorize by error type
- **Support cancellation** - Allow user to cancel builds
- **Snapshot management** - Create/restore workspace snapshots

### Build Flow

```
Task Starts → Snapshot Workspace → Apply Patch (if any) → Clean Workspace
    → Execute In-Process Build (MSBuild) → Process Build Result
    → SUCCESS: Commit Snapshot
    → FAILURE: Classify Error → Return to Orchestrator
```

### IBuildService Interface

```csharp
public interface IBuildService
{
    Task<BuildResult> BuildAsync(
        string projectPath,
        BuildOptions options = null,
        CancellationToken cancellationToken = default);

    Task<RestoreResult> RestoreAsync(
        string projectPath,
        CancellationToken cancellationToken = default);

    Task CleanAsync(string projectPath);
}

public class BuildOptions
{
    public string Configuration { get; set; } = "Debug";
    public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(60);
    public bool RestoreBeforeBuild { get; set; } = true;
    public Dictionary<string, string> Properties { get; set; } = new();
    public LoggerVerbosity Verbosity { get; set; } = LoggerVerbosity.Minimal;
}

public class BuildResult
{
    public bool Success { get; set; }
    public ErrorType? ErrorType { get; set; }
    public string ErrorMessage { get; set; }
    public List<BuildError> Errors { get; set; } = new();
    public List<BuildWarning> Warnings { get; set; } = new();
    public TimeSpan Duration { get; set; }
    public string BuildLog { get; set; }
}

public class BuildError
{
    public string Code { get; set; }          // e.g. CS1002
    public string Message { get; set; }
    public string File { get; set; }
    public int LineNumber { get; set; }
    public int ColumnNumber { get; set; }
    public ErrorType ErrorType { get; set; }  // e.g. CSharpCompiler
}

public class BuildWarning
{
    public string Code { get; set; }
    public string Message { get; set; }
    public string File { get; set; }
    public int LineNumber { get; set; }
    public int ColumnNumber { get; set; }
}

public class RestoreResult
{
    public bool Success { get; set; }
    public List<string> RestoredPackages { get; set; } = new();
    public TimeSpan Duration { get; set; }
    public string ErrorMessage { get; set; }
}
```

### BuildService Implementation

```csharp
using Microsoft.Build.Evaluation;
using Microsoft.Build.Execution;
using Microsoft.Build.Framework;

public class BuildService : IBuildService
{
    private readonly ILogger<BuildService> _logger;
    private readonly ErrorClassifier _errorClassifier;

    public async Task<BuildResult> BuildAsync(
        string projectPath,
        BuildOptions options = null,
        CancellationToken cancellationToken = default)
    {
        options ??= new BuildOptions();
        var stopwatch = Stopwatch.StartNew();

        return await Task.Run(() =>
        {
            var projectCollection = new ProjectCollection();
            var buildLogger = new StructuredLogger();

            try
            {
                var project = projectCollection.LoadProject(projectPath);
                project.SetProperty("Configuration", options.Configuration);

                var buildParameters = new BuildParameters(projectCollection)
                {
                    Loggers = new[] { buildLogger },
                    MaxNodeCount = Environment.ProcessorCount,
                    DetailedSummary = false
                };

                var targets = options.RestoreBeforeBuild
                    ? new[] { "Restore", "Build" }
                    : new[] { "Build" };

                var buildRequest = new BuildRequestData(
                    project.CreateProjectInstance(), targets);

                var buildResult = BuildManager.DefaultBuildManager
                    .Build(buildParameters, buildRequest);

                stopwatch.Stop();
                return CreateResult(buildResult, buildLogger, stopwatch.Elapsed);
            }
            finally
            {
                projectCollection.Dispose();
            }
        }, cancellationToken);
    }

    public async Task<RestoreResult> RestoreAsync(
        string projectPath,
        CancellationToken cancellationToken = default)
    {
        // Re-use BuildAsync with "Restore" target only
        var options = new BuildOptions
        {
            RestoreBeforeBuild = false
        };

        var projectCollection = new ProjectCollection();
        var buildLogger = new StructuredLogger();

        try
        {
            var project = projectCollection.LoadProject(projectPath);
            var buildParameters = new BuildParameters(projectCollection)
            {
                Loggers = new[] { buildLogger }
            };

            var buildRequest = new BuildRequestData(
                project.CreateProjectInstance(),
                new[] { "Restore" });

            var buildResult = BuildManager.DefaultBuildManager
                .Build(buildParameters, buildRequest);

            return new RestoreResult
            {
                Success = buildResult.OverallResult == BuildResultCode.Success,
                RestoredPackages = ExtractRestoredPackages(buildLogger),
                Duration = TimeSpan.Zero // Calculate from stopwatch
            };
        }
        finally
        {
            projectCollection.Dispose();
        }
    }

    public async Task CleanAsync(string projectPath)
    {
        var projectDir = Path.GetDirectoryName(projectPath);
        var binPath = Path.Combine(projectDir, "bin");
        var objPath = Path.Combine(projectDir, "obj");

        if (Directory.Exists(binPath)) Directory.Delete(binPath, recursive: true);
        if (Directory.Exists(objPath)) Directory.Delete(objPath, recursive: true);

        await Task.CompletedTask;
    }

    private List<string> ExtractRestoredPackages(StructuredLogger logger)
    {
        // Parse restored packages from build log
        var packages = new List<string>();
        // Implementation would parse the log for package names
        return packages;
    }
}
```

### Structured Logger

```csharp
public class StructuredLogger : ILogger
{
    public List<BuildErrorEventArgs> Errors { get; } = new();
    public List<BuildWarningEventArgs> Warnings { get; } = new();
    public string FullLog { get; private set; } = string.Empty;

    public void Initialize(IEventSource eventSource)
    {
        eventSource.ErrorRaised += (s, e) => Errors.Add(e);
        eventSource.WarningRaised += (s, e) => Warnings.Add(e);
    }

    public void Shutdown() { }
    public LoggerVerbosity Verbosity { get; set; }
    public string Parameters { get; set; }
}
```

### Workspace Isolation Rules

- Workspace-specific build directory — each project builds in its own directory
- Clear bin/obj before build — prevent stale artifacts
- No global folder writes — all operations scoped to workspace
- Process must be killable — support cancellation
- No elevated permissions — run as standard user
- Memory limit enforcement — monitor process memory usage
- Timeout enforcement — kill process after timeout

### Snapshot Management

```csharp
public class SnapshotManager
{
    public async Task<string> CreateSnapshotAsync(string workspacePath, string taskId)
    {
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var snapshotName = $"snapshot_{taskId}_{timestamp}.zip";
        var snapshotPath = Path.Combine(_snapshotDir, snapshotName);

        ZipFile.CreateFromDirectory(workspacePath, snapshotPath);
        return snapshotPath;
    }

    public async Task RestoreSnapshotAsync(string snapshotPath, string workspacePath)
    {
        Directory.Delete(workspacePath, recursive: true);
        Directory.CreateDirectory(workspacePath);
        ZipFile.ExtractToDirectory(snapshotPath, workspacePath);
    }
}
```

### Build Performance Optimization

```csharp
public class IncrementalBuildTracker
{
    private readonly Dictionary<string, string> _fileHashes = new();

    public bool HasFileChanged(string filePath)
    {
        var currentHash = ComputeFileHash(filePath);
        if (_fileHashes.TryGetValue(filePath, out var previousHash))
            return currentHash != previousHash;

        _fileHashes[filePath] = currentHash;
        return true;
    }

    private string ComputeFileHash(string filePath)
    {
        using var sha256 = System.Security.Cryptography.SHA256.Create();
        using var stream = File.OpenRead(filePath);
        var hashBytes = sha256.ComputeHash(stream);
        return Convert.ToHexString(hashBytes);
    }
}
```

### Build Caching Strategy

The build system implements multiple caching layers to optimize performance:

1. **NuGet Package Cache** — Cache NuGet packages globally
   - Packages stored in global NuGet cache directory
   - Shared across all projects on the machine
   - Offline mode supported for cached packages

2. **Build Artifact Reuse** — Reuse previous build artifacts when possible
   - Incremental build tracking via file hashes
   - Skip unchanged files during compilation
   - Preserve obj/ directory for incremental builds

3. **Roslyn Compilation Cache** — Cache Roslyn compilation results
   - In-memory cache of compiled syntax trees
   - Reuse compilations for unchanged source files
   - Cache metadata references for common assemblies

```csharp
public class BuildCacheService
{
    private readonly IMemoryCache _compilationCache;
    private readonly string _globalNuGetCache;

    public BuildCacheService(IMemoryCache compilationCache)
    {
        _compilationCache = compilationCache;
        _globalNuGetCache = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".nuget", "packages");
    }

    public bool TryGetCachedCompilation(string fileHash, out CompilationResult result)
    {
        return _compilationCache.TryGetValue(fileHash, out result);
    }

    public void CacheCompilation(string fileHash, CompilationResult result)
    {
        _compilationCache.Set(fileHash, result, TimeSpan.FromHours(1));
    }
}
```

---

## 9. Error Handling

### Error Handling Philosophy

1. **User Never Sees Technical Details** — All errors translated to user-friendly messages
2. **Silent Recovery When Possible** — Retry automatically before showing errors
3. **Actionable Guidance** — Every error message includes next steps
4. **Preserve User Work** — Never lose user data, always snapshot before risky operations
5. **Graceful Degradation** — System remains usable even with partial failures

### Error Severity Levels

| Level        | User Impact           | UI Indicator        | Action Required      |
| ------------ | --------------------- | ------------------- | -------------------- |
| **Info**     | None                  | Blue info icon      | None                 |
| **Warning**  | Minor, non-blocking   | Yellow warning icon | Optional user action |
| **Error**    | Blocking, recoverable | Red error icon      | User must resolve    |
| **Critical** | System-level failure  | Red with alert      | Immediate attention  |

### Error Classification Taxonomy

```csharp
// Build Errors
public enum BuildErrorType
{
    // C# Compiler Errors (CS0001-CS9999)
    CSharpSyntaxError,              // CS1001-CS1999: Syntax errors
    CSharpSemanticError,            // CS0001-CS0999: Type/member errors
    CSharpNullabilityWarning,       // CS8600-CS8999: Nullable reference warnings

    // XAML Errors (XDG0001-XDG9999)
    XamlParseError,                 // XDG0001-XDG0999: XML/XAML syntax
    XamlBindingError,               // XDG1000-XDG1999: Data binding
    XamlResourceError,              // XDG2000-XDG2999: Resource resolution

    // NuGet Errors (NU0001-NU9999)
    NuGetPackageNotFound,           // NU1101: Package doesn't exist
    NuGetVersionConflict,           // NU1107: Version conflict
    NuGetRestoreFailed,             // NU1000: General restore failure

    // MSBuild Errors (MSB0001-MSB9999)
    MSBuildProjectFileError,        // MSB4000-MSB4999: .csproj issues
    MSBuildTargetError,             // MSB3000-MSB3999: Build target failures

    // SDK Errors
    SdkNotFound,                    // .NET SDK not installed
    SdkVersionMismatch,             // Wrong SDK version

    // Timeout
    BuildTimeout,                   // Build exceeded timeout

    // Unknown
    UnknownBuildError
}

// AI Engine Errors
public enum AIErrorType
{
    // API Errors
    ApiKeyMissing,                  // No API key configured
    ApiKeyInvalid,                  // Invalid API key
    ApiRateLimitExceeded,           // Too many requests
    ApiQuotaExceeded,               // Monthly quota exceeded
    ApiNetworkError,                // Network connectivity issue
    ApiTimeout,                     // Request timeout

    // Response Errors
    InvalidJsonResponse,            // Malformed JSON
    SchemaValidationFailed,         // Response doesn't match schema
    EmptyResponse,                  // No content returned

    // Content Errors
    ContentPolicyViolation,         // Prompt violates content policy
    TokenLimitExceeded,             // Prompt too long

    // Model Errors
    ModelNotAvailable,              // Selected model unavailable
    ModelDeprecated,                // Model no longer supported

    UnknownAIError
}

// File System Errors
public enum FileSystemErrorType
{
    PathNotFound,                   // Directory/file doesn't exist
    PathTooLong,                    // Path exceeds Windows limit
    AccessDenied,                   // Permission denied
    DiskFull,                       // Insufficient disk space
    FileInUse,                      // File locked by another process
    InvalidFileName,                // Invalid characters in name
    SnapshotCreationFailed,         // Failed to create snapshot
    SnapshotRestoreFailed,          // Failed to restore snapshot
    UnknownFileSystemError
}

// Roslyn/Patch Errors
public enum PatchErrorType
{
    TargetNotFound,                 // Class/method not found
    SignatureMismatch,              // Method signature changed
    FileHashMismatch,               // File modified since patch created
    SyntaxError,                    // Generated code has syntax errors
    DuplicateMember,                // Member already exists
    ConflictDetected,               // Merge conflict
    ValidationFailed,               // Patch validation failed
    UnknownPatchError
}

// Orchestrator Errors
public enum OrchestratorErrorType
{
    InvalidStateTransition,         // Illegal state machine transition
    TaskExecutionFailed,            // Task failed to execute
    RetryBudgetExceeded,            // Max retries reached
    DependencyFailed,               // Dependent task failed
    TimeoutExceeded,                // Operation timeout
    CancellationRequested,          // User cancelled
    UnknownOrchestratorError
}

// Validation Support
public enum ValidationSeverity
{
    Info,
    Warning,
    Error
}

public enum ErrorSeverity
{
    Info,
    Warning,
    Error,
    Critical
}

public class ValidationResult
{
    public bool IsValid { get; set; }
    public string ErrorMessage { get; set; }
    public ValidationSeverity Severity { get; set; }

    public static ValidationResult Success() =>
        new ValidationResult { IsValid = true };

    public static ValidationResult Error(string message) =>
        new ValidationResult { IsValid = false, ErrorMessage = message, Severity = ValidationSeverity.Error };

    public static ValidationResult Warning(string message) =>
        new ValidationResult { IsValid = true, ErrorMessage = message, Severity = ValidationSeverity.Warning };
}
```

### Error Classifier

```csharp
public class ErrorClassifier
{
    public ErrorType Classify(BuildErrorEventArgs error)
    {
        if (!string.IsNullOrEmpty(error.Code))
        {
            if (error.Code.StartsWith("CS")) return ErrorType.CSharpCompiler;
            if (error.Code.StartsWith("XDG") || error.Code.StartsWith("XLS")) return ErrorType.XamlCompiler;
            if (error.Code.StartsWith("NU")) return ErrorType.NuGetRestore;
            if (error.Code.StartsWith("MSB")) return ErrorType.MSBuildInfrastructure;
        }

        if (error.File != null && error.File.EndsWith(".csproj"))
            return ErrorType.ProjectFile;

        return ErrorType.Unknown;
    }
}
```

### Error Classification Details

When `dotnet build` fails, parse output into structured error types:

```csharp
public enum CompilerErrorCode
{
    CS0001, CS0002, CS0003, // Standard C# compiler errors
    CS0103, CS0117, CS0246, // Type/name not found errors
    CS1001, CS1002, CS1003, // Syntax errors
    CS1501, CS1502, CS1503, // Method overload errors
    XDG0001, XDG0002,       // XAML design-time errors
    XLS0001, XLS0002,       // XAML loading errors
    NU1101, NU1102,         // NuGet package not found
    NU1107, NU1108,         // NuGet version conflicts
    MSB3073, MSB4181        // MSBuild structural errors
}

public record ErrorClassification
{
    public ErrorType Type { get; init; }
    public CompilerErrorCode? Code { get; init; }
    public string Message { get; init; }
    public string FilePath { get; init; }
    public int? LineNumber { get; init; }

    // Classification strategy for this specific error
    public string AutoFixStrategy { get; init; }

    /// <summary>
    /// Should this error be auto-retried, or is it unrecoverable?
    /// </summary>
    public bool IsRetryable { get; init; }
}

public class ErrorClassifier
{
    public static ErrorClassification ClassifyBuildError(string buildOutput)
    {
        // Parse dotnet build output

        if (buildOutput.Contains("error CS"))
            return new ErrorClassification
            {
                Type = ErrorType.BUILD_ERROR,
                Code = ExtractErrorCode(buildOutput),
                AutoFixStrategy = "roslyn-patch-and-retry",
                IsRetryable = true
            };

        if (buildOutput.Contains("XDG") || buildOutput.Contains("XLS"))
            return new ErrorClassification
            {
                Type = ErrorType.XAML_ERROR,
                AutoFixStrategy = "xaml-syntax-fix",
                IsRetryable = true
            };

        if (buildOutput.Contains("NU") || buildOutput.Contains("NuGet"))
            return new ErrorClassification
            {
                Type = ErrorType.NUGET_ERROR,
                AutoFixStrategy = "nuget-restore",
                IsRetryable = true
            };

        return new ErrorClassification
        {
            Type = ErrorType.BUILD_ERROR,
            AutoFixStrategy = "unknown-strategy",
            IsRetryable = false
        };
    }

    private static CompilerErrorCode? ExtractErrorCode(string buildOutput)
    {
        var match = System.Text.RegularExpressions.Regex.Match(buildOutput, @"(CS|XDG|XLS|NU|MSB)(\d+)");
        if (match.Success && Enum.TryParse<CompilerErrorCode>(match.Value, out var code))
            return code;
        return null;
    }
}
```

**Key Insight**: Error classification must happen BEFORE retry decision. The orchestrator never retries blindly.

### Build Error Recovery

```csharp
public class BuildErrorRecoveryService
{
    private readonly IAiEngine _aiEngine;
    private readonly IPatchEngine _patchEngine;
    private readonly INugetService _nugetService;
    private readonly IProjectService _projectService;
    private readonly ILogger<BuildErrorRecoveryService> _logger;

    public async Task<RecoveryResult> RecoverFromBuildErrorAsync(BuildError error)
    {
        return error.ErrorType switch
        {
            BuildErrorType.CSharpSyntaxError => await RecoverFromSyntaxErrorAsync(error),
            BuildErrorType.XamlParseError => await RecoverFromXamlErrorAsync(error),
            BuildErrorType.NuGetPackageNotFound => await RecoverFromNuGetErrorAsync(error),
            BuildErrorType.BuildTimeout => await RecoverFromTimeoutAsync(error),
            _ => RecoveryResult.Failed("No recovery strategy available")
        };
    }

    private async Task<RecoveryResult> RecoverFromSyntaxErrorAsync(BuildError error)
    {
        // 1. Extract error context
        var context = await ExtractErrorContextAsync(error);

        // 2. Ask AI to fix
        var fixPrompt = $@"
            The following code has a syntax error:

            File: {error.FilePath}
            Line: {error.LineNumber}
            Error: {error.Message}

            Code context:
            {context}

            Please provide a patch to fix this error.
        ";

        var patch = await _aiEngine.GeneratePatchAsync(fixPrompt);

        // 3. Apply patch
        var result = await _patchEngine.ApplyPatchAsync(patch);

        if (result.Success)
        {
            return RecoveryResult.Success("Syntax error fixed automatically");
        }

        return RecoveryResult.Failed("Unable to fix syntax error automatically");
    }

    private async Task<RecoveryResult> RecoverFromXamlErrorAsync(BuildError error)
    {
        // Extract XAML context and generate fix
        var context = await ExtractErrorContextAsync(error);

        var fixPrompt = $@"
            The following XAML has an error:

            File: {error.FilePath}
            Line: {error.LineNumber}
            Error: {error.Message}

            XAML context:
            {context}

            Please provide corrected XAML.
        ";

        var patch = await _aiEngine.GeneratePatchAsync(fixPrompt);
        var result = await _patchEngine.ApplyPatchAsync(patch);

        return result.Success
            ? RecoveryResult.Success("XAML error fixed automatically")
            : RecoveryResult.Failed("Unable to fix XAML error automatically");
    }

    private async Task<RecoveryResult> RecoverFromNuGetErrorAsync(BuildError error)
    {
        // Extract package name from error message
        var packageName = ExtractPackageName(error.Message);

        // Try to find alternative package version
        var availableVersions = await _nugetService.GetAvailableVersionsAsync(packageName);

        if (availableVersions.Any())
        {
            var latestStable = availableVersions
                .Where(v => !v.IsPrerelease)
                .OrderByDescending(v => v.Version)
                .FirstOrDefault();

            if (latestStable != null)
            {
                // Update package reference
                await _projectService.UpdatePackageVersionAsync(packageName, latestStable.Version);
                return RecoveryResult.Success($"Updated {packageName} to version {latestStable.Version}");
            }
        }

        return RecoveryResult.Failed($"Package {packageName} not found in NuGet");
    }

    private async Task<RecoveryResult> RecoverFromTimeoutAsync(BuildError error)
    {
        // Increase timeout and retry
        _logger.LogWarning("Build timeout detected, increasing timeout and retrying");
        return RecoveryResult.Success("Timeout recovery: increased timeout for retry", new { IncreasedTimeout = true });
    }

    private async Task<string> ExtractErrorContextAsync(BuildError error)
    {
        if (!File.Exists(error.FilePath))
            return string.Empty;

        var lines = await File.ReadAllLinesAsync(error.FilePath);
        var startLine = Math.Max(0, error.LineNumber - 5);
        var endLine = Math.Min(lines.Length - 1, error.LineNumber + 5);

        var contextLines = lines[startLine..endLine];
        return string.Join(Environment.NewLine, contextLines);
    }

    private string ExtractPackageName(string errorMessage)
    {
        // Parse package name from NuGet error message
        // Example: "Unable to find package 'MyPackage'" -> "MyPackage"
        var match = System.Text.RegularExpressions.Regex.Match(
            errorMessage,
            @"package ['""]?([^'""\s]+)['""]?",
            System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        return match.Success ? match.Groups[1].Value : string.Empty;
    }
}

public class RecoveryResult
{
    public bool Success { get; set; }
    public string Message { get; set; }
    public object Data { get; set; }

    public static RecoveryResult Success(string message, object data = null) =>
        new RecoveryResult { Success = true, Message = message, Data = data };

    public static RecoveryResult Failed(string message) =>
        new RecoveryResult { Success = false, Message = message };
}
```

### Snapshot Rollback Service

```csharp
public class SnapshotRollbackService
{
    private readonly ISnapshotRepository _snapshotRepository;
    private readonly IFileSystemSandbox _fileSystemSandbox;
    private readonly ICodeIndexer _codeIndexer;
    private readonly ILogger<SnapshotRollbackService> _logger;

    public async Task<RollbackResult> RollbackToLastGoodStateAsync(string projectId)
    {
        // Find last committed snapshot
        var lastGoodSnapshot = await _snapshotRepository.GetLastCommittedSnapshotAsync(projectId);

        if (lastGoodSnapshot == null)
        {
            return RollbackResult.Failed("No good snapshot found");
        }

        try
        {
            // Restore snapshot
            await _fileSystemSandbox.RestoreSnapshotAsync(projectId, lastGoodSnapshot.FilePath);

            // Re-index files
            await _codeIndexer.IndexProjectAsync(projectId);

            _logger.LogInformation("Rolled back project {ProjectId} to snapshot {SnapshotId}",
                projectId, lastGoodSnapshot.Id);

            return RollbackResult.Success($"Restored to snapshot from {lastGoodSnapshot.CreatedDate}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Rollback failed for project {ProjectId}", projectId);
            return RollbackResult.Failed($"Rollback failed: {ex.Message}");
        }
    }
}

public class RollbackResult
{
    public bool Success { get; set; }
    public string Message { get; set; }
    public string SnapshotId { get; set; }
    public DateTime? SnapshotDate { get; set; }

    public static RollbackResult Success(string message) =>
        new RollbackResult { Success = true, Message = message };

    public static RollbackResult Failed(string message) =>
        new RollbackResult { Success = false, Message = message };
}
```

### Circuit Breaker Pattern

```csharp
public enum CircuitState
{
    Closed,     // Normal operation
    Open,       // Failing, reject all requests
    HalfOpen    // Testing if service recovered
}

public class CircuitBreaker
{
    private int _failureCount;
    private DateTime _lastFailureTime;
    private CircuitState _state = CircuitState.Closed;

    private readonly int _failureThreshold = 5;
    private readonly TimeSpan _timeout = TimeSpan.FromMinutes(1);

    public async Task<T> ExecuteAsync<T>(Func<Task<T>> operation)
    {
        if (_state == CircuitState.Open)
        {
            if (DateTime.UtcNow - _lastFailureTime > _timeout)
            {
                _state = CircuitState.HalfOpen;
            }
            else
            {
                throw new CircuitBreakerOpenException("Circuit breaker is open");
            }
        }

        try
        {
            var result = await operation();

            if (_state == CircuitState.HalfOpen)
            {
                _state = CircuitState.Closed;
                _failureCount = 0;
            }

            return result;
        }
        catch (Exception ex)
        {
            _failureCount++;
            _lastFailureTime = DateTime.UtcNow;

            if (_failureCount >= _failureThreshold)
            {
                _state = CircuitState.Open;
            }

            throw;
        }
    }
}

public class CircuitBreakerOpenException : Exception
{
    public CircuitBreakerOpenException(string message) : base(message) { }
}
```

### Error Analytics & Pattern Detection

```csharp
public class ErrorAnalyticsService
{
    private readonly IErrorRepository _errorRepository;

    public async Task<ErrorStatistics> GetErrorStatisticsAsync(TimeSpan period)
    {
        var since = DateTime.UtcNow - period;

        var errors = await _errorRepository.GetErrorsSinceAsync(since);

        return new ErrorStatistics
        {
            TotalErrors = errors.Count,
            ErrorsByType = errors.GroupBy(e => e.ErrorType)
                .ToDictionary(g => g.Key, g => g.Count()),
            MostCommonError = errors.GroupBy(e => e.ErrorCode)
                .OrderByDescending(g => g.Count())
                .FirstOrDefault()?.Key,
            AverageRecoveryTime = errors
                .Where(e => e.RecoveredAt.HasValue)
                .Average(e => (e.RecoveredAt.Value - e.OccurredAt).TotalSeconds)
        };
    }
}

public class ErrorStatistics
{
    public int TotalErrors { get; set; }
    public Dictionary<ErrorType, int> ErrorsByType { get; set; }
    public string MostCommonError { get; set; }
    public double AverageRecoveryTime { get; set; }
}

public class ErrorPatternDetector
{
    private readonly IErrorRepository _errorRepository;
    private readonly IErrorPatternRepository _errorPatternRepository;

    public async Task DetectPatternsAsync()
    {
        var recentErrors = await _errorRepository.GetRecentErrorsAsync(100);

        // Group by error code - pattern = 3+ occurrences
        var patterns = recentErrors
            .GroupBy(e => e.ErrorCode)
            .Where(g => g.Count() >= 3)
            .Select(g => new ErrorPattern
            {
                ErrorCode = g.Key,
                OccurrenceCount = g.Count(),
                AffectedProjects = g.Select(e => e.ProjectId).Distinct().Count(),
                FirstSeen = g.Min(e => e.Timestamp),
                LastSeen = g.Max(e => e.Timestamp),
                CommonContext = FindCommonContext(g.ToList())
            });

        // Store patterns for AI learning
        foreach (var pattern in patterns)
        {
            await _errorPatternRepository.UpsertAsync(pattern);
        }
    }

    private string FindCommonContext(List<ErrorLog> errors)
    {
        // Analyze common patterns in error context
        var contexts = errors.Select(e => e.Context).Where(c => !string.IsNullOrEmpty(c));
        return contexts.GroupBy(c => c).OrderByDescending(g => g.Count()).FirstOrDefault()?.Key;
    }
}

public class ErrorPattern
{
    public string Id { get; set; }
    public string ErrorCode { get; set; }
    public int OccurrenceCount { get; set; }
    public int AffectedProjects { get; set; }
    public DateTime FirstSeen { get; set; }
    public DateTime LastSeen { get; set; }
    public string CommonContext { get; set; }
}
```

### Logging Infrastructure

```csharp
public class ErrorLogger
{
    private readonly ILogger _logger;
    private readonly IErrorRepository _errorRepository;

    public void LogError(Exception ex, string message, params object[] args)
    {
        // Log to file
        _logger.LogError(ex, message, args);

        // Log to database for analytics
        _errorRepository.AddAsync(new ErrorLog
        {
            Id = Guid.NewGuid().ToString(),
            Timestamp = DateTime.UtcNow,
            Level = "Error",
            Message = string.Format(message, args),
            Exception = ex.ToString(),
            StackTrace = ex.StackTrace
        });
    }

    public void LogWarning(string message, params object[] args)
    {
        _logger.LogWarning(message, args);
    }

    public void LogInfo(string message, params object[] args)
    {
        _logger.LogInformation(message, args);
    }
}

public class ErrorLog
{
    public string Id { get; set; }
    public DateTime Timestamp { get; set; }
    public string Level { get; set; }
    public string Message { get; set; }
    public string Exception { get; set; }
    public string StackTrace { get; set; }
    public string Context { get; set; }
    public string ProjectId { get; set; }
    public string ErrorCode { get; set; }
    public ErrorType? ErrorType { get; set; }
    public DateTime? RecoveredAt { get; set; }
    public DateTime OccurredAt { get; set; }
}

// Structured logging examples with parameter interpolation
// _logger.LogError(
//     "Build failed for project {ProjectId} with error {ErrorCode}: {ErrorMessage}",
//     projectId,
//     errorCode,
//     errorMessage);
//
// Produces:
// [ERROR] Build failed for project abc-123 with error CS0103: The name 'foo' does not exist
```

### User-Facing Error Messages

```csharp
public class ErrorMessageProvider
{
    private readonly Dictionary<BuildErrorType, ErrorMessageTemplate> _buildErrorMessages = new()
    {
        [BuildErrorType.CSharpSyntaxError] = new ErrorMessageTemplate
        {
            Title = "Code Syntax Error",
            Message = "There's a syntax error in the generated code.",
            UserAction = "The system will attempt to fix this automatically. If the problem persists, try rephrasing your prompt.",
            Icon = "Error",
            Severity = ErrorSeverity.Error
        },
        [BuildErrorType.XamlParseError] = new ErrorMessageTemplate
        {
            Title = "XAML Parsing Error",
            Message = "There's an issue with the XAML markup.",
            UserAction = "The system will attempt to fix this automatically.",
            Icon = "Error",
            Severity = ErrorSeverity.Error
        },
        [BuildErrorType.NuGetPackageNotFound] = new ErrorMessageTemplate
        {
            Title = "Package Not Found",
            Message = "A required NuGet package could not be found.",
            UserAction = "The system will try to find an alternative version.",
            Icon = "Warning",
            Severity = ErrorSeverity.Warning
        },
        [BuildErrorType.SdkNotFound] = new ErrorMessageTemplate
        {
            Title = ".NET SDK Required",
            Message = "The .NET 8.0 SDK is not installed on your system.",
            UserAction = "Please download and install the .NET 8.0 SDK from https://dotnet.microsoft.com",
            Icon = "Critical",
            Severity = ErrorSeverity.Critical,
            ActionButton = new ActionButton
            {
                Text = "Download .NET SDK",
                Url = "https://dotnet.microsoft.com/download/dotnet/8.0"
            }
        },
        [BuildErrorType.BuildTimeout] = new ErrorMessageTemplate
        {
            Title = "Build Timeout",
            Message = "The build is taking longer than expected.",
            UserAction = "The system will retry with a longer timeout.",
            Icon = "Warning",
            Severity = ErrorSeverity.Warning
        }
    };

    public ErrorMessageTemplate GetTemplate(BuildErrorType errorType)
    {
        return _buildErrorMessages.TryGetValue(errorType, out var template)
            ? template
            : new ErrorMessageTemplate
            {
                Title = "Build Error",
                Message = "An unexpected error occurred.",
                UserAction = "Please try again.",
                Severity = ErrorSeverity.Error
            };
    }
}

public class ErrorMessageTemplate
{
    public string Title { get; set; }
    public string Message { get; set; }
    public string UserAction { get; set; }
    public string Icon { get; set; }
    public ErrorSeverity Severity { get; set; }
    public ActionButton ActionButton { get; set; }
}

public class ActionButton
{
    public string Text { get; set; }
    public string Url { get; set; }
    public Action OnClick { get; set; }
}
```

### Error Dialog UI (XAML)

```xaml
<ContentDialog x:Name="ErrorDialog"
               Title="{x:Bind ViewModel.ErrorTitle}"
               PrimaryButtonText="{x:Bind ViewModel.PrimaryButtonText}"
               CloseButtonText="Close">
    <StackPanel Spacing="16">
        <!-- Error Icon -->
        <FontIcon Glyph="{x:Bind ViewModel.ErrorIcon}"
                  FontSize="48"
                  Foreground="{x:Bind ViewModel.ErrorColor}"/>

        <!-- Error Message -->
        <TextBlock Text="{x:Bind ViewModel.ErrorMessage}"
                   TextWrapping="Wrap"
                   Style="{StaticResource BodyTextBlockStyle}"/>

        <!-- User Action -->
        <InfoBar Severity="{x:Bind ViewModel.Severity}"
                 IsOpen="True"
                 Title="What to do next"
                 Message="{x:Bind ViewModel.UserAction}"/>

        <!-- Action Button (if applicable) -->
        <HyperlinkButton Content="{x:Bind ViewModel.ActionButtonText}"
                         NavigateUri="{x:Bind ViewModel.ActionButtonUrl}"
                         Visibility="{x:Bind ViewModel.HasActionButton}"/>

        <!-- Technical Details (Expandable) -->
        <Expander Header="Technical Details"
                  IsExpanded="False">
            <ScrollViewer MaxHeight="200">
                <TextBlock Text="{x:Bind ViewModel.TechnicalDetails}"
                           FontFamily="Consolas"
                           FontSize="12"
                           IsTextSelectionEnabled="True"/>
            </ScrollViewer>
        </Expander>
    </StackPanel>
</ContentDialog>
```

### Global Exception Handler

```csharp
public class GlobalExceptionHandler
{
    private readonly ILogger<GlobalExceptionHandler> _logger;

    public void Initialize()
    {
        // Catch unhandled exceptions
        AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
        TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;
        Application.Current.UnhandledException += OnApplicationUnhandledException;
    }

    private void OnUnhandledException(object sender, UnhandledExceptionEventArgs e)
    {
        var ex = e.ExceptionObject as Exception;
        _logger.LogCritical(ex, "Unhandled exception in AppDomain");

        // Show crash dialog
        ShowCrashDialog(ex);

        // Save crash dump
        SaveCrashDump(ex);
    }

    private void OnUnobservedTaskException(object sender, UnobservedTaskExceptionEventArgs e)
    {
        _logger.LogError(e.Exception, "Unobserved task exception");

        // Mark as observed to prevent crash
        e.SetObserved();
    }

    private void OnApplicationUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        _logger.LogError(e.Exception, "Unhandled UI exception");

        // Mark as handled to prevent crash
        e.Handled = true;

        // Show error dialog
        ShowErrorDialog(e.Exception);
    }

    private async void ShowCrashDialog(Exception ex)
    {
        var dialog = new ContentDialog
        {
            Title = "Application Error",
            Content = "The application encountered an unexpected error and needs to close.\n\n" +
                     "Error details have been saved to the log file.",
            CloseButtonText = "Close Application"
        };

        await dialog.ShowAsync();
        Application.Current.Exit();
    }

    private async void ShowErrorDialog(Exception ex)
    {
        var dialog = new ContentDialog
        {
            Title = "Unexpected Error",
            Content = $"An error occurred: {ex.Message}\n\nThe application will continue running.",
            CloseButtonText = "OK"
        };

        await dialog.ShowAsync();
    }

    private void SaveCrashDump(Exception ex)
    {
        var crashLogPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "SyncAIAppBuilder",
            "crash_logs",
            $"crash_{DateTime.UtcNow:yyyyMMdd_HHmmss}.log");

        Directory.CreateDirectory(Path.GetDirectoryName(crashLogPath));

        File.WriteAllText(crashLogPath, $@"
=== CRASH LOG ===
Timestamp: {DateTime.UtcNow}
Version: {GetType().Assembly.GetName().Version}

Exception: {ex.GetType().Name}
Message: {ex.Message}
StackTrace:
{ex.StackTrace}

Inner Exception: {ex.InnerException?.Message}
Inner StackTrace:
{ex.InnerException?.StackTrace}
");
    }
}
```

### Error Prevention (Input Validation)

```csharp
public class InputValidator
{
    public ValidationResult ValidatePrompt(string prompt)
    {
        if (string.IsNullOrWhiteSpace(prompt))
            return ValidationResult.Error("Prompt cannot be empty");

        if (prompt.Length < 10)
            return ValidationResult.Warning("Prompt is very short. Consider adding more details.");

        if (prompt.Length > 10000)
            return ValidationResult.Error("Prompt is too long. Maximum 10,000 characters.");

        return ValidationResult.Success();
    }

    public ValidationResult ValidateProjectName(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
            return ValidationResult.Error("Project name cannot be empty");

        var invalidChars = Path.GetInvalidFileNameChars();
        if (name.Any(c => invalidChars.Contains(c)))
            return ValidationResult.Error("Project name contains invalid characters");

        return ValidationResult.Success();
    }
}

public class PreconditionChecker
{
    private readonly ISdkManager _sdkManager;
    private readonly ILogger<PreconditionChecker> _logger;

    public async Task<PreconditionResult> CheckBuildPreconditionsAsync(string projectPath)
    {
        var issues = new List<string>();

        // Check SDK
        var sdkValidation = await _sdkManager.ValidateSdkAsync();
        if (!sdkValidation.IsValid)
            issues.Add(sdkValidation.ErrorMessage);

        // Check disk space
        var driveInfo = new DriveInfo(Path.GetPathRoot(projectPath));
        if (driveInfo.AvailableFreeSpace < 1_000_000_000) // 1 GB
            issues.Add("Low disk space. At least 1 GB free space recommended.");

        // Check file locks
        var lockedFiles = await FindLockedFilesAsync(projectPath);
        if (lockedFiles.Any())
            issues.Add($"Files are locked: {string.Join(", ", lockedFiles)}");

        return issues.Any()
            ? PreconditionResult.Failed(issues)
            : PreconditionResult.Success();
    }

    private async Task<List<string>> FindLockedFilesAsync(string projectPath)
    {
        var lockedFiles = new List<string>();
        var projectDir = Path.GetDirectoryName(projectPath);

        foreach (var file in Directory.GetFiles(projectDir, "*.*", SearchOption.AllDirectories))
        {
            try
            {
                using var stream = File.Open(file, FileMode.Open, FileAccess.ReadWrite, FileShare.None);
            }
            catch (IOException)
            {
                lockedFiles.Add(file);
            }
        }

        return lockedFiles;
    }
}

public class PreconditionResult
{
    public bool Success { get; set; }
    public List<string> Issues { get; set; } = new();

    public static PreconditionResult Success() => new() { Success = true };
    public static PreconditionResult Failed(List<string> issues) => new() { Success = false, Issues = issues };
}
```

---

## 10. API Contracts

### Internal Service Interfaces

#### Orchestrator Service (`IOrchestrator`)

```csharp
public interface IOrchestrator
{
    Task<BuilderState> DispatchAsync(BuilderEvent @event);
    Task<TaskResult> ExecuteTaskAsync(TaskDefinition task);
    BuilderContext GetCurrentContext();
}
```

#### Code Intelligence Service (`IRoslynService`)

```csharp
public interface IRoslynService
{
    Task<ProjectGraph> IndexProjectAsync(string path);
    Task<List<Symbol>> FindUsagesAsync(ISymbol symbol);
    Task<SemanticModel> GetSemanticModelAsync(string filePath);
}
```

#### Patch Engine (`IPatchEngine`)

```csharp
public interface IPatchEngine
{
    Task<string> ApplyPatchAsync(string filePath, PatchDefinition patch);
    Task<bool> ValidatePatchAsync(string filePath, PatchDefinition patch);
}
```

#### Execution Kernel (`IExecutionKernel`)

```csharp
public interface IExecutionKernel
{
    Task<BuildResult> BuildAsync(string projectPath);
    Task<TestResult> RunTestsAsync(string projectPath);
    Task<ExecutionResult> RunAppAsync(string projectPath);
}
```

### Data Transfer Objects

#### TaskDefinition

```csharp
public class TaskDefinition
{
    public string Id { get; set; }
    public TaskType Type { get; set; }
    public string Description { get; set; }
    public List<string> TargetFiles { get; set; }
    public Dictionary<string, object> Parameters { get; set; }
}
```

#### TaskResult

```csharp
public class TaskResult
{
    public bool Success { get; set; }
    public string TaskId { get; set; }
    public string ErrorMessage { get; set; }
    public object Data { get; set; }
}
```

#### Symbol and SymbolKind

```csharp
public class Symbol
{
    public string Name { get; set; }
    public string FullyQualifiedName { get; set; }
    public SymbolKind Kind { get; set; }
    public string FilePath { get; set; }
    public int LineNumber { get; set; }
    public int ColumnNumber { get; set; }
}

public enum SymbolKind
{
    Class,
    Interface,
    Method,
    Property,
    Field,
    Event,
    Namespace
}
```

#### PatchDefinition and PatchAction

```csharp
public class PatchDefinition
{
    public string FilePath { get; set; }
    public PatchAction Action { get; set; }
    public string TargetSymbol { get; set; }
    public string Content { get; set; }
    public Dictionary<string, object> Metadata { get; set; }
}

public enum PatchAction
{
    ADD_CLASS,
    ADD_METHOD,
    ADD_PROPERTY,
    ADD_FIELD,
    MODIFY_METHOD_BODY,
    MODIFY_PROPERTY,
    INSERT_USING,
    REMOVE_MEMBER,
    UPDATE_XAML_NODE,
    ADD_XAML_ELEMENT,
    MODIFY_XAML_ATTRIBUTE
}
```

#### TestResult, TestFailure, and ExecutionResult

```csharp
public class TestResult
{
    public bool Success { get; set; }
    public int TotalTests { get; set; }
    public int PassedTests { get; set; }
    public int FailedTests { get; set; }
    public List<TestFailure> Failures { get; set; }
    public TimeSpan Duration { get; set; }
}

public class TestFailure
{
    public string TestName { get; set; }
    public string ErrorMessage { get; set; }
    public string StackTrace { get; set; }
}

public class ExecutionResult
{
    public bool Success { get; set; }
    public int ExitCode { get; set; }
    public string StandardOutput { get; set; }
    public string StandardError { get; set; }
    public TimeSpan Duration { get; set; }
}
```

#### ProjectGraph and SourceFile

```csharp
public class ProjectGraph
{
    public string ProjectId { get; set; }
    public string ProjectPath { get; set; }
    public List<SourceFile> SourceFiles { get; set; }
    public List<Symbol> Symbols { get; set; }
    public Dictionary<string, List<string>> Dependencies { get; set; }
}

public class SourceFile
{
    public string FilePath { get; set; }
    public string Content { get; set; }
    public List<Symbol> Symbols { get; set; }
    public DateTime LastModified { get; set; }
}
```

### AI Engine Output Contracts (JSON Schemas)

#### Project Specification Contract

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "projectId": { "type": "string" },
    "projectName": { "type": "string" },
    "stack": {
      "type": "object",
      "properties": {
        "ui": { "enum": ["WinUI3", "WPF", "Console"] },
        "language": { "const": "C#" },
        "framework": { "const": ".NET 8.0" },
        "database": { "enum": ["SQLite", "None"] }
      },
      "required": ["ui", "language", "framework"]
    },
    "features": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "type": { "type": "string" },
          "description": { "type": "string" },
          "dependencies": { "type": "array", "items": { "type": "string" } }
        },
        "required": ["id", "type", "description"]
      }
    }
  },
  "required": ["projectId", "projectName", "stack", "features"]
}
```

#### Task Graph Contract

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "tasks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "type": { "enum": ["INFRASTRUCTURE", "MODEL", "SERVICE", "UI", "INTEGRATION", "FIX"] },
          "description": { "type": "string" },
          "targetFiles": { "type": "array", "items": { "type": "string" } },
          "dependencies": { "type": "array", "items": { "type": "string" } },
          "validationStrategy": { "enum": ["COMPILE", "UNIT_TEST", "XAML_PARSE"] }
        },
        "required": ["id", "type", "description", "targetFiles", "dependencies"]
      }
    }
  },
  "required": ["tasks"]
}
```

#### Patch Engine Contract

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "filePatches": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "path": { "type": "string" },
          "changes": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "action": {
                  "enum": [
                    "ADD_CLASS",
                    "ADD_METHOD",
                    "ADD_PROPERTY",
                    "ADD_FIELD",
                    "MODIFY_METHOD_BODY",
                    "MODIFY_PROPERTY",
                    "INSERT_USING",
                    "REMOVE_MEMBER",
                    "UPDATE_XAML_NODE",
                    "ADD_XAML_ELEMENT",
                    "MODIFY_XAML_ATTRIBUTE"
                  ]
                },
                "targetSymbol": { "type": "string" },
                "content": { "type": "string" }
              },
              "required": ["action", "content"]
            }
          }
        },
        "required": ["path", "changes"]
      }
    }
  },
  "required": ["filePatches"]
}
```

### Validation Rules

1. **Schema Check**: All AI Engine responses must pass JSON Schema validation
2. **Path Resolution**: Files referenced in tasks must exist or be marked for creation
3. **Dependency Integrity**: Task graph must be acyclic (DAG)
4. **Symbol Existence**: Patches targeting existing symbols must verify via Code Intelligence Layer

### Detailed Build Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│ 1. Task Starts                                          │
│    - Receive BuildTask from Orchestrator                │
│    - Validate workspace path                            │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 2. Snapshot Workspace                                   │
│    - Create ZIP snapshot of current state               │
│    - Store in .builder/snapshots/                       │
│    - Record timestamp and task ID                       │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 3. Apply Patch (if any)                                 │
│    - Receive code changes from Roslyn engine            │
│    - Apply to workspace files                           │
│    - Validate file integrity                            │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 4. Clean Workspace                                      │
│    - Delete bin/ and obj/ directories                   │
│    - Reset ProjectCollection context                    │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 5. Execute In-Process Build (Microsoft.Build)           │
│    - Load Project (ProjectCollection.LoadProject)       │
│    - Create Logger (StructuredLogger)                   │
│    - Run Target: "Restore;Build"                        │
│    - Timeout: 60-120 seconds                            │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 6. Process Build Result                                 │
│    - Retrieve structured errors from Logger             │
│    - Classify error types (CS, NU, MSB)                 │
│    - Generate BuildResult object                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ├─── SUCCESS ───┐
                     │                │
                     │                ▼
                     │    ┌───────────────────────────┐
                     │    │ 7a. Commit Snapshot       │
                     │    │    - Mark as successful   │
                     │    │    - Update state.json    │
                     │    └───────────────────────────┘
                     │
                     └─── FAILURE ───┐
                                     │
                                     ▼
                         ┌───────────────────────────┐
                         │ 7b. Classify Error        │
                         │    - Determine error type │
                         │    - Return to Orchestrator│
                         │    - Keep snapshot        │
                         └───────────────────────────┘
```

---

## 11. Implementation Sequence

### Phase 1A: Foundation (Mandatory before any other work)

1. ✅ Define `TaskType`, `ValidationStrategy`, `TaskStatus`, `ErrorType` enums
2. ✅ Define `Task` class (immutable where possible)
3. ✅ Define `BuilderState` enum
4. ✅ Define `BuilderContext` class
5. ✅ Define event record types
6. ✅ Implement `BuilderReducer.Reduce()` (pure function)

### Phase 1B: Orchestrator Control

7. ✅ Implement `RetryController` (budget tracking)
8. ✅ Implement `ConcurrencyPolicy` (no parallel mutations)
9. ✅ Implement `ErrorClassifier` (error categorization)

### Phase 2: Integration Points

- Planning Service → emits `TaskCompletedEvent` to orchestrator
- Roslyn Patch Engine → asks orchestrator before patching
- Build Validator → reports errors to orchestrator
- Fix Engine → respects orchestrator state machine

### Phase 3: Testing

- Unit tests for reducer (determinism)
- Integration tests for state transitions
- Replay tests (event log → identical state)

### Testing Strategy & Examples

#### Integration Tests (Kernel Level)

Since `BuildManager` is a static singleton, we test `BuildService` via integration tests with a real project on disk.

```csharp
[TestClass]
public class BuildServiceIntegrationTests
{
    private BuildService _buildService;
    private string _testWorkspace;

    [TestInitialize]
    public void Setup()
    {
        _testWorkspace = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(_testWorkspace);
        _buildService = new BuildService(new NullLogger<BuildService>());
    }

    [TestCleanup]
    public void Cleanup()
    {
        if (Directory.Exists(_testWorkspace))
            Directory.Delete(_testWorkspace, recursive: true);
    }

    [TestMethod]
    public async Task BuildAsync_ValidProject_ReturnsSuccess()
    {
        // Arrange
        var projectPath = CreateValidProject(_testWorkspace);

        // Act
        var result = await _buildService.BuildAsync(projectPath);

        // Assert
        Assert.IsTrue(result.Success);
        Assert.AreEqual(0, result.Errors.Count);
    }

    [TestMethod]
    public async Task BuildAsync_ProjectWithSyntaxError_ReturnsFailure()
    {
        // Arrange
        var projectPath = CreateProjectWithSyntaxError(_testWorkspace);

        // Act
        var result = await _buildService.BuildAsync(projectPath);

        // Assert
        Assert.IsFalse(result.Success);
        Assert.AreEqual(ErrorType.CSharpCompiler, result.ErrorType);
    }

    private string CreateValidProject(string workspace)
    {
        // Create a minimal valid .csproj and Program.cs
        var projectPath = Path.Combine(workspace, "TestProject.csproj");
        File.WriteAllText(projectPath, @"
<Project Sdk=""Microsoft.NET.Sdk"">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>");

        File.WriteAllText(Path.Combine(workspace, "Program.cs"),
            "Console.WriteLine(\"Hello, World!\");");

        return projectPath;
    }

    private string CreateProjectWithSyntaxError(string workspace)
    {
        var projectPath = CreateValidProject(workspace);
        File.WriteAllText(Path.Combine(workspace, "Program.cs"),
            "Console.WriteLine(\"Missing semicolon\""); // Missing closing paren and semicolon
        return projectPath;
    }
}
```

#### Unit Tests (Consumer Level)

Consumers of `IBuildService` (like Orchestrator) should mock the interface.

```csharp
[TestClass]
public class OrchestratorUnitTests
{
    [TestMethod]
    public async Task Orchestrator_HandlesBuildFailure_Correctly()
    {
        // Arrange
        var mockBuild = new Mock<IBuildService>();
        mockBuild.Setup(b => b.BuildAsync(It.IsAny<string>(), null, default))
                 .ReturnsAsync(new BuildResult
                 {
                     Success = false,
                     ErrorType = ErrorType.CSharpCompiler,
                     ErrorMessage = "CS1002: ; expected"
                 });

        var orchestrator = new Orchestrator(mockBuild.Object);

        // Act
        await orchestrator.RunTaskAsync(new BuildTask());

        // Assert
        mockBuild.Verify(b => b.BuildAsync(It.IsAny<string>(), null, default), Times.Once);
        // Verify remediation logic triggered
    }

    [TestMethod]
    public async Task Orchestrator_RetriesOnRetryableError()
    {
        // Arrange
        var mockBuild = new Mock<IBuildService>();
        var callCount = 0;

        mockBuild.Setup(b => b.BuildAsync(It.IsAny<string>(), null, default))
                 .ReturnsAsync(() =>
                 {
                     callCount++;
                     return callCount < 3
                         ? new BuildResult { Success = false, ErrorType = ErrorType.CSharpCompiler }
                         : new BuildResult { Success = true };
                 });

        var orchestrator = new Orchestrator(mockBuild.Object);

        // Act
        await orchestrator.RunTaskAsync(new BuildTask());

        // Assert
        Assert.AreEqual(3, callCount); // Initial + 2 retries
    }
}
```

---

> **Status**: 🔴 CRITICAL PATH FIRST IMPLEMENTATION
> **Complexity**: Medium (state machine fundamentals)
> **Risk**: HIGH if skipped (foundation for everything else)

---

## Design Philosophy Connection

This orchestrator implements the **"hide complexity, show results"** principle at the system level:

- **Hidden Complexity**: Full task graph, retry loops, error classification all internal
- **Shown Results**: User sees progress indicator + final working app
- **Error Handling**: All failures self-corrected before user sees them
- **Determinism**: Invisibly perfect replay makes system feel magical

**Without deterministic orchestrator:**

- Roslyn patch engine can produce cascading corruption
- Retry loops become nondeterministic
- Memory layer tracking becomes unreliable
- State debugging becomes impossible
- Silent error fixing can perpetuate failures

**With deterministic orchestrator:**

- Every state transition is logged
- Every retry is budgeted and tracked
- Every error is classified before retry decision
- System is replayable for debugging
- Users get consistent, reproducible results

---

## Next Deliverables (In Order)

Once orchestrator is confirmed:

1. **SQLite Schema** — Table design for project graph, memory layer, audit log
2. **Roslyn Indexing Architecture** — AST-based code intelligence indexing
3. **Patch Engine Contract** — API contract for Roslyn-based mutation
4. **Agent Contract** — How agents interact with orchestrator
5. **Intent Parser** — User → structured specification

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 7-layer overview, deployment model
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn, indexing, DB schema, mutation safety
- [UI_IMPLEMENTATION.md](./UI_IMPLEMENTATION.md) — Error UI components
- [PREVIEW_SYSTEM.md](./PREVIEW_SYSTEM.md) — Preview rendering
