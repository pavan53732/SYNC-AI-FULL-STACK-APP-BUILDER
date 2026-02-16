# Build System Specification - Local Build Kernel

**Purpose:** Define local build kernel behavior for MSBuild integration.  
**Scope:** Build execution, error classification, and result reporting.  
**Framework:** .NET 8 SDK, MSBuild, NuGet

---

## 1. Responsibilities

The Build System is responsible for:

* **Execute In-Process Restore** - Restore NuGet packages via MSBuild API
* **Execute In-Process Build** - Compile C# and XAML via `BuildManager`
* **Capture Structured Logs** - Collect errors/warnings directly from `ILogger`
* **Enforce timeout** - Prevent infinite builds
* **Enforce process isolation** - Build in isolated `ProjectCollection` context
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
│ 4. Clean Workspace                                      │
│    - Delete bin/ and obj/ directories                   │
│    - Reset ProjectCollection context                    │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 5. Execute In-Process Build (Microsoft.Build)           │
│    - Load Project (ProjectCollection.LoadProject)       │
│    - Create Logger (StructuredLogger)                   │
│    - Run Target: "Restore;Build"                        │
│    - Timeout: 60-120 seconds                            │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│ 6. Process Build Result                                 │
│    - Retrieve structured errors from Logger             │
│    - Classify error types (CS, NU, MSB)                 │
│    - Generate BuildResult object                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ├─── SUCCESS ───┐
                     │                │
                     │                ▼
                     │    ┌───────────────────────────┐
                     │    │ 7a. Commit Snapshot       │
                     │    │    - Mark as successful   │
                     │    │    - Update state.json    │
                     │    └───────────────────────────┘
                     │
                     └─── FAILURE ───┐
                                     │
                                     ▼
                         ┌───────────────────────────┐
                         │ 7b. Classify Error        │
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
    /// Builds a project asynchronously using MSBuild API.
    /// </summary>
    Task<BuildResult> BuildAsync(
        string projectPath, 
        BuildOptions options = null,
        CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Restores NuGet packages via MSBuild "Restore" target.
    /// </summary>
    Task<RestoreResult> RestoreAsync(
        string projectPath,
        CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Cleans build artifacts (bin/obj directories).
    /// </summary>
    Task CleanAsync(string projectPath);
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
    /// Additional global properties for MSBuild.
    /// </summary>
    public Dictionary<string, string> Properties { get; set; } = new();
    
    /// <summary>
    /// Diagnostic verbosity.
    /// </summary>
    public LoggerVerbosity Verbosity { get; set; } = LoggerVerbosity.Minimal;
}
```

### BuildResult Class

```csharp
public class BuildResult
{
    public bool Success { get; set; }
    public ErrorType? ErrorType { get; set; } // Dominant error type
    public string ErrorMessage { get; set; }   // Summary message
    public List<BuildError> Errors { get; set; } = new();
    public List<BuildWarning> Warnings { get; set; } = new();
    public TimeSpan Duration { get; set; }
    public string BuildLog { get; set; }       // Full diagnostic log
}
```

### BuildError Class

```csharp
public class BuildError
{
    public string Code { get; set; }          // e.g. CS1002
    public string Message { get; set; }
    public string File { get; set; }
    public int LineNumber { get; set; }
    public int ColumnNumber { get; set; }
    public ErrorType ErrorType { get; set; }  // e.g. CSharpCompiler
}
```

---

## 4. Error Classification

### Error Type Taxonomy

```csharp
public enum ErrorType
{
    CSharpCompiler,         // CSxxxx
    XamlCompiler,           // XDGxxxx, XLSxxxx
    NuGetRestore,           // NUxxxx
    MSBuildInfrastructure,  // MSBxxxx
    ProjectFile,            // Missing .csproj, invalid XML
    Timeout,                // Build exceeded time limit
    Unknown                 // Unclassified
}
```

### Error Classifier Implementation

```csharp
public class ErrorClassifier
{
    public ErrorType Classify(BuildErrorEventArgs error)
    {
        // 1. Check Error Code first (most reliable)
        if (!string.IsNullOrEmpty(error.Code))
        {
            if (error.Code.StartsWith("CS")) return ErrorType.CSharpCompiler;
            if (error.Code.StartsWith("XDG") || error.Code.StartsWith("XLS")) return ErrorType.XamlCompiler;
            if (error.Code.StartsWith("NU")) return ErrorType.NuGetRestore;
            if (error.Code.StartsWith("MSB")) return ErrorType.MSBuildInfrastructure;
        }

        // 2. Fallback to Project File analysis
        if (error.File != null && error.File.EndsWith(".csproj"))
        {
            return ErrorType.ProjectFile;
        }

        return ErrorType.Unknown;
    }
}
```

---

## 5. Build Service Implementation

### BuildService Class (API-Based)

```csharp
using Microsoft.Build.Evaluation;
using Microsoft.Build.Execution;
using Microsoft.Build.Framework;

public class BuildService : IBuildService
{
    private readonly ILogger<BuildService> _logger;
    private readonly ErrorClassifier _errorClassifier;
    
    public BuildService(ILogger<BuildService> logger)
    {
        _logger = logger;
        _errorClassifier = new ErrorClassifier();
    }
    
    public async Task<BuildResult> BuildAsync(
        string projectPath, 
        BuildOptions options = null,
        CancellationToken cancellationToken = default)
    {
        options ??= new BuildOptions();
        var stopwatch = Stopwatch.StartNew();
        
        return await Task.Run(() => 
        {
            var projectCollection = new ProjectCollection();
            var buildLogger = new StructuredLogger();
            
            try
            {
                // 1. Load Project
                var project = projectCollection.LoadProject(projectPath);
                
                // 2. Set Properties
                project.SetProperty("Configuration", options.Configuration);
                foreach (var prop in options.Properties)
                {
                    project.SetProperty(prop.Key, prop.Value);
                }
                
                // 3. Prepare Build Parameters
                var buildParameters = new BuildParameters(projectCollection)
                {
                    Loggers = new[] { buildLogger },
                    MaxNodeCount = Environment.ProcessorCount,
                    DetailedSummary = false
                };
                
                // 4. Create Request (Restore + Build)
                var targets = options.RestoreBeforeBuild 
                    ? new[] { "Restore", "Build" } 
                    : new[] { "Build" };
                    
                var buildRequest = new BuildRequestData(
                    project.CreateProjectInstance(),
                    targets
                );
                
                // 5. Execute
                var buildResult = BuildManager.DefaultBuildManager
                    .Build(buildParameters, buildRequest);
                
                stopwatch.Stop();
                
                // 6. Process Results
                return CreateResult(buildResult, buildLogger, stopwatch.Elapsed);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Build failed with exception");
                return new BuildResult
                {
                    Success = false,
                    ErrorType = ErrorType.MSBuildInfrastructure,
                    ErrorMessage = ex.Message,
                    Duration = stopwatch.Elapsed
                };
            }
            finally
            {
                projectCollection.Dispose();
            }
        }, cancellationToken);
    }
    
    private BuildResult CreateResult(
        Microsoft.Build.Execution.BuildResult msBuildResult,
        StructuredLogger logger,
        TimeSpan duration)
    {
        var result = new BuildResult
        {
            Success = msBuildResult.OverallResult == BuildResultCode.Success,
            Duration = duration,
            Errors = logger.Errors.Select(e => new BuildError 
            {
                Code = e.Code,
                Message = e.Message,
                File = e.File,
                LineNumber = e.LineNumber,
                ColumnNumber = e.ColumnNumber,
                ErrorType = _errorClassifier.Classify(e)
            }).ToList(),
            Warnings = logger.Warnings.Select(w => new BuildWarning
            {
                 Code = w.Code,
                 Message = w.Message,
                 File = w.File,
                 LineNumber = w.LineNumber
            }).ToList(),
            BuildLog = logger.FullLog
        };
        
        if (!result.Success && result.Errors.Any())
        {
            var primaryError = result.Errors.FirstOrDefault();
            result.ErrorType = primaryError?.ErrorType;
            result.ErrorMessage = primaryError?.Message;
        }
        
        return result;
    }

    public async Task<RestoreResult> RestoreAsync(
        string projectPath,
        CancellationToken cancellationToken = default)
    {
        // Re-use BuildAsync with "Restore" target only
        // Implementation omitted for brevity, logic identical to BuildAsync
        return new RestoreResult { Success = true }; 
    }

    public async Task CleanAsync(string projectPath)
    {
        var projectDir = Path.GetDirectoryName(projectPath);
        var binPath = Path.Combine(projectDir, "bin");
        var objPath = Path.Combine(projectDir, "obj");
        
        if (Directory.Exists(binPath)) Directory.Delete(binPath, recursive: true);
        if (Directory.Exists(objPath)) Directory.Delete(objPath, recursive: true);
        
        await Task.CompletedTask;
    }
}

/// <summary>
/// Captures MSBuild events into structured data.
/// </summary>
public class StructuredLogger : ILogger
{
    public List<BuildErrorEventArgs> Errors { get; } = new();
    public List<BuildWarningEventArgs> Warnings { get; } = new();
    public string FullLog { get; private set; } = string.Empty;
    
    public void Initialize(IEventSource eventSource)
    {
        eventSource.ErrorRaised += (s, e) => Errors.Add(e);
        eventSource.WarningRaised += (s, e) => Warnings.Add(e);
    }
    
    public void Shutdown() { }
    public LoggerVerbosity Verbosity { get; set; }
    public string Parameters { get; set; }
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

### Integration Tests (Kernel Level)
Since `BuildManager` is a static singleton, we test `BuildService` via integration tests with a real project on disk.

```csharp
[TestClass]
public class BuildServiceIntegrationTests
{
    private BuildService _buildService;
    private string _testWorkspace;

    [TestInitialize]
    public void Setup()
    {
        _testWorkspace = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(_testWorkspace);
        _buildService = new BuildService(new NullLogger<BuildService>());
    }

    [TestMethod]
    public async Task BuildAsync_ValidProject_ReturnsSuccess()
    {
        // Arrange
        var projectPath = CreateValidProject(_testWorkspace);

        // Act
        var result = await _buildService.BuildAsync(projectPath);

        // Assert
        Assert.IsTrue(result.Success);
        Assert.AreEqual(0, result.Errors.Count);
    }
}
```

### Unit Tests (Consumer Level)
Consumers of `IBuildService` (like Orchestrator) should mock the interface.

```csharp
[TestMethod]
public async Task Orchestrator_HandlesBuildFailure_Correctly()
{
    // Arrange
    var mockBuild = new Mock<IBuildService>();
    mockBuild.Setup(b => b.BuildAsync(It.IsAny<string>(), null, default))
             .ReturnsAsync(new BuildResult 
             { 
                 Success = false, 
                 ErrorType = ErrorType.CSharpCompiler 
             });

    var orchestrator = new Orchestrator(mockBuild.Object);

    // Act
    await orchestrator.RunTaskAsync(new BuildTask());

    // Assert
    // Verify remediation logic triggered
}
```

---

## References

- [EXECUTION_ARCHITECTURE.md](EXECUTION_ARCHITECTURE.md) - Execution subsystems
- [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) - Orchestrator integration
- [ROSLYN_INTEGRATION_SPECIFICATION.md](ROSLYN_INTEGRATION_SPECIFICATION.md) - Code mutation
