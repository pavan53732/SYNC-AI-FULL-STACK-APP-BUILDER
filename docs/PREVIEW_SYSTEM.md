# Preview System Specification - Hybrid Approach

## Overview

The Preview System provides **three modes** for users to visualize generated WinUI 3 applications:

1. **Embedded XAML Preview** - Real-time rendering inside the builder
2. **Code View** - Syntax-highlighted source code inspection
3. **Full Launch** - Compiled application execution in separate window

> **Crucial Distinction**: Unlike web-based prototyping tools, the "Full Launch" renders a **real, compiled .NET 8 binary** running natively on Windows. It is not a simulation; it is the actual production application.

---

## 1.2 PREVIEW PIPELINE (MANDATORY ORDER)

> **Invariant**: This sequence is strict. No step may be skipped or reordered.

> **Capability Inference Timing**: This preview pipeline follows the Reactive model defined in AI_RUNTIME_MODEL.md §1.1 (canonical).

### Preview Pipeline (Debug Configuration)

1. **Pre-Build Capability Scan (Fast Check)**: Quick Roslyn scan for obvious capability-requiring namespaces. If found and missing from manifest → Inject immediately.
2. **Build (Debug)**: Generate binaries.
3. **Asset Generation Check** (NEW):
   - Check if all required assets exist (icons, logos, splash screen)
   - If missing → Run **Asset Generation Pipeline** (see [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md))
   - Generate: app icons, tile logos, splash screen, store logo
   - **User sees**: "Generating visual assets..."
4. **Roslyn Reindex**: Update semantic model.
5. **Build Failure Check**: If build failed with capability-related error:
   - Run full **Capability Inference** scan
   - **Inject** missing capabilities to manifest
   - **Rebuild** (continuous retry until success or user cancellation)
6. **Manifest Evaluation (Post-Build)**:
   - If manifest changed during build → **Inject** → **Rebuild** (Resource Injection).
   - If no change → Proceed.
7. **Launch**: Execute in isolated environment.

> **Asset Generation Reference**: See [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) for the zero-template asset generation pipeline.
>
> **Branding Reference**: See [BRANDING_INFERENCE_HEURISTICS.md](./BRANDING_INFERENCE_HEURISTICS.md) for how brand identity is derived from user intent.

> **Key Difference from Packaging**: Preview allows "build → detect → fix → rebuild" cycle because iteration speed matters more than perfection. Packaging MUST run inference before build because installers cannot be partially fixed.

### Packaging Pipeline (Release Configuration)

As defined in SYSTEM_ARCHITECTURE.md:

1. **CAPABILITY_SCAN** (MANDATORY first step)
2. MANIFEST_UPDATE
3. VERSION_SYNC
4. BUILD_RELEASE
5. PACKAGE_CREATE
6. SIGN
7. VERIFY

> **INVARIANT**: For Packaging, capability inference MUST run BEFORE build. Missing capabilities cause build failures that require retry.

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
    // Isolation Policy (aligned with WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md §8):
    // FAIL-CLOSED: Block execution when proper isolation cannot be established
    // - For capability-requiring apps: MUST have Windows Sandbox or AppContainer
    // - For read-only preview: Allow degraded mode with hard capability restrictions
    public async Task<Process> LaunchFullPreviewAsync(string projectPath)
    {
        var capabilities = await DetectCapabilitiesAsync(projectPath);
        var hasCapabilities = capabilities.Any();

        // SECURITY STEP 1: Verify isolation is available
        if (!IsWindowsSandboxAvailable() && !IsAppContainerAvailable())
        {
            if (hasCapabilities)
            {
                // FAIL-CLOSED: Block capability-requiring apps without isolation
                throw new IsolationException(
                    "Execution blocked: Windows Sandbox and AppContainer unavailable. " +
                    "Capability-requiring apps require isolation.");
            }
            
            // DEGRADED MODE: Allow read-only preview with restrictions
            _logger.LogWarning("Isolation unavailable. Running in degraded mode for read-only preview.");
            return await LaunchInDegradedModeAsync(projectPath);
        }

        // SECURITY STEP 2: Show consent dialog
        var consent = await ShowSecurityConsentDialogAsync();
        if (!consent)
        {
            _logger.LogInformation("User declined to launch generated application");
            return null;
        }

        // Step 3: Build the project
        var buildResult = await _buildService.BuildAsync(projectPath);
        if (!buildResult.Success) throw new BuildException("Build failed", buildResult.Errors);

        // Step 4: Prepare for Preview Launch (NOT full MSIX packaging)
        // Preview Launch → Signed EXE in isolated sandbox (fast, lightweight)
        // Installer Generation → Full MSIX pipeline (separate workflow)
        await _packagingService.PreparePreviewExecutableAsync(projectPath);

        // Step 5: Get executable path (or packaged entry point)
        // DYNAMIC RESOLUTION: Do not hardcode "bin/Debug". Use MSBuild properties or Project Context.
        var exePath = _buildService.ResolveOutputAssemblyPath(projectPath, buildResult.Configuration);

        // Step 6: Launch process in Windows Sandbox
        await LaunchInSandboxAsync(exePath);

        _logger.LogInformation("Launched generated application in Sandbox: {ExePath}", exePath);
        return null;
    }

    /// <summary>
    /// Shows security consent dialog before launching AI-generated code.
    /// NOTE: This is a Runtime Boundary Safeguard, not an error state.
    /// It ensures the user explicitly authorizes code execution outside the builder.
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

| Feature             | Embedded Preview | Code View   | Full Launch           |
| ------------------- | ---------------- | ----------- | --------------------- |
| **Speed**           | Instant          | Fast        | Slow (requires build) |
| **Accuracy**        | High (XAML only) | N/A         | 100% (actual app)     |
| **Interactivity**   | Limited          | None        | Full                  |
| **Use Case**        | Quick UI checks  | Code review | Final testing         |
| **Build Required**  | No               | No          | Yes                   |
| **Separate Window** | No               | No          | Yes                   |

---

## Framework-Specific Preview Strategies

> **CRITICAL**: Different frameworks require different preview approaches. This system MUST adapt preview mode based on `targetPlatform.frameworkFamily`.

### Managed Frameworks (.NET)

| Framework | Embedded Preview | Code View | Full Launch | Notes |
|-----------|-----------------|-----------|-------------|-------|
| **WinUI 3** | ✅ XAML via `XamlReader.Load()` | ✅ C#/XAML | ✅ `Process.Start(exePath)` | Full support for all three modes |
| **WPF** | ⚠️ Limited (requires WPF-specific parser) | ✅ C#/XAML | ✅ `Process.Start(exePath)` | Use `System.Windows.Markup.XamlReader` for WPF XAML preview |
| **WinForms** | ❌ Not supported | ✅ C#/Designer.cs | ✅ `Process.Start(exePath)` | WinForms uses imperative code, not XAML; Code View + Full Launch only |
| **Console** | ❌ Not applicable | ✅ C# | ✅ `Process.Start(exePath)` with stdout capture | Capture stdout/stderr for text-based preview |

### Native Frameworks (C++)

| Framework | Embedded Preview | Code View | Full Launch | Notes |
|-----------|-----------------|-----------|-------------|-------|
| **Win32** | ❌ Not supported | ✅ C++/H | ✅ `Process.Start(exePath)` | No declarative UI; requires full compilation and execution |
| **WinRT** | ⚠️ XAML subset (same as WinUI 3) | ✅ C++/H | ✅ `Process.Start(exePath)` | C++/WinRT XAML can use same `XamlReader.Load()` |
| **Hybrid** | ⚠️ XAML only (managed part) | ✅ C#/C++ | ✅ `Process.Start(exePath)` | Preview managed XAML; full launch required for interop testing |

### Preview Mode Selection Logic

```csharp
public enum PreviewModeAvailability
{
    FullySupported,
    PartiallySupported,
    NotSupported
}

public class PreviewStrategyFactory
{
    public IPreviewStrategy GetStrategy(FrameworkFamily framework)
    {
        return framework switch
        {
            FrameworkFamily.WinUI3 => new XamlPreviewStrategy(),
            FrameworkFamily.WPF => new WpfXamlPreviewStrategy(),
            FrameworkFamily.WinForms => new CodeOnlyPreviewStrategy(),
            FrameworkFamily.Console => new ConsoleOutputPreviewStrategy(),
            FrameworkFamily.Win32 => new CodeOnlyPreviewStrategy(),
            FrameworkFamily.WinRT => new XamlPreviewStrategy(),
            FrameworkFamily.Hybrid => new HybridPreviewStrategy(),
            _ => throw new ArgumentOutOfRangeException(nameof(framework), framework, null)
        };
    }
}
```

### Implementation Notes by Framework

#### WinUI 3 / WPF / WinRT (XAML-based)

```text
Embedded Preview Flow:
1. Extract XAML content from generated .xaml files
2. Parse with framework-specific XamlReader:
   - WinUI 3: Windows.UI.Xaml.Markup.XamlReader
   - WPF: System.Windows.Markup.XamlReader
   - WinRT: Windows.UI.Xaml.Markup.XamlReader
3. Render resulting UIElement in preview container
4. Limitations:
   - No code-behind execution
   - No ViewModel data binding
   - No custom controls requiring compilation
```

#### WinForms

```text
Code View Only Flow:
1. Display .cs files with syntax highlighting
2. Show Designer.cs files side-by-side
3. Highlight event handler wiring
4. Full Launch required to see actual UI
```

#### Console

```text
Stdout Capture Flow:
1. Build console application
2. Start process with redirected stdout/stderr
3. Capture text output in real-time
4. Display in terminal-like control within builder
5. Support interactive input if app reads stdin
```

#### Win32 / Native C++

```text
Full Launch Required:
1. No embedded preview possible (imperative Win32 API calls)
2. Code View shows C++ source with syntax highlighting
3. Full Launch compiles and runs native executable
4. Monitor process for exit codes and crashes
```

#### Hybrid (C# + C++ Interop)

```text
Multi-Stage Preview:
1. Embedded XAML preview for managed UI parts
2. Code View for both C# and C++ sources
3. Full Launch required for interop testing
4. Special handling for P/Invoke and COM interop
```

### Fallback Strategy Matrix

| Primary Mode | If Fails → | Final Fallback |
|--------------|-----------|----------------|
| **Embedded XAML** (WinUI/WPF/WinRT) | Code View with error highlight | Full Launch |
| **Code View** (all frameworks) | N/A (always works) | Full Launch |
| **Full Launch** | Show build errors + diagnostics | N/A (user must fix errors) |

> **INVARIANT**: The preview system MUST clearly indicate which modes are available for the current framework and gracefully degrade to the next best available option.

### Embedded XAML Preview Limitations

> **IMPORTANT**: `XamlReader.Load()` can only parse **simple XAML** without compiled dependencies.

| XAML Feature                              | Supported  | Reason                            |
| ----------------------------------------- | ---------- | --------------------------------- |
| Basic layouts (Grid, StackPanel, etc.)    | ✅ Yes     | Built-in WinUI 3 controls         |
| Standard controls (Button, TextBox, etc.) | ✅ Yes     | Built-in WinUI 3 controls         |
| Static resources (colors, styles)         | ✅ Yes     | Can be parsed from XAML           |
| Simple data binding (`{Binding}`)         | ⚠️ Partial | Works if DataContext set manually |
| **Custom controls**                       | ❌ No      | Types not available at runtime    |
| **Code-behind event handlers**            | ❌ No      | Requires compilation              |
| **x:Bind (compiled bindings)**            | ❌ No      | Compile-time only                 |
| **ViewModels**                            | ❌ No      | Requires compiled assembly        |
| **Custom converters**                     | ❌ No      | Types not available               |

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

### Embedded XAML Preview (MVP)

1. Implement `XamlRenderService`
2. Create `PreviewPanel` with Tab 1 only
3. Handle XAML parsing errors gracefully
4. Add loading states and error messages

### Code View

1. Implement syntax highlighting service
2. Add file tree navigation
3. Support multiple file types (C#, XAML, JSON)
4. Add search and filter capabilities

### Full Launch

1. Integrate with `BuildService`
2. **Integrate properties from `PackagingService` (Manifests, Signing)**
3. Add build progress tracking
4. Implement process lifecycle management
5. Handle build errors and display diagnostics

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

### AI Service Failure Handling

> **INVARIANT**: The Preview system MUST handle AI service failures gracefully to ensure users can still test their applications.

#### Failure Classification for Preview

| Severity Level  | Condition                                         | Preview Behavior                                    |
| --------------- | ------------------------------------------------- | --------------------------------------------------- |
| **DEGRADED**    | 3+ consecutive health failures or 10+ rate limits | Continue with backoff; show yellow status indicator |
| **UNAVAILABLE** | Health check timeout or service not running       | Block asset generation only; allow code preview     |

#### Asset Failure Handling Rules

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ASSET GENERATION IN PREVIEW                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ 1. If asset generation is in progress:                              │
│    ├── Retry with exponential backoff (2s, 4s, 8s)                │
│    ├── Max 3 retries                                               │
│    └── If all fail: Use fallback asset → Continue                  │
│                                                                      │
│ 2. If optional assets missing (e.g., StoreLogo):                   │
│    ├── Do NOT block preview                                         │
│    ├── Show informational message                                   │
│    └── Continue with available assets                               │
│                                                                      │
│ 3. If mandatory assets missing (e.g., Square44x44Logo):           │
│    ├── Block preview until resolved                                 │
│    ├── Show error with "Generate Assets" action button              │
│    └── User can retry or use fallbacks                             │
│                                                                      │
│ 4. If AI service is completely unavailable:                        │
│    ├── Disable asset generation UI                                  │
│    ├── Allow code-only preview                                      │
│    └── Show "AI Service unavailable" banner                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

#### Fallback Asset Strategy for Preview

```csharp
public class PreviewAssetService
{
    /// <summary>
    /// Gets asset for preview, falling back to defaults if AI generation fails.
    /// </summary>
    public async Task<PreviewAsset> GetAssetForPreviewAsync(string assetId)
    {
        try
        {
            // Try AI-generated asset first
            var asset = await _assetGenerator.GenerateAsync(assetId);
            return new PreviewAsset { Data = asset, IsFallback = false };
        }
        catch (AssetGenerationException ex)
        {
            // Log error but don't block preview
            _logger.LogWarning("Asset generation failed for {AssetId}: {Error}", assetId, ex.Message);

            // Return fallback
            return new PreviewAsset
            {
                Data = AssetFallbacks.GetFallback(assetId),
                IsFallback = true
            };
        }
    }
}
```

#### User Notification Strategy

| Scenario               | Notification Type     | Action Required                       |
| ---------------------- | --------------------- | ------------------------------------- |
| Optional asset failed  | Info bar (subtle)     | None - continues silently             |
| Mandatory asset failed | Error bar with action | User clicks "Use Fallback" or "Retry" |
| AI service degraded    | Warning banner        | None - continues with backoff         |
| AI service unavailable | Error banner          | User can still preview code           |

The preview should remain functional even if AI service has issues, as long as the core build artifacts are available.

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

> **INVARIANT**: XAML sanitization MUST use XML parsing, not string matching. String-based detection is prone to bypasses (e.g., XML encoding, whitespace manipulation).

```csharp
// Sanitize XAML before rendering using XML parsing
public string SanitizeXaml(string xaml)
{
    // Define dangerous element types that should not be rendered in preview
    var dangerousElements = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "WebView",
        "WebView2",
        "Process",
        "FileOpenPicker",
        "FileSavePicker",
        "FolderPicker"
    };

    // Define dangerous attribute patterns
    var dangerousAttributes = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "DataContext"  // Prevent ViewModel injection
    };

    try
    {
        var doc = XDocument.Parse(xaml);
        
        // Check for dangerous elements
        foreach (var element in doc.Descendants())
        {
            if (dangerousElements.Contains(element.Name.LocalName))
            {
                throw new SecurityException($"Unsafe element detected: {element.Name.LocalName}");
            }
            
            // Check for dangerous attributes
            foreach (var attr in element.Attributes())
            {
                if (dangerousAttributes.Contains(attr.Name.LocalName))
                {
                    throw new SecurityException($"Unsafe attribute detected: {attr.Name.LocalName}");
                }
            }
        }

        return doc.ToString();
    }
    catch (XmlException ex)
    {
        throw new SecurityException($"Invalid XAML: {ex.Message}");
    }
}
```

> **Why XML Parsing Is Required**: 
> - String matching (`xaml.Contains("<WebView")`) can be bypassed with encoding (`<x:WebView/>`) or whitespace
> - XML parsing interprets XAML as a structured document, catching all variations
> - The sanitized output is the parsed-and-reserialized XAML, ensuring well-formedness

### Process Isolation

- Run generated apps in **sandboxed environment**
- Limit file system access to project directory
- Monitor resource usage (CPU, memory)
- User-controlled termination - user can stop the app at any time
- Graceful shutdown when the builder closes

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

- [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md) — 8-layer architecture overview and layer boundaries
- [AI_RUNTIME_MODEL.md](AI_RUNTIME_MODEL.md) — AI Construction Engine / Runtime Safety Kernel relationship
- [USER_WORKFLOWS.md](USER_WORKFLOWS.md) — Features and user interaction patterns
- [UI_IMPLEMENTATION.md](UI_IMPLEMENTATION.md) — UX principles
- [WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md](WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md) — Packaging subsystem details
- [EXECUTION_ENVIRONMENT.md](EXECUTION_ENVIRONMENT.md) — Build sandbox, MSBuild, workspace isolation
- [TOOLCHAIN_MANIFEST.md](TOOLCHAIN_MANIFEST.md) — Layer 5: bundled tool versions and paths
- [TOOLCHAIN_ISOLATION.md](TOOLCHAIN_ISOLATION.md) — Layer 5: build process isolation contract
- [STRUCTURED_SPEC_FORMAT.md](STRUCTURED_SPEC_FORMAT.md) — Canonical JSON schema for app specifications
- [REPAIR_PATTERNS.md](REPAIR_PATTERNS.md) — Deterministic repair strategies for build failures
- [AI_SERVICE_LAYER.md](AI_SERVICE_LAYER.md) — AI capabilities via user-configured providers
- [AI_MINI_SERVICE_IMPLEMENTATION.md](AI_MINI_SERVICE_IMPLEMENTATION.md) — Complete TypeScript implementation
- [PLATFORM_REQUIREMENTS_ENGINE.md](PLATFORM_REQUIREMENTS_ENGINE.md) — Zero-template asset generation pipeline
- [BRANDING_INFERENCE_HEURISTICS.md](BRANDING_INFERENCE_HEURISTICS.md) — Intelligent brand derivation

---

## Change Log

| Date       | Change                                                                                   |
| ---------- | ---------------------------------------------------------------------------------------- |
| 2026-02-23 | Added Asset Generation Check step (step 3) to Preview Pipeline                           |
| 2026-02-23 | Added PLATFORM_REQUIREMENTS_ENGINE.md and BRANDING_INFERENCE_HEURISTICS.md to References |
