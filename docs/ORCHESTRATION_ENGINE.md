# ORCHESTRATION ENGINE

> **The Logic Brain: State Machine, Task Lifecycle, Build System, Retry Logic & Concurrency Safety**
>
> _Merged from: ORCHESTRATOR_SPECIFICATION.md, BUILD_SYSTEM_SPECIFICATION.md, ERROR_HANDLING_SPECIFICATION.md, API_CONTRACTS.md_
>
> **Status**: Strict Consolidation (No architectural expansion)

---

## Table of Contents

1. [Core Challenge & Positioning](#1-core-challenge--positioning)
2. [Task Schema](#2-task-schema)
3. [State Machine](#3-state-machine)
4. [State Container & Event Log](#4-state-container--event-log)
5. [State Reducer](#5-state-reducer)
6. [Error Classification & Intelligence](#6-error-classification--intelligence)
7. [Retry Controller](#7-retry-controller)
8. [Concurrency Rules](#8-concurrency-rules)
9. [Validation Layer](#9-validation-layer)
10. [Build System](#10-build-system)
11. [Error Handling](#11-error-handling)
12. [API Contracts](#12-api-contracts)

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
- **Orchestrator updates UI**: The orchestrator pushes state changes to the UI; the kernel never signals the UI directly.

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

### Task Types (Strict Contract)

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
PATCHING ←────────────────┐
  ↓ (patch applied)       │
INDEXING                  │
  ↓ (index updated)       │
BUILDING                  │
  ↓ (build complete)      │
VALIDATING                │ (retry < maxRetries)
  ↓ (validation succeeds) └── RETRYING
BUILD_SUCCEEDED               ↓ (retry < maxRetries)
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
public record TaskStartedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public TaskType TaskType { get; init; }
}

public record TaskGuardPassedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public string ImpactAnalysis { get; init; }
}

public record TaskPatchedEvent : BuilderEvent // Replaces TaskExecutedEvent
{
    public string TaskId { get; init; }
    public List<string> ModifiedFiles { get; init; }
}

public record TaskIndexedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public int NodesIndexed { get; init; }
}

public record TaskValidatingEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public ValidationStrategy Strategy { get; init; }
}

public record TaskCompletedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public TimeSpan Duration { get; init; }
}

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
public record BuildCompletedEvent : BuilderEvent
{
    public int TasksCompleted { get; init; }
    public TimeSpan TotalDuration { get; init; }
    public List<string> GeneratedFiles { get; init; }
}

public record BuildFailedEvent : BuilderEvent
{
    public string FailureReason { get; init; }
    public string TaskIdThatFailed { get; init; }
}

public record RetryStartedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public int CurrentRetry { get; init; }
    public ErrorType PreviousError { get; init; }
}
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
                EventLog = [..context.EventLog, @event],
                ProjectMetadata = e.ExtractedFeatures.ToDictionary(f => f, f => (object)true)
            },

            // === TASK GRAPH BUILDING ===
            (BuilderState.SPEC_PARSED, var e) when @event is TaskStartedEvent te && te.TaskId == "graph-builder" =>
                context with
                {
                    State = BuilderState.TASK_GRAPH_BUILDING,
                    EventLog = [..context.EventLog, @event]
                },

            (BuilderState.TASK_GRAPH_BUILDING, var e) when @event is TaskCompletedEvent te && te.TaskId == "graph-builder" =>
                context with
                {
                    State = BuilderState.TASK_GRAPH_BUILT,
                    EventLog = [..context.EventLog, @event]
                },

            // === TASK EXECUTION & PHASES ===
            (BuilderState.TASK_GRAPH_BUILT, TaskStartedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.MUTATION_GUARD, @event),

            (BuilderState.MUTATION_GUARD, TaskGuardPassedEvent e) =>
                 UpdateTaskAndTransition(context, e.TaskId, BuilderState.PATCHING, @event),

            (BuilderState.PATCHING, TaskPatchedEvent e) =>
                 UpdateTaskAndTransition(context, e.TaskId, BuilderState.INDEXING, @event),

            (BuilderState.INDEXING, TaskIndexedEvent e) =>
                 UpdateTaskAndTransition(context, e.TaskId, BuilderState.BUILDING, @event),

            (BuilderState.BUILDING, TaskValidatingEvent e) =>
                context with
                {
                    State = BuilderState.VALIDATING,
                    EventLog = [..context.EventLog, @event]
                },

            // === SUCCESS PATH ===
            (BuilderState.VALIDATING, TaskCompletedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.TASK_GRAPH_BUILT, @event),

            // === FAILURE & RETRY PATH ===
            (BuilderState.VALIDATING, TaskFailedEvent e) when e.CurrentRetry < e.MaxRetries =>
                context with
                {
                    State = BuilderState.RETRYING,
                    EventLog = [..context.EventLog, @event]
                },

            (BuilderState.RETRYING, TaskStartedEvent e) =>
                context with
                {
                    State = BuilderState.EXECUTING_TASK,
                    EventLog = [..context.EventLog, @event]
                },

            (BuilderState.VALIDATING, TaskFailedEvent e) when e.CurrentRetry >= e.MaxRetries =>
                context with
                {
                    State = BuilderState.BUILD_FAILED,
                    EventLog = [..context.EventLog, @event]
                },

            // === COMPLETION ===
            (BuilderState.TASK_GRAPH_BUILT, BuildCompletedEvent e) =>
                context with
                {
                    State = BuilderState.BUILD_SUCCEEDED,
                    EventLog = [..context.EventLog, @event]
                },

            // === INVALID TRANSITION ===
            _ => throw new InvalidOperationException(
                $"Invalid transition: {context.State} + {(@event.GetType().Name)} not allowed")
        };
    }

    private static BuilderContext UpdateTaskAndTransition(
        BuilderContext context,
        string taskId,
        BuilderState newState,
        BuilderEvent @event)
    {
        if (context.TaskMap.TryGetValue(taskId, out var task))
        {
            task.Status = newState switch
            {
                BuilderState.MUTATION_GUARD => TaskStatus.RUNNING,
                BuilderState.PATCHING => TaskStatus.RUNNING,
                BuilderState.INDEXING => TaskStatus.RUNNING,
                BuilderState.BUILDING => TaskStatus.RUNNING,
                BuilderState.VALIDATING => TaskStatus.VALIDATING,
                BuilderState.TASK_GRAPH_BUILT => TaskStatus.COMPLETED,
                _ => task.Status
            };
        }

        return context with
        {
            State = newState,
            CurrentTaskId = newState == BuilderState.TASK_GRAPH_BUILT ? null : taskId,
            EventLog = [..context.EventLog, @event]
        };
    }
}
```

---

## 6. Error Classification & Intelligence

### 6.1 CompilerErrorCode Enum

```csharp
public enum CompilerErrorCode
{
    // C# Errors
    CS1001, // Identifier expected
    CS0103, // Name does not exist in context
    CS1061, // Contains no definition for
    CS0246, // Type or namespace could not be found
    CS1503, // Argument cannot be converted

    // XAML Errors
    XDG0062, // The name already exists in the field
    XDG0049, // The property does not exist in the XML namespace

    // NuGet Errors
    NU1101, // Unable to find package
    NU1102, // Unable to find package with version

    // MSBuild Errors
    MSB3073 // Command exited with code
}
```

### 6.2 ErrorClassification Record

```csharp
public record ErrorClassification
{
    public ErrorType Type { get; init; }
    public CompilerErrorCode? Code { get; init; }
    public string Message { get; init; }
    public string FilePath { get; init; }
    public int? LineNumber { get; init; }
    public string AutoFixStrategy { get; init; }
    public bool IsRetryable { get; init; }
}
```

### 6.3 Pre-Retry Intelligence

Error classification must happen **BEFORE** any retry decision is made. This ensures valid decisions.

1.  **Capture**: Retrieve raw error from build/execution result.
2.  **Classify**: Map raw error to `ErrorClassification` record using `CompilerErrorCode`.
3.  **Analyze**: Determine `IsRetryable` and `AutoFixStrategy`.
4.  **Decide**: Only then pass to `RetryController`.

### 6.4 Error Analytics & Pattern Detection

```csharp
public class ErrorAnalyticsService
{
    public void TrackError(ErrorClassification error)
    {
        // Aggregate error statistics
        // Identify recurring patterns
    }
}

public class ErrorPatternDetector
{
    public string DetectPattern(List<ErrorClassification> errors)
    {
        // Logic to identify systemic issues (e.g., missing dependency across multiple files)
        return null;
    }
}
```

---

## 7. Retry Controller

```csharp
public class RetryPolicy
{
    public TimeSpan InitialDelay { get; set; } = TimeSpan.FromSeconds(1);
    public double BackoffMultiplier { get; set; } = 2.0;
    public TimeSpan MaxDelay { get; set; } = TimeSpan.FromSeconds(30);

    public TimeSpan GetDelay(int retryCount)
    {
        var delay = InitialDelay.TotalMilliseconds * Math.Pow(BackoffMultiplier, retryCount);
        return TimeSpan.FromMilliseconds(Math.Min(delay, MaxDelay.TotalMilliseconds));
    }
}

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
            return new BuilderReducer().Reduce(
                context,
                new TaskFailedEvent
                {
                    TaskId = failedTask.Id,
                    ErrorType = errorClassification.Type,
                    ErrorMessage = $"Exhausted retries ({failedTask.RetryCount}/{failedTask.MaxRetries})",
                    CurrentRetry = failedTask.RetryCount,
                    MaxRetries = failedTask.MaxRetries
                });
        }
        
        // Increment retry counters
        failedTask.RetryCount++;
        context.UsedRetry++;
        
        // Emit retry event
        var retryEvent = new RetryStartedEvent
        {
            TaskId = failedTask.Id,
            CurrentRetry = failedTask.RetryCount,
            PreviousError = errorClassification.Type
        };
        
        // Return to EXECUTING_TASK state
        return context with
        {
            State = BuilderState.RETRYING,
            EventLog = [..context.EventLog, retryEvent]
        };
    }
}
```

### Retry Decision Matrix

| Error Type | Retry? | Max Retries | Strategy |
|------------|--------|-------------|----------|
| **Network Errors** | ✅ Yes | 3 | Exponential backoff |
| **API Rate Limit** | ✅ Yes | 5 | Fixed delay (60s) |
| **Syntax Errors** | ✅ Yes | 3 | AI re-generation |
| **Build Timeout** | ✅ Yes | 1 | Increase timeout |
| **SDK Not Found** | ❌ No | 0 | User must install |
| **API Key Invalid** | ❌ No | 0 | User must fix |
| **Disk Full** | ❌ No | 0 | User must free space |

---

## 8. Concurrency Rules

### Strict Serialization

```csharp
public class ConcurrencyPolicy
{
    /// <summary>
    /// Only ONE mutation task can be active at a time.
    /// This prevents Roslyn patch conflicts and state corruption.
    /// </summary>
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

    /// <summary>
    /// Read-only operations can proceed in parallel with other read-only ops,
    /// including during mutation task validation.
    /// </summary>
    public static bool IsReadOnlyTask(TaskType type) => type switch
    {
        // These can run anytime without blocking
        TaskType.MIGRATE_SCHEMA or
        TaskType.ADD_DEPENDENCY => false,  // Actually these are mutations

        _ => false
    };

    public static void ValidateConcurrency(
        BuilderContext context,
        Task incomingTask)
    {
        // Mutation Tasks require strict serialization if another task is executing
        // In this strict state machine, tasks execute one by one anyway.
        // This check is a safeguard against parallel execution attempts.
        if (context.CurrentTaskId != null && IsMutationTask(incomingTask.Type))
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

## 9. Validation Layer

### Precondition Checkers

Before existing the build or patching phase, strict preconditions must be verified.

```csharp
public class PreconditionChecker
{
    public void CheckPreconditions()
    {
        CheckSdkInstalled();
        CheckDiskSpace();
        CheckWorkspaceAccess();
    }

    private void CheckSdkInstalled() { /* .NET SDK check */ }
    private void CheckDiskSpace() { /* Free space validation */ }
    private void CheckWorkspaceAccess() { /* Write permission check */ }
}
```

### AI Output Validation Rules

Explicit validation contract block for all AI-generated content.

1.  **Schema Check**: JSON output must validate against `ProjectSpec` or `TaskGraph` schema.
2.  **Path Resolution**: All file paths must be resolved to absolute paths within the sandbox; no escaping outside.
3.  **Dependency Integrity**: `TaskGraph` must be a valid DAG (no cycles).
4.  **Symbol Existence**: Targeted symbols for patching must exist in the Semantic Model.

### Dependency Validation (DAG)

The Task Graph must be a Directed Acyclic Graph (DAG).

- **Cycle Detection**: Using Kahn's algorithm or DFS.
- **Orphan Detection**: All tasks must be reachable or have clear entry points.

---

## 10. Build System

### 10.1 Responsibilities

The Build System is responsible for:

- **Execute In-Process Restore** - Restore NuGet packages via MSBuild API
- **Execute In-Process Build** - Compile C# and XAML via `BuildManager`
- **Capture Structured Logs** - Collect errors/warnings directly from `ILogger`
- **Enforce timeout** - Prevent infinite builds
- **Enforce process isolation** - Build in isolated `ProjectCollection` context
- **Classify errors** - Categorize by error type
- **Support cancellation** - Allow user to cancel builds
- **Snapshot management** - Create/restore workspace snapshots

### 10.2 Build Flow

#### Standard Build Sequence

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

### 10.3 Build Runner Implementation

#### IBuildService Interface

```csharp
public interface IBuildService
{
    /// <summary>
    /// Builds a project asynchronously using MSBuild API.
    /// </summary>
    Task<BuildResult> BuildAsync(
        string projectPath,
        BuildOptions options = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Restores NuGet packages via MSBuild "Restore" target.
    /// </summary>
    Task<RestoreResult> RestoreAsync(
        string projectPath,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Cleans build artifacts (bin/obj directories).
    /// </summary>
    Task CleanAsync(string projectPath);
}
```

#### BuildOptions Class

```csharp
public class BuildOptions
{
    public string Configuration { get; set; } = "Debug";
    public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(60);
    public bool RestoreBeforeBuild { get; set; } = true;
    public Dictionary<string, string> Properties { get; set; } = new();
    public LoggerVerbosity Verbosity { get; set; } = LoggerVerbosity.Minimal;
}
```

#### BuildResult Class

```csharp
public class BuildResult
{
    public bool Success { get; set; }
    public ErrorType? ErrorType { get; set; } // Dominant error type
    public string ErrorMessage { get; set; }   // Summary message
    public List<BuildError> Errors { get; set; } = new();
    public List<BuildWarning> Warnings { get; set; } = new();
    public TimeSpan Duration { get; set; }
    public string BuildLog { get; set; }       // Full diagnostic log
}
```

#### BuildError Class

```csharp
public class BuildError
{
    public string Code { get; set; }          // e.g. CS1002
    public string Message { get; set; }
    public string File { get; set; }
    public int LineNumber { get; set; }
    public int ColumnNumber { get; set; }
    public BuildErrorType ErrorType { get; set; }  // e.g. CSharpCompiler
}

public class BuildWarning
{
    public string Code { get; set; }
    public string Message { get; set; }
    public string File { get; set; }
    public int LineNumber { get; set; }
}

public class RestoreResult
{
    public bool Success { get; set; }
    public List<string> RestoredPackages { get; set; } = new();
    public TimeSpan Duration { get; set; }
    public string ErrorMessage { get; set; }
}
```

### 10.4 Error Classification (Build Layer)

#### BuildErrorType Enum (Full Taxonomy)

```csharp
public enum BuildErrorType
{
    // C# Compiler Errors
    CSharpCompiler,             // General CS error
    CSharpSyntaxError,          // CS1000-1999
    CSharpSemanticError,        // CS0000-0999
    CSharpNullabilityWarning,   // CS8600+

    // XAML Errors
    XamlCompiler,               // General XAML error
    XamlParseError,             // Syntax/Structure
    XamlBindingError,           // Data binding
    XamlResourceError,          // StaticResource missing

    // NuGet Errors
    NuGetRestore,               // General NU error
    NuGetPackageNotFound,       // NU1101
    NuGetVersionConflict,       // NU1107
    NuGetRestoreFailed,         // NU1000

    // MSBuild Errors
    MSBuildInfrastructure,      // MSBxxxx
    MSBuildProjectFileError,    // .csproj invalid
    MSBuildTargetError,         // Target execution failed

    // SDK/Env Errors
    SdkNotFound,                // dotnet SDK missing
    SdkVersionMismatch,         // global.json mismatch

    // File System
    ProjectFileMissing,
    DiskFull,

    // Runtime
    Timeout,
    Unknown
}
```

#### BuildErrorClassifier

```csharp
public class BuildErrorClassifier
{
    public BuildErrorType Classify(BuildErrorEventArgs error)
    {
        // 1. Check Error Code first (most reliable)
        if (!string.IsNullOrEmpty(error.Code))
        {
            if (error.Code.StartsWith("CS")) return BuildErrorType.CSharpCompiler;
            if (error.Code.StartsWith("XDG") || error.Code.StartsWith("XLS")) return BuildErrorType.XamlCompiler;
            if (error.Code.StartsWith("NU")) return BuildErrorType.NuGetRestore;
            if (error.Code.StartsWith("MSB")) return BuildErrorType.MSBuildInfrastructure;
        }

        // 2. Fallback to Project File analysis
        if (error.File != null && error.File.EndsWith(".csproj"))
        {
            return BuildErrorType.MSBuildProjectFileError;
        }

        return BuildErrorType.Unknown;
    }
}
```

### 10.5 Build Service Implementation

#### BuildService Class (API-Based)

```csharp
using Microsoft.Build.Evaluation;
using Microsoft.Build.Execution;
using Microsoft.Build.Framework;

public class BuildService : IBuildService
{
    private readonly ILogger<BuildService> _logger;
    private readonly BuildErrorClassifier _errorClassifier;

    public BuildService(ILogger<BuildService> logger)
    {
        _logger = logger;
        _errorClassifier = new BuildErrorClassifier();
    }

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
                // 1. Load Project
                var project = projectCollection.LoadProject(projectPath);

                // 2. Set Properties
                project.SetProperty("Configuration", options.Configuration);
                foreach (var prop in options.Properties)
                {
                    project.SetProperty(prop.Key, prop.Value);
                }

                // 3. Prepare Build Parameters
                var buildParameters = new BuildParameters(projectCollection)
                {
                    Loggers = new[] { buildLogger },
                    MaxNodeCount = Environment.ProcessorCount,
                    DetailedSummary = false
                };

                // 4. Create Request (Restore + Build)
                var targets = options.RestoreBeforeBuild
                    ? new[] { "Restore", "Build" }
                    : new[] { "Build" };

                var buildRequest = new BuildRequestData(
                    project.CreateProjectInstance(),
                    targets
                );

                // 5. Execute
                var buildResult = BuildManager.DefaultBuildManager
                    .Build(buildParameters, buildRequest);

                stopwatch.Stop();

                // 6. Process Results
                return CreateResult(buildResult, buildLogger, stopwatch.Elapsed);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Build failed with exception");
                return new BuildResult
                {
                    Success = false,
                    ErrorType = BuildErrorType.MSBuildInfrastructure,
                    ErrorMessage = ex.Message,
                    Duration = stopwatch.Elapsed
                };
            }
            finally
            {
                projectCollection.Dispose();
            }
        }, cancellationToken);
    }

    private BuildResult CreateResult(
        Microsoft.Build.Execution.BuildResult msBuildResult,
        StructuredLogger logger,
        TimeSpan duration)
    {
        var result = new BuildResult
        {
            Success = msBuildResult.OverallResult == BuildResultCode.Success,
            Duration = duration,
            Errors = logger.Errors.Select(e => new BuildError
            {
                Code = e.Code,
                Message = e.Message,
                File = e.File,
                LineNumber = e.LineNumber,
                ColumnNumber = e.ColumnNumber,
                ErrorType = _errorClassifier.Classify(e)
            }).ToList(),
            Warnings = logger.Warnings.Select(w => new BuildWarning
            {
                 Code = w.Code,
                 Message = w.Message,
                 File = w.File,
                 LineNumber = w.LineNumber
            }).ToList(),
            BuildLog = logger.FullLog
        };

        if (!result.Success && result.Errors.Any())
        {
            var primaryError = result.Errors.FirstOrDefault();
            result.ErrorType = primaryError?.ErrorType;
            result.ErrorMessage = primaryError?.Message;
        }

        return result;
    }

    public async Task<RestoreResult> RestoreAsync(
        string projectPath,
        CancellationToken cancellationToken = default)
    {
        // Re-use BuildAsync with "Restore" target only
        // Implementation logic identical to BuildAsync but target="Restore"
        return new RestoreResult { Success = true };
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
}

/// <summary>
/// Captures MSBuild events into structured data.
/// </summary>
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

### 10.6 Snapshot Management

```csharp
public class SnapshotManager
{
    private readonly string _snapshotDir;
    private readonly ILogger _logger;

    public async Task<string> CreateSnapshotAsync(string workspacePath, string taskId)
    {
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var snapshotName = $"snapshot_{taskId}_{timestamp}.zip";
        var snapshotPath = Path.Combine(_snapshotDir, snapshotName);

        // Create ZIP of workspace
        ZipFile.CreateFromDirectory(workspacePath, snapshotPath);

        _logger.LogInformation("Created snapshot: {SnapshotPath}", snapshotPath);
        return snapshotPath;
    }

    public async Task RestoreSnapshotAsync(string snapshotPath, string workspacePath)
    {
        // Clear workspace
        Directory.Delete(workspacePath, recursive: true);
        Directory.CreateDirectory(workspacePath);

        // Extract snapshot
        ZipFile.ExtractToDirectory(snapshotPath, workspacePath);

        _logger.LogInformation("Restored snapshot: {SnapshotPath}", snapshotPath);
    }
}

### 10.7 Performance Optimization

#### IncrementalBuildTracker

```csharp
public class IncrementalBuildTracker
{
    private readonly Dictionary<string, string> _fileHashes = new();
    
    public bool HasFileChanged(string filePath)
    {
        var currentHash = ComputeFileHash(filePath);
        
        if (_fileHashes.TryGetValue(filePath, out var previousHash))
        {
            return currentHash != previousHash;
        }
        
        _fileHashes[filePath] = currentHash;
        return true;
    }
    
    private string ComputeFileHash(string filePath)
    {
        using var sha256 = SHA256.Create();
        using var stream = File.OpenRead(filePath);
        var hash = sha256.ComputeHash(stream);
        return Convert.ToBase64String(hash);
    }
}
```

#### Build Caching

* Cache NuGet packages globally
* Reuse previous build artifacts when possible
* Track file changes to avoid unnecessary rebuilds
* Cache Roslyn compilation results

### 10.8 Isolation Model

#### Workspace Isolation Rules

* **Workspace-specific build directory** - Each project builds in its own directory
* **Clear bin/obj before build** - Prevent stale artifacts
* **No global folder writes** - All operations scoped to workspace
* **Process must be killable** - Support cancellation
* **No elevated permissions** - Run as standard user
* **Memory limit enforcement** - Monitor process memory usage
* **Timeout enforcement** - Kill process after timeout

---

## 11. Error Handling

### 11.1 Error Handling Philosophy

#### Core Principles

1. **User Never Sees Technical Details** - All errors translated to user-friendly messages
2. **Silent Recovery When Possible** - Retry automatically before showing errors
3. **Actionable Guidance** - Every error message includes next steps
4. **Preserve User Work** - Never lose user data, always snapshot before risky operations
5. **Graceful Degradation** - System remains usable even with partial failures

#### Error Severity Levels

| Level | User Impact | UI Indicator | Action Required |
|-------|-------------|--------------|-----------------|
| **Info** | None | Blue info icon | None |
| **Warning** | Minor, non-blocking | Yellow warning icon | Optional user action |
| **Error** | Blocking, recoverable | Red error icon | User must resolve |
| **Critical** | System-level failure | Red with alert | Immediate attention |

### 11.2 Error Classification Taxonomy

All errors across the system are classified into strict enums.

#### ErrorSeverity Enum

```csharp
public enum ErrorSeverity
{
    Info,
    Warning,
    Error,
    Critical
}
```

#### BuildErrorType

(Defined in Section 10.4)

#### AIErrorType

```csharp
public enum AIErrorType
{
    // API Errors
    ApiKeyMissing, ApiKeyInvalid, ApiRateLimitExceeded, ApiQuotaExceeded, ApiNetworkError, ApiTimeout,
    // Response Errors
    InvalidJsonResponse, SchemaValidationFailed, EmptyResponse,
    // Content Errors
    ContentPolicyViolation, TokenLimitExceeded,
    // Model Errors
    ModelNotAvailable, ModelDeprecated,
    UnknownAIError
}
```

#### FileSystemErrorType

```csharp
public enum FileSystemErrorType
{
    PathNotFound, PathTooLong, AccessDenied, DiskFull, FileInUse, InvalidFileName,
    SnapshotCreationFailed, SnapshotRestoreFailed, UnknownFileSystemError
}
```

#### PatchErrorType

```csharp
public enum PatchErrorType
{
    TargetNotFound, SignatureMismatch, FileHashMismatch, SyntaxError, DuplicateMember,
    ConflictDetected, ValidationFailed, UnknownPatchError
}
```

#### OrchestratorErrorType

```csharp
public enum OrchestratorErrorType
{
    InvalidStateTransition, TaskExecutionFailed, RetryBudgetExceeded, DependencyFailed,
    TimeoutExceeded, CancellationRequested, UnknownOrchestratorError
}
```

### 11.3 Error Recovery Services

#### Build Error Recovery

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
            BuildErrorType.Timeout => await RecoverFromTimeoutAsync(error),
            _ => RecoveryResult.Failed("No recovery strategy available")
        };
    }
    // Implementation details omitted for brevity
}
```

#### Snapshot Rollback Service

```csharp
public class SnapshotRollbackService
{
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

            return RollbackResult.Success($"Restored to snapshot from {lastGoodSnapshot.CreatedDate}");
        }
        catch (Exception ex)
        {
            return RollbackResult.Failed($"Rollback failed: {ex.Message}");
        }
    }
}
```

### 11.4 User-Facing Error Messages

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
        // Additional templates...
    };

    public ErrorMessageTemplate GetMessageTemplate(BuildErrorType errorType)
    {
        return _buildErrorMessages.TryGetValue(errorType, out var template)
            ? template
            : GetDefaultTemplate();
    }
}
```

### 11.5 Logging & Wiring Strategy

```csharp
public class ErrorLogger
{
    public void LogError(Exception ex, ErrorSeverity severity, Dictionary<string,object> context)
    {
        // Integration with Structured Logging
    }
}

public class GlobalExceptionHandler
{
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
}
```

### 11.6 Circuit Breaker

```csharp
public class CircuitBreaker
{
    private int _failureCount;
    private DateTime _lastFailureTime;
    private CircuitState _state = CircuitState.Closed;

    public async Task<T> ExecuteAsync<T>(Func<Task<T>> operation)
    {
        if (_state == CircuitState.Open) throw new CircuitBreakerOpenException("Circuit breaker is open");
        try
        {
            var result = await operation();
            if (_state == CircuitState.HalfOpen) { _state = CircuitState.Closed; _failureCount = 0; }
            return result;
        }
        catch (Exception)
        {
            _failureCount++;
            if (_failureCount >= 5) _state = CircuitState.Open;
            throw;
        }
        }
    }
}

### 11.7 Error Prevention

#### Input Validation

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
```

#### Precondition Checks

```csharp
public class PreconditionChecker
{
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
}
```

---

## 12. API Contracts

### Part 1: Internal Service Interfaces

#### Orchestrator Service (`IOrchestrator`)

The Orchestrator is the central control point for all mutations.

```csharp
public interface IOrchestrator
{
    Task<BuilderState> DispatchAsync(BuilderEvent @event);
    Task<TaskResult> ExecuteTaskAsync(TaskDefinition task);
    BuilderContext GetCurrentContext();
}
```

#### Code Intelligence Service (`IRoslynService`)

Provides AST-based analysis and indexing.

- `Task<ProjectGraph> IndexProjectAsync(string path)`
- `Task<List<Symbol>> FindUsagesAsync(ISymbol symbol)`
- `Task<SemanticModel> GetSemanticModelAsync(string filePath)`

#### Patch Engine (`IPatchEngine`)

Surgically modifies source code.

- `Task<string> ApplyPatchAsync(string filePath, PatchDefinition patch)`
- `Task<bool> ValidatePatchAsync(string filePath, PatchDefinition patch)`

#### Execution Kernel (`IExecutionKernel`)

Manages the isolated .NET execution environment.

```csharp
public interface IExecutionKernel
{
    Task<BuildResult> BuildAsync(string projectPath);
    Task<TestResult> RunTestsAsync(string projectPath);
    Task<ExecutionResult> RunAppAsync(string projectPath);
}
```

### Part 2: AI Engine Output Contracts

#### Patch Definition (`PatchDefinition` / `CodePatch`)

**Source**: Generation Agents (Layer 4)
**Purpose**: Targeted modifications for the Patch Engine (Layer 5).

```json
{
  "type": "object",
  "properties": {
    "filePatches": {
      "array": {
        "items": {
          "type": "object",
          "properties": {
            "path": { "type": "string" },
            "changes": {
              "type": "array",
              "items": {
                "type": "object",
                "required": ["action", "content"],
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
                }
              }
            }
          }
        }
      }
    }
  }
}
```

#### ProjectSpec

**Source**: Initial user intent parsing.
**Purpose**: Defines the new project structure.

```json
{
  "type": "object",
  "required": ["projectId", "projectName", "stack", "features"],
  "properties": {
    "projectId": { "type": "string" },
    "projectName": { "type": "string", "pattern": "^[a-zA-Z][a-zA-Z0-9_]*$" },
    "stack": {
      "type": "object",
      "required": ["ui", "language", "framework", "database"],
      "properties": {
        "ui": { "enum": ["WinUI3", "WPF", "Console"] },
        "language": { "const": "C#" },
        "framework": { "const": ".NET 8.0" },
        "database": { "enum": ["SQLite", "None"] }
      }
    },
    "template": { "enum": ["winui-mvvm", "console", "classlib"] },
    "features": {
      "type": "array",
      "items": { "enum": ["sqlite", "navigation", "dependency-injection", "settings"] }
    }
  }
}
```

#### TaskGraph

**Source**: Planning Service.
**Purpose**: Defines the execution plan (DAG).

```json
{
  "type": "object",
  "required": ["tasks"],
  "properties": {
    "tasks": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "type", "description"],
        "properties": {
          "id": { "type": "string" },
          "type": { "enum": ["INFRASTRUCTURE", "MODEL", "SERVICE", "UI", "INTEGRATION", "FIX"] },
          "description": { "type": "string" },
          "validationStrategy": { "enum": ["COMPILE", "UNIT_TEST", "XAML_PARSE"] },
          "dependsOn": {
            "type": "array",
            "items": { "type": "string" }
          },
          "targetFiles": {
            "type": "array",
            "items": { "type": "string" }
          }
        }
      }
    }
  }
}
```
