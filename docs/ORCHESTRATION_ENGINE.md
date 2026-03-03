# ORCHESTRATION ENGINE

> **Sync AI is a Local AI Full-Stack Windows Native App Builder** — a sophisticated desktop application that autonomously designs, generates, compiles, validates, fixes, and packages complete production-ready Windows desktop applications from natural language descriptions by operators or users.
>
> _This document specifies the Runtime Safety Kernel (Orchestrator) of Sync AI._

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

```text
✓ No implicit transitions
✓ No uncontrolled parallel mutation (Parallel AI generation/planning is allowed, but mutation is serialized)
✓ One active mutation task at a time (strict serialization for file/state changes)
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
    // .NET Project Tasks
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
    BUILD_MSIX,
    
    // Native (C++) Project Tasks
    GENERATE_VCXPROJ,
    ADD_CPP_SOURCE,
    ADD_CPP_HEADER,
    ADD_RESOURCE_FILE,
    COMPILE_NATIVE,
    LINK_NATIVE,
    GENERATE_NATIVE_MANIFEST,
    BUILD_NATIVE_EXE,
    
    // Hybrid Project Tasks (C# + C++)
    GENERATE_HYBRID_SOLUTION,
    CONFIGURE_NATIVE_INTEROP,
    
    // Packaging Variants
    BUILD_MSI,
    BUILD_EXE_INSTALLER,
    BUILD_PORTABLE_ZIP
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

    // === NATIVE (C++) BUILD PHASE ===
    NATIVE_COMPILING = 26,        // cl.exe compilation
    NATIVE_LINKING = 27,          // link.exe linking
    NATIVE_BUILD_SUCCEEDED = 28,
    NATIVE_BUILD_FAILED = 29,
    
    // === HYBRID BUILD PHASE ===
    HYBRID_COMPILING = 30,        // Native + Managed compilation
    HYBRID_LINKING = 31,
    HYBRID_BUILD_SUCCEEDED = 32,
    HYBRID_BUILD_FAILED = 33,
    
    // === ALTERNATE PACKAGING ===
    MSI_BUILDING = 34,
    MSI_BUILD_SUCCEEDED = 35,
    MSI_BUILD_FAILED = 36,

    // === PLATFORM REQUIREMENTS & ASSET GENERATION ===
    REQUIREMENT_EVALUATION = 26, // Evaluate platform requirements (NO TEMPLATES)
    BRANDING_INFERENCE = 27,     // Derive brand identity from intent
    ASSET_GENERATING = 28,       // Generate icons, logos, splash screens via AI
    ASSETS_READY = 29,           // All assets generated successfully
    ASSET_GENERATION_FAILED = 30,// Asset generation failed (triggers retry)

    // === AI SERVICE FAILURE STATES (NEW) ===
    AI_SERVICE_UNAVAILABLE = 31, // AI mini-service not responding
    AI_SERVICE_DEGRADED = 32     // AI service partially available (fallback mode)
}
```

### State Diagram (Bounded Retry Model)

```text
IDLE
  ↓ (blueprint request arrives)

// AI Config Guard - Block unless validated
if (AIConfigState != AIConfigState.VALIDATED)
{
    TransitionTo(BuilderState.AI_SERVICE_UNAVAILABLE);
    return;
}

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

| State                 | Type     | Description                            | Recovery                |
| --------------------- | -------- | -------------------------------------- | ----------------------- |
| `PACKAGING_SUCCEEDED` | Success  | Application built, packaged, and ready | None needed             |
| `CANCELLED`           | Terminal | User explicitly cancelled              | User must restart build |

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

// Configuration change events
public record ConfigurationChangedEvent : BuilderEvent
{
    public string Reason { get; init; } = "User updated AI provider settings";
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
                // CONDITIONAL: Skip CAPABILITY_SCAN for DEBUG builds (reactive inference on failure)
                // Only run proactive scan for RELEASE builds
                context.CurrentBuildMode == BuildMode.RELEASE
                    ? context with { State = BuilderState.CAPABILITY_SCAN, EventLog = [..context.EventLog, @event] }
                    : context with { State = BuilderState.BUILDING, EventLog = [..context.EventLog, @event] },

            // === CAPABILITY SCAN (RELEASE builds only) ===
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

> **See also**: [REPAIR_PATTERNS.md](./REPAIR_PATTERNS.md) — Canonical catalog of deterministic repair strategies for each `ErrorType`. The Fix Agent uses this catalog to select the appropriate repair approach before attempting a free-form AI fix.
>
> **Toolchain**: All build operations referenced in error messages use exclusively the bundled toolchain. See [TOOLCHAIN_MANIFEST.md](./TOOLCHAIN_MANIFEST.md) for tool paths and [TOOLCHAIN_ISOLATION.md](./TOOLCHAIN_ISOLATION.md) for invocation contract.

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

    // === ASSET GENERATION ERRORS ===
    ASSET_GENERATION_FAILED,       // Image generation failed
    BRANDING_INFERENCE_FAILED,     // Could not derive brand identity
    REQUIREMENT_EVALUATION_FAILED, // Could not evaluate platform requirements

    // === AI SERVICE ERRORS (NEW) ===
    AI_SERVICE_UNAVAILABLE,        // AI mini-service not responding
    AI_SERVICE_TIMEOUT,            // AI request exceeded timeout
    AI_SERVICE_ERROR,              // AI service returned error
    AI_SERVICE_DEGRADED            // AI service in fallback mode
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

### Retry Stage Behavior Specification

> **INVARIANT**: Each retry stage has defined escalation behavior. The AI must adapt its strategy as retries progress.

| Retry Range | Stage              | AI Strategy                                                             | Kernel Action                                                             | Cool-off |
| ----------- | ------------------ | ----------------------------------------------------------------------- | ------------------------------------------------------------------------- | -------- |
| **1-3**     | FIX_LEVEL          | Local token repairs, syntax fixes, small adjustments                    | Log retry, allow continuation                                             | 0s       |
| **4-6**     | INTEGRATION_LEVEL  | Check DI wiring, service registration, module boundaries                | Log retry, warn if pattern persists                                       | 2s       |
| **7-9**     | ARCHITECTURE_LEVEL | Re-evaluate high-level plan, structural changes, alternative approaches | Log retry, prepare for potential reset                                    | 5s       |
| **≥10**     | SYSTEM_RESET       | **N/A - AI memory wiped**                                               | Rollback to snapshot, clear context, track failed approach, restart fresh | 10s      |

> **Mandatory Cool-Off Policy**: Each retry stage has an enforced cool-off period before retrying. This prevents rapid retry loops and allows system stabilization.

> **Operator Escalation Rule**: After every 3rd consecutive SYSTEM_RESET event (i.e., when `SystemResetCount % 3 == 0`), the system emits an `OperatorEscalationEvent` and **pauses the retry loop**, surfacing a blocking acknowledgment notification to the user before resuming.
>
> **Convergence trigger**: `SystemResetCount` is incremented on every SYSTEM_RESET. The check fires at counts 3, 6, 9, …
>
> **`OperatorEscalationEvent` payload**:
>
> - `SystemResetCount` — total resets so far
> - `AttemptedApproaches` — list of all strategy descriptions tried and failed
> - `TaskId` — the task that is stuck
> - `LastError` — most recent error classification
>
> **System behavior on escalation**:
>
> 1. Pause the retry loop (no further AI calls until user responds).
> 2. Show a blocking UI notification: _"Sync AI has tried multiple approaches without success. You can cancel and revise your request, or let the system continue with a new approach."_
> 3. User selects **Continue** (retry loop resumes with fresh context) or **Cancel** (transitions to `CANCELLED`).
>
> This is the only exception to the infinite-silent-retry model — it prevents indefinite looping on fundamentally unsolvable tasks without user awareness.

### Retry Budget Contract (Global Hard Limits)

> **INVARIANT**: Retry is BOUNDED. Infinite retries are FORBIDDEN except for approved error classes.

| Error Class                     | Max Retries | Ceiling Behavior                              |
| ------------------------------- | ----------- | --------------------------------------------- |
| **SYNTAX_ERROR** (CS\*)         | 3           | FIX_LEVEL only, then SYSTEM_RESET             |
| **BUILD_ERROR** (NETSDK*, MSB*) | 9           | Full retry 1-9, then SYSTEM_RESET             |
| **RUNTIME_ERROR**               | 9           | Full retry 1-9, then SYSTEM_RESET             |
| **CAPABILITY_MISSING**          | 3           | FIX_LEVEL only, then SYSTEM_RESET             |
| **MANIFEST_INVALID**            | 3           | FIX_LEVEL only, then SYSTEM_RESET             |
| **AI_SERVICE_UNAVAILABLE**      | Infinite    | No ceiling - service availability is external |
| **AI_SERVICE_DEGRADED**         | Infinite    | No ceiling - service availability is external |

> **Deterministic Terminal State**: When any retry ceiling is reached, the system MUST transition to a deterministic terminal recovery:
>
> - Emit `RetryCeilingReachedEvent`
> - Trigger SYSTEM_RESET (rollback + amnesia)
> - If 3+ consecutive SYSTEM_RESET events: emit `OperatorEscalationEvent`
>
> Only `AI_SERVICE_UNAVAILABLE` and `AI_SERVICE_DEGRADED` are permitted infinite retry - these depend on external service availability.

#### Stage Transition Behavior

```text
RETRY 1-3 (FIX_LEVEL):
├── AI attempts local fixes (token-level, syntax)
├── Error context preserved
└── Fast retry (minimal delay)

RETRY 4-6 (INTEGRATION_LEVEL):
├── AI escalates to integration checks
├── Examines DI container, service wiring
├── Error context preserved
└── Medium delay (integration analysis)

RETRY 7-9 (ARCHITECTURE_LEVEL):
├── AI re-evaluates entire approach
├── May request clarification
├── Considers alternative architectures
├── Error context preserved
└── Longer delay (architectural analysis)

RETRY ≥10 (SYSTEM_RESET):
├── AI memory COMPLETELY WIPED
├── Previous approach logged to AttemptedApproaches
├── Approach fingerprint computed and persisted
├── State rolled back to PreMutationSnapshotId
├── SystemResetCount incremented
├── Architect Agent receives AttemptedApproaches set with directive:
│   "The following architectural fingerprints have already been attempted and failed.
│    Do NOT produce an approach whose fingerprint matches any of these."
├── If Architect Agent produces colliding fingerprint → Kernel rejects immediately (no retry count)
└── Fresh attempt with no prior context
```

> **Note**: SYSTEM_RESET does NOT mean failure. It means "try a completely different approach." The system NEVER stops - only user cancellation terminates execution.

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
            // Compute approach fingerprint from failed AppSpec version
            // Fingerprint = SHA-256 of: {architecturePattern}:{topLevelEntityNames}:{pageCount}:{servicePattern}
            var failedApproach = failedTask.Description ?? "Unknown approach";
            var approachFingerprint = ComputeApproachFingerprint(failedTask);
                    
            // Append fingerprint to AttemptedApproaches (persists across SYSTEM_RESETs for session lifetime)
            var newAttemptedApproaches = new List<string>(context.AttemptedApproaches) { approachFingerprint };
                    
            var resetEvent = new SystemResetEvent
            {
                TaskId = failedTask.Id,
                RollbackSnapshotId = context.PreMutationSnapshotId ?? "none",
                PreviousApproach = failedApproach,
                ResetCount = context.SystemResetCount + 1,
                AttemptedFingerprints = newAttemptedApproaches
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

| Retry Range | Owner                  | Enforcement            | Behavior                              |
| ----------- | ---------------------- | ---------------------- | ------------------------------------- |
| 1-9         | AI Construction Engine | Strategy flexible      | AI adapts, learns, retries            |
| 10+         | Runtime Safety Kernel  | System Reset + Amnesia | Rollback, wipe memory, fresh approach |

---

## 8. Execution Lifecycle

### Named Thread Types

| Thread                    | Color  | Purpose                                      | Concurrency        |
| ------------------------- | ------ | -------------------------------------------- | ------------------ |
| 🟢 UI Thread              | Green  | Rendering, user input, never blocks          | Single (main)      |
| 🔵 Orchestrator Thread    | Blue   | Sequential execution, state machine          | Single             |
| 🟣 AI Worker Thread Pool  | Purple | AI code generation tasks                     | Max 2 concurrent   |
| 🟡 Patch Worker Thread    | Yellow | File mutations, requires exclusive file lock | Single-threaded    |
| 🔴 Build Worker Thread    | Red    | MSBuild compilation, isolated                | Single (per build) |
| ⚪ Background Maintenance | White  | Low priority cleanup                         | Single             |

### Phase Flow

**Bounded Retry Model — Spec Parsing (Orchestrator Thread)**

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

| Operation               | Can Run With        | Cannot Run With      | Lock Type            |
| ----------------------- | ------------------- | -------------------- | -------------------- |
| **Patching (Mutation)** | Nothing             | All other operations | Exclusive Write Lock |
| **Indexing**            | Read queries        | Mutation, Build      | Exclusive Write Lock |
| **Building**            | Nothing             | All other operations | Exclusive Build Lock |
| **Read Queries**        | All read operations | Mutation             | Shared Read Lock     |
| **AI Generation**       | Other AI Generation | Mutation, Build      | None (stateless)     |

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

### Single Active Transaction Invariant

> **INVARIANT**: Each Orchestrator instance may have **EXACTLY ONE** active `ConstructionTransaction` at any time.
>
> This is a runtime-enforced constraint, not just a documentation rule.

#### Runtime Enforcement Code

```csharp
public class Orchestrator
{
    private ConstructionTransaction? _activeTransaction;
    private readonly object _transactionLock = new();

    /// <summary>
    /// Begins a new construction transaction.
    /// CRASHES if a transaction is already active - this is intentional.
    /// </summary>
    public ConstructionTransaction BeginTransaction(string taskId, string description)
    {
        lock (_transactionLock)
        {
            if (_activeTransaction != null)
            {
                // CRASH: This is a fatal programming error
                // Multiple concurrent transactions would break state consistency
                throw new InvalidOperationException(
                    $"CANNOT begin transaction '{taskId}': " +
                    $"Transaction '{_activeTransaction.Id}' is already active. " +
                    "Each Orchestrator instance supports exactly ONE active transaction.");
            }

            _activeTransaction = new ConstructionTransaction
            {
                Id = taskId,
                Description = description,
                StartedAt = DateTime.UtcNow,
                PreMutationSnapshotId = GetCurrentSnapshotId()
            };

            return _activeTransaction;
        }
    }

    /// <summary>
    /// Commits the active transaction and clears it.
    /// </summary>
    public void CommitTransaction(string transactionId)
    {
        lock (_transactionLock)
        {
            if (_activeTransaction == null)
            {
                throw new InvalidOperationException(
                    $"CANNOT commit transaction '{transactionId}': No active transaction exists.");
            }

            if (_activeTransaction.Id != transactionId)
            {
                throw new InvalidOperationException(
                    $"CANNOT commit transaction '{transactionId}': " +
                    $"Active transaction is '{_activeTransaction.Id}'.");
            }

            // Emit TransactionCommittedEvent
            _eventBus.Publish(new TransactionCommittedEvent
            {
                TransactionId = transactionId,
                Duration = DateTime.UtcNow - _activeTransaction.StartedAt
            });

            _activeTransaction = null;
        }
    }
}
```

#### Crash Recovery After Transaction Violation

If the system crashes due to a transaction invariant violation:

1. **On Restart**: The system loads the last stable snapshot
2. **Transaction Log**: All uncommitted transactions are rolled back
3. **State Recovery**: `BuilderContext` is reconstructed from event log
4. **Resume**: System returns to `IDLE` or `EXECUTION_PLAN_BUILT` state

```csharp
public class TransactionRecoveryService
{
    public async Task<BuilderContext> RecoverFromCrashAsync(string projectId)
    {
        // 1. Load last stable snapshot
        var snapshot = await _snapshotService.GetLastStableSnapshotAsync(projectId);

        // 2. Replay events up to crash point
        var events = await _eventLog.GetEventsAfterAsync(snapshot.Timestamp);

        // 3. Identify incomplete transactions
        var incompleteTransactions = events
            .Where(e => e is TransactionStartedEvent)
            .Where(e => !events.Any(commit =>
                commit is TransactionCommittedEvent tc &&
                tc.TransactionId == ((TransactionStartedEvent)e).TransactionId))
            .ToList();

        // 4. Rollback incomplete transactions
        foreach (var incomplete in incompleteTransactions)
        {
            _logger.LogWarning("Rolling back incomplete transaction: {TransactionId}",
                ((TransactionStartedEvent)incomplete).TransactionId);
        }

        // 5. Rebuild context from committed state
        var context = await _snapshotService.RestoreSnapshotAsync(snapshot.Id);

        // 6. Emit RecoveryCompletedEvent
        await _eventBus.PublishAsync(new RecoveryCompletedEvent
        {
            ProjectId = projectId,
            RolledBackTransactions = incompleteTransactions.Count,
            RestoredSnapshotId = snapshot.Id
        });

        return context;
    }
}
```

> **Why This Matters**: Single active transaction guarantees that:
>
> - State is always in a consistent, recoverable state
> - Rollback has a clear target (the pre-mutation snapshot)
> - Concurrent mutation bugs are caught immediately (crash early, fail fast)

### Snapshot Creation Points

| Trigger             | State                  | Purpose                                    |
| ------------------- | ---------------------- | ------------------------------------------ |
| Before PATCHING     | `CREATING_SNAPSHOT`    | Enable rollback on failure or system reset |
| Before PACKAGING    | `CREATING_SNAPSHOT`    | Enable rollback on packaging failure       |
| Manual user request | Any non-mutation state | User-initiated checkpoint                  |

### Snapshot Lifecycle

```text
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

## 12. ConstructionTransaction with Provider/Model Tracking

> **INVARIANT**: Every ConstructionTransaction MUST record the AI provider and model used. This ensures reproducibility of AI-generated artifacts.

> **INVARIANT**: Any change to AI configuration (via Settings > AI Settings) MUST emit a `ConfigurationChangedEvent`. The Orchestrator then transitions to `SYSTEM_RESET` state, clears any active tasks, and forces a complete revalidation before continuing construction. Hot model swapping during active construction is FORBIDDEN.

### ConstructionTransaction Record

```csharp
public record ConstructionTransaction
{
    public string Id { get; init; }
    public string Description { get; init; }
    public DateTime StartedAt { get; init; }
    public DateTime? CompletedAt { get; init; }

    // Snapshot reference for rollback
    public string PreMutationSnapshotId { get; init; }

    // === PROVIDER/MODEL TRACKING (CRITICAL FOR REPRODUCIBILITY) ===
    public string AIProviderBaseUrl { get; init; }    // e.g., "https://openrouter.ai/api/v1"
    public string AIModelName { get; init; }          // e.g., "openai/gpt-4o"
    public string AIServiceVersion { get; init; }     // ai-service.exe build version

    // Trace ID for correlating logs
    public string TraceId { get; init; }

    // AI operations performed in this transaction
    public List<AIOperationRecord> AIOperations { get; init; } = new();

    // Result
    public bool Success { get; init; }
    public string? ErrorMessage { get; init; }
}

public record AIOperationRecord
{
    public string OperationId { get; init; }
    public string OperationType { get; init; }  // "LLM", "IMAGE_GEN", "VLM", "SEARCH"
    public string ModelUsed { get; init; }       // Which model slot handled this operation
    public DateTime Timestamp { get; init; }
    public TimeSpan Duration { get; init; }
    public bool Success { get; init; }
    public int TokenCount { get; init; }        // For LLM operations
    public string? IntentHash { get; init; }    // Hash of input prompt for caching
    public string? ResultHash { get; init; }    // Hash of output for verification
}
```

### Provider Info Injection

```csharp
public class ConstructionTransactionFactory
{
    private readonly AIServiceClient _aiClient;

    public async Task<ConstructionTransaction> CreateTransactionAsync(string taskId, string description)
    {
        // Get health/config info from AI service
        var health = await _aiClient.GetHealthAsync();

        return new ConstructionTransaction
        {
            Id = taskId,
            Description = description,
            StartedAt = DateTime.UtcNow,
            PreMutationSnapshotId = GetCurrentSnapshotId(),

            // Provider/Model Tracking (CRITICAL)
            AIProviderBaseUrl = "configured-via-settings",
            AIModelName = "configured-via-settings",
            AIServiceVersion = health.Version ?? "unknown",

            // Generate trace ID for log correlation
            TraceId = GenerateTraceId()
        };
    }

    private string GenerateTraceId()
    {
        // Format: trace_{guid}
        return $"trace_{Guid.NewGuid():N}";
    }
}
```

---

## 13. Timeout Granularity Configuration

> **INVARIANT**: Timeouts MUST be configured per-operation-type, not globally. Different AI operations have vastly different latency profiles.

### Timeout Configuration

```csharp
public class AIOperationTimeouts
{
    /// <summary>
    /// Timeout configuration by operation type.
    /// These are ENFORCED by the Orchestrator, not by the AI service.
    /// </summary>
    public static readonly Dictionary<string, TimeSpan> OperationTimeouts = new()
    {
        // LLM Operations (varies by complexity)
        ["LLM_CHAT_SIMPLE"] = TimeSpan.FromSeconds(30),      // Simple queries
        ["LLM_CHAT_COMPLEX"] = TimeSpan.FromSeconds(120),    // Code generation
        ["LLM_CHAT_ARCHITECTURE"] = TimeSpan.FromSeconds(180), // Architecture design

        // Image Generation
        ["IMAGE_GEN_STANDARD"] = TimeSpan.FromSeconds(30),   // 1024x1024
        ["IMAGE_GEN_LARGE"] = TimeSpan.FromSeconds(60),      // Larger sizes


        // Vision
        ["VLM_ANALYSIS"] = TimeSpan.FromSeconds(45),          // Image analysis

        // Search
        ["WEB_SEARCH"] = TimeSpan.FromSeconds(20),            // Web search

        // Build Operations
        ["BUILD_DEBUG"] = TimeSpan.FromSeconds(120),          // Debug build
        ["BUILD_RELEASE"] = TimeSpan.FromSeconds(300),        // Release build with optimization

        // Packaging
        ["MSIX_PACKAGE"] = TimeSpan.FromSeconds(60),
        ["SIGNING"] = TimeSpan.FromSeconds(30)
    };

    /// <summary>
    /// Get timeout for a specific operation type.
    /// Falls back to default if not configured.
    /// </summary>
    public static TimeSpan GetTimeout(string operationType)
    {
        return OperationTimeouts.TryGetValue(operationType, out var timeout)
            ? timeout
            : TimeSpan.FromSeconds(120); // Default fallback
    }
}
```

### Timeout Enforcement

```csharp
public class TimeoutAwareAIClient
{
    private readonly AIServiceClient _client;

    public async Task<T> ExecuteWithTimeoutAsync<T>(
        string operationType,
        Func<CancellationToken, Task<T>> operation)
    {
        var timeout = AIOperationTimeouts.GetTimeout(operationType);

        using var cts = new CancellationTokenSource(timeout);

        try
        {
            return await operation(cts.Token);
        }
        catch (OperationCanceledException) when (!cts.Token.IsCancellationRequested)
        {
            // This was a timeout, not external cancellation
            throw new AIOperationTimeoutException(operationType, timeout);
        }
    }
}
```

---

## 14. Trace ID Propagation

> **INVARIANT**: Every request from Orchestrator → AI Service → Transaction Log MUST include a Trace ID for log correlation and debugging.

### Trace Context

```csharp
public class TraceContext
{
    public string TraceId { get; init; }
    public string ProjectId { get; init; }
    public string TaskId { get; init; }
    public string ParentSpanId { get; init; }
    public List<string> SpanChain { get; init; } = new();

    /// <summary>
    /// Creates a child span for nested operations.
    /// </summary>
    public TraceContext CreateChildSpan(string spanName)
    {
        return new TraceContext
        {
            TraceId = TraceId,
            ProjectId = ProjectId,
            TaskId = TaskId,
            ParentSpanId = Guid.NewGuid().ToString("N")[..8],
            SpanChain = new List<string>(SpanChain) { spanName }
        };
    }
}
```

### HTTP Header Propagation

```csharp
public class TracingHttpClient : DelegatingHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        // Get trace context from current scope
        var traceContext = TraceContext.Current;

        if (traceContext != null)
        {
            // Add trace headers to ALL AI service requests
            request.Headers.Add("X-Trace-Id", traceContext.TraceId);
            request.Headers.Add("X-Project-Id", traceContext.ProjectId);
            request.Headers.Add("X-Task-Id", traceContext.TaskId);
            request.Headers.Add("X-Parent-Span-Id", traceContext.ParentSpanId);
        }

        return await base.SendAsync(request, cancellationToken);
    }
}
```

### AI Service Request with Trace ID

```typescript
// ai-mini-service/index.ts - Request logging with trace ID

interface RequestContext {
  traceId: string;
  projectId: string;
  taskId: string;
  parentSpanId?: string;
}

function logRequest(context: RequestContext, operation: string, data: unknown) {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      traceId: context.traceId,
      projectId: context.projectId,
      taskId: context.taskId,
      operation,
      data,
    })
  );
}

// Example: Chat endpoint with trace logging
export async function handleChat(request: Request): Promise<Response> {
  const traceId = request.headers.get('X-Trace-Id') || 'unknown';
  const projectId = request.headers.get('X-Project-Id') || 'unknown';
  const taskId = request.headers.get('X-Task-Id') || 'unknown';

  logRequest({ traceId, projectId, taskId }, 'chat_request', {
    /* ... */
  });

  // ... process request ...

  logRequest({ traceId, projectId, taskId }, 'chat_response', {
    /* ... */
  });
}
```

---

## 15. AI Service Failure Governance

> **INVARIANT**: When the AI Service is unavailable, the system MUST transition to a defined fallback state and follow explicit recovery procedures.

### Failure Detection

```csharp
public class AIServiceHealthMonitor
{
    private readonly AIServiceClient _client;
    private readonly ILogger<AIServiceHealthMonitor> _logger;

    public AIServiceHealthStatus LastKnownStatus { get; private set; } = AIServiceHealthStatus.UNKNOWN;
    public DateTime? LastSuccessfulHealthCheck { get; private set; }

    public async Task<AIServiceHealthStatus> CheckHealthAsync()
    {
        try
        {
            var health = await _client.GetHealthAsync();
            LastKnownStatus = health.Status;
            LastSuccessfulHealthCheck = DateTime.UtcNow;
            return health.Status;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AI Service health check failed");
            LastKnownStatus = AIServiceHealthStatus.UNAVAILABLE;
            return AIServiceHealthStatus.UNAVAILABLE;
        }
    }
}

public enum AIServiceHealthStatus
{
    UNKNOWN,
    HEALTHY,
    DEGRADED,      // Partial functionality
    UNAVAILABLE    // Not responding
}
```

### Fallback Strategy

```csharp
public class AIServiceFallbackStrategy
{
    /// <summary>
    /// Determines the appropriate fallback when AI service fails.
    /// </summary>
    public FallbackAction DetermineFallback(AIServiceHealthStatus status, BuilderContext context)
    {
        return status switch
        {
            AIServiceHealthStatus.HEALTHY => FallbackAction.Continue(),

            AIServiceHealthStatus.DEGRADED => FallbackAction.TransitionTo(
                BuilderState.AI_SERVICE_DEGRADED,
                "AI Service operating in degraded mode. Some features may be unavailable."
            ),

            AIServiceHealthStatus.UNAVAILABLE => FallbackAction.TransitionTo(
                BuilderState.AI_SERVICE_UNAVAILABLE,
                "AI Service is not responding. Attempting automatic recovery..."
            ),

            _ => FallbackAction.TransitionTo(
                BuilderState.AI_SERVICE_UNAVAILABLE,
                "AI Service status unknown. Running health check..."
            )
        };
    }
}

public record FallbackAction
{
    public bool ShouldTransition { get; init; }
    public BuilderState? TargetState { get; init; }
    public string Message { get; init; }

    public static FallbackAction Continue() => new() { ShouldTransition = false };

    public static FallbackAction TransitionTo(BuilderState state, string message) => new()
    {
        ShouldTransition = true,
        TargetState = state,
        Message = message
    };
}
```

### State Transitions for AI Service Failures

```csharp
// Add to BuilderReducer

// === CONFIGURATION CHANGE HANDLING ===
(BuilderState.ANY, ConfigurationChangedEvent e) =>
{
    // Cancel any running tasks, rollback to last stable snapshot,
    // and force a full system reset before applying new config.
    return context with
    {
        State = BuilderState.SYSTEM_RESET,
        UserCancelled = false,   // not a user cancel, just a reset
        EventLog = [..context.EventLog, e]
    };
}

// === AI SERVICE FAILURE HANDLING ===
(BuilderState.AI_GENERATING, AIServiceUnavailableEvent e) =>
    context with { State = BuilderState.AI_SERVICE_UNAVAILABLE, EventLog = [..context.EventLog, @event] },

(BuilderState.AI_SERVICE_UNAVAILABLE, AIServiceRecoveredEvent e) =>
    context with { State = BuilderState.AI_GENERATING, EventLog = [..context.EventLog, @event] },

(BuilderState.AI_SERVICE_UNAVAILABLE, AIServiceRecoveryFailedEvent e) when e.AttemptCount >= 3 =>
    // After 3 recovery attempts, wait longer before retrying
    context with { State = BuilderState.AI_SERVICE_UNAVAILABLE, EventLog = [..context.EventLog, @event] },

// Degraded mode - can continue with limited functionality
(BuilderState.AI_SERVICE_DEGRADED, AIServiceRecoveredEvent e) =>
    context with { State = BuilderState.AI_GENERATING, EventLog = [..context.EventLog, @event] },
```

### Recovery Procedure

```text
AI_SERVICE_UNAVAILABLE State:
┌─────────────────────────────────────────────────────────────┐
│ 1. Log failure with Trace ID                                │
│ 2. Emit AIServiceUnavailableEvent                           │
│ 3. Attempt automatic recovery:                              │
│    a. Check if ai-service.exe process is running            │
│    b. If not, start the service                             │
│    c. Wait for health check to pass (max 30s)               │
│ 4. If recovery succeeds:                                    │
│    → Emit AIServiceRecoveredEvent                           │
│    → Resume AI_GENERATING                                   │
│ 5. If recovery fails after 3 attempts:                      │
│    → Wait 60 seconds                                        │
│    → Retry recovery                                          │
│ 6. User can always cancel to stop waiting                   │
└─────────────────────────────────────────────────────────────┘
```

### 15.1 Degraded State Definition and Escalation

| State                    | Trigger                                                                                                     | Behavior                                                                                                                   | Recovery                                                                                                             |
| ------------------------ | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `AI_SERVICE_DEGRADED`    | - 3 consecutive health check failures<br>- 3 consecutive request timeouts<br>- 10+ 429 rate‑limit responses | - AI operations continue with exponential backoff<br>- Blueprint generation is **blocked**<br>- UI shows yellow status dot | Auto‑recovery after 1 successful health check; fallback to `AI_SERVICE_UNAVAILABLE` if 10 consecutive failures       |
| `AI_SERVICE_UNAVAILABLE` | - Health check timeout (5s)<br>- Process not running<br>- Any request returns 5xx error                     | - All AI‑dependent operations are blocked<br>- Orchestrator stays in this state until recovery succeeds                    | Automatic restart of mini‑service, then retry health check; after 3 failed restarts, wait 60s and retry indefinitely |

**Transition Rules:**

- `AI_SERVICE_DEGRADED` → `AI_GENERATING` after a successful health check.
- `AI_SERVICE_UNAVAILABLE` → `CONFIGURED` after mini‑service restart and successful `/health` call.
- User can always cancel to leave these states and return to `IDLE`.

---

## 16. AI E2E Test Suite Specification

> **INVARIANT**: All AI service integrations MUST have end-to-end tests that verify the complete request/response cycle.

### Test Categories

```csharp
public class AIServiceE2ETests
{
    // === LLM Tests ===
    [Fact]
    public async Task LLM_ChatSimple_ReturnsValidResponse()
    {
        var response = await _client.ChatAsync(
            systemPrompt: "You are a helpful assistant.",
            userPrompt: "Say 'hello'"
        );

        Assert.NotNull(response);
        Assert.NotEmpty(response);
    }

    [Fact]
    public async Task LLM_ChatCodeGeneration_GeneratesValidCode()
    {
        var response = await _client.ChatAsync(
            systemPrompt: "You are a C# code generator.",
            userPrompt: "Generate a simple ViewModel class"
        );

        Assert.NotNull(response);
        Assert.Contains("class", response);
        Assert.Contains("ViewModel", response);
    }

    // === Image Generation Tests ===
    [Fact]
    public async Task Image_GenerateStandard_ReturnsValidImage()
    {
        var imageBase64 = await _client.GenerateImageAsync(
            prompt: "A simple app icon",
            size: "1024x1024"
        );

        Assert.NotNull(imageBase64);
        Assert.True(imageBase64.Length > 0);
        // Verify it's valid base64 by decoding
        var imageBytes = Convert.FromBase64String(imageBase64);
        Assert.True(imageBytes.Length > 0);
    }


    // === Vision Tests ===
    [Fact]
    public async Task Vision_AnalyzeImage_ReturnsValidDescription()
    {
        var imageData = await _client.GenerateImageAsync(
            prompt: "A red square",
            size: "1024x1024"
        );

        var analysis = await _client.AnalyzeImageAsync(
            prompt: "Describe this image",
            imageData: imageData
        );

        Assert.NotNull(analysis);
        Assert.Contains("red", analysis.ToLower());
    }

    // === Search Tests ===
    [Fact]
    public async Task Search_Query_ReturnsRelevantResults()
    {
        var results = await _client.SearchAsync(
            query: "WinUI 3 documentation",
            numResults: 5
        );

        Assert.NotNull(results);
        Assert.NotEmpty(results);
    }

    // === Error Handling Tests ===
    [Fact]
    public async Task ServiceUnavailable_ReturnsAppropriateError()
    {
        // Stop the AI service
        await _serviceManager.StopServiceAsync();

        await Assert.ThrowsAsync<AIServiceUnavailableException>(
            () => _client.ChatAsync("test", "test")
        );

        // Restart for other tests
        await _serviceManager.StartServiceAsync();
    }

    [Fact]
    public async Task Timeout_ExceedsLimit_ThrowsTimeoutException()
    {
        await Assert.ThrowsAsync<AIOperationTimeoutException>(
            () => _timeoutClient.ExecuteWithTimeoutAsync(
                "LLM_CHAT_SIMPLE",
                async (ct) => {
                    await Task.Delay(TimeSpan.FromSeconds(60), ct);
                    return "result";
                }
            )
        );
    }

    // === Trace ID Tests ===
    [Fact]
    public async Task Request_WithTraceId_PropagatesToLogs()
    {
        var traceId = $"test_{Guid.NewGuid():N}";

        await _client.ChatAsync(
            systemPrompt: "test",
            userPrompt: "test",
            traceId: traceId
        );

        // Verify trace ID appears in logs
        var logEntry = await _logReader.FindByTraceIdAsync(traceId);
        Assert.NotNull(logEntry);
        Assert.Equal(traceId, logEntry.TraceId);
    }
}
```

---

## 17. ai-service.exe Package Integrity

> **INVARIANT**: The ai-service.exe MUST verify its own integrity on startup and reject execution if tampered.

### Startup Integrity Check

```typescript
// ai-mini-service/integrity.ts

import { createHash } from 'crypto';
import { readFileSync, existsSync } from 'fs';

interface IntegrityCheckResult {
  valid: boolean;
  expectedHash: string;
  actualHash: string;
  timestamp: string;
}

export async function verifyIntegrity(): Promise<IntegrityCheckResult> {
  // The expected hash is embedded at build time
  const EXPECTED_HASH = process.env.AI_SERVICE_HASH || '';

  // Calculate actual hash of running executable
  const executablePath = process.execPath;
  const executableData = readFileSync(executablePath);
  const actualHash = createHash('sha256').update(executableData).digest('hex');

  const valid = EXPECTED_HASH === '' || actualHash === EXPECTED_HASH;

  if (!valid) {
    console.error('⚠️ INTEGRITY CHECK FAILED');
    console.error(`Expected: ${EXPECTED_HASH}`);
    console.error(`Actual:   ${actualHash}`);
    console.error('The ai-service.exe may have been tampered with!');
  }

  return {
    valid,
    expectedHash: EXPECTED_HASH,
    actualHash,
    timestamp: new Date().toISOString(),
  };
}
```

### C# Client Verification

```csharp
public class AIServiceIntegrityValidator
{
    private readonly string _servicePath;
    private readonly string _expectedHash;

    public AIServiceIntegrityValidator(string servicePath, string expectedHash)
    {
        _servicePath = servicePath;
        _expectedHash = expectedHash;
    }

    public async Task<IntegrityResult> VerifyBeforeStartAsync()
    {
        var exePath = Path.Combine(_servicePath, "ai-service.exe");

        if (!File.Exists(exePath))
        {
            return IntegrityResult.Failed("ai-service.exe not found");
        }

        // Calculate SHA256 hash
        using var sha256 = System.Security.Cryptography.SHA256.Create();
        using var stream = File.OpenRead(exePath);
        var hashBytes = await sha256.ComputeHashAsync(stream);
        var actualHash = Convert.ToHexString(hashBytes).ToLower();

        if (actualHash != _expectedHash.ToLower())
        {
            return IntegrityResult.Failed(
                $"Hash mismatch. Expected: {_expectedHash}, Actual: {actualHash}");
        }

        // Verify signature (Windows Authenticode)
        var signatureValid = VerifyAuthenticodeSignature(exePath);
        if (!signatureValid)
        {
            return IntegrityResult.Failed("Authenticode signature verification failed");
        }

        return IntegrityResult.Success();
    }

    private bool VerifyAuthenticodeSignature(string filePath)
    {
        // Use Windows CryptoAPI to verify Authenticode signature
        // Implementation depends on Windows API interop
        // Return true if signature is valid or if running in development mode
        #if DEBUG
        return true; // Skip signature check in debug builds
        #else
        return WinTrust.VerifyEmbeddedSignature(filePath);
        #endif
    }
}

public record IntegrityResult
{
    public bool IsValid { get; init; }
    public string? ErrorMessage { get; init; }

    public static IntegrityResult Success() => new() { IsValid = true };
    public static IntegrityResult Failed(string error) => new() { IsValid = false, ErrorMessage = error };
}
```

### Integration with Service Startup

```csharp
public class AIMiniServiceManager
{
    public async Task<bool> StartServiceAsync()
    {
        // 1. Verify integrity BEFORE starting
        var integrity = await _integrityValidator.VerifyBeforeStartAsync();

        if (!integrity.IsValid)
        {
            _logger.LogError("AI Service integrity check failed: {Error}", integrity.ErrorMessage);
            // Show user-friendly error
            await ShowIntegrityErrorDialog(integrity.ErrorMessage);
            return false;
        }

        // 2. Proceed with normal startup
        // ... existing startup code ...
    }
}
```

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 8-layer overview, deployment model
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn indexing, symbol graph, patch engine
- [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — AI Construction Engine vs Runtime Safety Kernel
- [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) — Sandbox, MSBuild, filesystem isolation
- [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Multi-agent coordination
- [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — **AI capabilities via user-configured providers**
- [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md) — Complete TypeScript implementation
- [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) — **NEW: Zero-template approach - Platform requirements**
- [BRANDING_INFERENCE_HEURISTICS.md](./BRANDING_INFERENCE_HEURISTICS.md) — **NEW: Intelligent brand derivation**

---

## Change Log

| Date          | Change                                                                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-02-26    | **Added Section 17: ai-service.exe Package Integrity** - Startup integrity check, hash verification, Authenticode signature validation                  |
| 2026-02-26    | **Added Section 16: AI E2E Test Suite Specification** - Complete test coverage for LLM, Image Gen, Vision, Search, Error handling, Trace ID propagation |
| 2026-02-26    | **Added Section 15: AI Service Failure Governance** - Failure detection, fallback strategy, state transitions for AI_SERVICE_UNAVAILABLE/DEGRADED       |
| 2026-02-26    | **Added Section 14: Trace ID Propagation** - Trace context, HTTP header propagation, AI service request logging with trace ID                           |
| > > > > > > > | 2026-02-26                                                                                                                                              | **Added Section 13: Timeout Granularity Configuration** - Per-operation-type timeouts, timeout enforcement                                             |
| > > > > > > > | 2026-02-26                                                                                                                                              | **Added Section 12: ConstructionTransaction with SDK Version Tracking** - SDK version, commit hash, trace ID, AI operation records for reproducibility |
| > > > > > > > | 2026-02-26                                                                                                                                              | **Added AI_SERVICE_UNAVAILABLE (31) and AI_SERVICE_DEGRADED (32) states** - New states for AI service failure handling                                 |
| > > > > > > > | 2026-02-26                                                                                                                                              | **Added AI_SERVICE_UNAVAILABLE, AI_SERVICE_TIMEOUT, AI_SERVICE_ERROR, AI_SERVICE_DEGRADED error types**                                                |
| > > > > > > > | 2026-02-25                                                                                                                                              | **Added Retry Stage Behavior Specification** - Detailed behavior for 1-3/4-6/7-9/≥10 retry stages with AI strategy and Kernel actions                  |
| > > > > > > > | 2026-02-25                                                                                                                                              | **Added Single Active Transaction Runtime Enforcement** - Code-level enforcement with crash recovery explanation                                       |
| > > > > > > > | 2026-02-25                                                                                                                                              | **Added Invariant: Kernel-Exclusive State Mutation** - Explicit statement that only Kernel mutates BuilderState                                        |
| > > > > > > > | 2026-02-25                                                                                                                                              | **Added Invariant: Single Active Transaction** - Exactly one active ConstructionTransaction per Orchestrator                                           |
| > > > > > > > | 2026-02-25                                                                                                                                              | **Added AssetGenerationFailedEvent** - Event for asset generation failures                                                                             |
| > > > > > > > | 2026-02-25                                                                                                                                              | **Added ASSET_GENERATION_FAILED → RETRYING transition** - State machine path for asset retry                                                           |
| 2026-02-23    | Added ASSET_GENERATION_FAILED, BRANDING_INFERENCE_FAILED, REQUIREMENT_EVALUATION_FAILED error types                                                     |
| 2026-02-23    | Added Platform Requirements & Asset Generation states (26-29)                                                                                           |
| 2026-02-23    | Added RequirementsEvaluatedEvent, BrandingInferredEvent, AssetsGeneratedEvent                                                                           |
| 2026-02-23    | Added state transitions for REQUIREMENT_EVALUATION → BRANDING_INFERENCE → ASSET_GENERATING → ASSETS_READY                                               |
| 2026-02-21    | Converted to Bounded Retry model - removed FAILED state, added SYSTEM_RESET                                                                     |
| 2026-02-21    | Added CANCELLED state as only terminal state (user-initiated only)                                                                                      |
| 2026-02-21    | Added SystemResetEvent and AttemptedApproaches tracking                                                                                                 |
| 2026-02-21    | Fixed all architectural contradictions (1-7)                                                                                                            |
