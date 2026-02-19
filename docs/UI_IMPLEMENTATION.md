# UI IMPLEMENTATION

> **The Presentation Layer: Design Philosophy, WinUI 3 Components, Visual State Machine & Error Feedback**
>

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
>
> **The Factory Metaphor**: The UI is the control room of an autonomous factory. The user sets the parameters (prompts), and the factory (Orchestrator + Agents) handles the dangerous machinery (compilers, file I/O) behind safety glass. The user sees the product, not the assembly line.

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

### Spacing Scale (8px System)

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

### Typography Scale

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

### Color Palette — Status Indicators

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

### Material System

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

                <!-- Settings Button -->
                <Button Content="&#xE713;"
                        FontFamily="Segoe MDL2 Assets"
                        Style="{StaticResource TransparentButtonStyle}"
                        HorizontalAlignment="Right"
                        Click="OnSettingsClick"/>
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

### ProjectsPage.xaml

**Purpose:** List and manage local workspaces

```xaml
<Page x:Class="SyncAIAppBuilder.UI.Pages.ProjectsPage">
    <Grid Padding="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Spacing="16">
            <TextBlock Text="Projects"
                       Style="{StaticResource TitleTextBlockStyle}"/>

            <CommandBar DefaultLabelPosition="Right">
                <AppBarButton Icon="Add"
                              Label="New Project"
                              Click="{x:Bind ViewModel.CreateProject}"/>
                <AppBarButton Icon="Refresh"
                              Label="Refresh"
                              Click="{x:Bind ViewModel.RefreshProjects}"/>
                <AppBarButton Icon="Delete"
                              Label="Delete"
                              Click="{x:Bind ViewModel.DeleteProject}"
                              IsEnabled="{x:Bind ViewModel.HasSelection, Mode=OneWay}"/>
            </CommandBar>
        </StackPanel>

        <!-- Project List -->
        <ListView Grid.Row="1"
                  ItemsSource="{x:Bind ViewModel.Projects, Mode=OneWay}"
                  SelectedItem="{x:Bind ViewModel.SelectedProject, Mode=TwoWay}"
                  SelectionMode="Single">
            <ListView.ItemTemplate>
                <DataTemplate x:DataType="models:Project">
                    <Grid Padding="12" ColumnSpacing="12">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="48"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <!-- Project Icon -->
                        <FontIcon Grid.Column="0"
                                  Glyph="&#xE8F1;"
                                  FontSize="32"/>

                        <!-- Project Info -->
                        <StackPanel Grid.Column="1" Spacing="4">
                            <TextBlock Text="{x:Bind Name}"
                                       FontWeight="SemiBold"
                                       FontSize="16"/>
                            <TextBlock Text="{x:Bind Path}"
                                       Foreground="{ThemeResource TextFillColorSecondaryBrush}"
                                       FontSize="12"/>
                            <TextBlock Text="{x:Bind LastModified, Converter={StaticResource DateTimeConverter}}"
                                       Foreground="{ThemeResource TextFillColorTertiaryBrush}"
                                       FontSize="11"/>
                        </StackPanel>

                        <!-- Health Status -->
                        <InfoBadge Grid.Column="2"
                                   Value="{x:Bind HealthStatus}"
                                   Severity="{x:Bind HealthSeverity}"/>
                    </Grid>
                </DataTemplate>
            </ListView.ItemTemplate>
        </ListView>
    </Grid>
</Page>
```

### EditorPage.xaml

**Purpose:** Prompt input and generation control

```xaml
<Page x:Class="SyncAIAppBuilder.UI.Pages.EditorPage">
    <Grid Padding="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Prompt Editor -->
        <StackPanel Grid.Row="0" Spacing="12">
            <TextBlock Text="Describe your application"
                       Style="{StaticResource SubtitleTextBlockStyle}"/>

            <TextBox x:Name="PromptInput"
                     Text="{x:Bind ViewModel.Prompt, Mode=TwoWay}"
                     PlaceholderText="E.g., Build a todo app with SQLite database and dark mode support..."
                     AcceptsReturn="True"
                     TextWrapping="Wrap"
                     MinHeight="120"
                     MaxHeight="300"/>

            <!-- Generation Options -->
            <StackPanel Orientation="Horizontal" Spacing="12">
                <ComboBox Header="Generation Mode"
                          ItemsSource="{x:Bind ViewModel.GenerationModes}"
                          SelectedItem="{x:Bind ViewModel.SelectedMode, Mode=TwoWay}"
                          Width="200"/>
            </StackPanel>

            <!-- Action Buttons -->
            <StackPanel Orientation="Horizontal" Spacing="8">
                <Button Content="Generate Application"
                        Style="{StaticResource AccentButtonStyle}"
                        Click="{x:Bind ViewModel.GenerateApp}"
                        IsEnabled="{x:Bind ViewModel.CanGenerate, Mode=OneWay}">
                    <Button.Icon>
                        <FontIcon Glyph="&#xE768;"/>
                    </Button.Icon>
                </Button>

                <Button Content="Cancel"
                        Click="{x:Bind ViewModel.CancelGeneration}"
                        IsEnabled="{x:Bind ViewModel.IsGenerating, Mode=OneWay}">
                    <Button.Icon>
                        <FontIcon Glyph="&#xE711;"/>
                    </Button.Icon>
                </Button>
            </StackPanel>
        </StackPanel>

        <!-- Task List -->
        <Grid Grid.Row="1" Margin="0,24,0,0">
            <ListView ItemsSource="{x:Bind ViewModel.ActiveTasks, Mode=OneWay}"
                      Header="Active Tasks">
                <ListView.ItemTemplate>
                    <DataTemplate x:DataType="models:TaskItem">
                        <Grid Padding="12" ColumnSpacing="12">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <ProgressRing Grid.Column="0"
                                          IsActive="{x:Bind IsRunning}"
                                          Width="24" Height="24"/>

                            <StackPanel Grid.Column="1" Spacing="4">
                                <TextBlock Text="{x:Bind Description}"
                                           FontWeight="SemiBold"/>
                                <TextBlock Text="{x:Bind Status}"
                                           Foreground="{ThemeResource TextFillColorSecondaryBrush}"
                                           FontSize="12"/>
                            </StackPanel>

                            <TextBlock Grid.Column="2"
                                       Text="{x:Bind RetryCount, Converter={StaticResource RetryCountConverter}}"
                                       Foreground="{ThemeResource SystemErrorTextColor}"
                                       Visibility="{x:Bind HasRetries}"/>
                        </Grid>
                    </DataTemplate>
                </ListView.ItemTemplate>
            </ListView>
        </Grid>

        <!-- Progress Indicator -->
        <InfoBar Grid.Row="2"
                 IsOpen="{x:Bind ViewModel.IsGenerating, Mode=OneWay}"
                 Severity="Informational"
                 Title="Generating Application"
                 Message="{x:Bind ViewModel.CurrentTaskDescription, Mode=OneWay}">
            <InfoBar.Content>
                <ProgressBar IsIndeterminate="True"/>
            </InfoBar.Content>
        </InfoBar>
    </Grid>
</Page>
```

### BuildMonitorPanel.xaml

**Purpose:** Real-time orchestrator state visualization (Developer Mode)

```xaml
<UserControl x:Class="SyncAIAppBuilder.UI.Components.BuildMonitorPanel">
    <Grid Padding="16" RowSpacing="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- Orchestrator State -->
        <StackPanel Grid.Row="0" Spacing="8">
            <TextBlock Text="Orchestrator State"
                       Style="{StaticResource SubtitleTextBlockStyle}"/>

            <Grid ColumnSpacing="12">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <FontIcon Grid.Column="0"
                          Glyph="{x:Bind ViewModel.StateIcon, Mode=OneWay}"
                          Foreground="{x:Bind ViewModel.StateColor, Mode=OneWay}"
                          FontSize="32"/>

                <StackPanel Grid.Column="1" Spacing="4">
                    <TextBlock Text="{x:Bind ViewModel.CurrentState, Mode=OneWay}"
                               FontSize="20"
                               FontWeight="SemiBold"/>
                    <TextBlock Text="{x:Bind ViewModel.StateDescription, Mode=OneWay}"
                               Foreground="{ThemeResource TextFillColorSecondaryBrush}"/>
                </StackPanel>
            </Grid>
        </StackPanel>

        <!-- Current Task Info -->
        <StackPanel Grid.Row="1" Spacing="8">
            <TextBlock Text="Current Task"
                       Style="{StaticResource BodyStrongTextBlockStyle}"/>

            <Grid ColumnSpacing="16">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Spacing="4">
                    <TextBlock Text="{x:Bind ViewModel.CurrentTaskName, Mode=OneWay}"/>
                    <ProgressBar Value="{x:Bind ViewModel.TaskProgress, Mode=OneWay}"
                                 Maximum="100"/>
                </StackPanel>

                <StackPanel Grid.Column="1" Spacing="4">
                    <TextBlock Text="Retry Count"
                               Foreground="{ThemeResource TextFillColorSecondaryBrush}"
                               FontSize="12"/>
                    <TextBlock Text="{x:Bind ViewModel.RetryCount, Mode=OneWay}"
                               FontSize="24"
                               FontWeight="Bold"
                               Foreground="{x:Bind ViewModel.RetryCountColor, Mode=OneWay}"
                               HorizontalAlignment="Center"/>
                </StackPanel>
            </Grid>
        </StackPanel>

        <!-- Build Log -->
        <ScrollViewer Grid.Row="2">
            <RichTextBlock x:Name="BuildLog"
                           FontFamily="Consolas"
                           FontSize="12"
                           IsTextSelectionEnabled="True"/>
        </ScrollViewer>
    </Grid>
</UserControl>
```

### CodePreviewPage.xaml

**Purpose:** Read-only code viewer with syntax highlighting

```xaml
<Page x:Class="SyncAIAppBuilder.UI.Pages.CodePreviewPage">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="250"/>
            <ColumnDefinition Width="4"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- File Tree -->
        <TreeView Grid.Column="0"
                  ItemsSource="{x:Bind ViewModel.FileTree, Mode=OneWay}"
                  SelectionChanged="OnFileSelected">
            <TreeView.ItemTemplate>
                <DataTemplate x:DataType="models:FileNode">
                    <TreeViewItem ItemsSource="{x:Bind Children}">
                        <StackPanel Orientation="Horizontal" Spacing="8">
                            <FontIcon Glyph="{x:Bind Icon}"/>
                            <TextBlock Text="{x:Bind Name}"/>
                        </StackPanel>
                    </TreeViewItem>
                </DataTemplate>
            </TreeView.ItemTemplate>
        </TreeView>

        <GridSplitter Grid.Column="1"/>

        <!-- Code Viewer -->
        <Grid Grid.Column="2">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- File Header -->
            <Grid Grid.Row="0"
                  Background="{ThemeResource LayerFillColorDefaultBrush}"
                  Padding="16,8">
                <TextBlock Text="{x:Bind ViewModel.CurrentFilePath, Mode=OneWay}"
                           FontFamily="Consolas"/>
            </Grid>

            <!-- Code Display -->
            <ScrollViewer Grid.Row="1">
                <RichTextBlock x:Name="CodeDisplay"
                               FontFamily="Consolas"
                               FontSize="14"
                               Padding="16"
                               IsTextSelectionEnabled="True"/>
            </ScrollViewer>
        </Grid>
    </Grid>
</Page>
```

### SettingsPage.xaml

**Purpose:** Application configuration

```xaml
<Page x:Class="SyncAIAppBuilder.UI.Pages.SettingsPage">
    <ScrollViewer>
        <StackPanel Padding="24" Spacing="24" MaxWidth="800">

            <!-- AI Configuration -->
            <Expander Header="AI Configuration" IsExpanded="True">
                <StackPanel Spacing="12" Padding="12">
                    <PasswordBox Header="API Key"
                                 Password="{x:Bind ViewModel.ApiKey, Mode=TwoWay}"
                                 PlaceholderText="Enter your AI API key"/>

                    <ComboBox Header="Model"
                              ItemsSource="{x:Bind ViewModel.AvailableModels}"
                              SelectedItem="{x:Bind ViewModel.SelectedModel, Mode=TwoWay}"
                              Width="300"/>
                </StackPanel>
            </Expander>

            <!-- Build Configuration -->
            <Expander Header="Build Configuration">
                <StackPanel Spacing="12" Padding="12">
                    <InfoBar Severity="Informational"
                             IsOpen="True"
                             Message="Build settings are managed automatically. The system retries continuously until success."/>
                </StackPanel>
            </Expander>

            <!-- Workspace Configuration -->
            <Expander Header="Workspace">
                <StackPanel Spacing="12" Padding="12">
                    <TextBox Header="Workspace Path"
                             Text="{x:Bind ViewModel.WorkspacePath, Mode=TwoWay}"
                             IsReadOnly="True"/>

                    <Button Content="Change Location"
                            Click="{x:Bind ViewModel.ChangeWorkspacePath}"/>
                </StackPanel>
            </Expander>

            <!-- SDK Validation -->
            <Expander Header="SDK Status">
                <StackPanel Spacing="12" Padding="12">
                    <Grid ColumnSpacing="12">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <TextBlock Grid.Column="0"
                                   Text="{x:Bind ViewModel.SdkVersion, Mode=OneWay}"/>

                        <FontIcon Grid.Column="1"
                                  Glyph="&#xE73E;"
                                  Foreground="Green"
                                  Visibility="{x:Bind ViewModel.IsSdkValid, Mode=OneWay}"/>
                    </Grid>

                    <Button Content="Validate SDK"
                            Click="{x:Bind ViewModel.ValidateSdk}"/>
                </StackPanel>
            </Expander>

            <!-- Developer Options -->
            <Expander Header="Developer Options">
                <StackPanel Spacing="12" Padding="12">
                    <ToggleSwitch x:Name="DeveloperModeToggle"
                                  Header="Developer Mode"
                                  IsOn="{x:Bind ViewModel.DeveloperModeEnabled, Mode=TwoWay}"
                                  OnContent="Enabled"
                                  OffContent="Disabled"/>

                    <InfoBar Severity="Informational"
                             IsOpen="True"
                             Message="Developer Mode is recommended only for debugging. Most users should keep this disabled for a cleaner experience."/>
                </StackPanel>
            </Expander>

            <!-- Save Button -->
            <Button Content="Save Settings"
                    Style="{StaticResource AccentButtonStyle}"
                    Click="{x:Bind ViewModel.SaveSettings}"
                    HorizontalAlignment="Right"/>
        </StackPanel>
    </ScrollViewer>
</Page>
```

---

## 6. Micro-Interactions & Motion Design

### Generate Button Behavior

| State        | Visual                                                        |
| ------------ | ------------------------------------------------------------- |
| **Idle**     | 160×48px, accent color, enabled                               |
| **Hover**    | +4% brightness, elevation shadow, translate Y: -2px           |
| **Click**    | Shrink to 96% scale (80ms)                                    |
| **Building** | Disabled, text "Building…", indeterminate progress bar inside |

**Idle XAML**:

```xaml
<Button x:Name="GenerateButton"
        Content="Generate Application"
        Width="160"
        Height="48"
        CornerRadius="8"
        Style="{StaticResource AccentButtonStyle}"/>
```

**Hover State**:

```csharp
private void OnGenerateButtonPointerEntered(object sender, PointerRoutedEventArgs e)
{
    // Increase brightness by 4%
    var compositor = ElementCompositionPreview.GetElementVisual(GenerateButton).Compositor;
    var brightnessEffect = new BrightnessEffect
    {
        Source = new CompositionEffectSourceParameter("source"),
        BlackPoint = new Vector2(0.0f),
        WhitePoint = new Vector2(1.04f) // +4% brightness
    };

    // Increase elevation shadow
    GenerateButton.Translation = new Vector3(0, -2, 8);
}
```

**Click Animation** (80ms shrink):

```csharp
private async void OnGenerateClick(object sender, RoutedEventArgs e)
{
    // Shrink to 96% scale for 80ms
    var scaleAnimation = GenerateButton.Compositor.CreateVector3KeyFrameAnimation();
    scaleAnimation.InsertKeyFrame(0.0f, new Vector3(1.0f, 1.0f, 1.0f));
    scaleAnimation.InsertKeyFrame(1.0f, new Vector3(0.96f, 0.96f, 1.0f));
    scaleAnimation.Duration = TimeSpan.FromMilliseconds(80);

    GenerateButton.StartAnimation("Scale", scaleAnimation);
    await Task.Delay(80);

    // Transition to building state
    TransitionToBuildingState();
}
```

**Building State**:

```csharp
private void TransitionToBuildingState()
{
    GenerateButton.Content = "Building…";
    GenerateButton.IsEnabled = false;

    // Show progress bar inside button
    var progressBar = new ProgressBar
    {
        IsIndeterminate = true,
        Height = 4,
        VerticalAlignment = VerticalAlignment.Bottom
    };

    // Add to button's visual tree
    var grid = GenerateButton.Content as Grid;
    grid?.Children.Add(progressBar);
}
```

### Status Indicator Pulse

**Status Dot** (12px circle in status bar):

```xaml
<Ellipse x:Name="StatusDot"
         Width="12"
         Height="12"
         Fill="{StaticResource StatusIdleBrush}"/>
```

**Building State Pulse** (1.5s cycle):

```csharp
private void StartStatusPulse()
{
    var compositor = ElementCompositionPreview.GetElementVisual(StatusDot).Compositor;

    // Scale animation: 1.0 → 1.15 → 1.0
    var scaleAnimation = compositor.CreateVector3KeyFrameAnimation();
    scaleAnimation.InsertKeyFrame(0.0f, new Vector3(1.0f, 1.0f, 1.0f));
    scaleAnimation.InsertKeyFrame(0.5f, new Vector3(1.15f, 1.15f, 1.0f));
    scaleAnimation.InsertKeyFrame(1.0f, new Vector3(1.0f, 1.0f, 1.0f));
    scaleAnimation.Duration = TimeSpan.FromSeconds(1.5);
    scaleAnimation.IterationBehavior = AnimationIterationBehavior.Forever;

    // Apply cubic easing
    var easing = compositor.CreateCubicBezierEasingFunction(
        new Vector2(0.42f, 0.0f),
        new Vector2(0.58f, 1.0f)
    );
    scaleAnimation.InsertExpressionKeyFrame(0.5f, "this.FinalValue", easing);

    StatusDot.StartAnimation("Scale", scaleAnimation);

    // Change color to blue
    StatusDot.Fill = (SolidColorBrush)Resources["StatusBuildingBrush"];
}
```

**Success Flash** (300ms):

```csharp
private async void ShowSuccessFlash()
{
    // Quick green flash
    StatusDot.Fill = (SolidColorBrush)Resources["StatusSuccessBrush"];

    await Task.Delay(300);

    // Fade back to idle gray over 200ms
    var fadeAnimation = StatusDot.Compositor.CreateColorKeyFrameAnimation();
    fadeAnimation.InsertKeyFrame(1.0f, Color.FromArgb(255, 107, 107, 107)); // #6B6B6B
    fadeAnimation.Duration = TimeSpan.FromMilliseconds(200);

    StatusDot.StartAnimation("Fill.Color", fadeAnimation);
}
```

### Page Transitions

**Smooth Fade + Slide** (120ms fade out, 160ms slide in):

```csharp
private async Task TransitionToPage(Page newPage, Page currentPage)
{
    var compositor = ElementCompositionPreview.GetElementVisual(currentPage).Compositor;

    // Step 1: Fade out current page (120ms)
    var fadeOut = compositor.CreateScalarKeyFrameAnimation();
    fadeOut.InsertKeyFrame(1.0f, 0.0f);
    fadeOut.Duration = TimeSpan.FromMilliseconds(120);

    currentPage.StartAnimation("Opacity", fadeOut);
    await Task.Delay(120);

    // Step 2: Swap pages
    ContentFrame.Content = newPage;

    // Step 3: Slide in new page from right (160ms)
    var slideIn = compositor.CreateVector3KeyFrameAnimation();
    slideIn.InsertKeyFrame(0.0f, new Vector3(100, 0, 0)); // Start 100px to the right
    slideIn.InsertKeyFrame(1.0f, new Vector3(0, 0, 0));
    slideIn.Duration = TimeSpan.FromMilliseconds(160);

    // Cubic ease out
    var easing = compositor.CreateCubicBezierEasingFunction(
        new Vector2(0.0f, 0.0f),
        new Vector2(0.2f, 1.0f)
    );
    slideIn.InsertExpressionKeyFrame(1.0f, "this.FinalValue", easing);

    newPage.StartAnimation("Translation", slideIn);

    // Fade in simultaneously
    var fadeIn = compositor.CreateScalarKeyFrameAnimation();
    fadeIn.InsertKeyFrame(0.0f, 0.0f);
    fadeIn.InsertKeyFrame(1.0f, 1.0f);
    fadeIn.Duration = TimeSpan.FromMilliseconds(160);

    newPage.StartAnimation("Opacity", fadeIn);
}
```

### Silent Retry Feedback

```csharp
private void ShowSubtleRetryHint(int retryCount)
{
    if (retryCount <= 3)
    {
        // Silent - no UI change, only internal log
        _logger.LogDebug("Retry attempt {Attempt} in progress", retryCount);
        return;
    }

    if (retryCount == 4)
    {
        // Slight opacity shimmer (400ms)
        var shimmer = BuildStatusText.Compositor.CreateScalarKeyFrameAnimation();
        shimmer.InsertKeyFrame(0.0f, 1.0f);
        shimmer.InsertKeyFrame(0.5f, 0.85f);
        shimmer.InsertKeyFrame(1.0f, 1.0f);
        shimmer.Duration = TimeSpan.FromMilliseconds(400);

        BuildStatusText.StartAnimation("Opacity", shimmer);

        // Update subtext
        BuildStatusSubtext.Text = "Optimizing build…";
        BuildStatusSubtext.Visibility = Visibility.Visible;
    }
}
```

### Snapshot Restore (Invisible)

```csharp
private async Task RollbackToSnapshot(string snapshotId)
{
    // No UI flicker - seamless transition
    await _snapshotService.RestoreAsync(snapshotId);

    // Only visible if user is in Logs tab (Developer Mode)
    if (DeveloperModeEnabled && CurrentTab == "Logs")
    {
        LogsPanel.AppendLine($"[INFO] Restored to stable state: {snapshotId}");

        // Show diff indicator
        DiffIndicator.Visibility = Visibility.Visible;
        DiffIndicator.Text = "Reverted to last stable state";
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
**User Experience**: 8 simple states

### The 6 User-Visible States

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

- **Trigger**: Orchestrator enters execution (maps from `SPEC_PARSED`, `TASK_GRAPH_READY`, `MUTATION_GUARD`, `PATCHING`, `INDEXING`, `TASK_EXECUTING`, `VALIDATING`, `RETRYING` attempts 1-3)
- **UI**: "Building…" text, blue pulsing dot, soft shimmer, previous preview blurred
- **Hidden**: Task names, retry counter, file operations, state transitions
- **Critical**: Remain in `BUILDING` during retries 1-3 (silent recovery)
- **→** `PREVIEW_READY` (success) or `SOFT_RECOVERY` (retry 4+) or `HARD_FAILURE` (budget exhausted)

#### 🔷 PREVIEW_READY

- **Trigger**: Orchestrator `COMPLETED`
- **UI**: Green flash (300ms), preview rendered, action buttons appear (Improve, Export, View Code, Add Feature)
- **→** `BUILDING` (new prompt)

#### 🔷 SOFT_RECOVERY

- **Trigger**: Retries ongoing (extended duration)
- **UI**: Banner "Optimizing build…" (blue, not red), Cancel button
- **Hidden**: Error details, retry count, technical diagnostics
- **Critical**: System continues retrying until success or user cancellation
- **→** `PREVIEW_READY` (retry succeeded) or `EMPTY_IDLE` (user cancelled)

#### 🔷 INTERVENTION_REQUIRED

- **Trigger**: Safety Guard blocks mutation
- **UI**: Warning InfoBar explaining dependency impact, Force Apply / Discard buttons
- **→** `BUILDING` (Force Apply) or `EMPTY_IDLE` (Discard)

> **Note**: There is no HARD_FAILURE or FATAL_ENVIRONMENT_ERROR state. The system retries continuously until success or user cancellation. Environment issues are handled through user guidance dialogs that don't block the state machine.

### Orchestrator → UI State Mapping Table

| UI State                | Orchestrator States (Backend)                                                                                                          |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `FIRST_LAUNCH`          | N/A (no orchestrator instance)                                                                                                         |
| `EMPTY_IDLE`            | `IDLE`                                                                                                                                 |
| `TYPING`                | `IDLE` (no backend change)                                                                                                             |
| `BUILDING`              | `SPEC_PARSED`, `TASK_GRAPH_READY`, `MUTATION_GUARD`, `PATCHING`, `INDEXING`, `TASK_EXECUTING`, `VALIDATING`, `RETRYING` (initial)     |
| `PREVIEW_READY`         | `COMPLETED`                                                                                                                            |
| `SOFT_RECOVERY`         | `RETRYING` (extended duration, user informed)                                                                                          |
| `INTERVENTION_REQUIRED` | `GUARD_REJECTED`                                                                                                                       |

> **Note**: There is no `FAILED` or `ENVIRONMENT_INVALID` orchestrator state. The system retries continuously until success or user cancellation.

### State Mapping

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

> **Note**: The system never enters a terminal failure state. All errors trigger continuous retry until success or user cancellation.
```

### ViewModel Implementation

```csharp
public class MainViewModel : ObservableObject
{
    private UIState _currentState = UIState.FIRST_LAUNCH;
    private readonly IOrchestrator _orchestrator;
    private readonly IProjectService _projectService;
    private int _retryCount;

    public UIState CurrentState
    {
        get => _currentState;
        set
        {
            if (SetProperty(ref _currentState, value))
            {
                OnStateChanged(value);
            }
        }
    }

    private bool _developerModeEnabled;

    [ObservableProperty]
    public bool DeveloperModeEnabled
    {
        get => _developerModeEnabled;
        set
        {
            SetProperty(ref _developerModeEnabled, value);
            UpdateUIVisibility();
        }
    }

    public MainViewModel(IOrchestrator orchestrator, IProjectService projectService)
    {
        _orchestrator = orchestrator;
        _projectService = projectService;

        // Subscribe to orchestrator events
        _orchestrator.StateChanged += OnOrchestratorStateChanged;
        _orchestrator.RetryAttempt += OnRetryAttempt;

        // Initialize state
        CurrentState = DetermineInitialState();
    }

    private UIState DetermineInitialState()
    {
        var projectCount = _projectService.GetProjectCount();
        return projectCount == 0 ? UIState.FIRST_LAUNCH : UIState.EMPTY_IDLE;
    }

    private void OnOrchestratorStateChanged(object sender, StateChangedEvent e)
    {
        CurrentState = MapToUIState(e.NewState, _retryCount);
    }

    private void OnRetryAttempt(object sender, RetryEvent e)
    {
        _retryCount = e.AttemptNumber;

        // Update UI state based on retry count
        if (_retryCount > 3)
        {
            CurrentState = UIState.SOFT_RECOVERY;
        }
    }

    private void OnStateChanged(UIState newState)
    {
        // Update UI elements based on state
        UpdateGenerateButton(newState);
        UpdateStatusDot(newState);
        UpdatePreviewPanel(newState);
        TriggerStateAnimation(newState);
    }

    private void UpdateUIVisibility()
    {
        if (DeveloperModeEnabled)
        {
            // Show BuildMonitorPanel in navigation
            // Show detailed status bar info
            // Enable advanced settings
            UpdateNavigationItems();
        }
        else
        {
            // Hide advanced features
            UpdateNavigationItems();
        }
    }

    private void UpdateNavigationItems()
    {
        var navItems = new List<NavigationViewItem>
        {
            new() { Content = "Projects", Icon = new SymbolIcon(Symbol.Folder),  Tag = "projects" },
            new() { Content = "Editor",   Icon = new SymbolIcon(Symbol.Edit),    Tag = "editor"   },
            new() { Content = "Preview",  Icon = new SymbolIcon(Symbol.View),    Tag = "preview"  },
            new() { Content = "Settings", Icon = new SymbolIcon(Symbol.Setting), Tag = "settings" }
        };

        // Only show Build Monitor if Developer Mode enabled
        if (DeveloperModeEnabled)
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
                   (success)
```

> **Key Insight**: The system never stops retrying. SOFT_RECOVERY indicates extended retry duration with user awareness, not failure. The only exit paths are success (PREVIEW_READY) or user cancellation (EMPTY_IDLE).

---

## 8. Error Feedback UX

### Two-Tier Recovery System

#### Tier 1: Silent Auto-Recovery (Initial Retries)

- ✅ No error message shown
- ✅ Spinner continues smoothly
- ✅ No UI change whatsoever
- Exponential backoff applied
- System continues retrying automatically

#### Tier 2: Extended Recovery (User Informed)

- Blue warning InfoBar: "Optimizing Build…"
- Message: "We're refining the build. This may take a moment…"
- Cancel button available (user can stop at any time)
- Logs tab becomes visible (collapsed by default)
- Alternative build strategies attempted (clean build, restore, fallback config)
- System continues retrying until success or user cancellation

> **Note**: There is no "Tier 3: Hard Failure". The system never stops retrying on its own. The only terminal states are success or user-initiated cancellation.

### Error Message Translation

| Technical Error                | User-Friendly Message                                                                                        |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `CS0246`: namespace not found  | "We couldn't find a required component. The system will attempt to add the missing reference automatically." |
| `CS1061`: member doesn't exist | "There's a mismatch in the code structure. Attempting to fix automatically."                                 |
| `CS0103`: name doesn't exist   | "A variable name wasn't recognized. Retrying with corrections."                                              |
| `MSB3073`: command exited      | "The build process encountered an issue. Retrying with different settings."                                  |

### Recovery Implementation

**Tier 1 — `BuildWithSilentRetryAsync()`**:

```csharp
private async Task<BuildResult> BuildWithSilentRetryAsync(
    string projectPath,
    CancellationToken cancellationToken)
{
    var attempt = 0;
    var delay = TimeSpan.FromSeconds(1);

    while (!cancellationToken.IsCancellationRequested)
    {
        attempt++;
        var result = await _buildService.BuildAsync(projectPath, cancellationToken);

        if (result.Success)
        {
            _logger.LogInformation("Build succeeded on attempt {Attempt}", attempt);
            return result;
        }

        // Log internally, don't show to user
        _logger.LogWarning("Build attempt {Attempt} failed: {Error}", attempt, result.Error);

        // Check if we should transition to Tier 2 (extended recovery UI)
        if (attempt >= 3 && !_extendedRecoveryShown)
        {
            _extendedRecoveryShown = true;
            ShowExtendedRecoveryUI();
        }

        // Exponential backoff
        await Task.Delay(delay, cancellationToken);
        delay = TimeSpan.FromMilliseconds(delay.TotalMilliseconds * 1.5);
    }

    // User cancelled
    return BuildResult.Cancelled();
}
```

**Tier 2 — `ExtendedRecoveryBar` XAML + `ShowExtendedRecoveryUI()`**:

```xaml
<InfoBar x:Name="ExtendedRecoveryBar"
         Severity="Informational"
         IsOpen="False"
         Title="Optimizing Build…"
         Message="We're refining the build. This may take a moment…">
    <InfoBar.ActionButton>
        <Button Content="Cancel"
                Click="{x:Bind ViewModel.CancelBuild}"/>
    </InfoBar.ActionButton>
</InfoBar>
```

```csharp
private void ShowExtendedRecoveryUI()
{
    // Show informational (not warning) banner
    ExtendedRecoveryBar.IsOpen = true;

    // Make Logs tab available in Developer Mode (but don't auto-open)
    if (DeveloperModeEnabled)
    {
        LogsTab.Visibility = Visibility.Visible;
    }
}
```

**Cancellation Handling**:

```csharp
private async void OnCancelBuild()
{
    // User chose to stop the build
    _cancellationTokenSource.Cancel();

    // Hide the extended recovery UI
    ExtendedRecoveryBar.IsOpen = false;

    // Return to idle state
    CurrentState = UIState.EMPTY_IDLE;

    // Optional: Show brief confirmation
    ShowToast("Build cancelled. Your project is ready for your next prompt.");
}
```

> **Key Difference**: The system never shows a "failure" dialog. It continues retrying until it succeeds or the user explicitly cancels.

**Error Context for Logging** (Developer Mode only):

```csharp
public string GetErrorContext(BuildError error)
{
    // Only shown in Developer Mode logs
    return error.Code switch
    {
        "CS0246" => $"[{error.Code}] Namespace not found: {error.Message}",
        "CS1061" => $"[{error.Code}] Member not found: {error.Message}",
        "CS0103" => $"[{error.Code}] Name not found: {error.Message}",
        "CS0029" => $"[{error.Code}] Type mismatch: {error.Message}",
        "MSB3073" => $"[{error.Code}] Build task failed: {error.Message}",
        "MSB4018" => $"[{error.Code}] Build task error: {error.Message}",
        _        => $"[{error.Code}] {error.Message}"
    };
}
```

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

### `UpdateNavigationItems()` Implementation

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

    // Only show Build Monitor if Developer Mode enabled
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

```csharp
private async void CelebrateFirstSuccess()
{
    // Small animated toast
    var toast = new TeachingTip
    {
        Title = "Your app is ready!",
        Subtitle = "You can now preview, export, or improve it.",
        IsLightDismissEnabled = true
    };

    await toast.ShowAsync();

    // Subtle scale animation on preview
    await PreviewPanel.ScaleAsync(1.0, 1.05, duration: 200);
    await PreviewPanel.ScaleAsync(1.05, 1.0, duration: 200);
}
```

### Progressive Mastery Unlock

```csharp
private void UnlockAdvancedFeatures()
{
    if (_projectService.GetProjectCount() >= 3)
    {
        // Subtle unlock
        HistoryTab.Visibility = Visibility.Visible;
        DiffViewTooltip.IsEnabled = true;

        // Show one-time hint
        ShowTeachingTip("Advanced features unlocked! Check Settings for Developer Mode.");
    }
}
```

### Empty Project State XAML

If user opens a new project with no code yet:

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

### Theme Toggle

```csharp
public void ToggleTheme()
{
    var currentTheme = Application.Current.RequestedTheme;
    Application.Current.RequestedTheme =
        currentTheme == ApplicationTheme.Light
            ? ApplicationTheme.Dark
            : ApplicationTheme.Light;
}
```

### Accessibility Requirements

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

### Performance

- `ListView` virtualization for large lists
- Incremental loading for file trees
- Lazy-load code preview content
- All operations async with progress indication

**Async Pattern**:

```csharp
// ✅ Good: Async with progress
public async Task LoadProjectsAsync()
{
    IsLoading = true;
    try
    {
        var projects = await _projectService.GetProjectsAsync();
        Projects = new ObservableCollection<Project>(projects);
    }
    finally
    {
        IsLoading = false;
    }
}

// ❌ Bad: Blocking UI thread
public void LoadProjects()
{
    var projects = _projectService.GetProjects(); // Blocks!
    Projects = new ObservableCollection<Project>(projects);
}
```

### Unit Testing

```csharp
[TestClass]
public class EditorViewModelTests
{
    [TestMethod]
    public async Task GenerateApp_ValidPrompt_SendsCommand()
    {
        // Arrange
        var mockOrchestrator = new Mock<IOrchestrator>();
        var viewModel = new EditorViewModel(mockOrchestrator.Object);
        viewModel.Prompt = "Build a todo app";

        // Act
        await viewModel.GenerateApp();

        // Assert
        mockOrchestrator.Verify(
            o => o.SubmitCommandAsync(It.IsAny<GenerateProjectCommand>()),
            Times.Once);
    }
}
```

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
            GenerationMode = this.SelectedMode
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

### Strict Boundaries

**UI Never**: Calls kernel services, modifies workspace files, handles retry logic, executes build commands, manages state transitions

**UI Always**: Sends commands to Orchestrator, subscribes to events, updates on dispatcher thread, validates input before sending, shows loading states

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 7-layer overview, deployment model
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine, build system, retry logic
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn integration, patch engine
- [PREVIEW_SYSTEM.md](./PREVIEW_SYSTEM.md) — Preview rendering
