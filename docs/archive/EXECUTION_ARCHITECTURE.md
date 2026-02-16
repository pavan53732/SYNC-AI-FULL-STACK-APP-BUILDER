# Execution Architecture - Local Windows Desktop

**Status**: Critical architectural specification - Local-only Windows desktop deployment  
**Scope**: All execution on user's PC (no cloud services)  
**UI Framework**: WinUI 3 (Windows App SDK, .NET 8, MSIX deployment)  
**Audience**: Architecture team, platform engineers

---

## Part 1: Core Principle - The Autonomous Construction Environment

> "Fully internal" does NOT mean "no tools exist"
>
> It means: All tools are **embedded services**, not user-facing developer utilities.
> Users never open an IDE, run CLI commands, or manage build systems.
> The builder acts as a self-contained **Autonomous Software Construction Environment**.

### The Lovable Model (Reference)

Lovable feels completely "internal" and seamless.

But it still runs:

- Node runtime
- Package manager
- Build tool
- Dev server
- Hosting container

**All abstracted behind the UI.**

Your Windows builder must do the same:

- Embed .NET SDK
- Manage MSBuild execution
- Wrap XAML compilation
- Control NuGet restoration

**Users never see or interact with these tools directly.** They are managed entirely by the orchestrator. This "No IDE Required" model ensures that the complexity of the .NET ecosystem is fully abstracted.

---

## Part 2: Local-First Build Model Architecture

### Core Architecture Shift: Local-First Build Model

#### Previous Assumption (Cloud-Based)

Similar to Lovable, Budibase, or other web builders:

- UI in browser or web app
- Execution in cloud container
- Build infrastructure centralized
- Infra complexity hidden

#### New Reality (Self-Contained Windows Construction Kernel)

All **build and execution** on user's PC using **Embedded Tools**:

- WinUI 3 desktop application (modern Windows UI)
- **Embedded MSBuild & Roslyn** (No external SDK required)
- User controls infrastructure
- Complexity is visible and managed by orchestrator

### Cloud Dependencies Clarification

> **IMPORTANT**: "Local-First" refers to the **build infrastructure**, not all components.

**Local Components** (Zero Cloud Dependency):

- ✅ Build system (Embedded Microsoft.Build, NuGet)
- ✅ File system operations (snapshots, rollback)
- ✅ Preview rendering (XAML, code view)
- ✅ Application execution (generated .exe runs in Sandbox)
- ✅ Database (SQLite, local storage)
- ✅ Roslyn code analysis (In-process AST parsing)

**Cloud Components** (Requires Internet):

- ☁️ AI code generation (GPT-4 API calls)
- ☁️ AI SDK (z-ai-web-dev-sdk)
- ☁️ NuGet package downloads (first-time only, then cached)

**Accurate Description**:

> "Self-Contained **Construction Kernel** with Cloud-Powered **Intelligence**"

**User Impact**:

- ✅ Can build and run existing projects **offline** (if packages cached)
- ❌ Cannot generate new code **offline** (requires AI API)
- ✅ Zero setup required (No "Install .NET SDK" step)

### Two-Layer Architecture (Single WinUI 3 App)

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
    │Graph   │ │Conflict│ │Sandbox    │
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
## 2. Database Schema
> **Source of Truth**: See [DATABASE_SPECIFICATION.md](./DATABASE_SPECIFICATION.md) for the definitive schema definition.

The Execution Context relies on the `files`, `symbols`, `symbol_edges`, `syntax_nodes`, and `snapshots` tables defined in the master schema.


Run entirely on user's PC. Zero cloud.
```

### Critical Difference: Local vs. Cloud

| Factor                 | Cloud Model (Lovable)  | Local-Only (Your Builder)                    |
| ---------------------- | ---------------------- | -------------------------------------------- |
| **Execution Location** | Cloud container        | User's PC                                    |
| **Infrastructure**     | Fixed, managed         | Variable, on user machine                    |
| **Isolation**          | Container-level        | Filesystem + process-level                   |
| **SDK Version**        | Fixed in container     | User's installed version                     |
| **Error Handling**     | Retry in cloud         | Must retry locally                           |
| **Resource Limits**    | Infinite (cloud scale) | Limited (PC RAM, disk)                       |
| **Logging**            | Centralized            | Local persistence                            |
| **Antivirus**          | Managed                | User's settings apply                        |
| **Disk Requirements**  | Server managed         | User's available space                       |
| **Network**            | Internal to datacenter | User's connection (if using cloud AI Engine) |
| **Code Execution**     | Trusted (we control)   | Untrusted (user generated)                   |
| **Determinism**        | Can hide infra issues  | Must handle all variability                  |

---

## Part 3: The 6 Embedded Subsystems

### 3.1 Filesystem Sandbox Subsystem

#### Purpose

Prevent cross-project contamination, enable snapshots, support rollback.

#### Architecture

```
Builder Workspace Root
├── Projects/
│   ├── Project_A/
│   │   ├── src/
│   │   ├── bin/build/
│   │   ├── .snapshots/
│   │   │   ├── snapshot_001.zip
│   │   │   ├── snapshot_002.zip
│   │   │   └── snapshot_003.zip
│   │   └── .diffs/
│   │       ├── diff_001-002.patch
│   │       └── diff_002-003.patch
│   │
│   └── Project_B/
│       └── ... (same structure)
│
├── Temp/
│   ├── build_workspace_001/
│   ├── build_workspace_002/
│   └── (clean after each build)
│
└── Cache/
    ├── roslyn_symbols/
    ├── embeddings/
    └── dependency_graph/
```

#### Key Properties

1. **Isolation**: Each project in separate directory tree
2. **Snapshots**: ZIP archives of known-good states
3. **Diffs**: Patch files for version control
4. **Temp Workspace**: Isolated build environment per operation
5. **Cleanup**: Automatic cleanup after build completes

#### Implementation (Core)

```csharp
public class FileSystemSandbox
{
    private readonly string _projectRoot;
    private readonly string _tempWorkspace;

    /// Create isolated workspace for this build
    public async Task<IsolatedBuildEnvironment> CreateIsolatedWorkspaceAsync()
    {
        var timestamp = DateTime.Now.Ticks;
        var workspace = Path.Combine(_tempWorkspace, $"build_{timestamp}");
        Directory.CreateDirectory(workspace);

        return new IsolatedBuildEnvironment(workspace);
    }

    /// Create snapshot of current state (for rollback)
    public async Task<string> CreateSnapshotAsync(string projectId)
    {
        var snapshotDir = Path.Combine(_projectRoot, projectId, ".snapshots");
        var snapshotId = $"snapshot_{DateTime.Now:yyyyMMdd_HHmmss}";
        var snapshotPath = Path.Combine(snapshotDir, $"{snapshotId}.zip");

        // ZIP all project files
        ZipFile.CreateFromDirectory(
            Path.Combine(_projectRoot, projectId, "src"),
            snapshotPath);

        return snapshotPath;
    }

    /// Rollback to previous snapshot
    public async Task RollbackToSnapshotAsync(string projectId, string snapshotPath)
    {
        var projectSrc = Path.Combine(_projectRoot, projectId, "src");

        // Clear current files
        Directory.Delete(projectSrc, recursive: true);

        // Restore from snapshot
        ZipFile.ExtractToDirectory(snapshotPath, projectSrc);
    }

    /// Cleanup temporary workspace
    public void CleanupWorkspace(IsolatedBuildEnvironment env)
    {
        if (Directory.Exists(env.WorkspacePath))
        {
            Directory.Delete(env.WorkspacePath, recursive: true);
        }
    }
}
```

#### Local-Only Enhancements

##### Disk Space Validation

```csharp
public class DiskSpaceValidator
{
    public bool HasSufficientSpace(string projectPath, long requiredBytes)
    {
        var drive = new DriveInfo(Path.GetPathRoot(projectPath));
        return drive.AvailableFreeSpace > requiredBytes;
    }

    public async Task<bool> ValidateBeforeSnapshotAsync(string projectPath)
    {
        var projectSize = GetDirectorySize(projectPath);
        var requiredSpace = projectSize * 2; // Need 2x for compression

        return HasSufficientSpace(projectPath, requiredSpace);
    }
}
```

##### Snapshot Compression Strategies

```csharp
// For local-only: Optimize snapshot size
public async Task<string> CreateCompressedSnapshotAsync(string projectId)
{
    // Exclude bin/, obj/, .vs/ from snapshots
    var excludePatterns = new[] { "bin", "obj", ".vs", "node_modules" };

    // Create selective ZIP
    using var archive = ZipFile.Open(snapshotPath, ZipArchiveMode.Create);
    foreach (var file in GetProjectFiles(projectId, excludePatterns))
    {
        archive.CreateEntryFromFile(file, GetRelativePath(file));
    }
}
```

##### Path Validation Security

```csharp
public class PathValidator
{
    private readonly string _sandboxRoot;

    public bool IsPathSafe(string requestedPath)
    {
        var fullPath = Path.GetFullPath(requestedPath);
        var rootPath = Path.GetFullPath(_sandboxRoot);

        // Prevent directory traversal attacks
        return fullPath.StartsWith(rootPath, StringComparison.OrdinalIgnoreCase);
    }
}
```

---

### 3.2 Execution Kernel Subsystem (Embedded)

#### Purpose

Manage isolated .NET execution using **in-process Microsoft.Build APIs** (no CLI).

#### Embedded SDK Strategy (Self-Contained)

**Selected Strategy**: **Option B (Embed Required Components)**

- **Why**: Zero dependency on user environment.
- **Implementation**: We ship `Microsoft.Build.*` assemblies and a bundled .NET runtime.
- **Bootstrapper**: Use `MSBuildLocator` to load the bundled MSBuild context.

#### Implementation (API-Based)

```csharp
using Microsoft.Build.Evaluation;
using Microsoft.Build.Execution;
using Microsoft.Build.Framework;
using Microsoft.Build.Locator;

public class ExecutionKernel
{
    private readonly ILogger _logger;
    private readonly FileSystemSandbox _sandbox;
    private static bool _isInitialized;

    public ExecutionKernel(ILogger logger, FileSystemSandbox sandbox)
    {
        _logger = logger;
        _sandbox = sandbox;
        InitializeMSBuild();
    }

    /// <summary>
    /// One-time initialization of MSBuild Locator
    /// </summary>
    private static void InitializeMSBuild()
    {
        if (!_isInitialized)
        {
            // Locate the embedded SDK/MSBuild instance
            MSBuildLocator.RegisterDefaults();
            _isInitialized = true;
        }
    }

    /// <summary>
    /// Builds project using Microsoft.Build APIs (No CLI)
    /// </summary>
    public async Task<BuildResult> BuildAsync(
        string projectPath,
        string configuration = "Debug")
    {
        return await Task.Run(() =>
        {
            var projectCollection = new ProjectCollection();

            try
            {
                // Load project into memory
                var project = projectCollection.LoadProject(projectPath);

                // Set properties
                project.SetProperty("Configuration", configuration);
                project.SetProperty("Platform", "Any CPU");

                // Configure logger
                var buildLogger = new StructuredLogger();

                // Create build parameters
                var buildParameters = new BuildParameters(projectCollection)
                {
                    Loggers = new[] { buildLogger },
                    MaxNodeCount = Environment.ProcessorCount // Parallel build
                };

                // Create build request
                var buildRequest = new BuildRequestData(
                    project.CreateProjectInstance(),
                    new[] { "Restore", "Build" } // Run Restore then Build
                );

                // Execute Build
                var result = BuildManager.DefaultBuildManager
                    .Build(buildParameters, buildRequest);

                return new BuildResult
                {
                    Success = result.OverallResult == BuildResultCode.Success,
                    Output = buildLogger.Output,
                    Errors = buildLogger.Errors,
                    ExitCode = result.OverallResult == BuildResultCode.Success ? 0 : 1
                };
            }
            finally
            {
                projectCollection.Dispose();
            }
        });
    }

    /// <summary>
    /// Captures build output efficiently
    /// </summary>
    private class StructuredLogger : ILogger
    {
        public string Output { get; private set; }
        public string Errors { get; private set; }
        // Implementation details...
    }
}
```

#### Restore Strategy

Instead of `dotnet restore` CLI, we include the `Restore` target in the build request:

```csharp
new[] { "Restore", "Build" }
```

This leverages the internal NuGet targets linked in the embedded SDK.

#### Embedded Environment Integrity

##### Environment Verification

```csharp
public class EmbeddedEnvironmentValidator
{
    private readonly string _embeddedSdkPath;

    public bool ValidateEnvironment()
    {
        // 1. Verify MSBuild assemblies are present
        if (!File.Exists(Path.Combine(_embeddedSdkPath, "Microsoft.Build.dll")))
            return false;

        // 2. Verify .NET Runtime is functional
        // (Self-check handled by app startup)

        return true;
    }
}
```

##### Timeout Handling with Cancellation

```csharp
public async Task<BuildResult> BuildWithTimeoutAsync(
    string projectPath,
    TimeSpan timeout,
    CancellationToken cancellationToken = default)
{
    using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
    cts.CancelAfter(timeout);

    try
    {
        // Use the new API-based BuildAsync
        return await _kernel.BuildAsync(projectPath, "Debug");
    }
    catch (OperationCanceledException)
    {
        return new BuildResult
        {
            Success = false,
            Errors = "Build timed out."
        };
    }
}
```

            Success = false,
            Errors = $"Build timed out after {timeout.TotalSeconds} seconds",
            TimedOut = true
        };
    }

}

````

##### Real-Time Progress Reporting
```csharp
public async Task<BuildResult> BuildWithProgressAsync(
    string projectPath,
    IProgress<BuildPhase>? progress = null)
{
    progress?.Report(new BuildPhase { Phase = "Restoring packages", Percentage = 10 });
    await RestoreAsync(projectPath);

    progress?.Report(new BuildPhase { Phase = "Compiling", Percentage = 50 });
    var result = await BuildAsync(projectPath);

    progress?.Report(new BuildPhase { Phase = "Complete", Percentage = 100 });
    return result;
}
````

##### Resource Throttling

```csharp
private async Task<BuildResult> BuildWithThrottlingAsync(string projectPath)
{
    // Respect user's machine
    var processorCount = Environment.ProcessorCount;
    var maxParallelism = Math.Max(1, processorCount - 1);  // Leave one core free

    var result = await BuildAsync(
        projectPath,
        additionalArgs: $"/m:{maxParallelism}");

    return result;
}
```

---

### 3.3 Roslyn Code Intelligence Service

#### Purpose

AST parsing, symbol resolution, safe patching, impact analysis.
All internal — not in frontend.

#### Architecture

```
Code Intelligence Service
├─ Symbol Graph Builder
│  ├─ ParseAssembly()
│  ├─ ExtractSymbols()
│  └─ BuildReferenceGraph()
│
├─ File Impact Analyzer
│  ├─ GetFileDependencies()
│  ├─ GetDependentFiles()
│  ├─ CalculateChangeImpact()
│  └─ SuggestFilesForRegen()
│
└─ AST Navigator
   ├─ FindClass()
   ├─ FindMethod()
   ├─ GetReferences()
   └─ GetDependencies()
```

#### Core Implementation

```csharp
public class RoslynCodeIntelligenceService
{
    private readonly string _projectPath;
    private Compilation? _cachedCompilation;
    private Dictionary<string, ISymbol>? _symbolIndex;

    /// Build or update symbol index
    public async Task IndexProjectAsync()
    {
        var workspace = MSBuildWorkspace.Create();
        var project = await workspace.OpenProjectAsync(_projectPath);
        var compilation = await project.GetCompilationAsync();

        _cachedCompilation = compilation;
        _symbolIndex = new Dictionary<string, ISymbol>();

        // Index all symbols
        IndexSymbolsRecursive(compilation.GlobalNamespace);
    }

    /// Find all classes in project
    public async Task<List<ClassDefinition>> FindAllClassesAsync()
    {
        var classes = new List<ClassDefinition>();

        var symbolsByKind = _symbolIndex
            .Where(kvp => kvp.Value.Kind == SymbolKind.NamedType)
            .Cast<KeyValuePair<string, INamedTypeSymbol>>();

        foreach (var (name, symbol) in symbolsByKind)
        {
            classes.Add(new ClassDefinition
            {
                FullName = symbol.ToDisplayString(),
                FilePath = symbol.Locations.First().SourceTree?.FilePath,
                Methods = symbol.GetMembers().OfType<IMethodSymbol>().ToList(),
                Properties = symbol.GetMembers().OfType<IPropertySymbol>().ToList()
            });
        }

        return classes;
    }

    /// Analyze impact of changing a file
    public async Task<FileImpactAnalysis> AnalyzeChangeImpactAsync(string filePath)
    {
        var syntaxTree = _cachedCompilation.SyntaxTrees
            .FirstOrDefault(st => st.FilePath == filePath);

        if (syntaxTree == null)
            throw new FileNotFoundException(filePath);

        var semanticModel = _cachedCompilation.GetSemanticModel(syntaxTree);

        // Find all symbols defined in this file
        var root = syntaxTree.GetRoot();
        var declaredSymbols = FindDeclaredSymbols(root, semanticModel);

        // Find all files that reference these symbols
        var dependentFiles = new HashSet<string>();
        foreach (var symbol in declaredSymbols)
        {
            var references = SymbolFinder.FindReferencesAsync(symbol, _cachedCompilation).Result;
            foreach (var reference in references)
            {
                foreach (var location in reference.Locations)
                {
                    if (location.SourceTree?.FilePath != filePath)
                    {
                        dependentFiles.Add(location.SourceTree!.FilePath);
                    }
                }
            }
        }

        return new FileImpactAnalysis
        {
            FilePath = filePath,
            AffectedFiles = dependentFiles.ToList(),
            ImpactLevel = dependentFiles.Count switch
            {
                0 => ImpactLevel.Isolated,
                <= 5 => ImpactLevel.Low,
                <= 20 => ImpactLevel.Medium,
                _ => ImpactLevel.High
            }
        };
    }

    private void IndexSymbolsRecursive(INamespaceSymbol namespaceSymbol)
    {
        foreach (var member in namespaceSymbol.GetMembers())
        {
            if (member is INamedTypeSymbol namedType)
            {
                _symbolIndex![member.Name] = member;
                IndexSymbolsRecursive(namedType);
            }
        }
    }
}

public class FileImpactAnalysis
{
    public string FilePath { get; set; }
    public List<string> AffectedFiles { get; set; }
    public ImpactLevel ImpactLevel { get; set; }
}

public enum ImpactLevel { Isolated, Low, Medium, High }
```

#### Local-Only Allocation Strategies

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

#### Key Constraint: UI Thread Safety

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

#### Use Cases

- **Smart Retrieval**: Know exactly which files to send to AI Engine
- **Impact Analysis**: Warn if change affects many files
- **Safe Patching**: AST-aware modifications
- **Conflict Detection**: Prevent overlapping changes

---

### 3.4 Patch Engine (Transaction-Based)

#### Purpose

No raw file writes. All mutations through structured patching.

#### Architecture

```
Patch Engine
├─ C# Syntax Tree Diffing
│  ├─ CompareStructures()
│  └─ GeneratePatches()
│
├─ XAML Node Modification
│  ├─ FindElement()
│  ├─ ModifyAttribute()
│  └─ AddChild()
│
├─ Conflict Detection
│  ├─ DetectOverlapping Changes()
│  └─ ResolveConflicts()
│
└─ Transaction Manager
   ├─ BeginTransaction()
   ├─ ApplyPatch()
   ├─ Rollback()
   └─ Commit()
```

#### Implementation Pattern

```csharp
public class TransactionalPatchEngine
{
    private readonly FileSystemSandbox _sandbox;
    private Stack<ISnapshot> _undoStack = new();

    /// Begin patch operation
    public async Task<IPatchTransaction> BeginPatchAsync(string filePath)
    {
        // Create snapshot before patching
        var snapshot = await _sandbox.CreateSnapshotAsync(Path.GetDirectoryName(filePath)!);

        return new PatchTransaction(filePath, snapshot, _undoStack);
    }
}

public interface IPatchTransaction : IAsyncDisposable
{
    Task AddAttributeAsync(string className, string attributeName);
    Task AddUsingAsync(string namespaceName);
    Task ModifyPropertyAsync(string propertyName, string newValue);
    Task AddMethodAsync(string methodCode);
    Task CommitAsync();
    Task RollbackAsync();
}

public class PatchTransaction : IPatchTransaction
{
    private readonly string _filePath;
    private readonly string _snapshotPath;
    private List<Patch> _patches = new();
    private bool _committed = false;

    public async Task AddAttributeAsync(string className, string attributeName)
    {
        var syntax = CSharpSyntaxTree.ParseText(await File.ReadAllTextAsync(_filePath));
        var root = syntax.GetCompilationUnitSyntax();

        // Find class
        var classDecl = root.DescendantNodes().OfType<ClassDeclarationSyntax>()
            .FirstOrDefault(c => c.Identifier.Text == className);

        if (classDecl == null)
            throw new InvalidOperationException($"Class {className} not found");

        // Add attribute
        var attr = SyntaxFactory.Attribute(SyntaxFactory.IdentifierName(attributeName));
        var newClass = classDecl.AddAttributeLists(
            SyntaxFactory.AttributeList().AddAttributes(attr));

        var newRoot = root.ReplaceNode(classDecl, newClass);

        _patches.Add(new Patch
        {
            Type = PatchType.AddAttribute,
            Description = $"Added @{attributeName} to {className}",
            NewContent = newRoot.ToFullString()
        });
    }

    public async Task CommitAsync()
    {
        if (_committed)
            throw new InvalidOperationException("Transaction already committed");

        // Write all patches to file in order
        var content = await File.ReadAllTextAsync(_filePath);
        foreach (var patch in _patches)
        {
            content = patch.NewContent;
        }

        await File.WriteAllTextAsync(_filePath, content);
        _committed = true;
    }

    public async Task RollbackAsync()
    {
        if (_committed)
            throw new InvalidOperationException("Cannot rollback committed transaction");

        // Rollback handled by snapshot restore
        _patches.Clear();
    }

    public async ValueTask DisposeAsync()
    {
        if (!_committed)
        {
            await RollbackAsync();
        }
    }
}
```

#### Guarantees

- **Atomic**: Entire patch succeeds or fails
- **Reversible**: Snapshot available for rollback
- **Conflict-Free**: Detect overlapping changes
- **Auditable**: Track every patch

---

### 3.5 Orchestrator Engine

#### Purpose

Task graph, deterministic state machine, retry limits, error classification.
The brain of the system.

**See [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) for complete details.**

---

### 3.6 Memory + Project Graph (SQLite)

#### Purpose

Persistent storage of:

- Files
- Symbols
- Dependencies
- Errors
- Architectural decisions
- User constraints

#### Schema

```sql
-- Core project data
CREATE TABLE projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    path TEXT NOT NULL,
    created_at DATETIME,
    updated_at DATETIME
);

-- File index
CREATE TABLE files (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    file_path TEXT,
    content_hash TEXT,
    content_size INT,
    indexed_at DATETIME,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Symbol index
CREATE TABLE symbols (
    id TEXT PRIMARY KEY,
    file_id TEXT,
    symbol_name TEXT,
    symbol_kind TEXT,  -- class, method, property, etc.
    line_number INT,
    namespace TEXT,
    FOREIGN KEY (file_id) REFERENCES files(id)
);

-- Dependencies
CREATE TABLE dependencies (
    id TEXT PRIMARY KEY,
    source_file_id TEXT,
    target_symbol_id TEXT,
    dependency_type TEXT,  -- references, inherits, uses, etc.
    FOREIGN KEY (source_file_id) REFERENCES files(id),
    FOREIGN KEY (target_symbol_id) REFERENCES symbols(id)
);

-- Build errors (for pattern matching)
CREATE TABLE build_errors (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    error_code TEXT,  -- CS0123, XDG001, etc.
    error_message TEXT,
    file_id TEXT,
    line_number INT,
    solution TEXT,  -- How we fixed it last time
    occurrence_count INT,
    FOREIGN KEY (project_id) REFERENCES projects(id),
    FOREIGN KEY (file_id) REFERENCES files(id)
);

-- Architectural decisions
CREATE TABLE architectural_decisions (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    decision_type TEXT,  -- naming_convention, layer_structure, etc.
    decision_value TEXT,
    reasoning TEXT,
    applied_at DATETIME,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Embeddings (for semantic search)
CREATE TABLE embeddings (
    id TEXT PRIMARY KEY,
    file_id TEXT,
    embedding BLOB,  -- Vector embedding
    embedding_model TEXT,  -- e.g., "text-embedding-3-small"
    FOREIGN KEY (file_id) REFERENCES files(id)
);

-- Snapshots
CREATE TABLE snapshots (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    snapshot_path TEXT,
    created_at DATETIME,
    description TEXT,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Execution log
CREATE TABLE execution_log (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    event_type TEXT,  -- task_started, task_completed, build_failed, etc.
    event_data JSON,
    timestamp DATETIME,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);
```

#### Usage Pattern

```csharp
public class ProjectGraphService
{
    private readonly SQLiteConnection _db;

    /// Get all symbols in project
    public async Task<List<Symbol>> GetProjectSymbolsAsync(string projectId)
    {
        return await _db.QueryAsync<Symbol>(
            @"SELECT s.* FROM symbols s
              JOIN files f ON s.file_id = f.id
              WHERE f.project_id = @projectId",
            new { projectId });
    }

    /// Find dependencies for a file
    public async Task<List<Dependency>> GetFileDependenciesAsync(string fileId)
    {
        return await _db.QueryAsync<Dependency>(
            @"SELECT d.* FROM dependencies d
              WHERE d.source_file_id = @fileId",
            new { fileId });
    }

    /// Get previous solutions for error
    public async Task<List<ErrorSolution>> FindErrorSolutionsAsync(string errorCode)
    {
        return await _db.QueryAsync<ErrorSolution>(
            @"SELECT error_message, solution FROM build_errors
              WHERE error_code = @errorCode
              ORDER BY occurrence_count DESC
              LIMIT 5",
            new { errorCode });
    }

    /// Store architectural decision
    public async Task RecordDecisionAsync(string projectId, string decisionType, string value)
    {
        await _db.ExecuteAsync(
            @"INSERT INTO architectural_decisions
              (id, project_id, decision_type, decision_value, applied_at)
              VALUES (newid(), @projectId, @decisionType, @value, Now())",
            new { projectId, decisionType, value });
    }
}
```

---

## Part 4: Security & Isolation (Executing Untrusted Code)

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

### Explicit Security Constraints

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

## Part 5: Machine Variability Handling

### The Local-Only Challenge (Embedded Edition)

Unlike cloud environments with fixed infrastructure, local execution must handle:

| Issue                          | Solution                                  |
| ------------------------------ | ----------------------------------------- |
| **Embedded Runtime Corrupted** | App self-repair / Reinstall prompt        |
| **Missing Windows Runtime**    | Detected by MSIX installer                |
| **Antivirus blocking MSBuild** | Sign binaries with trusted cert           |
| **Low disk space**             | Check before build, warn user             |
| **Broken NuGet cache**         | Clear local cache, retry restore          |
| **Limited RAM**                | Use incremental builds, limit parallelism |
| **Slow disk**                  | Use smaller snapshots, avoid full ZIP     |
| **Power loss during build**    | Snapshot before = safe recovery           |

### Error Handling Architecture

```csharp
public class MachineVariabilityHandler
{
    /// Detect and handle common local issues
    public async Task<BuildResult> BuildWithFallbacksAsync(
        string projectPath,
        IProgress<BuildPhase>? progress = null)
    {
        // Phase 1: Verify Embedded Environment
        if (!_envValidator.ValidateEnvironment())
        {
             return BuildResult.CriticalFailure("Embedded SDK is corrupted.");
        }

        // Phase 2: Attempt restore (In-Process)
        var restoreResult = await _kernel.BuildAsync(projectPath, "Debug"); // Restore is part of build targets
        if (!restoreResult.Success)
        {
            // Try clearing cache + retry
            if (restoreResult.HasNuGetConnectionError)
            {
                _logger.LogInformation("Clearing NuGet cache...");
                await ClearNuGetCacheAsync();

                restoreResult = await _kernel.BuildAsync(projectPath, "Debug");
                if (!restoreResult.Success)
                    return restoreResult;
            }
        }

        return restoreResult;
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
}
```

---

## Part 6: UI Framework - WinUI 3

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

## Part 7: System-Level Architecture

Complete stack when fully internalized:

```
┌──────────────────────────────────────────────────┐
│          WinUI 3 Frontend (Thin Layer)           │
│    (Prompt input, progress, app preview)         │
└──────────────┬───────────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────┐
│       Orchestrator API / HTTP Layer              │
│   (Task dispatch, status queries, results)       │
└──────────────┬───────────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────┐
│         Orchestrator Engine (State Machine)      │
│  (Task graph, retries, error classification)     │
└──────────────┬───────────────────────────────────┘
               │
    ┌──────────┼──────────┐
    │          │          │
┌───▼───┐  ┌──▼───┐  ┌──▼─────┐
│ Code  │  │Patch │  │Execute │
│ Intel │  │Engine│  │Kernel  │
├───────┤  ├──────┤  ├────────┤
│Roslyn │  │Transac││MSBuild │
│Indexer│  │tional ││NuGet   │
│Symbol │  │Writes ││DotNet  │
│Graph  │  │ Rollb ││dotnet  │
└───┬───┘  └──┬────┘  └───┬────┘
    │         │          │
    └─────────┼──────────┘
              │
    ┌─────────▼────────────┐
    │   File System        │
    │   Sandbox            │
    ├──────────────────────┤
    │ Isolated Projects    │
    │ Snapshots + Diffs    │
    │ Temp Workspaces      │
    └────────┬─────────────┘
             │
    ┌────────▼──────────────┐
    │  SQLite Graph DB      │
    ├───────────────────────┤
    │ Symbols               │
    │ Dependencies          │
    │ Errors                │
    │ Decisions             │
    │ Execution Log         │
    └───────────────────────┘
```

---

## Part 8: Deployment Decision Point

### Choice A: Local Desktop Application

**What runs where:**

- UI: On user's machine (WinUI 3)
- Orchestrator: On user's machine
- Execution Kernel: On user's machine
- Databases: On user's disk

**Pros:**

- No network latency
- User owns all code
- Works offline
- No cloud costs

**Cons:**

- Requires .NET 8 SDK on user machine
- Large disk space (snapshots, embeddings)
- Update distribution complexity

**Best for:** Power users, developers, enterprise deployments

---

### Choice B: Server-Hosted (Lovable Model)

**What runs where:**

- UI: Browser or Electron on user's machine (thin)
- Orchestrator: On cloud server
- Execution Kernel: On cloud server
- Databases: On cloud server

**Pros:**

- Update users automatically
- Leverage cloud compute (scale builds)
- Centralized control
- Easy to monetize

**Cons:**

- Network latency on each operation
- Users don't own infrastructure
- Privacy concerns
- Service availability dependency

**Best for:** SaaS, public platform, managed service

---

### Choice C: Hybrid (Recommended)

**What runs where:**

- UI: WinUI 3 on local machine
- Orchestrator: Pluggable (local or cloud)
- Execution Kernel: Configurable
  - Default: Local (for development)
  - Option: Cloud build agent (for scale)
- Databases: Local cache + cloud sync

**Pros:**

- Dev speed (local builds)
- Production scale (cloud when needed)
- Offline capability
- Privacy flexible

**Cons:**

- Architecture complexity
- Sync logic required
- Fallback handling needed

**Best for:** Professional builders, team workflows

---

## Part 9: Required for True Internalization

Minimum checklist:

- ✅ Filesystem Sandbox (isolated projects, snapshots, rollback)
- ✅ Execution Kernel (managed .NET, MSBuild, NuGet)
- ✅ Code Intelligence (Roslyn indexing, symbol graph)
- ✅ Patch Engine (transactional, conflict-detecting, reversible)
- ✅ Orchestrator (deterministic state machine, task graph)
- ✅ Memory Layer (SQLite project graph, error patterns, decisions)
- ✅ Process Isolation (each build isolated, resource limits)
- ✅ Error Classification (before retry, actionable fixes)
- ✅ Snapshot Support (rollback capability)
- ✅ Deployment Model (local, cloud, or hybrid)

---

## Part 10: Critical Warning

If you try to build without these subsystems:

```
AI Engine generates code
  ↓
Write files directly
  ↓
Run dotnet build (CLI)
  ↓
Error! (unstructured output)
  ↓
Retry with fresh generation
  ↓
Overwrites good code
  ↓
Cascading failures (Project broken)
```

**vs. With proper internalization (Embedded SDK):**

```
AI Engine generates code
  ↓
Transactional patch (Roslyn)
  ↓
Run In-Process Build (Microsoft.Build)
  ↓
Error! (structured diagnostics)
  ↓
Fix Agent patches (silent)
  ↓
Run In-Process Build again
  ↓
Success!
  ↓
User sees: "Done ✅"
```

---

## Part 11: Concurrency & Serialization Rules

**Strict Execution Policy**:
To ensure deterministic state and prevent race conditions in the embedded environment:

**✅ Parallel Execution Allowed**:

- Planning Layer (Task Graph creation)
- AI Code Generation (LLM streaming)
- Retrieval (Vector search, Read-only graph query)

**🔒 Strictly Serialized (Single Thread)**:

- **Patch Application** (Roslyn AST modification)
- **Indexing** (Updating SQLite graph)
- **Restore operations** (NuGet graph modification)
- **Build execution** (MSBuild via BuildManager)
- **Snapshot Commit** (Filesystem write)

> **Visual Rule**: "Reads can be parallel. Writes must be serial."

```

---

## Part 11: Implementation Roadmap

### Phase 1: Foundation
1. Filesystem Sandbox (week 1)
2. Orchestrator (week 2-3) — with Execution Kernel hooks
3. Project Graph DB (week 3)

### Phase 2: Code Intelligence
4. Roslyn Indexing Service (week 4-5)
5. Impact Analysis (week 5)
6. Embedding Integration (week 6)

### Phase 3: Mutation Safety
7. Patch Engine (transaction-based) (week 7-8)
8. Conflict Detection (week 8)
9. Rollback System (week 9)

### Phase 4: Execution
10. Execution Kernel (managed .NET) (week 10-11)
11. Error Classification (week 11)
12. Auto-Fix Strategies (week 12)

### Phase 5: Production
13. Testing & Hardening (week 13-14)
14. Deployment Model (week 14-15)
15. Documentation (ongoing)

---

## Part 12: Summary

> You cannot eliminate compile processes, runtime environments, or build systems.
>
> You can only encapsulate them.
>
> "Fully internal" means they are embedded services, not external tools.
>
> Users experience seamlessness.
> Engineers know: tools are bundled, not gone.

The system stays reliable because:
- Everything is deterministic (orchestrator)
- Everything is isolated (sandbox)
- Everything is reversible (snapshots)
- Everything is classified (error detection)
- Everything is transactional (patch engine)

Build for resilience, not simplicity.

---

## Part 13: Local-Only Implementation Reality

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
```
