# UI Specification - WinUI 3 Presentation Layer

**Purpose:** Define exactly what developers must build in WinUI 3.  
**Scope:** Presentation layer only. No business logic inside UI.  
**Framework:** WinUI 3 (Windows App SDK), .NET 8, MVVM pattern

---

## 1. UI Architectural Rules

### Core Principles
* **WinUI 3** (Windows App SDK) - Modern Windows UI framework
* **MVVM pattern mandatory** - ViewModels handle all UI logic
* **UI is thin** - No business logic in code-behind
* **No direct file writes** - All file operations through services
* **No direct build calls** - All actions go through Orchestrator
* **All long operations async** - Never block UI thread
* **UI never blocks main thread** - Use async/await everywhere
* **Fluent Design System** - Follow Microsoft's design language

### Dependency Injection
```csharp
// App.xaml.cs - Service registration
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
        services.AddSingleton<IOrchestrator, OrchestratorService>();
        services.AddSingleton<IProjectService, ProjectService>();
        services.AddSingleton<IPreviewService, PreviewService>();
        
        return services.BuildServiceProvider();
    }
    
    public static T GetService<T>() => 
        ((App)Current)._services.GetService<T>();
}
```

```

---

## 2. Design System (Pixel-Perfect Specifications)

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

**Specifications**:
- **Minimum Width**: 1200px
- **Minimum Height**: 800px
- **Default Size**: 1440 × 900px
- **Background**: Mica (BaseAlt)
- **Card Corner Radius**: 12px
- **Outer Padding**: 32px

### Spacing Scale (8px System)

Use consistent spacing throughout the application:

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Tight spacing (icon padding) |
| `sm` | 8px | Default spacing between related elements |
| `md` | 16px | Section spacing |
| `lg` | 24px | Major section spacing |
| `xl` | 32px | Page margins |

**Implementation**:
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

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| **Title** | 28px | Semibold | Page titles, empty state |
| **Subtitle** | 20px | Semibold | Section headers |
| **Body** | 16px | Regular | Primary content |
| **Caption** | 14px | Regular | Secondary text, labels |
| **Small** | 12px | Regular | Metadata, timestamps |
| **Code** | 14px | Regular | Code display (Cascadia Code) |

**Implementation**:
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

### Color Palette

**Status Indicators**:
```xaml
<ResourceDictionary>
    <!-- Status Colors -->
    <SolidColorBrush x:Key="StatusIdleBrush" Color="#6B6B6B"/>
    <SolidColorBrush x:Key="StatusBuildingBrush" Color="#0078D4"/>
    <SolidColorBrush x:Key="StatusSuccessBrush" Color="#107C10"/>
    <SolidColorBrush x:Key="StatusErrorBrush" Color="#D13438"/>
</ResourceDictionary>
```

| State | Color | Hex | Behavior |
|-------|-------|-----|----------|
| **Idle** | Gray | `#6B6B6B` | Static |
| **Building** | Blue | `#0078D4` | Pulse animation |
| **Success** | Green | `#107C10` | Flash 300ms |
| **Error** | Red | `#D13438` | Soft pulse |

### Material System

**Background Materials**:
```csharp
// Mica for main window background
this.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.BaseAlt };

// Acrylic for panels
var acrylicBrush = new AcrylicBrush
{
    TintColor = Colors.Transparent,
    TintOpacity = 0.0,
    TintLuminosityOpacity = 0.15,
    FallbackColor = Colors.Transparent
};
```

**Material Usage**:
- **Main Window**: Mica BaseAlt
- **Side Panels**: Acrylic (subtle, 15% luminosity)
- **Cards**: LayerFillColorDefault with 12px corner radius
- **Elevated Cards**: Add subtle drop shadow

### Component Sizing

**Buttons**:
- **Primary Button**: 160px × 48px, 8px corner radius
- **Icon Button**: 32px × 32px
- **Chip Button**: Auto width × 32px, 16px corner radius

**Input Fields**:
- **Prompt Box**: 720px × 48px (empty state), 10px corner radius
- **Text Input**: Auto width × 32px, 6px corner radius

**Panels**:
- **Left Panel**: 260px fixed width
- **Top Bar**: Full width × 64px
- **Tab Strip**: Full width × 48px

---

## 3. Main Application Layout

### Window Structure

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
                           Foreground="White"
                           FontSize="16"
                           FontWeight="SemiBold"
                           VerticalAlignment="Center"
                           Margin="12,0,0,0"/>
                
                <!-- Project Selector -->
                <ComboBox x:Name="ProjectSelector"
                          Width="200"
                          Margin="32,0,0,0"
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
        <NavigationView Grid.Row="1" 
                        x:Name="NavView"
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
            
            <!-- Left Panel -->
            <Border Grid.Column="0" 
                    Background="{ThemeResource LayerFillColorDefaultBrush}"
                    BorderBrush="{ThemeResource CardStrokeColorDefaultBrush}"
                    BorderThickness="0,0,1,0">
                <Frame x:Name="LeftPanelFrame"/>
            </Border>
            
            <!-- Splitter -->
            <GridSplitter Grid.Column="1" 
                          Background="{ThemeResource DividerStrokeColorDefaultBrush}"/>
            
            <!-- Main Content Frame -->
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

## 3. Required Pages

### 1. ProjectsPage.xaml

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

### 2. EditorPage.xaml

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
                
                <NumberBox Header="Max Retries"
                           Value="{x:Bind ViewModel.MaxRetries, Mode=TwoWay}"
                           Minimum="0"
                           Maximum="10"
                           Width="120"/>
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

### 3. BuildMonitorPanel.xaml

**Purpose:** Real-time orchestrator state visualization

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

### 4. CodePreviewPage.xaml

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

### 5. SettingsPage.xaml

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
                    <NumberBox Header="Retry Budget"
                               Value="{x:Bind ViewModel.RetryBudget, Mode=TwoWay}"
                               Minimum="1"
                               Maximum="20"/>
                    
                    <NumberBox Header="Build Timeout (seconds)"
                               Value="{x:Bind ViewModel.BuildTimeout, Mode=TwoWay}"
                               Minimum="30"
                               Maximum="300"/>
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
            
            <!-- Save Button -->
            <Button Content="Save Settings"
                    Style="{StaticResource AccentButtonStyle}"
                    Click="{x:Bind ViewModel.SaveSettings}"
                    HorizontalAlignment="Right"/>
        </StackPanel>
    </ScrollViewer>
</Page>
```

```

---

## 4. Micro-Interactions (Motion Design)

### Generate Button Behavior

The primary action button must feel responsive and provide clear feedback.

**Idle State**:
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

**Status Dot** (12px circle in top bar):
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
    
    // Fade back to idle gray
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

**User sees**: "Building your app…"

**If retry occurs internally**:
```csharp
private void ShowSubtleRetryHint(int retryCount)
{
    if (retryCount <= 3)
    {
        // Silent - no UI change
        // Only log internally
        _logger.LogDebug("Retry attempt {Attempt} in progress", retryCount);
        return;
    }
    
    // After 3 retries, show subtle hint
    if (retryCount == 4)
    {
        // Slight text shimmer effect
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

**If rollback happens**:
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

## 5. Progressive Disclosure Pattern (Lovable-Style UX)

### Philosophy

> **"Powerful internal system, minimal visible complexity"**

The UI follows a **progressive disclosure** pattern where advanced features are hidden by default, presenting a clean, calm interface to users while maintaining full power for developers who need it.

### Default View (Simple Mode)

**Always Visible**:
- ✅ Prompt input (EditorPage)
- ✅ Generate button
- ✅ Preview tabs (XAML Preview, Code View, Full Launch)
- ✅ Export button
- ✅ Status bar (minimal info: Orchestrator state, SDK status, error count)

**Hidden by Default**:
- ❌ Build Monitor panel (detailed orchestrator state)
- ❌ Task graph visualization
- ❌ Raw build logs
- ❌ Retry attempt details
- ❌ Snapshot history
- ❌ Advanced build settings

### Developer Mode Toggle

Users can enable **"Developer Mode"** in Settings to reveal advanced features:

```csharp
public class MainViewModel : ObservableObject
{
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
    
    private void UpdateUIVisibility()
    {
        if (DeveloperModeEnabled)
        {
            // Show BuildMonitorPanel in navigation
            // Show detailed status bar info
            // Enable advanced settings
        }
        else
        {
            // Hide advanced features
            // Show only essential UI elements
        }
    }
}
```

### Settings Toggle UI

```xaml
<!-- SettingsPage.xaml - Add this section -->
<Expander Header="Developer Options">
    <StackPanel Spacing="12" Padding="12">
        <ToggleSwitch x:Name="DeveloperModeToggle"
                      Header="Developer Mode"
                      IsOn="{x:Bind ViewModel.DeveloperModeEnabled, Mode=TwoWay}"
                      OnContent="Enabled"
                      OffContent="Disabled">
            <ToggleSwitch.Description>
                Show advanced features like build logs, task graphs, and retry statistics.
            </ToggleSwitch.Description>
        </ToggleSwitch>
        
        <InfoBar Severity="Informational"
                 IsOpen="True"
                 Message="Developer Mode is recommended only for debugging. Most users should keep this disabled for a cleaner experience."/>
    </StackPanel>
</Expander>
```

### Navigation Visibility

```csharp
// MainWindow.xaml.cs
private void UpdateNavigationItems()
{
    var navItems = new List<NavigationViewItem>
    {
        new() { Content = "Projects", Icon = new SymbolIcon(Symbol.Folder), Tag = "projects" },
        new() { Content = "Editor", Icon = new SymbolIcon(Symbol.Edit), Tag = "editor" },
        new() { Content = "Preview", Icon = new SymbolIcon(Symbol.View), Tag = "preview" },
        new() { Content = "Settings", Icon = new SymbolIcon(Symbol.Setting), Tag = "settings" }
    };
    
    // Only show Build Monitor if Developer Mode enabled
    if (ViewModel.DeveloperModeEnabled)
    {
        navItems.Insert(3, new NavigationViewItem 
        { 
            Content = "Build Monitor", 
            Icon = new SymbolIcon(Symbol.RepeatAll), 
            Tag = "build" 
        });
    }
    
    NavView.MenuItems.Clear();
    foreach (var item in navItems)
    {
        NavView.MenuItems.Add(item);
    }
}
```

### Error Display Strategy

**Simple Mode** (Default):
```
❌ We encountered an issue while building your app.
   Retrying automatically...
```

**Developer Mode** (Enabled):
```
❌ Build Error: CS0246
   File: MainViewModel.cs, Line 42
   Message: The type or namespace name 'ObservableObject' could not be found
   
   [Show Stack Trace] [View Build Log]
```

### Benefits

1. **New Users**: Clean, unintimidating interface (Lovable-style)
2. **Power Users**: Full access to diagnostics when needed
3. **Best of Both Worlds**: Simple by default, powerful when required

---

## 6. Failure State Hierarchy (Three-Tier System)

### Philosophy

> **"Fail silently, succeed loudly"**

Errors must be handled gracefully with minimal user disruption. The system uses a three-tier approach based on severity and recoverability.

### Tier 1: Silent Auto-Recovery

**Condition**: Build error resolved within retry budget (≤3 attempts)

**User Experience**:
- ✅ No error message shown
- ✅ Spinner continues smoothly
- ✅ No logs exposed
- ✅ No UI change whatsoever

**Implementation**:
```csharp
private async Task<BuildResult> BuildWithSilentRetryAsync(string projectPath)
{
    for (int attempt = 1; attempt <= 3; attempt++)
    {
        var result = await _buildService.BuildAsync(projectPath);
        
        if (result.Success)
        {
            // Silent success - user never knew there was a problem
            _logger.LogInformation("Build succeeded on attempt {Attempt}", attempt);
            return result;
        }
        
        // Log internally, don't show to user
        _logger.LogWarning("Build attempt {Attempt} failed: {Error}", attempt, result.Error);
        
        // Exponential backoff
        await Task.Delay(TimeSpan.FromSeconds(Math.Pow(2, attempt - 1)));
    }
    
    // Escalate to Tier 2
    return await HandleRecoverableFailureAsync(projectPath);
}
```

### Tier 2: Recoverable Failure

**Condition**: Initial retries failed, but system can try alternative approaches

**User Experience**:
```xaml
<InfoBar x:Name="RecoverableFailureBar"
         Severity="Warning"
         IsOpen="False"
         Title="Build Issue Detected"
         Message="We encountered an issue while building your app. Retrying with adjustments…">
    <InfoBar.ActionButton>
        <Button Content="Retry Now" 
                Click="{x:Bind ViewModel.RetryBuild}"/>
    </InfoBar.ActionButton>
</InfoBar>
```

**Logs Tab**: Becomes available (collapsed by default)

**Implementation**:
```csharp
private async Task<BuildResult> HandleRecoverableFailureAsync(string projectPath)
{
    // Show non-technical warning
    RecoverableFailureBar.IsOpen = true;
    
    // Make Logs tab available (but don't auto-open)
    LogsTab.Visibility = Visibility.Visible;
    
    // Try alternative build strategies
    var strategies = new[]
    {
        () => _buildService.BuildWithCleanAsync(projectPath),
        () => _buildService.BuildWithRestoreAsync(projectPath),
        () => _buildService.BuildWithFallbackConfigAsync(projectPath)
    };
    
    foreach (var strategy in strategies)
    {
        var result = await strategy();
        if (result.Success)
        {
            RecoverableFailureBar.IsOpen = false;
            return result;
        }
    }
    
    // Escalate to Tier 3
    return await HandleHardFailureAsync(projectPath);
}
```

### Tier 3: Hard Failure

**Condition**: Retry budget exhausted, structural conflict detected

**User Experience**:
```xaml
<ContentDialog x:Name="HardFailureDialog"
               Title="Build Could Not Complete"
               PrimaryButtonText="Retry"
               SecondaryButtonText="Modify Prompt"
               CloseButtonText="Cancel"
               DefaultButton="ContentDialogButton.Close">
    <StackPanel Spacing="16" Padding="24">
        <!-- Error Icon -->
        <FontIcon Glyph="&#xE7BA;" 
                  FontSize="48" 
                  Foreground="{ThemeResource SystemErrorTextColor}"
                  HorizontalAlignment="Center"/>
        
        <!-- Main Message -->
        <TextBlock Text="We couldn't complete this build."
                   Style="{StaticResource SubtitleTextBlockStyle}"
                   HorizontalAlignment="Center"/>
        
        <!-- Reason -->
        <TextBlock Text="{x:Bind ViewModel.FriendlyErrorMessage}"
                   TextWrapping="Wrap"
                   HorizontalAlignment="Center"/>
        
        <!-- Technical Details (Collapsed) -->
        <Expander Header="View Technical Details"
                  HorizontalAlignment="Stretch">
            <StackPanel Spacing="8" Padding="12">
                <TextBlock Text="{x:Bind ViewModel.ErrorType}" FontWeight="SemiBold"/>
                <TextBlock Text="{x:Bind ViewModel.AffectedFile}"/>
                <TextBlock Text="{x:Bind ViewModel.BuildCode}" FontFamily="Consolas"/>
                <TextBlock Text="{x:Bind ViewModel.RetryAttempts}"/>
                <TextBlock Text="{x:Bind ViewModel.SnapshotId}" Foreground="{ThemeResource TextFillColorSecondaryBrush}"/>
            </StackPanel>
        </Expander>
    </StackPanel>
</ContentDialog>
```

**Implementation**:
```csharp
private async Task<BuildResult> HandleHardFailureAsync(string projectPath)
{
    // Populate error details
    ViewModel.FriendlyErrorMessage = TranslateErrorMessage(lastError);
    ViewModel.ErrorType = lastError.Type.ToString();
    ViewModel.AffectedFile = Path.GetFileName(lastError.FilePath);
    ViewModel.BuildCode = lastError.Code;
    ViewModel.RetryAttempts = $"Attempted {totalRetries} times";
    ViewModel.SnapshotId = await _snapshotService.GetLatestSnapshotIdAsync();
    
    // Show dialog
    var result = await HardFailureDialog.ShowAsync();
    
    if (result == ContentDialogResult.Primary)
    {
        // User clicked Retry
        return await BuildWithSilentRetryAsync(projectPath);
    }
    else if (result == ContentDialogResult.Secondary)
    {
        // User clicked Modify Prompt
        NavigateToEditor();
    }
    
    return BuildResult.Failed(lastError);
}
```

---

## 7. First-Time User Experience

### Empty State (First Launch)

**Layout** (Centered, 720px max width):
```xaml
<Grid x:Name="EmptyStateGrid"
      Visibility="{x:Bind ViewModel.IsFirstLaunch, Mode=OneWay}">
    <StackPanel VerticalAlignment="Center"
                HorizontalAlignment="Center"
                Spacing="24"
                MaxWidth="720">
        
        <!-- Title -->
        <TextBlock Text="What would you like to build?"
                   FontSize="28"
                   FontWeight="Semibold"
                   HorizontalAlignment="Center"
                   Foreground="{ThemeResource TextFillColorPrimaryBrush}"/>
        
        <!-- Prompt Box -->
        <TextBox x:Name="FirstPromptBox"
                 PlaceholderText="Describe your app in plain English…"
                 Height="48"
                 CornerRadius="10"
                 TextWrapping="Wrap"
                 AcceptsReturn="False"/>
        
        <!-- Generate Button -->
        <Button Content="Generate Application"
                Width="160"
                Height="48"
                CornerRadius="8"
                Style="{StaticResource AccentButtonStyle}"
                HorizontalAlignment="Center"
                Click="{x:Bind ViewModel.GenerateFromEmptyState}"/>
        
        <!-- Suggestion Chips -->
        <ItemsControl ItemsSource="{x:Bind ViewModel.SuggestionChips}"
                      Margin="0,16,0,0">
            <ItemsControl.ItemsPanel>
                <ItemsPanelTemplate>
                    <StackPanel Orientation="Horizontal" 
                                Spacing="8"
                                HorizontalAlignment="Center"/>
                </ItemsPanelTemplate>
            </ItemsControl.ItemsPanel>
            <ItemsControl.ItemTemplate>
                <DataTemplate x:DataType="x:String">
                    <Button Content="{Binding}"
                            Height="32"
                            CornerRadius="16"
                            Padding="16,0"
                            Style="{StaticResource SubtleButtonStyle}"
                            Click="OnSuggestionClick"/>
                </DataTemplate>
            </ItemsControl.ItemTemplate>
        </ItemsControl>
        
        <!-- Helper Text -->
        <TextBlock Text="Tip: Be specific about features you want"
                   FontSize="14"
                   Foreground="{ThemeResource TextFillColorSecondaryBrush}"
                   HorizontalAlignment="Center"/>
    </StackPanel>
</Grid>
```

**Suggestion Chips**:
```csharp
public ObservableCollection<string> SuggestionChips { get; } = new()
{
    "Inventory system",
    "CRM app",
    "Task manager",
    "Note-taking app",
    "Budget tracker",
    "Recipe organizer"
};

private void OnSuggestionClick(object sender, RoutedEventArgs e)
{
    var button = sender as Button;
    FirstPromptBox.Text = button.Content.ToString();
    FirstPromptBox.Focus(FocusState.Programmatic);
}
```

### No Tutorial Wizard

**Philosophy**: Users learn by doing, not by reading documentation walls.

- ❌ No multi-step onboarding
- ❌ No feature tour
- ❌ No "Getting Started" guide
- ✅ Immediate prompt input
- ✅ Contextual tooltips only when needed

---

## 8. Anti-Terror UX Rules

### Never Show to Users

| ❌ Forbidden | Why |
|-------------|-----|
| Raw MSBuild console output | Overwhelming, technical noise |
| Stack traces by default | Intimidating, not actionable |
| Full file paths | Exposes internal structure unnecessarily |
| Red error overlays blocking entire UI | Creates panic, prevents recovery |
| Frozen UI during builds | Feels broken, causes anxiety |
| Compiler error codes without translation | Meaningless to non-developers |

### Always Provide

| ✅ Required | Why |
|------------|-----|
| Animated feedback during operations | Reassures user system is working |
| Cancel button for long operations | Gives user control |
| Retry option on failures | Enables recovery |
| State recovery via snapshots | Prevents data loss |
| User-friendly error messages | Actionable, understandable |

### Error Message Translation

**Implementation**:
```csharp
public string TranslateErrorMessage(BuildError error)
{
    return error.Code switch
    {
        "CS0246" => "We couldn't find a required component. The system will attempt to add the missing reference automatically.",
        "CS1061" => "There's a mismatch in the code structure. Attempting to fix automatically.",
        "CS0103" => "A variable name wasn't recognized. Retrying with corrections.",
        "CS0029" => "There's a type mismatch in the generated code. Adjusting automatically.",
        "MSB3073" => "The build process encountered an issue. Retrying with different settings.",
        "MSB4018" => "A build task failed. Attempting alternative build strategy.",
        _ => "We encountered a build issue. Retrying with adjustments…"
    };
}
```

### Example Translations

**Bad** (Technical):
```
CS0246: The type or namespace name 'ObservableObject' could not be found 
(are you missing a using directive or an assembly reference?)
at MainViewModel.cs:line 12
```

**Good** (User-Friendly):
```
We couldn't find a required component.
The system will attempt to add the missing reference automatically.
```

---

**Bad** (Technical):
```
MSB3073: The command "dotnet build" exited with code 1.
```

**Good** (User-Friendly):
```
The build process encountered an issue.
Retrying with different settings…
```

### UI Behavior During Errors

**Never**:
- Block the entire window with modal error
- Show red background overlays
- Display technical jargon
- Freeze animations
- Remove user's ability to cancel

**Always**:
- Keep UI responsive
- Show calm, informative messages
- Provide clear next steps
- Maintain animation/feedback
- Allow user to retry or modify

---

## 9. UI → Orchestrator Contract

### Command Pattern

UI sends commands to Orchestrator:

```csharp
// ViewModel sends command
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

UI receives events from Orchestrator:

```csharp
public class BuildMonitorViewModel : ObservableObject
{
    private readonly IOrchestrator _orchestrator;
    
    public BuildMonitorViewModel(IOrchestrator orchestrator)
    {
        _orchestrator = orchestrator;
        
        // Subscribe to orchestrator events
        _orchestrator.StateChanged += OnOrchestratorStateChanged;
        _orchestrator.TaskProgress += OnTaskProgress;
        _orchestrator.BuildResult += OnBuildResult;
        _orchestrator.Error += OnError;
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
            TaskProgress = e.ProgressPercentage;
            RetryCount = e.RetryCount;
        });
    }
}
```

### UI Never Directly:
- ❌ Calls kernel services
- ❌ Modifies workspace files
- ❌ Handles retry logic
- ❌ Executes build commands
- ❌ Manages state transitions

### UI Always:
- ✅ Sends commands to Orchestrator
- ✅ Subscribes to Orchestrator events
- ✅ Updates UI on dispatcher thread
- ✅ Validates user input before sending
- ✅ Shows loading states during operations

---

## 5. Visual States

### Orchestrator State Mapping

| Orchestrator State | UI Indicator | Icon | Color |
|--------------------|--------------|------|-------|
| IDLE | "Ready" | &#xE73E; | Green |
| SPEC_PARSED | "Analyzing..." | &#xE8B5; | Blue |
| TASK_GRAPH_READY | "Planning..." | &#xE8F4; | Blue |
| TASK_EXECUTING | "Building..." | &#xE895; | Orange |
| VALIDATING | "Validating..." | &#xE73A; | Blue |
| RETRYING | "Retrying..." | &#xE777; | Yellow |
| COMPLETED | "Success" | &#xE73E; | Green |
| FAILED | "Failed" | &#xE783; | Red |

### State-Specific UI Behavior

```csharp
private void UpdateUIForState(OrchestratorState state)
{
    switch (state)
    {
        case OrchestratorState.IDLE:
            GenerateButton.IsEnabled = true;
            CancelButton.IsEnabled = false;
            ProgressRing.IsActive = false;
            break;
            
        case OrchestratorState.TASK_EXECUTING:
            GenerateButton.IsEnabled = false;
            CancelButton.IsEnabled = true;
            ProgressRing.IsActive = true;
            break;
            
        case OrchestratorState.RETRYING:
            ShowRetryWarning();
            break;
            
        case OrchestratorState.COMPLETED:
            ShowSuccessNotification();
            GenerateButton.IsEnabled = true;
            CancelButton.IsEnabled = false;
            ProgressRing.IsActive = false;
            break;
            
        case OrchestratorState.FAILED:
            ShowErrorDialog();
            GenerateButton.IsEnabled = true;
            CancelButton.IsEnabled = false;
            ProgressRing.IsActive = false;
            break;
    }
}
```

---

## 6. Theme System

### Light/Dark Mode Support

```xaml
<!-- App.xaml -->
<Application.Resources>
    <ResourceDictionary>
        <ResourceDictionary.ThemeDictionaries>
            <!-- Light Theme -->
            <ResourceDictionary x:Key="Light">
                <SolidColorBrush x:Key="AppBackgroundBrush" Color="#FFFFFF"/>
                <SolidColorBrush x:Key="CodeBackgroundBrush" Color="#F5F5F5"/>
            </ResourceDictionary>
            
            <!-- Dark Theme -->
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

---

## 7. Accessibility

### Requirements
- All interactive elements must have `AutomationProperties.Name`
- Keyboard navigation must work for all features
- High contrast mode support
- Screen reader compatibility
- Minimum touch target size: 44x44 pixels

### Example

```xaml
<Button Content="Generate"
        AutomationProperties.Name="Generate Application Button"
        AutomationProperties.HelpText="Starts the application generation process"
        ToolTipService.ToolTip="Generate Application (Ctrl+G)"/>
```

---

## 8. Performance Guidelines

### Virtualization
- Use `ListView` with virtualization for large lists
- Implement incremental loading for file trees
- Lazy-load code preview content

### Async Operations
```csharp
// Good: Async with progress
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

// Bad: Blocking UI
public void LoadProjects()
{
    var projects = _projectService.GetProjects(); // Blocks!
    Projects = new ObservableCollection<Project>(projects);
}
```

---

## 9. Error Handling in UI

### User-Friendly Error Messages

```csharp
private void ShowError(Exception ex)
{
    var dialog = new ContentDialog
    {
        Title = "Operation Failed",
        Content = GetUserFriendlyMessage(ex),
        CloseButtonText = "OK",
        XamlRoot = this.XamlRoot
    };
    
    await dialog.ShowAsync();
}

private string GetUserFriendlyMessage(Exception ex)
{
    return ex switch
    {
        BuildException => "The build failed. Check the build monitor for details.",
        SdkNotFoundException => "The .NET SDK was not found. Please install it.",
        _ => "An unexpected error occurred. Please try again."
    };
}
```

---

## 10. Testing UI Components

### ViewModel Unit Tests

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

## References

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) - Orchestrator contract
- [PREVIEW_SYSTEM_SPECIFICATION.md](PREVIEW_SYSTEM_SPECIFICATION.md) - Preview modes
- [DESIGN_PHILOSOPHY.md](DESIGN_PHILOSOPHY.md) - UX principles
