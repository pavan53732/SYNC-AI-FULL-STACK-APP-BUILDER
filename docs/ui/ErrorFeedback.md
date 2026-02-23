# Error Feedback UX

> **UI Layer: Two-Tier Recovery System and User-Friendly Error Messages**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)
>
> **Related:** [VisualStateMachine.md](./VisualStateMachine.md) — UI states

---

## Table of Contents

1. [Two-Tier Recovery System](#1-two-tier-recovery-system)
2. [Error Message Translation](#2-error-message-translation)
3. [Recovery Implementation](#3-recovery-implementation)
4. [Anti-Terror UX Rules](#4-anti-terror-ux-rules)

---

## 1. Two-Tier Recovery System

### Tier 1: Silent Auto-Recovery (Initial Retries)

- ✅ No error message shown
- ✅ Spinner continues smoothly
- ✅ No UI change whatsoever
- Exponential backoff applied
- System continues retrying automatically

### Tier 2: Extended Recovery (User Informed)

- Blue warning InfoBar: "Optimizing Build…"
- Message: "We're refining the build. This may take a moment…"
- Cancel button available (user can stop at any time)
- Logs tab becomes visible (collapsed by default)
- System continues retrying until success or user cancellation

---

## 2. Error Message Translation

| Technical Error                | User-Friendly Message                                                                                        |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `CS0246`: namespace not found  | "We couldn't find a required component. The system will attempt to add the missing reference automatically." |
| `CS1061`: member doesn't exist | "There's a mismatch in the code structure. Attempting to fix automatically."                                 |
| `CS0103`: name doesn't exist   | "A variable name wasn't recognized. Retrying with corrections."                                              |
| `MSB3073`: command exited      | "The build process encountered an issue. Retrying with different settings."                                  |

---

## 3. Recovery Implementation

**Tier 1 — `BuildWithSilentRetryAsync()`**:

```csharp
private async Task<BuildResult> BuildWithSilentRetryAsync(
    string projectPath,
    CancellationToken cancellationToken)
{
    var attempt = 0;
    var delay = TimeSpan.FromSeconds(1);

    while (!cancellationToken.IsCancellationRequested)
    {
        attempt++;
        var result = await _buildService.BuildAsync(projectPath, cancellationToken);

        if (result.Success)
        {
            _logger.LogInformation("Build succeeded on attempt {Attempt}", attempt);
            return result;
        }

        // Log internally, don't show to user
        _logger.LogWarning("Build attempt {Attempt} failed: {Error}", attempt, result.Error);

        // Check if we should transition to Tier 2 (extended recovery UI)
        if (attempt >= 3 && !_extendedRecoveryShown)
        {
            _extendedRecoveryShown = true;
            ShowExtendedRecoveryUI();
        }

        // Exponential backoff
        await Task.Delay(delay, cancellationToken);
        delay = TimeSpan.FromMilliseconds(delay.TotalMilliseconds * 1.5);
    }

    // User cancelled
    return BuildResult.Cancelled();
}
```

**Tier 2 — ExtendedRecoveryBar**:

```xaml
<InfoBar x:Name="ExtendedRecoveryBar"
         Severity="Informational"
         IsOpen="False"
         Title="Optimizing Build…"
         Message="We're refining the build. This may take a moment…">
    <InfoBar.ActionButton>
        <Button Content="Cancel"
                Click="{x:Bind ViewModel.CancelBuild}"/>
    </InfoBar.ActionButton>
</InfoBar>
```

---

## 4. Anti-Terror UX Rules

**Never show**:

- Raw MSBuild console output
- Stack traces by default
- Full file paths
- Red error overlays blocking entire UI
- Frozen UI during builds
- Compiler error codes without translation

**Always provide**:

- Animated feedback during operations
- Cancel button for long operations
- Retry option on failures
- State recovery via snapshots
- User-friendly error messages

---

## References

- [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md) — Parent document
- [VisualStateMachine.md](./VisualStateMachine.md) — UI states
- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Retry controller

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from UI_IMPLEMENTATION.md as part of documentation reorganization |