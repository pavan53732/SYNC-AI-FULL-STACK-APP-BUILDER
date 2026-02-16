# Orchestration and Execution

> **Authority**: This document defines the deterministic state machine, execution lifecycle, retry model, and error handling. No other document may redefine these elements.
> **Status**: Core execution control layer

---

## Part 1: Deterministic Orchestrator

### Core Challenge

Without a deterministic orchestrator:
- Roslyn patch engine can produce cascading corruption
- Retry loops become nondeterministic
- Memory layer tracking becomes unreliable
- State debugging becomes impossible
- Silent error fixing can perpetuate failures

**Solution**: Control layer MUST exist BEFORE mutation layer.

---

### Orchestrator Positioning

```
┌──────────────────────────┐
│   WinUI 3 UI Layer       │
│   (User Input/Output)    │
└────────────┬─────────────┘
             │ (Command Request)
             ↓
┌──────────────────────────┐
│   ORCHESTRATOR ENGINE    │ ← CONTROL LAYER
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

---

### Orchestrator Core Principles

```
✓ No implicit transitions
✓ No uncontrolled parallel mutation
✓ One active task at a time (strict serialization)
✓ Strict retry budget (no infinite loops)
✓ Immutable state transitions (functional programming)
✓ Full event log for replay/debug (deterministic replay)
```

---

## Part 2: State Machine Definition

### BuilderState Enum

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

### State Transition Diagram

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

## Part 3: Task Schema

```csharp
public enum TaskType
{
    CREATE_PROJECT,
    MIGRATE_SCHEMA,
    ADD_DEPENDENCY,
    ADD_VIEW,
    ADD_VIEWMODEL,
    ADD_SERVICE,
    MODIFY_FILE,
    PATCH_FILE,
    ADD_FILE,
    DELETE_FILE,
    REFACTOR_FILE
}

public enum ValidationStrategy
{
    DOTNET_BUILD,
    XAML_COMPILE,
    NUGET_RESTORE,
    SYNTAX_CHECK_ONLY,
    NONE
}

public enum TaskStatus
{
    PENDING,
    RUNNING,
    VALIDATING,
    RETRYING,
    COMPLETED,
    FAILED
}

public enum ErrorType
{
    BUILD_ERROR,
    XAML_ERROR,
    NUGET_ERROR,
    PATCH_CONFLICT,
    VALIDATION_TIMEOUT
}

public class Task
{
    public string Id { get; }
    public int Version { get; } = 1;
    public TaskType Type { get; }
    public string Description { get; }
    public List<string> DependsOnTaskIds { get; }
    public List<string> TargetFiles { get; }
    public ValidationStrategy Validation { get; }
    public TimeSpan ValidationTimeout { get; }
    public int RetryCount { get; set; }
    public int MaxRetries { get; set; } = 5;
    public TaskStatus Status { get; set; }
    public ErrorType? LastError { get; set; }
    public string? ErrorMessage { get; set; }
    public int RetryBudget { get; set; } = 5;
    public DateTime CreatedAt { get; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public List<string> ActionLog { get; } = new();
}
```

---

## Part 4: State Reducer (Pure Function)

```csharp
public class BuilderReducer
{
    public static BuilderContext Reduce(BuilderContext context, BuilderEvent @event)
    {
        return (context.State, @event) switch
        {
            (BuilderState.IDLE, SpecParsedEvent e) => context with
            {
                State = BuilderState.SPEC_PARSED,
                EventLog = [..context.EventLog, @event]
            },
            (BuilderState.SPEC_PARSED, TaskStartedEvent te) when te.TaskId == "graph-builder" =>
                context with { State = BuilderState.TASK_GRAPH_BUILDING },
            (BuilderState.TASK_GRAPH_BUILDING, TaskCompletedEvent te) when te.TaskId == "graph-builder" =>
                context with { State = BuilderState.TASK_GRAPH_BUILT },
            (BuilderState.TASK_GRAPH_BUILT, TaskStartedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.MUTATION_GUARD, @event),
            (BuilderState.MUTATION_GUARD, TaskGuardPassedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.PATCHING, @event),
            (BuilderState.PATCHING, TaskPatchedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.INDEXING, @event),
            (BuilderState.INDEXING, TaskIndexedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.BUILDING, @event),
            (BuilderState.BUILDING, TaskValidatingEvent e) =>
                context with { State = BuilderState.VALIDATING },
            (BuilderState.VALIDATING, TaskCompletedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.TASK_GRAPH_BUILT, @event),
            (BuilderState.VALIDATING, TaskFailedEvent e) when e.CurrentRetry < e.MaxRetries =>
                context with { State = BuilderState.RETRYING },
            (BuilderState.RETRYING, TaskStartedEvent e) =>
                context with { State = BuilderState.EXECUTING_TASK },
            (BuilderState.VALIDATING, TaskFailedEvent e) when e.CurrentRetry >= e.MaxRetries =>
                context with { State = BuilderState.BUILD_FAILED },
            (BuilderState.TASK_GRAPH_BUILT, BuildCompletedEvent e) =>
                context with { State = BuilderState.BUILD_SUCCEEDED },
            _ => throw new InvalidOperationException($"Invalid transition: {context.State} + {@event.GetType().Name}")
        };
    }
}
```

---

## Part 5: Retry Controller

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
            return new BuilderReducer().Reduce(context, new TaskFailedEvent
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

**Rules**:
1. No task retries more than its `MaxRetries` value
2. No system retries beyond total `TotalRetryBudget`
3. Each retry must be explicitly logged
4. Retry must re-run: patch → validation → error classification

---

## Part 6: Concurrency Rules

```csharp
public class ConcurrencyPolicy
{
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
    
    public static void ValidateConcurrency(BuilderContext context, Task incomingTask)
    {
        if (context.State == BuilderState.EXECUTING_TASK && IsMutationTask(incomingTask.Type))
        {
            throw new InvalidOperationException(
                "Cannot start mutation task while another task is executing.");
        }
    }
}
```

**Iron Law**: Only 1 mutation task at a time. No parallel Roslyn patching.

---

## Part 7: Execution Lifecycle

### Full Hidden Background Execution Lifecycle

#### Phase 0 — Pre-Execution Guard
```csharp
public async Task<ExecutionSession> SubmitGenerateRequestAsync(string prompt)
{
    if (_currentState != OrchestratorState.IDLE)
        throw new InvalidOperationException("Orchestrator busy");
    
    await _workspaceLock.WaitAsync();
    
    var session = new ExecutionSession
    {
        Id = Guid.NewGuid(),
        Prompt = prompt,
        StartTime = DateTime.UtcNow,
        CancellationToken = new CancellationTokenSource()
    };
    
    _currentState = OrchestratorState.AI_PLANNING;
    await _executionQueue.EnqueueAsync(session);
    
    return session;
}
```

#### Phase 1 — AI Planning
- Prepare AI context
- Retrieve relevant symbols
- Retrieve dependency graph
- Trim context to token budget
- Call z-ai-web-dev-sdk
- Validate JSON schema
- Persist TaskGraph to SQLite
- Transition to TASK_GRAPH_READY

#### Phase 2 — Task Execution Loop
- Topological sort for dependency order
- Create snapshot before each task
- Apply patch via Patch Engine
- Update Roslyn index
- Execute build
- Classify errors
- Check retry budget
- Commit or rollback snapshot

#### Phase 3 — Patch Application
- Load target file
- Parse SyntaxTree
- Apply AST transformation
- Validate syntax
- Format code
- Write atomically
- Update SQLite graph

#### Phase 4 — Build Execution
- dotnet restore (if needed)
- dotnet build
- Capture stdout/stderr
- Parse MSBuild errors

#### Phase 5 — Silent Retry Loop
- Construct minimal error context
- Call z-ai-web-dev-sdk (Fix Mode)
- Receive structured patch
- Apply patch
- Build again

#### Phase 6 — Finalization
- Commit final snapshot
- Record version in timeline
- Update project metadata
- Release workspace lock
- Transition to COMPLETED
- Trigger preview refresh

---

## Part 8: Threading Model

| Thread Type | Responsibility | Concurrency |
|-------------|----------------|-------------|
| UI Thread | Rendering, clicks, animations | Single |
| Orchestrator Thread | State machine, task queue, retry control | Sequential |
| AI Worker Pool | SDK API calls, context prep | Parallel (max 2) |
| Patch Worker | Roslyn parsing, AST transformations | Serialized |
| Build Worker | dotnet restore/build | Isolated |
| Background Maintenance | Snapshot pruning, SQLite vacuum | Idle only |

---

## Part 9: Error Classification

### Error Type Taxonomy

```csharp
public enum BuildErrorType
{
    CSharpSyntaxError,            // CS1001-CS1999
    CSharpSemanticError,         // CS0001-CS0999
    XamlParseError,              // XDG0001-XDG0999
    XamlBindingError,            // XDG1000-XDG1999
    NuGetPackageNotFound,        // NU1101
    NuGetVersionConflict,        // NU1107
    MSBuildProjectFileError,     // MSB4000-MSB4999
    SdkNotFound,
    BuildTimeout
}

public enum AIErrorType
{
    ApiKeyMissing,
    ApiKeyInvalid,
    ApiRateLimitExceeded,
    ApiNetworkError,
    InvalidJsonResponse,
    SchemaValidationFailed,
    ContentPolicyViolation
}

public enum PatchErrorType
{
    TargetNotFound,
    SignatureMismatch,
    FileHashMismatch,
    SyntaxError,
    DuplicateMember,
    ConflictDetected
}
```

### Error Classifier

```csharp
public class ErrorClassifier
{
    public static ErrorClassification ClassifyBuildError(string buildOutput)
    {
        if (buildOutput.Contains("error CS"))
            return new ErrorClassification
            {
                Type = ErrorType.BUILD_ERROR,
                AutoFixStrategy = "roslyn-patch-and-retry",
                IsRetryable = true
            };
        
        if (buildOutput.Contains("XDG"))
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
            IsRetryable = false
        };
    }
}
```

---

## Part 10: Retry Decision Matrix

| Error Type | Retry? | Max Retries | Strategy |
|------------|--------|-------------|----------|
| Network Errors | ✅ Yes | 3 | Exponential backoff |
| API Rate Limit | ✅ Yes | 5 | Fixed delay (60s) |
| Syntax Errors | ✅ Yes | 3 | AI re-generation |
| Build Timeout | ✅ Yes | 1 | Increase timeout |
| SDK Not Found | ❌ No | 0 | User must install |
| API Key Invalid | ❌ No | 0 | User must fix |
| Disk Full | ❌ No | 0 | User must free space |

---

## Part 11: Event Log

```csharp
public abstract record BuilderEvent
{
    public DateTime Timestamp { get; init; } = DateTime.Now;
    public int EventSequence { get; init; }
}

public record SpecParsedEvent : BuilderEvent
{
    public string SpecJson { get; init; }
    public List<string> ExtractedFeatures { get; init; }
}

public record TaskStartedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public TaskType TaskType { get; init; }
}

public record TaskCompletedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public TimeSpan Duration { get; init; }
}

public record TaskFailedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public ErrorType ErrorType { get; init; }
    public string ErrorMessage { get; init; }
    public int CurrentRetry { get; init; }
    public int MaxRetries { get; init; }
}

public record BuildCompletedEvent : BuilderEvent
{
    public int TasksCompleted { get; init; }
    public TimeSpan TotalDuration { get; init; }
    public List<string> GeneratedFiles { get; init; }
}

public record RetryStartedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public int CurrentRetry { get; init; }
    public ErrorType PreviousError { get; init; }
}
```

---

## Part 12: Crash Recovery

```csharp
private async Task HandleCrashRecoveryAsync(ExecutionSession incompleteSession)
{
    // 1. Detect incomplete ExecutionSession
    _logger.LogWarning("Detected incomplete session: {SessionId}", incompleteSession.Id);
    
    // 2. Rollback to last stable snapshot
    var lastStableSnapshot = await _database.GetLastStableSnapshotAsync(incompleteSession.ProjectId);
    await _snapshotManager.RollbackAsync(lastStableSnapshot.Id);
    
    // 3. Mark previous version as failed
    await _database.MarkVersionAsFailedAsync(incompleteSession.Id);
    
    // 4. Notify user gently
    await ShowToastAsync("We restored your project to a stable version.");
}
```

---

## Part 13: Boot Sequence

1. **App Startup** - Initialize WinUI window, show splash
2. **Environment Validation** - Check .NET SDK, MSBuild, NuGet, disk space
3. **Load Project Registry** - Read workspaces, validate snapshots, validate graph
4. **Initialize Services** - Instantiate singletons (Orchestrator, RoslynIndexer, PatchEngine, etc.)
5. **Warm-Up Index** - Pre-load symbol graph, pre-cache dependency tree
6. **UI Ready** - Fade out splash, show main window

---

## Related Documents

- [00_CANONICAL_AUTHORITY.md](./00_CANONICAL_AUTHORITY.md) - System invariants
- [03_BUILD_AND_MUTATION_KERNEL.md](./03_BUILD_AND_MUTATION_KERNEL.md) - Build execution
- [04_INDEXING_AND_MEMORY.md](./04_INDEXING_AND_MEMORY.md) - SQLite persistence

---

**End of Orchestration and Execution Specification**
