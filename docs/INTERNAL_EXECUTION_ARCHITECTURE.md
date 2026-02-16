# Internal Execution Architecture

**Status**: Critical architectural decision - Response 5 validation  
**Topic**: What "fully internal" actually means at system level  
**Audience**: Architecture team, platform engineers  

---

## Core Principle

> "Fully internal" does NOT mean "no tools exist"
> 
> It means: All tools are embedded services, abstracted from users.
> Users never touch IDE, CLI, or external build systems.
> Everything happens inside your platform.

---

## The Lovable Model (Reference)

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

**Users never see these tools.**

---

## 1️⃣ Filesystem Sandbox Subsystem

### Purpose
Prevent cross-project contamination, enable snapshots, support rollback.

### Architecture
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

### Key Properties
1. **Isolation**: Each project in separate directory tree
2. **Snapshots**: ZIP archives of known-good states
3. **Diffs**: Patch files for version control
4. **Temp Workspace**: Isolated build environment per operation
5. **Cleanup**: Automatic cleanup after build completes

### Implementation Requirements

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

---

## 2️⃣ Internal .NET Execution Kernel

### Purpose
Managed abstraction layer for .NET SDK, MSBuild, NuGet.
Users never interact with CLI or build system — all hidden.

### Architecture
```
┌─────────────────────────────────────┐
│   Orchestrator (Task Engine)        │
└──────────────────┬──────────────────┘
                   │
┌──────────────────▼──────────────────┐
│  Execution Kernel (Managed API)     │
├─────────────────────────────────────┤
│ • RunNuGetRestore()                 │
│ • RunDotNetBuild()                  │
│ • RunMigrations()                   │
│ • RunTests()                        │
│ • KillRunawayProcess()              │
└──────────────────┬──────────────────┘
                   │
┌──────────────────▼──────────────────┐
│  Embedded Runtimes (Hidden)         │
├─────────────────────────────────────┤
│ • .NET SDK 8.0                      │
│ • MSBuild                           │
│ • NuGet CLI                         │
│ • dotnet CLI                        │
└─────────────────────────────────────┘
```

### Implementation

```csharp
public class ExecutionKernel
{
    private readonly string _dotnetExePath;
    private readonly string _projectPath;
    private readonly IsolatedBuildEnvironment _environment;
    private readonly ProcessPoolManager _processPool;
    
    /// Restore NuGet packages
    public async Task<ExecutionResult> RestoreNuGetAsync()
    {
        var process = _processPool.GetProcess();
        
        var result = await RunManagedProcessAsync(
            _dotnetExePath,
            "restore",
            workingDirectory: _projectPath,
            timeout: TimeSpan.FromMinutes(5),
            captureOutput: true);
        
        // Check for NuGet-specific errors
        if (result.ExitCode != 0)
        {
            var errorClassification = ClassifyNuGetError(result.StdErr);
            return new ExecutionResult
            {
                Success = false,
                ErrorType = errorClassification.Type,
                ErrorMessage = result.StdErr,
                IsRetryable = errorClassification.IsRetryable
            };
        }
        
        return new ExecutionResult { Success = true };
    }
    
    /// Build project
    public async Task<ExecutionResult> BuildAsync()
    {
        var result = await RunManagedProcessAsync(
            _dotnetExePath,
            "build --configuration Release",
            workingDirectory: _projectPath,
            timeout: TimeSpan.FromMinutes(10),
            captureOutput: true);
        
        if (result.ExitCode != 0)
        {
            // Parse MSBuild errors
            var errors = ParseMSBuildErrors(result.StdErr);
            
            return new ExecutionResult
            {
                Success = false,
                Errors = errors,
                IsRetryable = errors.Any(e => e.IsRetryable)
            };
        }
        
        return new ExecutionResult
        {
            Success = true,
            ArtifactPath = Path.Combine(_projectPath, "bin", "Release")
        };
    }
    
    /// Run migrations (database setup)
    public async Task<ExecutionResult> RunMigrationsAsync()
    {
        return await RunManagedProcessAsync(
            _dotnetExePath,
            "ef database update",
            workingDirectory: _projectPath,
            timeout: TimeSpan.FromMinutes(5));
    }
    
    /// Private: Managed process execution with resource limits
    private async Task<ProcessOutput> RunManagedProcessAsync(
        string executable,
        string arguments,
        string workingDirectory,
        TimeSpan timeout,
        bool captureOutput = false)
    {
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = executable,
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
            
            // Set resource limits
            SetProcessResourceLimits(process, timeout);
            
            // Wait with timeout
            var completed = process.WaitForExit((int)timeout.TotalMilliseconds);
            
            if (!completed)
            {
                process.Kill();
                return new ProcessOutput
                {
                    ExitCode = -1,
                    StdErr = "Process exceeded timeout"
                };
            }
            
            return new ProcessOutput
            {
                ExitCode = process.ExitCode,
                StdOut = captureOutput ? process.StandardOutput.ReadToEnd() : "",
                StdErr = captureOutput ? process.StandardError.ReadToEnd() : ""
            };
        }
        finally
        {
            process.Dispose();
        }
    }
    
    private void SetProcessResourceLimits(Process process, TimeSpan timeout)
    {
        // Windows: Set job object limits if needed
        // Prevent runaway processes from consuming system resources
        
        // Example: Limit memory (Windows-specific)
        // JobObjectManager.SetMemoryLimit(process, 2_000_000_000); // 2GB max
    }
}

public class ExecutionResult
{
    public bool Success { get; set; }
    public string? ErrorMessage { get; set; }
    public List<BuildError>? Errors { get; set; }
    public bool IsRetryable { get; set; }
    public string? ArtifactPath { get; set; }
}
```

### Key Features
- **Managed execution**: No user interaction with CLI
- **Process isolation**: Each build in separate process
- **Resource limits**: Prevent runaway processes
- **Error capture**: Full stdout/stderr for analysis
- **Timeout handling**: Kill long-running builds
- **Artifact tracking**: Know where outputs are

---

## 3️⃣ Roslyn Code Intelligence Service

### Purpose
AST parsing, symbol resolution, safe patching, impact analysis.
All internal — not in frontend.

### Architecture
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

### Implementation

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
    
    /// Get safe patch suggestions for file
    public async Task<List<PatchSuggestion>> GetPatchSuggestionsAsync(
        string filePath,
        string intent)
    {
        // Parse intent
        // Find relevant symbols
        // Suggest specific AST modifications
        
        return new List<PatchSuggestion>();
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

### Use Cases
- **Smart Retrieval**: Know exactly which files to send to AI Engine
- **Impact Analysis**: Warn if change affects many files
- **Safe Patching**: AST-aware modifications
- **Conflict Detection**: Prevent overlapping changes

---

## 4️⃣ Patch Engine (Transaction-Based)

### Purpose
No raw file writes. All mutations through structured patching.

### Architecture
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
│  ├─ DetectOverlapPing Changes()
│  └─ ResolveConflicts()
│
└─ Transaction Manager
   ├─ BeginTransaction()
   ├─ ApplyPatch()
   ├─ Rollback()
   └─ Commit()
```

### Implementation Pattern

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

### Guarantees
- **Atomic**: Entire patch succeeds or fails
- **Reversible**: Snapshot available for rollback
- **Conflict-Free**: Detect overlapping changes
- **Auditable**: Track every patch

---

## 5️⃣ Orchestrator Engine

### Purpose
Task graph, deterministic state machine, retry limits, error classification.
The brain of the system.

**See [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) for complete details.**

---

## 6️⃣ Memory + Project Graph (SQLite)

### Purpose
Persistent storage of:
- Files
- Symbols  
- Dependencies
- Errors
- Architectural decisions
- User constraints

### Schema

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

### Usage Pattern

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

## System-Level Architecture

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

## Deployment Decision Point

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

## Required for True Internalization

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

## Critical Warning

If you try to build without these subsystems:

```
AI Engine generates code
  ↓
Write files directly
  ↓
Run dotnet build
  ↓
Error! (no classification)
  ↓
Retry with fresh generation
  ↓
Overwrites good code
  ↓
Cascading failures
  ↓
10 minutes later: Project broken
```

**vs. With proper internalization:**

```
AI Engine generates code
  ↓
Transactional patch
  ↓
Run dotnet build (isolated)
  ↓
Error! (classified: missing attribute)
  ↓
Fix Agent patches (silent)
  ↓
Run dotnet build again
  ↓
Success!
  ↓
User sees: "Done ✅"
```

---

## Implementation Roadmap

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

## Summary

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

**Status**: 🟢 Production-ready specification  
**Complexity**: High (distributed system concerns)  
**Risk**: CRITICAL if skipped (foundation of reliability)  
**Estimated LOC**: ~2,000 lines C# (core subsystems)
