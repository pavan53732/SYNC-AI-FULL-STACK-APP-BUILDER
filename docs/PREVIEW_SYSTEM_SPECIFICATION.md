# Preview System Specification - Hybrid Approach

## Overview

The Preview System provides **three modes** for users to visualize generated WinUI 3 applications:
1. **Embedded XAML Preview** - Real-time rendering inside the builder
2. **Code View** - Syntax-highlighted source code inspection
3. **Full Launch** - Compiled application execution in separate window

---

## Architecture

### Preview Service Layer

```csharp
public class PreviewService
{
    private readonly BuildService _buildService;
    private readonly XamlRenderService _xamlRenderer;
    private readonly CodeHighlightService _codeHighlighter;
    
    // Mode 1: Quick XAML Preview (Embedded)
    // ⚠️ LIMITATION: Only works for simple XAML without code-behind/ViewModels
    public async Task<UIElement> RenderXamlPreviewAsync(string xamlContent)
    {
        UIElement element = null;
        Exception parseException = null;
        
        // CRITICAL: XamlReader.Load MUST run on UI thread (WinUI 3 thread affinity)
        await _dispatcherQueue.EnqueueAsync(() =>
        {
            try
            {
                // Parse XAML string to UIElement
                element = XamlReader.Load(xamlContent) as UIElement;
            }
            catch (XamlParseException ex)
            {
                parseException = ex;
                _logger.LogError(ex, "XAML parse failed at line {Line}", ex.LineNumber);
            }
        });
        
        if (parseException != null)
        {
            throw new PreviewException($"XAML parsing failed: {parseException.Message}", parseException);
        }
        
        return element;
    }
    
    // Mode 2: Code View (Syntax Highlighted)
    public async Task<FormattedCode> GetFormattedCodeAsync(
        string projectPath, 
        CodeFileType fileType)
    {
        var files = await GetProjectFilesAsync(projectPath, fileType);
        var highlighted = await _codeHighlighter.HighlightAsync(files);
        
        return highlighted;
    }
    
    // Mode 3: Full Launch (Compiled App)
    // ⚠️ SECURITY: Requires user consent before launching AI-generated code
    public async Task<Process> LaunchFullPreviewAsync(string projectPath)
    {
        // SECURITY STEP 1: Show consent dialog
        var consent = await ShowSecurityConsentDialogAsync();
        if (!consent)
        {
            _logger.LogInformation("User declined to launch generated application");
            return null;
        }
        
        // Step 2: Build the project
        var buildResult = await _buildService.BuildAsync(projectPath);
        
        if (!buildResult.Success)
        {
            throw new BuildException("Build failed", buildResult.Errors);
        }
        
        // Step 3: Get executable path
        var exePath = Path.Combine(
            projectPath, 
            "bin/Debug/net8.0-windows/GeneratedApp.exe");
        
        // Step 4: Launch process with limited privileges
        var process = Process.Start(new ProcessStartInfo
        {
            FileName = exePath,
            UseShellExecute = false,  // More secure
            WorkingDirectory = Path.GetDirectoryName(exePath),
            CreateNoWindow = false
        });
        
        _logger.LogInformation("Launched generated application: {ExePath}", exePath);
        return process;
    }
    
    /// <summary>
    /// Shows security consent dialog before launching AI-generated code.
    /// </summary>
    private async Task<bool> ShowSecurityConsentDialogAsync()
    {
        var dialog = new ContentDialog
        {
            Title = "Security Warning",
            Content = new StackPanel
            {
                Spacing = 12,
                Children =
                {
                    new TextBlock
                    {
                        Text = "This will run AI-generated code on your computer.",
                        TextWrapping = TextWrapping.Wrap,
                        FontWeight = FontWeights.SemiBold
                    },
                    new TextBlock
                    {
                        Text = "Only proceed if you trust the generated application.",
                        TextWrapping = TextWrapping.Wrap
                    },
                    new InfoBar
                    {
                        Severity = InfoBarSeverity.Warning,
                        IsOpen = true,
                        Message = "Future versions will support Windows Sandbox for isolated execution."
                    }
                }
            },
            PrimaryButtonText = "I Understand, Launch",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close
        };
        
        var result = await dialog.ShowAsync();
        return result == ContentDialogResult.Primary;
    }
}
```

---

## UI Components

### PreviewPanel.xaml

```xaml
<UserControl x:Class="SyncAIAppBuilder.UI.Components.PreviewPanel"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    
    <Grid>
        <!-- Tab Navigation -->
        <TabView x:Name="PreviewTabs" TabWidthMode="Equal">
            
            <!-- Tab 1: Live XAML Preview -->
            <TabViewItem Header="Live Preview" IconSource="Play">
                <Grid>
                    <Border x:Name="PreviewContainer" 
                            Background="{ThemeResource ApplicationPageBackgroundThemeBrush}"
                            BorderBrush="{ThemeResource CardStrokeColorDefaultBrush}"
                            BorderThickness="1"
                            CornerRadius="8"
                            Padding="16">
                        <!-- Generated XAML renders here -->
                    </Border>
                    
                    <!-- Loading Indicator -->
                    <ProgressRing x:Name="PreviewLoader" 
                                  IsActive="False"
                                  Width="48" Height="48"/>
                    
                    <!-- Error Display -->
                    <InfoBar x:Name="PreviewError" 
                             Severity="Error" 
                             IsOpen="False"
                             Title="Preview Error"/>
                </Grid>
            </TabViewItem>
            
            <!-- Tab 2: Code View -->
            <TabViewItem Header="Code" IconSource="Code">
                <Grid>
                    <!-- File Tree -->
                    <TreeView x:Name="FileTree" Width="200" HorizontalAlignment="Left"/>
                    
                    <!-- Code Editor with Syntax Highlighting -->
                    <ScrollViewer Margin="220,0,0,0">
                        <RichTextBlock x:Name="CodeDisplay" 
                                       FontFamily="Consolas"
                                       FontSize="14"/>
                    </ScrollViewer>
                </Grid>
            </TabViewItem>
            
            <!-- Tab 3: Full Launch -->
            <TabViewItem Header="Full App" IconSource="NewWindow">
                <StackPanel VerticalAlignment="Center" 
                            HorizontalAlignment="Center"
                            Spacing="16">
                    
                    <TextBlock Text="Launch Compiled Application" 
                               Style="{StaticResource TitleTextBlockStyle}"/>
                    
                    <TextBlock Text="Build and run the complete application in a separate window"
                               Style="{StaticResource BodyTextBlockStyle}"
                               Foreground="{ThemeResource TextFillColorSecondaryBrush}"/>
                    
                    <Button x:Name="LaunchButton"
                            Content="Launch Application"
                            Click="OnLaunchFullApp"
                            Style="{StaticResource AccentButtonStyle}"
                            HorizontalAlignment="Center">
                        <Button.Icon>
                            <FontIcon Glyph="&#xE768;"/>
                        </Button.Icon>
                    </Button>
                    
                    <!-- Build Progress -->
                    <ProgressBar x:Name="BuildProgress" 
                                 IsIndeterminate="True"
                                 Visibility="Collapsed"/>
                    
                    <!-- Running App Info -->
                    <InfoBar x:Name="AppRunningInfo"
                             Severity="Success"
                             IsOpen="False"
                             Title="Application Running"
                             Message="The generated app is running in a separate window"/>
                </StackPanel>
            </TabViewItem>
        </TabView>
    </Grid>
</UserControl>
```

### PreviewPanel.xaml.cs

```csharp
public sealed partial class PreviewPanel : UserControl
{
    private readonly PreviewService _previewService;
    private Process _runningProcess;
    
    public PreviewPanel()
    {
        InitializeComponent();
        _previewService = App.GetService<PreviewService>();
    }
    
    // Mode 1: Embedded XAML Preview
    public async Task ShowXamlPreviewAsync(string xamlContent)
    {
        PreviewLoader.IsActive = true;
        PreviewError.IsOpen = false;
        
        try
        {
            var element = await _previewService.RenderXamlPreviewAsync(xamlContent);
            PreviewContainer.Child = element;
        }
        catch (Exception ex)
        {
            PreviewError.Message = ex.Message;
            PreviewError.IsOpen = true;
        }
        finally
        {
            PreviewLoader.IsActive = false;
        }
    }
    
    // Mode 2: Code View
    public async Task ShowCodeViewAsync(string projectPath)
    {
        var formattedCode = await _previewService.GetFormattedCodeAsync(
            projectPath, 
            CodeFileType.All);
        
        // Populate file tree
        FileTree.ItemsSource = formattedCode.Files;
        
        // Display first file
        if (formattedCode.Files.Any())
        {
            DisplayCode(formattedCode.Files.First());
        }
    }
    
    // Mode 3: Full Launch
    private async void OnLaunchFullApp(object sender, RoutedEventArgs e)
    {
        LaunchButton.IsEnabled = false;
        BuildProgress.Visibility = Visibility.Visible;
        
        try
        {
            var projectPath = GetCurrentProjectPath();
            _runningProcess = await _previewService.LaunchFullPreviewAsync(projectPath);
            
            AppRunningInfo.IsOpen = true;
            
            // Monitor process exit
            _runningProcess.EnableRaisingEvents = true;
            _runningProcess.Exited += OnAppProcessExited;
        }
        catch (Exception ex)
        {
            ShowError($"Failed to launch app: {ex.Message}");
        }
        finally
        {
            LaunchButton.IsEnabled = true;
            BuildProgress.Visibility = Visibility.Collapsed;
        }
    }
    
    private void OnAppProcessExited(object sender, EventArgs e)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            AppRunningInfo.IsOpen = false;
            _runningProcess = null;
        });
    }
}
```

---

## Preview Modes Comparison

| Feature | Embedded Preview | Code View | Full Launch |
|---------|-----------------|-----------|-------------|
| **Speed** | Instant | Fast | Slow (requires build) |
| **Accuracy** | High (XAML only) | N/A | 100% (actual app) |
| **Interactivity** | Limited | None | Full |
| **Use Case** | Quick UI checks | Code review | Final testing |
| **Build Required** | No | No | Yes |
| **Separate Window** | No | No | Yes |

---

### Embedded XAML Preview Limitations

> **IMPORTANT**: `XamlReader.Load()` can only parse **simple XAML** without compiled dependencies.

| XAML Feature | Supported | Reason |
|--------------|-----------|--------|
| Basic layouts (Grid, StackPanel, etc.) | ✅ Yes | Built-in WinUI 3 controls |
| Standard controls (Button, TextBox, etc.) | ✅ Yes | Built-in WinUI 3 controls |
| Static resources (colors, styles) | ✅ Yes | Can be parsed from XAML |
| Simple data binding (`{Binding}`) | ⚠️ Partial | Works if DataContext set manually |
| **Custom controls** | ❌ No | Types not available at runtime |
| **Code-behind event handlers** | ❌ No | Requires compilation |
| **x:Bind (compiled bindings)** | ❌ No | Compile-time only |
| **ViewModels** | ❌ No | Requires compiled assembly |
| **Custom converters** | ❌ No | Types not available |

**Fallback Strategy**:
```
1. Try Embedded Preview (XamlReader.Load)
   ↓ (if XamlParseException)
2. Show Code View with syntax highlighting
   ↓ (user can request)
3. Full Launch (Mode 3) - always works (100% accurate)
```

**Recommendation**: Use Embedded Preview for **quick layout checks** only. For full testing, use **Full Launch** (Mode 3).

---

## Implementation Strategy

### Phase 1: Embedded XAML Preview (MVP)
1. Implement `XamlRenderService`
2. Create `PreviewPanel` with Tab 1 only
3. Handle XAML parsing errors gracefully
4. Add loading states and error messages

### Phase 2: Code View
1. Implement syntax highlighting service
2. Add file tree navigation
3. Support multiple file types (C#, XAML, JSON)
4. Add search and filter capabilities

### Phase 3: Full Launch
1. Integrate with `BuildService`
2. Add build progress tracking
3. Implement process lifecycle management
4. Handle build errors and display diagnostics

---

## Error Handling

### XAML Parsing Errors
```csharp
try
{
    var element = XamlReader.Load(xamlContent);
}
catch (XamlParseException ex)
{
    // Show user-friendly error with line number
    ShowError($"XAML Error at line {ex.LineNumber}: {ex.Message}");
}
```

### Build Errors
```csharp
var buildResult = await _buildService.BuildAsync(projectPath);

if (!buildResult.Success)
{
    // Display build errors in InfoBar
    var errorSummary = string.Join("\n", 
        buildResult.Errors.Take(3).Select(e => e.Message));
    
    ShowError($"Build failed:\n{errorSummary}");
}
```

### Process Launch Errors
```csharp
try
{
    Process.Start(exePath);
}
catch (Win32Exception ex)
{
    ShowError($"Failed to launch app: {ex.Message}");
}
```

---

## Performance Considerations

### XAML Preview Optimization
- **Debounce**: Wait 500ms after last code change before re-rendering
- **Caching**: Cache parsed XAML trees for unchanged content
- **Async Rendering**: Use background thread for XAML parsing

### Code View Optimization
- **Lazy Loading**: Load file content on-demand when selected
- **Virtual Scrolling**: Use virtualization for large files
- **Syntax Highlighting**: Use incremental highlighting for large files

### Full Launch Optimization
- **Incremental Build**: Only rebuild changed files
- **Build Caching**: Reuse previous build artifacts when possible
- **Process Pooling**: Keep process alive for faster subsequent launches

---

## Security Considerations

### XAML Injection Prevention
```csharp
// Sanitize XAML before rendering
public string SanitizeXaml(string xaml)
{
    // Remove potentially dangerous elements
    var dangerous = new[] { "WebView", "Process", "FileIO" };
    
    foreach (var tag in dangerous)
    {
        if (xaml.Contains($"<{tag}"))
        {
            throw new SecurityException($"Unsafe element detected: {tag}");
        }
    }
    
    return xaml;
}
```

### Process Isolation
- Run generated apps in **sandboxed environment**
- Limit file system access to project directory
- Monitor resource usage (CPU, memory)
- Auto-terminate after timeout (5 minutes)

---

## User Experience Guidelines

### Loading States
- Show spinner during XAML parsing
- Display progress bar during build
- Indicate when app is running

### Error Messages
- Clear, actionable error descriptions
- Include line numbers for XAML/code errors
- Suggest fixes when possible

### Transitions
- Smooth tab switching animations
- Fade in/out for preview updates
- Slide animations for panel expansion

---

## Testing Strategy

### Unit Tests
```csharp
[TestClass]
public class PreviewServiceTests
{
    [TestMethod]
    public async Task RenderXamlPreview_ValidXaml_ReturnsUIElement()
    {
        var xaml = "<Button Content=\"Test\" />";
        var result = await _previewService.RenderXamlPreviewAsync(xaml);
        
        Assert.IsNotNull(result);
        Assert.IsInstanceOfType(result, typeof(Button));
    }
    
    [TestMethod]
    public async Task LaunchFullPreview_ValidProject_StartsProcess()
    {
        var process = await _previewService.LaunchFullPreviewAsync(testProjectPath);
        
        Assert.IsNotNull(process);
        Assert.IsFalse(process.HasExited);
    }
}
```

### Integration Tests
- Test full workflow: Generate → Preview → Launch
- Verify error handling for invalid XAML
- Test build failure scenarios
- Validate process cleanup on app exit

---

## Future Enhancements

### Hot Reload
- Detect code changes and auto-refresh preview
- Update running app without full rebuild
- Preserve app state during reload

### Interactive Preview
- Allow clicking/interacting with embedded preview
- Capture events and show in debug panel
- Enable property inspection

### Multi-Window Preview
- Preview multiple pages simultaneously
- Side-by-side comparison of versions
- Responsive design testing (different window sizes)

---

## References

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture overview
- [EXECUTION_ARCHITECTURE.md](EXECUTION_ARCHITECTURE.md) - Build and execution subsystems
- [USER_WORKFLOW.md](USER_WORKFLOW.md) - User interaction patterns
- [DESIGN_PHILOSOPHY.md](DESIGN_PHILOSOPHY.md) - UX principles
