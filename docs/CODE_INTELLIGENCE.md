# CODE INTELLIGENCE

> **The Knowledge Layer: Roslyn Integration, Semantic Indexing, Database Schema, Patch Engine & Mutation Safety**
>
> _Merged from: ROSLYN_INTEGRATION_SPECIFICATION.md, INDEXING_ARCHITECTURE_SPECIFICATION.md, DATABASE_SPECIFICATION.md, SAFETY_AND_PERFORMANCE_SPECIFICATION.md, API_CONTRACTS.md_

---

## Table of Contents

1. [Core Principle: No Raw File Writes](#1-core-principle-no-raw-file-writes)
2. [Indexing Architecture](#2-indexing-architecture)
3. [Roslyn Compilation Model](#3-roslyn-compilation-model)
4. [Code Indexer & Symbol Graph](#4-code-indexer--symbol-graph)
5. [Database Schema](#5-database-schema)
6. [Patch Engine](#6-patch-engine)
7. [Conflict Detection](#7-conflict-detection)
8. [XAML Binding Index](#8-xaml-binding-index)
9. [Mutation Safety Guards](#9-mutation-safety-guards)
10. [Impact Analysis Engine](#10-impact-analysis-engine)
11. [AI Retrieval Pipeline](#11-ai-retrieval-pipeline)
12. [Database Access Layer](#12-database-access-layer)
13. [Performance Optimizations](#13-performance-optimizations)
14. [Graph Integrity Verifier](#14-graph-integrity-verifier)
15. [Service Contracts](#15-service-contracts)

---

## 1. Core Principle: No Raw File Writes

### ❌ FORBIDDEN Operations

```csharp
// ❌ NEVER DO THIS - String replacement
var code = File.ReadAllText("MyClass.cs");
code = code.Replace("oldMethod", "newMethod");
File.WriteAllText("MyClass.cs", code);

// ❌ NEVER DO THIS - Regex replacement
var code = File.ReadAllText("MyClass.cs");
code = Regex.Replace(code, pattern, replacement);
File.WriteAllText("MyClass.cs", code);

// ❌ NEVER DO THIS - Direct file overwrite
File.WriteAllText("MyClass.cs", llmGeneratedCode);
```

### ✅ REQUIRED Approach

```csharp
// ✅ ALWAYS DO THIS - Roslyn AST transformation
var tree = CSharpSyntaxTree.ParseText(File.ReadAllText("MyClass.cs"));
var root = await tree.GetRootAsync();

// Apply transformation
var newRoot = root.ReplaceNode(oldNode, newNode);

// Format and write
var formatted = Formatter.Format(newRoot, workspace);
File.WriteAllText("MyClass.cs", formatted.ToFullString());
```

---

## 2. Indexing Architecture

### Design Philosophy

> **Lovable likely uses**: Shallow + summary + retrieval + retry loop
>
> **You are building**: Deep semantic + deterministic + local execution

**Enterprise-Level (Sync AI)**: Deep semantic + deterministic + local execution

**Different scale. Different guarantees.**

### Hybrid Architecture (Recommended)

The system uses **Enterprise-Level Core + Lovable-Level Retrieval Optimization**:

1. ✅ **Full Roslyn semantic graph** (Enterprise) — Full AST, cross-file resolution
2. ✅ **XAML binding graph** (Enterprise) — WinUI 3 binding tracking
3. ✅ **Snapshot-aware indexing** (Enterprise) — Version-tracked graph state
4. ✅ **Lightweight project summary** (Lovable) — Compressed context for AI
5. ✅ **Hybrid structured + semantic retrieval** (Lovable) — Token-efficient context
6. ✅ **Strict mutation guard** (Enterprise) — 5-layer safety before patch

### Comparison

| Feature           | Lovable-Level    | Enterprise-Level  |
| ----------------- | ---------------- | ----------------- |
| AST depth         | Shallow metadata | Full tree storage |
| Graph depth       | Flat             | Multi-layer       |
| Binding awareness | Minimal          | Full (XAML ↔ VM)  |
| Impact analysis   | Basic            | Deterministic     |
| Refactor safety   | Medium           | Strong            |
| Token control     | Summary-based    | Graph-based       |
| Scalability       | < 100K LOC       | 200K+ LOC         |

### Enterprise Architecture Overview

```
Workspace Scanner
   ↓
Full Roslyn Compilation Model
   ↓
Semantic Model Builder
   ↓
Symbol Graph (Complete)
   ↓
Dependency Graph (Bidirectional)
   ↓
XAML Binding Graph
   ↓
Project Knowledge Graph
   ↓
AI Retrieval Layer
```

### What Must Be Indexed

- **Classes** — Name, namespace, base class, interfaces
- **Methods** — Signature, parameters, return type, accessibility
- **Properties** — Type, getter/setter, accessibility
- **Fields** — Type, accessibility, initializer
- **Interfaces** — Members, inheritance
- **Inheritance graph** — Class hierarchy
- **Dependency graph** — File-to-file dependencies
- **XAML binding references** — x:Name, Binding paths, x:Bind paths

---

## 3. Roslyn Compilation Model

### Full Compilation Builder

```csharp
public class CompilationModelBuilder
{
    public async Task<Compilation> BuildCompilationAsync(string projectPath)
    {
        var syntaxTrees = new List<SyntaxTree>();
        var csFiles = Directory.GetFiles(projectPath, "*.cs", SearchOption.AllDirectories);

        foreach (var file in csFiles)
        {
            var code = await File.ReadAllTextAsync(file);
            var tree = CSharpSyntaxTree.ParseText(code, path: file);
            syntaxTrees.Add(tree);
        }

        var compilation = CSharpCompilation.Create(
            assemblyName: "ProjectCompilation",
            syntaxTrees: syntaxTrees,
            references: GetMetadataReferences(),
            options: new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary)
        );

        // Build semantic model for each tree
        foreach (var tree in syntaxTrees)
        {
            var semanticModel = compilation.GetSemanticModel(tree);
            await IndexSemanticModelAsync(tree.FilePath, semanticModel);
        }

        return compilation;
    }
}
```

### Full Syntax Tree Index

```csharp
public class FullSyntaxTreeIndex
{
    private ConcurrentDictionary<string, SyntaxTree> _syntaxTrees = new();

    public async Task IndexFileAsync(string filePath)
    {
        var code = await File.ReadAllTextAsync(filePath);
        var tree = CSharpSyntaxTree.ParseText(code, path: filePath);

        _syntaxTrees[filePath] = tree;

        // Store all syntax nodes
        var root = await tree.GetRootAsync();
        await IndexSyntaxNodesAsync(filePath, root);
    }

    private async Task IndexSyntaxNodesAsync(string filePath, SyntaxNode node)
    {
        await _database.ExecuteAsync(@"
            INSERT INTO syntax_nodes (id, file_path, kind, span_start, span_end, parent_id)
            VALUES (@id, @filePath, @kind, @spanStart, @spanEnd, @parentId)",
            new
            {
                id = Guid.NewGuid().ToString(),
                filePath,
                kind = node.Kind().ToString(),
                spanStart = node.Span.Start,
                spanEnd = node.Span.End,
                parentId = node.Parent != null ? GetNodeId(node.Parent) : null
            });

        foreach (var child in node.ChildNodes())
        {
            await IndexSyntaxNodesAsync(filePath, child);
        }
    }
}
```

---

## 4. Code Indexer & Symbol Graph

### ICodeIndexer Interface

```csharp
public interface ICodeIndexer
{
    Task IndexFileAsync(string filePath);
    Task IndexProjectAsync(string projectPath);
    Task<List<SymbolReference>> FindReferencesAsync(string symbolName);
    Task<FileDependencyGraph> GetDependencyGraphAsync(string filePath);
}
```

### CodeIndexer Implementation

```csharp
public class CodeIndexer : ICodeIndexer
{
    private readonly IDbConnection _db;
    private readonly ILogger<CodeIndexer> _logger;

    public async Task IndexFileAsync(string filePath)
    {
        var sourceText = await File.ReadAllTextAsync(filePath);
        var tree = CSharpSyntaxTree.ParseText(sourceText);
        var root = await tree.GetRootAsync();

        var fileHash = ComputeFileHash(sourceText);
        var fileId = await UpsertFileAsync(filePath, fileHash);

        // Delete existing symbols for this file
        await _db.ExecuteAsync(
            "DELETE FROM Symbols WHERE FileId = @FileId",
            new { FileId = fileId });

        // Index classes, methods, properties
        foreach (var classDecl in root.DescendantNodes().OfType<ClassDeclarationSyntax>())
            await IndexClassAsync(fileId, classDecl);

        foreach (var methodDecl in root.DescendantNodes().OfType<MethodDeclarationSyntax>())
            await IndexMethodAsync(fileId, methodDecl);

        foreach (var propertyDecl in root.DescendantNodes().OfType<PropertyDeclarationSyntax>())
            await IndexPropertyAsync(fileId, propertyDecl);
    }

    private async Task IndexClassAsync(int fileId, ClassDeclarationSyntax classDecl)
    {
        var namespaceName = classDecl.Ancestors()
            .OfType<NamespaceDeclarationSyntax>()
            .FirstOrDefault()?.Name.ToString();

        var fullyQualifiedName = $"{namespaceName}.{classDecl.Identifier.Text}";

        await _db.ExecuteAsync(
            @"INSERT INTO Symbols (FileId, SymbolType, Name, FullyQualifiedName, Namespace, LineNumber, Accessibility)
              VALUES (@FileId, 'Class', @Name, @FQN, @Namespace, @Line, @Access)",
            new
            {
                FileId = fileId,
                Name = classDecl.Identifier.Text,
                FQN = fullyQualifiedName,
                Namespace = namespaceName,
                Line = classDecl.GetLocation().GetLineSpan().StartLinePosition.Line,
                Access = GetAccessibility(classDecl.Modifiers)
            });
    }
}
```

### Graph Update Algorithm

Must be **deterministic** and **transactional**:

```csharp
public async Task UpdateGraphForFileAsync(string filePath, string newContent)
{
    using var transaction = _connection.BeginTransaction();

    try
    {
        // 1. Clear old records for this file
        await ClearFileRecordsAsync(filePath, currentSnapshotId);

        // 2. Parse with Roslyn
        var syntaxTree = CSharpSyntaxTree.ParseText(newContent);
        var root = await syntaxTree.GetRootAsync();

        // 3. Extract & insert syntax nodes
        foreach (var node in root.DescendantNodes())
        {
            if (IsIndexable(node)) InsertSyntaxNode(node);
        }

        // 4. Resolve semantic model & insert symbols
        var semanticModel = _compilation.GetSemanticModel(syntaxTree);
        foreach (var symbol in ExtractSymbols(semanticModel))
            InsertSymbol(symbol);

        // 5. Resolve & insert edges
        foreach (var edge in ResolveEdges(semanticModel))
            InsertEdge(edge);

        // 6. Handle XAML (if applicable)
        if (IsXaml(filePath))
            UpdateXamlBindings(filePath, newContent);

        transaction.Commit();
    }
    catch
    {
        transaction.Rollback();
        throw;
    }
}
```

### Incremental Indexing Strategy

**Hash-Based Detection** — skip unchanged files:

```csharp
var currentHash = ComputeSha256(fileContent);
var storedHash = await _db.GetFileHashAsync(filePath);
if (currentHash == storedHash) return; // SKIP
```

**Symbol Diff Strategy** — when a file is modified, only update:

1. Symbols defined in **that file**
2. Incoming edges **to** those symbols (re-validation)

**Dependency Revalidation** — if `Symbol A` is removed:

1. Query `symbol_edges` WHERE `to_symbol_id == A`
2. Identify all dependents
3. Mark files for semantic re-check
4. Block mutation if breaking change detected

---

## 5. Database Schema

### Database Architecture

SQLite for all local data. Each component has its own database file:

```
C:\Users\{User}\AppData\Local\SyncAIAppBuilder\
├── application.db          # Settings, projects list
├── Workspaces\
│   └── {ProjectId}\
│       └── .builder\
│           ├── project_graph.db    # Symbol index, dependencies, Roslyn data
│           ├── orchestrator.db     # State machine, event log, task history
│           └── build_history.db    # Build results, error classifications
```

### Application Database (application.db)

```sql
CREATE TABLE Projects (
    Id TEXT PRIMARY KEY,
    Name TEXT NOT NULL,
    Description TEXT,
    WorkspacePath TEXT NOT NULL UNIQUE,
    CreatedDate DATETIME NOT NULL,
    ModifiedDate DATETIME NOT NULL,
    LastOpenedDate DATETIME,
    IsArchived INTEGER DEFAULT 0,
    HealthStatus TEXT DEFAULT 'Unknown',
    SdkVersion TEXT,
    TargetFramework TEXT
);
CREATE INDEX idx_projects_modified ON Projects(ModifiedDate DESC);
CREATE INDEX idx_projects_health ON Projects(HealthStatus);

CREATE TABLE Settings (
    Key TEXT PRIMARY KEY,
    Value TEXT NOT NULL,
    Category TEXT,
    DataType TEXT NOT NULL,
    ModifiedDate DATETIME NOT NULL
);

CREATE TABLE RecentPrompts (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Prompt TEXT NOT NULL,
    UsageCount INTEGER DEFAULT 1,
    LastUsedDate DATETIME NOT NULL,
    ProjectId TEXT,
    FOREIGN KEY (ProjectId) REFERENCES Projects(Id) ON DELETE SET NULL
);
CREATE INDEX idx_recent_prompts_date ON RecentPrompts(LastUsedDate DESC);
```

### Project Graph Database (project_graph.db)

Multi-layer graph model: File → Syntax → Symbol → Edge → XAML → Version.

```sql
-- File layer
CREATE TABLE files (
    id INTEGER PRIMARY KEY,
    path TEXT NOT NULL UNIQUE,
    hash TEXT NOT NULL,
    last_modified_utc TEXT NOT NULL,
    language TEXT NOT NULL,        -- 'cs', 'xaml', 'xml', 'json'
    snapshot_id INTEGER NOT NULL
);

    parent_node_id INTEGER,
    FOREIGN KEY(file_id) REFERENCES files(id)
);
CREATE INDEX idx_files_snapshot ON files(snapshot_id);
CREATE INDEX idx_files_path ON files(path);

-- Syntax layer (Roslyn AST nodes)
CREATE TABLE syntax_nodes (
    id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,
    kind TEXT NOT NULL,
    name TEXT,
    span_start INTEGER,
    span_end INTEGER,
    parent_node_id INTEGER,
    FOREIGN KEY(file_id) REFERENCES files(id)
);
CREATE INDEX idx_syntax_file ON syntax_nodes(file_id);
CREATE INDEX idx_syntax_name ON syntax_nodes(name);

-- Symbol layer (Roslyn resolved symbols)
CREATE TABLE symbols (
    id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,
    syntax_node_id INTEGER,
    name TEXT NOT NULL,
    fully_qualified_name TEXT NOT NULL,
    kind TEXT NOT NULL,            -- 'NamedType', 'Method', 'Property'
    return_type TEXT,
    accessibility TEXT,
    is_static INTEGER,
    is_abstract INTEGER,
    snapshot_id INTEGER NOT NULL,
    FOREIGN KEY(file_id) REFERENCES files(id)
);
CREATE INDEX idx_symbols_fqn ON symbols(fully_qualified_name);

-- Edge layer (directed semantic relationships)
CREATE TABLE symbol_edges (
    id INTEGER PRIMARY KEY,
    from_symbol_id INTEGER NOT NULL,
    to_symbol_id INTEGER NOT NULL,
    edge_type TEXT NOT NULL,       -- 'CALLS', 'INHERITS', 'IMPLEMENTS', 'REFERENCES', 'INJECTS'
    snapshot_id INTEGER NOT NULL,
    FOREIGN KEY(from_symbol_id) REFERENCES symbols(id),
    FOREIGN KEY(to_symbol_id) REFERENCES symbols(id)
);
CREATE INDEX idx_symbols_snapshot ON symbols(snapshot_id);
CREATE INDEX idx_symbol_edges_from ON symbol_edges(from_symbol_id);
CREATE INDEX idx_symbol_edges_to ON symbol_edges(to_symbol_id);

-- XAML binding layer
CREATE TABLE xaml_bindings (
    id INTEGER PRIMARY KEY,
    xaml_file_id INTEGER NOT NULL,
    viewmodel_symbol_id INTEGER NOT NULL,
    binding_property TEXT NOT NULL,
    binding_target TEXT NOT NULL,
    snapshot_id INTEGER NOT NULL,
    FOREIGN KEY(xaml_file_id) REFERENCES files(id),
    FOREIGN KEY(viewmodel_symbol_id) REFERENCES symbols(id)
);
CREATE INDEX idx_xaml_vm ON xaml_bindings(viewmodel_symbol_id);

-- NuGet packages
CREATE TABLE NuGetPackages (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PackageId TEXT NOT NULL,
    Version TEXT NOT NULL,
    IsDirectDependency INTEGER DEFAULT 1,
    AddedDate DATETIME NOT NULL,
    UNIQUE(PackageId, Version)
);
CREATE INDEX idx_nuget_packages_id ON NuGetPackages(PackageId);

-- Snapshots & versions
CREATE TABLE snapshots (
    id INTEGER PRIMARY KEY,
    created_utc TEXT NOT NULL,
    reason TEXT NOT NULL,
    parent_snapshot_id INTEGER
);

CREATE TABLE versions (
    id INTEGER PRIMARY KEY,
    snapshot_id INTEGER NOT NULL,
    summary TEXT NOT NULL,
    build_status TEXT NOT NULL,
    created_utc TEXT NOT NULL,
    FOREIGN KEY(snapshot_id) REFERENCES snapshots(id)
);
```

### Orchestrator Database (orchestrator.db)

```sql
CREATE TABLE OrchestratorStates (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    State TEXT NOT NULL,
    Timestamp DATETIME NOT NULL,
    Metadata TEXT,
    PreviousStateId INTEGER,
    FOREIGN KEY (PreviousStateId) REFERENCES OrchestratorStates(Id)
);
CREATE INDEX idx_orchestrator_states_time ON OrchestratorStates(Timestamp DESC);

CREATE TABLE Tasks (
    Id TEXT PRIMARY KEY,
    TaskType TEXT NOT NULL,
    Description TEXT,
    Status TEXT NOT NULL,
    CreatedDate DATETIME NOT NULL,
    StartedDate DATETIME,
    CompletedDate DATETIME,
    RetryCount INTEGER DEFAULT 0,
    MaxRetries INTEGER DEFAULT 5,
    ParentTaskId TEXT,
    Priority INTEGER DEFAULT 0,
    Payload TEXT,
    Result TEXT,
    FOREIGN KEY (ParentTaskId) REFERENCES Tasks(Id) ON DELETE CASCADE
);
CREATE INDEX idx_tasks_status ON Tasks(Status);
CREATE INDEX idx_tasks_created ON Tasks(CreatedDate DESC);
CREATE INDEX idx_tasks_parent ON Tasks(ParentTaskId);

CREATE TABLE TaskEvents (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    TaskId TEXT NOT NULL,
    EventType TEXT NOT NULL,
    Timestamp DATETIME NOT NULL,
    EventData TEXT,
    FOREIGN KEY (TaskId) REFERENCES Tasks(Id) ON DELETE CASCADE
);
CREATE INDEX idx_task_events_task ON TaskEvents(TaskId);
CREATE INDEX idx_task_events_time ON TaskEvents(Timestamp DESC);

CREATE TABLE RetryHistory (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    TaskId TEXT NOT NULL,
    RetryNumber INTEGER NOT NULL,
    Timestamp DATETIME NOT NULL,
    ErrorType TEXT,
    ErrorMessage TEXT,
    FixAttempt TEXT,
    FOREIGN KEY (TaskId) REFERENCES Tasks(Id) ON DELETE CASCADE
);
CREATE INDEX idx_retry_history_task ON RetryHistory(TaskId);

CREATE TABLE Snapshots (
    Id TEXT PRIMARY KEY,
    TaskId TEXT,
    FilePath TEXT NOT NULL,
    CreatedDate DATETIME NOT NULL,
    SizeBytes INTEGER,
    FileCount INTEGER,
    IsCommitted INTEGER DEFAULT 0,
    FOREIGN KEY (TaskId) REFERENCES Tasks(Id) ON DELETE SET NULL
);
CREATE INDEX idx_snapshots_task ON Snapshots(TaskId);
CREATE INDEX idx_snapshots_committed ON Snapshots(IsCommitted);
```

### Build History Database (build_history.db)

```sql
CREATE TABLE BuildResults (
    Id TEXT PRIMARY KEY,
    TaskId TEXT,
    ProjectPath TEXT NOT NULL,
    Configuration TEXT DEFAULT 'Debug',
    Success INTEGER NOT NULL,
    StartTime DATETIME NOT NULL,
    EndTime DATETIME NOT NULL,
    DurationMs INTEGER NOT NULL,
    ExitCode INTEGER,
    BuildLog TEXT
);
CREATE INDEX idx_build_results_time ON BuildResults(StartTime DESC);
CREATE INDEX idx_build_results_success ON BuildResults(Success);

CREATE TABLE BuildErrors (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    BuildResultId TEXT NOT NULL,
    ErrorCode TEXT,
    ErrorType TEXT NOT NULL,
    Severity TEXT NOT NULL,
    Message TEXT NOT NULL,
    FilePath TEXT,
    LineNumber INTEGER,
    ColumnNumber INTEGER,
    FOREIGN KEY (BuildResultId) REFERENCES BuildResults(Id) ON DELETE CASCADE
);
CREATE INDEX idx_build_errors_result ON BuildErrors(BuildResultId);
CREATE INDEX idx_build_errors_code ON BuildErrors(ErrorCode);
CREATE INDEX idx_build_errors_type ON BuildErrors(ErrorType);

CREATE TABLE PerformanceMetrics (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    BuildResultId TEXT NOT NULL,
    MetricName TEXT NOT NULL,
    MetricValue REAL NOT NULL,
    Unit TEXT NOT NULL,
    FOREIGN KEY (BuildResultId) REFERENCES BuildResults(Id) ON DELETE CASCADE
);
CREATE INDEX idx_perf_metrics_build ON PerformanceMetrics(BuildResultId);

CREATE TABLE ErrorPatterns (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    ErrorCode TEXT NOT NULL,
    ErrorType TEXT NOT NULL,
    Pattern TEXT NOT NULL,
    CommonCause TEXT,
    SuggestedFix TEXT,
    OccurrenceCount INTEGER DEFAULT 1,
    LastSeen DATETIME NOT NULL,
    UNIQUE(ErrorCode, Pattern)
);
CREATE INDEX idx_error_patterns_code ON ErrorPatterns(ErrorCode);

```

---

## 6. Patch Engine

### Allowed Patch Operations

LLM must NOT return full files. Only structured patch operations:

```csharp
public enum PatchOperationType
{
    ADD_CLASS,
    ADD_METHOD,
    ADD_PROPERTY,
    ADD_FIELD,
    MODIFY_METHOD_BODY,
    MODIFY_PROPERTY,
    INSERT_USING,
    REMOVE_MEMBER,
    UPDATE_XAML_NODE,
    ADD_XAML_ELEMENT,
    MODIFY_XAML_ATTRIBUTE
}
```

### Patch Operation Structure

```csharp
public class PatchOperation
{
    public PatchOperationType OperationType { get; set; }
    public string TargetFile { get; set; }
    public object Payload { get; set; }
    public string ExpectedFileHash { get; set; } // For conflict detection
}
```

### Patch Payloads

```csharp
public class AddClassPayload
{
    public string Namespace { get; set; }
    public string ClassName { get; set; }
    public string BaseClass { get; set; }
    public string[] Interfaces { get; set; }
    public string Accessibility { get; set; } = "public";
    public bool IsStatic { get; set; }
    public bool IsAbstract { get; set; }
}

public class AddMethodPayload
{
    public string TargetClass { get; set; }
    public string MethodName { get; set; }
    public string ReturnType { get; set; }
    public MethodParameter[] Parameters { get; set; }
    public string MethodBody { get; set; }
    public string Accessibility { get; set; } = "public";
    public bool IsStatic { get; set; }
    public bool IsAsync { get; set; }
}

public class ModifyMethodBodyPayload
{
    public string TargetClass { get; set; }
    public string MethodName { get; set; }
    public string MethodSignature { get; set; } // For overload resolution
    public string NewMethodBody { get; set; }
}

public class AddPropertyPayload
{
    public string TargetClass { get; set; }
    public string PropertyName { get; set; }
    public string PropertyType { get; set; }
    public string Accessibility { get; set; } = "public";
    public bool HasGetter { get; set; } = true;
    public bool HasSetter { get; set; } = true;
    public string InitialValue { get; set; }
}
```

### IPatchEngine Interface

```csharp
public interface IPatchEngine
{
    Task<PatchResult> ApplyPatchAsync(PatchOperation patch);
    Task<PatchValidationResult> ValidatePatchAsync(PatchOperation patch);
    Task<BatchPatchResult> ApplyPatchBatchAsync(PatchOperation[] patches);
}
```

### PatchEngine Implementation

```csharp
public class PatchEngine : IPatchEngine
{
    private readonly ILogger<PatchEngine> _logger;
    private readonly ICodeIndexer _indexer;
    private readonly AdhocWorkspace _workspace;

    public async Task<PatchResult> ApplyPatchAsync(PatchOperation patch)
    {
        // 1. Validate patch
        var validation = await ValidatePatchAsync(patch);
        if (!validation.IsValid) return PatchResult.Failed(validation.ErrorMessage);

        // 2. Load file & check hash for conflicts
        var sourceText = await File.ReadAllTextAsync(filePath);
        var currentHash = ComputeFileHash(sourceText);
        if (patch.ExpectedFileHash != null && currentHash != patch.ExpectedFileHash)
            return PatchResult.Failed("File has been modified since patch was created");

        // 3. Parse to syntax tree
        var tree = CSharpSyntaxTree.ParseText(sourceText);
        var root = await tree.GetRootAsync();

        // 4. Apply transformation based on operation type
        var newRoot = patch.OperationType switch
        {
            PatchOperationType.ADD_CLASS => ApplyAddClass(root, payload),
            PatchOperationType.ADD_METHOD => ApplyAddMethod(root, payload),
            PatchOperationType.MODIFY_METHOD_BODY => ApplyModifyMethodBody(root, payload),
            PatchOperationType.ADD_PROPERTY => ApplyAddProperty(root, payload),
            _ => throw new NotSupportedException()
        };

        // 5. Validate syntax
        var diagnostics = newRoot.GetDiagnostics();
        if (diagnostics.Any(d => d.Severity == DiagnosticSeverity.Error))
            return PatchResult.Failed("Syntax errors in patched code");

        // 6. Format, write atomically, and re-index
        var formatted = Formatter.Format(newRoot, _workspace);
        await File.WriteAllTextAsync(filePath, formatted.ToFullString());
        await _indexer.IndexFileAsync(filePath);

        return PatchResult.Success(ComputeFileHash(formatted.ToFullString()));
    }
}
```

---

## 7. Conflict Detection

### Patch Failure Scenarios

A patch fails if:

- **Target node not found** — Class, method, or property doesn't exist
- **Signature mismatch** — Method signature has changed
- **File hash changed** — File was modified since patch was created
- **Syntax invalid** — Generated code has syntax errors
- **Duplicate member** — Adding a member that already exists

### PatchResult & Error Types

```csharp
public class PatchResult
{
    public bool Success { get; set; }
    public PatchErrorType? Error { get; set; }
    public string ErrorMessage { get; set; }
    public string NewFileHash { get; set; }
}

public enum PatchErrorType
{
    ValidationFailed,
    FileHashMismatch,
    TargetNotFound,
    SignatureMismatch,
    SyntaxError,
    DuplicateMember,
    UnexpectedException
}
```

---

## 8. XAML Binding Index

### XAML ↔ ViewModel Graph

Special layer for WinUI 3:

- Bindings (`{x:Bind ViewModel.Property}`)
- Commands (`{x:Bind ViewModel.SaveCommand}`)
- Dependency properties
- Resource dictionary references

**Without this, WinUI refactors break.**

```csharp
public class XamlBindingIndexer
{
    public async Task IndexXamlFileAsync(string xamlPath)
    {
        var xaml = await File.ReadAllTextAsync(xamlPath);
        var doc = XDocument.Parse(xaml);

        // Extract x:Bind expressions
        var bindings = doc.Descendants()
            .SelectMany(e => e.Attributes())
            .Where(a => a.Value.Contains("{x:Bind"))
            .Select(a => ExtractBindingPath(a.Value));

        foreach (var binding in bindings)
        {
            var viewModelSymbol = await FindViewModelSymbolAsync(xamlPath, binding.Path);

            if (viewModelSymbol != null)
            {
                await _database.ExecuteAsync(@"
                    INSERT INTO binding_edges (id, xaml_node_id, viewmodel_symbol_id, binding_type)
                    VALUES (@id, @xamlNodeId, @viewModelSymbolId, @bindingType)",
                    new
                    {
                        id = Guid.NewGuid().ToString(),
                        xamlNodeId = GetXamlNodeId(xamlPath, binding.ElementName),
                        viewModelSymbolId = viewModelSymbol.Id,
                        bindingType = binding.Type
                    });
            }
        }

        // Also extract {Binding} and x:Name references
        var namedElements = doc.Descendants()
            .Where(e => e.Attribute(XName.Get("Name", "http://schemas.microsoft.com/winfx/2006/xaml")) != null);

        foreach (var element in namedElements)
        {
            var name = element.Attribute(
                XName.Get("Name", "http://schemas.microsoft.com/winfx/2006/xaml")).Value;
            await StoreXamlBindingAsync(xamlPath, name, element);
        }
    }
}
```

---

## 9. Mutation Safety Guards

The guard sits between the AI's proposal and the Patch Engine:

```
AI Patch Proposal → [Mutation Safety Guard] → Patch Engine
```

### Layer 1: Target Existence Validation

- Does the target symbol actually exist?
- Does the snapshot ID match the active snapshot?
- Does the file hash match the expected state?

**Action**: If any check fails → **REJECT** immediately (Stale Context).

### Layer 2: Impact Radius Calculation

1. Query `symbol_edges` for the target symbol
2. Traverse **Outgoing** edges (depth=2)
3. Traverse **Incoming** edges (depth=1)
4. Identify all affected symbols, files, and XAML bindings

**Output**: `MutationScope` object.

### Layer 3: Breaking Change Detection

If the patch modifies public contracts (method signatures, interface definitions, constructor parameters, ViewModel properties bound in XAML):

**Action**: Simulate resolution of dependent symbols. If any become unresolved → **BLOCK**.

### Layer 4: AST Simulation (Dry Run)

1. Clone the SyntaxTree in memory
2. Apply the patch transformation
3. Build a temporary compilation context
4. Validate type resolution, symbol references, binding validity

**Action**: If compilation errors appear → **REJECT**.

### Layer 5: Deterministic Snapshot Pre-Commit

1. Freeze graph state
2. Apply patch in temp/sandbox directory
3. Run `dotnet build` (or design-time build)
4. Only commit if successful

### Guard Failure Escalation

The AI does NOT get infinite retries:

1. **Attempt 1 (Soft Rejection)** — Return tailored error (e.g., "Symbol Foo not found")
2. **Attempt 2 (Hard Rejection)** — Return "Breaking Change Detected" with impact path
3. **Attempt 3 (Barrier Failure)** — **STOP AUTOMATION**. Transition to `INTERVENTION_REQUIRED`. Prompt user: "Should I: (A) Force apply? (B) Revert? (C) Create new file instead?"

4. **Attempt 3 (Barrier Failure)** — **STOP AUTOMATION**. Transition to `INTERVENTION_REQUIRED`. Prompt user: "Should I: (A) Force apply? (B) Revert? (C) Create new file instead?"

---

## 10. Concurrency Safety Model

**Principle**: Single-Writer, Multi-Reader.

### Thread Roles

- **Indexing Writer**: 1 Thread (Exclusive)
- **Patch Writer**: 1 Thread (Exclusive)
- **Build Runner**: 1 Thread (Exclusive)
- **Readers (UI/AI)**: Concurrent allowed

### Locking Strategy

1.  **Workspace Lock**:
    - Mutex: `Global\Workspace_{ProjectId}`
    - Ensures only one ExecutionSession (Orchestrator) active per project.

2.  **Graph Write Lock**:
    - SQLite: `BEGIN IMMEDIATE TRANSACTION`
    - Blocks other writers, allows readers (WAL mode).

3.  **File Locking**:
    - Patch Engine locks target file during read-modify-write cycle.
    - Prevents external edits (e.g., VS Code) from colliding.

### Execution Ordering Rule (Strict)

```
PATCH → INDEX → BUILD → COMMIT
```

**Forbidden States**:

- ❌ Indexing while Patching
- ❌ Building while Patching
- ❌ Patching during Restore

---

## 10. Impact Analysis Engine

```csharp
public class ImpactAnalyzer
{
    public async Task<ImpactAnalysis> AnalyzeChangeAsync(string symbolName, ChangeType changeType)
    {
        var analysis = new ImpactAnalysis();

        // 1. Determine affected symbols via recursive graph traversal
        var affectedSymbols = await GetAffectedSymbolsAsync(symbolName);
        analysis.AffectedSymbols = affectedSymbols;

        // 2. Determine dependent files
        analysis.DependentFiles = await GetDependentFilesAsync(symbolName);

        // 3. Determine cascade effect
        var cascadeEffect = await CalculateCascadeEffectAsync(symbolName, changeType);
        analysis.CascadeEffect = cascadeEffect;

        // 4. Block unsafe mutation
        if (cascadeEffect.ImpactLevel > ImpactLevel.Medium)
        {
            analysis.IsSafe = false;
            analysis.Reason = "Change affects too many symbols. Manual review required.";
        }

        return analysis;
    }

    private async Task<List<string>> GetAffectedSymbolsAsync(string symbolName)
    {
        // Recursive CTE for graph traversal
        var results = await _database.QueryAsync<string>(@"
            WITH RECURSIVE affected AS (
                SELECT to_symbol_id FROM symbol_edges WHERE from_symbol_id = @symbolId
                UNION
                SELECT e.to_symbol_id FROM symbol_edges e
                INNER JOIN affected a ON e.from_symbol_id = a.to_symbol_id
            )
            SELECT DISTINCT s.name FROM affected a
            INNER JOIN symbol_nodes s ON a.to_symbol_id = s.id",
            new { symbolId = GetSymbolId(symbolName) });

        return results.ToList();
    }
}
```

---

## 11. AI Retrieval Pipeline

Optimized for **token efficiency** and **relevance**.

### Context Assembly (Prioritized Order)

1. **System Rules** — WinUI constraints
2. **Project Summary** — High-level architecture
3. **Target Symbol Definition** — Full code of target
4. **Direct Dependencies** — Interfaces, services used
5. **XAML Bindings** — Corresponding XAML file
6. **Error Context** — If in fix mode

### Deterministic Context Builder

````csharp
public async Task<string> PrepareEnterpriseAIContextAsync(string prompt, string projectId)
{
    var context = new StringBuilder();

    // 1. Project knowledge graph
    var knowledgeGraph = await _database.GetProjectKnowledgeGraphAsync(projectId);
    context.AppendLine($"Project Graph: {JsonSerializer.Serialize(knowledgeGraph)}");

    // 2. Impact analysis
    var impactAnalysis = await _impactAnalyzer.AnalyzePromptAsync(prompt);
    context.AppendLine($"Impact: {JsonSerializer.Serialize(impactAnalysis)}");

    // 3. Relevant semantic model subset
    var relevantSymbols = await _semanticRetriever.GetRelevantSymbolsAsync(prompt);
    foreach (var symbol in relevantSymbols)
    {
        var semanticInfo = await _compilation.GetSemanticInfoAsync(symbol);
        context.AppendLine($"Symbol: {JsonSerializer.Serialize(semanticInfo)}");
    }

    // 4. Strict token budgeting
    return await _tokenManager.TrimContextAsync(context.ToString(), maxTokens: 8000);
}

### Hybrid Retrieval Model (Lovable vs Enterprise)

**Lovable-Level (Lightweight)**:
- Shallow metadata index
- Regex-based symbol extraction
- Retrieval-friendly JSON summaries

```csharp
public async Task<string> PrepareAIContextAsync(string prompt, string projectId)
{
    var context = new StringBuilder();

    // 1. Inject system constraints
    context.AppendLine("System: React + Supabase builder");
    context.AppendLine("Constraints: Use functional components, TypeScript, Tailwind CSS");

    // 2. Inject project_summary
    var summary = await _database.GetProjectSummaryAsync(projectId);
    context.AppendLine($"Project: {JsonSerializer.Serialize(summary)}");

    // 3. Retrieve relevant symbols
    var relevantSymbols = await _retriever.GetRelevantSymbolsAsync(prompt);
    foreach (var symbol in relevantSymbols)
    {
        context.AppendLine($"Symbol: {symbol.Name} ({symbol.Kind})");
    }

    // 4. Retrieve relevant files
    var relevantFiles = await _retriever.GetRelevantFilesAsync(prompt);
    foreach (var file in relevantFiles)
    {
        var content = await File.ReadAllTextAsync(file.Path);
        context.AppendLine($"File: {file.Path}");
        context.AppendLine(content);
    }

    // 5. Send minimal context (DO NOT send full project)
    return context.ToString();
}
```

**Enterprise-Level (Sync AI)**: Deep semantic + deterministic + local execution



### Project Summary Builder

```csharp
public class ProjectSummaryBuilder
{
    public async Task<ProjectSummary> BuildSummaryAsync(string projectPath)
    {
        return new ProjectSummary
        {
            Framework = DetectFramework(projectPath),
            AuthType = DetectAuthType(projectPath),
            DatabaseType = DetectDatabaseType(projectPath),
            Entities = await ExtractEntitiesAsync(projectPath),
            Routes = await ExtractRoutesAsync(projectPath),
            ApiEndpoints = await ExtractApiEndpointsAsync(projectPath),
            UiPages = await ExtractUiPagesAsync(projectPath)
        };
    }
}
```

---

## 12. Database Access Layer

### Repository Pattern

```csharp
public interface IRepository<T> where T : class
{
    Task<T> GetByIdAsync(object id);
    Task<IEnumerable<T>> GetAllAsync();
    Task<T> AddAsync(T entity);
    Task UpdateAsync(T entity);
    Task DeleteAsync(object id);
}

public class DapperRepository<T> : IRepository<T> where T : class
{
    private readonly IDbConnection _connection;

    public async Task<T> GetByIdAsync(object id)
    {
        var tableName = typeof(T).Name + "s";
        return await _connection.QuerySingleOrDefaultAsync<T>(
            $"SELECT * FROM {tableName} WHERE Id = @Id", new { Id = id });
    }
}
```

### Unit of Work Pattern

```csharp
public interface IUnitOfWork : IDisposable
{
    IProjectRepository Projects { get; }
    ISymbolRepository Symbols { get; }
    ITaskRepository Tasks { get; }

    Task<int> SaveChangesAsync();
    Task BeginTransactionAsync();
    Task CommitAsync();
    Task RollbackAsync();
}
```

### Migration Framework

```csharp
public interface IMigration
{
    int Version { get; }
    string Description { get; }
    Task UpAsync(IDbConnection connection);
    Task DownAsync(IDbConnection connection);
}

public class MigrationRunner
{
    public async Task MigrateAsync()
    {
        await EnsureMigrationsTableAsync();
        var currentVersion = await GetCurrentVersionAsync();

        var migrations = GetAllMigrations()
            .Where(m => m.Version > currentVersion)
            .OrderBy(m => m.Version);

        foreach (var migration in migrations)
        {
            using var transaction = _connection.BeginTransaction();
            try
            {
                await migration.UpAsync(_connection);
                await RecordMigrationAsync(migration.Version, migration.Description);
                transaction.Commit();
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }
    }
}
```

### Backup & Recovery

```csharp
public class DatabaseBackupService
{
    public async Task CreateBackupAsync(string databasePath, string backupPath)
    {
        using var connection = new SqliteConnection($"Data Source={databasePath}");
        await connection.OpenAsync();
        var command = connection.CreateCommand();
        command.CommandText = $"VACUUM INTO '{backupPath}'";
        await command.ExecuteNonQueryAsync();
    }
}
```

---

## 13. Performance Optimizations

### Compilation Model Reuse

- **Don't** create new `CSharpCompilation` for every patch
- **Do** replace only the changed `SyntaxTree` in existing `Compilation`

### Lazy Graph Traversal

- **Limit** traversal depth (max 2-3 levels)
- **Limit** symbol count per retrieval
- Only load semantic models for files in the `MutationScope`

### SQLite Optimization

```sql
CREATE INDEX idx_edges_composite ON symbol_edges(from_id, type);
```

- **WAL Mode** — Write-Ahead Logging for concurrency
- **Weekly Vacuum** — Auto-maintenance task

### Symbol Caching Layer (RAM)

- Cache frequently accessed symbols (e.g., `MainViewModel`, `App.xaml.cs`)
- Cache hot dependency edges
- Invalidate cache entries on file modification

### Connection Pooling

```csharp
public class DatabaseConnectionFactory
{
    private readonly ConcurrentDictionary<string, SqliteConnection> _connections = new();

    public SqliteConnection GetConnection(string databasePath)
    {
        return _connections.GetOrAdd(databasePath, path =>
        {
            var connectionString = new SqliteConnectionStringBuilder
            {
                DataSource = path,
                Mode = SqliteOpenMode.ReadWriteCreate,
                Cache = SqliteCacheMode.Shared,
                Pooling = true
            }.ToString();
            return new SqliteConnection(connectionString);
        });
    }
}
```

### Retrieval Throttling

- Hard Cap: Max 200 symbols per context
- Hard Cap: Max 8KB of source code per prompt
- Force AI to request "More Context" if needed

### Caching Strategies

- **Cache SyntaxTrees** — Avoid re-parsing unchanged files
- **Incremental indexing** — Only re-index modified files
- **Lazy symbol resolution** — Load symbols on-demand
- **Batch patch operations** — Apply multiple patches in single transaction

---

## 14. Graph Integrity Verifier

**Run triggers**: Boot, Post-Restore, Post-Crash, Weekly.

### Checks

1. **File ↔ Symbol Consistency** — Recompute file hash, compare with DB. Mismatch → re-index
2. **Edge Validity** — Verify `from_id` and `to_id` exist in `symbols`. Orphan → delete
3. **XAML Binding Validation** — Verify `viewmodel_symbol_id` exists and property matches
4. **Snapshot Chain** — Verify `parent_snapshot_id` links form a valid tree (no cycles, no gaps)

### Self-Healing Repair Strategy

If corruption detected:

1. Lock Workspace
2. Create "Safety Snapshot" (backup current state)
3. **TRUNCATE** graph tables
4. Perform **Full Re-index** from disk
5. Validate Integrity
6. Resume operation

**User Feedback**: "Restoring project integrity..." (Non-blocking toast)

---

## 15. Service Contracts

### Code Intelligence Service (`IRoslynService`)

```csharp
public interface IRoslynService
{
    Task<ProjectGraph> IndexProjectAsync(string path);
    Task<List<Symbol>> FindUsagesAsync(ISymbol symbol);
    Task<SemanticModel> GetSemanticModelAsync(string filePath);
}
```

### Patch Engine (`IPatchEngine`)

```csharp
public interface IPatchEngine
{
    Task<string> ApplyPatchAsync(string filePath, PatchDefinition patch);
    Task<bool> ValidatePatchAsync(string filePath, PatchDefinition patch);
}
```

---

## Why This Architecture?

1. **Roslyn-Backed** — Relies on compiler truth, not regex
2. **Deterministic** — Same input always yields same graph state
3. **Snapshot-Safe** — DB state aligns perfectly with file system snapshots
4. **Token-Efficient** — Graph traversal prevents dumping entire codebases into LLM
5. **WinUI-Specific** — First-class handling of XAML bindings prevents MVVM drift

---

## 16. System Maturity Level

By implementing these systems, we move beyond "template generators" to a **Deterministic Windows-Native Construction Kernel**.

| Feature            | Hobby/Web Builder        | Sync AI (Production)    |
| :----------------- | :----------------------- | :---------------------- |
| **Mutation Check** | Regex/LLM Validation     | 5-Layer Semantic Guard  |
| **Concurrency**    | Race Conditions Probable | Single-Writer Mutex     |
| **Scaling**        | Fails > 10K LOC          | Optimized for 100K+ LOC |
| **Reliability**    | "It works often"         | Automated Self-Healing  |

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 7-layer overview, deployment model
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine, build system, retry logic
- [UI_IMPLEMENTATION.md](./UI_IMPLEMENTATION.md) — UI components, visual state machine
- [PREVIEW_SYSTEM.md](./PREVIEW_SYSTEM.md) — Preview rendering
````
