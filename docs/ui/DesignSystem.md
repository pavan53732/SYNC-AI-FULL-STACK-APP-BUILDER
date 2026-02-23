# Design System

> **UI Layer: Window Specifications, Typography, Color Palette, and Spacing**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)
>
> **Related:** [MainLayout.md](./MainLayout.md) — Application layout

---

## Table of Contents

1. [Window Specifications](#1-window-specifications)
2. [Spacing Scale (8px System)](#2-spacing-scale-8px-system)
3. [Typography Scale](#3-typography-scale)
4. [Color Palette — Status Indicators](#4-color-palette--status-indicators)
5. [Material System](#5-material-system)
6. [Component Sizing](#6-component-sizing)

---

## 1. Window Specifications

```csharp
// MainWindow.xaml.cs
public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        // Set window constraints
        this.MinWidth = 1200;
        this.MinHeight = 800;

        // Set default size
        this.Width = 1440;
        this.Height = 900;

        // Apply Mica background
        this.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.BaseAlt };
    }
}
```

- **Minimum Width**: 1200px
- **Minimum Height**: 800px
- **Default Size**: 1440 × 900px
- **Background**: Mica (BaseAlt)
- **Card Corner Radius**: 12px
- **Outer Padding**: 32px

---

## 2. Spacing Scale (8px System)

| Token | Value | Usage                                    |
| ----- | ----- | ---------------------------------------- |
| `xs`  | 4px   | Tight spacing (icon padding)             |
| `sm`  | 8px   | Default spacing between related elements |
| `md`  | 16px  | Section spacing                          |
| `lg`  | 24px  | Major section spacing                    |
| `xl`  | 32px  | Page margins                             |

**ResourceDictionary Implementation**:

```xaml
<ResourceDictionary>
    <x:Double x:Key="SpacingXS">4</x:Double>
    <x:Double x:Key="SpacingSM">8</x:Double>
    <x:Double x:Key="SpacingMD">16</x:Double>
    <x:Double x:Key="SpacingLG">24</x:Double>
    <x:Double x:Key="SpacingXL">32</x:Double>
</ResourceDictionary>
```

---

## 3. Typography Scale

| Style        | Size | Weight   | Usage                        |
| ------------ | ---- | -------- | ---------------------------- |
| **Title**    | 28px | Semibold | Page titles, empty state     |
| **Subtitle** | 20px | Semibold | Section headers              |
| **Body**     | 16px | Regular  | Primary content              |
| **Caption**  | 14px | Regular  | Secondary text, labels       |
| **Small**    | 12px | Regular  | Metadata, timestamps         |
| **Code**     | 14px | Regular  | Code display (Cascadia Code) |

**Style Definitions**:

```xaml
<Style x:Key="TitleStyle" TargetType="TextBlock">
    <Setter Property="FontSize" Value="28"/>
    <Setter Property="FontWeight" Value="Semibold"/>
</Style>

<Style x:Key="SubtitleStyle" TargetType="TextBlock">
    <Setter Property="FontSize" Value="20"/>
    <Setter Property="FontWeight" Value="Semibold"/>
</Style>

<Style x:Key="CodeStyle" TargetType="TextBlock">
    <Setter Property="FontFamily" Value="Cascadia Code"/>
    <Setter Property="FontSize" Value="14"/>
</Style>
```

---

## 4. Color Palette — Status Indicators

| State         | Color  | Hex       | Behavior        |
| ------------- | ------ | --------- | --------------- |
| **Idle**      | Gray   | `#6B6B6B` | Static          |
| **Building**  | Blue   | `#0078D4` | Pulse animation |
| **Packaging** | Purple | `#881798` | Pulse animation |
| **Success**   | Green  | `#107C10` | Flash 300ms     |
| **Error**     | Red    | `#D13438` | Soft pulse      |

**ResourceDictionary**:

```xaml
<ResourceDictionary>
    <SolidColorBrush x:Key="StatusIdleBrush"     Color="#6B6B6B"/>
    <SolidColorBrush x:Key="StatusBuildingBrush" Color="#0078D4"/>
    <SolidColorBrush x:Key="StatusPackagingBrush" Color="#881798"/>
    <SolidColorBrush x:Key="StatusSuccessBrush"  Color="#107C10"/>
    <SolidColorBrush x:Key="StatusErrorBrush"    Color="#D13438"/>
</ResourceDictionary>
```

---

## 5. Material System

**Background Brush Construction**:

```csharp
// Mica for main window background
this.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.BaseAlt };

// Acrylic for side panels
var acrylicBrush = new AcrylicBrush
{
    TintColor = Colors.Transparent,
    TintOpacity = 0.0,
    TintLuminosityOpacity = 0.15,
    FallbackColor = Colors.Transparent
};
```

- **Main Window**: Mica BaseAlt
- **Side Panels**: Acrylic (subtle, 15% luminosity)
- **Cards**: LayerFillColorDefault with 12px corner radius
- **Elevated Cards**: Add subtle drop shadow

---

## 6. Component Sizing

| Component      | Size                                           |
| -------------- | ---------------------------------------------- |
| Primary Button | 160px × 48px, 8px corner radius                |
| Icon Button    | 32px × 32px                                    |
| Chip Button    | Auto width × 32px, 16px corner radius          |
| Prompt Box     | 720px × 48px (empty state), 10px corner radius |
| Text Input     | Auto width × 32px, 6px corner radius           |
| Left Panel     | 260px fixed width                              |
| Top Bar        | Full width × 64px                              |
| Tab Strip      | Full width × 48px                              |

---

## References

- [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md) — Parent document
- [MainLayout.md](./MainLayout.md) — Application layout
- [MicroInteractions.md](./MicroInteractions.md) — Animations
- [VisualStateMachine.md](./VisualStateMachine.md) — UI states

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from UI_IMPLEMENTATION.md as part of documentation reorganization |