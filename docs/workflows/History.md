# History & Time Travel

> **User Workflows: Snapshots, Undo/Redo, and State Recovery**
>
> **Parent Document:** [USER_WORKFLOWS.md](../USER_WORKFLOWS.md)

---

## Project Time Travel

Every generation creates a snapshot:

```
Project/History/
├── 001_initial_generation/
│   ├── snapshot.json
│   └── Files/
├── 002_added_dark_mode/
│   ├── snapshot.json
│   └── Files/
└── 003_added_notifications/
    ├── snapshot.json
    └── Files/
```

---

## History Controls

| Control       | Action                                    |
| :------------ | :---------------------------------------- |
| **Undo**      | Revert to previous snapshot               |
| **Redo**      | Re-apply a reverted snapshot              |
| **Browse**    | View history timeline, preview any state  |
| **Restore**   | Full restore to any historical point      |

---

## Snapshot Contents

Each snapshot includes:
- Complete file state
- Generation prompt
- Task graph used
- Build result
- Timestamp

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from USER_WORKFLOWS.md |