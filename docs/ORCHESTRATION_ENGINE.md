# ORCHESTRATION ENGINE

> **Runtime Safety & Execution Kernel: State Machine, Task Lifecycle, Build System, Retry Logic & Concurrency Safety**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>


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
9. [Build System](#9-build-system)
10. [Error Handling](#10-error-handling)
11. [API Contracts](#11-api-contracts)
12. [Appendix A: Supporting Types](#appendix-a-supporting-types)
13. [Appendix B: Implementation Sequence](#appendix-b-implementation-sequence)
14. [Appendix C: Testing Strategy](#appendix-c-testing-strategy)
15. [Appendix D: Why This Matters](#appendix-d-why-this-matters)
16. [Appendix E: Design Philosophy Connection](#appendix-e-design-philosophy-connection)
17. [Appendix F: Next Deliverables](#appendix-f-next-deliverables-in-order)

---

## 1. Core Challenge & Positioning

### Why the Runtime Safety Kernel Must Exist

**Priority**: 🔴 **FIRST DELIVERABLE** — The enforcement layer that guarantees deterministic execution.

The Runtime Safety Kernel (Orchestrator) is the **enforcement layer** that validates all AI-driven construction. Without it:

- Roslyn patch engine can produce cascading corruption
- Retry loops become nondeterministic
- Memory layer tracking becomes unreliable
- State debugging becomes impossible
- Silent error fixing can perpetuate failures

**Key Principle**: The Runtime Safety Kernel enforces deterministic execution guarantees for AI-driven construction operations.

> **AI leads, Kernel enforces.** The AI Construction Engine proposes mutations; the Kernel validates, snapshots, and guarantees safety.

### Architectural Position

```
┌──────────────────────────┐
│   WinUI 3 UI Layer       │
│   (User Input/Output)    │
└────────────┬─────────────┘
             │ (Command Request)
             ↓
┌──────────────────────────┐
│   ORCHESTRATOR ENGINE    │ ← RUNTIME SAFETY KERNEL (This Spec)
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
✓ Bounded autonomous refinement (max 10 retries with staged escalation)
✓ Immutable state transitions (functional programming)
✓ Full event log for replay/debug (deterministic replay)
✓ Deterministic termination (FAILED state with rollback on exhaustion)
```

### Retry Governance Contract

> **AI owns the retry strategy. The Kernel enforces hard ceilings.**

The AI Construction Engine has full flexibility to adapt, retry, and escalate during cycles 1-9. The Runtime Safety Kernel enforces a hard abort at cycle 10+.

| Retry Range | Owner | Enforcement | Behavior |
|-------------|-------|-------------|----------|
| 1-9 | AI Construction Engine | Strategy flexible | AI adapts, learns, retries |
| 10+ | Runtime Safety Kernel | Hard abort + rollback | System stops, user notified |

**AI Retry Strategy (Cycles 1-9)**:
| Stage | Range | Agent Responsible |
|-------|-------|-------------------|
| FIX_LEVEL | 1-3 | Fix Agent (local token repairs) |
| INTEGRATION_LEVEL | 4-6 | Integration Agent (DI/wiring review) |
| ARCHITECTURE_LEVEL | 7-9 | Architect Agent (plan re-evaluation) |

**Kernel Enforcement (Cycle 10+)**: The Runtime Safety Kernel:
1. Stops all mutations immediately
2. Rolls back to `LastStableSnapshotHash`
3. Transitions to `BuilderState.FAILED`
4. Clears all task-scoped memory
5. Emits `BuildFailedEvent` for user notification
6. Awaits user intervention

> See [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) §5 for complete retry ownership details.

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
    /// Packaging operations
    GENERATE_MANIFEST,
    INFER_CAPABILITIES,
    CONFIGURE_PACKAGING,
    GENERATE_CERTIFICATE,
    SIGN_PACKAGE,
    BUILD_MSIX
}

public enum ValidationStrategy
{
    DOTNET_BUILD,        // Run full dotnet build
    XAML_COMPILE,        // Compile XAML only
    NUGET_RESTORE,       // Restore packages
    SYNTAX_CHECK_ONLY,   // Parse syntax without build
    MANIFEST_VALIDATE,   // Validate Package.appxmanifest
    MSIX_BUILD,          // Validate MSIX packaging
    NONE                 // No validation
}

public enum TaskStatus
{
    PENDING,             // Queued, awaiting execution
    RUNNING,             // Currently executing
    VALIDATING,          // Build/validation phase
    RETRYING,            // Failed, attempting retry (max 10 total)
    COMPLETED,           // Task succeeded
    FAILED               // Task failed after max retries exhausted
}

public enum ErrorType
{
    BUILD_ERROR,         // C# compiler error (CSxxxx)
    XAML_ERROR,          // XAML compiler error (XDGxxxx)
    NUGET_ERROR,         // NuGet restore error (NUxxxx)
    PATCH_CONFLICT,      // Roslyn patch failed to apply
    VALIDATION_TIMEOUT,  // Build took too long
    MANIFEST_ERROR,      // Invalid Package.appxmanifest
    CAPABILITY_ERROR,    // Missing/Excessive capabilities
    SIGNING_ERROR,       // Certificate or signing failure
    PACKAGING_ERROR,     // MSIX bundling failure
    RUNTIME_PREVIEW_ERROR, // App crashed during preview
    SANDBOX_ESCAPE_ATTEMPT, // Security violation
    PROCESS_CRASH        // Host process termination
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

    // Retry tracking
    public int RetryCount { get; set; }               // Current attempt number (informational only)
    public string? LastPatchHash { get; set; }        // SHA256 of last applied patch (for deduplication)

    // State
    public TaskStatus Status { get; set; }            // Current status
    public ErrorType? LastError { get; set; }         // Last error encountered
    public string? ErrorMessage { get; set; }         // Error details

    // Admin/Elevation awareness
    public bool RequiresAdmin { get; set; }           // Task requires elevation (signing, cert install)

    // Audit trail
    public DateTime CreatedAt { get; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public List<string> ActionLog { get; } = new();   // What was attempted
}
```

**Key Design Decision**: No free-form tasks. Only structured, enumerated task types prevent undefined behavior.

> **Note**: `TaskType` is an execution primitive vocabulary. The AI Construction Engine maps flexible blueprint operations into this bounded execution set. This allows the AI to reason with unlimited flexibility while the Runtime Safety Kernel validates against a finite, well-defined execution vocabulary. The enum exists for kernel validation, not to constrain AI planning creativity.

---

## 3. State Machine

### Builder States

```csharp
public enum BuilderState
{
    IDLE = 0,                // Awaiting user action or blueprint
    BLUEPRINT_DESIGN = 1,    // User intent → adaptive blueprint
    BLUEPRINT_READY = 2,     // Blueprint validated, ready for planning
    EXECUTION_PLAN_BUILDING = 3, // Planning service creating execution plan
    EXECUTION_PLAN_BUILT = 4,    // Execution plan complete, ready to execute
    // Execution Breakdown
    MUTATION_GUARD = 5,      // Pre-execution safety check (Impact/Breaking Change)
    PATCHING = 6,            // Roslyn AST transformation
    INDEXING = 7,            // Updating semantic graph post-patch
    BUILDING = 8,            // MSBuild / Dotnet CLI execution
    // Validation & Result
    VALIDATING = 9,          // Final integrity check
    RETRYING = 10,           // Retry in progress
    EXECUTING_TASK = 11,     // Task execution/retry in progress
    BUILD_SUCCEEDED = 12,    // All tasks completed
    // === TERMINAL FAILURE STATE ===
    FAILED = 13,             // Max retries exceeded - system stopped, awaiting user intervention
    // Packaging Phase
    PACKAGING = 14,          // MSIX bundling & signing
    PACKAGING_SUCCEEDED = 15, // Application ready for distribution
    // Packaging Failure
    PACKAGING_FAILED = 16,   // Packaging failed after max retries
    // Mandatory Packaging Steps
    CAPABILITY_CHECK = 17,
    MANIFEST_UPDATING = 18,
    REBUILD_REQUIRED = 19,
    SIGNING = 20,
    SIGNATURE_VALIDATION = 21,
    ENVIRONMENT_RECOVERY = 22     // Suspension of mutations to recover environment
}
```

### State Diagram

```
IDLE
  ↓ (blueprint request arrives)
BLUEPRINT_DESIGN
  ↓ (blueprint valid)
BLUEPRINT_READY
  ↓ (execution plan generated)
EXECUTION_PLAN_BUILDING
  ↓ (plan complete)
EXECUTION_PLAN_BUILT
  ↓ (execute next task)
MUTATION_GUARD
  ↓ (guard safe)
PATCHING ←─────────────────────────────┐
  ↓ (patch applied)                     │
INDEXING                                │
  ↓ (index updated)                     │
BUILDING                                │
  ↓ (build complete)                    │
VALIDATING                              │
  │                                     │
  ├──(validation succeeds)──→ BUILD_SUCCEEDED
  │                                ↓
  │                           CAPABILITY_CHECK
  │                                ↓ (changes detected)
  │                           MANIFEST_UPDATING
  │                                ↓
  │                           REBUILD_REQUIRED
  │                                ↓
  │                           BUILDING
  │                                ↓
  │                           PACKAGING
  │                                ↓
  │                           SIGNING
  │                                ↓
  │                           SIGNATURE_VALIDATION
  │                                ↓
  │                           PACKAGING_SUCCEEDED
  │
  └──(validation fails)──→ RETRYING
                              │
                              ├──(retry < 10)──→ EXECUTING_TASK ──→ MUTATION_GUARD
                              │                                              ↑
                              │                                              │
                              └──(retry >= 10 / ABORT stage)──→ FAILED ───────┘
                                         │                              ROLLBACK
                                         ↓                         (to LastStableSnapshot)
                                    [User intervention required]
```

### Terminal States

| State | Type | Description | Recovery |
|-------|------|-------------|----------|
| `PACKAGING_SUCCEEDED` | Success | Application built, packaged, and ready | None needed |
| `FAILED` | Failure | Max retries exceeded, rollback complete | User must modify spec or environment |
| `PACKAGING_FAILED` | Failure | Packaging failed after retries | User must check signing config |

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

    // Project metadata
    public string ProjectName { get; set; }
    public string ProjectPath { get; set; }
    public Dictionary<string, object> ProjectMetadata { get; } = new();

    // === RUNTIME SAFETY: Agent Execution Context Injection ===
    /// <summary>
    /// Active agent context providing safety ceilings and isolation boundaries.
    /// MUST be set before any task execution begins.
    /// Source: AGENT_EXECUTION_CONTRACT.md
    /// </summary>
    public AgentExecutionContext? ActiveAgentContext { get; set; }

    // Safety Ceilings (Delegate from ActiveAgentContext for fast access)
    public int MaxFilesTouchedPerTask => ActiveAgentContext?.MaxFilesTouchedPerTask ?? 5;
    public int MaxNodesModifiedPerTask => ActiveAgentContext?.MaxNodesModifiedPerTask ?? 100;

    // Snapshot tracking for rollback
    public string? SemanticSnapshotHash { get; set; }      // Hash BEFORE current task
    public string? LastStableSnapshotHash { get; set; }    // Hash of last verified build

    // Debug info
    public List<string> DebugLog { get; } = new();
    public DateTime StartTime { get; } = DateTime.Now;

    // === RUNTIME SAFETY: Context Validation ===
    public void ValidateAgentContext()
    {
        if (ActiveAgentContext == null)
        {
            throw new InvalidOperationException(
                "AgentExecutionContext must be injected into BuilderContext before task execution. " +
                "See AGENT_EXECUTION_CONTRACT.md §4 for injection pattern.");
        }
    }
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
    public int CurrentRetry { get; init; }  // Informational only - for logging/debugging
}

// System-level events
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
    public RetryStage Stage { get; init; }
}

// === RUNTIME SAFETY: Mutation Ceiling Events ===
public record MutationCeilingValidatedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public int FilesTouched { get; init; }
    public int NodesModified { get; init; }
    public bool HasBreakingChanges { get; init; }
}

public record MutationCeilingExceededEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public string RejectionReason { get; init; }
    public string CeilingType { get; init; }  // "MaxFilesTouchedPerTask" or "MaxNodesModifiedPerTask" or "BreakingChange"
}

// === RUNTIME SAFETY: Memory Lifecycle Events ===
public record MemoryScopeDisposedEvent : BuilderEvent
{
    public MemoryScope Scope { get; init; }
    public string ProjectId { get; init; }
    public int ResourcesReleased { get; init; }
}

// === TERMINAL FAILURE EVENTS ===
public record BuildFailedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public string Reason { get; init; }
    public ErrorClassification Error { get; init; }
    public int TotalRetries { get; init; }
    public string? RollbackSnapshotId { get; init; }
}

public record SnapshotRollbackEvent : BuilderEvent
{
    public string SnapshotId { get; init; }
    public string Reason { get; init; }
    public bool Success { get; init; }
    public string? ErrorMessage { get; init; }
}

public record RetryEscalationEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public RetryStage PreviousStage { get; init; }
    public RetryStage NewStage { get; init; }
    public int RetryCount { get; init; }
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

            // === RUNTIME SAFETY: Mutation Ceiling Check in State Machine ===
            // MUTATION_GUARD validates AgentExecutionContext and MutationCeilings BEFORE patching
            (BuilderState.MUTATION_GUARD, TaskGuardPassedEvent e) =>
                ExecuteMutationGuardValidation(context, e.TaskId, @event),

            // Only transition to PATCHING if mutation ceiling validation passed
            (BuilderState.MUTATION_GUARD, MutationCeilingValidatedEvent e) =>
                 UpdateTaskAndTransition(context, e.TaskId, BuilderState.PATCHING, @event),

            // Handle mutation ceiling exceeded - trigger retry with different strategy
            (BuilderState.MUTATION_GUARD, MutationCeilingExceededEvent e) =>
                context with
                {
                    State = BuilderState.RETRYING,
                    EventLog = [..context.EventLog, @event]
                },

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

            // === FAILURE & BOUNDED RETRY PATH ===
            // System retries up to max 10 attempts with staged escalation
            // RetryController determines stage and handles ABORT transition
            (BuilderState.VALIDATING, TaskFailedEvent e) =>
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

            // === COMPLETION ===
            (BuilderState.TASK_GRAPH_BUILT, BuildCompletedEvent e) =>
                context with
                {
                    State = BuilderState.BUILD_SUCCEEDED,
                    EventLog = [..context.EventLog, @event]
                },

            // === RUNTIME SAFETY: Memory Lifecycle Wired to State Transitions ===
            // Memory disposal events are emitted at specific lifecycle points
            // These transitions trigger MemoryLifecycleManager calls via side effects
            
            // Memory disposal on task completion (success)
            (BuilderState.VALIDATING, TaskCompletedEvent e) => 
                DisposeMemoryAndTransition(context, MemoryScope.TASK, e),

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

    // === RUNTIME SAFETY: Mutation Guard Validation ===
    /// <summary>
    /// Validates AgentExecutionContext and mutation ceilings before allowing PATCHING state.
    /// This is the enforcement point for runtime safety guarantees.
    /// </summary>
    private static BuilderContext ExecuteMutationGuardValidation(
        BuilderContext context,
        string taskId,
        BuilderEvent @event)
    {
        // 1. Validate AgentExecutionContext is injected
        if (context.ActiveAgentContext == null)
        {
            throw new InvalidOperationException(
                "AgentExecutionContext not injected. " +
                "Call BuilderContext.ValidateAgentContext() before task execution.");
        }

        // 2. Emit validation event (actual validation happens in MutationCeilingEnforcer)
        // This is a placeholder - in real implementation, this would call:
        // var result = await _mutationCeilingEnforcer.ValidateMutationCeilingAsync(patch, context.ActiveAgentContext);
        // For the reducer (pure function), we just emit the event that triggers validation

        return context with
        {
            State = BuilderState.MUTATION_GUARD,
            EventLog = [..context.EventLog, @event]
        };
    }

    // === RUNTIME SAFETY: Memory Lifecycle Helper ===
    /// <summary>
    /// Disposes memory scope and transitions state.
    /// Emits MemoryScopeDisposedEvent for audit trail.
    /// </summary>
    private static BuilderContext DisposeMemoryAndTransition(
        BuilderContext context,
        MemoryScope scope,
        BuilderEvent originalEvent)
    {
        // Emit memory disposal event
        var memoryEvent = new MemoryScopeDisposedEvent
        {
            Scope = scope,
            ProjectId = context.ProjectPath,
            ResourcesReleased = 0 // Actual count tracked by MemoryLifecycleManager
        };

        // In real implementation, this triggers:
        // _memoryLifecycleManager.DisposeScope(scope, context.ProjectPath);

        return context with
        {
            EventLog = [..context.EventLog, originalEvent, memoryEvent]
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
    CS0001, CS0002, CS0003, // Standard C# compiler errors
    CS1001, // Identifier expected
    CS0103, // Name does not exist in context
    CS1061, // Contains no definition for
    CS0246, // Type or namespace could not be found
    CS1503, // Argument cannot be converted

    // XAML Errors
    XDG0001, XDG0002,       // XAML design-time errors
    XDG0062, // The name already exists in the field
    XDG0049, // The property does not exist in the XML namespace

    // NuGet Errors
    NU1101, // Unable to find package
    NU1102, // Unable to find package with version

    // MSBuild Errors
    MSB3073, // Command exited with code
    MSB4181  // MSBuild structural errors
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
    private readonly IErrorRepository _errorRepository;
    private readonly ILogger<ErrorAnalyticsService> _logger;

    public ErrorAnalyticsService(IErrorRepository errorRepository, ILogger<ErrorAnalyticsService> logger)
    {
        _errorRepository = errorRepository;
        _logger = logger;
    }

    public void TrackError(ErrorClassification error)
    {
        _errorRepository.AddAsync(new ErrorLog
        {
            Timestamp = DateTime.UtcNow,
            ErrorType = error.Type.ToString(),
            ErrorCode = error.Code?.ToString(),
            Message = error.Message,
            FilePath = error.FilePath,
            LineNumber = error.LineNumber,
            AutoFixStrategy = error.AutoFixStrategy,
            IsRetryable = error.IsRetryable
        });

        _logger.LogInformation("Tracked error {ErrorCode} in {FilePath}", error.Code, error.FilePath);
    }

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

public class ErrorPatternDetector
{
    private readonly IErrorPatternRepository _errorPatternRepository;
    private readonly IErrorRepository _errorRepository;

    public ErrorPatternDetector(IErrorPatternRepository errorPatternRepository, IErrorRepository errorRepository)
    {
        _errorPatternRepository = errorPatternRepository;
        _errorRepository = errorRepository;
    }

    public async Task DetectPatternsAsync()
    {
        var recentErrors = await _errorRepository.GetRecentErrorsAsync(100);

        // Group by error code
        var patterns = recentErrors
            .GroupBy(e => e.ErrorCode)
            .Where(g => g.Count() >= 3)  // Pattern = 3+ occurrences
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
        // Find common file paths or namespaces
        var commonPaths = errors
            .Select(e => Path.GetDirectoryName(e.FilePath))
            .GroupBy(p => p)
            .OrderByDescending(g => g.Count())
            .FirstOrDefault()?.Key;

        return commonPaths ?? "Unknown";
    }
}

public class ErrorStatistics
{
    public int TotalErrors { get; set; }
    public Dictionary<string, int> ErrorsByType { get; set; }
    public string MostCommonError { get; set; }
    public double? AverageRecoveryTime { get; set; }
}

public class ErrorPattern
{
    public string ErrorCode { get; set; }
    public int OccurrenceCount { get; set; }
    public int AffectedProjects { get; set; }
    public DateTime FirstSeen { get; set; }
    public DateTime LastSeen { get; set; }
    public string CommonContext { get; set; }
}
```

---

## 7. Retry Controller & Escalation Strategy

### 7.1 Retry Stages

To prevent infinite mutation loops, the system enforces a strict escalation policy.

```csharp
public enum RetryStage
{
    FIX_LEVEL,          // Stage 1: Try local token repairs
    INTEGRATION_LEVEL,  // Stage 2: Check DI and wiring
    ARCHITECTURE_LEVEL, // Stage 3: Re-evaluate high-level plan
    ABORT               // Stage 4: Rollback and Fail
}

public class RetryPolicy
{
    public TimeSpan InitialDelay { get; set; } = TimeSpan.FromSeconds(1);
    public double BackoffMultiplier { get; set; } = 2.0;
    public int MaxRetriesPerStage { get; set; } = 3;

    public TimeSpan GetDelay(int retryCount)
    {
        var delay = InitialDelay.TotalMilliseconds * Math.Pow(BackoffMultiplier, retryCount);
        return TimeSpan.FromMilliseconds(delay);
    }
}
```

### 7.2 Safety Snapshots

Before any mutation phase, the system captures a **Semantic Snapshot**. This allows a clean rollback if the retry escalation fails.

```csharp
public class BuilderContext
{
    // ... existing properties ...
    public string SemanticSnapshotHash { get; set; }     // Hash of state BEFORE current task
    public string LastStableSnapshotHash { get; set; }   // Hash of last successfully verified build

    // Safety Ceilings (Injected from AgentExecutionContext)
    public int MaxFilesTouchedPerTask { get; set; }
    public int MaxNodesModifiedPerTask { get; set; }
}
```

### 7.3 Retry Controller Logic

```csharp
public class RetryController
{
    public static BuilderContext ExecuteRetry(
        BuilderContext context,
        Task failedTask,
        ErrorClassification error)
    {
        failedTask.RetryCount++;

        // 1. Post-Failure Graph Integrity Check
        if (!GraphIntegrityVerifier.Verify(context.ProjectId))
        {
            return AbortAndRollback(context, failedTask, "Graph integrity compromised during mutation.");
        }

        // 2. Determine Stage based on RetryCount
        var stage = DetermineStage(failedTask.RetryCount);

        // 2. Check for ABORT condition
        if (stage == RetryStage.ABORT)
        {
            // Assuming an AbortAndRollback method exists elsewhere or needs to be defined.
            // For this change, we'll just transition to a FAILED state and log.
            // In a real system, this would trigger a rollback to LastStableSnapshotHash.
            var abortEvent = new BuildFailedEvent
            {
                TaskId = failedTask.Id,
                Reason = "Max retries exceeded across all stages. Aborting task.",
                Error = error
            };
            return context with
            {
                State = BuilderState.FAILED,
                EventLog = [..context.EventLog, abortEvent]
            };
        }

        // 3. Emit detailed event
        var retryEvent = new RetryStartedEvent
        {
            TaskId = failedTask.Id,
            CurrentRetry = failedTask.RetryCount,
            Stage = stage,
            PreviousError = error.Type
        };

        // 4. Return to RETRYING state
        return context with
        {
            State = BuilderState.RETRYING,
            EventLog = [..context.EventLog, retryEvent]
        };
    }

    private static RetryStage DetermineStage(int retryCount) => retryCount switch
    {
        <= 3 => RetryStage.FIX_LEVEL,
        <= 6 => RetryStage.INTEGRATION_LEVEL,
        <= 9 => RetryStage.ARCHITECTURE_LEVEL,
        _ => RetryStage.ABORT
    };
}
```

**Escalation Rules**:
*   **Fix Level (1-3)**: The `FixAgent` attempts to repair the specific file causing the error.
*   **Integration Level (4-6)**: The `IntegrationAgent` reviews `Program.cs` and DI registration.
*   **Architecture Level (7-9)**: The `ArchitectAgent` reviews the task plan itself.
*   **Abort (10+)**: The system explicitly stops, rolls back to `LastStableSnapshotHash`, and asks the user for help.

### Packaging Retry Policy

| Error Code | Classification | Strategy |
| :--- | :--- | :--- |
| **PKG001** | Manifest Invalid | Regenerate `Package.appxmanifest` + retry |
| **PKG002** | Capability Mismatch | Inject missing capabilities via CIE + retry |
| **PKG003** | Asset Missing | Generate placeholder assets + retry |
| **PKG004** | Sign Failed | Prompt user for certificate + retry |
| **PKG005** | Identity Mismatch | Update manifest to match certificate + retry |

### 7.4 Snapshot Rollback Policy (Wired to Retry)

The snapshot system is explicitly tied to the retry escalation ladder:

```csharp
public class SnapshotRollbackPolicy
{
    /// <summary>
    /// Determines rollback action based on retry stage.
    /// Called by RetryController.ExecuteRetry() before any retry attempt.
    /// </summary>
    public async Task<RollbackDecision> EvaluateRollbackNeedAsync(
        RetryStage stage,
        BuilderContext context,
        Task failedTask)
    {
        return stage switch
        {
            RetryStage.FIX_LEVEL => RollbackDecision.Continue(), // No rollback - local fix
            
            RetryStage.INTEGRATION_LEVEL => RollbackDecision.Continue(), // No rollback - wiring fix
            
            RetryStage.ARCHITECTURE_LEVEL => await CreateCheckpointSnapshotAsync(context),
            
            RetryStage.ABORT => await RollbackToLastStableAsync(context),
            
            _ => RollbackDecision.Continue()
        };
    }
    
    private async Task<RollbackDecision> CreateCheckpointSnapshotAsync(BuilderContext context)
    {
        // Before architectural changes, create safety checkpoint
        var snapshotId = await _snapshotService.CreateSnapshotAsync(
            context.ProjectPath,
            reason: "Pre-Architecture-Retry"
        );
        
        return RollbackDecision.CheckpointCreated(snapshotId);
    }
    
    private async Task<RollbackDecision> RollbackToLastStableAsync(BuilderContext context)
    {
        var lastStable = context.LastStableSnapshotHash;
        
        if (string.IsNullOrEmpty(lastStable))
        {
            // No stable snapshot - catastrophic failure
            return RollbackDecision.CatastrophicFailure("No stable snapshot available for rollback");
        }
        
        await _snapshotService.RollbackAsync(lastStable);
        await _roslynIndexer.ReindexProjectAsync(context.ProjectPath); // Re-index after rollback
        
        return RollbackDecision.RolledBack(lastStable);
    }
}

public record RollbackDecision
{
    public bool ShouldRollback { get; init; }
    public string SnapshotId { get; init; }
    public string Reason { get; init; }
    
    public static RollbackDecision Continue() => new() { ShouldRollback = false };
    public static RollbackDecision CheckpointCreated(string snapshotId) => new() { ShouldRollback = false, SnapshotId = snapshotId };
    public static RollbackDecision RolledBack(string snapshotId) => new() { ShouldRollback = true, SnapshotId = snapshotId };
    public static RollbackDecision CatastrophicFailure(string reason) => new() { ShouldRollback = true, Reason = reason };
}
```

**Rollback Trigger Points:**

| Trigger | Action | Snapshot Used |
|---------|--------|---------------|
| FIX_LEVEL retry | None | Continue with current state |
| INTEGRATION_LEVEL retry | None | Continue with current state |
| ARCHITECTURE_LEVEL retry | Create checkpoint | New checkpoint created |
| ABORT | Full rollback | `LastStableSnapshotHash` |
| Graph integrity failure | Immediate rollback | `LastStableSnapshotHash` |
| User cancellation | No rollback | State preserved for resume |

### 7.5 Mutation Ceiling Enforcement

The `AgentExecutionContext` defines safety ceilings that MUST be enforced BEFORE any patch is committed:

```csharp
public class MutationCeilingEnforcer
{
    private readonly ICodeIndexer _indexer;
    
    /// <summary>
    /// Called by PatchEngine BEFORE applying any patch.
    /// Returns ValidationResult indicating if mutation is within bounds.
    /// </summary>
    public async Task<MutationValidationResult> ValidateMutationCeilingAsync(
        PatchOperation patch,
        AgentExecutionContext context)
    {
        var analysis = await AnalyzePatchImpactAsync(patch);
        
        // Check 1: Files touched ceiling
        if (analysis.FilesTouched.Count > context.MaxFilesTouchedPerTask)
        {
            return MutationValidationResult.ExceedsCeiling(
                $"Patch touches {analysis.FilesTouched.Count} files, " +
                $"exceeds limit of {context.MaxFilesTouchedPerTask}",
                ceilingType: "MaxFilesTouchedPerTask"
            );
        }
        
        // Check 2: Nodes modified ceiling
        if (analysis.NodesModified > context.MaxNodesModifiedPerTask)
        {
            return MutationValidationResult.ExceedsCeiling(
                $"Patch modifies {analysis.NodesModified} AST nodes, " +
                $"exceeds limit of {context.MaxNodesModifiedPerTask}",
                ceilingType: "MaxNodesModifiedPerTask"
            );
        }
        
        // Check 3: Breaking change detection
        if (analysis.HasBreakingChanges)
        {
            return MutationValidationResult.BreakingChangeDetected(
                analysis.BreakingChangeDescription
            );
        }
        
        return MutationValidationResult.WithinBounds(analysis);
    }
    
    private async Task<PatchImpactAnalysis> AnalyzePatchImpactAsync(PatchOperation patch)
    {
        // Use Roslyn to analyze the patch before applying
        var targetFile = await _indexer.GetSyntaxTreeAsync(patch.TargetFile);
        var simulatedPatch = SimulatePatch(targetFile, patch);
        
        return new PatchImpactAnalysis
        {
            FilesTouched = new List<string> { patch.TargetFile },
            NodesModified = CountModifiedNodes(targetFile, simulatedPatch),
            HasBreakingChanges = DetectBreakingChanges(targetFile, simulatedPatch),
            BreakingChangeDescription = DescribeBreakingChanges(targetFile, simulatedPatch)
        };
    }
}

public record MutationValidationResult
{
    public bool IsWithinBounds { get; init; }
    public string RejectionReason { get; init; }
    public string CeilingType { get; init; }
    public PatchImpactAnalysis Analysis { get; init; }
    
    public static MutationValidationResult WithinBounds(PatchImpactAnalysis analysis) => new() 
    { 
        IsWithinBounds = true, 
        Analysis = analysis 
    };
    
    public static MutationValidationResult ExceedsCeiling(string reason, string ceilingType) => new() 
    { 
        IsWithinBounds = false, 
        RejectionReason = reason,
        CeilingType = ceilingType
    };
    
    public static MutationValidationResult BreakingChangeDetected(string description) => new() 
    { 
        IsWithinBounds = false, 
        RejectionReason = description,
        CeilingType = "BreakingChange"
    };
}

public record PatchImpactAnalysis
{
    public List<string> FilesTouched { get; init; }
    public int NodesModified { get; init; }
    public bool HasBreakingChanges { get; init; }
    public string BreakingChangeDescription { get; init; }
}
```

**Integration Point:**

```csharp
// In PatchEngine.ApplyPatchAsync()
public async Task<PatchResult> ApplyPatchAsync(PatchOperation patch)
{
    // 1. ENFORCE MUTATION CEILING (before any work)
    var ceilingCheck = await _mutationCeilingEnforcer.ValidateMutationCeilingAsync(
        patch, 
        _agentExecutionContext
    );
    
    if (!ceilingCheck.IsWithinBounds)
    {
        _logger.LogWarning("Mutation ceiling exceeded: {Reason}", ceilingCheck.RejectionReason);
        return PatchResult.Rejected(ceilingCheck.RejectionReason);
    }
    
    // 2. Apply patch (existing logic)...
}
```

### 7.6 Memory Lifecycle Enforcement

Memory scopes must be disposed at specific lifecycle points to prevent leaks:

```csharp
public enum MemoryScope
{
    GLOBAL,      // Lives for app lifetime - never disposed
    PROJECT,     // Lives for project session - disposed on project close
    AGENT,       // Lives for agent execution - disposed when agent completes
    TASK,        // Lives for single task - disposed on task completion/failure
    RETRY        // Lives for single retry attempt - disposed after each retry
}

public class MemoryLifecycleManager
{
    private readonly ConcurrentDictionary<MemoryScope, Dictionary<string, object>> _scopes = new();
    
    /// <summary>
    /// Called by Orchestrator at specific lifecycle points.
    /// </summary>
    public void DisposeScope(MemoryScope scope, string projectId)
    {
        var scopeKey = $"{scope}:{projectId}";
        
        if (_scopes.TryRemove(scopeKey, out var scopeData))
        {
            // Dispose any IDisposable resources
            foreach (var item in scopeData.Values)
            {
                if (item is IDisposable disposable)
                {
                    disposable.Dispose();
                }
            }
            
            _logger.LogDebug("Disposed memory scope: {Scope} for project: {ProjectId}", scope, projectId);
        }
    }
    
    /// <summary>
    /// Called after each retry attempt to isolate retry memory.
    /// </summary>
    public void ClearRetryMemory(string projectId)
    {
        DisposeScope(MemoryScope.RETRY, projectId);
    }
    
    /// <summary>
    /// Called when task completes (success or failure).
    /// </summary>
    public void ClearTaskMemory(string projectId)
    {
        DisposeScope(MemoryScope.TASK, projectId);
        DisposeScope(MemoryScope.RETRY, projectId); // Also clear retry scope
    }
    
    /// <summary>
    /// Called when agent execution completes.
    /// </summary>
    public void ClearAgentMemory(string projectId)
    {
        DisposeScope(MemoryScope.AGENT, projectId);
        DisposeScope(MemoryScope.TASK, projectId);
        DisposeScope(MemoryScope.RETRY, projectId);
    }
}
```

**Integration Points:**

```csharp
// In Orchestrator - after task completion
private async Task FinalizeTaskAsync(Task task, BuilderContext context)
{
    // ... existing finalization logic ...
    
    // Clear task-scoped memory
    _memoryLifecycleManager.ClearTaskMemory(context.ProjectId);
}

// In RetryController - after each retry
private async Task PrepareRetryAsync(Task task, BuilderContext context)
{
    // Clear retry-scoped memory before new attempt
    _memoryLifecycleManager.ClearRetryMemory(context.ProjectId);
}

// In Orchestrator - on ABORT stage
private async Task HandleAbortAsync(Task task, BuilderContext context)
{
    // Clear all execution-scoped memory
    _memoryLifecycleManager.ClearAgentMemory(context.ProjectId);
    
    // ... rollback logic ...
}
```

**Memory Isolation Guarantee:**

| Scope | Disposed When | Purpose |
|-------|---------------|---------|
| GLOBAL | Never | App-wide caches, settings |
| PROJECT | Project close | Project-specific caches |
| AGENT | Agent completes | Agent context, generated plans |
| TASK | Task completes | Task-specific data, patches |
| RETRY | After each retry | Isolates retry attempts |


---

## 8. Execution Lifecycle

### 8.1 Phase 0 — Pre-Execution Guard

The Pre-Execution Guard runs **before** any AI planning or code generation begins. It ensures the system is in a valid state and prevents concurrent execution conflicts.

```csharp
// When user clicks Generate
public async Task SubmitGenerateRequestAsync(string prompt)
{
    // 1. Validate state
    if (_currentState != OrchestratorState.IDLE)
        throw new InvalidOperationException("Orchestrator busy");

    // 2. Lock workspace (mutex)
    await _workspaceLock.WaitAsync();

    // 3. Create ExecutionSession
    var session = new ExecutionSession
    {
        Id = Guid.NewGuid(),
        Prompt = prompt,
        StartTime = DateTime.UtcNow,
        CancellationToken = new CancellationTokenSource()
    };

    // 4. Transition state
    _currentState = OrchestratorState.AI_PLANNING;

    // 5. Queue for execution
    await _executionQueue.EnqueueAsync(session);
}
```

**ExecutionSession fields:**

- `SessionId`: Guid
- `ProjectPath`: string
- `Prompt`: string
- `RetryBudget`: int (default: 3 — maximum retry attempts per task node)

**OrchestratorLoop (governing lifecycle pattern):**

```csharp
// Orchestrator thread — ThreadPriority.AboveNormal
private readonly BlockingCollection<ExecutionSession> _sessionQueue = new();

void OrchestratorLoop()
{
    foreach (var session in _sessionQueue.GetConsumingEnumerable())
    {
        ProcessSessionAsync(session).GetAwaiter().GetResult();
    }
}
```

Thread priority set to `ThreadPriority.AboveNormal` to ensure responsive session dispatch.

### 8.2 Named Thread Types

The system uses a carefully designed threading model with 6 distinct thread types, each with specific responsibilities and constraints:

| Thread                               | Color  | Purpose                                        | Concurrency        |
| ------------------------------------ | ------ | ---------------------------------------------- | ------------------ |
| 🟢 **UI Thread**                     | Green  | Rendering, user input, never blocks            | Single (main)      |
| 🔵 **Orchestrator Thread**           | Blue   | Single background thread, sequential execution | Single             |
| 🟣 **AI Worker Thread Pool**         | Purple | AI code generation tasks                       | Max 2 concurrent   |
| 🟡 **Patch Worker Thread**           | Yellow | File mutations, requires exclusive file lock   | Single-threaded    |
| 🔴 **Build Worker Thread**           | Red    | MSBuild compilation, isolated and killable     | Single (per build) |
| ⚪ **Background Maintenance Thread** | White  | Low priority cleanup, runs only when idle      | Single             |

**Threading Rules:**

- UI Thread never performs blocking I/O
- Only Patch Worker modifies files
- Build Worker can be forcefully terminated
- Background Thread yields to all other threads

### 8.3 Thread Communication Model

All inter-thread communication follows strict patterns to prevent race conditions and deadlocks:

- **Channels or BlockingCollection** - All communication uses producer/consumer queues
- **Immutable command objects** - All messages are records (immutable by default)
- **Event-driven architecture** - No polling, only reactive event handling
- **CancellationToken everywhere** - All async operations support cancellation
- **Never share mutable state** - State changes only through message passing

```csharp
// Example: Thread-safe command passing
public record ExecuteTaskCommand(
    Guid TaskId,
    string Operation,
    Dictionary<string, object> Parameters,
    CancellationToken CancellationToken
);

// Channel-based communication
private readonly Channel<ExecuteTaskCommand> _orchestratorChannel =
    Channel.CreateUnbounded<ExecuteTaskCommand>();
```

### 8.4 Phase Flow

**Phase 1 — Spec Parsing (Orchestrator Thread)**

The GenerateCommand record is deserialized and validated. The AI model produces a structured JSON task graph. On schema validation failure, `CorrectTaskGraphAsync()` is invoked for one corrective round-trip before aborting.

**Phase 2 — Task Graph Construction (Orchestrator Thread)**

The validated JSON is materialized into a `TaskGraph` object. Dependency edges are resolved. State transitions: `SPEC_PARSED → TASK_GRAPH_READY`.

**Phase 3 — Task Execution Loop (Patch Worker + AI Worker Pool)**

Each task node is executed sequentially:

1. AI Worker generates patch via `GeneratePatchAsync()`
2. Patch Worker applies patch via `IPatchTransaction`
3. Roslyn performs `IncrementalIndexFileAsync()` (mandatory between patch and build)
4. Build Worker executes `BuildAsync()`
5. On build failure: `ParseBuildExceptions(buildResult.Exception)` → retry or abort
6. On retry: state transitions `TASK_EXECUTING → RETRYING → TASK_EXECUTING`

**Phase 4 — Validation (Build Worker)**

Full project build is executed. Output is validated against the original spec. State: `VALIDATING`.

**Phase 5 — Snapshot & Rollback (Orchestrator Thread)**

On success: `SnapshotService.CreateSnapshotAsync()` with `TriggerReason` recorded.
On failure after retry budget exhausted: `SnapshotService.RollbackAsync()` → full Roslyn `IndexProjectAsync()` re-index required after rollback. State transitions to `FAILED`.

**Phase 6 — Finalization (Orchestrator Thread)**

1. `ProjectVersion` entity written to database (Id, ProjectId, SnapshotId, Description, Timestamp)
2. `EventAggregator.PublishAsync(new PreviewRefreshEvent { ProjectPath = session.ProjectPath })` triggers Preview Service refresh
3. Session marked `COMPLETED`
4. Workspace lock (`_workspaceLock`) released — **Step 4 of finalization**

**Phase 7 — Packaging & Signing (Mandatory)**

This phase is mandatory for every successful generation, ensuring a deployable artifact.

```text
PATCH
↓
INDEX
↓
BUILD
↓
VALIDATE
↓
CAPABILITY_SCAN (MANDATORY)
↓
MANIFEST_UPDATE
↓
REBUILD_IF_REQUIRED
↓
PACKAGE
↓
SIGN
↓
VERIFY_SIGNATURE
↓
PACKAGING_SUCCEEDED
```

> Capability inference is mandatory for every build. Packaging is not optional.

### 8.5 Boot Sequence Stages

The application follows a strict 6-stage boot sequence to ensure all dependencies are properly initialized:

1. **Stage 1: App Startup**
   - `OnLaunched` event fires
   - Display splash screen
   - Initialize logging

2. **Stage 2: Environment Validation**
   - Verify .NET SDK installation
   - Check MSBuild availability via MSBuildLocator
   - Validate disk space (minimum 2GB free)

3. **Stage 3: Load Project Registry**
   - Read SQLite metadata
   - Validate snapshot integrity
   - Load recent projects list

4. **Stage 4: Initialize Services**
   - Orchestrator Engine
   - Roslyn Code Intelligence
   - Patch Engine
   - Build Kernel
   - AI Engine connection

5. **Stage 5: Warm-Up Index**
   - Pre-load last opened project symbols
   - Initialize semantic cache
   - Pre-warm embeddings

6. **Stage 6: UI Ready**
   - Fade out splash screen
   - Show MainPage
   - Enable user input

### 8.6 Safety Controls During Boot

Before completing boot, the system performs critical safety checks:

```csharp
await KillOrphanBuildProcessesAsync();
CleanLockFiles();
await TerminateStaleSessionsAsync();
// Check for incomplete session from crash
var incomplete = await _database.GetIncompleteSessionAsync();
if (incomplete != null)
    await HandleCrashRecoveryAsync(incomplete);
```

**Safety Operations:**

- Kill any orphaned build processes from previous crashes
- Clean stale lock files in workspace directories
- Terminate incomplete execution sessions
- Detect and recover from previous crash

### 8.7 Crash Recovery Flow

When an incomplete session is detected from a previous crash:

```csharp
private async Task HandleCrashRecoveryAsync(ExecutionSession incomplete)
{
    // 1. Detect incomplete ExecutionSession
    _logger.LogWarning("Detected incomplete session: {SessionId}", incomplete.Id);

    // 2. Rollback to last stable snapshot
    var lastStable = await _database.GetLastStableSnapshotAsync(incomplete.ProjectId);
    await _snapshotManager.RollbackAsync(lastStable.Id);

    // 3. Mark previous version as failed
    await _database.MarkVersionAsFailedAsync(incomplete.Id);

    // 4. Notify user gently
    await ShowToastAsync("We restored your project to a stable version.",
        severity: InfoBarSeverity.Informational);
}
```

**Recovery Steps:**

1. Log the detection of incomplete session
2. Automatically rollback to last stable snapshot
3. Mark the crashed version as failed in history
4. Show gentle notification to user (no technical details)

---

## 9. Background Systems

### 9.1 9 Lettered Hidden Systems (A-I)

The architecture includes 9 critical background systems that operate invisibly:

| Letter | System                            | Responsibility                                     |
| ------ | --------------------------------- | -------------------------------------------------- |
| **A**  | Deterministic Orchestrator Engine | State machine, task scheduling, retry logic        |
| **B**  | Roslyn Indexing Engine            | Real-time AST parsing, symbol graph maintenance    |
| **C**  | Structured Patch Engine           | Transactional code mutations, conflict detection   |
| **D**  | Snapshot & Rollback System        | Version control, differential backups, restore     |
| **E**  | Build Kernel Supervisor           | MSBuild orchestration, error classification        |
| **F**  | Silent Retry Loop                 | Automatic error recovery without user visibility   |
| **G**  | Memory Layer (SQLite)             | Persistent storage for decisions, patterns, errors |
| **H**  | Workspace Sandbox Manager         | File isolation, path validation, security          |
| **I**  | Resource Monitor                  | Disk space, memory, CPU throttling                 |

### 9.2 5 Background Processes

Continuous background processes ensure system health and performance:

| Process                       | Trigger                  | Purpose                                   |
| ----------------------------- | ------------------------ | ----------------------------------------- |
| **A. Project Graph Sync**     | FileSystemWatcher events | Keep symbol index synchronized with files |
| **B. Incremental Indexing**   | File change events       | Update embeddings for modified code       |
| **C. Snapshot Pruning**       | Scheduled (daily)        | Remove old snapshots to free disk space   |
| **D. AI Context Preparation** | Predictive loading       | Pre-fetch likely needed context           |
| **E. Environment Validation** | Periodic checks          | Verify SDK health, clear corrupted caches |

**ProjectGraphSync — File System Watcher:**

```csharp
public class ProjectGraphSync
{
    private readonly FileSystemWatcher _watcher;

    public ProjectGraphSync(string projectPath)
    {
        _watcher = new FileSystemWatcher(projectPath, "*.cs")
        {
            NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite,
            IncludeSubdirectories = true,
            EnableRaisingEvents = true
        };
        _watcher.Changed += OnFileChanged;
        _watcher.Created += OnFileCreated;
        _watcher.Deleted += OnFileDeleted;
    }

    private async void OnFileChanged(object sender, FileSystemEventArgs e)
    {
        await _graphDb.UpdateFileMetadataAsync(e.FullPath);
        await _roslynService.IncrementalIndexFileAsync(e.FullPath);
    }
    // OnFileCreated and OnFileDeleted follow same dual-call pattern
}
```

Monitors `*.cs` files only. `IncludeSubdirectories = true`. Each change triggers both `UpdateFileMetadataAsync` AND `IncrementalIndexFileAsync`.

### 9.3 What User SHOULD NEVER See

The following internal details are always hidden from users:

- ❌ Task graph structure
- ❌ Patch operations and diffs
- ❌ Roslyn AST tree
- ❌ MSBuild raw output
- ❌ NuGet package resolution logs
- ❌ Snapshot IDs and versions
- ❌ Retry counts and attempts
- ❌ File diffs (by default, available in advanced mode only)

---

## 10. Concurrency Rules

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

> **Scope Clarification**: "Strict serialization" applies only to **mutation operations** (code changes via Roslyn patches). Read-only operations like semantic queries, symbol lookups, and file indexing can run in parallel. The state machine serializes the PATCHING → INDEXING → BUILDING sequence, but not read access to the code intelligence system.

---

## 9. Build System

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
    public ErrorType ErrorType { get; set; }  // e.g. CSharpCompiler
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

#### ErrorType Enum (Simple Taxonomy)

```csharp
public enum ErrorType
{
    CSharpCompiler,         // CSxxxx
    XamlCompiler,           // XDGxxxx, XLSxxxx
    NuGetRestore,           // NUxxxx
    MSBuildInfrastructure,  // MSBxxxx
    ProjectFile,            // Missing .csproj, invalid XML
    Timeout,                // Build exceeded time limit
    Unknown                 // Unclassified
}
```

#### ErrorClassifier

```csharp
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

#### ErrorClassifier

```csharp
public class ErrorClassifier
{
    public ErrorType Classify(BuildErrorEventArgs error)
    {
        // 1. Check Error Code first (most reliable)
        if (!string.IsNullOrEmpty(error.Code))
        {
            if (error.Code.StartsWith("CS")) return ErrorType.CSharpCompiler;
            if (error.Code.StartsWith("XDG") || error.Code.StartsWith("XLS")) return ErrorType.XamlCompiler;
            if (error.Code.StartsWith("NU")) return ErrorType.NuGetRestore;
            if (error.Code.StartsWith("MSB")) return ErrorType.MSBuildInfrastructure;
        }

        // 2. Fallback to Project File analysis
        if (error.File != null && error.File.EndsWith(".csproj"))
        {
            return ErrorType.ProjectFile;
        }

        return ErrorType.Unknown;
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
                    ErrorType = ErrorType.MSBuildInfrastructure,
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
```

---

## 10. Error Handling

### 10.1 Error Handling Philosophy

#### Core Principles

1. **User Never Sees Technical Details** - All errors translated to user-friendly messages
2. **Silent Recovery When Possible** - Retry automatically before showing errors
3. **Actionable Guidance** - Every error message includes next steps
4. **Preserve User Work** - Never lose user data, always snapshot before risky operations
5. **Graceful Degradation** - System remains usable even with partial failures

#### Error Severity Levels

| Level        | User Impact           | UI Indicator        | Action Required      |
| ------------ | --------------------- | ------------------- | -------------------- |
| **Info**     | None                  | Blue info icon      | None                 |
| **Warning**  | Minor, non-blocking   | Yellow warning icon | Optional user action |
| **Error**    | Blocking, recoverable | Red error icon      | User must resolve    |
| **Critical** | System-level failure  | Red with alert      | Immediate attention  |

### 10.2 Error Classification Taxonomy

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

#### ErrorType

(Defined in Section 6)

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
    Unknown
}
```

#### FileSystemErrorType

```csharp
public enum FileSystemErrorType
{
    PathNotFound, PathTooLong, AccessDenied, DiskFull, FileInUse, InvalidFileName,
    SnapshotCreationFailed, SnapshotRestoreFailed, Unknown
}
```

#### PatchErrorType

```csharp
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
```

#### OrchestratorErrorType

```csharp
public enum OrchestratorErrorType
{
    InvalidStateTransition, TaskExecutionFailed, RetryBudgetExceeded, DependencyFailed,
    TimeoutExceeded, CancellationRequested, Unknown
}
```

### 10.3 Error Recovery Services

#### Build Error Recovery

```csharp
public class BuildErrorRecoveryService
{
    public async Task<RecoveryResult> RecoverFromBuildErrorAsync(BuildError error)
    {
        return error.ErrorType switch
        {
            ErrorType.CSharpCompiler => await RecoverFromSyntaxErrorAsync(error),
            ErrorType.XamlCompiler => await RecoverFromXamlErrorAsync(error),
            ErrorType.NuGetRestore => await RecoverFromNuGetErrorAsync(error),
            ErrorType.Timeout => await RecoverFromTimeoutAsync(error),
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

### 10.4 User-Facing Error Messages

```csharp
public class ErrorMessageProvider
{
    private readonly Dictionary<ErrorType, ErrorMessageTemplate> _buildErrorMessages = new()
    {
        [ErrorType.CSharpCompiler] = new ErrorMessageTemplate
        {
            Title = "Code Syntax Error",
            Message = "There's a syntax error in the generated code.",
            UserAction = "The system will attempt to fix this automatically. If the problem persists, try rephrasing your prompt.",
            Icon = "Error",
            Severity = ErrorSeverity.Error
        },

        [ErrorType.ProjectFile] = new ErrorMessageTemplate
        {
            Title = ".NET SDK Required",
            Message = "The .NET 8.0 SDK is not installed on your system.",
            UserAction = "Please download and install the .NET 8.0 SDK from the link below.",
            ActionButton = new ActionButton
            {
                Text = "Download .NET SDK",
                Url = "https://dotnet.microsoft.com/download/dotnet/8.0"
            },
            Icon = "Warning",
            Severity = ErrorSeverity.Critical
        },

        [ErrorType.Timeout] = new ErrorMessageTemplate
        {
            Title = "Build Timeout",
            Message = "The build is taking longer than expected.",
            UserAction = "The system will retry with a longer timeout. For complex projects, this may take a few minutes.",
            Icon = "Clock",
            Severity = ErrorSeverity.Warning
        }
    };

    public ErrorMessageTemplate GetMessageTemplate(ErrorType errorType)
    {
        return _buildErrorMessages.TryGetValue(errorType, out var template)
            ? template
            : GetDefaultTemplate();
    }

    private ErrorMessageTemplate GetDefaultTemplate() => new()
    {
        Title = "Unexpected Error",
        Message = "An unexpected error occurred.",
        UserAction = "Please try again. If the problem persists, check the logs for more details.",
        Icon = "Error",
        Severity = ErrorSeverity.Error
    };
}

public class ErrorMessageTemplate
{
    public string Title { get; set; }
    public string Message { get; set; }
    public string UserAction { get; set; }
    public ActionButton ActionButton { get; set; }
    public string Icon { get; set; }
    public ErrorSeverity Severity { get; set; }
}

public class ActionButton
{
    public string Text { get; set; }
    public string Url { get; set; }
    public Action OnClick { get; set; }
}
```

#### Error Dialog UI

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

### 10.5 Logging & Wiring Strategy

```csharp
public class ErrorLogger
{
    private readonly ILogger _logger;

    public void LogError(Exception ex, string message, params object[] args)
    {
        // Log to file
        _logger.LogError(ex, message, args);

        // Log to database for analytics
        _errorRepository.AddAsync(new ErrorLog
        {
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

public class GlobalExceptionHandler
{
    public void Initialize()
    {
        // Catch unhandled exceptions
        AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
        TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;
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

### 10.6 Error Prevention

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
}

public class ValidationResult
{
    public bool IsValid { get; set; }
    public string Message { get; set; }
    public bool IsWarning { get; set; }

    public static ValidationResult Success() => new ValidationResult { IsValid = true };
    public static ValidationResult Error(string message) => new ValidationResult { IsValid = false, Message = message };
    public static ValidationResult Warning(string message) => new ValidationResult { IsValid = true, IsWarning = true, Message = message };
}
````

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

    private async Task<List<string>> FindLockedFilesAsync(string projectPath)
    {
        var lockedFiles = new List<string>();
        var files = Directory.GetFiles(projectPath, "*.cs", SearchOption.AllDirectories)
            .Concat(Directory.GetFiles(projectPath, "*.csproj", SearchOption.AllDirectories));

        foreach (var file in files)
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
    public List<string> Issues { get; set; } = new List<string>();

    public static PreconditionResult Success() => new PreconditionResult { Success = true };
    public static PreconditionResult Failed(List<string> issues) => new PreconditionResult { Success = false, Issues = issues };
    public static PreconditionResult Failed(string issue) => new PreconditionResult { Success = false, Issues = new List<string> { issue } };
}
```

---

## 11. API Contracts

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
        "required": ["id", "type", "description", "targetFiles", "dependsOn"],
        "properties": {
          "id": { "type": "string" },
          "type": { "enum": ["INFRASTRUCTURE", "MODEL", "SERVICE", "UI", "INTEGRATION", "FIX"] },
          "description": { "type": "string" },
          "targetFiles": { "type": "array", "items": { "type": "string" } },
          "dependsOn": { "type": "array", "items": { "type": "string" } },
          "validationStrategy": { "enum": ["COMPILE", "UNIT_TEST", "XAML_PARSE"] }
        }
      }
    }
  }
}
```

---

## Appendix A: Supporting Types

### TaskResult Class

```csharp
public class TaskResult
{
    public bool Success { get; set; }
    public string TaskId { get; set; }
    public TimeSpan Duration { get; set; }
    public string ErrorMessage { get; set; }
    public List<string> ModifiedFiles { get; set; } = new();

    public static TaskResult Success(string taskId, List<string> modifiedFiles = null) =>
        new TaskResult { Success = true, TaskId = taskId, ModifiedFiles = modifiedFiles ?? new List<string>() };

    public static TaskResult Failed(string taskId, string errorMessage) =>
        new TaskResult { Success = false, TaskId = taskId, ErrorMessage = errorMessage };
}
```

---

## Appendix B: Implementation Sequence

This orchestrator must be implemented in this order:

### Phase 1A: Foundation (Mandatory before any other work)

1. Define `TaskType`, `ValidationStrategy`, `TaskStatus`, `ErrorType` enums
2. Define `Task` class (immutable where possible)
3. Define `BuilderState` enum
4. Define `BuilderContext` class
5. Define event record types
6. Implement `BuilderReducer.Reduce()` (pure function)

### Phase 1B: Orchestrator Control

7. Implement `RetryController` (budget tracking)
8. Implement `ConcurrencyPolicy` (no parallel mutations)
9. Implement `ErrorClassifier` (error categorization)

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

## Appendix C: Testing Strategy

### Integration Tests (Kernel Level)

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
}
```

### Unit Tests (Consumer Level)

Consumers of `IBuildService` (like Orchestrator) should mock the interface.

```csharp
[TestMethod]
public async Task Orchestrator_HandlesBuildFailure_Correctly()
{
    // Arrange
    var mockBuild = new Mock<IBuildService>();
    mockBuild.Setup(b => b.BuildAsync(It.IsAny<string>(), null, default))
             .ReturnsAsync(new BuildResult
             {
                 Success = false,
                 ErrorType = ErrorType.CSharpCompiler
             });

    var orchestrator = new Orchestrator(mockBuild.Object);

    // Act
    await orchestrator.RunTaskAsync(new BuildTask());

    // Assert
    // Verify remediation logic triggered
}
```

---

## Appendix D: Why This Matters

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

## Appendix E: Design Philosophy Connection

This orchestrator implements the **"hide complexity, show results"** principle at the system level:

- **Hidden Complexity**: Full task graph, retry loops, error classification all internal
- **Shown Results**: User sees progress indicator + final working app
- **Error Handling**: All failures self-corrected before user sees them
- **Determinism**: Invisibly perfect replay makes system feel magical

---

## Appendix F: Next Deliverables (In Order)

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
