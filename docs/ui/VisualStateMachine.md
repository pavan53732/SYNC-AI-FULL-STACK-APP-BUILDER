# Visual State Machine

> **UI Layer: UI States, Orchestrator Mapping, and State Transitions**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)
>
> **Related:** [ErrorFeedback.md](./ErrorFeedback.md) — Error handling UX

---

## Table of Contents

1. [Core Principle](#1-core-principle)
2. [The 6 User-Visible States](#2-the-6-user-visible-states)
3. [Orchestrator → UI State Mapping](#3-orchestrator→ui-state-mapping)
4. [State Mapping Implementation](#4-state-mapping-implementation)
5. [State Transition Diagram](#5-state-transition-diagram)

---

## 1. Core Principle

> **UI state ≠ Orchestrator state**
> 
> The UI abstracts complexity by mapping many backend states into few calm visual states.

**Backend Reality**: 15+ orchestrator states
**User Experience**: 8 simple states

---

## 2. The 6 User-Visible States

### 🔷 FIRST_LAUNCH
- **Trigger**: App installed, no projects exist
- **UI**: Centered prompt with suggestion chips ("CRM", "Inventory", "Task Manager")
- **→** `EMPTY_IDLE` (after first project created)

### 🔷 EMPTY_IDLE
- **Trigger**: Project exists, Orchestrator `IDLE`
- **UI**: Prompt box centered and active, Generate button enabled, status dot gray
- **→** `TYPING` (prompt focused) or `BUILDING` (Generate clicked)

### 🔷 TYPING
- **Trigger**: Prompt field focused or text changed
- **UI**: Generate button full opacity, helper hints fade out, suggestion chips dim
- **→** `BUILDING` (Generate clicked) or `EMPTY_IDLE` (input cleared)

### 🔷 BUILDING
- **Trigger**: Orchestrator enters execution
- **UI**: "Building…" text, blue pulsing dot, soft shimmer, previous preview blurred
- **Hidden**: Task names, retry counter, file operations, state transitions
- **→** `PREVIEW_READY` (success) or `SOFT_RECOVERY` (retry 4+)

### 🔷 PREVIEW_READY
- **Trigger**: Orchestrator `COMPLETED`
- **UI**: Green flash (300ms), preview rendered, action buttons appear
- **→** `BUILDING` (new prompt)

### 🔷 SOFT_RECOVERY
- **Trigger**: Retries ongoing (extended duration)
- **UI**: Banner "Optimizing build…" (blue, not red), Cancel button
- **→** `PREVIEW_READY` (retry succeeded) or `EMPTY_IDLE` (user cancelled)

### 🔷 INTERVENTION_REQUIRED
- **Trigger**: Safety Guard blocks mutation
- **UI**: Warning InfoBar explaining dependency impact, Force Apply / Discard buttons
- **→** `BUILDING` (Force Apply) or `EMPTY_IDLE` (Discard)

---

## 3. Orchestrator → UI State Mapping

| UI State                | Orchestrator States (Backend)                                                                                                          |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `FIRST_LAUNCH`          | N/A (no orchestrator instance)                                                                                                         |
| `EMPTY_IDLE`            | `IDLE`                                                                                                                                 |
| `TYPING`                | `IDLE` (no backend change)                                                                                                             |
| `BUILDING`              | `SPEC_PARSED`, `TASK_GRAPH_READY`, `MUTATION_GUARD`, `PATCHING`, `INDEXING`, `TASK_EXECUTING`, `VALIDATING`, `RETRYING` (initial)     |
| `PREVIEW_READY`         | `COMPLETED`                                                                                                                            |
| `SOFT_RECOVERY`         | `RETRYING` (extended duration, user informed)                                                                                          |
| `INTERVENTION_REQUIRED` | `GUARD_REJECTED`                                                                                                                       |

---

## 4. State Mapping Implementation

```csharp
private UIState MapToUIState(OrchestratorState orchestratorState, bool extendedRetry)
{
    return orchestratorState switch
    {
        OrchestratorState.IDLE               => UIState.EMPTY_IDLE,
        OrchestratorState.SPEC_PARSED        => UIState.BUILDING,
        OrchestratorState.TASK_GRAPH_READY   => UIState.BUILDING,
        OrchestratorState.MUTATION_GUARD     => UIState.BUILDING,
        OrchestratorState.PATCHING           => UIState.BUILDING,
        OrchestratorState.INDEXING           => UIState.BUILDING,
        OrchestratorState.TASK_EXECUTING     => UIState.BUILDING,
        OrchestratorState.VALIDATING         => UIState.BUILDING,
        OrchestratorState.RETRYING when !extendedRetry => UIState.BUILDING,
        OrchestratorState.RETRYING when extendedRetry  => UIState.SOFT_RECOVERY,
        OrchestratorState.COMPLETED          => UIState.PREVIEW_READY,
        OrchestratorState.GUARD_REJECTED     => UIState.INTERVENTION_REQUIRED,
        _                                    => UIState.EMPTY_IDLE
    };
}
```

---

## 5. State Transition Diagram

```
┌─────────────┐
│FIRST_LAUNCH │ (No projects)
└──────┬──────┘
       │ Create first project
       ↓
┌─────────────┐
│ EMPTY_IDLE  │ (Project exists, idle)
└──────┬──────┘
       │ Focus prompt
       ↓
┌─────────────┐
│   TYPING    │ (Prompt active)
└──────┬──────┘
       │ Click Generate
       ↓
┌─────────────┐
│  BUILDING   │ (Orchestrator executing, silent retries)
└──────┬──────┘
       │
       ├─────────────┬──────────────┐
       │ Success     │ Extended     │ User cancels
       │             │ retry        │
       ↓             ↓              ↓
┌──────────────┐ ┌────────────┐ ┌──────────────┐
│PREVIEW_READY │ │SOFT_RECOVERY│ │ EMPTY_IDLE   │
└──────────────┘ └────────────┘ └──────────────┘
       │             │              │
       │             │ (continues   │
       │             │  retrying)   │
       │             ↓              │
       │      ┌──────────────┐      │
       └─────→│PREVIEW_READY │←─────┘
              └──────────────┘
```

---

## References

- [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md) — Parent document
- [ErrorFeedback.md](./ErrorFeedback.md) — Error handling UX
- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Backend states

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from UI_IMPLEMENTATION.md as part of documentation reorganization |