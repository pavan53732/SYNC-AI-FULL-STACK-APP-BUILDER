# Progressive Disclosure

> **UI Layer: Simple Mode, Developer Mode & Feature Gating**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)
>
> **Related:** [DesignPhilosophy.md](./DesignPhilosophy.md) | [Onboarding.md](./Onboarding.md)

---

## Table of Contents

1. [Default View — Simple Mode](#1-default-view--simple-mode)
2. [Developer Mode](#2-developer-mode)
3. [Progressive Mastery](#3-progressive-mastery)
4. [UpdateNavigationItems Implementation](#4-updatenavigationitems-implementation)

---

## 1. Default View — Simple Mode

**Always Visible** (every user, every session):

- Prompt input box
- Generate button
- Preview tabs
- Export button
- Minimal status bar (Orchestrator state, last build time)

**Hidden by Default** (complexity suppressed until needed):

- Build Monitor panel
- Task graph visualization
- Raw build logs
- Retry attempt details
- Snapshot history browser
- Advanced build settings

---

## 2. Developer Mode

Enabled via **Settings → Developer Options → Developer Mode**.

When enabled, the following are revealed:

| Feature | Where Revealed |
|---------|---------------|
| Build Monitor tab | Navigation bar |
| Detailed status bar info | Status bar |
| Error codes with stack traces | Error dialogs |
| Full file paths in errors | Error messages |
| Logs tab | During `SOFT_RECOVERY` state |

> **PRINCIPLE**: Developer Mode is opt-in. The default experience is always the simplified consumer view. Developer Mode is for debugging and advanced inspection — not for day-to-day use.

```xaml
<!-- Settings Page — Developer Options expander -->
<Expander Header="Developer Options">
    <StackPanel Spacing="12" Padding="12">
        <ToggleSwitch Header="Developer Mode"
                      IsOn="{x:Bind ViewModel.DeveloperModeEnabled, Mode=TwoWay}"
                      OnContent="Enabled"
                      OffContent="Disabled"/>

        <InfoBar Severity="Informational"
                 IsOpen="True"
                 Message="Developer Mode is recommended only for debugging. Most users should keep this disabled for a cleaner experience."/>
    </StackPanel>
</Expander>
```

---

## 3. Progressive Mastery

After **3 or more projects** are successfully built, additional features are subtly unlocked with a one-time teaching tip:

- **History tab** — browse previous build versions
- **Diff view tooltip** — enabled on preview panel

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

---

## 4. `UpdateNavigationItems` Implementation

The navigation bar is rebuilt every time Developer Mode is toggled. Build Monitor is conditionally inserted:

```csharp
// MainWindow.xaml.cs — called by DeveloperModeEnabled setter
private void UpdateNavigationItems()
{
    var navItems = new List<NavigationViewItem>
    {
        new() { Content = "Projects", Icon = new SymbolIcon(Symbol.Folder),  Tag = "projects" },
        new() { Content = "Editor",   Icon = new SymbolIcon(Symbol.Edit),    Tag = "editor"   },
        new() { Content = "Preview",  Icon = new SymbolIcon(Symbol.View),    Tag = "preview"  },
        new() { Content = "Settings", Icon = new SymbolIcon(Symbol.Setting), Tag = "settings" }
    };

    // Build Monitor only visible in Developer Mode
    if (ViewModel.DeveloperModeEnabled)
    {
        navItems.Insert(3, new NavigationViewItem
        {
            Content = "Build Monitor",
            Icon    = new SymbolIcon(Symbol.RepeatAll),
            Tag     = "build"
        });
    }

    NavView.MenuItems.Clear();
    foreach (var item in navItems)
        NavView.MenuItems.Add(item);
}
```

---

## References

- [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md) — Parent document (section 9)
- [DesignPhilosophy.md](./DesignPhilosophy.md) — Why complexity is hidden
- [Onboarding.md](./Onboarding.md) — First-launch contextual disclosure
- [VisualStateMachine.md](./VisualStateMachine.md) — State-driven visibility rules

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from UI_IMPLEMENTATION.md §9 as part of documentation reorganization |
