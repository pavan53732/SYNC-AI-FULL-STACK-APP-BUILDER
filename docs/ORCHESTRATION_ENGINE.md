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
public enum BuilderState
{
    IDLE = 0,                // Awaiting user action or spec
    SPEC_PARSING = 1,        // User intent → structured spec
    SPEC_PARSED = 2,         // Spec validated, ready for planning
    TASK_GRAPH_BUILDING = 3, // Planning service creating DAG
    TASK_GRAPH_BUILT = 4,    // Task DAG complete, ready to execute
    // Execution Breakdown
    MUTATION_GUARD = 5,      // Pre-execution safety check (Impact/Breaking Change)
    PATCHING = 6,            // Roslyn AST transformation
    INDEXING = 7,            // Updating semantic graph post-patch
    BUILDING = 8,            // MSBuild / Dotnet CLI execution
    // Validation & Result
    VALIDATING = 9,          // Final integrity check
    RETRYING = 10,           // Retry in progress
    BUILD_SUCCEEDED = 11,    // All tasks completed
    BUILD_FAILED = 12        // Unrecoverable failure
}
```

### State Diagram

```
IDLE
  ↓ (spec arrives)
SPEC_PARSING
  ↓ (spec valid)
SPEC_PARSED
  ↓ (plan generated)
TASK_GRAPH_BUILDING
  ↓ (DAG complete)
TASK_GRAPH_BUILT
  ↓ (execute next task)
MUTATION_GUARD
  ↓ (guard safe)
PATCHING
  ↓ (patch applied)
INDEXING
  ↓ (index updated)
BUILDING
  ↓ (build complete)
VALIDATING
  ↓ (validation succeeds)    ↓ (validation fails)
BUILD_SUCCEEDED            RETRYING
                              ↓ (retry < maxRetries)
                           EXECUTING_TASK
                              ↓ (retry >= maxRetries)
                           BUILD_FAILED
```

---

## 4. State Container & Event Log

### BuilderContext (Single Source of Truth)

```csharp
public class BuilderContext
{
    public BuilderState State { get; set; }

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
            (BuilderState.IDLE, SpecParsedEvent e) => context with
            {
                State = BuilderState.SPEC_PARSED,
                EventLog = [..context.EventLog, @event]
            },

            // === TASK GRAPH BUILDING ===
            (BuilderState.SPEC_PARSED, var e) when @event is TaskStartedEvent te && te.TaskId == "graph-builder" =>
                context with { State = BuilderState.TASK_GRAPH_BUILDING, EventLog = [..context.EventLog, @event] },

            (BuilderState.TASK_GRAPH_BUILDING, var e) when @event is TaskCompletedEvent te && te.TaskId == "graph-builder" =>
                context with { State = BuilderState.TASK_GRAPH_BUILT, EventLog = [..context.EventLog, @event] },

            // === TASK EXECUTION PHASES ===
            (BuilderState.TASK_GRAPH_BUILT, TaskStartedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.MUTATION_GUARD, @event),

            (BuilderState.MUTATION_GUARD, TaskGuardPassedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.PATCHING, @event),

            (BuilderState.PATCHING, TaskPatchedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.INDEXING, @event),

            (BuilderState.INDEXING, TaskIndexedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.BUILDING, @event),

            (BuilderState.BUILDING, TaskValidatingEvent e) =>
                context with { State = BuilderState.VALIDATING, EventLog = [..context.EventLog, @event] },

            // === SUCCESS PATH ===
            (BuilderState.VALIDATING, TaskCompletedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.TASK_GRAPH_BUILT, @event),

            // === FAILURE & RETRY PATH ===
            (BuilderState.VALIDATING, TaskFailedEvent e) when e.CurrentRetry < e.MaxRetries =>
                context with { State = BuilderState.RETRYING, EventLog = [..context.EventLog, @event] },

            (BuilderState.RETRYING, TaskStartedEvent e) =>
                context with { State = BuilderState.EXECUTING_TASK, EventLog = [..context.EventLog, @event] },

            (BuilderState.VALIDATING, TaskFailedEvent e) when e.CurrentRetry >= e.MaxRetries =>
                context with { State = BuilderState.BUILD_FAILED, EventLog = [..context.EventLog, @event] },

            // === COMPLETION ===
            (BuilderState.TASK_GRAPH_BUILT, BuildCompletedEvent e) =>
                context with { State = BuilderState.BUILD_SUCCEEDED, EventLog = [..context.EventLog, @event] },

            // === INVALID TRANSITION ===
            _ => throw new InvalidOperationException(
                $"Invalid transition: {context.State} + {(@event.GetType().Name)} not allowed")
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
            State = BuilderState.RETRYING,
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

    public static void ValidateConcurrency(
        BuilderContext context,
        Task incomingTask)
    {
        if (context.State == BuilderState.EXECUTING_TASK && IsMutationTask(incomingTask.Type))
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
    CSharpSyntaxError,              // CS1001-CS1999
    CSharpSemanticError,            // CS0001-CS0999
    XamlParseError,                 // XDG0001-XDG0999
    XamlBindingError,               // XDG1000-XDG1999
    NuGetPackageNotFound,           // NU1101
    NuGetVersionConflict,           // NU1107
    MSBuildProjectFileError,        // MSB4000-MSB4999
    SdkNotFound,
    BuildTimeout,
    UnknownBuildError
}

// AI Engine Errors
public enum AIErrorType
{
    ApiKeyMissing, ApiKeyInvalid, ApiRateLimitExceeded,
    ApiQuotaExceeded, ApiNetworkError, ApiTimeout,
    InvalidJsonResponse, SchemaValidationFailed, EmptyResponse,
    TokenLimitExceeded, ModelNotAvailable, UnknownAIError
}

// File System Errors
public enum FileSystemErrorType
{
    PathNotFound, AccessDenied, DiskFull, FileInUse,
    SnapshotCreationFailed, SnapshotRestoreFailed, UnknownFileSystemError
}

// Roslyn/Patch Errors
public enum PatchErrorType
{
    TargetNotFound, SignatureMismatch, FileHashMismatch,
    SyntaxError, DuplicateMember, ConflictDetected, UnknownPatchError
}

// Orchestrator Errors
public enum OrchestratorErrorType
{
    InvalidStateTransition, TaskExecutionFailed, RetryBudgetExceeded,
    DependencyFailed, TimeoutExceeded, CancellationRequested
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

### Build Error Recovery

```csharp
public class BuildErrorRecoveryService
{
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
        var patch = await _aiEngine.GeneratePatchAsync(
            $"Fix syntax error at {error.FilePath}:{error.LineNumber} - {error.Message}");

        // 3. Apply patch
        var result = await _patchEngine.ApplyPatchAsync(patch);
        return result.Success
            ? RecoveryResult.Success("Syntax error fixed automatically")
            : RecoveryResult.Failed("Unable to fix syntax error automatically");
    }
}
```

### Circuit Breaker Pattern

```csharp
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
                _state = CircuitState.HalfOpen;
            else
                throw new CircuitBreakerOpenException("Circuit breaker is open");
        }

        try
        {
            var result = await operation();
            if (_state == CircuitState.HalfOpen) { _state = CircuitState.Closed; _failureCount = 0; }
            return result;
        }
        catch (Exception)
        {
            _failureCount++;
            _lastFailureTime = DateTime.UtcNow;
            if (_failureCount >= _failureThreshold) _state = CircuitState.Open;
            throw;
        }
    }
}
```

### User-Facing Error Messages

```csharp
public class ErrorMessageProvider
{
    private readonly Dictionary<BuildErrorType, ErrorMessageTemplate> _messages = new()
    {
        [BuildErrorType.CSharpSyntaxError] = new()
        {
            Title = "Code Syntax Error",
            Message = "There's a syntax error in the generated code.",
            UserAction = "The system will attempt to fix this automatically.",
            Severity = ErrorSeverity.Error
        },
        [BuildErrorType.SdkNotFound] = new()
        {
            Title = ".NET SDK Required",
            Message = "The .NET 8.0 SDK is not installed on your system.",
            UserAction = "Please download and install the .NET 8.0 SDK.",
            Severity = ErrorSeverity.Critical
        },
        [BuildErrorType.BuildTimeout] = new()
        {
            Title = "Build Timeout",
            Message = "The build is taking longer than expected.",
            UserAction = "The system will retry with a longer timeout.",
            Severity = ErrorSeverity.Warning
        }
    };
}
```

### Global Exception Handler

```csharp
public class GlobalExceptionHandler
{
    public void Initialize()
    {
        AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
        TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;
        Application.Current.UnhandledException += OnApplicationUnhandledException;
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
        if (prompt.Length > 10000)
            return ValidationResult.Error("Prompt is too long. Maximum 10,000 characters.");
        return ValidationResult.Success();
    }
}

public class PreconditionChecker
{
    public async Task<PreconditionResult> CheckBuildPreconditionsAsync(string projectPath)
    {
        var issues = new List<string>();
        // Check SDK, disk space, file locks...
        return issues.Any()
            ? PreconditionResult.Failed(issues)
            : PreconditionResult.Success();
    }
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

### AI Engine Output Contracts (JSON Schemas)

#### Project Specification Contract

```json
{
  "type": "object",
  "properties": {
    "projectId": { "type": "string" },
    "projectName": { "type": "string" },
    "stack": {
      "type": "object",
      "properties": {
        "ui": { "enum": ["WinUI3", "WPF", "Console"] },
        "language": { "const": "C#" },
        "framework": { "const": ".NET 8.0" }
      }
    },
    "features": {
      "type": "array",
      "items": {
        "properties": { "id": {}, "type": {}, "description": {}, "dependencies": {} }
      }
    }
  },
  "required": ["projectId", "projectName", "stack", "features"]
}
```

#### Task Graph Contract

```json
{
  "type": "object",
  "properties": {
    "tasks": {
      "type": "array",
      "items": {
        "properties": {
          "id": { "type": "string" },
          "type": { "enum": ["INFRASTRUCTURE", "MODEL", "SERVICE", "UI", "INTEGRATION", "FIX"] },
          "description": { "type": "string" },
          "targetFiles": { "type": "array" },
          "dependencies": { "type": "array" },
          "validationStrategy": { "enum": ["COMPILE", "UNIT_TEST", "XAML_PARSE"] }
        }
      }
    }
  }
}
```

#### Patch Engine Contract

```json
{
  "type": "object",
  "properties": {
    "filePatches": {
      "type": "array",
      "items": {
        "properties": {
          "path": { "type": "string" },
          "changes": {
            "type": "array",
            "items": {
              "properties": {
                "action": {
                  "enum": [
                    "ADD_CLASS",
                    "ADD_METHOD",
                    "MODIFY_METHOD_BODY",
                    "INSERT_USING",
                    "UPDATE_XAML_NODE"
                  ]
                },
                "targetSymbol": { "type": "string" },
                "content": { "type": "string" }
              }
            }
          }
        }
      }
    }
  }
}
```

### Validation Rules

1. **Schema Check**: All AI Engine responses must pass JSON Schema validation
2. **Path Resolution**: Files referenced in tasks must exist or be marked for creation
3. **Dependency Integrity**: Task graph must be acyclic (DAG)
4. **Symbol Existence**: Patches targeting existing symbols must verify via Code Intelligence Layer

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

---

> **Status**: 🔴 CRITICAL PATH FIRST IMPLEMENTATION
> **Complexity**: Medium (state machine fundamentals)
> **Risk**: HIGH if skipped (foundation for everything else)

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 7-layer overview, deployment model
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn, indexing, DB schema, mutation safety
- [UI_IMPLEMENTATION.md](./UI_IMPLEMENTATION.md) — Error UI components
- [PREVIEW_SYSTEM.md](./PREVIEW_SYSTEM.md) — Preview rendering
