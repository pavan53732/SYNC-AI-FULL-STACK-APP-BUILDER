# Page Specifications

> **UI Layer: Detailed XAML for All Five Application Pages**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)
>
> **Related:** [MainLayout.md](./MainLayout.md) | [DesignSystem.md](./DesignSystem.md) | [VisualStateMachine.md](./VisualStateMachine.md)

---

## Table of Contents

1. [Pages Overview](#1-pages-overview)
2. [ProjectsPage.xaml](#2-projectspagexaml)
3. [EditorPage.xaml](#3-editorpagexaml)
4. [BuildMonitorPanel.xaml](#4-buildmonitorpanelxaml)
5. [CodePreviewPage.xaml](#5-codepreviewpagexaml)
6. [SettingsPage.xaml](#6-settingspagexaml)

---

## 1. Pages Overview

| Page | Class | Purpose |
|------|-------|---------|
| `ProjectsPage` | `SyncAIAppBuilder.UI.Pages.ProjectsPage` | List and manage local workspaces |
| `EditorPage` | `SyncAIAppBuilder.UI.Pages.EditorPage` | Prompt input and generation control |
| `BuildMonitorPanel` | `SyncAIAppBuilder.UI.Components.BuildMonitorPanel` | Real-time orchestrator state (Developer Mode only) |
| `CodePreviewPage` | `SyncAIAppBuilder.UI.Pages.CodePreviewPage` | Read-only code viewer with syntax highlighting |
| `SettingsPage` | `SyncAIAppBuilder.UI.Pages.SettingsPage` | Application configuration including AI provider settings |

---

## 2. ProjectsPage.xaml

**Purpose:** List and manage local workspaces.

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

---

## 3. EditorPage.xaml

**Purpose:** Prompt input, generation control, and asset generation progress.

```xaml
<Page x:Class="SyncAIAppBuilder.UI.Pages.EditorPage">
    <Grid Padding="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
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

        <!-- Active Task List -->
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

        <!-- Generation Progress InfoBar -->
        <InfoBar Grid.Row="2"
                 IsOpen="{x:Bind ViewModel.IsGenerating, Mode=OneWay}"
                 Severity="Informational"
                 Title="Generating Application"
                 Message="{x:Bind ViewModel.CurrentTaskDescription, Mode=OneWay}">
            <InfoBar.Content>
                <ProgressBar IsIndeterminate="True"/>
            </InfoBar.Content>
        </InfoBar>

        <!-- Asset Generation Progress -->
        <StackPanel Grid.Row="3" Spacing="8" Margin="0,16,0,0"
                    Visibility="{x:Bind ViewModel.IsGeneratingAssets, Mode=OneWay}">
            <TextBlock Text="Generating Visual Assets"
                       Style="{StaticResource SubtitleTextBlockStyle}"/>

            <!-- Requirement Evaluation Row -->
            <Grid ColumnSpacing="12">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <ProgressRing Grid.Column="0" Width="20" Height="20"
                              IsActive="{x:Bind ViewModel.IsEvaluatingRequirements}"/>
                <TextBlock Grid.Column="1" Text="Evaluating platform requirements..."
                           VerticalAlignment="Center"/>
                <FontIcon Grid.Column="2" Glyph="&#xE73E;" Foreground="Green"
                          Visibility="{x:Bind ViewModel.RequirementsEvaluated}"/>
            </Grid>

            <!-- Branding Inference Row -->
            <Grid ColumnSpacing="12">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <ProgressRing Grid.Column="0" Width="20" Height="20"
                              IsActive="{x:Bind ViewModel.IsInferringBranding}"/>
                <TextBlock Grid.Column="1" Text="Deriving brand identity..."
                           VerticalAlignment="Center"/>
                <FontIcon Grid.Column="2" Glyph="&#xE73E;" Foreground="Green"
                          Visibility="{x:Bind ViewModel.BrandingInferred}"/>
            </Grid>

            <!-- Per-Asset Generation List -->
            <ListView ItemsSource="{x:Bind ViewModel.AssetsToGenerate, Mode=OneWay}"
                      SelectionMode="None">
                <ListView.ItemTemplate>
                    <DataTemplate x:DataType="models:AssetGenerationItem">
                        <Grid ColumnSpacing="12">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <ProgressRing Grid.Column="0" Width="16" Height="16"
                                          IsActive="{x:Bind IsGenerating}"/>
                            <TextBlock Grid.Column="1" Text="{x:Bind AssetName}"
                                       VerticalAlignment="Center"/>
                            <FontIcon Grid.Column="2" Glyph="&#xE73E;" Foreground="Green"
                                      Visibility="{x:Bind IsComplete}"/>
                        </Grid>
                    </DataTemplate>
                </ListView.ItemTemplate>
            </ListView>
        </StackPanel>
    </Grid>
</Page>
```

---

## 4. BuildMonitorPanel.xaml

**Purpose:** Real-time orchestrator state visualization. Only visible in Developer Mode.

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

        <!-- Build Log (scrollable, monospaced) -->
        <ScrollViewer Grid.Row="2">
            <RichTextBlock x:Name="BuildLog"
                           FontFamily="Consolas"
                           FontSize="12"
                           IsTextSelectionEnabled="True"/>
        </ScrollViewer>
    </Grid>
</UserControl>
```

---

## 5. CodePreviewPage.xaml

**Purpose:** Read-only code viewer with file tree and syntax highlighting.

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

            <!-- File Path Header -->
            <Grid Grid.Row="0"
                  Background="{ThemeResource LayerFillColorDefaultBrush}"
                  Padding="16,8">
                <TextBlock Text="{x:Bind ViewModel.CurrentFilePath, Mode=OneWay}"
                           FontFamily="Consolas"/>
            </Grid>

            <!-- Code Content -->
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

---

## 6. SettingsPage.xaml

**Purpose:** Application configuration — AI provider slots, Developer Mode toggle.

```xaml
<Page x:Class="SyncAIAppBuilder.UI.Pages.SettingsPage">
    <ScrollViewer>
        <StackPanel Padding="24" Spacing="24" MaxWidth="800">

            <!-- AI Settings Expander -->
            <Expander Header="AI Settings" IsExpanded="True">
                <StackPanel Spacing="16" Padding="12">

                    <!-- AI Service Status Row -->
                    <Grid ColumnSpacing="12">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Grid.Column="0" Text="AI Service Status"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal" Spacing="8">
                            <Ellipse x:Name="AIServiceStatusDot"
                                     Width="12" Height="12"
                                     Fill="{x:Bind ViewModel.ServiceStatusBrush, Mode=OneWay}"/>
                            <TextBlock Text="{x:Bind ViewModel.AIServiceStatus, Mode=OneWay}"/>
                        </StackPanel>
                    </Grid>

                    <InfoBar Severity="Informational"
                             IsOpen="True"
                             Message="Configure your AI providers below. Each slot uses an OpenAI-compatible API."/>

                    <!-- Primary Model (Code & Chat) -->
                    <StackPanel Spacing="8"
                                BorderBrush="{StaticResource CardStrokeColorDefaultBrush}"
                                BorderThickness="1" CornerRadius="8" Padding="16">
                        <TextBlock Text="🧠 Primary Model (Code &amp; Chat)"
                                   Style="{StaticResource SubtitleTextBlockStyle}"/>
                        <TextBlock Text="Used for code generation, chat completions, and architecture design."
                                   Opacity="0.6"/>
                        <TextBox Header="Model Name"
                                 PlaceholderText="e.g., openai/gpt-4o"
                                 Text="{x:Bind ViewModel.PrimaryModelName, Mode=TwoWay}"/>
                        <TextBox Header="Base URL"
                                 PlaceholderText="e.g., https://openrouter.ai/api/v1"
                                 Text="{x:Bind ViewModel.PrimaryBaseUrl, Mode=TwoWay}"/>
                        <PasswordBox Header="API Key"
                                     PlaceholderText="sk-..."
                                     Password="{x:Bind ViewModel.PrimaryApiKey, Mode=TwoWay}"/>
                        <Button Content="Test Connection"
                                Click="{x:Bind ViewModel.TestPrimaryConnection}"
                                Style="{StaticResource AccentButtonStyle}"/>
                    </StackPanel>

                    <!-- Vision Model (UI Analysis) -->
                    <StackPanel Spacing="8"
                                BorderBrush="{StaticResource CardStrokeColorDefaultBrush}"
                                BorderThickness="1" CornerRadius="8" Padding="16">
                        <TextBlock Text="👁️ Vision Model (UI Analysis)"
                                   Style="{StaticResource SubtitleTextBlockStyle}"/>
                        <TextBlock Text="Used for analyzing UI screenshots and image understanding."
                                   Opacity="0.6"/>
                        <TextBox Header="Model Name"
                                 PlaceholderText="e.g., openai/gpt-4o"
                                 Text="{x:Bind ViewModel.VisionModelName, Mode=TwoWay}"/>
                        <TextBox Header="Base URL"
                                 PlaceholderText="e.g., https://openrouter.ai/api/v1"
                                 Text="{x:Bind ViewModel.VisionBaseUrl, Mode=TwoWay}"/>
                        <PasswordBox Header="API Key"
                                     PlaceholderText="sk-..."
                                     Password="{x:Bind ViewModel.VisionApiKey, Mode=TwoWay}"/>
                        <Button Content="Test Connection"
                                Click="{x:Bind ViewModel.TestVisionConnection}"/>
                    </StackPanel>

                    <!-- Image Generation Model -->
                    <StackPanel Spacing="8"
                                BorderBrush="{StaticResource CardStrokeColorDefaultBrush}"
                                BorderThickness="1" CornerRadius="8" Padding="16">
                        <TextBlock Text="🎨 Image Generation (Icons &amp; Splash)"
                                   Style="{StaticResource SubtitleTextBlockStyle}"/>
                        <TextBlock Text="Used for generating app icons, splash screens, and visual assets."
                                   Opacity="0.6"/>
                        <TextBox Header="Model Name"
                                 PlaceholderText="e.g., dall-e-3"
                                 Text="{x:Bind ViewModel.ImageGenModelName, Mode=TwoWay}"/>
                        <TextBox Header="Base URL"
                                 PlaceholderText="e.g., https://api.openai.com/v1"
                                 Text="{x:Bind ViewModel.ImageGenBaseUrl, Mode=TwoWay}"/>
                        <PasswordBox Header="API Key"
                                     PlaceholderText="sk-..."
                                     Password="{x:Bind ViewModel.ImageGenApiKey, Mode=TwoWay}"/>
                        <Button Content="Test Connection"
                                Click="{x:Bind ViewModel.TestImageGenConnection}"/>
                    </StackPanel>

                    <Button Content="Save AI Settings"
                            Click="{x:Bind ViewModel.SaveAISettings}"
                            Style="{StaticResource AccentButtonStyle}"
                            HorizontalAlignment="Right"/>
                </StackPanel>
            </Expander>

            <!-- Developer Options Expander -->
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

## References

- [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md) — Parent document (section 5)
- [MainLayout.md](./MainLayout.md) — Window and navigation shell
- [DesignSystem.md](./DesignSystem.md) — Typography, spacing, and color tokens
- [VisualStateMachine.md](./VisualStateMachine.md) — State-driven control visibility
- [PLATFORM_REQUIREMENTS_ENGINE.md](../PLATFORM_REQUIREMENTS_ENGINE.md) — Asset generation pipeline wired into EditorPage

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Expanded with full XAML for all five pages (was previously summary only) |
| 2026-02-23 | Initial extraction from UI_IMPLEMENTATION.md §5 |