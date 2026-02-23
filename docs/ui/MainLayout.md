# Main Layout

> **UI Layer: Application Shell and Navigation**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)

---

## Application Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Title Bar                                                    │
│  [App Icon] SyncAI Explorer    [Project: MyApp ▼] [⚙] [−][□][×]│
├─────────────────────────────────────────────────────────────┤
│ Navigation Bar                                               │
│  [Projects] [Editor] [Preview] [Build Monitor] [Settings]   │
├──────────────────┬──────────────────────────────────────────┤
│ Left Panel       │ Main Content Area                        │
│ (200-300px)      │                                          │
│                  │                                          │
│ Project Explorer │ Dynamic content based on selected tab    │
│ or File Tree     │                                          │
│                  │                                          │
├──────────────────┴──────────────────────────────────────────┤
│ Status Bar                                                   │
│ [Orchestrator: IDLE] [SDK: ✓] [Last Build: 2.3s] [Errors: 0]│
└─────────────────────────────────────────────────────────────┘
```

See [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md) for complete MainWindow.xaml.

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from UI_IMPLEMENTATION.md |