# Orchestrator Specification & Task Schema

**Status**: Production-grade implementation foundation  
**Priority**: 🔴 **FIRST DELIVERABLE** - Must implement before all other components  
**Reason**: Without deterministic control, Roslyn indexing and patching create nondeterministic mutation loops

---

## Core Challenge

The naive approach: Intent Parser → Task Graph → Agents Generate → Roslyn Patches → Build/Validate

**Problem**: Without a deterministic orchestrator:
- Roslyn patch engine can produce cascading corruption
- Retry loops become nondeterministic
- Memory layer tracking becomes unreliable
- State debugging becomes impossible
- Silent error fixing can perpetuate failures

**Solution**: Control layer MUST exist BEFORE mutation layer.

---

## Orchestrator Positioning (Response 7 Validation)

**Three-Layer Architecture (Local-Only Model)**:

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

**Key**: Orchestrator sits **BETWEEN** UI and kernel, NOT embedded in either.

**Responsibility**:
- UI submits commands to orchestrator
- Orchestrator validates, queues, dispatches
- Kernel executes work
- Orchestrator monitors result
- Orchestrator decides retry or failure
- Orchestrator logs event
- Orchestrator updates UI with result

**Never**: UI directly calls kernel. Always through orchestrator.

---

## 1️⃣ Orchestrator Core Principles

```
✓ No implicit transitions
✓ No uncontrolled parallel mutation
✓ One active task at a time (strict serialization)
✓ Strict retry budget (no infinite loops)
✓ Immutable state transitions (functional programming)
✓ Full event log for replay/debug (deterministic replay)
```

The orchestrator is the **gatekeeper** that prevents the system from entering corrupt states.

---

## 2️⃣ Task Schema (Versioned & Typed)

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

## 3️⃣ Orchestrator State Machine

The orchestrator is a **state machine** with explicit, documented transitions.

```csharp
public enum BuilderState
{
    IDLE = 0,                // Awaiting user action or spec
    SPEC_PARSING = 1,        // User intent → structured spec
    SPEC_PARSED = 2,         // Spec validated, ready for planning
    TASK_GRAPH_BUILDING = 3, // Planning service creating DAG
    TASK_GRAPH_BUILT = 4,    // Task DAG complete, ready to execute
    EXECUTING_TASK = 5,      // Active task is running
    VALIDATING = 6,          // Build/XAML validation phase
    RETRYING = 7,            // Retry in progress
    BUILD_SUCCEEDED = 8,     // All tasks completed
    BUILD_FAILED = 9         // Unrecoverable failure
}
```

**State Diagram**:
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
EXECUTING_TASK
  ↓ (task done)
VALIDATING
  ↓ (validation succeeds)    ↓ (validation fails)
BUILD_SUCCEEDED            RETRYING
                              ↓ (retry < maxRetries)
                           EXECUTING_TASK
                              ↓ (retry >= maxRetries)
                           BUILD_FAILED
```

---

## 4️⃣ State Container (Context/Store)

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

---

## 5️⃣ Event Log (Replayable & Debuggable)

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

## 6️⃣ State Reducer (Deterministic Transition Logic)

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
            
            // === TASK EXECUTION ===
            (BuilderState.TASK_GRAPH_BUILT, TaskStartedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.EXECUTING_TASK, @event),
            
            (BuilderState.EXECUTING_TASK, TaskValidatingEvent e) =>
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
                BuilderState.EXECUTING_TASK => TaskStatus.RUNNING,
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

**Key Property**: The reducer is **pure** (no side effects). Given the same input, it always produces the same output. This enables:
- Perfect replay from event log
- Time-travel debugging
- Deterministic state reconstruction
- Audit trail validation

---

## 7️⃣ Retry Controller (Strict Budget & Rules)

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

**Rules**:
1. No task retries more than its `MaxRetries` value
2. No system retries beyond total `TotalRetryBudget`
3. Each retry must be explicitly logged
4. Retry must re-run: patch → validation → error classification

---

## 8️⃣ Concurrency Rules (Strict Serialization)

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

## 9️⃣ Error Classification (Pre-Retry Intelligence)

When `dotnet build` fails, parse output into structured error types:

```csharp
public enum CompilerErrorCode
{
    CS0001, CS0002, CS0003, // ... standard C# compiler errors
    XDG0001, XDG0002,       // XAML design-time errors
    NU1101, NU1102,         // NuGet restoration errors
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
            AutoFixStrategy = "unknown-strategy",
            IsRetryable = false
        };
    }
}
```

**Key Insight**: Error classification must happen BEFORE retry decision. The orchestrator never retries blindly.

---

## 1️⃣0️⃣ Implementation Sequence

This orchestrator must be implemented in this order:

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

### Phase 2: Integration Points (after orchestrator complete)
- Planning Service → emits `TaskCompletedEvent` to orchestrator
- Roslyn Patch Engine → asks orchestrator before patching
- Build Validator → reports errors to orchestrator
- Fix Engine → respects orchestrator state machine

### Phase 3: Testing
- Unit tests for reducer (determinism)
- Integration tests for state transitions
- Replay tests (event log → identical state)

---

## Why This Matters

**Without deterministic orchestrator:**
- Roslyn patches accumulate silently (different result each run)
- Retry loops can infinite cycle  
- Memory layer can't trust which state generated which output
- Users see non-reproducible failures ("works sometimes")

**With deterministic orchestrator:**
- Every state transition is logged
- Every retry is budgeted and tracked
- Every error is classified before retry decision
- System is replayable for debugging
- Users get consistent, reproducible results

---

## Design Philosophy Connection

This orchestrator implements the **"hide complexity, show results"** principle at the system level:

- **Hidden Complexity**: Full task graph, retry loops, error classification all internal
- **Shown Results**: User sees progress indicator + final working app
- **Error Handling**: All failures self-corrected before user sees them
- **Determinism**: Invisibly perfect replay makes system feel magical

---

## Next Deliverables (In Order)

Once orchestrator is confirmed:

1. **SQLite Schema** - Table design for project graph, memory layer, audit log
2. **Roslyn Indexing Architecture** - AST-based code intelligence indexing
3. **Patch Engine Contract** - API contract for Roslyn-based mutation
4. **Agent Contract** - How agents interact with orchestrator
5. **Intent Parser** - User → structured specification

---

**Status**: 🔴 CRITICAL PATH FIRST IMPLEMENTATION  
**Complexity**: Medium (state machine fundamentals)  
**Risk**: HIGH if skipped (foundation for everything else)  
**Estimated LOC**: ~400-500 lines C# (core reducer + supporting classes)
