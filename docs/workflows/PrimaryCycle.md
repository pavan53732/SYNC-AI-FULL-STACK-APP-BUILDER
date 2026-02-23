# Primary Cycle

> **User Workflows: The Generate Cycle**
>
> **Parent Document:** [USER_WORKFLOWS.md](../USER_WORKFLOWS.md)

---

## The Generate Cycle

```
┌─────────────────────────────────────────────────────────────────────┐
│ USER: "Build me a task manager with categories and due dates"      │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ AI CONSTRUCTION ENGINE (The Primary Brain)                         │
│                                                                     │
│ 1. Parse Intent → Structured Specification                         │
│ 2. Select Architecture Template (MVVM,三层, etc.)                  │
│ 3. Design Data Model (entities, relationships)                     │
│ 4. Generate UI Layout (XAML views)                                 │
│ 5. Implement Business Logic (ViewModels, services)                 │
│ 6. Create Database Schema (SQLite migrations)                      │
│ 7. Emit Unit Tests                                                 │
│ 8. Package as MSIX (auto-sign)                                    │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ RESULT: Running App in Preview + MSIX Installer                    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## User Responsibility

The user is responsible only for:

- Describing intent
- Accepting or rejecting changes
- Requesting refinements

All technical complexity is hidden.

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from USER_WORKFLOWS.md |