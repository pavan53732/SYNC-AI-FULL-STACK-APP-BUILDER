# ORCHESTRATION ENGINE

> **Runtime Safety & Execution Kernel: State Machine, Task Lifecycle, Build System, Retry Logic & Concurrency Safety**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).

---

## Table of Contents

1. [Core Challenge & Positioning](#1-core-challenge--positioning)
2. [Task Schema](#2-task-schema)
3. [State Machine](#3-state-machine)
4. [State Container & Event Log](#4-state-container--event-log)
5. [State Reducer](#5-state-reducer)
6. [Error Classification & Intelligence](#6-error-classification--intelligence)
7. [Retry Controller](#7-retry-controller)
8. [Execution Lifecycle](#8-execution-lifecycle)
9. [Concurrency Rules](#9-concurrency-rules)
10. [API Contracts](#10-api-contracts)

---

## 1. Core Challenge & Positioning

### Why the Runtime Safety Kernel Must Exist

**Priority**: 🔴 **FIRST DELIVERABLE** — The enforcement layer that guarantees deterministic execution.

The Runtime Safety Kernel (Orchestrator) is the **enforcement layer** that validates all AI-driven construction.

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
✓ One active task at a time (strict serialization for mutation execution)
✓ Bounded autonomous refinement (max 10 retries with staged escalation)
✓ Immutable state transitions (functional programming)
✓ Full event log for replay/debug (deterministic replay)
✓ Deterministic termination (FAILED state with rollback on exhaustion)
```

---

## 2. Task Schema

### Task Types (Strict Contract)

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
    REFACTOR_FILE,
    GENERATE_MANIFEST,
    INFER_CAPABILITIES,
    CONFIGURE_PACKAGING,
    GENERATE_CERTIFICATE,
    SIGN_PACKAGE,
    BUILD_MSIX
}

public enum TaskStatus
{
    PENDING, RUNNING, VALIDATING, RETRYING, COMPLETED, FAILED
}
```

### Task Class

```csharp
public class Task
{
    public string Id { get; }
    public int Version { get; } = 1;
    public TaskType Type { get; }
    public string Description { get; }

    // Dependencies
    public List<string> DependsOnTaskIds { get; }
    public List<string> TargetFiles { get; }

    // Validation configuration
    public ValidationStrategy Validation { get; }
    public TimeSpan ValidationTimeout { get; }

    // Retry tracking
    public int RetryCount { get; set; }
    public string? LastPatchHash { get; set; }

    // State
    public TaskStatus Status { get; set; }
    public ErrorType? LastError { get; set; }
    public string? ErrorMessage { get; set; }

    // Audit trail
    public DateTime CreatedAt { get; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public List<string> ActionLog { get; } = new();
}
```

### ValidationStrategy Enum

```csharp
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
```

---

## 2.1 AgentExecutionContext Injection Rule (MANDATORY)

> **INVARIANT**: `AgentExecutionContext` MUST be injected into `BuilderContext` before any task execution begins. Without this, mutation ceilings cannot be enforced.

### Injection Sequence

```
1. Task dequeued from execution queue
2. Orchestrator creates AgentExecutionContext:
   a. Map TaskType → AgentRole
   b. Set TaskId from current task
   c. Set AllowedFilePatterns based on AgentRole
   d. Set MaxFilesTouchedPerTask, MaxNodesModifiedPerTask from defaults
3. Call BuilderContext.SetActiveAgentContext(context)
4. Call BuilderContext.ValidateAgentContext() — throws if null
5. Transition to EXECUTING_TASK state
```

---

## 3. State Machine

### Builder States

```csharp
public enum BuilderState
{
    IDLE = 0,
    BLUEPRINT_DESIGN = 1,
    BLUEPRINT_READY = 2,
    EXECUTION_PLAN_BUILDING = 3,
    EXECUTION_PLAN_BUILT = 4,
    MUTATION_GUARD = 5,
    PATCHING = 6,
    INDEXING = 7,
    BUILDING = 8,
    VALIDATING = 9,
    RETRYING = 10,
    EXECUTING_TASK = 11,
    BUILD_SUCCEEDED = 12,
    FAILED = 13,
    PACKAGING = 14,
    PACKAGING_SUCCEEDED = 15,
    PACKAGING_FAILED = 16,
    CAPABILITY_CHECK = 17,
    MANIFEST_UPDATING = 18,
    REBUILD_REQUIRED = 19,
    SIGNING = 20,
    SIGNATURE_VALIDATION = 21,
    ENVIRONMENT_RECOVERY = 22
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
PATCHING
  ↓ (patch applied)
INDEXING
  ↓ (index updated)
BUILDING
  ↓ (build complete)
VALIDATING
  │
  ├──(validation succeeds)──→ BUILD_SUCCEEDED
  │                                ↓
  │                           CAPABILITY_CHECK
  │                                ↓
  │                           PACKAGING
  │                                ↓
  │                           PACKAGING_SUCCEEDED
  │
  └──(validation fails)──→ RETRYING
                              │
                              ├──(retry < 10)──→ EXECUTING_TASK ──→ MUTATION_GUARD
                              │
                              └──(retry >= 10)──→ FAILED
                                         │
                                         ↓
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

    // Runtime Safety: Agent Execution Context
    public AgentExecutionContext? ActiveAgentContext { get; set; }

    // Safety Ceilings
    public int MaxFilesTouchedPerTask => ActiveAgentContext?.MaxFilesTouchedPerTask ?? 5;
    public int MaxNodesModifiedPerTask => ActiveAgentContext?.MaxNodesModifiedPerTask ?? 100;

    // Snapshot tracking for rollback
    public string? SemanticSnapshotHash { get; set; }
    public string? LastStableSnapshotHash { get; set; }

    // Debug info
    public List<string> DebugLog { get; } = new();
    public DateTime StartTime { get; } = DateTime.Now;

    // Context Validation
    public void ValidateAgentContext()
    {
        if (ActiveAgentContext == null)
        {
            throw new InvalidOperationException(
                "AgentExecutionContext must be injected into BuilderContext before task execution.");
        }
    }
}
```

### Event Types (Replayable & Debuggable)

```csharp
public abstract record BuilderEvent
{
    public DateTime Timestamp { get; init; } = DateTime.Now;
    public int EventSequence { get; init; }
}

// Task execution events
public record TaskStartedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public TaskType TaskType { get; init; }
}

public record TaskPatchedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public List<string> ModifiedFiles { get; init; }
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

// Terminal failure events
public record BuildFailedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public string Reason { get; init; }
    public ErrorClassification Error { get; init; }
    public int TotalRetries { get; init; }
    public string? RollbackSnapshotId { get; init; }
}
```

---

## 5. State Reducer

The reducer is a **pure function** that takes (state, event) → new state.

```csharp
public class BuilderReducer
{
    public static BuilderContext Reduce(BuilderContext context, BuilderEvent @event)
    {
        return (context.State, @event) switch
        {
            // Task Execution
            (BuilderState.EXECUTION_PLAN_BUILT, TaskStartedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.MUTATION_GUARD, @event),

            (BuilderState.MUTATION_GUARD, TaskGuardPassedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.PATCHING, @event),

            (BuilderState.PATCHING, TaskPatchedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.INDEXING, @event),

            (BuilderState.INDEXING, TaskIndexedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.BUILDING, @event),

            (BuilderState.BUILDING, TaskValidatingEvent e) =>
                context with { State = BuilderState.VALIDATING },

            // Success Path
            (BuilderState.VALIDATING, TaskCompletedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.EXECUTION_PLAN_BUILT, @event),

            // Failure & Retry Path
            (BuilderState.VALIDATING, TaskFailedEvent e) =>
                context with { State = BuilderState.RETRYING, EventLog = [..context.EventLog, @event] },

            (BuilderState.RETRYING, TaskStartedEvent e) =>
                context with { State = BuilderState.EXECUTING_TASK, EventLog = [..context.EventLog, @event] },

            // Completion
            (BuilderState.EXECUTION_PLAN_BUILT, BuildCompletedEvent e) =>
                context with { State = BuilderState.BUILD_SUCCEEDED, EventLog = [..context.EventLog, @event] },

            // Invalid Transition
            _ => throw new InvalidOperationException($"Invalid transition: {context.State} + {@event.GetType().Name}")
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
                BuilderState.EXECUTION_PLAN_BUILT => TaskStatus.COMPLETED,
                _ => task.Status
            };
        }

        return context with
        {
            State = newState,
            CurrentTaskId = newState == BuilderState.EXECUTION_PLAN_BUILT ? null : taskId,
            EventLog = [..context.EventLog, @event]
        };
    }
}
```

---

## 6. Error Classification & Intelligence

### ErrorClassification Record

```csharp
public record ErrorClassification
{
    public ErrorType Type { get; init; }
    public string Message { get; init; }
    public string FilePath { get; init; }
    public int? LineNumber { get; init; }
    public string AutoFixStrategy { get; init; }
    public bool IsRetryable { get; init; }
}
```

### ErrorType Enum

```csharp
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

### Pre-Retry Intelligence

Error classification must happen **BEFORE** any retry decision is made:

1. **Capture**: Retrieve raw error from build/execution result.
2. **Classify**: Map raw error to `ErrorClassification` record.
3. **Analyze**: Determine `IsRetryable` and `AutoFixStrategy`.
4. **Decide**: Pass to `RetryController`.

---

## 7. Retry Controller

### Retry Stages

```csharp
public enum RetryStage
{
    FIX_LEVEL,          // Stage 1: Try local token repairs
    INTEGRATION_LEVEL,  // Stage 2: Check DI and wiring
    ARCHITECTURE_LEVEL, // Stage 3: Re-evaluate high-level plan
    ABORT               // Stage 4: Rollback and Fail
}
```

### Retry Controller Logic

```csharp
public class RetryController
{
    public static BuilderContext ExecuteRetry(BuilderContext context, Task failedTask, ErrorClassification error)
    {
        failedTask.RetryCount++;

        var stage = DetermineStage(failedTask.RetryCount);

        if (stage == RetryStage.ABORT)
        {
            var abortEvent = new BuildFailedEvent
            {
                TaskId = failedTask.Id,
                Reason = "Max retries exceeded.",
                Error = error
            };
            return context with { State = BuilderState.FAILED, EventLog = [..context.EventLog, abortEvent] };
        }

        var retryEvent = new RetryStartedEvent
        {
            TaskId = failedTask.Id,
            CurrentRetry = failedTask.RetryCount,
            Stage = stage,
            PreviousError = error.Type
        };

        return context with { State = BuilderState.RETRYING, EventLog = [..context.EventLog, retryEvent] };
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

### Escalation Rules

| Stage | Range | Behavior |
|-------|-------|----------|
| FIX_LEVEL | 1-3 | Fix Agent attempts local token repairs |
| INTEGRATION_LEVEL | 4-6 | Integration Agent reviews DI registration |
| ARCHITECTURE_LEVEL | 7-9 | Architect Agent re-evaluates the plan |
| ABORT | 10+ | System stops, rolls back, asks user for help |

### Retry Governance Contract

> **AI owns the retry strategy. The Kernel enforces hard ceilings.**

| Retry Range | Owner | Enforcement | Behavior |
|-------------|-------|-------------|----------|
| 1-9 | AI Construction Engine | Strategy flexible | AI adapts, learns, retries |
| 10+ | Runtime Safety Kernel | Hard abort + rollback | System stops, user notified |

---

## 8. Execution Lifecycle

### Named Thread Types

| Thread | Color | Purpose | Concurrency |
|--------|-------|---------|-------------|
| 🟢 UI Thread | Green | Rendering, user input, never blocks | Single (main) |
| 🔵 Orchestrator Thread | Blue | Single background thread, sequential execution | Single |
| 🟣 AI Worker Thread Pool | Purple | AI code generation tasks | Max 2 concurrent |
| 🟡 Patch Worker Thread | Yellow | File mutations, requires exclusive file lock | Single-threaded |
| 🔴 Build Worker Thread | Red | MSBuild compilation, isolated and killable | Single (per build) |
| ⚪ Background Maintenance Thread | White | Low priority cleanup, runs only when idle | Single |

### Phase Flow

**Phase 1 — Spec Parsing (Orchestrator Thread)**

**Phase 2 — Task Graph Construction (Orchestrator Thread)**

**Phase 3 — Task Execution Loop (Patch Worker + AI Worker Pool)**

**Phase 4 — Validation (Build Worker)**

**Phase 5 — Snapshot & Rollback (Orchestrator Thread)**

**Phase 6 — Finalization (Orchestrator Thread)**

**Phase 7 — Packaging & Signing (Mandatory)**

### Boot Sequence Stages

1. **Stage 1: App Startup** — OnLaunched event, splash screen
2. **Stage 2: Environment Validation** — Verify .NET SDK, MSBuild
3. **Stage 3: Load Project Registry** — Read SQLite metadata
4. **Stage 4: Initialize Services** — Orchestrator, Roslyn, Patch Engine
5. **Stage 5: Warm-Up Index** — Pre-load symbols
6. **Stage 6: UI Ready** — Show MainPage

---

## 9. Concurrency Rules

### Strict Serialization

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
            throw new InvalidOperationException("Cannot start mutation task while another task is executing.");
        }
    }
}
```

**Iron Law**: Only 1 mutation task at a time. No parallel Roslyn patching. Reads can be parallel. Writes must be serial.

### Concurrency Matrix

| Operation | Can Run With | Cannot Run With | Lock Type |
|-----------|--------------|-----------------|-----------|
| **Patching (Mutation)** | Nothing | All other operations | Exclusive Write Lock |
| **Indexing** | Read queries | Mutation, Build | Shared Read Lock |
| **Building** | Nothing | All other operations | Exclusive Build Lock |
| **Read Queries** | All read operations | Mutation | Shared Read Lock |

---

## 10. API Contracts

### Orchestrator Service (IOrchestrator)

```csharp
public interface IOrchestrator
{
    Task<BuilderState> DispatchAsync(BuilderEvent @event);
    Task<TaskResult> ExecuteTaskAsync(TaskDefinition task);
    BuilderContext GetCurrentContext();
}
```

### Supporting Types

```csharp
public class TaskResult
{
    public bool Success { get; set; }
    public string TaskId { get; set; }
    public TimeSpan Duration { get; set; }
    public string ErrorMessage { get; set; }
    public List<string> ModifiedFiles { get; set; } = new();

    public static TaskResult Success(string taskId, List<string> modifiedFiles = null) =>
        new() { Success = true, TaskId = taskId, ModifiedFiles = modifiedFiles ?? new List<string>() };

    public static TaskResult Failed(string taskId, string errorMessage) =>
        new() { Success = false, TaskId = taskId, ErrorMessage = errorMessage };
}
```

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 7-layer overview, deployment model
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn indexing, symbol graph, patch engine
- [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — AI Construction Engine vs Runtime Safety Kernel
- [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) — Sandbox, MSBuild, filesystem isolation
- [WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md](./WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md) — Manifest, capability inference, MSIX