# Build and Mutation Kernel

> **Authority**: This document defines the embedded MSBuild kernel, Roslyn mutation engine, patch engine, snapshot system, and security boundaries.
> **Status**: Core execution engine layer

---

## Part 1: Execution Kernel (Embedded MSBuild)

### Core Principle

All build operations use **in-process Microsoft.Build APIs**, not external CLI tools. Users never see build commands.

### Build Flow

```
1. Task Starts
   - Receive BuildTask from Orchestrator
   
2. Snapshot Workspace
   - Create ZIP snapshot of current state
   - Store in .builder/snapshots/
   
3. Apply Patch (if any)
   - Receive code changes from Roslyn engine
   - Apply to workspace files
   
4. Clean Workspace
   - Delete bin/ and obj/ directories
   
5. Execute In-Process Build
   - Load Project (ProjectCollection.LoadProject)
   - Run Target: "Restore;Build"
   - Timeout: 60-120 seconds
   
6. Process Build Result
   - Retrieve structured errors
   - Classify error types
   - Generate BuildResult
```

### Build Service Implementation

```csharp
using Microsoft.Build.Evaluation;
using Microsoft.Build.Execution;
using Microsoft.Build.Framework;

public class BuildService : IBuildService
{
    public async Task<BuildResult> BuildAsync(
        string projectPath, 
        BuildOptions options = null,
        CancellationToken cancellationToken = default)
    {
        return await Task.Run(() => 
        {
            var projectCollection = new ProjectCollection();
            var buildLogger = new StructuredLogger();
            
            var project = projectCollection.LoadProject(projectPath);
            project.SetProperty("Configuration", options?.Configuration ?? "Debug");
            
            var buildParameters = new BuildParameters(projectCollection)
            {
                Loggers = new[] { buildLogger },
                MaxNodeCount = Environment.ProcessorCount
            };
            
            var targets = options?.RestoreBeforeBuild != false 
                ? new[] { "Restore", "Build" } 
                : new[] { "Build" };
            
            var buildRequest = new BuildRequestData(
                project.CreateProjectInstance(),
                targets
            );
            
            var buildResult = BuildManager.DefaultBuildManager
                .Build(buildParameters, buildRequest);
            
            return CreateResult(buildResult, buildLogger);
        }, cancellationToken);
    }
}
```

---

## Part 2: Roslyn Code Intelligence

### Purpose
- AST parsing
- Symbol resolution
- Safe patching
- Impact analysis

### Symbol Indexing

```csharp
public class RoslynCodeIntelligenceService
{
    private Compilation? _cachedCompilation;
    private Dictionary<string, ISymbol>? _symbolIndex;
    
    public async Task IndexProjectAsync()
    {
        var workspace = MSBuildWorkspace.Create();
        var project = await workspace.OpenProjectAsync(_projectPath);
        var compilation = await project.GetCompilationAsync();
        
        _cachedCompilation = compilation;
        _symbolIndex = new Dictionary<string, ISymbol>();
        
        IndexSymbolsRecursive(compilation.GlobalNamespace);
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
```

### Impact Analysis

```csharp
public async Task<FileImpactAnalysis> AnalyzeChangeImpactAsync(string filePath)
{
    var syntaxTree = _cachedCompilation.SyntaxTrees
        .FirstOrDefault(st => st.FilePath == filePath);
    
    var semanticModel = _cachedCompilation.GetSemanticModel(syntaxTree);
    var root = syntaxTree.GetRoot();
    var declaredSymbols = FindDeclaredSymbols(root, semanticModel);
    
    var dependentFiles = new HashSet<string>();
    foreach (var symbol in declaredSymbols)
    {
        var references = await SymbolFinder.FindReferencesAsync(symbol, _cachedCompilation);
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
```

---

## Part 3: Transactional Patch Engine

### Core Principle
No raw file writes. All mutations through structured patching with rollback capability.

### Patch Transaction

```csharp
public class TransactionalPatchEngine
{
    private readonly FileSystemSandbox _sandbox;
    private Stack<ISnapshot> _undoStack = new();
    
    public async Task<IPatchTransaction> BeginPatchAsync(string filePath)
    {
        var snapshot = await _sandbox.CreateSnapshotAsync(
            Path.GetDirectoryName(filePath)!
        );
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
```

### AST-Based Patching

```csharp
public async Task AddAttributeAsync(string className, string attributeName)
{
    var syntax = CSharpSyntaxTree.ParseText(await File.ReadAllTextAsync(_filePath));
    var root = syntax.GetCompilationUnitSyntax();
    
    var classDecl = root.DescendantNodes().OfType<ClassDeclarationSyntax>()
        .FirstOrDefault(c => c.Identifier.Text == className);
    
    var attr = SyntaxFactory.Attribute(
        SyntaxFactory.IdentifierName(attributeName));
    var newClass = classDecl.AddAttributeLists(
        SyntaxFactory.AttributeList().AddAttributes(attr));
    
    var newRoot = root.ReplaceNode(classDecl, newClass);
    await File.WriteAllTextAsync(_filePath, newRoot.ToFullString());
}
```

---

## Part 4: Snapshot System

### Snapshot Manager

```csharp
public class SnapshotManager
{
    public async Task<string> CreateSnapshotAsync(string workspacePath, string taskId)
    {
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var snapshotName = $"snapshot_{taskId}_{timestamp}.zip";
        var snapshotPath = Path.Combine(_snapshotDir, snapshotName);
        
        ZipFile.CreateFromDirectory(workspacePath, snapshotPath);
        return snapshotPath;
    }
    
    public async Task RestoreSnapshotAsync(string snapshotPath, string workspacePath)
    {
        Directory.Delete(workspacePath, recursive: true);
        Directory.CreateDirectory(workspacePath);
        ZipFile.ExtractToDirectory(snapshotPath, workspacePath);
    }
}
```

### Snapshot Rules
- Create snapshot **before** every mutation
- Store in `.builder/snapshots/`
- Mark as committed on success
- Keep for rollback on failure

---

## Part 5: Security Boundaries

### Explicit Security Constraints

```csharp
public class SecurityBoundary
{
    private readonly string _projectRootPath;
    
    /// Validate path is within project
    public bool IsPathAllowed(string filePath)
    {
        var fullPath = Path.GetFullPath(filePath);
        var rootPath = Path.GetFullPath(_projectRootPath);
        
        return fullPath.StartsWith(rootPath, StringComparison.OrdinalIgnoreCase)
            && !fullPath.Contains("..");
    }
}
```

### ❌ Forbidden Operations

- **Arbitrary Shell Execution**: Never allow `Process.Start("cmd.exe")`
- **Elevated Privileges**: Never run as admin
- **Registry Writes**: Never modify Windows registry
- **Unsafe File Traversal**: Never access outside project

### ✅ Allowed Operations

- **Whitelisted Commands**: Only `dotnet restore`, `dotnet build`, `dotnet run`
- **Isolated File Access**: Only project directory
- **Standard User Context**: Run as normal user permissions

---

## Part 6: Performance Rules

### Incremental Build

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
}
```

### Performance Guidelines
- Track file hashes for incremental builds
- Cache Roslyn compilation results
- Reuse NuGet packages globally
- Limit parallelism based on available RAM

---

## Related Documents

- [00_CANONICAL_AUTHORITY.md](./00_CANONICAL_AUTHORITY.md) - System invariants
- [02_ORCHESTRATION_AND_EXECUTION.md](./02_ORCHESTRATION_AND_EXECUTION.md) - State machine

---

**End of Build and Mutation Kernel**
