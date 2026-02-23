# Crash Recovery

> **Execution Layer: Boot Safety Controls, Session Recovery, and Restore Procedures**
>
> **Parent Document:** [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md)
>
> **Related:** [FilesystemSandbox.md](./FilesystemSandbox.md) — Snapshot constraints

---

## Table of Contents

1. [Boot Safety Controls](#1-boot-safety-controls)
2. [Crash Recovery Flow](#2-crash-recovery-flow)
3. [Recovery Steps](#3-recovery-steps)

---

## 1. Boot Safety Controls

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

---

## 2. Crash Recovery Flow

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

---

## 3. Recovery Steps

1. Log the detection of incomplete session
2. Automatically rollback to last stable snapshot
3. Mark the crashed version as failed in history
4. Show gentle notification to user (no technical details)

---

## References

- [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md) — Parent document
- [FilesystemSandbox.md](./FilesystemSandbox.md) — Snapshot constraints
- [ResourceMonitoring.md](./ResourceMonitoring.md) — Health monitoring
- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — State recovery

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from EXECUTION_ENVIRONMENT.md as part of documentation reorganization |