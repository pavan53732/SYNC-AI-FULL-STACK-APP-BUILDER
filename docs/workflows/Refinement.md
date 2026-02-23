# Refinement Workflow

> **User Workflows: Iterative App Refinement**
>
> **Parent Document:** [USER_WORKFLOWS.md](../USER_WORKFLOWS.md)

---

## Iterative Refinement

After initial generation, users refine via natural language:

| User Request                            | AI Action                                      |
| :-------------------------------------- | :--------------------------------------------- |
| "Add a dark mode toggle"                | Modify App.xaml, add setting, update styles    |
| "Make the task list grid view"          | Convert ListView → GridView                    |
| "Add email reminders"                   | Add background task, notification API          |
| "Export tasks to CSV"                   | Add export service, file picker integration    |

---

## Refinement Cycle

```
User Request → Safety Guard → Task Graph → Patching → Build → Preview
                    │
                    └──► Reject dangerous changes
```

The Safety Guard prevents breaking changes before they reach the codebase.

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from USER_WORKFLOWS.md |