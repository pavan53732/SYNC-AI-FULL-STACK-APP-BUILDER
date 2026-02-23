# Retry Controller

> **Orchestration Layer: Retry Stages, Governance, and Escalation Policy**
>
> **Parent Document:** [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md)
>
> **Related:** [StateMachine.md](./StateMachine.md) — Builder states and transitions

---

## Table of Contents

1. [Retry Ownership](#1-retry-ownership)
2. [Retry Stages](#2-retry-stages)
3. [Retry Stage Behavior Specification](#3-retry-stage-behavior-specification)
4. [Retry Controller Logic](#4-retry-controller-logic)
5. [Retry Governance Contract](#5-retry-governance-contract)
6. [Error Classification](#6-error-classification)

---

## 1. Retry Ownership

> **INVARIANT**: The Orchestrator is the ONLY component that manages retry loops. Agents MUST NOT have internal retry loops. Agents attempt a fix ONCE and return. The Orchestrator decides whether to retry.

---

## 2. Retry Stages

### Continuous - Never Abort

```csharp
public enum RetryStage
{
    FIX_LEVEL,          // Stage 1: Try local token repairs (retries 1-3)
    INTEGRATION_LEVEL,  // Stage 2: Check DI and wiring (retries 4-6)
    ARCHITECTURE_LEVEL, // Stage 3: Re-evaluate high-level plan (retries 7-9)
    SYSTEM_RESET        // Stage 4: Rollback, Wipe AI Memory, Try New Approach (retry 10+)
}
```

---

## 3. Retry Stage Behavior Specification

> **INVARIANT**: Each retry stage has defined escalation behavior. The AI must adapt its strategy as retries progress.

| Retry Range | Stage | AI Strategy | Kernel Action |
|-------------|-------|-------------|---------------|
| **1-3** | FIX_LEVEL | Local token repairs, syntax fixes, small adjustments | Log retry, allow continuation |
| **4-6** | INTEGRATION_LEVEL | Check DI wiring, service registration, module boundaries | Log retry, warn if pattern persists |
| **7-9** | ARCHITECTURE_LEVEL | Re-evaluate high-level plan, structural changes, alternative approaches | Log retry, prepare for potential reset |
| **≥10** | SYSTEM_RESET | **N/A - AI memory wiped** | Rollback to snapshot, clear context, track failed approach, restart fresh |

### Stage Transition Behavior

```
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
├── State rolled back to PreMutationSnapshotId
├── SystemResetCount incremented
└── Fresh attempt with no prior context
```

> **Note**: SYSTEM_RESET does NOT mean failure. It means "try a completely different approach." The system NEVER stops - only user cancellation terminates execution.

---

## 4. Retry Controller Logic

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

---

## 5. Retry Governance Contract

| Retry Range | Owner | Enforcement | Behavior |
|-------------|-------|-------------|----------|
| 1-9 | AI Construction Engine | Strategy flexible | AI adapts, learns, retries |
| 10+ | Runtime Safety Kernel | System Reset + Amnesia | Rollback, wipe memory, fresh approach |

---

## 6. Error Classification

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

## References

- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Parent document
- [StateMachine.md](./StateMachine.md) — Builder states and transitions
- [SnapshotAuthority.md](./SnapshotAuthority.md) — Rollback mechanisms
- [AI_SERVICE_LAYER.md](../AI_SERVICE_LAYER.md) — AI service integration

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from ORCHESTRATION_ENGINE.md as part of documentation reorganization |