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
✓ Continuous autonomous refinement (Infinite silent retries with staged escalation)
✓ Immutable state transitions (functional programming)
✓ Full event log for replay/debug (deterministic replay)
✓ Deterministic resets (SYSTEM_RESET state with rollback on stuck loops, but never terminal failure)
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
    PENDING, RUNNING, VALIDATING, RETRYING, COMPLETED, CANCELLED
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
    AI_GENERATING = 5,           // AI generates code
    CREATING_SNAPSHOT = 6,       // Snapshot BEFORE mutation (MANDATORY)
    MUTATION_GUARD = 7,          // Validate mutation safety
    PATCHING = 8,                // Apply AST transformation
    INDEXING = 9,                // Update semantic graph
    CAPABILITY_SCAN = 10,        // Capability inference BEFORE build (for Release)
    BUILDING = 11,               // MSBuild compilation
    VALIDATING = 12,             // Final integrity check
    
    // === RETRY & RESULT ===
    RETRYING = 13,
    EXECUTING_TASK = 14,
    BUILD_SUCCEEDED = 15,
    CANCELLED = 16,              // Terminal state ONLY via user cancellation
    SYSTEM_RESET = 17,           // Reset with rollback + memory wipe
    
    // === PACKAGING PHASE ===
    PACKAGING = 18,
    PACKAGING_SUCCEEDED = 19,
    PACKAGING_FAILED = 20,
    MANIFEST_UPDATING = 21,
    REBUILD_REQUIRED = 22,
    SIGNING = 23,
    SIGNATURE_VALIDATION = 24,
    ENVIRONMENT_RECOVERY = 25,
    
    // === PLATFORM REQUIREMENTS & ASSET GENERATION (NEW) ===
    REQUIREMENT_EVALUATION = 26, // Evaluate platform requirements (NO TEMPLATES)
    BRANDING_INFERENCE = 27,     // Derive brand identity from intent
    ASSET_GENERATING = 28,       // Generate icons, logos, splash screens via AI
    ASSETS_READY = 29,           // All assets generated successfully
    ASSET_GENERATION_FAILED = 30 // Asset generation failed (triggers retry)
}
```

### State Diagram (Infinite Silent Retry Model)

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
                              └──(retry >= 10)──→ SYSTEM_RESET
                                         │
                                         ├──→ ROLLBACK TO SNAPSHOT
                                         │
                                         └──→ (Clear AI Memory)
                                                    │
                                                    └──→ AI_GENERATING
                                                        (Fresh attempt with new approach)

  ╔═══════════════════════════════════════════════════════════════╗
  ║  USER CANCELLATION (Only way to stop)                        ║
  ╠═══════════════════════════════════════════════════════════════╣
  ║  Any State ──→ User Clicks Cancel ──→ CANCELLED              ║
  ║                                                               ║
  ║  User sees: "Build cancelled"                                ║
  ║  System state: Rolled back to last stable snapshot           ║
  ╚═══════════════════════════════════════════════════════════════╝
```

### Terminal States

| State | Type | Description | Recovery |
|-------|------|-------------|----------|
| `PACKAGING_SUCCEEDED` | Success | Application built, packaged, and ready | None needed |
| `CANCELLED` | Terminal | User explicitly cancelled | User must restart build |

**NOTE**: There is NO `FAILED` state. The system never stops on its own - only user cancellation stops the build.

---

## 4. State Container & Event Log

### BuilderContext (Single Source of Truth)

```csharp
public class BuilderContext
{
    public BuilderState State { get; set; }

    // Task execution - SINGLE TASK AT A TIME
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
    public string? PreMutationSnapshotId { get; set; }      // Snapshot created BEFORE current task
    public string? LastStableSnapshotHash { get; set; }     // Hash of last verified build

    // Build mode (affects capability inference timing)
    public BuildMode CurrentBuildMode { get; set; } = BuildMode.DEBUG;

    // System Reset tracking
    public int SystemResetCount { get; set; } = 0;          // Number of times we've done a full reset
    public List<string> AttemptedApproaches { get; } = new(); // Track what's been tried

    // Cancellation
    public bool UserCancelled { get; set; } = false;

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

### Runtime Enforcement of Single Active Transaction

The single-transaction invariant is enforced at runtime through:

#### Code Enforcement
```csharp
// Invariant: Exactly one active ConstructionTransaction per Orchestrator instance.
if (_activeTransaction != null)
{
    throw new InvalidOperationException(
        "TRANSACTION_ALREADY_ACTIVE: Orchestrator enforces single active transaction.");
}
```

#### Persistence Guarantees
- **ActiveTransactionId persisted in DB**: The ID of the currently active transaction is written to persistent storage before any mutation begins
- **Crash recovery restores only that transaction**: On restart, the system queries the persisted ActiveTransactionId and resumes exactly that transaction
- **All new tasks rejected until resolved**: While an active transaction exists, any new task requests are rejected with `TRANSACTION_ALREADY_ACTIVE` error

This ensures that the documented invariant ("one task at a time") has runtime enforcement that survives process crashes and restarts.

### Event Types (Replayable & Debuggable)

```csharp
public abstract record BuilderEvent
{
    public DateTime Timestamp { get; init; } = DateTime.Now;
    public int EventSequence { get; init; }
}

// Snapshot Events
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

// Retry events
public record RetryStartedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public int CurrentRetry { get; init; }
    public ErrorType PreviousError { get; init; }
    public RetryStage Stage { get; init; }
}

// System Reset events
public record SystemResetEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public string RollbackSnapshotId { get; init; }
    public string PreviousApproach { get; init; }
    public int ResetCount { get; init; }
}

// User cancellation events
public record UserCancelledEvent : BuilderEvent
{
    public string Reason { get; init; } = "User requested cancellation";
}

// Capability scan events
public record CapabilityScanCompletedEvent : BuilderEvent
{
    public string TaskId { get; init; }
    public List<string> DetectedCapabilities { get; init; }
    public List<string> AddedCapabilities { get; init; }
    public bool ManifestUpdated { get; init; }
}

// Platform Requirements events (NEW)
public record RequirementsEvaluatedEvent : BuilderEvent
{
    public string ProjectId { get; init; }
    public int TotalRequirements { get; init; }
    public int MandatoryCount { get; init; }
    public int RecommendedCount { get; init; }
    public int AssetCount { get; init; }
}

public record BrandingInferredEvent : BuilderEvent
{
    public string ProjectId { get; init; }
    public string Domain { get; init; }
    public string PrimaryColor { get; init; }
    public string StyleMood { get; init; }
}

public record AssetsGeneratedEvent : BuilderEvent
{
    public string ProjectId { get; init; }
    public List<GeneratedAssetInfo> GeneratedAssets { get; init; }
    public bool AllSuccess { get; init; }
}

public record GeneratedAssetInfo
{
    public string AssetId { get; init; }
    public string Category { get; init; }
    public string FilePath { get; init; }
    public int Width { get; init; }
    public int Height { get; init; }
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
        // Check for user cancellation first
        if (context.UserCancelled && @event is not UserCancelledEvent)
        {
            return context with { State = BuilderState.CANCELLED };
        }

        return (context.State, @event) switch
        {
            // === USER CANCELLATION (Only terminal state) ===
            (_, UserCancelledEvent e) =>
                context with { State = BuilderState.CANCELLED, UserCancelled = true },

            // === AI GENERATION ===
            (BuilderState.EXECUTION_PLAN_BUILT, TaskStartedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.AI_GENERATING, @event),

            (BuilderState.AI_GENERATING, AIGenerationCompletedEvent e) =>
                context with { State = BuilderState.CREATING_SNAPSHOT, EventLog = [..context.EventLog, @event] },

            // === SNAPSHOT CREATION ===
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

            // === CAPABILITY SCAN ===
            (BuilderState.CAPABILITY_SCAN, CapabilityScanCompletedEvent e) =>
                context with { State = BuilderState.BUILDING, EventLog = [..context.EventLog, @event] },

            (BuilderState.BUILDING, TaskValidatingEvent e) =>
                context with { State = BuilderState.VALIDATING },

            // === SUCCESS PATH ===
            (BuilderState.VALIDATING, TaskCompletedEvent e) =>
                UpdateTaskAndTransition(context, e.TaskId, BuilderState.EXECUTION_PLAN_BUILT, @event),

            // === FAILURE & RETRY PATH ===
            (BuilderState.VALIDATING, TaskFailedEvent e) =>
                context with { State = BuilderState.RETRYING, EventLog = [..context.EventLog, @event] },

            (BuilderState.RETRYING, TaskStartedEvent e) =>
                context with { State = BuilderState.EXECUTING_TASK, EventLog = [..context.EventLog, @event] },

            // === SYSTEM RESET (Never terminal - always retries) ===
            (BuilderState.RETRYING, BuildFailedEvent e) when e.TotalRetries >= 10 =>
                HandleSystemResetWithRollback(context, e),

            (BuilderState.SYSTEM_RESET, SystemResetEvent e) =>
                context with 
                { 
                    State = BuilderState.AI_GENERATING,
                    SystemResetCount = e.ResetCount,
                    EventLog = [..context.EventLog, @event] 
                },

            // === COMPLETION ===
            (BuilderState.EXECUTION_PLAN_BUILT, BuildCompletedEvent e) =>
                context with { State = BuilderState.BUILD_SUCCEEDED, EventLog = [..context.EventLog, @event] },

            // === PLATFORM REQUIREMENTS & ASSET GENERATION (NEW) ===
            (BuilderState.BUILD_SUCCEEDED, BuildCompletedEvent e) =>
                context with { State = BuilderState.REQUIREMENT_EVALUATION, EventLog = [..context.EventLog, @event] },

            (BuilderState.REQUIREMENT_EVALUATION, RequirementsEvaluatedEvent e) =>
                context with { State = BuilderState.BRANDING_INFERENCE, EventLog = [..context.EventLog, @event] },

            (BuilderState.BRANDING_INFERENCE, BrandingInferredEvent e) =>
                context with { State = BuilderState.ASSET_GENERATING, EventLog = [..context.EventLog, @event] },

            (BuilderState.ASSET_GENERATING, AssetsGeneratedEvent e) =>
                context with { State = BuilderState.ASSETS_READY, EventLog = [..context.EventLog, @event] },

            (BuilderState.ASSETS_READY, TaskStartedEvent e) =>
                context with { State = BuilderState.PACKAGING, EventLog = [..context.EventLog, @event] },

            // === INVALID TRANSITION ===
            _ => throw new InvalidOperationException($"Invalid transition: {context.State} + {@event.GetType().Name}")
        };
    }

    private static BuilderContext HandleSystemResetWithRollback(BuilderContext context, BuildFailedEvent @event)
    {
        // SYSTEM RESET - Never terminal, always retry with fresh context
        // 1. Rollback to pre-mutation snapshot
        // 2. Clear AI memory (forced amnesia)
        // 3. Track the failed approach
        // 4. Retry with completely new strategy

        var failedApproach = context.TaskMap[@event.TaskId]?.Description ?? "Unknown approach";
        
        var newAttemptedApproaches = new List<string>(context.AttemptedApproaches) { failedApproach };
        
        var resetEvent = new SystemResetEvent
        {
            TaskId = @event.TaskId,
            RollbackSnapshotId = context.PreMutationSnapshotId ?? "none",
            PreviousApproach = failedApproach,
            ResetCount = context.SystemResetCount + 1
        };

        // Transition to SYSTEM_RESET state, then immediately back to AI_GENERATING
        // The AI will generate a completely new approach
        return context with
        {
            State = BuilderState.SYSTEM_RESET,
            SystemResetCount = context.SystemResetCount + 1,
            AttemptedApproaches = newAttemptedApproaches,
            EventLog = [..context.EventLog, @event, resetEvent]
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
                BuilderState.CANCELLED => TaskStatus.CANCELLED,
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
    public bool IsRetryable { get; init; } = true; // Always retryable in infinite retry model
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
    PROCESS_CRASH,
    
    // === ASSET GENERATION ERRORS (NEW) ===
    ASSET_GENERATION_FAILED,       // Image generation failed
    BRANDING_INFERENCE_FAILED,     // Could not derive brand identity
    REQUIREMENT_EVALUATION_FAILED  // Could not evaluate platform requirements
}
```

---

## 7. Retry Controller

### Retry Ownership

> **INVARIANT**: The Orchestrator is the ONLY component that manages retry loops. Agents MUST NOT have internal retry loops. Agents attempt a fix ONCE and return. The Orchestrator decides whether to retry.

### Retry Stages (Continuous - Never Abort)

```csharp
public enum RetryStage
{
    FIX_LEVEL,          // Stage 1: Try local token repairs (retries 1-3)
    INTEGRATION_LEVEL,  // Stage 2: Check DI and wiring (retries 4-6)
    ARCHITECTURE_LEVEL, // Stage 3: Re-evaluate high-level plan (retries 7-9)
    SYSTEM_RESET        // Stage 4: Rollback, Wipe AI Memory, Try New Approach (retry 10+)
}
```

### Retry Controller Logic

```csharp
public class RetryController
{
    /// <summary>
    /// Orchestrator-managed retry. Never stops - always retries.
    /// At cycle 10+, performs SYSTEM_RESET with forced amnesia.
    /// </summary>
    public static BuilderContext ExecuteRetry(BuilderContext context, Task failedTask, ErrorClassification error)
    {
        failedTask.RetryCount++;

        var stage = DetermineStage(failedTask.RetryCount);

        // Stage 4: SYSTEM_RESET - Not terminal, just a fresh start
        if (stage == RetryStage.SYSTEM_RESET)
        {
            var resetEvent = new SystemResetEvent
            {
                TaskId = failedTask.Id,
                RollbackSnapshotId = context.PreMutationSnapshotId ?? "none",
                PreviousApproach = failedTask.Description,
                ResetCount = context.SystemResetCount + 1
            };
            
            // Emit SystemResetEvent - the system continues, never stops
            return context with 
            { 
                State = BuilderState.SYSTEM_RESET,
                SystemResetCount = context.SystemResetCount + 1,
                EventLog = [..context.EventLog, resetEvent] 
            };
        }

        // Log every retry attempt
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
        _ => RetryStage.SYSTEM_RESET  // Never ABORT - always reset and retry
    };
}
```

### Retry Governance Contract

| Retry Range | Owner | Enforcement | Behavior |
|-------------|-------|-------------|----------|
| 1-9 | AI Construction Engine | Strategy flexible | AI adapts, learns, retries |
| 10+ | Runtime Safety Kernel | System Reset + Amnesia | Rollback, wipe memory, fresh approach |

#### Infinite Loop Prevention Guarantee

**By design, infinite retry loops are impossible.**

The retry system enforces this through:

1. **Finite stages**: Only 4 stages exist (FIX_LEVEL → INTEGRATION_LEVEL → ARCHITECTURE_LEVEL → SYSTEM_RESET)
2. **Progressive escalation**: Each stage represents a fundamentally different approach, not repetition
3. **SYSTEM_RESET clears state**: Stage 4 wipes AI memory and context, ensuring a fresh approach
4. **No ABORT state**: The system never gives up — it always resets and retries with a clean slate

This means the system can never enter a non-terminating state. Every failure eventually triggers a SYSTEM_RESET, which produces a fundamentally new approach.

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

**Phase 3 — Task Execution Loop (SERIALIZED)**
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

### DAG Execution Clarification

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

### Concurrency Matrix

| Operation | Can Run With | Cannot Run With | Lock Type |
|-----------|--------------|-----------------|-----------|
| **Patching (Mutation)** | Nothing | All other operations | Exclusive Write Lock |
| **Indexing** | Read queries | Mutation, Build | Exclusive Write Lock |
| **Building** | Nothing | All other operations | Exclusive Build Lock |
| **Read Queries** | All read operations | Mutation | Shared Read Lock |
| **AI Generation** | Other AI Generation | Mutation, Build | None (stateless) |

```csharp
public class ConcurrencyPolicy
{
    public static LockType GetRequiredLock(OperationType operation) => operation switch
    {
        OperationType.Mutation => LockType.ExclusiveWrite,
        OperationType.Indexing => LockType.ExclusiveWrite,
        OperationType.Build => LockType.ExclusiveBuild,
        OperationType.ReadQuery => LockType.SharedRead,
        OperationType.AIGeneration => LockType.None,
        _ => LockType.SharedRead
    };
}
```

---

## 10. Snapshot Authority

### Snapshot Timing Invariant

> **INVARIANT**: A snapshot MUST be created BEFORE any mutation. This is enforced by the `CREATING_SNAPSHOT` state in the state machine.

### Snapshot Creation Points

| Trigger | State | Purpose |
|---------|-------|---------|
| Before PATCHING | `CREATING_SNAPSHOT` | Enable rollback on failure or system reset |
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
7. If PATCHING fails and system reset triggered:
   - Rollback to PreMutationSnapshotId
   - Clear AI memory (forced amnesia)
   - Retry with completely new approach
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
    void RequestCancellation();  // Only way to stop execution
}
```

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 8-layer overview, deployment model
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn indexing, symbol graph, patch engine
- [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — AI Construction Engine vs Runtime Safety Kernel
- [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) — Sandbox, MSBuild, filesystem isolation
- [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Multi-agent coordination
- [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — **AI capabilities via z-ai-web-dev-sdk (NO API KEYS!)**
- [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md) — Complete TypeScript implementation
- [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) — **NEW: Zero-template approach - Platform requirements**
- [BRANDING_INFERENCE_HEURISTICS.md](./BRANDING_INFERENCE_HEURISTICS.md) — **NEW: Intelligent brand derivation**

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Added ASSET_GENERATION_FAILED, BRANDING_INFERENCE_FAILED, REQUIREMENT_EVALUATION_FAILED error types |
| 2026-02-23 | Added Platform Requirements & Asset Generation states (26-29) |
| 2026-02-23 | Added RequirementsEvaluatedEvent, BrandingInferredEvent, AssetsGeneratedEvent |
| 2026-02-23 | Added state transitions for REQUIREMENT_EVALUATION → BRANDING_INFERENCE → ASSET_GENERATING → ASSETS_READY |
| 2026-02-21 | Converted to Infinite Silent Retry model - removed FAILED state, added SYSTEM_RESET |
| 2026-02-21 | Added CANCELLED state as only terminal state (user-initiated only) |
| 2026-02-21 | Added SystemResetEvent and AttemptedApproaches tracking |
| 2026-02-21 | Fixed all architectural contradictions (1-7) |