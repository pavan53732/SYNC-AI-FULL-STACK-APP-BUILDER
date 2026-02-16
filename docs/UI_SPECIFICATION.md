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

---

## 2. Main Application Layout

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

---

## 4. UI → Orchestrator Contract

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
