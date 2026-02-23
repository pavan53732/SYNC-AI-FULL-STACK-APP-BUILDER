# Accessibility

> **UI Layer: Theme System, Keyboard Navigation, and Screen Reader Support**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)

---

## Light/Dark Mode

```xaml
<Application.Resources>
    <ResourceDictionary>
        <ResourceDictionary.ThemeDictionaries>
            <ResourceDictionary x:Key="Light">
                <SolidColorBrush x:Key="AppBackgroundBrush" Color="#FFFFFF"/>
                <SolidColorBrush x:Key="CodeBackgroundBrush" Color="#F5F5F5"/>
            </ResourceDictionary>
            <ResourceDictionary x:Key="Dark">
                <SolidColorBrush x:Key="AppBackgroundBrush" Color="#1E1E1E"/>
                <SolidColorBrush x:Key="CodeBackgroundBrush" Color="#252526"/>
            </ResourceDictionary>
        </ResourceDictionary.ThemeDictionaries>
    </ResourceDictionary>
</Application.Resources>
```

---

## Accessibility Requirements

- All interactive elements must have `AutomationProperties.Name`
- Keyboard navigation for all features
- High contrast mode support
- Screen reader compatibility
- Minimum touch target size: 44×44px

**Example**:

```xaml
<Button Content="Generate"
        AutomationProperties.Name="Generate Application Button"
        AutomationProperties.HelpText="Starts the application generation process"
        ToolTipService.ToolTip="Generate Application (Ctrl+G)"/>
```

---

## Performance

- `ListView` virtualization for large lists
- Incremental loading for file trees
- Lazy-load code preview content
- All operations async with progress indication

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from UI_IMPLEMENTATION.md |