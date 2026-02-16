# UI IMPLEMENTATION

> **The Presentation Layer: Design Philosophy, WinUI 3 Components, Visual State Machine & Error Feedback**
>
> _Merged from: DESIGN_PHILOSOPHY.md, UI_SPECIFICATION.md, UI_STATE_MACHINE.md, ERROR_HANDLING_SPECIFICATION.md_

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Architecture & Rules](#2-architecture--rules)
3. [Design System](#3-design-system)
4. [Main Application Layout](#4-main-application-layout)
5. [Page Specifications](#5-page-specifications)
6. [Micro-Interactions & Motion Design](#6-micro-interactions--motion-design)
7. [Visual State Machine](#7-visual-state-machine)
8. [Error Feedback UX](#8-error-feedback-ux)
9. [Progressive Disclosure](#9-progressive-disclosure)
10. [Onboarding & First Launch](#10-onboarding--first-launch)
11. [Theme System & Accessibility](#11-theme-system--accessibility)
12. [UI → Orchestrator Contract](#12-ui--orchestrator-contract)

---

## 1. Design Philosophy

### The Central Principle

> **Hide complexity, show only results.**
>
> Smooth UX does not mean the system is simple.
> It means the system is sophisticated AND the UI abstracts away the details.
> **The Goal**: A completely autonomous construction environment where the user never needs to touch an IDE, CLI, or compiler logs.

**What Users See** vs **What Happens Internally**:

```
USER VIEW                                INTERNAL REALITY
─────────────────────────────────────────────────────────
Prompt input                             Natural language parsing
                                         Intent extraction
                                         Feature mapping
         ↓                               Feature decomposition
[Spinner...]                            Architecture design
                                        Code generation (agents)
                                        Syntax validation
                                        Dependency resolution
                                        Build compilation
                                        Error detection
                                        Auto-fix execution
         ↓                               Re-compilation
✅ Working app preview                  Final validation
                                        Preview rendering
```

### The 5 Principles

1. **Fail Silently, Succeed Loudly** — Internal errors: classify and auto-fix. Only show success states. Never show compile logs or raw MSBuild output.

2. **One UI, Multiple Stages** — Single spinner for entire pipeline. Multiple stages happen invisibly. Single preview result shown.

3. **Intelligent Scoping** — Impact analysis before regeneration. Only touch affected modules. Preserve untouched code.

4. **Opinionated Defaults** — Constrain stack choices (WinUI 3 + .NET 8 + SQLite). Use opinionated templates. Enforce naming conventions.

5. **Real Code Ownership** — Generate actual C#, XAML, SQL (not proprietary format). Export to GitHub, download as ZIP, continue in IDE.

### The Psychology of "Hidden Complexity"

- **Reduced Cognitive Load** — One clear result (working app)
- **Increased Confidence** — No errors = system works
- **Speed Perception** — Spinner is brief, no intermediate steps
- **Trust Building** — Consistently works, no surprises

---

## 2. Architecture & Rules

### Core Principles

- **WinUI 3** (Windows App SDK) — Modern Windows UI framework
- **MVVM pattern mandatory** — ViewModels handle all UI logic
- **UI is thin** — No business logic in code-behind
- **No direct file writes** — All file operations through services
- **No direct build calls** — All actions go through Orchestrator
- **All long operations async** — Never block UI thread
- **Fluent Design System** — Follow Microsoft's design language

### Dependency Injection

```csharp
public partial class App : Application
{
    private readonly IServiceProvider _services;

    public App()
    {
        _services = ConfigureServices();
    }

    private IServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();

        // ViewModels
        services.AddTransient<MainViewModel>();
        services.AddTransient<EditorViewModel>();
        services.AddTransient<ProjectsViewModel>();
        services.AddTransient<BuildMonitorViewModel>();

        // Services
        services.AddSingleton<IProjectService, ProjectService>();
        services.AddScoped<IOrchestrator, OrchestratorService>();
        services.AddScoped<IPreviewService, PreviewService>();
        services.AddScoped<IRoslynIndexer, RoslynIndexerService>();

        return services.BuildServiceProvider();
    }

    public static T GetService<T>() =>
        ((App)Current)._services.GetService<T>();
}
```

---

## 3. Design System

### Window Specifications

- **Minimum Width**: 1200px
- **Minimum Height**: 800px
- **Default Size**: 1440 × 900px
- **Background**: Mica (BaseAlt)
- **Card Corner Radius**: 12px
- **Outer Padding**: 32px

### Spacing Scale (8px System)

| Token | Value | Usage                                    |
| ----- | ----- | ---------------------------------------- |
| `xs`  | 4px   | Tight spacing (icon padding)             |
| `sm`  | 8px   | Default spacing between related elements |
| `md`  | 16px  | Section spacing                          |
| `lg`  | 24px  | Major section spacing                    |
| `xl`  | 32px  | Page margins                             |

### Typography Scale

| Style        | Size | Weight   | Usage                        |
| ------------ | ---- | -------- | ---------------------------- |
| **Title**    | 28px | Semibold | Page titles, empty state     |
| **Subtitle** | 20px | Semibold | Section headers              |
| **Body**     | 16px | Regular  | Primary content              |
| **Caption**  | 14px | Regular  | Secondary text, labels       |
| **Small**    | 12px | Regular  | Metadata, timestamps         |
| **Code**     | 14px | Regular  | Code display (Cascadia Code) |

### Color Palette — Status Indicators

| State        | Color | Hex       | Behavior        |
| ------------ | ----- | --------- | --------------- |
| **Idle**     | Gray  | `#6B6B6B` | Static          |
| **Building** | Blue  | `#0078D4` | Pulse animation |
| **Success**  | Green | `#107C10` | Flash 300ms     |
| **Error**    | Red   | `#D13438` | Soft pulse      |

### Material System

- **Main Window**: Mica BaseAlt
- **Side Panels**: Acrylic (subtle, 15% luminosity)
- **Cards**: LayerFillColorDefault with 12px corner radius
- **Elevated Cards**: Add subtle drop shadow

### Component Sizing

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

## 4. Main Application Layout

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

### MainWindow.xaml

```xaml
<Window x:Class="SyncAIAppBuilder.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SyncAI Explorer"
        MinWidth="1200" MinHeight="800">

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="48"/> <!-- Title Bar -->
            <RowDefinition Height="48"/> <!-- Navigation -->
            <RowDefinition Height="*"/>  <!-- Content -->
            <RowDefinition Height="32"/> <!-- Status Bar -->
        </Grid.RowDefinitions>

        <!-- Title Bar -->
        <Grid Grid.Row="0" Background="{ThemeResource SystemAccentColor}">
            <StackPanel Orientation="Horizontal" Padding="16,0">
                <Image Source="/Assets/AppIcon.png" Width="24" Height="24"/>
                <TextBlock Text="SyncAI Explorer"
                           Foreground="White" FontSize="16" FontWeight="SemiBold"
                           VerticalAlignment="Center" Margin="12,0,0,0"/>
                <ComboBox x:Name="ProjectSelector" Width="200" Margin="32,0,0,0"
                          VerticalAlignment="Center"
                          ItemsSource="{x:Bind ViewModel.Projects, Mode=OneWay}"
                          SelectedItem="{x:Bind ViewModel.CurrentProject, Mode=TwoWay}"/>
            </StackPanel>
        </Grid>

        <!-- Navigation Bar -->
        <NavigationView Grid.Row="1" x:Name="NavView"
                        IsBackButtonVisible="Collapsed"
                        IsSettingsVisible="False"
                        PaneDisplayMode="Top"
                        SelectionChanged="OnNavigationChanged">
            <NavigationView.MenuItems>
                <NavigationViewItem Content="Projects" Icon="Folder" Tag="projects"/>
                <NavigationViewItem Content="Editor" Icon="Edit" Tag="editor"/>
                <NavigationViewItem Content="Preview" Icon="View" Tag="preview"/>
                <NavigationViewItem Content="Build Monitor" Icon="RepeatAll" Tag="build"/>
                <NavigationViewItem Content="Settings" Icon="Setting" Tag="settings"/>
            </NavigationView.MenuItems>
        </NavigationView>

        <!-- Main Content -->
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="250" MinWidth="200" MaxWidth="400"/>
                <ColumnDefinition Width="4"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0"
                    Background="{ThemeResource LayerFillColorDefaultBrush}"
                    BorderBrush="{ThemeResource CardStrokeColorDefaultBrush}"
                    BorderThickness="0,0,1,0">
                <Frame x:Name="LeftPanelFrame"/>
            </Border>

            <GridSplitter Grid.Column="1"
                          Background="{ThemeResource DividerStrokeColorDefaultBrush}"/>

            <Frame Grid.Column="2" x:Name="ContentFrame"/>
        </Grid>

        <!-- Status Bar -->
        <Grid Grid.Row="3"
              Background="{ThemeResource LayerFillColorDefaultBrush}"
              BorderBrush="{ThemeResource CardStrokeColorDefaultBrush}"
              BorderThickness="0,1,0,0">
            <StackPanel Orientation="Horizontal" Padding="12,0" Spacing="16">
                <TextBlock>
                    <Run Text="Orchestrator:"/>
                    <Run Text="{x:Bind ViewModel.OrchestratorState, Mode=OneWay}"
                         FontWeight="SemiBold"/>
                </TextBlock>
                <TextBlock>
                    <Run Text="SDK:"/>
                    <Run Text="{x:Bind ViewModel.SdkStatus, Mode=OneWay}"/>
                </TextBlock>
                <TextBlock>
                    <Run Text="Last Build:"/>
                    <Run Text="{x:Bind ViewModel.LastBuildDuration, Mode=OneWay}"/>
                </TextBlock>
                <TextBlock>
                    <Run Text="Errors:"/>
                    <Run Text="{x:Bind ViewModel.ErrorCount, Mode=OneWay}"
                         Foreground="{ThemeResource SystemErrorTextColor}"/>
                </TextBlock>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
```

---

## 5. Page Specifications

### ProjectsPage

**Purpose:** List and manage local workspaces

Key elements:

- Header with title + CommandBar (New Project, Refresh, Delete)
- ListView with project cards showing: icon, name, path, last modified date, health badge

### EditorPage

**Purpose:** Prompt input and generation control

Key elements:

- Multi-line prompt TextBox with placeholder text
- Generation mode ComboBox + Max retries NumberBox
- Generate (accent) and Cancel buttons
- Active tasks ListView with progress rings
- InfoBar progress indicator during generation

### BuildMonitorPanel

**Purpose:** Real-time orchestrator state visualization (Developer Mode)

Key elements:

- Orchestrator state icon + description
- Current task name + progress bar + retry counter
- Scrollable build log (Consolas font, selectable text)

### CodePreviewPage

**Purpose:** Read-only code viewer with syntax highlighting

Key elements:

- TreeView file explorer (left, 250px)
- GridSplitter
- Code display with file path header (Consolas, 14px)

### SettingsPage

**Purpose:** Application configuration

Key sections (Expander-based):

- AI Configuration (API key, model selection)
- Build Configuration (retry budget, timeout)
- Workspace path
- SDK validation status
- Developer Options (toggle for Developer Mode)

---

## 6. Micro-Interactions & Motion Design

### Generate Button Behavior

| State        | Visual                                                        |
| ------------ | ------------------------------------------------------------- |
| **Idle**     | 160×48px, accent color, enabled                               |
| **Hover**    | +4% brightness, elevation shadow, translate Y: -2px           |
| **Click**    | Shrink to 96% scale (80ms)                                    |
| **Building** | Disabled, text "Building…", indeterminate progress bar inside |

### Status Indicator Pulse

**Building State** (1.5s cycle):

- Scale: 1.0 → 1.15 → 1.0
- Color: Blue (`#0078D4`)
- Cubic bezier easing

**Success Flash** (300ms):

- Quick green flash → fade back to idle gray (200ms)

### Page Transitions

- **Fade out** current page: 120ms, opacity → 0
- **Slide in** new page from right: 160ms, +100px → 0px, cubic ease-out
- **Fade in** simultaneously: 160ms, opacity 0 → 1

### Silent Retry Feedback

```csharp
private void ShowSubtleRetryHint(int retryCount)
{
    if (retryCount <= 3)
    {
        // Silent - no UI change, only internal log
        return;
    }

    if (retryCount == 4)
    {
        // Slight opacity shimmer (400ms) + subtext: "Optimizing build…"
        BuildStatusSubtext.Text = "Optimizing build…";
        BuildStatusSubtext.Visibility = Visibility.Visible;
    }
}
```

---

## 7. Visual State Machine

### Core Principle

> **UI state ≠ Orchestrator state**
>
> The UI abstracts complexity by mapping many backend states into few calm visual states.

**Backend Reality**: 15+ orchestrator states
**User Experience**: 7 simple states

### The 7 User-Visible States

#### 🔷 FIRST_LAUNCH

- **Trigger**: App installed, no projects exist
- **UI**: Centered prompt with suggestion chips ("CRM", "Inventory", "Task Manager")
- **Psychology**: "You can just describe your idea" — removes setup anxiety
- **→** `EMPTY_IDLE` (after first project created)

#### 🔷 EMPTY_IDLE

- **Trigger**: Project exists, Orchestrator `IDLE`
- **UI**: Prompt box centered and active, Generate button enabled, status dot gray
- **→** `TYPING` (prompt focused) or `BUILDING` (Generate clicked)

#### 🔷 TYPING

- **Trigger**: Prompt field focused or text changed
- **UI**: Generate button full opacity, helper hints fade out, suggestion chips dim
- **→** `BUILDING` (Generate clicked) or `EMPTY_IDLE` (input cleared)

#### 🔷 BUILDING

- **Trigger**: Orchestrator enters execution (maps from `SPEC_PARSED`, `TASK_GRAPH_READY`, `TASK_EXECUTING`, `VALIDATING`, `RETRYING` attempts 1-3)
- **UI**: "Building…" text, blue pulsing dot, soft shimmer, previous preview blurred
- **Hidden**: Task names, retry counter, file operations, state transitions
- **Critical**: Remain in `BUILDING` during retries 1-3 (silent recovery)
- **→** `PREVIEW_READY` (success) or `SOFT_RECOVERY` (retry 4+) or `HARD_FAILURE` (budget exhausted)

#### 🔷 PREVIEW_READY

- **Trigger**: Orchestrator `COMPLETED`
- **UI**: Green flash (300ms), preview rendered, action buttons appear (Improve, Export, View Code, Add Feature)
- **→** `BUILDING` (new prompt)

#### 🔷 SOFT_RECOVERY

- **Trigger**: Retries ongoing (attempts 4+)
- **UI**: Banner "Optimizing build…" (blue, not red), Cancel button
- **Hidden**: Error details, retry count, technical diagnostics
- **→** `PREVIEW_READY` (retry succeeded) or `HARD_FAILURE` (exhausted) or `EMPTY_IDLE` (cancelled)

#### 🔷 HARD_FAILURE

- **Trigger**: Retry budget exhausted, Orchestrator `FAILED`
- **UI**: Neutral gray card with small warning icon, gentle language ("We couldn't complete this build"), Retry + Modify Prompt buttons, technical details collapsed
- **→** `BUILDING` (Retry) or `TYPING` (Modify Prompt)

#### 🔷 INTERVENTION_REQUIRED

- **Trigger**: Safety Guard blocks mutation
- **UI**: Warning InfoBar explaining dependency impact, Force Apply / Discard buttons
- **→** `BUILDING` (Force Apply) or `EMPTY_IDLE` (Discard)

### State Mapping

```csharp
private UIState MapToUIState(OrchestratorState orchestratorState, int retryCount)
{
    return orchestratorState switch
    {
        OrchestratorState.IDLE => UIState.EMPTY_IDLE,
        OrchestratorState.SPEC_PARSED => UIState.BUILDING,
        OrchestratorState.TASK_GRAPH_READY => UIState.BUILDING,
        OrchestratorState.TASK_EXECUTING => UIState.BUILDING,
        OrchestratorState.VALIDATING => UIState.BUILDING,
        OrchestratorState.RETRYING when retryCount <= 3 => UIState.BUILDING,
        OrchestratorState.RETRYING when retryCount > 3 => UIState.SOFT_RECOVERY,
        OrchestratorState.COMPLETED => UIState.PREVIEW_READY,
        OrchestratorState.FAILED => UIState.HARD_FAILURE,
        _ => UIState.EMPTY_IDLE
    };
}
```

### State Transition Diagram

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
│  BUILDING   │ (Orchestrator executing)
└──────┬──────┘
       │
       ├─────────────┬──────────────┐
       │ Success     │ Retry 4+     │ Retry exhausted
       ↓             ↓              ↓
┌──────────────┐ ┌────────────┐ ┌──────────────┐
│PREVIEW_READY │ │SOFT_RECOVERY│ │HARD_FAILURE  │
└──────────────┘ └────────────┘ └──────────────┘
       │             │              │
       └─────────────┴──> Back to BUILDING (new prompt)
```

---

## 8. Error Feedback UX

### Three-Tier Failure System

#### Tier 1: Silent Auto-Recovery (Retries 1-3)

- ✅ No error message shown
- ✅ Spinner continues smoothly
- ✅ No UI change whatsoever
- Exponential backoff: 1s, 2s, 4s

#### Tier 2: Recoverable Failure (Retries 4+)

- Blue warning InfoBar: "Build Issue Detected"
- Message: "We encountered an issue while building your app. Retrying with adjustments…"
- Retry button available
- Logs tab becomes visible (collapsed by default)
- Alternative build strategies attempted (clean build, restore, fallback config)

#### Tier 3: Hard Failure (Budget Exhausted)

- ContentDialog with warning icon
- Title: "Build Could Not Complete"
- User-friendly error message (translated from technical error)
- Buttons: Retry, Modify Prompt, Cancel
- Technical details in collapsed Expander

### Error Message Translation

| Technical Error                | User-Friendly Message                                                                                        |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `CS0246`: namespace not found  | "We couldn't find a required component. The system will attempt to add the missing reference automatically." |
| `CS1061`: member doesn't exist | "There's a mismatch in the code structure. Attempting to fix automatically."                                 |
| `CS0103`: name doesn't exist   | "A variable name wasn't recognized. Retrying with corrections."                                              |
| `MSB3073`: command exited      | "The build process encountered an issue. Retrying with different settings."                                  |

### Anti-Terror UX Rules

**Never show**:

- Raw MSBuild console output
- Stack traces by default
- Full file paths
- Red error overlays blocking entire UI
- Frozen UI during builds
- Compiler error codes without translation

**Always provide**:

- Animated feedback during operations
- Cancel button for long operations
- Retry option on failures
- State recovery via snapshots
- User-friendly error messages

---

## 9. Progressive Disclosure

### Default View (Simple Mode)

**Always Visible**: Prompt input, Generate button, Preview tabs, Export button, minimal status bar

**Hidden by Default**: Build Monitor panel, task graph visualization, raw build logs, retry attempt details, snapshot history, advanced build settings

### Developer Mode Toggle

Enabled via Settings → Developer Options. Reveals:

- Build Monitor in navigation
- Detailed status bar info
- Error codes and stack traces
- File paths in error messages
- Logs tab

**Progressive Mastery**: After 3+ projects, subtly unlock History tab and Diff view with a one-time teaching tip.

---

## 10. Onboarding & First Launch

### Empty State

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
│   Describe your app in plain      │
│   English.                         │
│                                    │
└────────────────────────────────────┘
```

**Psychological Goals**: Power ("I can build anything"), Simplicity ("Just describe it"), Safety ("No setup required")

### What NOT to do

- ❌ Multi-step onboarding wizard
- ❌ SDK configuration screens
- ❌ Feature tour
- ❌ "Getting Started" guide

### First Successful Build Celebration

Small animated TeachingTip: "Your app is ready!" + subtle scale animation on preview panel (1.0 → 1.05 → 1.0, 200ms each).

### Failure Psychology

**❌ Never Use**: "Build failed", "Unhandled exception", red backgrounds, blame language

**✅ Always Use**: "We couldn't complete this request", neutral gray card, small warning icon, gentle language, clear next steps

---

## 11. Theme System & Accessibility

### Light/Dark Mode

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

### Accessibility Requirements

- All interactive elements must have `AutomationProperties.Name`
- Keyboard navigation for all features
- High contrast mode support
- Screen reader compatibility
- Minimum touch target size: 44×44px

### Performance

- `ListView` virtualization for large lists
- Incremental loading for file trees
- Lazy-load code preview content
- All operations async with progress indication

---

## 12. UI → Orchestrator Contract

### Command Pattern

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
            GenerationMode = this.SelectedMode,
            MaxRetries = this.MaxRetries
        };

        await _orchestrator.SubmitCommandAsync(command);
    }
}
```

### Event Subscription

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
}
```

### Strict Boundaries

**UI Never**: Calls kernel services, modifies workspace files, handles retry logic, executes build commands, manages state transitions

**UI Always**: Sends commands to Orchestrator, subscribes to events, updates on dispatcher thread, validates input before sending, shows loading states

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 7-layer overview, deployment model
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine, build system, retry logic
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn integration, patch engine
- [PREVIEW_SYSTEM.md](./PREVIEW_SYSTEM.md) — Preview rendering
