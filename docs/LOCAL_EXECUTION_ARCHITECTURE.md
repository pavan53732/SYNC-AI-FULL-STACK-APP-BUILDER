# Local Execution Architecture

**Status**: Local-only Windows desktop deployment (WinUI 3 confirmed)  
**Scope**: All execution on user's PC (no cloud services)  
**UI Framework**: WinUI 3 (Windows App SDK, .NET 8, MSIX deployment)  

---

## Core Architecture Shift: Local-Only Model

### Previous Assumption (Cloud-Based)
Similar to Lovable, Budibase, or other web builders:
- UI in browser or web app
- Execution in cloud container
- Build infrastructure centralized
- Infra complexity hidden

### New Reality (Local-Only Model with WinUI 3)
All execution on user's PC:
- WinUI 3 desktop application (modern Windows UI)
- All build operations local (MSBuild, .NET SDK embedded)
- User controls infrastructure
- Complexity is visible and managed by orchestrator

---

## Two-Layer Architecture (Single WinUI 3 App)

```
┌─────────────────────────────────────────┐
│          WinUI 3 Builder UI             │
│      (Fluent Design System)             │
├──────────────────────────────┬──────────┤
│ Prompt Console               │          │
│ Real-time Progress Monitor   │ Thin     │
│ Project File Explorer        │ XAML UI  │
│ Build Output Viewer          │          │
│ Code Preview                 │          │
└──────────────────────────────┴──────────┘
                   ↓ (Direct C# Call)
┌─────────────────────────────────────────┐
│       Orchestrator Engine               │
│   (Deterministic State Machine)         │
├─────────────────────────────────────────┤
│ • Task Graph Management                 │
│ • State Machine (10 states)             │
│ • Retry Control (strict budget)         │
│ • Event Log (replayable)                │
│ • Error Classification                  │
└────────────────┬────────────────────────┘
                 │
         ┌───────┼────────┐
         │       │        │
    ┌────▼───┐ ┌─▼────┐ ┌▼──────────┐
    │ Roslyn │ │Patch │ │Execution  │
    │Indexer │ │Engine│ │ Kernel    │
    ├────────┤ ├──────┤ ├───────────┤
    │ AST    │ │ Tx   │ │MSBuild    │
    │Symbol  │ │Write │ │NuGet      │
    │Graph   │ │Conflict
    │        │ │ Check │ │Sandbox    │
    └────┬───┘ └──┬───┘ └─┬────────┘
         │        │       │
         └────────┼───────┘
                  │
         ┌────────▼────────┐
         │ File Sandbox    │
         │ (Snapshots,     │
         │  Rollback,      │
         │  Versioning)    │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │ SQLite DB       │
         │ (Graph +        │
         │  Memory)        │
         └─────────────────┘

Run entirely on user's PC. Zero cloud.
```

---

## Critical Difference: Local vs. Cloud

| Factor | Cloud Model (Lovable) | Local-Only (Your Builder) |
|--------|----------------------|-------------------------|
| **Execution Location** | Cloud container | User's PC |
| **Infrastructure** | Fixed, managed | Variable, on user machine |
| **Isolation** | Container-level | Filesystem + process-level |
| **SDK Version** | Fixed in container | User's installed version |
| **Error Handling** | Retry in cloud | Must retry locally |
| **Resource Limits** | Infinite (cloud scale) | Limited (PC RAM, disk) |
| **Logging** | Centralized | Local persistence |
| **Antivirus** | Managed | User's settings apply |
| **Disk Requirements** | Server managed | User's available space |
| **Network** | Internal to datacenter | User's connection (if using cloud LLM) |
| **Code Execution** | Trusted (we control) | Untrusted (user generated) |
| **Determinism** | Can hide infra issues | Must handle all variability |

**Impact**: Local-only is fundamentally harder because you cannot hide machine variability.

---

## 1️⃣ Filesystem Sandbox (Local-Only Requirements)

### Directory Structure

```
C:\YourBuilder\Workspaces\
├── {ProjectId_001}/
│   ├── src/                          (User's generated code)
│   │   ├── SyncAIAppBuilder.csproj
│   │   ├── Program.cs
│   │   └── ... (all generated files)
│   │
│   ├── .builder/                      (Internal, hidden from user)
│   │   ├── snapshots/
│   │   │   ├── snapshot_0001.zip
│   │   │   ├── snapshot_0002.zip
│   │   │   └── ... (after each successful task)
│   │   │
│   │   ├── diffs/
│   │   │   ├── diff_0001_0002.patch
│   │   │   └── ... (incremental changes)
│   │   │
│   │   ├── build_temp/                (Cleaned after each build)
│   │   │   ├── bin/
│   │   │   ├── obj/
│   │   │   └── ... (temporary artifacts)
│   │   │
│   │   ├── project_graph.db           (SQLite, indexed symbols)
│   │   ├── build_log.json             (Full build output)
│   │   └── state.json                 (Last known good state)
│   │
│   └── .metadata.json
│
├── {ProjectId_002}/
│   └── ... (same structure)
│
└── Cache/
    ├── roslyn_symbols_cache/
    ├── embedding_cache/
    └── nuget_packages_*.cache
```

### Snapshot Strategy

**When to Snapshot:**
- Before ANY mutation task
- After successful build validation
- At user checkpoints (save)
- Before each agent generation

**Why Snapshots Matter (Local):**
- User's machine is fragile (limited resources)
- One bad generation cannot corrupt project
- Can instantly rollback to known good
- Non-destructive workflow

**Implementation:**

```csharp
public class FilesystemSandbox
{
    private readonly string _workspacePath;
    private readonly string _snapshotDir;
    
    /// Create snapshot BEFORE mutation
    public async Task<Snapshot> CreateSnapshotAsync(string description)
    {
        var snapshotId = Guid.NewGuid().ToString("N").Substring(0, 8);
        var timestamp = DateTime.UtcNow;
        var snapshotPath = Path.Combine(_snapshotDir, $"snapshot_{timestamp:yyyyMMdd_HHmmss}.zip");
        
        // ZIP only src/ directory (not build artifacts)
        await Task.Run(() =>
        {
            ZipFile.CreateFromDirectory(
                Path.Combine(_workspacePath, "src"),
                snapshotPath,
                CompressionLevel.Optimal,
                includeBaseDirectory: false);
        });
        
        return new Snapshot
        {
            Id = snapshotId,
            Path = snapshotPath,
            CreatedAt = timestamp,
            Description = description,
            SizeBytes = new FileInfo(snapshotPath).Length
        };
    }
    
    /// Restore from snapshot
    public async Task RestoreSnapshotAsync(Snapshot snapshot)
    {
        var srcPath = Path.Combine(_workspacePath, "src");
        
        // Delete current source
        if (Directory.Exists(srcPath))
        {
            Directory.Delete(srcPath, recursive: true);
        }
        
        // Extract snapshot
        await Task.Run(() =>
        {
            ZipFile.ExtractToDirectory(snapshot.Path, srcPath);
        });
        
        // Invalidate build artifacts
        var buildTemp = Path.Combine(_workspacePath, ".builder", "build_temp");
        if (Directory.Exists(buildTemp))
        {
            Directory.Delete(buildTemp, recursive: true);
        }
    }
    
    /// Get list of available snapshots
    public List<Snapshot> ListSnapshots()
    {
        return Directory.GetFiles(_snapshotDir, "snapshot_*.zip")
            .OrderByDescending(f => f)
            .Take(10)  // Keep last 10 only
            .Select(path => new Snapshot
            {
                Path = path,
                CreatedAt = File.GetCreationTime(path),
                SizeBytes = new FileInfo(path).Length
            })
            .ToList();
    }
    
    /// Cleanup old snapshots (disk space management)
    public void CleanupOldSnapshots(int keepCount = 5)
    {
        var snapshots = ListSnapshots();
        var toDelete = snapshots.Skip(keepCount).ToList();
        
        foreach (var snapshot in toDelete)
        {
            File.Delete(snapshot.Path);
        }
    }
}
```

---

## 2️⃣ Internal Build Kernel (Local-Only Constraints)

### Challenge: User May Not Have .NET SDK

Your builder must handle:
- ✗ .NET SDK not installed
- ✗ Wrong version installed
- ✗ Missing workloads (WinUI, XAML)
- ✗ Broken NuGet cache
- ✗ Antivirus blocking dotnet.exe
- ✗ Low disk space
- ✗ Limited RAM

**Solution**: Detect and report clearly.

### Build Kernel Architecture

```csharp
public class ExecutionKernel
{
    private readonly string _projectPath;
    private readonly ILogger _logger;
    
    /// Pre-build validation (check machine state)
    public async Task<BuildValidation> ValidateBuildEnvironmentAsync()
    {
        var results = new BuildValidation();
        
        // Check .NET SDK
        var sdkCheck = await CheckDotNetSdkAsync();
        results.DotNetSdkFound = sdkCheck.Found;
        results.DotNetVersion = sdkCheck.Version;
        results.DotNetPath = sdkCheck.Path;
        
        if (!sdkCheck.Found)
        {
            results.Issues.Add(new BuildIssue
            {
                Severity = IssueSeverity.Fatal,
                Message = ".NET 8 SDK not found",
                Suggestion = "Download from https://dotnet.microsoft.com/download/dotnet/8.0",
                CanFix = false
            });
        }
        
        // Check disk space
        var diskSpace = GetAvailableDiskSpace(_projectPath);
        if (diskSpace < 2_000_000_000)  // 2GB min
        {
            results.Issues.Add(new BuildIssue
            {
                Severity = IssueSeverity.Warning,
                Message = $"Low disk space: {diskSpace / 1_000_000_000}GB available",
                Suggestion = "Free up disk space before building",
                CanFix = false
            });
        }
        
        // Check NuGet cache integrity
        var nugetStatus = await ValidateNuGetCacheAsync();
        if (!nugetStatus.Valid)
        {
            results.Issues.Add(new BuildIssue
            {
                Severity = IssueSeverity.Warning,
                Message = "NuGet cache may be corrupted",
                Suggestion = "Run 'nuget locals all -clear' or let builder repair",
                CanFix = true
            });
        }
        
        return results;
    }
    
    /// Run dotnet restore with timeout
    public async Task<ExecutionResult> RestorePackagesAsync(
        TimeSpan timeout = default,
        IProgress<string>? progress = null)
    {
        timeout = timeout == default ? TimeSpan.FromMinutes(5) : timeout;
        
        var result = await RunProcessWithTimeoutAsync(
            dotnetPath: await GetDotNetPathAsync(),
            arguments: "restore",
            workingDirectory: _projectPath,
            timeout: timeout,
            captureOutput: true,
            progress: progress);
        
        if (result.ExitCode != 0)
        {
            // Classify NuGet error
            var errorClassification = ClassifyNuGetError(result.StdErr);
            
            return new ExecutionResult
            {
                Success = false,
                ExitCode = result.ExitCode,
                StdOut = result.StdOut,
                StdErr = result.StdErr,
                ErrorType = errorClassification.Type,
                IsRetryable = errorClassification.IsRetryable,
                SuggestedFix = errorClassification.SuggestedFix
            };
        }
        
        return new ExecutionResult { Success = true };
    }
    
    /// Run dotnet build with timeout
    public async Task<ExecutionResult> BuildAsync(
        string configuration = "Release",
        TimeSpan timeout = default,
        IProgress<string>? progress = null,
        CancellationToken cancellationToken = default)
    {
        timeout = timeout == default ? TimeSpan.FromMinutes(10) : timeout;
        
        var result = await RunProcessWithTimeoutAsync(
            dotnetPath: await GetDotNetPathAsync(),
            arguments: $"build --configuration {configuration} /p:TreatWarningsAsErrors=false",
            workingDirectory: _projectPath,
            timeout: timeout,
            captureOutput: true,
            progress: progress,
            cancellationToken: cancellationToken);
        
        if (result.ExitCode != 0)
        {
            // Parse MSBuild errors
            var errors = ParseMSBuildErrors(result.StdErr);
            
            return new ExecutionResult
            {
                Success = false,
                ExitCode = result.ExitCode,
                Errors = errors,
                IsRetryable = errors.Any(e => e.IsRetryable),
                HasBuildArtifacts = false
            };
        }
        
        // Success - copy artifacts
        var outputDir = Path.Combine(_projectPath, "bin", configuration);
        
        return new ExecutionResult
        {
            Success = true,
            ExitCode = 0,
            ArtifactPath = outputDir,
            HasBuildArtifacts = Directory.Exists(outputDir),
            ArtifactSize = GetDirectorySize(outputDir)
        };
    }
    
    /// Critical: Run process with timeout + cancellation
    private async Task<ProcessOutput> RunProcessWithTimeoutAsync(
        string dotnetPath,
        string arguments,
        string workingDirectory,
        TimeSpan timeout,
        bool captureOutput,
        IProgress<string>? progress = null,
        CancellationToken cancellationToken = default)
    {
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = dotnetPath,
                Arguments = arguments,
                WorkingDirectory = workingDirectory,
                UseShellExecute = false,
                RedirectStandardOutput = captureOutput,
                RedirectStandardError = captureOutput,
                CreateNoWindow = true
            }
        };
        
        try
        {
            process.Start();
            
            // Listen to output in real-time (for progress UI)
            var outputTask = Task.CompletedTask;
            if (captureOutput)
            {
                outputTask = Task.Run(() =>
                {
                    string? line;
                    while ((line = process.StandardError.ReadLine()) != null)
                    {
                        progress?.Report(line);
                        _logger.LogInformation(line);
                    }
                });
            }
            
            // Wait with timeout
            var exitedInTime = process.WaitForExit((int)timeout.TotalMilliseconds);
            
            if (!exitedInTime)
            {
                process.Kill(entireProcessTree: true);
                return new ProcessOutput
                {
                    ExitCode = -1,
                    StdErr = $"Process exceeded timeout ({timeout.TotalSeconds}s)",
                    TimedOut = true
                };
            }
            
            // Check cancellation
            if (cancellationToken.IsCancellationRequested)
            {
                return new ProcessOutput
                {
                    ExitCode = -1,
                    StdErr = "Build cancelled by user",
                    Cancelled = true
                };
            }
            
            await outputTask;
            
            return new ProcessOutput
            {
                ExitCode = process.ExitCode,
                StdOut = captureOutput ? process.StandardOutput.ReadToEnd() : "",
                StdErr = captureOutput ? process.StandardError.ReadToEnd() : "",
                TimedOut = false
            };
        }
        finally
        {
            process.Dispose();
        }
    }
    
    private async Task<(bool Found, string? Version, string? Path)> CheckDotNetSdkAsync()
    {
        try
        {
            var result = await RunProcessWithTimeoutAsync(
                dotnetPath: "dotnet",
                arguments: "--version",
                workingDirectory: Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                timeout: TimeSpan.FromSeconds(5),
                captureOutput: true);
            
            if (result.ExitCode == 0)
            {
                var version = result.StdOut?.Trim();
                return (true, version, "dotnet");
            }
        }
        catch { }
        
        return (false, null, null);
    }
}
```

### Key Features
- **Pre-build validation** - check SDK, disk, NuGet before building
- **Timeout handling** - kill runaway builds
- **Cancellation support** - user can stop long builds
- **Real-time progress** - stream output to UI
- **Resource awareness** - handle low disk/memory gracefully
- **Error classification** - parse MSBuild errors strategically

---

## 2️⃣.5️⃣ Roslyn Service (Mandatory Code Intelligence)

### Why Roslyn Is Mandatory (Response 7 Validation)

Never use raw text mutation for code changes. Must have AST-based manipulation through Roslyn.

**Required Capabilities**:
1. C# AST parsing (syntax tree)
2. Symbol graph building (types, methods, properties, fields)
3. Safe refactoring (semantic analysis before mutation)
4. XAML + C# binding validation
5. File impact analysis (what changes affect what)

### Architecture

Runs as **separate service class** (not embedded in UI or orchestrator):

```csharp
public interface IRoslynService
{
    /// Parse project and build symbol graph
    Task<ProjectSymbolGraph> IndexProjectAsync(string projectPath);
    
    /// Analyze file dependencies
    Task<FileDependencyAnalysis> AnalyzeDependenciesAsync(string filePath);
    
    /// Safe refactoring: class rename with validation
    Task<RefactoringResult> RenameClassAsync(
        string className, 
        string newClassName,
        CancellationToken cancellation = default);
    
    /// Get semantic information (for code generation)
    Task<SemanticModel> GetSemanticModelAsync(string filePath);
}

public class RoslynService : IRoslynService
{
    private MSBuildWorkspace _workspace;
    private Dictionary<string, ProjectSymbolGraph> _cache;
    
    public async Task<ProjectSymbolGraph> IndexProjectAsync(string projectPath)
    {
        // 1. Load .NET project via MSBuildWorkspace
        var project = await _workspace.OpenProjectAsync(projectPath);
        
        // 2. Compile to get symbols
        var compilation = await project.GetCompilationAsync();
        
        // 3. Walk symbol tree
        var graph = new ProjectSymbolGraph();
        WalkSymbols(compilation.GlobalNamespace, graph);
        
        // 4. Cache for fast access
        _cache[projectPath] = graph;
        return graph;
    }
    
    private void WalkSymbols(INamespaceSymbol ns, ProjectSymbolGraph graph)
    {
        foreach (var symbol in ns.GetMembers())
        {
            if (symbol is INamedTypeSymbol typeSymbol)
            {
                // Record all types (classes, interfaces, records, etc.)
                graph.Types.Add(new TypeInfo
                {
                    Name = typeSymbol.Name,
                    FullName = typeSymbol.ToDisplayString(),
                    Kind = typeSymbol.Kind,
                    Methods = typeSymbol.GetMembers()
                        .OfType<IMethodSymbol>()
                        .Select(m => new MethodInfo { Name = m.Name })
                        .ToList(),
                    Properties = typeSymbol.GetMembers()
                        .OfType<IPropertySymbol>()
                        .Select(p => new PropertyInfo { Name = p.Name })
                        .ToList()
                });
            }
            else if (symbol is INamespaceSymbol nestedNs)
            {
                WalkSymbols(nestedNs, graph);
            }
        }
    }
}
```

### Allocation (Local-Only Model)

**Option A**: Single shared instance (recommended)
- One Roslyn service for entire builder app
- Caches compiled symbols
- Thread-safe (uses lock or async queue)

**Option B**: Per-project instance
- Separate Roslyn service per project
- Higher memory usage
- Better isolation (if one crashes, others continue)

**Option C**: Background worker thread
- Dedicated thread pool for Roslyn operations
- UI thread never blocked
- Queue-based task dispatch

**Recommended**: Option A with async queue dispatch.

### Key Constraint

**Never call Roslyn synchronously** on UI thread:

```csharp
// BAD: Freezes UI
var graph = _roslynService.IndexProject(path); // Blocks!

// GOOD: Async, doesn't block
var graph = await _roslynService.IndexProjectAsync(path);

// GOOD: Background dispatch
_dispatcher.Dispatch(() => 
{
    _ = _roslynService.IndexProjectAsync(path); // Fire and forget
});
```

---

## 3️⃣ Security & Isolation (Executing Untrusted Code)

### Challenge: Generated Code Is Untrusted

Your builder generates code that runs on the user's PC. You must prevent:

❌ **Arbitrary Shell Execution**
```csharp
// BAD: Never allow this
Process.Start("cmd.exe", "/c whatever");
```

✅ **Whitelisted Operations**
```csharp
// GOOD: Only controlled builds
await kernel.BuildAsync();
await kernel.RunProjectAsync();
```

❌ **Registry Writes**
```csharp
// BAD: Don't allow registry manipulation
RegistryKey.SetValue(...);
```

✅ **Isolated File Access**
```csharp
// GOOD: Only project directory
var srcPath = workspacePath + "/src/";
```

❌ **Elevated Privileges**
```csharp
// BAD: Don't run as admin
ProcessStartInfo.UseShellExecute = true;
```

✅ **Standard User Context**
```csharp
// GOOD: User's normal permissions
ProcessStartInfo.UseShellExecute = false;
```

### Implementation

```csharp
public class SecurityBoundary
{
    private readonly string _projectRootPath;
    
    /// Validate path is within project (prevent directory traversal)
    public bool IsPathAllowed(string filePath)
    {
        var fullPath = Path.GetFullPath(filePath);
        var rootPath = Path.GetFullPath(_projectRootPath);
        
        // Must be within project directory
        return fullPath.StartsWith(rootPath, StringComparison.OrdinalIgnoreCase)
            && !fullPath.Contains("..");  // No directory traversal
    }
    
    /// Generated code execution must be sandboxed
    public async Task<AppDomain> CreateSandboxedDomainAsync()
    {
        // For .NET Framework only (not .NET Core)
        // .NET Core has different isolation model
        
        // For .NET 8+ (your case):
        // Use ProcessStartInfo with limited permissions
        
        return null;  // Not applicable in .NET Core
    }
    
    /// Only allow these dotnet commands
    private static readonly HashSet<string> AllowedCommands = new()
    {
        "restore",
        "build",
        "run",
        "publish",
        "test",
        "clean"
    };
    
    public bool IsCommandAllowed(string command)
    {
        return AllowedCommands.Contains(command);
    }
}
```

### Response 7: Explicit Security Constraints

From Response 7 developer guidance - **strict prohibitions**:

#### ❌ NO Arbitrary Shell Execution
```csharp
// FORBIDDEN: Cmd.exe, PowerShell.exe
Process.Start("cmd.exe", "/c " + userInput);
Process.Start("powershell.exe", "-Command " + userInput);
```

#### ❌ NO Elevated Privileges
```csharp
// FORBIDDEN: Running as admin
var info = new ProcessStartInfo { UseShellExecute = true, Verb = "runas" };
```

#### ❌ NO Registry Writes
```csharp
// FORBIDDEN: Modifying Windows registry
RegistryKey.SetValue("HKEY_LOCAL_MACHINE\\Software\\...", value);
```

#### ❌ NO Unsafe File Traversal
```csharp
// FORBIDDEN: Accessing outside project
var path = "/../../sensitive_file.txt";
new FileInfo(path).Open(FileMode.Read);
```

#### ✅ Whitelist-Only Command Execution
```csharp
private static readonly HashSet<string> AllowedCommands = new()
{
    "dotnet restore",
    "dotnet build",
    "dotnet run",
    "dotnet publish",
    "dotnet test",
    "dotnet clean"
};

/// Validate before execution
public bool CanExecute(string command)
{
    return AllowedCommands.Any(allowed => 
        command.StartsWith(allowed, StringComparison.OrdinalIgnoreCase));
}
```

---

## 4️⃣ Machine Variability Handling

### What Your Builder Must Handle

| Issue | Solution |
|-------|----------|
| .NET SDK not installed | Show download link, fail gracefully |
| Wrong .NET version | Check version, suggest upgrade |
| Missing XAML workload | Provide install instructions |
| Low disk space | Check before build, warn user |
| Antivirus blocking dotnet | Suggest whitelist, fallback to safe mode |
| Broken NuGet cache | Clear cache, retry restore |
| Limited RAM | Use incremental builds, limit parallelism |
| Slow disk | Use smaller snapshots, avoid full ZIP |
| Power loss during build | Snapshot before = safe recovery |

### Error Handling Architecture

```csharp
public class MachineVariabilityHandler
{
    /// Detect and handle common local issues
    public async Task<BuildResult> BuildWithFallbacksAsync(
        string projectPath,
        IProgress<BuildPhase>? progress = null)
    {
        // Phase 1: Validate environment
        var validation = await ValidateEnvironmentAsync(projectPath);
        if (validation.HasFatalIssues)
        {
            return BuildResult.FailedValidation(validation);
        }
        
        // Phase 2: Attempt restore
        var restoreResult = await RestoreWithRetryAsync(projectPath);
        if (!restoreResult.Success)
        {
            // Try clearing cache + retry
            if (restoreResult.ErrorType == ErrorType.NuGetCacheCorrupted)
            {
                _logger.LogInformation("Clearing NuGet cache...");
                await ClearNuGetCacheAsync();
                
                restoreResult = await RestoreWithRetryAsync(projectPath);
                if (!restoreResult.Success)
                    return BuildResult.Failed(restoreResult);
            }
        }
        
        // Phase 3: Build with throttling
        var buildResult = await BuildWithThrottlingAsync(projectPath);
        
        return buildResult;
    }
    
    private async Task<bool> ClearNuGetCacheAsync()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var nugetCache = Path.Combine(localAppData, "NuGet", "v3-cache");
        
        try
        {
            if (Directory.Exists(nugetCache))
            {
                Directory.Delete(nugetCache, recursive: true);
                _logger.LogInformation("NuGet cache cleared");
            }
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning($"Failed to clear NuGet cache: {ex.Message}");
            return false;
        }
    }
    
    private async Task<BuildResult> BuildWithThrottlingAsync(string projectPath)
    {
        // Respect user's machine
        var processorCount = Environment.ProcessorCount;
        var maxParallelism = Math.Max(1, processorCount - 1);  // Leave one core free
        
        var result = await kernel.BuildAsync(
            additionalArgs: $"/m:{maxParallelism}");
        
        return result;
    }
}
```

---

## 5️⃣ UI Framework: WinUI 3 (CONFIRMED) ✅

### Selected: WinUI 3

**Modern, Fluent Design System**:
- Native Windows 11 feel
- Performance optimized
- Active Microsoft development
- Professional 2026 builder expectations
- Async/await threading (cleaner code)
- MVVM Toolkit integration
- MSIX modern deployment

**Target Platform**: Windows 10 Build 22621+ (Windows 11 standard)

**Why WinUI 3**:
- Modern UI framework aligned with current Microsoft direction
- Superior performance vs legacy frameworks
- Native hardware acceleration
- Built-in dependency injection
- Active development and future-proof

### Architecture for WinUI 3

1. **Service layer** remains identical (Orchestrator + Execution Kernel)
2. **UI architecture** (WinUI 3):
   - MVVM Toolkit (Microsoft recommended)
   - Dependency Injection built-in
   - WinAppSDK 1.5+
   - Fluent Design System

3. **Threading model** (WinUI 3):
   - Async/await primary pattern
   - DispatcherQueue for UI thread access
   - Background tasks with ThreadPoolTimer
   - Clean, modern async patterns throughout

4. **Deployment** (WinUI 3):
   - MSIX packaging
   - Store distribution or side-load
   - Automatic updates
   - Modern installer experience

### WinUI 3 Specifics

**Project Structure**:
```
SyncAIAppBuilder.sln
├── SyncAIAppBuilder.Orchestration/       (Class library)
├── SyncAIAppBuilder.ExecutionKernel/     (Class library)
├── SyncAIAppBuilder.CodeIntelligence/    (Class library)
└── SyncAIAppBuilder.Desktop/             (WinUI 3 App)
    ├── App.xaml(.cs)
    ├── MainWindow.xaml(.cs)
    ├── Views/
    └── ViewModels/
```

**MVVM Pattern (WinUI 3 + MVVM Toolkit)**:
```csharp
using Microsoft.Mvvm.Toolkit;

public partial class BuildViewModel : ObservableObject
{
    private readonly IOrchestrator _orchestrator;
    
    [ObservableProperty]
    private string projectName;
    
    [ObservableProperty]
    private bool isBuilding;
    
    [RelayCommand]
    private async Task BuildProjectAsync()
    {
        IsBuilding = true;
        var result = await _orchestrator.ExecuteTaskAsync(task);
        IsBuilding = false;
    }
}
```

**Threading (WinUI 3 DispatcherQueue)**:
```csharp
// Update UI from background task
await DispatcherQueue.EnqueueAsync(() =>
{
    BuildProgressText = "Compiling...";
    BuildPercentage = 45;
});
```

---

## 6️⃣ Local-Only Implementation Reality

### What Gets Harder

1. **Infra** - Can't hide behind cloud
2. **Errors** - User sees all system variability
3. **Retries** - Must be local, consume resources
4. **Logging** - Must persist locally
5. **Updates** - User controls when/if they upgrade

### What Gets Easier

1. **Privacy** - No cloud, no telemetry needed
2. **Responsiveness** - Local = instant
3. **Cost** - No server bills
4. **Control** - User owns entire process

---

## Implementation Ready (WinUI 3 Confirmed)

All architectural decisions are finalized:
- ✅ Orchestrator (deterministic state machine)
- ✅ Execution Kernel (local, managed)
- ✅ Subsystems (6 embedded systems)
- ✅ Local deployment (desktop-only)
- ✅ UI Framework (WinUI 3)

Next deliverable: Complete solution structure and service layer design.

---

**Status**: 🟢 Architecture Finalized - Ready for Implementation  
**Framework**: WinUI 3 (.NET 8)  
**Target OS**: Windows 10 Build 22621+ (Windows 11 standard)  
**Deployment**: MSIX packaging  
**Complexity**: High (distributed system concerns locally)  
**Risk**: CRITICAL if skipped (foundation of reliability)  
**Estimated Total LOC**: 2,650 lines C# core
