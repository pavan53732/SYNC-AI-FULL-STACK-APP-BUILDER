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
10. [Snapshot Authority](#10-snapshot-authority)
11. [API Contracts](#11-api-contracts)

---

## 1. Core Challenge & Positioning

### Why the Runtime Safety Kernel Must Exist

**Priority**: 🔴 **FIRST DELIVERABLE** — The enforcement layer that guarantees deterministic execution.

The Runtime Safety Kernel (Orchestrator) is the **enforcement layer** that validates all AI-driven construction.

**Key Principle**: The Runtime Safety Kernel enforces deterministic execution guarantees for AI-driven construction operations.

> **AI leads, Kernel enforces.** The AI Construction Engine proposes mutations; the Kernel validates, snapshots, and guarantees safety.

### Core Principles

```
✓ No implicit transitions
✓ No uncontrolled parallel mutation
✓ One active task at a time (strict serialization for mutation execution)
✓ Bounded autonomous refinement (max 10 retries with staged escalation)
✓ Immutable state transitions (functional programming)
✓ Full event log for replay/debug (deterministic replay)
✓ Deterministic termination (FAILED state with rollback on exhaustion)
✓ Snapshot BEFORE mutation (MANDATORY - enables rollback)
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
    
    // === TASK EXECUTION PIPELINE (FIXED ORDER) ===
    AI_GENERATING = 5,           // NEW: AI generates code
    CREATING_SNAPSHOT = 6,       // NEW: Snapshot BEFORE mutation (MANDATORY)
    MUTATION_GUARD = 7,          // Validate mutation safety
    PATCHING = 8,                // Apply AST transformation
    INDEXING = 9,                // Update semantic graph
    CAPABILITY_SCAN = 10,        // NEW: Capability inference BEFORE build (for Release)
    BUILDING = 11,               // MSBuild compilation
    VALIDATING = 12,             // Final integrity check
    
    // === RETRY & RESULT ===
    RETRYING = 13,
    EXECUTING_TASK = 14,
    BUILD_SUCCEEDED = 15,
    FAILED = 16,                 // Terminal failure state
    
    // === PACKAGING PHASE ===
    PACKAGING = 17,
    PACKAGING_SUCCEEDED = 18,
    PACKAGING_FAILED = 19,
    MANIFEST_UPDATING = 20,
    REBUILD_REQUIRED = 21,
    SIGNING = 22,
    SIGNATURE_VALIDATION = 23,
    ENVIRONMENT_RECOVERY = 24
}
```

### State Diagram (FIXED - Addresses Contradictions 1, 3, 7)

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
  
  ╔═══════════════════════════════════════════════════════════════╗
  ║  TASK EXECUTION PIPELINE (STRICT ORDER)                      ║
  ╠═══════════════════════════════════════════════════════════════╣
  ║                                                               ║
  ║  AI_GENERATING                                               ║
  ║    ↓ (AI completes code generation)                          ║
  ║  CREATING_SNAPSHOT  ← MANDATORY: Snapshot BEFORE mutation    ║
  ║    ↓ (snapshot created successfully)                          ║
  ║  MUTATION_GUARD                                              ║
  ║    ↓ (guard safe)                                            ║
  ║  PATCHING                                                     ║
  ║    ↓ (patch applied)                                          ║
  ║  INDEXING                                                     ║
  ║    ↓ (index updated)                                          ║
  ║  CAPABILITY_SCAN  ← Proactive: BEFORE build for Release      ║
  ║    ↓ (capabilities inferred/updated)                          ║
  ║  BUILDING                                                     ║
  ║    ↓ (build complete)                                         ║
  ║  VALIDATING                                                   ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
  │
  ├──(validation succeeds)──→ BUILD_SUCCEEDED
  │                                ↓
  │                           PACKAGING
  │                                ↓
  │                           PACKAGING_SUCCEEDED
  │
  └──(validation fails)──→ RETRYING
                              │
                              ├──(retry < 10)──→ EXECUTING_TASK ──→ AI_GENERATING
                              │
                              └──(retry >= 10)──→ FAILED
                                         │
                                         ↓
                                    ROLLBACK TO SNAPSHOT
                                    (Created at CREATING_SNAPSHOT state)
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

    // Task execution - SINGLE TASK AT A TIME (Fixes Contradiction 6)
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

    // Snapshot tracking for rollback (Fixes Contradiction 1)
    public string? PreMutationSnapshotId { get; set; }      // Snapshot created BEFORE current task
    public string? LastStableSnapshotHash { get; set; }     // Hash of last verified build

    // Build mode (affects capability inference timing)
    public BuildMode CurrentBuildMode { get; set; } = BuildMode.DEBUG;

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

public enum BuildMode
{
    DEBUG,    // Reactive capability inference (after build failure)
    RELEASE   // Proactive capability inference (before build)
}
```

### Event Types (Replayable & Debuggable)

```csharp
public abstract record BuilderEvent
{
    public DateTime Timestamp { get; init; } = DateTime.Now;
    public int EventSequence { get; init; }
}

// Snapshot Events (Fixes Contradiction 1)
public record SnapshotCreatedEvent : BuilderEvent
{
    public string SnapshotId { get; init; }
    public string Reason { get; init; }  // "Pre-Mutation", "Pre-Packaging", "Manual"
    public string TaskId { get; init; }
}

// Task execution events
public record TaskStartedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public TaskType TaskType { get; init; }
}

public record AIGenerationCompletedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public string GeneratedPatchHash { get; init; }
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

// Retry events (Fixes Contradiction 4 - All retries logged)
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

// Capability scan events (Fixes Contradiction 7)
public record CapabilityScanCompletedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public List<string> DetectedCapabilities { get; init; }
    public List<string> AddedCapabilities { get; init; }
    public bool ManifestUpdated { get; init; }
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
            // === AI GENERATION (Fixes Contradiction 3) ===
            (BuilderState.EXECUTION_PLAN_BUILT, TaskStartedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.AI_GENERATING, @event),

            (BuilderState.AI_GENERATING, AIGenerationCompletedEvent e) =>
                context with { State = BuilderState.CREATING_SNAPSHOT, EventLog = [..context.EventLog, @event] },

            // === SNAPSHOT CREATION (Fixes Contradiction 1) ===
            (BuilderState.CREATING_SNAPSHOT, SnapshotCreatedEvent e) =>
                context with 
                { 
                    State = BuilderState.MUTATION_GUARD, 
                    PreMutationSnapshotId = e.SnapshotId,
                    EventLog = [..context.EventLog, @event] 
                },

            // === MUTATION PIPELINE ===
            (BuilderState.MUTATION_GUARD, TaskGuardPassedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.PATCHING, @event),

            (BuilderState.PATCHING, TaskPatchedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.INDEXING, @event),

            (BuilderState.INDEXING, TaskIndexedEvent e) =>
                context with { State = BuilderState.CAPABILITY_SCAN, EventLog = [..context.EventLog, @event] },

            // === CAPABILITY SCAN (Fixes Contradiction 7) ===
            (BuilderState.CAPABILITY_SCAN, CapabilityScanCompletedEvent e) =>
                context with { State = BuilderState.BUILDING, EventLog = [..context.EventLog, @event] },

            (BuilderState.BUILDING, TaskValidatingEvent e) =>
                context with { State = BuilderState.VALIDATING },

            // === SUCCESS PATH ===
            (BuilderState.VALIDATING, TaskCompletedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.EXECUTION_PLAN_BUILT, @event),

            // === FAILURE & RETRY PATH (Fixes Contradiction 4 - All logged) ===
            (BuilderState.VALIDATING, TaskFailedEvent e) =>
                context with { State = BuilderState.RETRYING, EventLog = [..context.EventLog, @event] },

            (BuilderState.RETRYING, TaskStartedEvent e) =>
                context with { State = BuilderState.EXECUTING_TASK, EventLog = [..context.EventLog, @event] },

            // === ABORT (Uses PreMutationSnapshotId for rollback) ===
            (BuilderState.RETRYING, BuildFailedEvent e) when e.TotalRetries >= 10 =>
                HandleAbortWithRollback(context, e),

            // === COMPLETION ===
            (BuilderState.EXECUTION_PLAN_BUILT, BuildCompletedEvent e) =>
                context with { State = BuilderState.BUILD_SUCCEEDED, EventLog = [..context.EventLog, @event] },

            // === INVALID TRANSITION ===
            _ => throw new InvalidOperationException($"Invalid transition: {context.State} + {@event.GetType().Name}")
        };
    }

    private static BuilderContext HandleAbortWithRollback(BuilderContext context, BuildFailedEvent @event)
    {
        // Rollback to the snapshot created BEFORE mutation
        // This is possible because we MANDATE CREATING_SNAPSHOT state before PATCHING
        return context with
        {
            State = BuilderState.FAILED,
            EventLog = [..context.EventLog, @event]
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
    BUILD_ERROR,
    XAML_ERROR,
    NUGET_ERROR,
    PATCH_CONFLICT,
    VALIDATION_TIMEOUT,
    MANIFEST_ERROR,
    CAPABILITY_ERROR,
    SIGNING_ERROR,
    PACKAGING_ERROR,
    RUNTIME_PREVIEW_ERROR,
    SANDBOX_ESCAPE_ATTEMPT,
    PROCESS_CRASH
}
```

---

## 7. Retry Controller

### Retry Ownership (Fixes Contradiction 4)

> **INVARIANT**: The Orchestrator is the ONLY component that manages retry loops. Agents MUST NOT have internal retry loops. Agents attempt a fix ONCE and return. The Orchestrator decides whether to retry.

### Retry Stages

```csharp
public enum RetryStage
{
    FIX_LEVEL,          // Stage 1: Try local token repairs (retries 1-3)
    INTEGRATION_LEVEL,  // Stage 2: Check DI and wiring (retries 4-6)
    ARCHITECTURE_LEVEL, // Stage 3: Re-evaluate high-level plan (retries 7-9)
    ABORT               // Stage 4: Rollback and Fail (retry 10+)
}
```

### Retry Controller Logic

```csharp
public class RetryController
{
    /// <summary>
    /// Orchestrator-managed retry. All attempts are logged to EventLog.
    /// Agents do NOT manage their own retries.
    /// </summary>
    public static BuilderContext ExecuteRetry(BuilderContext context, Task failedTask, ErrorClassification error)
    {
        failedTask.RetryCount++;

        var stage = DetermineStage(failedTask.RetryCount);

        if (stage == RetryStage.ABORT)
        {
            var abortEvent = new BuildFailedEvent
            {
                TaskId = failedTask.Id,
                Reason = "Max retries exceeded. Rolling back to pre-mutation snapshot.",
                Error = error,
                TotalRetries = failedTask.RetryCount,
                RollbackSnapshotId = context.PreMutationSnapshotId
            };
            return context with { State = BuilderState.FAILED, EventLog = [..context.EventLog, abortEvent] };
        }

        // Log every retry attempt (Fixes Contradiction 4)
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

### Retry Governance Contract

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
| 🔵 Orchestrator Thread | Blue | Sequential execution, state machine | Single |
| 🟣 AI Worker Thread Pool | Purple | AI code generation tasks | Max 2 concurrent |
| 🟡 Patch Worker Thread | Yellow | File mutations, requires exclusive file lock | Single-threaded |
| 🔴 Build Worker Thread | Red | MSBuild compilation, isolated | Single (per build) |
| ⚪ Background Maintenance | White | Low priority cleanup | Single |

### Phase Flow

**Phase 1 — Spec Parsing (Orchestrator Thread)**

**Phase 2 — Task Graph Construction (Orchestrator Thread)**

**Phase 3 — Task Execution Loop (SERIALIZED - Fixes Contradiction 6)**
1. AI_GENERATING - AI generates code
2. CREATING_SNAPSHOT - Snapshot BEFORE mutation
3. MUTATION_GUARD - Validate safety
4. PATCHING - Apply transformation
5. INDEXING - Update semantic graph
6. CAPABILITY_SCAN - Proactive capability inference
7. BUILDING - Compile
8. VALIDATING - Check integrity

**Phase 4 — Finalization (Orchestrator Thread)**

**Phase 5 — Packaging & Signing (Mandatory)**

### DAG Execution Clarification (Fixes Contradiction 6)

> **The DAG shows PLANNING dependencies, not EXECUTION parallelism.**
>
> - Tasks at the same DAG level indicate they CAN theoretically run in parallel
> - BUT the Orchestrator executes them SEQUENTIALLY (one at a time)
> - This ensures deterministic state and safe rollback
> - `BuilderContext.CurrentTaskId` is always a single value, not a list

```csharp
// DAG planner outputs parallelizable structure
// Orchestrator flattens to sequential execution

public class SequentialExecutionStrategy
{
    public IEnumerable<Task> FlattenForExecution(TaskGraph dag)
    {
        // Topological sort ensures dependencies are respected
        // But execution is strictly sequential
        foreach (var task in dag.TopologicalSort())
        {
            yield return task;
        }
    }
}
```

---

## 9. Concurrency Rules

### Concurrency Matrix (Fixes Contradiction 5)

| Operation | Can Run With | Cannot Run With | Lock Type |
|-----------|--------------|-----------------|-----------|
| **Patching (Mutation)** | Nothing | All other operations | Exclusive Write Lock |
| **Indexing** | Read queries | Mutation, Build | **Exclusive Write Lock** (FIXED) |
| **Building** | Nothing | All other operations | Exclusive Build Lock |
| **Read Queries** | All read operations | Mutation | Shared Read Lock |
| **AI Generation** | Other AI Generation | Mutation, Build | None (stateless) |

### Why Indexing Requires Exclusive Write Lock

> Indexing WRITES to `project_graph.db`. SQLite requires exclusive access during writes. The previous "Shared Read Lock" was incorrect and would cause database corruption.

```csharp
public class ConcurrencyPolicy
{
    public static LockType GetRequiredLock(OperationType operation) => operation switch
    {
        OperationType.Mutation => LockType.ExclusiveWrite,
        OperationType.Indexing => LockType.ExclusiveWrite,  // FIXED: Was SharedRead
        OperationType.Build => LockType.ExclusiveBuild,
        OperationType.ReadQuery => LockType.SharedRead,
        OperationType.AIGeneration => LockType.None,
        _ => LockType.SharedRead
    };
}
```

---

## 10. Snapshot Authority

### Snapshot Timing Invariant (Fixes Contradiction 1)

> **INVARIANT**: A snapshot MUST be created BEFORE any mutation. This is enforced by the `CREATING_SNAPSHOT` state in the state machine.

### Snapshot Creation Points

| Trigger | State | Purpose |
|---------|-------|---------|
| Before PATCHING | `CREATING_SNAPSHOT` | Enable rollback on failure |
| Before PACKAGING | `CREATING_SNAPSHOT` | Enable rollback on packaging failure |
| Manual user request | Any non-mutation state | User-initiated checkpoint |

### Snapshot Lifecycle

```
1. AI_GENERATING completes
2. State transitions to CREATING_SNAPSHOT
3. SnapshotService.CreateSnapshotAsync() called
4. SnapshotCreatedEvent emitted with snapshot ID
5. PreMutationSnapshotId stored in BuilderContext
6. State transitions to MUTATION_GUARD
7. If PATCHING fails and retries exhausted:
   - Rollback to PreMutationSnapshotId
   - Guaranteed rollback capability
```

---

## 11. API Contracts

### Orchestrator Service (IOrchestrator)

```csharp
public interface IOrchestrator
{
    Task<BuilderState> DispatchAsync(BuilderEvent @event);
    Task<TaskResult> ExecuteTaskAsync(TaskDefinition task);
    BuilderContext GetCurrentContext();
}
```

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 7-layer overview, deployment model
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn indexing, symbol graph, patch engine
- [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — AI Construction Engine vs Runtime Safety Kernel
- [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) — Sandbox, MSBuild, filesystem isolation
- [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Multi-agent coordination

---

## Change Log

| Date | Change | Contradiction Fixed |
|------|--------|---------------------|
| 2026-02-21 | Added AI_GENERATING state | #3 - AI Code Generation Missing |
| 2026-02-21 | Added CREATING_SNAPSHOT state before PATCHING | #1 - Snapshot Timing Paradox |
| 2026-02-21 | Added CAPABILITY_SCAN state before BUILDING | #7 - Capability Inference Timing |
| 2026-02-21 | Fixed Indexing lock type to Exclusive Write | #5 - Concurrency Lock Deadlock |
| 2026-02-21 | Added DAG sequential execution clarification | #6 - DAG Parallelism vs Serialization |
| 2026-02-21 | Added retry ownership invariant | #4 - Infinite Loop Trap |