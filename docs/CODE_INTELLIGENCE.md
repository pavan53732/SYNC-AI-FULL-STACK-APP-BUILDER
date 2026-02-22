# CODE INTELLIGENCE

> **The Knowledge Layer: Roslyn Integration, Semantic Indexing, Database Schema, Patch Engine & Mutation Safety**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> _The Code Intelligence layer provides knowledge to the AI Construction Engine. The Runtime Safety Kernel enforces mutation boundaries._

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
10. [Concurrency & Guard Failure Policy](#10-concurrency--guard-failure-policy)
11. [Impact Analysis Engine](#11-impact-analysis-engine)
12. [AI Retrieval Pipeline](#12-ai-retrieval-pipeline)
13. [Database Access Layer](#13-database-access-layer)
14. [Performance Optimizations](#14-performance-optimizations)
15. [Graph Integrity Verifier](#15-graph-integrity-verifier)
16. [Service Contracts](#16-service-contracts)

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

### Indexing Policy

The system uses a **tiered indexing approach** optimized for different scenarios:

**Full Semantic Mode** (Default for Production Operations):
- Full Roslyn AST, symbol graph, and cross-file resolution.
- Required for all mutation operations and capability inference.
- Ensures consistent, deterministic behavior for code changes.

**Lightweight Mode** (Initial Scans and Quick Lookups):
- Shallow metadata index for fast project overview.
- Used for initial project discovery and UI listings.
- Automatically upgraded to Full Semantic when mutations are needed.

### Mutation Mode Enforcement (INVARIANT)

> **CRITICAL**: All mutation operations MUST use Full Semantic Mode. Lightweight Mode is strictly FORBIDDEN for any operation that modifies code.

```csharp
public class MutationModeEnforcer
{
    /// <summary>
    /// Called BEFORE any patch operation. Throws if not in Full Semantic Mode.
    /// </summary>
    public void EnsureFullSemanticModeForMutation(IndexingMode currentMode)
    {
        if (currentMode != IndexingMode.FULL_SEMANTIC)
        {
            throw new InvalidOperationException(
                "MUTATION_REQUIRES_FULL_SEMANTIC: " +
                "All mutation operations require Full Semantic Mode. " +
                "Current mode: " + currentMode + ". " +
                "Call UpgradeToFullSemanticModeAsync() before attempting mutations.");
        }
    }
}

public enum IndexingMode
{
    LIGHTWEIGHT,    // Shallow metadata only
    FULL_SEMANTIC   // Complete Roslyn AST + symbol graph
}
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

## 2.1 Lightweight Indexing

For smaller projects or initial scans, we use a "shallow" index.

### Symbol-Level Index (Shallow)

Lightweight symbol extraction using regex — no full AST required.

```csharp
public class SymbolExtractor
{
    public async Task<List<Symbol>> ExtractSymbolsAsync(string filePath)
    {
        var code = await File.ReadAllTextAsync(filePath);
        var symbols = new List<Symbol>();

        // Lightweight parsing (regex) - C# syntax patterns
        var classMatches = Regex.Matches(code, @"(?:public|internal|private|protected)?\s*(?:partial\s+)?class\s+(\w+)");
        foreach (Match match in classMatches)
        {
            symbols.Add(new Symbol
            {
                Name = match.Groups[1].Value,
                Kind = "class",
                Exported = match.Value.Contains("public") || match.Value.Contains("internal")
            });
        }

        var methodMatches = Regex.Matches(code, @"(?:public|private|protected|internal)\s+(?:static\s+)?(?:async\s+)?(?:[\w<>]+)\s+(\w+)\s*\(");
        foreach (Match match in methodMatches)
        {
            symbols.Add(new Symbol
            {
                Name = match.Groups[1].Value,
                Kind = "method",
                Exported = match.Value.Contains("public")
            });
        }

        return symbols;
    }
}
```

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

        return compilation;
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

### Graph Update Algorithms

Triggered by `FileSystemWatcher` or IDE event:

1. Create new snapshot ID (e.g., `Snapshot_N+1`).
2. Clear old records for this file in current snapshot context.
3. Parse with Roslyn to generate new `SyntaxTree`.
4. Extract & Insert Syntax Nodes (`syntax_nodes`).
5. Insert Symbols (`symbol_nodes`).
6. Resolve & Insert Edges (`symbol_edges`).
7. Commit transaction (Atomic Switch).

---

## 5. Database Schema

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
    type TEXT DEFAULT 'component', -- 'component', 'api', 'model', 'config'
    snapshot_id INTEGER NOT NULL
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
    FOREIGN KEY(viewmodel_symbol_id) REFERENCES symbol_nodes(id)
);
CREATE INDEX idx_xaml_vm ON xaml_bindings(viewmodel_symbol_id);

-- Snapshot layer (Graph Versioning)
CREATE TABLE snapshots (
    id INTEGER PRIMARY KEY,
    parent_snapshot_id INTEGER,
    created_utc TEXT NOT NULL,
    reason TEXT NOT NULL,          -- 'Pre-Generation', 'Post-Patch', 'Manual'
    FOREIGN KEY(parent_snapshot_id) REFERENCES snapshots(id)
);

-- Vector Embeddings Layer
CREATE TABLE file_embeddings (
    id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,
    vector BLOB NOT NULL,           -- Serialized float array
    model TEXT,                     -- e.g., 'text-embedding-3-small'
    created_utc TEXT NOT NULL,
    FOREIGN KEY(file_id) REFERENCES files(id)
);
CREATE INDEX idx_file_embeddings_file ON file_embeddings(file_id);
```

### Generated Assets Table (Cross-Reference)

> **NOTE**: The `generated_assets` table for tracking AI-generated visual assets (icons, logos, splash screens)
> is defined in [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) Section 6.2.
>
> This table is managed by the Platform Requirements Engine, not the Code Intelligence layer.

**For reference, the schema is:**

```sql
-- See PLATFORM_REQUIREMENTS_ENGINE.md for full implementation
CREATE TABLE generated_assets (
    id INTEGER PRIMARY KEY,
    project_id TEXT NOT NULL,
    requirement_id TEXT NOT NULL,
    asset_category TEXT NOT NULL,
    file_path TEXT NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    format TEXT NOT NULL DEFAULT 'png',
    generation_source TEXT NOT NULL,  -- 'AI_GENERATED', 'USER_PROVIDED'
    generation_prompt TEXT,
    brand_context TEXT,               -- JSON of branding used
    created_utc TEXT NOT NULL,
    hash TEXT NOT NULL
);
```

### Snapshot Storage Optimization

Snapshots must use Logical Graph Deltas + GZip File Snapshots to prevent disk explosion on large projects.

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

        // 2. Parse to syntax tree
        var filePath = patch.TargetFile;
        var sourceText = await File.ReadAllTextAsync(filePath);
        var tree = CSharpSyntaxTree.ParseText(sourceText);
        var root = await tree.GetRootAsync();

        // 3. Apply transformation based on operation type
        var newRoot = patch.OperationType switch
        {
            PatchOperationType.ADD_CLASS => ApplyAddClass(root, (AddClassPayload)patch.Payload),
            PatchOperationType.ADD_METHOD => ApplyAddMethod(root, (AddMethodPayload)patch.Payload),
            _ => throw new NotSupportedException()
        };

        // 4. Validate syntax & format
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
                await IndexBindingAsync(xamlPath, binding.Path, "XML");
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

## 9. Mutation Safety Guards

### Patch Delta Ceiling

To prevent catastrophic regeneration, the `MutationGuard` enforces a limit on the scale of transformation allowed per task.

```csharp
public class MutationGuard
{
    private readonly ICodeIndexer _indexer;

    public async Task<bool> IsSafePatchAsync(string filePath, SyntaxNode newRoot, AgentExecutionContext context)
    {
        var oldRoot = await _indexer.GetSyntaxRootAsync(filePath);
        var diff = ComputeAstDiff(oldRoot, newRoot);

        // Ceiling Enforcement
        if (diff.NodesModified > context.MaxNodesModifiedPerTask)
            throw new MutationLimitExceededException($"Mutation too large: {diff.NodesModified} nodes");

        if (diff.FilesTouched > context.MaxFilesTouchedPerTask)
            throw new MutationLimitExceededException($"Too many files: {diff.FilesTouched} files");

        return true;
    }
}
```

---

## 10. Concurrency & Guard Failure Policy

### 10.1 Concurrency & Execution Ordering Guarantees

**Principle**: Single-Writer, Multi-Reader.

**Thread Roles**
- **Indexing Writer**: 1 Thread (Exclusive)
- **Patch Writer**: 1 Thread (Exclusive)
- **Build Runner**: 1 Thread (Exclusive)
- **Readers (UI/AI)**: Concurrent allowed

**Locking Strategy**
1. **Workspace Lock**: Mutex `Global\Workspace_{ProjectId}` ensures only one ExecutionSession active per project.
2. **Graph Write Lock**: SQLite `BEGIN IMMEDIATE TRANSACTION` blocks other writers, allows readers (WAL mode).
3. **File Locking**: Patch Engine locks target file during read-modify-write cycle.

**Execution Ordering Rule (Strict)**
`PATCH → INDEX → BUILD → COMMIT`

### 10.2 Guard Failure Escalation Policy

The system uses an Infinite Silent Retry model. If a mutation repeatedly fails the safety guard:

1. **Attempt 1-3 (Soft Rejection)** — Return tailored error (e.g., "Symbol Foo not found") to the Agent.
2. **Attempt 4-9 (Hard Rejection)** — Return "Breaking Change Detected" with impact path. Agent attempts architectural pivot.
3. **Attempt 10+ (Barrier Failure / System Reset)** — **SYSTEM RESET**. The kernel triggers an automatic rollback to the pre-mutation snapshot, clears the AI context (forced amnesia), and forces the Architect agent to generate an entirely different file strategy. The user only ever sees "Optimizing build..."

---

## 11. Impact Analysis Engine

Determines affected symbols before a patch is committed.

```csharp
public class ImpactAnalyzer
{
    public async Task<ImpactAnalysis> AnalyzeChangeAsync(string symbolName, ChangeType changeType)
    {
        var analysis = new ImpactAnalysis();
        analysis.AffectedSymbols = await GetAffectedSymbolsAsync(symbolName);

        // Block unsafe mutation
        if (analysis.AffectedSymbols.Count > 50)
        {
            analysis.IsSafe = false;
            analysis.Reason = "Change affects too many symbols. Manual review required.";
        }
        return analysis;
    }
}
```


---

## 12. AI Retrieval Pipeline

### Context Assembly (Prioritized Order)

1. **System Rules** — WinUI constraints
2. **Project Summary** — High-level architecture
3. **Target Symbol Definition** — Full code of target
4. **Direct Dependencies** — Interfaces, services used
5. **XAML Bindings** — Corresponding XAML file

> **PRINCIPLE**: Context is assembled based on relevance, not arbitrary token limits. The AI model manages its own context window constraints. All relevant symbols and files are included to ensure complete understanding.


---

## 13. Database Access Layer

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

    public DapperRepository(IDbConnection connection) { _connection = connection; }

    public async Task<T> GetByIdAsync(object id)
    {
        var tableName = typeof(T).Name + "s";
        return await _connection.QuerySingleOrDefaultAsync<T>(
            $"SELECT * FROM {tableName} WHERE Id = @Id", new { Id = id });
    }
}
```


---

## 14. Performance Optimizations

### Compilation Model Reuse

- **Don't** create new `CSharpCompilation` for every patch
- **Do** replace only the changed `SyntaxTree` in existing `Compilation`

### SQLite Optimization

- **WAL Mode** — Write-Ahead Logging for concurrency
- **Weekly Vacuum** — Auto-maintenance task
- **Indexes** — Composite indexes on frequently queried columns

```sql
CREATE INDEX idx_edges_composite ON symbol_edges(from_symbol_id, edge_type, snapshot_id);
```


---

## 15. Graph Integrity Verifier

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


---

## 16. Service Contracts

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

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 8-layer overview, deployment model
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine, build system, retry logic
- [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — AI Construction Engine vs Runtime Safety Kernel
- [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — **AI capabilities via user-configured providers**
- [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md) — Complete TypeScript implementation
- [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) — Sandbox, MSBuild, filesystem isolation
- [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) — **NEW: generated_assets table for AI-generated assets**

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Added Generated Assets Table cross-reference section |
| 2026-02-23 | Added PLATFORM_REQUIREMENTS_ENGINE.md to References |