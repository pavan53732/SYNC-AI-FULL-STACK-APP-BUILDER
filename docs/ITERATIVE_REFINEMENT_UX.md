# Iterative Refinement & Export UX Specification

**Purpose**: Define conversational refinement, export/packaging, and project history UX patterns  
**Framework**: WinUI 3, MVVM pattern  
**Philosophy**: AI companion, not code generator

---

## Core Principle

> **Iterative evolution without intimidation**
> 
> Zero technical exposure. Controlled mutation through orchestrator. Feels like chatting, not programming.

---

## 1. "Improve This App" – Conversational Refinement Flow

### Entry Point

After first successful build (UI State: `PREVIEW_READY`):

```xaml
<Button Content="Improve this app"
        Style="{StaticResource SubtleAccentButtonStyle}"
        Height="36"
        CornerRadius="18"
        Margin="0,16,0,0"
        Click="{x:Bind ViewModel.EnterRefinementMode}"/>
```

**Button Style**:
- Subtle accent outline
- 36px height
- Rounded corners (18px)
- Positioned below preview

---

### Layout Transition

When clicked, right panel switches to **Refinement Mode**:

```
┌─────────────────────────────┐
│   App Preview (Top 60%)     │
│                             │
├─────────────────────────────┤
│ Conversation Panel (40%)    │
│                             │
└─────────────────────────────┘
```

**Implementation**:
```csharp
private async void EnterRefinementMode()
{
    // Animate panel resize
    await PreviewPanel.AnimateHeightAsync(
        from: "100%", 
        to: "60%", 
        duration: 200
    );
    
    // Slide in conversation panel
    ConversationPanel.Visibility = Visibility.Visible;
    await ConversationPanel.SlideInFromBottomAsync(duration: 160);
    
    // Show system message
    AddSystemMessage("You can add features, redesign layouts, or modify behavior.");
}
```

---

### Conversation Panel Structure

```xaml
<Grid x:Name="ConversationPanel" Height="40%">
    <Grid.RowDefinitions>
        <RowDefinition Height="*"/> <!-- Message history -->
        <RowDefinition Height="Auto"/> <!-- Input box -->
    </Grid.RowDefinitions>
    
    <!-- Message History -->
    <ScrollViewer Grid.Row="0" Padding="16">
        <ItemsControl ItemsSource="{x:Bind ViewModel.ConversationMessages}">
            <ItemsControl.ItemTemplate>
                <DataTemplate x:DataType="local:ConversationMessage">
                    <Grid Margin="0,0,0,12">
                        <!-- User message: right-aligned -->
                        <Border Background="{ThemeResource AccentFillColorDefaultBrush}"
                                CornerRadius="12"
                                Padding="12,8"
                                HorizontalAlignment="Right"
                                MaxWidth="320"
                                Visibility="{x:Bind IsUserMessage}">
                            <TextBlock Text="{x:Bind Content}" TextWrapping="Wrap"/>
                        </Border>
                        
                        <!-- System message: left-aligned -->
                        <Border Background="{ThemeResource LayerFillColorDefaultBrush}"
                                CornerRadius="12"
                                Padding="12,8"
                                HorizontalAlignment="Left"
                                MaxWidth="320"
                                Visibility="{x:Bind IsSystemMessage}">
                            <TextBlock Text="{x:Bind Content}" TextWrapping="Wrap"/>
                        </Border>
                    </Grid>
                </DataTemplate>
            </ItemsControl.ItemTemplate>
        </ItemsControl>
    </ScrollViewer>
    
    <!-- Input Box -->
    <Grid Grid.Row="1" Padding="16" Background="{ThemeResource LayerFillColorAltBrush}">
        <TextBox x:Name="RefinementPrompt"
                 PlaceholderText="Describe what you'd like to change…"
                 Height="40"
                 CornerRadius="20"
                 AcceptsReturn="False"
                 KeyDown="{x:Bind OnRefinementKeyDown}"/>
        
        <Button Content="&#xE724;" <!-- Send icon -->
                FontFamily="Segoe MDL2 Assets"
                Style="{StaticResource AccentButtonStyle}"
                Width="32" Height="32"
                CornerRadius="16"
                HorizontalAlignment="Right"
                Margin="0,0,8,0"
                Click="{x:Bind SendRefinementRequest}"/>
    </Grid>
</Grid>
```

---

### User Examples (Natural Language)

Users can type:
- "Add user authentication"
- "Make the UI more modern"
- "Add filtering to the customer list"
- "Add export to Excel"
- "Improve performance"

**No technical knowledge required**

---

### Refinement Flow State Machine

```
IDLE
  ↓ (user sends message)
USER_MESSAGE
  ↓ (orchestrator processes)
AI_PLANNING (hidden from user)
  ↓ (orchestrator executes)
APPLYING_CHANGES (maps to UI State: BUILDING)
  ↓ (build succeeds)
PREVIEW_UPDATE (maps to UI State: PREVIEW_READY)
```

**User sees**:
- "Updating your app…" (with shimmer)
- Preview updates smoothly
- No task names, no file operations

---

### Smart Feature Detection

**User says**: "Add login"

**System internally**:
1. Adds `AuthService.cs`
2. Adds `LoginView.xaml`
3. Updates `NavigationService`
4. Adds DI registration in `App.xaml.cs`
5. Updates `MainViewModel`

**User sees**:
- "Updating your app…"
- Preview shows new login screen
- No mention of files, patches, or dependencies

---

### Refinement Failure UX

**Soft Failure** (retries ongoing):
```csharp
AddSystemMessage("Working on that change…");
// Silent retry continues
```

**Hard Failure** (retry budget exhausted):
```csharp
AddSystemMessage("I couldn't safely apply that change. You can refine your request.");

// Show action buttons
ShowRefinementActions(new[] { "Retry", "Edit Prompt" });
```

**Never show**:
- Compiler output
- Stack traces
- File paths
- Technical errors

---

### Proactive AI Suggestions (Advanced)

After applying a change, AI can suggest:

```csharp
private void ShowProactiveSuggestion(string suggestion)
{
    var suggestionChip = new Button
    {
        Content = suggestion,
        Style = Resources["SuggestionChipStyle"],
        Height = 32,
        CornerRadius = new CornerRadius(16),
        Padding = new Thickness(16, 0, 16, 0)
    };
    
    SuggestionPanel.Children.Add(suggestionChip);
}

// Example:
ShowProactiveSuggestion("Would you like to add role-based permissions?");
```

**Suggestions appear as pill buttons** below the last message

---

## 2. Export & MSIX Packaging UX

### Goal

> Export should feel like "Ship My App", not "Run MSBuild with packaging profile"

---

### Export Entry Point

In `PREVIEW_READY` state, top right of preview panel:

```xaml
<DropDownButton Content="Export" Style="{StaticResource AccentButtonStyle}">
    <DropDownButton.Flyout>
        <MenuFlyout>
            <MenuFlyoutItem Text="Build Installer (MSIX)" 
                            Icon="Package"
                            Click="{x:Bind BuildInstaller}"/>
            <MenuFlyoutItem Text="Export Source Code" 
                            Icon="SaveLocal"
                            Click="{x:Bind ExportSourceCode}"/>
            <MenuFlyoutItem Text="Open Project Folder" 
                            Icon="Folder"
                            Click="{x:Bind OpenProjectFolder}"/>
        </MenuFlyout>
    </DropDownButton.Flyout>
</DropDownButton>
```

---

### MSIX Packaging Flow

When "Build Installer" selected, show modal:

```xaml
<ContentDialog x:Name="PackagingDialog"
               Title="Build Windows Installer"
               PrimaryButtonText="Build Installer"
               CloseButtonText="Cancel"
               DefaultButton="Primary">
    <StackPanel Spacing="16" Padding="24">
        <!-- App Name -->
        <TextBox Header="App Name"
                 Text="{x:Bind ViewModel.AppName, Mode=TwoWay}"
                 PlaceholderText="My Application"/>
        
        <!-- Publisher Name -->
        <TextBox Header="Publisher Name"
                 Text="{x:Bind ViewModel.PublisherName, Mode=TwoWay}"
                 PlaceholderText="CN=YourName"/>
        
        <!-- Version (Auto-generated) -->
        <TextBlock Text="{x:Bind ViewModel.AppVersion}" 
                   Foreground="{ThemeResource TextFillColorSecondaryBrush}"
                   FontSize="14"/>
        
        <!-- Icon Upload -->
        <StackPanel>
            <TextBlock Text="App Icon" FontWeight="SemiBold" Margin="0,0,0,8"/>
            <Button Content="Upload Icon" 
                    Icon="Pictures"
                    Click="{x:Bind UploadIcon}"/>
            <Image Source="{x:Bind ViewModel.IconPath}" 
                   Width="64" Height="64" 
                   Margin="0,8,0,0"/>
        </StackPanel>
    </StackPanel>
</ContentDialog>
```

---

### Packaging State Machine

```
CONFIGURE (user fills form)
  ↓
PACKAGING (MSBuild packaging)
  ↓
SIGNING (certificate signing)
  ↓
VERIFYING (validation)
  ↓
READY (installer available)
```

**User sees**:
```csharp
private async Task PackageApplicationAsync()
{
    // Update dialog to show progress
    PackagingDialog.Title = "Preparing your installer…";
    PackagingDialog.IsPrimaryButtonEnabled = false;
    
    // Show smooth progress bar
    var progressBar = new ProgressBar { IsIndeterminate = true };
    PackagingDialog.Content = progressBar;
    
    // Execute packaging
    var result = await _packagingService.CreateMSIXAsync(
        appName: ViewModel.AppName,
        publisher: ViewModel.PublisherName,
        version: ViewModel.AppVersion,
        iconPath: ViewModel.IconPath
    );
    
    if (result.Success)
    {
        ShowPackagingSuccess(result.InstallerPath);
    }
    else
    {
        ShowPackagingFailure(result.Error);
    }
}
```

---

### On Success

```csharp
private void ShowPackagingSuccess(string installerPath)
{
    PackagingDialog.Title = "Your installer is ready!";
    
    var successPanel = new StackPanel { Spacing = 16 };
    
    // Success icon
    successPanel.Children.Add(new FontIcon 
    { 
        Glyph = "\uE73E", // Checkmark
        FontSize = 48,
        Foreground = new SolidColorBrush(Colors.Green)
    });
    
    // File path (subtle)
    successPanel.Children.Add(new TextBlock
    {
        Text = Path.GetFileName(installerPath),
        FontSize = 14,
        Foreground = (Brush)Resources["TextFillColorSecondaryBrush"]
    });
    
    // Action buttons
    var buttonPanel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
    buttonPanel.Children.Add(new Button { Content = "Open Folder" });
    buttonPanel.Children.Add(new Button { Content = "Install Now" });
    buttonPanel.Children.Add(new Button { Content = "Share" });
    
    successPanel.Children.Add(buttonPanel);
    
    PackagingDialog.Content = successPanel;
}
```

---

### On Failure

```csharp
private void ShowPackagingFailure(PackagingError error)
{
    PackagingDialog.Title = "We couldn't complete the packaging process.";
    
    var failurePanel = new StackPanel { Spacing = 16 };
    
    // Friendly message
    failurePanel.Children.Add(new TextBlock
    {
        Text = TranslatePackagingError(error),
        TextWrapping = TextWrapping.Wrap
    });
    
    // Action buttons
    var buttonPanel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
    buttonPanel.Children.Add(new Button { Content = "Retry" });
    
    // Technical details (collapsed)
    var expander = new Expander
    {
        Header = "View Technical Details",
        Content = new TextBlock { Text = error.TechnicalDetails }
    };
    failurePanel.Children.Add(expander);
    
    PackagingDialog.Content = failurePanel;
}
```

---

## 3. Project History Timeline UX

### Goal

> Show evolution, maintain safety, enable rollback, avoid technical clutter

---

### History Tab Layout

```xaml
<TabViewItem Header="History" IconSource="History">
    <Grid>
        <!-- Timeline -->
        <ScrollViewer Padding="24">
            <ItemsControl ItemsSource="{x:Bind ViewModel.ProjectVersions}">
                <ItemsControl.ItemTemplate>
                    <DataTemplate x:DataType="local:ProjectVersion">
                        <Grid Margin="0,0,0,24">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="40"/> <!-- Timeline dot -->
                                <ColumnDefinition Width="*"/> <!-- Content -->
                            </Grid.ColumnDefinitions>
                            
                            <!-- Timeline Dot -->
                            <Ellipse Grid.Column="0"
                                     Width="12" Height="12"
                                     Fill="{ThemeResource AccentFillColorDefaultBrush}"
                                     VerticalAlignment="Top"
                                     Margin="0,4,0,0"/>
                            
                            <!-- Vertical Line -->
                            <Rectangle Grid.Column="0"
                                       Width="2"
                                       Fill="{ThemeResource DividerStrokeColorDefaultBrush}"
                                       VerticalAlignment="Stretch"
                                       HorizontalAlignment="Center"
                                       Margin="0,16,0,0"/>
                            
                            <!-- Version Card -->
                            <Border Grid.Column="1"
                                    Background="{ThemeResource LayerFillColorDefaultBrush}"
                                    CornerRadius="8"
                                    Padding="16"
                                    PointerEntered="OnVersionHover"
                                    Tapped="OnVersionClick">
                                <StackPanel Spacing="8">
                                    <!-- Title -->
                                    <TextBlock Text="{x:Bind Description}"
                                               FontWeight="SemiBold"
                                               FontSize="16"/>
                                    
                                    <!-- Timestamp -->
                                    <TextBlock Text="{x:Bind Timestamp}"
                                               FontSize="12"
                                               Foreground="{ThemeResource TextFillColorSecondaryBrush}"/>
                                    
                                    <!-- Snapshot ID (collapsed) -->
                                    <Expander Header="Details" IsExpanded="False">
                                        <TextBlock Text="{x:Bind SnapshotId}"
                                                   FontFamily="Consolas"
                                                   FontSize="12"/>
                                    </Expander>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </DataTemplate>
                </ItemsControl.ItemTemplate>
            </ItemsControl>
        </ScrollViewer>
    </Grid>
</TabViewItem>
```

**Example Timeline**:
```
● Version 4 – Added Export Feature
│ 2 hours ago
│
● Version 3 – Improved Dashboard UI
│ Yesterday
│
● Version 2 – Added Authentication
│ 2 days ago
│
● Version 1 – Initial App Created
  3 days ago
```

---

### Clicking a Version

Right panel shows version details:

```xaml
<Grid x:Name="VersionDetailsPanel">
    <StackPanel Spacing="16" Padding="24">
        <!-- Before/After Toggle -->
        <ToggleSwitch Header="Show Before/After"
                      IsOn="{x:Bind ShowDiff, Mode=TwoWay}"
                      OnContent="After"
                      OffContent="Before"/>
        
        <!-- Preview -->
        <Border CornerRadius="8" BorderThickness="1">
            <Grid>
                <!-- Before Preview -->
                <ContentPresenter Content="{x:Bind BeforePreview}"
                                  Visibility="{x:Bind ShowBeforePreview}"/>
                
                <!-- After Preview -->
                <ContentPresenter Content="{x:Bind AfterPreview}"
                                  Visibility="{x:Bind ShowAfterPreview}"/>
            </Grid>
        </Border>
        
        <!-- Diff View (Optional) -->
        <Expander Header="View Code Changes">
            <ScrollViewer MaxHeight="300">
                <TextBlock Text="{x:Bind DiffSummary}"
                           FontFamily="Cascadia Code"
                           FontSize="12"/>
            </ScrollViewer>
        </Expander>
        
        <!-- Restore Button -->
        <Button Content="Restore This Version"
                Style="{StaticResource AccentButtonStyle}"
                Click="{x:Bind RestoreVersion}"/>
    </StackPanel>
</Grid>
```

---

### Restore Flow

When user clicks "Restore This Version":

```csharp
private async void RestoreVersion(ProjectVersion version)
{
    // Show confirmation dialog
    var dialog = new ContentDialog
    {
        Title = "Restore app to this version?",
        Content = $"This will restore your app to: {version.Description}",
        PrimaryButtonText = "Restore",
        CloseButtonText = "Cancel"
    };
    
    var result = await dialog.ShowAsync();
    
    if (result == ContentDialogResult.Primary)
    {
        // Execute restore
        await _snapshotService.RestoreAsync(version.SnapshotId);
        
        // Rebuild silently
        await _orchestrator.RebuildCurrentProjectAsync();
        
        // Update preview
        await RefreshPreviewAsync();
        
        // Show success
        ShowToast("Restored successfully.");
    }
}
```

**User sees**:
- Confirmation dialog
- "Restoring…" (brief)
- Preview updates
- Success toast

**User does NOT see**:
- File operations
- Snapshot mechanics
- Build process

---

### Timeline Micro-Animations

```csharp
private void OnVersionHover(object sender, PointerRoutedEventArgs e)
{
    var border = sender as Border;
    
    // Scale up slightly
    border.Scale = new Vector3(1.02f, 1.02f, 1.0f);
    
    // Increase elevation
    border.Translation = new Vector3(0, -2, 8);
}

private async void OnVersionClick(object sender, TappedRoutedEventArgs e)
{
    var versionCard = sender as Border;
    
    // Highlight with accent border
    versionCard.BorderBrush = (Brush)Resources["AccentFillColorDefaultBrush"];
    versionCard.BorderThickness = new Thickness(2);
    
    // Expand details panel (slide down 180ms)
    await VersionDetailsPanel.SlideDownAsync(duration: 180);
}
```

**Smooth scroll snap**:
```xaml
<ScrollViewer ScrollViewer.VerticalScrollMode="Enabled"
              ScrollViewer.VerticalSnapPointsType="Mandatory"
              ScrollViewer.VerticalSnapPointsAlignment="Near">
    <!-- Timeline items -->
</ScrollViewer>
```

---

## 4. Advanced Timeline Features

After multiple versions (5+), show filters:

```xaml
<CommandBar>
    <AppBarButton Icon="Filter" Label="Filter">
        <AppBarButton.Flyout>
            <MenuFlyout>
                <MenuFlyoutItem Text="All Changes"/>
                <MenuFlyoutItem Text="Feature Additions"/>
                <MenuFlyoutItem Text="UI Changes"/>
                <MenuFlyoutItem Text="Refactors"/>
            </MenuFlyout>
        </AppBarButton.Flyout>
    </AppBarButton>
</CommandBar>
```

**Build Health Indicator** (per version):
```xaml
<FontIcon Glyph="&#xE73E;" <!-- Checkmark -->
          Foreground="Green"
          Visibility="{x:Bind BuildSucceeded}"/>

<FontIcon Glyph="&#xE7BA;" <!-- Warning -->
          Foreground="Orange"
          Visibility="{x:Bind HadRetries}"/>
```

**Retry Count Indicator** (Developer Mode only):
```xaml
<TextBlock Text="{x:Bind RetryCount}"
           FontSize="12"
           Foreground="{ThemeResource TextFillColorSecondaryBrush}"
           Visibility="{x:Bind DeveloperModeEnabled}"/>
```

---

## 5. Emotional UX Summary

### Your App Should Feel Like:
- ✅ AI collaborator
- ✅ Conversational partner
- ✅ Iterative design tool

### NOT Like:
- ❌ Code generator
- ❌ IDE replacement
- ❌ Build dashboard
- ❌ Technical tool

---

## 6. Final Combined User Journey

1. **Prompt**: "Build a CRM app"
2. **Working WinUI app** appears
3. **Improve conversationally**: "Add export to Excel"
4. **Timeline shows evolution**: Version 1 → Version 2
5. **Export to installer**: One-click MSIX
6. **Ship**: Install or share

**All with**:
- Silent retries
- Deterministic backend
- Snapshot safety
- Calm UI
- Zero technical exposure

---

## References

- [UI_STATE_MACHINE.md](./UI_STATE_MACHINE.md) - 7-state system
- [UI_SPECIFICATION.md](./UI_SPECIFICATION.md) - Pixel-perfect measurements
- [ERROR_HANDLING_SPECIFICATION.md](./ERROR_HANDLING_SPECIFICATION.md) - Failure handling
- [DESIGN_PHILOSOPHY.md](./DESIGN_PHILOSOPHY.md) - Lovable-style principles
