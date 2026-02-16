# Background Systems & Hidden Processes Specification

**Purpose**: Define all systems that run silently beneath the Lovable-style UI  
**Philosophy**: Complexity is hidden, not absent  
**Framework**: WinUI 3 + Local Kernel + Orchestrator

---

## Core Principle

> **Calm UI with 10+ background subsystems**
> 
> When user clicks "Generate", 10+ systems run silently. User sees: Spinner → App appears.

**Reality**: Deterministic state engine, safety rollback, continuous indexing, intelligent retry loops, local build supervision

---

## 1. Hidden Systems (Never Shown in Normal Mode)

These systems exist but are **invisible** unless Advanced Mode is enabled.

---

### A. Deterministic Orchestrator Engine

**Running**:
- State machine transitions
- Task graph execution
- Retry counter
- Error classification
- Timeout enforcement

**User sees**: "Building…"

**User does NOT see**: `STATE: VALIDATING_DEPENDENCY_GRAPH`

**Implementation**:
```csharp
public class Orchestrator
{
    private OrchestratorState _currentState;
    private TaskGraph _taskGraph;
    private int _retryCount;
    
    private async Task ExecuteTaskGraphAsync()
    {
        // Hidden from user
        _currentState = OrchestratorState.SPEC_PARSED;
        _taskGraph = await _taskGraphBuilder.BuildAsync(spec);
        
        foreach (var task in _taskGraph.TopologicalSort())
        {
            _currentState = OrchestratorState.TASK_EXECUTING;
            await ExecuteTaskWithRetryAsync(task);
        }
        
        _currentState = OrchestratorState.VALIDATING;
        await ValidateOutputAsync();
        
        _currentState = OrchestratorState.COMPLETED;
        
        // User only sees UI state: BUILDING → PREVIEW_READY
    }
}
```

---

### B. Roslyn Indexing Engine

**Continuously maintains**:
- Syntax trees
- Symbol graph
- Dependency map
- XAML bindings
- Cross-file references

**Runs**:
- After every patch
- After snapshot restore
- After project load

**User never sees**: "Re-indexing 42 symbols…"

**Implementation**:
```csharp
public class RoslynIndexer
{
    private ConcurrentDictionary<string, SyntaxTree> _syntaxTrees;
    private SymbolGraph _symbolGraph;
    
    public async Task IndexProjectAsync(string projectPath)
    {
        // Runs silently in background
        var files = Directory.GetFiles(projectPath, "*.cs", SearchOption.AllDirectories);
        
        foreach (var file in files)
        {
            var tree = await ParseFileAsync(file);
            _syntaxTrees[file] = tree;
            
            // Update symbol graph
            await _symbolGraph.UpdateFromTreeAsync(tree);
        }
        
        // Build dependency map
        await BuildDependencyMapAsync();
        
        // Index XAML bindings
        await IndexXamlBindingsAsync();
        
        // No UI notification
    }
    
    public async Task IncrementalIndexFileAsync(string filePath)
    {
        // After patch, re-index only changed file
        var tree = await ParseFileAsync(filePath);
        _syntaxTrees[filePath] = tree;
        await _symbolGraph.UpdateFromTreeAsync(tree);
        
        // Silent
    }
}
```

---

### C. Structured Patch Engine

**For every change**:
1. Parse C# AST
2. Modify node
3. Validate syntax
4. Format code
5. Write atomically
6. Re-index file

**User never sees**: "ADD_METHOD operation applied."

**Implementation**:
```csharp
public class PatchEngine
{
    public async Task<PatchResult> ApplyPatchAsync(Patch patch)
    {
        // 1. Parse AST
        var tree = await CSharpSyntaxTree.ParseTextAsync(File.ReadAllText(patch.FilePath));
        var root = await tree.GetRootAsync();
        
        // 2. Modify node
        var modifiedRoot = patch.Operation switch
        {
            PatchOperation.ADD_METHOD => AddMethod(root, patch.MethodDeclaration),
            PatchOperation.MODIFY_METHOD => ModifyMethod(root, patch.MethodName, patch.NewBody),
            PatchOperation.DELETE_METHOD => DeleteMethod(root, patch.MethodName),
            _ => throw new InvalidOperationException()
        };
        
        // 3. Validate syntax
        var diagnostics = modifiedRoot.GetDiagnostics();
        if (diagnostics.Any(d => d.Severity == DiagnosticSeverity.Error))
        {
            return PatchResult.Failed("Syntax error after patch");
        }
        
        // 4. Format code
        var formatted = Formatter.Format(modifiedRoot, workspace);
        
        // 5. Write atomically
        await File.WriteAllTextAsync(patch.FilePath, formatted.ToFullString());
        
        // 6. Re-index file
        await _indexer.IncrementalIndexFileAsync(patch.FilePath);
        
        // Log internally, don't show to user
        _logger.LogInformation("Patch applied: {Operation} on {File}", patch.Operation, patch.FilePath);
        
        return PatchResult.Success();
    }
}
```

---

### D. Snapshot & Rollback System

**Before every mutation**:
- Create snapshot
- Store diff
- Save metadata

**On failure**:
- Rollback automatically
- Retry

**User sees**: Nothing

**Implementation**:
```csharp
public class SnapshotService
{
    public async Task<string> CreateSnapshotAsync(string projectPath, string reason)
    {
        var snapshotId = Guid.NewGuid().ToString();
        var snapshotPath = Path.Combine(_snapshotsDir, snapshotId);
        
        // Copy entire project state
        await CopyDirectoryAsync(projectPath, snapshotPath);
        
        // Store metadata
        var metadata = new SnapshotMetadata
        {
            Id = snapshotId,
            Timestamp = DateTime.UtcNow,
            TriggerReason = reason,
            ProjectPath = projectPath
        };
        
        await _database.SaveSnapshotMetadataAsync(metadata);
        
        // Silent - no UI notification
        _logger.LogDebug("Snapshot created: {SnapshotId}", snapshotId);
        
        return snapshotId;
    }
    
    public async Task RollbackAsync(string snapshotId)
    {
        var snapshot = await _database.GetSnapshotAsync(snapshotId);
        var snapshotPath = Path.Combine(_snapshotsDir, snapshotId);
        
        // Restore files
        await CopyDirectoryAsync(snapshotPath, snapshot.ProjectPath, overwrite: true);
        
        // Re-index
        await _indexer.IndexProjectAsync(snapshot.ProjectPath);
        
        // Silent rollback
        _logger.LogInformation("Rolled back to snapshot: {SnapshotId}", snapshotId);
    }
}
```

---

### E. Build Kernel Supervisor

**Internally**:
- Launch `dotnet restore`
- Launch `dotnet build`
- Capture logs
- Parse MSBuild output
- Classify errors
- Kill process on timeout

**User sees**: "Building your app…"

**Implementation**:
```csharp
public class BuildKernel
{
    public async Task<BuildResult> BuildProjectAsync(string projectPath)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = $"build \"{projectPath}\" --no-restore",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        
        using var process = new Process { StartInfo = startInfo };
        var outputBuilder = new StringBuilder();
        var errorBuilder = new StringBuilder();
        
        process.OutputDataReceived += (s, e) => outputBuilder.AppendLine(e.Data);
        process.ErrorDataReceived += (s, e) => errorBuilder.AppendLine(e.Data);
        
        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        
        // Timeout enforcement
        var completed = await process.WaitForExitAsync(TimeSpan.FromMinutes(5));
        
        if (!completed)
        {
            process.Kill();
            return BuildResult.Failed("Build timeout exceeded");
        }
        
        // Parse MSBuild output
        var errors = ParseMSBuildErrors(outputBuilder.ToString());
        
        // Classify errors
        var classification = ClassifyErrors(errors);
        
        // Log internally
        _logger.LogInformation("Build completed with {ErrorCount} errors", errors.Count);
        
        // User only sees: "Building…" → "Preview Ready" or "Optimizing build…"
        
        return process.ExitCode == 0 
            ? BuildResult.Success() 
            : BuildResult.Failed(classification);
    }
}
```

---

### F. Silent Retry Loop

**If build fails**:
1. Send minimal error context to AI
2. Receive structured fix
3. Apply patch
4. Retry build
5. Up to retry limit

**User only sees**: "Optimizing build…" (after 3 silent retries)

**Implementation**:
```csharp
public class RetryController
{
    private const int SilentRetryLimit = 3;
    private const int TotalRetryLimit = 10;
    
    public async Task<BuildResult> BuildWithRetryAsync(string projectPath)
    {
        for (int attempt = 1; attempt <= TotalRetryLimit; attempt++)
        {
            var result = await _buildKernel.BuildProjectAsync(projectPath);
            
            if (result.Success)
            {
                // Silent success
                _logger.LogInformation("Build succeeded on attempt {Attempt}", attempt);
                return result;
            }
            
            // Log internally
            _logger.LogWarning("Build failed on attempt {Attempt}: {Error}", attempt, result.Error);
            
            // Update UI state based on attempt count
            if (attempt > SilentRetryLimit)
            {
                // Show "Optimizing build…" to user
                _uiStateManager.TransitionTo(UIState.SOFT_RECOVERY);
            }
            
            // Get AI fix
            var fix = await _aiEngine.GenerateFixAsync(result.Error);
            
            // Apply patch
            await _patchEngine.ApplyPatchAsync(fix.Patch);
            
            // Exponential backoff
            await Task.Delay(TimeSpan.FromSeconds(Math.Pow(2, attempt - 1)));
        }
        
        // Retry budget exhausted
        return BuildResult.Failed("Retry limit exceeded");
    }
}
```

---

### G. Memory Layer (SQLite)

**Continuously stores**:
- Architectural decisions
- Naming conventions
- Error history
- Snapshot graph
- Project metadata

**User never interacts directly with DB**

**Schema**:
```sql
-- Architectural Decisions
CREATE TABLE ArchitecturalDecisions (
    Id TEXT PRIMARY KEY,
    ProjectId TEXT NOT NULL,
    Decision TEXT NOT NULL,
    Rationale TEXT,
    Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Naming Conventions
CREATE TABLE NamingConventions (
    Id TEXT PRIMARY KEY,
    ProjectId TEXT NOT NULL,
    Pattern TEXT NOT NULL,
    Example TEXT,
    Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Error History
CREATE TABLE ErrorHistory (
    Id TEXT PRIMARY KEY,
    ProjectId TEXT NOT NULL,
    ErrorCode TEXT,
    ErrorMessage TEXT,
    Resolution TEXT,
    Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Snapshot Graph
CREATE TABLE Snapshots (
    Id TEXT PRIMARY KEY,
    ProjectId TEXT NOT NULL,
    TriggerReason TEXT,
    ParentSnapshotId TEXT,
    Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Project Metadata
CREATE TABLE Projects (
    Id TEXT PRIMARY KEY,
    Name TEXT NOT NULL,
    WorkspacePath TEXT NOT NULL,
    SdkVersion TEXT,
    LastBuildResult TEXT,
    SnapshotCount INTEGER DEFAULT 0,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    LastModified DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

### H. Workspace Sandbox Manager

**Enforces**:
- No writes outside workspace
- Clean bin/obj folders
- Snapshot diff boundaries
- Safe file deletion

**User never sees path restrictions**

**Implementation**:
```csharp
public class SandboxManager
{
    private readonly string _workspaceRoot;
    
    public bool IsPathSafe(string path)
    {
        var fullPath = Path.GetFullPath(path);
        var workspacePath = Path.GetFullPath(_workspaceRoot);
        
        // Ensure path is within workspace
        return fullPath.StartsWith(workspacePath, StringComparison.OrdinalIgnoreCase);
    }
    
    public async Task WriteFileAsync(string path, string content)
    {
        if (!IsPathSafe(path))
        {
            throw new SecurityException("Attempted write outside workspace");
        }
        
        await File.WriteAllTextAsync(path, content);
    }
    
    public async Task CleanBuildArtifactsAsync(string projectPath)
    {
        // Clean bin/obj silently
        var binPath = Path.Combine(projectPath, "bin");
        var objPath = Path.Combine(projectPath, "obj");
        
        if (Directory.Exists(binPath))
            Directory.Delete(binPath, recursive: true);
        
        if (Directory.Exists(objPath))
            Directory.Delete(objPath, recursive: true);
        
        // No UI notification
    }
}
```

---

### I. Resource Monitor

**Background checks**:
- Disk space
- Memory usage
- CPU usage
- SDK version validity
- NuGet health

**Only surfaces if threshold crossed**

**Implementation**:
```csharp
public class ResourceMonitor
{
    private Timer _monitoringTimer;
    
    public void StartMonitoring()
    {
        _monitoringTimer = new Timer(CheckResources, null, TimeSpan.Zero, TimeSpan.FromMinutes(1));
    }
    
    private void CheckResources(object state)
    {
        // Check disk space
        var driveInfo = new DriveInfo(Path.GetPathRoot(_workspaceRoot));
        var availableGB = driveInfo.AvailableFreeSpace / (1024.0 * 1024 * 1024);
        
        if (availableGB < 1.0)
        {
            // Surface to user
            _uiStateManager.ShowLowDiskSpaceWarning();
        }
        
        // Check memory
        var memoryUsage = GC.GetTotalMemory(forceFullCollection: false);
        var memoryMB = memoryUsage / (1024.0 * 1024);
        
        if (memoryMB > 1000)
        {
            // Log internally, don't show to user yet
            _logger.LogWarning("High memory usage: {MemoryMB} MB", memoryMB);
        }
        
        // Check SDK
        var sdkValid = await ValidateSdkAsync();
        if (!sdkValid)
        {
            _uiStateManager.ShowSdkIssueWarning();
        }
        
        // All checks run silently unless threshold crossed
    }
}
```

---

## 2. Background Processes (Run Continuously)

These run even when user is idle.

---

### A. Project Graph Sync

**Purpose**: Ensure SQLite graph matches file system

**Implementation**:
```csharp
public class ProjectGraphSync
{
    private FileSystemWatcher _watcher;
    
    public void StartWatching(string projectPath)
    {
        _watcher = new FileSystemWatcher(projectPath)
        {
            NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite,
            Filter = "*.cs",
            IncludeSubdirectories = true
        };
        
        _watcher.Changed += OnFileChanged;
        _watcher.Created += OnFileCreated;
        _watcher.Deleted += OnFileDeleted;
        
        _watcher.EnableRaisingEvents = true;
    }
    
    private async void OnFileChanged(object sender, FileSystemEventArgs e)
    {
        // Reconcile state silently
        await _database.UpdateFileMetadataAsync(e.FullPath);
        await _indexer.IncrementalIndexFileAsync(e.FullPath);
    }
}
```

---

### B. Incremental Indexing

**When file changes**: Re-index only that file, update dependency graph

**Implementation**: See Roslyn Indexer `IncrementalIndexFileAsync` above

---

### C. Snapshot Pruning

**If too many snapshots**: Archive older versions, compress diffs

**Implementation**:
```csharp
public class SnapshotPruner
{
    private const int MaxSnapshots = 50;
    
    public async Task PruneOldSnapshotsAsync(string projectId)
    {
        var snapshots = await _database.GetSnapshotsAsync(projectId);
        
        if (snapshots.Count > MaxSnapshots)
        {
            var toArchive = snapshots
                .OrderBy(s => s.Timestamp)
                .Take(snapshots.Count - MaxSnapshots);
            
            foreach (var snapshot in toArchive)
            {
                await ArchiveSnapshotAsync(snapshot.Id);
            }
            
            // Silent operation
            _logger.LogInformation("Archived {Count} old snapshots", toArchive.Count());
        }
    }
}
```

---

### D. AI Context Preparation

**Pre-build retrieval data**: Relevant files cached, symbol references cached, token trimming prepared

**Implementation**:
```csharp
public class AIContextCache
{
    public async Task PrepareContextAsync(string projectPath)
    {
        // Cache relevant files
        var relevantFiles = await _indexer.GetRelevantFilesAsync(projectPath);
        _cache.Set($"relevant_files_{projectPath}", relevantFiles);
        
        // Cache symbol references
        var symbols = await _indexer.GetSymbolGraphAsync();
        _cache.Set($"symbols_{projectPath}", symbols);
        
        // Pre-trim tokens
        var trimmedContext = await _tokenManager.TrimContextAsync(relevantFiles);
        _cache.Set($"trimmed_context_{projectPath}", trimmedContext);
        
        // So AI call is fast
    }
}
```

---

### E. Environment Validation

**On startup**: Verify .NET SDK, MSBuild, NuGet, workspace integrity

**Implementation**:
```csharp
public class EnvironmentValidator
{
    public async Task<ValidationResult> ValidateEnvironmentAsync()
    {
        var results = new List<ValidationIssue>();
        
        // Verify .NET SDK
        var sdkVersion = await GetDotNetSdkVersionAsync();
        if (sdkVersion == null)
        {
            results.Add(new ValidationIssue(".NET SDK not found"));
        }
        
        // Verify MSBuild
        var msbuildPath = await FindMSBuildAsync();
        if (msbuildPath == null)
        {
            results.Add(new ValidationIssue("MSBuild not accessible"));
        }
        
        // Validate NuGet
        var nugetValid = await ValidateNuGetAsync();
        if (!nugetValid)
        {
            results.Add(new ValidationIssue("NuGet configuration issue"));
        }
        
        // Check workspace integrity
        var workspaceValid = Directory.Exists(_workspaceRoot);
        if (!workspaceValid)
        {
            results.Add(new ValidationIssue("Workspace directory missing"));
        }
        
        // Runs silently, only surfaces if critical issue
        return new ValidationResult(results);
    }
}
```

---

## 3. Hidden Safety Mechanisms

Critical but invisible.

---

### A. Operation Whitelist

**LLM cannot**:
- Execute shell
- Access registry
- Write outside workspace
- Modify system files
- Add unsafe dependencies

**Implementation**:
```csharp
public class OperationWhitelist
{
    private static readonly HashSet<string> AllowedOperations = new()
    {
        "ADD_CLASS",
        "MODIFY_METHOD",
        "ADD_PROPERTY",
        "ADD_DEPENDENCY",
        "UPDATE_XAML"
    };
    
    public bool IsOperationAllowed(string operation)
    {
        return AllowedOperations.Contains(operation);
    }
    
    public bool IsDependencySafe(string packageName)
    {
        // Check against known safe packages
        // Reject packages with known vulnerabilities
        return _safetyChecker.IsPackageSafe(packageName);
    }
}
```

---

### B. Dry-Run Patch Validation

**Before applying patch**: Simulate AST modification, validate syntax tree, check node existence

**Implementation**:
```csharp
public async Task<bool> ValidatePatchAsync(Patch patch)
{
    // Simulate AST modification
    var tree = await CSharpSyntaxTree.ParseTextAsync(File.ReadAllText(patch.FilePath));
    var root = await tree.GetRootAsync();
    
    try
    {
        var modifiedRoot = ApplyPatchToNode(root, patch);
        
        // Validate syntax tree
        var diagnostics = modifiedRoot.GetDiagnostics();
        if (diagnostics.Any(d => d.Severity == DiagnosticSeverity.Error))
        {
            return false;
        }
        
        // Check node existence
        if (patch.Operation == PatchOperation.MODIFY_METHOD)
        {
            var method = FindMethod(root, patch.MethodName);
            if (method == null)
            {
                return false;
            }
        }
        
        return true;
    }
    catch
    {
        return false;
    }
}
```

---

### C. Retry Budget Controller

**Prevents**: Infinite AI retry loops, endless build cycles, resource exhaustion

**Implementation**: See Retry Controller above

---

### D. Token Budget Guard

**Prevents**: Sending entire project to AI, context overflow, exponential cost growth

**Implementation**:
```csharp
public class TokenBudgetGuard
{
    private const int MaxTokensPerRequest = 8000;
    
    public async Task<string> TrimContextAsync(List<string> files)
    {
        var context = new StringBuilder();
        var tokenCount = 0;
        
        foreach (var file in files.OrderByDescending(f => _relevanceScorer.Score(f)))
        {
            var fileContent = await File.ReadAllTextAsync(file);
            var fileTokens = _tokenizer.CountTokens(fileContent);
            
            if (tokenCount + fileTokens > MaxTokensPerRequest)
            {
                // Trim file content
                var trimmed = _tokenizer.TrimToTokenLimit(fileContent, MaxTokensPerRequest - tokenCount);
                context.AppendLine(trimmed);
                break;
            }
            
            context.AppendLine(fileContent);
            tokenCount += fileTokens;
        }
        
        return context.ToString();
    }
}
```

---

## 4. What User SHOULD NEVER See (Normal Mode)

In Lovable-style mode:
- ❌ Task graph
- ❌ Patch operations
- ❌ Roslyn AST tree
- ❌ MSBuild raw output
- ❌ NuGet logs
- ❌ Snapshot IDs
- ❌ Retry counts
- ❌ File diffs by default

**All of this exists. But hidden.**

---

## 5. Full Hidden Engine Stack

When user clicks "Generate", this runs silently:

```
Parse Prompt
    ↓
Generate Task Graph (hidden)
    ↓
Snapshot (hidden)
    ↓
Apply Patch (AST) (hidden)
    ↓
Re-index (hidden)
    ↓
dotnet restore (hidden)
    ↓
dotnet build (hidden)
    ↓
Error?
    YES → Classify → AI Fix → Patch → Retry (hidden until attempt 4)
    NO  → Commit
    ↓
Update Preview (visible)
    ↓
Log Version (hidden)
```

**User sees**: Spinner → App appears

---

## Final Reality

You are building:

**A calm UI**

With:
- 10+ background subsystems
- Deterministic state engine
- Safety rollback system
- Continuous indexing
- Intelligent retry loops
- Local build supervision

**That's why Lovable feels simple.**

**Because complexity is hidden — not absent.**

---

## References

- [UI_STATE_MACHINE.md](./UI_STATE_MACHINE.md) - 7 user-visible states
- [ADVANCED_MODE_SPECIFICATION.md](./ADVANCED_MODE_SPECIFICATION.md) - Power user features
- [ORCHESTRATOR_SPECIFICATION.md](./ORCHESTRATOR_SPECIFICATION.md) - State machine
- [ERROR_HANDLING_SPECIFICATION.md](./ERROR_HANDLING_SPECIFICATION.md) - Retry logic
- [DESIGN_PHILOSOPHY.md](./DESIGN_PHILOSOPHY.md) - Lovable-style principles
