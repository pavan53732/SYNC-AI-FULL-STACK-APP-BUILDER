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

## 2.1 Lightweight Indexing (Lovable Mode)

For smaller projects or initial scans, we use a "shallow" index similar to Lovable/Cursor.

### File Level Index

Captured during initial scan:

```csharp
public class FileLevelIndex
{
    public string FilePath { get; set; }
    public string Hash { get; set; }
    public FileType Type { get; set; } // Component, API, Model, Config
    public List<string> Exports { get; set; } // Public classes/methods
    public List<string> Imports { get; set; } // Using statements
}
```

### Dependency Mapping (Shallow)

Stored in the `dependencies` table:

| id  | from_symbol      | to_symbol        | type     |
| :-- | :--------------- | :--------------- | :------- |
| 1   | `UserPage`       | `UserController` | `import` |
| 2   | `UserController` | `UserModel`      | `import` |
| 3   | `/api/users`     | `UserController` | `route`  |

**Best For**: UI-heavy apps, <50 files, clear file-to-component mapping.

## 2.2 Project Summary (AI Context)

The "First Thing AI Sees" to understand the project stack.

### Schema

```sql
CREATE TABLE project_summary (
    id INTEGER PRIMARY KEY CHECK (id = 1), -- Singleton
    framework TEXT NOT NULL,      -- 'React', 'WinUI', 'Blazor'
    auth_type TEXT,               -- 'Supabase', 'Firebase', 'Identity'
    database_type TEXT,           -- 'PostgreSQL', 'SQLite'
    entities TEXT,                -- JSON Array: ['User', 'Product']
    routes TEXT,                  -- JSON Array: ['/login', '/dashboard']
    api_endpoints TEXT,           -- JSON Array: ['GET /api/users']
    ui_pages TEXT,                -- JSON Array: ['LoginPage', 'Dashboard']
    last_updated DATETIME
);
```

### JSON Example

```json
{
  "framework": "React + Vite",
  "auth_type": "Supabase (Email/Password)",
  "database_type": "PostgreSQL",
  "entities": ["Users", "Projects", "Tasks"],
  "routes": ["/login", "/dashboard", "/projects/:id"],
  "api_endpoints": ["GET /api/projects", "POST /api/tasks"],
  "ui_pages": ["LoginPage", "DashboardLayout", "TaskDetail"]
}
```

## 2.2 Project Summary (AI Context)

The "First Thing AI Sees" to understand the project stack.

### Schema

```sql
CREATE TABLE project_summary (
    id INTEGER PRIMARY KEY CHECK (id = 1), -- Singleton
    framework TEXT NOT NULL,      -- 'React', 'WinUI', 'Blazor'
    auth_type TEXT,               -- 'Supabase', 'Firebase', 'Identity'
    database_type TEXT,           -- 'PostgreSQL', 'SQLite'
    entities TEXT,                -- JSON Array: ['User', 'Product']
    routes TEXT,                  -- JSON Array: ['/login', '/dashboard']
    api_endpoints TEXT,           -- JSON Array: ['GET /api/users']
    ui_pages TEXT,                -- JSON Array: ['LoginPage', 'Dashboard']
    last_updated DATETIME
);
```

### JSON Example

```json
{
  "framework": "React + Vite",
  "auth_type": "Supabase (Email/Password)",
  "database_type": "PostgreSQL",
  "entities": ["Users", "Projects", "Tasks"],
  "routes": ["/login", "/dashboard", "/projects/:id"],
  "api_endpoints": ["GET /api/projects", "POST /api/tasks"],
  "ui_pages": ["LoginPage", "DashboardLayout", "TaskDetail"]
}
```

---

## 3. Roslyn Compilation Model

### Full Compilation Builder

#### Roslyn Integration Layer Responsibilities

1.  **Parse C# files** into SyntaxTree with full fidelity.
2.  **Build Symbol Graph** (Semantic Model) for cross-file resolution.
3.  **Provide reference lookup** (Find All References).
4.  **Apply structured patches** via Syntax Rewriters.
5.  **Validate syntax** before writing to disk.
6.  **Format code** after mutation (Whitespace/Indentation).
7.  **Detect patch conflicts** (Hash mismatch, Signature mismatch).
8.  **Index XAML bindings** using dual-pass (Regex + Semantic) strategy.

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

    private async Task IndexSemanticModelAsync(string filePath, SemanticModel model)
    {
        var root = await model.SyntaxTree.GetRootAsync();
        foreach (var classDecl in root.DescendantNodes().OfType<ClassDeclarationSyntax>())
        {
            var symbol = model.GetDeclaredSymbol(classDecl);
            if (symbol != null)
            {
                await _db.ExecuteAsync("INSERT INTO semantic_symbols ...", new { Name = symbol.Name });
            }
        }
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

    private async Task<int> UpsertFileAsync(string filePath, string fileHash)
    {
        // Use RETURNING Id for efficiency (SQLite 3.35+)
        return await _db.ExecuteScalarAsync<int>(@"
            INSERT INTO files (path, hash, last_modified_utc, language, snapshot_id)
            VALUES (@Path, @Hash, @LastModified, 'cs', @SnapshotId)
            ON CONFLICT(path) DO UPDATE SET
                hash = excluded.hash,
                last_modified_utc = excluded.last_modified_utc
            RETURNING id;",
            new
            {
                Path = filePath,
                Hash = fileHash,
                LastModified = File.GetLastWriteTimeUtc(filePath),
                SnapshotId = 1 // Placeholder
            });
    }

    private string ComputeFileHash(string content)
    {
        using var sha256 = System.Security.Cryptography.SHA256.Create();
        var bytes = System.Text.Encoding.UTF8.GetBytes(content);
        var hash = sha256.ComputeHash(bytes);
        return Convert.ToBase64String(hash);
    }

    private string GetAccessibility(SyntaxTokenList modifiers)
    {
        if (modifiers.Any(m => m.IsKind(SyntaxKind.PublicKeyword))) return "public";
        if (modifiers.Any(m => m.IsKind(SyntaxKind.PrivateKeyword))) return "private";
        if (modifiers.Any(m => m.IsKind(SyntaxKind.ProtectedKeyword))) return "protected";
        if (modifiers.Any(m => m.IsKind(SyntaxKind.InternalKeyword))) return "internal";
        return "internal"; // Default
    }
}
```

### Partial Class Strategy

- **Merging**: Symbols with same `FullyQualifiedName` are merged.
- **File Mapping**: `symbol_nodes` entry created for _each_ file contribution.
- **Navigation**: "Go to Definition" lists all partial files.

### Extension Method Strategy

- **Indexing**: Indexed as static methods with `Extension` kind.
- **Resolution**:
  1. Match receiver type.
  2. Check `this` parameter type.
  3. Verify namespace availability in consuming file.

### Graph Update Algorithms

We handle three distinct mutation scenarios to maintain graph consistency.

#### Scenario A: On File Change (Single File Mutation)

Triggered by `FileSystemWatcher` or IDE event.

1.  **Create new snapshot ID** (e.g., `Snapshot_N+1`).
2.  **Clear old records** for this file in _current_ snapshot context.
3.  **Parse with Roslyn** to generate new `SyntaxTree`.
4.  **Extract & Insert Syntax Nodes** (`syntax_nodes`).
5.  **Resolve Semantic Model** (Update Compilation).
6.  **Insert Symbols** (`symbol_nodes`).
7.  **Resolve & Insert Edges** (`symbol_edges`).
8.  **Handle XAML** (if `.xaml` or `.cs` paired file).
9.  **Commit transaction** (Atomic Switch).

```csharp
public async Task UpdateGraphForFileAsync(string filePath, string newContent)
{
    using var transaction = _connection.BeginTransaction();
    try
    {
        var nextSnapshotId = await _snapshotService.CreateNextSnapshotAsync();
        await ClearFileRecordsAsync(filePath, nextSnapshotId);

        // ... (Parsing and Insertion Logic) ...

        await _snapshotService.SetActiveSnapshotAsync(nextSnapshotId);
        transaction.Commit();
    }
    catch { transaction.Rollback(); throw; }
}
```

#### Scenario B: On Snapshot Restore (Time Travel)

Triggered by User Timeline. **Zero re-indexing required.**

1.  **Rollback file system** (IO operation).
2.  **Set Active Snapshot ID** in Orchestrator (`CurrentSnapshotId = X`).
3.  **DB remains untouched** (Historical data is preserved in `symbol_nodes`).
4.  **Clear Caches** (Invalidate `Compilation` and RAM caches).

#### Scenario C: Full Rebuild (Corruption Recovery)

Triggered by `GraphIntegrityVerifier` failure.

1.  **Delete all graph records** (`DELETE FROM files; DELETE FROM symbols...`).
2.  **Iterate all files** in workspace.
3.  **Batch insert files** (`files` table).
4.  **Batch process** syntax and semantics (Parallelized).
5.  **Rebuild indexes**.

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

INSERT INTO Settings (Key, Value, DataType, ModifiedDate) VALUES
('AutoSaveInterval', '5', 'Integer', CURRENT_TIMESTAMP),
('Theme', 'Dark', 'String', CURRENT_TIMESTAMP),
('MaxHistory', '50', 'Integer', CURRENT_TIMESTAMP);

CREATE TABLE RecentPrompts (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Prompt TEXT NOT NULL,
    UsageCount INTEGER DEFAULT 1,
    LastUsedDate DATETIME NOT NULL,
    ProjectId TEXT,
    FOREIGN KEY (ProjectId) REFERENCES Projects(Id) ON DELETE SET NULL
);
CREATE INDEX idx_recent_prompts_date ON RecentPrompts(LastUsedDate DESC);

CREATE TABLE UserPreferences (
    Id INTEGER PRIMARY KEY CHECK (Id = 1), -- Singleton
    Theme TEXT DEFAULT 'Dark',
    AutoSave INTEGER DEFAULT 1,
    CopilotEnabled INTEGER DEFAULT 1,
    LastUpdated DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ProjectMetadata (
    Id TEXT PRIMARY KEY,
    Name TEXT NOT NULL,
    LastAccessed DATETIME,
    FrameworkVersion TEXT,
    FrameworkVersion TEXT,
    FOREIGN KEY (Id) REFERENCES Projects(Id) ON DELETE CASCADE
);



```

### Project Graph Database (project_graph.db)

Multi-layer graph model: File → Syntax → Symbol → Edge → XAML → Version.

````sql
-- File layer
CREATE TABLE files (
    id INTEGER PRIMARY KEY,
    path TEXT NOT NULL UNIQUE,
    hash TEXT NOT NULL,
    last_modified_utc TEXT NOT NULL,
    language TEXT NOT NULL,        -- 'cs', 'xaml', 'xml', 'json'
    type TEXT DEFAULT 'component', -- 'component', 'api', 'model', 'config' (Lovable Mode)
    snapshot_id INTEGER NOT NULL
);
CREATE INDEX idx_files_snapshot ON files(snapshot_id);
CREATE INDEX idx_files_path ON files(path);

CREATE TABLE syntax_trees (
    id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,
    json_blob TEXT NOT NULL,
    FOREIGN KEY(file_id) REFERENCES files(id)
);

CREATE TABLE semantic_symbols (
    id INTEGER PRIMARY KEY,
    symbol_id INTEGER NOT NULL,
    embedding_vector BLOB,
    documentation_xml TEXT,
    FOREIGN KEY(symbol_id) REFERENCES symbol_nodes(id)
);

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
CREATE TABLE symbol_nodes (
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
CREATE INDEX idx_symbol_nodes_fqn ON symbol_nodes(fully_qualified_name);
CREATE INDEX idx_symbol_nodes_snapshot ON symbol_nodes(snapshot_id);

-- Edge layer (directed semantic relationships)
CREATE TABLE symbol_edges (
    id INTEGER PRIMARY KEY,
    from_symbol_id INTEGER NOT NULL,
    to_symbol_id INTEGER NOT NULL,
    edge_type TEXT NOT NULL,       -- 'CALLS', 'INHERITS', 'IMPLEMENTS', 'REFERENCES', 'INJECTS', 'BINDS', 'OVERRIDES', 'GENERIC_CONSTRAINT'
    snapshot_id INTEGER NOT NULL,
    FOREIGN KEY(from_symbol_id) REFERENCES symbol_nodes(id),
    FOREIGN KEY(to_symbol_id) REFERENCES symbol_nodes(id)
);
-- Invariant: For every forward edge, a reverse traversal path must exist (physically or logically).
CREATE INDEX idx_symbol_edges_from ON symbol_edges(from_symbol_id);
CREATE INDEX idx_symbol_edges_to ON symbol_edges(to_symbol_id);

-- Snapshot layer (Graph Versioning)
CREATE TABLE snapshots (
    id INTEGER PRIMARY KEY,
    parent_snapshot_id INTEGER,
    description TEXT,
    created_utc TEXT NOT NULL,
    is_active INTEGER DEFAULT 0,
    FOREIGN KEY(parent_snapshot_id) REFERENCES snapshots(id)
);

CREATE TABLE graph_snapshots (
    id INTEGER PRIMARY KEY,
    snapshot_id INTEGER NOT NULL,
    symbol_count INTEGER,
    edge_count INTEGER,
    FOREIGN KEY(snapshot_id) REFERENCES snapshots(id)
);


-- XAML binding layer
CREATE TABLE xaml_bindings (
    id INTEGER PRIMARY KEY,
    xaml_file_id INTEGER NOT NULL,
    viewmodel_symbol_id INTEGER NOT NULL,
    binding_property TEXT NOT NULL,
    binding_target TEXT NOT NULL,
    snapshot_id INTEGER NOT NULL,
    FOREIGN KEY(xaml_file_id) REFERENCES files(id),
    FOREIGN KEY(viewmodel_symbol_id) REFERENCES symbol_nodes(id)
);

-- Bidirectional File Graph (Enterprise)
CREATE TABLE file_nodes (
    id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,
    path TEXT NOT NULL,
    FOREIGN KEY(file_id) REFERENCES files(id)
);

CREATE TABLE file_edges (
    id INTEGER PRIMARY KEY,
    from_file_id INTEGER NOT NULL,
    to_file_id INTEGER NOT NULL,
    edge_type TEXT NOT NULL, -- 'IMPORTS', 'DEFINES'
    FOREIGN KEY(from_file_id) REFERENCES file_nodes(id),
    FOREIGN KEY(to_file_id) REFERENCES file_nodes(id)
);

-- Version Control (Enterprise)
CREATE TABLE graph_deltas (
    id INTEGER PRIMARY KEY,
    snapshot_id INTEGER NOT NULL,
    delta_type TEXT NOT NULL, -- 'SYMBOL_ADDED', 'SYMBOL_REMOVED', 'EDGE_ADDED'
    entity_id INTEGER NOT NULL,
    entity_table TEXT NOT NULL,
    FOREIGN KEY(snapshot_id) REFERENCES snapshots(id)
);

-- Lightweight Dependency Graph (Lovable Mode)
CREATE TABLE dependencies (
    id INTEGER PRIMARY KEY,
    from_symbol_id INTEGER NOT NULL,
    to_symbol_id INTEGER NOT NULL,
    relation_type TEXT NOT NULL -- 'import', 'export', 'route', 'db'
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


CREATE TABLE versions (
    id INTEGER PRIMARY KEY,
    snapshot_id INTEGER NOT NULL,
    summary TEXT NOT NULL,
    build_status TEXT NOT NULL,
    created_utc TEXT NOT NULL,
    FOREIGN KEY(snapshot_id) REFERENCES snapshots(id)
);

## 5.3 Snapshot Storage Optimization

Snapshots must use:

* Logical Graph Deltas + GZip File Snapshots

Rules:

* Store deltas, not full copies
* Materialize files only on restore
* Weekly vacuum + compaction

Prevents disk explosion on large projects.

### Snapshot Compression Strategy

```csharp
public class SnapshotCompressionStrategy
{
    public async Task<byte[]> CompressAsync(string snapshotPath)
    {
        using var sourceStream = File.OpenRead(snapshotPath);
        using var memoryStream = new MemoryStream();
        using var gzipStream = new System.IO.Compression.GZipStream(memoryStream, System.IO.Compression.CompressionMode.Compress);
        await sourceStream.CopyToAsync(gzipStream);
        return memoryStream.ToArray();
    }
}
````

````

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

CREATE TABLE TaskSnapshots (
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
````

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

## 5. Knowledge Graph Structure

### Vector Layer (project_graph.db)

Manage semantic embeddings for symbols and files.

```csharp
public class VectorEmbedding
{
    public string Id { get; set; }
    public string SymbolId { get; set; }
    public float[] Values { get; set; }
    public string Model { get; set; } // e.g., "text-embedding-3-small"
    public DateTime Created { get; set; }
    public int Dimensions { get; set; }
}
```

### Versioned Knowledge Graph

Track evolution of the project graph over time.

```sql
CREATE TABLE GraphSnapshots (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    commit_hash TEXT NOT NULL,
    s3_path TEXT,
    node_count INTEGER DEFAULT 0,
    edge_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_graph_snapshots_project ON GraphSnapshots(project_id);
CREATE INDEX idx_graph_snapshots_commit ON GraphSnapshots(commit_hash);
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

public class PatchValidationResult
{
    public bool IsValid { get; set; }
    public string ErrorMessage { get; set; }
    public string ErrorCode { get; set; }
}

public class BatchPatchResult
{
    public bool Success { get; set; }
    public List<PatchResult> Results { get; set; }
    public string BatchId { get; set; }
}

public class MethodParameter
{
    public string Type { get; set; }
    public string Name { get; set; }
    public string DefaultValue { get; set; }
    public bool IsParams { get; set; }
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
    public string Modifiers { get; set; } = "public";
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
    public string Modifiers { get; set; } = "public";
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
        var filePath = patch.TargetFile;
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

    private string ComputeFileHash(string content)
    {
        using var sha256 = System.Security.Cryptography.SHA256.Create();
        var bytes = System.Text.Encoding.UTF8.GetBytes(content);
        var hash = sha256.ComputeHash(bytes);
        return Convert.ToBase64String(hash);
    }

    public async Task<PatchValidationResult> ValidatePatchAsync(PatchOperation patch)
    {
        if (patch.Payload == null)
            return new PatchValidationResult { IsValid = false, ErrorMessage = "Payload is null" };

        if (string.IsNullOrEmpty(patch.TargetFile))
            return new PatchValidationResult { IsValid = false, ErrorMessage = "Target file is required" };

        // Operation-specific validation
        return patch.OperationType switch
        {
            PatchOperationType.ADD_METHOD => ValidateAddMethod((AddMethodPayload)patch.Payload),
            PatchOperationType.ADD_CLASS => ValidateAddClass((AddClassPayload)patch.Payload),
            _ => new PatchValidationResult { IsValid = true }
        };
    }

    private SyntaxNode ApplyAddClass(SyntaxNode root, AddClassPayload payload)
    {
        var namespaceDecl = root.DescendantNodes()
            .OfType<NamespaceDeclarationSyntax>()
            .FirstOrDefault(n => n.Name.ToString() == payload.Namespace);

        if (namespaceDecl == null)
        {
            // Create namespace if missing
            namespaceDecl = SyntaxFactory.NamespaceDeclaration(SyntaxFactory.ParseName(payload.Namespace));
            // In a real scenario, we'd add this to a new CompilationUnit
            // For now, assuming root is CompilationUnit
            if (root is CompilationUnitSyntax cu)
            {
                 root = cu.AddMembers(namespaceDecl);
                 // Re-fetch to get the node inside the new root
                 namespaceDecl = root.DescendantNodes().OfType<NamespaceDeclarationSyntax>().Last();
            }
        }

        var modifiers = ParseModifiers(payload.Modifiers); // e.g., "public partial"
        var classDecl = SyntaxFactory.ClassDeclaration(payload.ClassName)
            .WithModifiers(modifiers);

        // Add Base Class
        if (!string.IsNullOrEmpty(payload.BaseClass))
        {
             classDecl = classDecl.AddBaseListTypes(
                SyntaxFactory.SimpleBaseType(SyntaxFactory.ParseTypeName(payload.BaseClass)));
        }

        // Add Interfaces
        if (payload.Interfaces != null && payload.Interfaces.Any())
        {
            var interfaceTypes = payload.Interfaces.Select(i =>
                SyntaxFactory.SimpleBaseType(SyntaxFactory.ParseTypeName(i))).ToArray();
            classDecl = classDecl.AddBaseListTypes(interfaceTypes);
        }

        var newNamespace = namespaceDecl.AddMembers(classDecl);
        return root.ReplaceNode(namespaceDecl, newNamespace);
    }

    private SyntaxNode ApplyAddMethod(SyntaxNode root, AddMethodPayload payload)
    {
        var classDecl = root.DescendantNodes()
            .OfType<ClassDeclarationSyntax>()
            .FirstOrDefault(c => c.Identifier.Text == payload.TargetClass);

        if (classDecl == null) return root;

        var modifiers = ParseModifiers(payload.Modifiers ?? "public");

        var methodDecl = SyntaxFactory.MethodDeclaration(
            SyntaxFactory.ParseTypeName(payload.ReturnType),
            payload.MethodName)
            .WithModifiers(modifiers);

        // Add Parameters
        if (payload.Parameters != null)
        {
            var parameters = payload.Parameters.Select(p =>
                SyntaxFactory.Parameter(SyntaxFactory.Identifier(p.Name))
                    .WithType(SyntaxFactory.ParseTypeName(p.Type)))
                .ToArray();

            methodDecl = methodDecl.WithParameterList(SyntaxFactory.ParameterList(SyntaxFactory.SeparatedList(parameters)));
        }

        // Add Body
        methodDecl = methodDecl.WithBody(SyntaxFactory.Block(SyntaxFactory.ParseStatement(payload.MethodBody)));

        var newClass = classDecl.AddMembers(methodDecl);
        return root.ReplaceNode(classDecl, newClass);
    }

    private SyntaxTokenList ParseModifiers(string modifiers)
    {
        var list = new List<SyntaxToken>();
        foreach (var mod in modifiers.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            var kind = ParseAccessibility(mod);
            if (kind != SyntaxKind.None) list.Add(SyntaxFactory.Token(kind));
        }
        return SyntaxTokenList.Create(list.ToArray());
    }

    private SyntaxKind ParseAccessibility(string modifier)
    {
        return modifier.ToLower() switch
        {
            "public" => SyntaxKind.PublicKeyword,
            "private" => SyntaxKind.PrivateKeyword,
            "protected" => SyntaxKind.ProtectedKeyword,
            "internal" => SyntaxKind.InternalKeyword,
            "static" => SyntaxKind.StaticKeyword,
            "async" => SyntaxKind.AsyncKeyword,
            "partial" => SyntaxKind.PartialKeyword,
            _ => SyntaxKind.None
        };
    }

    private SyntaxNode ApplyModifyMethodBody(SyntaxNode root, ModifyMethodBodyPayload payload)
    {
        var methodDecl = root.DescendantNodes()
            .OfType<MethodDeclarationSyntax>()
            .FirstOrDefault(m => m.Identifier.Text == payload.MethodName &&
                                 m.Parent is ClassDeclarationSyntax c &&
                                 c.Identifier.Text == payload.TargetClass);

        if (methodDecl == null) return root;

        var newBody = SyntaxFactory.Block(SyntaxFactory.ParseStatement(payload.NewMethodBody));
        var newMethod = methodDecl.WithBody(newBody);
        return root.ReplaceNode(methodDecl, newMethod);
    }

    private SyntaxNode ApplyAddProperty(SyntaxNode root, AddPropertyPayload payload)
    {
        var classDecl = root.DescendantNodes()
            .OfType<ClassDeclarationSyntax>()
            .FirstOrDefault(c => c.Identifier.Text == payload.TargetClass);

        if (classDecl == null) return root;

        var propertyDecl = SyntaxFactory.PropertyDeclaration(
            SyntaxFactory.ParseTypeName(payload.PropertyType),
            payload.PropertyName)
            .WithModifiers(SyntaxTokenList.Create(SyntaxFactory.Token(SyntaxKind.PublicKeyword)))
            .WithAccessorList(SyntaxFactory.AccessorList(SyntaxFactory.List(new[]
            {
                SyntaxFactory.AccessorDeclaration(SyntaxKind.GetAccessorDeclaration)
                    .WithSemicolonToken(SyntaxFactory.Token(SyntaxKind.SemicolonToken)),
                SyntaxFactory.AccessorDeclaration(SyntaxKind.SetAccessorDeclaration)
                    .WithSemicolonToken(SyntaxFactory.Token(SyntaxKind.SemicolonToken))
            })));

        var newClass = classDecl.AddMembers(propertyDecl);
        return root.ReplaceNode(classDecl, newClass);
    }

    private PatchValidationResult ValidateAddMethod(AddMethodPayload payload)
    {
        if (string.IsNullOrEmpty(payload.TargetClass))
            return new PatchValidationResult { IsValid = false, ErrorMessage = "Target class is required" };
        if (string.IsNullOrEmpty(payload.MethodName))
            return new PatchValidationResult { IsValid = false, ErrorMessage = "Method name is required" };
        return new PatchValidationResult { IsValid = true };
    }

    private PatchValidationResult ValidateAddClass(AddClassPayload payload)
    {
        if (string.IsNullOrEmpty(payload.Namespace))
            return new PatchValidationResult { IsValid = false, ErrorMessage = "Namespace is required" };
        if (string.IsNullOrEmpty(payload.ClassName))
            return new PatchValidationResult { IsValid = false, ErrorMessage = "Class name is required" };
        return new PatchValidationResult { IsValid = true };
    }
}
```

---

## 6.1 Deterministic Pre-Commit Sandbox

> **Invariant**: Snapshot ID is frozen before patch application. All symbol access must use this ID.

1. Freeze graph state
2. Apply patch in temp/sandbox directory
3. Run `dotnet build` (or design-time build)
4. Only commit if successful

## 6.2 Testing Strategy

Mandated unit tests for patch success, hash mismatch, breaking changes, rollback, and XAML binding breaks. No mutation engine without test coverage.

### Unit Testing Patterns

#### ApplyPatch_AddMethod_Success

```csharp
[Fact]
public async Task ApplyPatch_AddMethod_Success()
{
    // Arrange
    var code = "public class Foo {}";
    var patch = new PatchOperation {
        Type = PatchType.AddMethod,
        TargetClass = "Foo",
        Payload = new AddMethodPayload {
            MethodName = "Bar",
            ReturnType = "void",
            Modifiers = "public"
        }
    };

    // Act
    var result = await _patchEngine.ApplyPatchAsync(code, patch);

    // Assert
    Assert.True(result.Success);
    Assert.Contains("public void Bar()", result.NewCode);
    Assert.Contains("}", result.NewCode); // Class closed
}
```

#### ApplyPatch_FileHashMismatch_Fails

```csharp
[Fact]
public async Task ApplyPatch_FileHashMismatch_Fails()
{
    // Arrange
    var originalHash = "abc123hash";
    var patch = new PatchOperation {
        TargetFile = "Foo.cs",
        ExpectedFileHash = "old_hash_xyz" // Deliberately wrong
    };

    // Act
    var result = await _patchEngine.ApplyPatchAsync(patch);

    // Assert
    Assert.False(result.Success);
    Assert.Equal(PatchErrorType.FileHashMismatch, result.Error);
}
```

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

### Patch Verification

```csharp
public interface IPatchVerifier
{
    Task<PatchValidationResult> VerifyAsync(PatchOperation patch, MutationScope scope);
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

### Regex Strategy (Fallback)

Used when XML parsing fails or for fast scanning:

- **x:Bind**: `\{x:Bind\s+(?<path>[^,}]+)`
- **Binding**: `\{Binding\s+(?<path>[^,}]+)`
- **Method**: `\{x:Bind\s+(?<method>\w+)\(`

```csharp
public class XamlBindingIndexer
{
    // Regex fallback for robust parsing when XML is malformed
    private static readonly Regex XBindRegex = new(@"\{x:Bind\s+(?<path>[^,}]+)", RegexOptions.Compiled);
    private static readonly Regex BindingRegex = new(@"\{Binding\s+(?<path>[^,}]+)", RegexOptions.Compiled);

    public async Task IndexXamlFileAsync(string xamlPath)
    {
        var xaml = await File.ReadAllTextAsync(xamlPath);

        // 1. Try robust Regex extraction first (for speed and resilience)
        var regexBindings = XBindRegex.Matches(xaml).Concat(BindingRegex.Matches(xaml));
        foreach (Match match in regexBindings)
        {
             var path = match.Groups["path"].Value;
             await IndexBindingAsync(xamlPath, path, "Regex");
        }

        // 2. Try precise XML parsing (for depth)
        try
        {
            var doc = XDocument.Parse(xaml);
            var xmlBindings = doc.Descendants()
                .SelectMany(e => e.Attributes())
                .Where(a => a.Value.Contains("{x:Bind") || a.Value.Contains("{Binding"))
                .Select(a => ExtractBindingPath(a.Value));

            foreach (var binding in xmlBindings)
            {
                 // Upsert with higher confidence
                 await IndexBindingAsync(xamlPath, binding.Path, "XML");
            }

            // Extract x:Name for code-behind linking
            var namedElements = doc.Descendants()
                .Where(e => e.Attribute(XName.Get("Name", "http://schemas.microsoft.com/winfx/2006/xaml")) != null);

            foreach (var element in namedElements)
            {
                var name = element.Attribute(
                    XName.Get("Name", "http://schemas.microsoft.com/winfx/2006/xaml")).Value;
                await StoreXamlBindingAsync(xamlPath, name, element);
            }
        }
        catch (XmlException)
        {
            // Fallback to regex-only results if XML is broken
        }
    }
}
```

---

## 9. Intent Classification

Analyze user prompts to determine the required operation.

```csharp
public enum UserIntent
{
    GeneralQuestion,
    CodeExplanation,
    Refactoring,
    BugFix,
    FeatureAddition,
    TestGeneration
}

public class IntentClassifier
{
    public async Task<UserIntent> ClassifyAsync(string prompt)
    {
        // ... Implementation using lightweight LLM or keyword analysis
        return UserIntent.FeatureAddition;
    }
}
```

---

## 10. Mutation Safety Guards

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

### Impact Analysis SQL (Recursive CTE)

```sql
WITH RECURSIVE SymbolGenerations AS (
    -- Generation 0: The target symbol
    SELECT id, file_id, 0 AS generation
    FROM symbol_nodes
    WHERE fully_qualified_name = @TargetSymbol

    UNION ALL

    -- Recursively find dependents (who calls me?)
    SELECT e.from_symbol_id, s.file_id, g.generation + 1
    FROM symbol_edges e
    JOIN SymbolGenerations g ON e.to_symbol_id = g.id
    JOIN symbol_nodes s ON e.from_symbol_id = s.id
    WHERE g.generation < 2 -- Limit depth
)
SELECT DISTINCT file_id FROM SymbolGenerations;
```

### Layer 3: Breaking Change Detection

If the patch modifies public contracts (method signatures, interface definitions, constructor parameters, ViewModel properties bound in XAML):

**Action**: Simulate resolution of dependent symbols. If any become unresolved → **BLOCK**.

### Layer 4: AST Simulation (Dry Run)

1. Clone the SyntaxTree in memory
2. Apply the patch transformation
3. Build a temporary compilation context
4. Validate type resolution, symbol references, binding validity

**Action**: If compilation errors appear → **REJECT**.

## 10.1 Concurrency & Execution Ordering Guarantees

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

## 10.2 Guard Failure Escalation Policy

The AI does NOT get infinite retries:

1. **Attempt 1 (Soft Rejection)** — Return tailored error (e.g., "Symbol Foo not found")
2. **Attempt 2 (Hard Rejection)** — Return "Breaking Change Detected" with impact path
3. **Attempt 3 (Barrier Failure)** — **STOP AUTOMATION**. Transition to `INTERVENTION_REQUIRED`. Prompt user: "Should I: (A) Force apply? (B) Revert? (C) Create new file instead?"

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

## 11. AI Retrieval System

### 11.1 Retrieval Pipeline (Context Assembly)

Optimized for **token efficiency** and **relevance**.

### Context Assembly (Prioritized Order)

1. **System Rules** — WinUI constraints
2. **Project Summary** — High-level architecture
3. **Throttling Enforcement**:
   ```csharp
   if (contextLength > 8000) throw new ContextLimitExceededException();
   ```
4. **Target Symbol Definition** — Full code of target
5. **Direct Dependencies** — Interfaces, services used
6. **XAML Bindings** — Corresponding XAML file
7. **Error Context** — If in fix mode

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
````

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

### Project Summary Example

```json
{
  "framework": "WinUI 3",
  "authType": "EntraID",
  "databaseType": "SQLite",
  "entities": ["Customer", "Order", "Product"],
  "routes": ["/home", "/settings", "/dashboard"],
  "apiEndpoints": ["GET /api/orders", "POST /api/login"]
}
```

---

### 13.4 Retrieval Throttling Rules

- Hard Cap: Max 200 symbols per context
- Hard Cap: Max 8KB of source code per prompt
- Force AI to request "More Context" if needed

---

### 11.2 Vector Index (Embeddings)

We generate embeddings for:

1.  **File Summaries** (High-level intent)
2.  **Symbol Signatures** (API surface)
3.  **Documentation Comments** (Semantic meaning)

```csharp
public class VectorIndex
{
    public async Task IndexFileEmbeddingAsync(string filePath, string content)
    {
        var embedding = await _embeddingService.GenerateAsync(content);
        await _db.ExecuteAsync(
            "INSERT INTO file_embeddings (file_id, vector) VALUES (@Id, @Vector)",
            new { Id = GetFileId(filePath), Vector = embedding });
    }

    public async Task<List<string>> SemanticSearchAsync(string query)
    {
        var queryVector = await _embeddingService.GenerateAsync(query);
        // Cosine similarity search (using SQLite-vss or manual math)
        return await _db.SearchAsync(queryVector, limit: 10);
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

### Specialized Repositories

```csharp
public interface IProjectRepository : IRepository<Project> { }
public interface ISymbolRepository : IRepository<Symbol>
{
    Task<IEnumerable<Symbol>> GetByFileAsync(long fileId);
}
public interface ITaskRepository : IRepository<TaskItem> { }
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
        }
    }

    private async Task EnsureMigrationsTableAsync()
    {
        await _connection.ExecuteAsync(@"
            CREATE TABLE IF NOT EXISTS Migrations (
                Version INTEGER PRIMARY KEY,
                Description TEXT,
                AppliedDate DATETIME DEFAULT CURRENT_TIMESTAMP
            );");
    }

    private async Task RecordMigrationAsync(int version, string description)
    {
        await _connection.ExecuteAsync(
            "INSERT INTO Migrations (Version, Description) VALUES (@Version, @Description)",
            new { Version = version, Description = description });
    }
}
```

### Backup & Recovery

````csharp
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

    public async Task RestoreBackupAsync(string backupPath, string databasePath)
    {
        // Simple file copy strategy for SQLite
        await using var source = File.OpenRead(backupPath);
        await using var dest = File.Create(databasePath);
        await source.CopyToAsync(dest);
    }

    public Task CreateAutoBackupAsync(string dbPath) =>
        CreateBackupAsync(dbPath, $"{dbPath}.{DateTime.Now:yyyyMMddHHmmss}.bak");
}

### Connection Pooling Model

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
CREATE INDEX idx_edges_composite ON symbol_edges(from_symbol_id, edge_type, snapshot_id);
````

- **WAL Mode** — Write-Ahead Logging for concurrency
- **Weekly Vacuum** — Auto-maintenance task

### Symbol Caching Layer (RAM)

- Cache frequently accessed symbols (e.g., `MainViewModel`, `App.xaml.cs`)
- Cache hot dependency edges
- Invalidate cache entries on file modification

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

### Scenario B: On Snapshot Restore

When the user reverts to a previous Snapshot (via Timeline):

1.  **Stop** all indexing/patching.
2.  **Close** existing SQLite connections.
3.  **Replace** `project_graph.db` with the snapshot version.
4.  **Clear** in-memory `Compilation` cache.
5.  **Restart** Orchestrator in `Idle` state.
6.  **Trigger** background consistency check.

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
    Task<PatchResult> ApplyPatchAsync(PatchOperation patch);
    Task<PatchValidationResult> ValidatePatchAsync(PatchOperation patch);
    Task<BatchPatchResult> ApplyPatchBatchAsync(PatchOperation[] patches);
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

### Characteristics Comparison

| Feature             | Lovable-Level (Lightweight) | Enterprise-Level (Sync AI)     |
| :------------------ | :-------------------------- | :----------------------------- |
| **AST Depth**       | Regex / Shallow Parse       | Full Roslyn Syntax Tree        |
| **Index Speed**     | < 1s                        | 5-10s (Initial), < 100ms (Inc) |
| **Refactor Safety** | Low (Text Replacements)     | High (Semantic Awareness)      |
| **Storage**         | ~2MB JSON                   | ~50MB SQLite Graph             |
| **Determinism**     | Probabilistic (LLM)         | Deterministic (Compiler)       |

### When Works Best

- **Lovable Model**: UI Prototyping, Single-File Edits, "Make it look pretty" tasks.
- **Sync AI Model**: Complex Refactoring, API Integration, "Rename this method everywhere" tasks, >100K LOC Repos.

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 7-layer overview, deployment model
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine, build system, retry logic
- [UI_IMPLEMENTATION.md](./UI_IMPLEMENTATION.md) — UI components, visual state machine
- [PREVIEW_SYSTEM.md](./PREVIEW_SYSTEM.md) — Preview rendering

```

```

---
