# Snapshot Authority

> **Orchestration Layer: Snapshot Timing, Transaction Management, and Rollback**
>
> **Parent Document:** [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md)
>
> **Related:** [StateMachine.md](./StateMachine.md) — Builder states and transitions

---

## Table of Contents

1. [State Container & Event Log](#1-state-container--event-log)
2. [State Reducer](#2-state-reducer)
3. [Snapshot Timing Invariant](#3-snapshot-timing-invariant)
4. [Single Active Transaction Invariant](#4-single-active-transaction-invariant)
5. [Snapshot Creation Points](#5-snapshot-creation-points)
6. [Snapshot Lifecycle](#6-snapshot-lifecycle)

---

## 1. State Container & Event Log

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

## 2. State Reducer

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

## 3. Snapshot Timing Invariant

> **INVARIANT**: A snapshot MUST be created BEFORE any mutation. This is enforced by the `CREATING_SNAPSHOT` state in the state machine.

---

## 4. Single Active Transaction Invariant

> **INVARIANT**: Each Orchestrator instance may have **EXACTLY ONE** active `ConstructionTransaction` at any time.
>
> This is a runtime-enforced constraint, not just a documentation rule.

### Runtime Enforcement Code

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

### Crash Recovery After Transaction Violation

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
> - State is always in a consistent, recoverable state
> - Rollback has a clear target (the pre-mutation snapshot)
> - Concurrent mutation bugs are caught immediately (crash early, fail fast)

---

## 5. Snapshot Creation Points

| Trigger | State | Purpose |
|---------|-------|---------|
| Before PATCHING | `CREATING_SNAPSHOT` | Enable rollback on failure or system reset |
| Before PACKAGING | `CREATING_SNAPSHOT` | Enable rollback on packaging failure |
| Manual user request | Any non-mutation state | User-initiated checkpoint |

---

## 6. Snapshot Lifecycle

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

## References

- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Parent document
- [StateMachine.md](./StateMachine.md) — Builder states and transitions
- [RetryController.md](./RetryController.md) — System reset handling
- [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md) — Git-based snapshot storage

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from ORCHESTRATION_ENGINE.md as part of documentation reorganization |