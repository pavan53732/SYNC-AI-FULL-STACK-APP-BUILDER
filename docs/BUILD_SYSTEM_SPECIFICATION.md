# Build System Specification - Local Build Kernel

**Purpose:** Define local build kernel behavior for MSBuild integration.  
**Scope:** Build execution, error classification, and result reporting.  
**Framework:** .NET 8 SDK, MSBuild, NuGet

---

## 1. Responsibilities

The Build System is responsible for:

* **Execute `dotnet restore`** - Restore NuGet packages
* **Execute `dotnet build`** - Compile C# and XAML
* **Parse MSBuild output** - Extract errors and warnings
* **Enforce timeout** - Prevent infinite builds
* **Enforce process isolation** - Sandbox build execution
* **Capture logs** - Structured logging for debugging
* **Classify errors** - Categorize by error type
* **Support cancellation** - Allow user to cancel builds
* **Snapshot management** - Create/restore workspace snapshots

---

## 2. Build Flow

### Standard Build Sequence

```
┌─────────────────────────────────────────────────────────┐
│ 1. Task Starts                                          │
│    - Receive BuildTask from Orchestrator                │
│    - Validate workspace path                            │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 2. Snapshot Workspace                                   │
│    - Create ZIP snapshot of current state               │
│    - Store in .builder/snapshots/                       │
│    - Record timestamp and task ID                       │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 3. Apply Patch (if any)                                 │
│    - Receive code changes from Roslyn engine            │
│    - Apply to workspace files                           │
│    - Validate file integrity                            │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 4. Clean Build Artifacts                                │
│    - Delete bin/ and obj/ directories                   │
│    - Clear NuGet cache if needed                        │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 5. Restore NuGet Packages                               │
│    - Run: dotnet restore                                │
│    - Timeout: 120 seconds                               │
│    - Capture output                                     │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 6. Build Project                                        │
│    - Run: dotnet build --no-restore                     │
│    - Timeout: 60 seconds                                │
│    - Capture stdout and stderr                          │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 7. Parse Build Output                                   │
│    - Extract errors and warnings                        │
│    - Classify error types                               │
│    - Generate structured result                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ├─── SUCCESS ───┐
                     │                │
                     │                ▼
                     │    ┌───────────────────────────┐
                     │    │ 8a. Commit Snapshot       │
                     │    │    - Mark as successful   │
                     │    │    - Update state.json    │
                     │    └───────────────────────────┘
                     │
                     └─── FAILURE ───┐
                                     │
                                     ▼
                         ┌───────────────────────────┐
                         │ 8b. Classify Error        │
                         │    - Determine error type │
                         │    - Return to Orchestrator│
                         │    - Keep snapshot        │
                         └───────────────────────────┘
```

---

## 3. Build Runner Implementation

### IBuildService Interface

```csharp
public interface IBuildService
{
    /// <summary>
    /// Builds a project asynchronously with timeout and cancellation support.
    /// </summary>
    Task<BuildResult> BuildAsync(
        string projectPath, 
        BuildOptions options = null,
        CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Restores NuGet packages for a project.
    /// </summary>
    Task<RestoreResult> RestoreAsync(
        string projectPath,
        CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Cleans build artifacts (bin/obj directories).
    /// </summary>
    Task CleanAsync(string projectPath);
    
    /// <summary>
    /// Validates that the .NET SDK is available.
    /// </summary>
    Task<SdkValidationResult> ValidateSdkAsync();
}
```

### BuildOptions Class

```csharp
public class BuildOptions
{
    /// <summary>
    /// Build configuration (Debug or Release).
    /// </summary>
    public string Configuration { get; set; } = "Debug";
    
    /// <summary>
    /// Maximum time allowed for build (default: 60 seconds).
    /// </summary>
    public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(60);
    
    /// <summary>
    /// Whether to restore NuGet packages before building.
    /// </summary>
    public bool RestoreBeforeBuild { get; set; } = true;
    
    /// <summary>
    /// Whether to clean before building.
    /// </summary>
    public bool CleanBeforeBuild { get; set; } = false;
    
    /// <summary>
    /// Additional MSBuild arguments.
    /// </summary>
    public string[] AdditionalArguments { get; set; }
    
    /// <summary>
    /// Verbosity level (quiet, minimal, normal, detailed, diagnostic).
    /// </summary>
    public string Verbosity { get; set; } = "minimal";
}
```

### BuildResult Class

```csharp
public class BuildResult
{
    /// <summary>
    /// Whether the build succeeded.
    /// </summary>
    public bool Success { get; set; }
    
    /// <summary>
    /// Type of error if build failed.
    /// </summary>
    public ErrorType? ErrorType { get; set; }
    
    /// <summary>
    /// Primary error message.
    /// </summary>
    public string ErrorMessage { get; set; }
    
    /// <summary>
    /// All errors encountered during build.
    /// </summary>
    public List<BuildError> Errors { get; set; } = new();
    
    /// <summary>
    /// All warnings encountered during build.
    /// </summary>
    public List<BuildWarning> Warnings { get; set; } = new();
    
    /// <summary>
    /// Time taken to complete the build.
    /// </summary>
    public TimeSpan Duration { get; set; }
    
    /// <summary>
    /// Full build output log.
    /// </summary>
    public string BuildLog { get; set; }
    
    /// <summary>
    /// Exit code from dotnet build process.
    /// </summary>
    public int ExitCode { get; set; }
}
```

### BuildError Class

```csharp
public class BuildError
{
    /// <summary>
    /// Error code (e.g., CS0103, XAML1234).
    /// </summary>
    public string Code { get; set; }
    
    /// <summary>
    /// Error message text.
    /// </summary>
    public string Message { get; set; }
    
    /// <summary>
    /// File path where error occurred.
    /// </summary>
    public string FilePath { get; set; }
    
    /// <summary>
    /// Line number in file.
    /// </summary>
    public int? LineNumber { get; set; }
    
    /// <summary>
    /// Column number in file.
    /// </summary>
    public int? ColumnNumber { get; set; }
    
    /// <summary>
    /// Classified error type.
    /// </summary>
    public ErrorType ErrorType { get; set; }
}
```

---

## 4. Error Classification

### Error Type Taxonomy

```csharp
public enum ErrorType
{
    /// <summary>
    /// C# compiler errors (CS0001-CS9999).
    /// </summary>
    CSharpCompiler,
    
    /// <summary>
    /// XAML parsing/compilation errors (XDG0001-XDG9999).
    /// </summary>
    XamlCompiler,
    
    /// <summary>
    /// NuGet package restore errors (NU0001-NU9999).
    /// </summary>
    NuGetRestore,
    
    /// <summary>
    /// MSBuild infrastructure errors (MSB0001-MSB9999).
    /// </summary>
    MSBuildInfrastructure,
    
    /// <summary>
    /// Project file errors (.csproj syntax).
    /// </summary>
    ProjectFile,
    
    /// <summary>
    /// SDK not found or version mismatch.
    /// </summary>
    SdkNotFound,
    
    /// <summary>
    /// Build timeout exceeded.
    /// </summary>
    Timeout,
    
    /// <summary>
    /// Unknown or unclassified error.
    /// </summary>
    Unknown
}
```

### Error Classifier Implementation

```csharp
public class ErrorClassifier
{
    public ErrorType ClassifyError(string errorCode, string errorMessage)
    {
        if (string.IsNullOrEmpty(errorCode))
            return ClassifyByMessage(errorMessage);
        
        // C# compiler errors
        if (errorCode.StartsWith("CS", StringComparison.OrdinalIgnoreCase))
            return ErrorType.CSharpCompiler;
        
        // XAML errors
        if (errorCode.StartsWith("XDG", StringComparison.OrdinalIgnoreCase) ||
            errorCode.StartsWith("XLS", StringComparison.OrdinalIgnoreCase))
            return ErrorType.XamlCompiler;
        
        // NuGet errors
        if (errorCode.StartsWith("NU", StringComparison.OrdinalIgnoreCase))
            return ErrorType.NuGetRestore;
        
        // MSBuild errors
        if (errorCode.StartsWith("MSB", StringComparison.OrdinalIgnoreCase))
            return ErrorType.MSBuildInfrastructure;
        
        return ErrorType.Unknown;
    }
    
    private ErrorType ClassifyByMessage(string message)
    {
        if (message.Contains("SDK", StringComparison.OrdinalIgnoreCase))
            return ErrorType.SdkNotFound;
        
        if (message.Contains(".csproj", StringComparison.OrdinalIgnoreCase))
            return ErrorType.ProjectFile;
        
        return ErrorType.Unknown;
    }
}
```

---

## 5. Build Service Implementation

### BuildService Class

```csharp
public class BuildService : IBuildService
{
    private readonly ILogger<BuildService> _logger;
    private readonly ErrorClassifier _errorClassifier;
    private readonly string _dotnetPath;
    
    public BuildService(ILogger<BuildService> logger)
    {
        _logger = logger;
        _errorClassifier = new ErrorClassifier();
        _dotnetPath = FindDotnetExecutable();
    }
    
    public async Task<BuildResult> BuildAsync(
        string projectPath, 
        BuildOptions options = null,
        CancellationToken cancellationToken = default)
    {
        options ??= new BuildOptions();
        var stopwatch = Stopwatch.StartNew();
        
        try
        {
            // Validate project path
            if (!File.Exists(projectPath))
            {
                return new BuildResult
                {
                    Success = false,
                    ErrorType = ErrorType.ProjectFile,
                    ErrorMessage = $"Project file not found: {projectPath}"
                };
            }
            
            // Clean if requested
            if (options.CleanBeforeBuild)
            {
                await CleanAsync(projectPath);
            }
            
            // Restore if requested
            if (options.RestoreBeforeBuild)
            {
                var restoreResult = await RestoreAsync(projectPath, cancellationToken);
                if (!restoreResult.Success)
                {
                    return new BuildResult
                    {
                        Success = false,
                        ErrorType = ErrorType.NuGetRestore,
                        ErrorMessage = restoreResult.ErrorMessage,
                        Duration = stopwatch.Elapsed
                    };
                }
            }
            
            // Build
            var buildArgs = BuildCommandArguments(projectPath, options);
            var processResult = await RunDotnetCommandAsync(
                buildArgs, 
                options.Timeout, 
                cancellationToken);
            
            stopwatch.Stop();
            
            // Parse output
            var result = ParseBuildOutput(processResult, stopwatch.Elapsed);
            return result;
        }
        catch (OperationCanceledException)
        {
            return new BuildResult
            {
                Success = false,
                ErrorType = ErrorType.Timeout,
                ErrorMessage = "Build was cancelled",
                Duration = stopwatch.Elapsed
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Build failed with exception");
            return new BuildResult
            {
                Success = false,
                ErrorType = ErrorType.Unknown,
                ErrorMessage = ex.Message,
                Duration = stopwatch.Elapsed
            };
        }
    }
    
    private string[] BuildCommandArguments(string projectPath, BuildOptions options)
    {
        var args = new List<string>
        {
            "build",
            $"\"{projectPath}\"",
            $"--configuration {options.Configuration}",
            $"--verbosity {options.Verbosity}"
        };
        
        if (!options.RestoreBeforeBuild)
        {
            args.Add("--no-restore");
        }
        
        if (options.AdditionalArguments != null)
        {
            args.AddRange(options.AdditionalArguments);
        }
        
        return args.ToArray();
    }
    
    private async Task<ProcessResult> RunDotnetCommandAsync(
        string[] arguments,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = _dotnetPath,
            Arguments = string.Join(" ", arguments),
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        
        using var process = new Process { StartInfo = startInfo };
        var outputBuilder = new StringBuilder();
        var errorBuilder = new StringBuilder();
        
        process.OutputDataReceived += (s, e) =>
        {
            if (e.Data != null)
                outputBuilder.AppendLine(e.Data);
        };
        
        process.ErrorDataReceived += (s, e) =>
        {
            if (e.Data != null)
                errorBuilder.AppendLine(e.Data);
        };
        
        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        
        // Wait with timeout
        using var timeoutCts = new CancellationTokenSource(timeout);
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken, timeoutCts.Token);
        
        try
        {
            await process.WaitForExitAsync(linkedCts.Token);
        }
        catch (OperationCanceledException)
        {
            process.Kill(entireProcessTree: true);
            throw;
        }
        
        return new ProcessResult
        {
            ExitCode = process.ExitCode,
            StandardOutput = outputBuilder.ToString(),
            StandardError = errorBuilder.ToString()
        };
    }
    
    private BuildResult ParseBuildOutput(ProcessResult processResult, TimeSpan duration)
    {
        var result = new BuildResult
        {
            Success = processResult.ExitCode == 0,
            ExitCode = processResult.ExitCode,
            BuildLog = processResult.StandardOutput + processResult.StandardError,
            Duration = duration
        };
        
        if (!result.Success)
        {
            // Parse errors from output
            var errors = ExtractErrors(processResult.StandardOutput);
            result.Errors = errors;
            
            if (errors.Any())
            {
                var firstError = errors.First();
                result.ErrorType = firstError.ErrorType;
                result.ErrorMessage = firstError.Message;
            }
        }
        
        return result;
    }
    
    private List<BuildError> ExtractErrors(string buildOutput)
    {
        var errors = new List<BuildError>();
        var lines = buildOutput.Split('\n');
        
        // MSBuild error format: path(line,col): error CODE: message
        var errorRegex = new Regex(
            @"^(.+?)\((\d+),(\d+)\):\s*error\s+([A-Z]+\d+):\s*(.+)$",
            RegexOptions.Compiled);
        
        foreach (var line in lines)
        {
            var match = errorRegex.Match(line.Trim());
            if (match.Success)
            {
                var errorCode = match.Groups[4].Value;
                var error = new BuildError
                {
                    FilePath = match.Groups[1].Value,
                    LineNumber = int.Parse(match.Groups[2].Value),
                    ColumnNumber = int.Parse(match.Groups[3].Value),
                    Code = errorCode,
                    Message = match.Groups[5].Value,
                    ErrorType = _errorClassifier.ClassifyError(errorCode, match.Groups[5].Value)
                };
                
                errors.Add(error);
            }
        }
        
        return errors;
    }
    
    public async Task<RestoreResult> RestoreAsync(
        string projectPath,
        CancellationToken cancellationToken = default)
    {
        var args = new[] { "restore", $"\"{projectPath}\"" };
        var result = await RunDotnetCommandAsync(
            args, 
            TimeSpan.FromSeconds(120), 
            cancellationToken);
        
        return new RestoreResult
        {
            Success = result.ExitCode == 0,
            ErrorMessage = result.ExitCode != 0 ? result.StandardError : null
        };
    }
    
    public async Task CleanAsync(string projectPath)
    {
        var projectDir = Path.GetDirectoryName(projectPath);
        var binPath = Path.Combine(projectDir, "bin");
        var objPath = Path.Combine(projectDir, "obj");
        
        if (Directory.Exists(binPath))
            Directory.Delete(binPath, recursive: true);
        
        if (Directory.Exists(objPath))
            Directory.Delete(objPath, recursive: true);
        
        await Task.CompletedTask;
    }
    
    public async Task<SdkValidationResult> ValidateSdkAsync()
    {
        try
        {
            var args = new[] { "--version" };
            var result = await RunDotnetCommandAsync(
                args, 
                TimeSpan.FromSeconds(5), 
                CancellationToken.None);
            
            if (result.ExitCode == 0)
            {
                var version = result.StandardOutput.Trim();
                return new SdkValidationResult
                {
                    IsValid = true,
                    Version = version
                };
            }
        }
        catch { }
        
        return new SdkValidationResult
        {
            IsValid = false,
            ErrorMessage = ".NET SDK not found or not accessible"
        };
    }
    
    private string FindDotnetExecutable()
    {
        // Check common locations
        var paths = new[]
        {
            "dotnet",
            @"C:\Program Files\dotnet\dotnet.exe",
            @"C:\Program Files (x86)\dotnet\dotnet.exe"
        };
        
        foreach (var path in paths)
        {
            if (File.Exists(path) || IsInPath(path))
                return path;
        }
        
        throw new FileNotFoundException(".NET SDK not found");
    }
    
    private bool IsInPath(string executable)
    {
        try
        {
            var process = Process.Start(new ProcessStartInfo
            {
                FileName = executable,
                Arguments = "--version",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            });
            
            process?.WaitForExit(1000);
            return process?.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }
}
```

---

## 6. Isolation Model

### Workspace Isolation Rules

* **Workspace-specific build directory** - Each project builds in its own directory
* **Clear bin/obj before build** - Prevent stale artifacts
* **No global folder writes** - All operations scoped to workspace
* **Process must be killable** - Support cancellation
* **No elevated permissions** - Run as standard user
* **Memory limit enforcement** - Monitor process memory usage
* **Timeout enforcement** - Kill process after timeout

### Snapshot Management

```csharp
public class SnapshotManager
{
    private readonly string _snapshotDir;
    
    public async Task<string> CreateSnapshotAsync(string workspacePath, string taskId)
    {
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var snapshotName = $"snapshot_{taskId}_{timestamp}.zip";
        var snapshotPath = Path.Combine(_snapshotDir, snapshotName);
        
        // Create ZIP of workspace
        ZipFile.CreateFromDirectory(workspacePath, snapshotPath);
        
        _logger.LogInformation("Created snapshot: {SnapshotPath}", snapshotPath);
        return snapshotPath;
    }
    
    public async Task RestoreSnapshotAsync(string snapshotPath, string workspacePath)
    {
        // Clear workspace
        Directory.Delete(workspacePath, recursive: true);
        Directory.CreateDirectory(workspacePath);
        
        // Extract snapshot
        ZipFile.ExtractToDirectory(snapshotPath, workspacePath);
        
        _logger.LogInformation("Restored snapshot: {SnapshotPath}", snapshotPath);
    }
}
```

---

## 7. Performance Optimization

### Incremental Build Support

```csharp
public class IncrementalBuildTracker
{
    private readonly Dictionary<string, string> _fileHashes = new();
    
    public bool HasFileChanged(string filePath)
    {
        var currentHash = ComputeFileHash(filePath);
        
        if (_fileHashes.TryGetValue(filePath, out var previousHash))
        {
            return currentHash != previousHash;
        }
        
        _fileHashes[filePath] = currentHash;
        return true;
    }
    
    private string ComputeFileHash(string filePath)
    {
        using var sha256 = SHA256.Create();
        using var stream = File.OpenRead(filePath);
        var hash = sha256.ComputeHash(stream);
        return Convert.ToBase64String(hash);
    }
}
```

### Build Caching

* Cache NuGet packages globally
* Reuse previous build artifacts when possible
* Track file changes to avoid unnecessary rebuilds
* Cache Roslyn compilation results

---

## 8. Testing Strategy

### Unit Tests

```csharp
[TestClass]
public class BuildServiceTests
{
    [TestMethod]
    public async Task BuildAsync_ValidProject_ReturnsSuccess()
    {
        // Arrange
        var buildService = new BuildService(Mock.Of<ILogger<BuildService>>());
        var projectPath = "TestProjects/ValidApp/ValidApp.csproj";
        
        // Act
        var result = await buildService.BuildAsync(projectPath);
        
        // Assert
        Assert.IsTrue(result.Success);
        Assert.AreEqual(0, result.ExitCode);
    }
    
    [TestMethod]
    public async Task BuildAsync_CompilerError_ClassifiesCorrectly()
    {
        // Arrange
        var buildService = new BuildService(Mock.Of<ILogger<BuildService>>());
        var projectPath = "TestProjects/ErrorApp/ErrorApp.csproj";
        
        // Act
        var result = await buildService.BuildAsync(projectPath);
        
        // Assert
        Assert.IsFalse(result.Success);
        Assert.AreEqual(ErrorType.CSharpCompiler, result.ErrorType);
        Assert.IsTrue(result.Errors.Any());
    }
}
```

---

## References

- [EXECUTION_ARCHITECTURE.md](EXECUTION_ARCHITECTURE.md) - Execution subsystems
- [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) - Orchestrator integration
- [ROSLYN_INTEGRATION_SPECIFICATION.md](ROSLYN_INTEGRATION_SPECIFICATION.md) - Code mutation
