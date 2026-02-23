# Onboarding & First Launch

> **UI Layer: Empty State, First Build Celebration & Failure Psychology**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)
>
> **Related:** [DesignPhilosophy.md](./DesignPhilosophy.md) | [ProgressiveDisclosure.md](./ProgressiveDisclosure.md) | [VisualStateMachine.md](./VisualStateMachine.md)

---

## Table of Contents

1. [Empty State Layout](#1-empty-state-layout)
2. [What NOT to Do](#2-what-not-to-do)
3. [First Successful Build Celebration](#3-first-successful-build-celebration)
4. [Progressive Mastery Unlock](#4-progressive-mastery-unlock)
5. [Empty Project State XAML](#5-empty-project-state-xaml)
6. [Failure Psychology](#6-failure-psychology)

---

## 1. Empty State Layout

Shown when the app launches for the very first time (no projects exist yet). The `FIRST_LAUNCH` UI state is active.

```
┌────────────────────────────────────┐
│                                    │
│   What would you like to build?   │
│                                    │
│   [                              ] │
│                                    │
│         [ Generate ]               │
│                                    │
│   [CRM] [Inventory] [Task Manager] │
│                                    │
│   Describe your app in plain       │
│   English.                         │
│                                    │
└────────────────────────────────────┘
```

**Psychological Goals**:

| Goal | Message |
|------|---------|
| **Power** | "I can build anything" |
| **Simplicity** | "Just describe it" |
| **Safety** | "No setup required" |

---

## 2. What NOT to Do

The first-launch experience must NOT include:

- ❌ Multi-step onboarding wizard
- ❌ SDK configuration screens
- ❌ Feature tour overlay
- ❌ "Getting Started" guide
- ❌ Account creation or sign-in gate

The user should be able to generate their first app **without reading any documentation**.

---

## 3. First Successful Build Celebration

When the first build completes successfully, a small animated `TeachingTip` acknowledges the milestone:

```csharp
private async void CelebrateFirstSuccess()
{
    // Small animated toast — not a modal dialog
    var toast = new TeachingTip
    {
        Title                = "Your app is ready!",
        Subtitle             = "You can now preview, export, or improve it.",
        IsLightDismissEnabled = true
    };

    await toast.ShowAsync();

    // Subtle scale animation on preview panel (1.0 → 1.05 → 1.0, 200ms each)
    await PreviewPanel.ScaleAsync(1.0, 1.05, duration: 200);
    await PreviewPanel.ScaleAsync(1.05, 1.0, duration: 200);
}
```

---

## 4. Progressive Mastery Unlock

After 3 or more successful projects, advanced UI features are quietly unlocked:

```csharp
private void UnlockAdvancedFeatures()
{
    if (_projectService.GetProjectCount() >= 3)
    {
        // Subtle unlock — no fanfare
        HistoryTab.Visibility    = Visibility.Visible;
        DiffViewTooltip.IsEnabled = true;

        // One-time teaching tip
        ShowTeachingTip("Advanced features unlocked! Check Settings for Developer Mode.");
    }
}
```

See [ProgressiveDisclosure.md](./ProgressiveDisclosure.md) for the full list of gated features.

---

## 5. Empty Project State XAML

Shown when a user opens an existing project that has not had any features added yet:

```xaml
<StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
    <FontIcon Glyph="&#xE8F1;" FontSize="64" Opacity="0.3"/>

    <TextBlock Text="This project doesn't have any features yet."
               FontSize="16" Margin="0,16,0,8"/>

    <TextBlock Text="Describe what you'd like to add."
               FontSize="14"
               Foreground="{ThemeResource TextFillColorSecondaryBrush}"/>

    <Button Content="Add a Feature" Margin="0,16,0,0"/>
</StackPanel>
```

---

## 6. Failure Psychology

Even when something goes wrong internally, the language and visuals must remain calm and constructive.

**❌ Never Use**:

- "Build failed"
- "Unhandled exception"
- Red backgrounds or overlays
- Blame language ("You did something wrong")

**✅ Always Use**:

- "We couldn't complete this request"
- Neutral gray card with a small warning icon
- Gentle, action-oriented language
- Clear next steps (retry, cancel, contact support)

---

## References

- [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md) — Parent document (section 10)
- [DesignPhilosophy.md](./DesignPhilosophy.md) — Foundational principles behind this approach
- [ProgressiveDisclosure.md](./ProgressiveDisclosure.md) — Feature-gating after first launch
- [VisualStateMachine.md](./VisualStateMachine.md) — `FIRST_LAUNCH` state definition

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from UI_IMPLEMENTATION.md §10 as part of documentation reorganization |
