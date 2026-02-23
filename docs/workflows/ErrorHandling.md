# Error Handling Workflow

> **User Workflows: Silent Recovery and User-Facing Error Experience**
>
> **Parent Document:** [USER_WORKFLOWS.md](../USER_WORKFLOWS.md)

---

## Silent Auto-Recovery

The system handles most errors without user awareness:

1. Build fails → Auto-retry with adjusted parameters
2. AI response incomplete → Request continuation
3. Dependency missing → Auto-install via NuGet
4. XAML binding error → Suggest fix and retry

User sees: Smooth progress, no interruption.

---

## User-Facing Errors

When recovery fails after max attempts:

| Situation           | User Message                                        |
| :------------------ | :-------------------------------------------------- |
| Build failed        | "We couldn't complete the build. Please try again." |
| AI service error    | "Connection issue. Please check your AI settings."  |
| Disk full           | "Not enough disk space. Please free up space."      |

---

## Recovery Options

- **Retry**: Attempt the operation again
- **Undo**: Revert to last known good state
- **Export Logs**: Download diagnostic information (Dev Mode)

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from USER_WORKFLOWS.md |