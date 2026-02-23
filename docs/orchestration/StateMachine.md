# State Machine

> **Orchestration Layer: Builder States, Transitions, and Terminal States**
>
> **Parent Document:** [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md)
>
> **Related:** [RetryController.md](./RetryController.md) — Retry stages and escalation

---

## Table of Contents

1. [Core Challenge & Positioning](#1-core-challenge--positioning)
2. [Task Schema](#2-task-schema)
3. [Builder States](#3-builder-states)
4. [State Diagram](#4-state-diagram)
5. [Terminal States](#5-terminal-states)

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

## 3. Builder States

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

---

## 4. State Diagram

### Infinite Silent Retry Model

```
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

---

## 5. Terminal States

| State | Type | Description | Recovery |
|-------|------|-------------|----------|
| `PACKAGING_SUCCEEDED` | Success | Application built, packaged, and ready | None needed |
| `CANCELLED` | Terminal | User explicitly cancelled | User must restart build |

**NOTE**: There is NO `FAILED` state. The system never stops on its own - only user cancellation stops the build.

---

## References

- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Parent document
- [RetryController.md](./RetryController.md) — Retry stages and escalation
- [Concurrency.md](./Concurrency.md) — Thread types and locking
- [SnapshotAuthority.md](./SnapshotAuthority.md) — Snapshot timing and rollback
- [API_Contracts.md](./API_Contracts.md) — Service interfaces
- [SYSTEM_ARCHITECTURE.md](../SYSTEM_ARCHITECTURE.md) — 8-layer overview

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from ORCHESTRATION_ENGINE.md as part of documentation reorganization |