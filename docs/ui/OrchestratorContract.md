# UI → Orchestrator Contract

> **UI Layer: Command Pattern and Event Subscription**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)
>
> **Related:** [VisualStateMachine.md](./VisualStateMachine.md) — UI states

---

## Table of Contents

1. [Command Pattern](#1-command-pattern)
2. [Event Subscription](#2-event-subscription)
3. [Strict Boundaries](#3-strict-boundaries)

---

## 1. Command Pattern

UI sends commands to Orchestrator:

```csharp
public class EditorViewModel : ObservableObject
{
    private readonly IOrchestrator _orchestrator;

    public async Task GenerateApp()
    {
        var command = new GenerateProjectCommand
        {
            Prompt = this.Prompt,
            ProjectPath = this.CurrentProjectPath,
            GenerationMode = this.SelectedMode
        };

        await _orchestrator.SubmitCommandAsync(command);
    }
}
```

---

## 2. Event Subscription

UI receives events on dispatcher thread:

```csharp
public class BuildMonitorViewModel : ObservableObject
{
    public BuildMonitorViewModel(IOrchestrator orchestrator)
    {
        orchestrator.StateChanged += OnOrchestratorStateChanged;
        orchestrator.TaskProgress += OnTaskProgress;
        orchestrator.BuildResult += OnBuildResult;
        orchestrator.Error += OnError;
    }

    private void OnOrchestratorStateChanged(object sender, StateChangedEvent e)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            CurrentState = e.NewState.ToString();
            StateDescription = e.Description;
            UpdateStateIcon(e.NewState);
        });
    }

    private void OnTaskProgress(object sender, TaskProgressEvent e)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            CurrentTaskName = e.TaskName;
            TaskProgress    = e.ProgressPercentage;
            RetryCount      = e.RetryCount;
        });
    }
}
```

---

## 3. Strict Boundaries

**UI Never**: Calls kernel services, modifies workspace files, handles retry logic, executes build commands, manages state transitions

**UI Always**: Sends commands to Orchestrator, subscribes to events, updates on dispatcher thread, validates input before sending, shows loading states

---

## References

- [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md) — Parent document
- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Orchestrator interface
- [AI_RUNTIME_MODEL.md](../AI_RUNTIME_MODEL.md) — AI-Primary model

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from UI_IMPLEMENTATION.md as part of documentation reorganization |