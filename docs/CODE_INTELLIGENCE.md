# CODE INTELLIGENCE

> **The Knowledge Layer: Roslyn Integration, Semantic Indexing, Database Schema, Patch Engine & Mutation Safety**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> **Related Specification Documents:**
>
> - [STRUCTURED_SPEC_FORMAT.md](./STRUCTURED_SPEC_FORMAT.md) — The Application Spec that Code Intelligence reads to understand the project entity model
> - [PROJECT_ARCHETYPE_RESOLUTION.md](./PROJECT_ARCHETYPE_RESOLUTION.md) — Framework selection affecting code analysis
> - [TOOLCHAIN_MANIFEST.md](./TOOLCHAIN_MANIFEST.md) — Bundled Roslyn/MSVC versions used for analysis
> - [TOOLCHAIN_ISOLATION.md](./TOOLCHAIN_ISOLATION.md) — Isolation contract for any toolchain analysis processes
>
> _The Code Intelligence layer provides knowledge to the AI Construction Engine. The Runtime Safety Kernel enforces mutation boundaries._

---

## Table of Contents

1. [Core Principle: No Raw File Writes](#1-core-principle-no-raw-file-writes)
2. [Indexing Architecture](#2-indexing-architecture)
2.1. [Lightweight Indexing](#21-lightweight-indexing)
3. [Roslyn Compilation Model](#3-roslyn-compilation-model)
4. [Code Indexer & Symbol Graph](#4-code-indexer--symbol-graph)
4.1. [Native Code Intelligence (C++)](#41-native-code-intelligence-c)
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

## 1. Core Principle: No Unstructured Code Manipulation

> **INVARIANT**: Sync AI must NEVER perform unstructured string manipulation of source code. All code modifications MUST use Roslyn AST transformations or XML parsing.

### What This Means

The invariant **"No Raw File Writes"** specifically prohibits:

- Direct string replacement (`string.Replace()`)
- Regex-based code modification (`Regex.Replace()` on C# source)
- Direct file overwrite with LLM-generated code

The invariant **PERMITS**:

- Roslyn AST transformation followed by `Formatter.Format()` → `File.WriteAllTextAsync()`
- XML parsing of XAML followed by `XDocument.Save()` or `File.WriteAllTextAsync()`

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

// ❌ NEVER DO THIS - Direct file overwrite with LLM output
File.WriteAllText("MyClass.cs", llmGeneratedCode);
```

### ✅ REQUIRED Approach (Roslyn AST Transformation)

```csharp
// ✅ ALWAYS DO THIS - Roslyn AST transformation
var tree = CSharpSyntaxTree.ParseText(File.ReadAllText("MyClass.cs"));
var root = await tree.GetRootAsync();

// Apply transformation
var newRoot = root.ReplaceNode(oldNode, newNode);

// Format and write - THIS IS PERMITTED
var formatted = Formatter.Format(newRoot, workspace);
File.WriteAllTextAsync("MyClass.cs", formatted.ToFullString());
```

> **Why This Is Permitted**: The `File.WriteAllTextAsync()` call writes the output of `Formatter.Format()`, which produces deterministic, syntax-verified C# code. This is NOT unstructured string manipulation — it is the final step of a structured AST transformation pipeline.

### Code Formatting and Cleanup (Implicit in Roslyn Formatter)

The `Formatter.Format()` method automatically includes:

1. **Indentation & Spacing**: Consistent formatting based on `.editorconfig` rules
2. **Unused Using Removal**: Automatically removes `using` directives that are not referenced in the code
3. **Namespace Organization**: Sorts and groups `using` statements according to style rules
4. **Whitespace Normalization**: Ensures consistent blank lines, spacing around operators

```csharp
// Example: Before Formatter.Format()
using System;
using System.Collections.Generic;  // Unused
using Windows.UI.Xaml;            // Unused

public class MyClass { }

// After Formatter.Format() - unused usings removed
using System;

public class MyClass { }
```

**Reference**: Roslyn's `Formatter.Format()` is part of `Microsoft.CodeAnalysis.Formatting` namespace and includes `RemoveUnnecessaryImports` as a standard cleanup operation.

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

## 4.1 Native Code Intelligence (C++)

> **NOTE**: Native code intelligence applies to Win32, WinRT, and Hybrid projects. For pure .NET projects (WinUI3, WPF, WinForms), only Roslyn-based analysis is required.

### C++ Symbol Extraction

For native C++ projects, the system uses a simplified symbol extractor based on regex patterns (not full AST):

```csharp
public class NativeSymbolExtractor
{
    // C++ class detection
    private static readonly Regex ClassRegex = new(@"class\s+(\w+)\s*[:{]", RegexOptions.Compiled);
    
    // C++ method detection  
    private static readonly Regex MethodRegex = new(@"(\w+)\s+(\w+)\s*\([^)]*\)\s*[{;]", RegexOptions.Compiled);
    
    // Header include detection
    private static readonly Regex IncludeRegex = new(@"#include\s+[<""]([^>""]+)[>""]", RegexOptions.Compiled);
    
    // Win32 API detection
    private static readonly Regex WinApiRegex = new(@"\b(CreateWindow|DestroyWindow|MessageBox)\b", RegexOptions.Compiled);

    public async Task<NativeSymbolIndex> ExtractSymbolsAsync(string sourcePath)
    {
        var symbols = new NativeSymbolIndex();
        
        // Extract headers
        var includes = IncludeRegex.Matches(await File.ReadAllTextAsync(sourcePath));
        foreach (Match match in includes)
            symbols.Includes.Add(match.Groups[1].Value);
            
        // Extract classes
        var classes = ClassRegex.Matches(await File.ReadAllTextAsync(sourcePath));
        foreach (Match match in classes)
            symbols.Classes.Add(match.Groups[1].Value);
            
        // Extract methods
        var methods = MethodRegex.Matches(await File.ReadAllTextAsync(sourcePath));
        foreach (Match match in methods)
            symbols.Methods.Add(new NativeMethod 
            { 
                ReturnType = match.Groups[1].Value,
                Name = match.Groups[2].Value 
            });
            
        // Detect Win32 APIs used
        var winapis = WinApiRegex.Matches(await File.ReadAllTextAsync(sourcePath));
        foreach (Match match in winapis)
            symbols.Win32Apis.Add(match.Value);
            
        return symbols;
    }
}

public class NativeSymbolIndex
{
    public List<string> Includes { get; set; } = new();
    public List<string> Classes { get; set; } = new();
    public List<NativeMethod> Methods { get; set; } = new();
    public List<string> Win32Apis { get; set; } = new();
}
```

### Resource File (.rc) Parsing

Native Windows applications use resource files:

```csharp
public class ResourceFileParser
{
    // Icon resource
    private static readonly Regex IconRegex = new(@"ICON\s+""([^""]+)""", RegexOptions.Compiled);
    
    // Bitmap resource
    private static readonly Regex BitmapRegex = new(@"BITMAP\s+""([^""]+)""", RegexOptions.Compiled);
    
    // String table
    private static readonly Regex StringTableRegex = new(@"STRINGTABLE\s+BEGIN(.+?)END", RegexOptions.Compiled | RegexOptions.Singleline);

    public async Task<ResourceIndex> ParseResourceFileAsync(string rcPath)
    {
        var content = await File.ReadAllTextAsync(rcPath);
        return new ResourceIndex
        {
            Icons = IconRegex.Matches(content).Select(m => m.Groups[1].Value).ToList(),
            Bitmaps = BitmapRegex.Matches(content).Select(m => m.Groups[1].Value).ToList(),
            StringTables = ParseStringTables(content)
        };
    }
}
```

### Native Build Integration

When the target platform is Win32, WinRT, or Hybrid:

1. **Symbol Extraction**: Use `NativeSymbolExtractor` for .cpp/.h files
2. **Resource Parsing**: Use `ResourceFileParser` for .rc files
3. **Dependency Graph**: Build header dependency graph from includes
4. **Linker Input**: Track .obj files for linker invocation

---

### Native Mutation Safety Invariant

> **CRITICAL**: For C++ code, all source transformations MUST operate on Clang AST (libclang).
> 
> - Regex or string replacement on .cpp/.h files is **FORBIDDEN**.
> - Patch engine must support structured C++ AST transformations.
> - Direct file writes with LLM-generated C++ code are **PROHIBITED**.
>
> This ensures C++ mutation safety parity with Roslyn-enforced C# mutations.

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

-- Learned Repair Patterns (Cross-Session Learning)
CREATE TABLE learned_repairs (
    id INTEGER PRIMARY KEY,
    error_hash TEXT NOT NULL,       -- SHA256 of normalized error context
    error_tier TEXT NOT NULL,       -- T1 (syntax), T2 (semantic), T3 (architecture)
    error_code TEXT,                -- Compiler error code (e.g., CS0103)
    error_message_normalized TEXT,  -- Stripped of line numbers, paths
    repair_action TEXT NOT NULL,    -- JSON patch or fix strategy
    repair_type TEXT NOT NULL,      -- 'AST_PATCH', 'REGISTRATION_FIX', 'IMPORT_ADDITION', etc.
    success_count INTEGER DEFAULT 1,
    failure_count INTEGER DEFAULT 0,
    first_seen_utc TEXT NOT NULL,
    last_success_utc TEXT NOT NULL,
    project_id TEXT,                -- Optional: for attribution
    toolchain_version TEXT,         -- Version when fix was learned
    framework_family TEXT,          -- WinUI3/WPF/WinForms/Win32/etc.
    confidence_score REAL DEFAULT 0.5  -- success_count / (success_count + failure_count)
);

CREATE INDEX idx_learned_repairs_hash ON learned_repairs(error_hash);
CREATE INDEX idx_learned_repairs_confidence ON learned_repairs(confidence_score DESC);
CREATE INDEX idx_learned_repairs_tier ON learned_repairs(error_tier);
```
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

---

## 4.1 Native Code Intelligence (C++)

> **CRITICAL**: For C++ code, all source transformations MUST operate on Clang AST (libclang).
> 
> - Regex or string replacement on .cpp/.h files is **FORBIDDEN**.
> - Patch engine must support structured C++ AST transformations.
> - Direct file writes with LLM-generated C++ code are **PROHIBITED**.
>
> This ensures C++ mutation safety parity with Roslyn-enforced C# mutations.

### Clang LibTooling Integration

```csharp
public class ClangAstService
{
    private readonly string _clangPath;
    
    public async Task<ClangTranslationUnit> ParseAsync(string cppFilePath, CancellationToken ct)
    {
        // Use bundled Clang from toolchain
        var args = new[]
        {
            "-fsyntax-only",
            "-Xclang", "-ast-dump",
            "-std:c++20",
            cppFilePath
        };
        
        return await ExecuteClangToolAsync(_clangPath, args, ct);
    }
    
    public async Task<string> TransformAsync(ClangTranslationUnit unit, Func<ClangNode, ClangNode> transformer)
    {
        // Apply AST transformation
        var transformed = transformer(unit.Root);
        
        // Re-emit with clang-format (deterministic config)
        return await EmitFormattedAsync(transformed);
    }
}
```

### C++ Mutation Contract

All C++ modifications MUST:
1. Parse using bundled Clang (version pinned in [TOOLCHAIN_MANIFEST.md](./TOOLCHAIN_MANIFEST.md))
2. Apply transformations via LibTooling AST operations
3. Re-emit formatted source via clang-format (deterministic config)
4. Prohibit raw text rewrite or regex-based replacement

See [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) §3.5 for native compilation contract.

### Snapshot Storage (Git-Based)

> **NOTE**: Snapshots are managed via Git. See §7 below for the complete Git-based snapshot mechanism.

### 2.9 Version Control Integration

The system uses a hidden Git repository for snapshot management:

- **Location**: `{ProjectRoot}/.sync_git/` (hidden from user)
- **Purpose**: Lightweight versioning, time travel, rollback
- **User Access**: Via Timeline UI in [USER_WORKFLOWS.md](./USER_WORKFLOWS.md) §4

See §7 for complete Git implementation details.

Snapshots use the project's `.git/` repository for version history:

- **SnapshotId** values are Git commit hashes
- **Rollback** uses `git checkout` to restore previous states
- **Pruning** uses `git gc` and branch management to control repository size
- **No custom compression** needed - Git handles delta compression natively

The `snapshots` table in SQLite maps logical snapshot IDs to Git commit SHAs for fast lookup:

```sql
-- Snapshots are Git commits; this table provides fast lookup
INSERT INTO snapshots (id, parent_snapshot_id, created_utc, reason)
VALUES (1, NULL, '2026-02-23T00:00:00Z', 'Pre-Generation');
-- The actual snapshot content is in Git's object store
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
    DELETE_FILE,              // Remove file from project
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

## 7. Git-Based Snapshot System

The system uses a hidden Git repository for deterministic snapshot management and time travel.

### 7.1 Snapshot Storage Location

```
{ProjectRoot}/
├── .sync_git/              # Hidden Git repository (managed by system)
│   ├── objects/            # Git objects
│   ├── refs/               # Branch/tag references
│   └── HEAD                # Current snapshot reference
├── src/                    # User-visible source code
├── assets/                 # Generated assets
└── ProjectMetadata.db      # Maps snapshots to user prompts
```

**Key Invariant**: The `.sync_git/` folder is **hidden from users** to prevent manual interference.

### 7.2 Snapshot Creation Triggers

| Trigger | Snapshot Message Format | Retention |
|---------|------------------------|-----------|
| **Pre-Generation** | `"Pre-generation snapshot: {timestamp}"` | Keep last 5 |
| **Post-Patch** | `"Applied patch: {patch_id}"` | Keep last 20 |
| **User Prompt** | `"User request: {prompt_preview}"` | Keep all (timeline) |
| **Build Success** | `"Build succeeded: {version}"` | Keep last 10 |
| **System Reset** | `"SYSTEM_RESET at cycle {cycle_number}"` | Keep all (audit trail) |

### 7.3 Time Travel UI Integration

Per [USER_WORKFLOWS.md](./USER_WORKFLOWS.md) §4, users interact with snapshots via:

- **Timeline View**: Vertical list of generations and refinements
- **Preview Hover**: Screenshot of app state at that snapshot
- **Restore Button**: Reverts filesystem + database to exact state
- **Safety Net**: Current work stashed before restore

### 7.4 Snapshot Pruning Strategy

To prevent unbounded growth:

```csharp
public class SnapshotManager
{
    private const int MaxSnapshots = 50;
    private const int MaxSizeGB = 5;
    
    public void PruneOldSnapshots()
    {
        // Keep most recent N snapshots
        var snapshots = GetSnapshots().OrderByDescending(s => s.Timestamp).ToList();
        
        if (snapshots.Count > MaxSnapshots)
        {
            foreach (var snapshot in snapshots.Skip(MaxSnapshots))
            {
                ArchiveSnapshot(snapshot); // Move to cold storage
            }
        }
        
        // Size-based pruning if exceeds threshold
        if (GetTotalSize() > MaxSizeGB)
        {
            PruneByAge(); // Remove oldest first
        }
    }
}
```

**User Notification**: When pruning occurs, gentle message: _"Old versions automatically archived to save space."_

### 7.5 Restore Operation

```csharp
public async Task RestoreSnapshotAsync(string snapshotId)
{
    // 1. Stash current work
    await StashCurrentChangesAsync();
    
    // 2. Checkout snapshot
    await gitRepository.CheckoutAsync(snapshotId);
    
    // 3. Restore database state
    await RestoreDatabaseStateAsync(snapshotId);
    
    // 4. Silent rebuild
    await orchestrator.RebuildCurrentProjectAsync();
    
    // 5. Refresh preview
    await RefreshPreviewAsync();
}
```

**User sees**: Simple "Restoring..." spinner, then working app
**User does NOT see**: Git operations, file moves, build process

### 7.6 Snapshot Integrity

- **SHA-256 Hashing**: Every commit verified
- **Atomic Commits**: All-or-nothing snapshot creation
- **Rollback Safety**: Failed rollbacks leave system in stable state

---

## 8. Patch Engine

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

> **INVARIANT**: XML parsing is the AUTHORITATIVE method for XAML binding extraction. Regex is a FALLBACK-ONLY method used when XML parsing fails. Regex results MUST be deduplicated against XML results when both methods succeed.

```csharp
public class XamlBindingIndexer
{
    // Regex fallback for robust parsing when XML is malformed
    private static readonly Regex XBindRegex = new(@"\{x:Bind\s+(?<path>[^,}]+)", RegexOptions.Compiled);
    private static readonly Regex BindingRegex = new(@"\{Binding\s+(?<path>[^,}]+)", RegexOptions.Compiled);

    public async Task IndexXamlFileAsync(string xamlPath)
    {
        var xaml = await File.ReadAllTextAsync(xamlPath);
        var extractedBindings = new Dictionary<string, XamlBindingSource>();

        // 1. Try precise XML parsing FIRST (authoritative)
        try
        {
            var doc = XDocument.Parse(xaml);
            var xmlBindings = doc.Descendants()
                .SelectMany(e => e.Attributes())
                .Where(a => a.Value.Contains("{x:Bind") || a.Value.Contains("{Binding"))
                .Select(a => ExtractBindingPath(a.Value));

            foreach (var binding in xmlBindings)
            {
                // XML results are authoritative - mark as such
                extractedBindings[binding.Path] = new XamlBindingSource
                {
                    Path = binding.Path,
                    Source = "XML",
                    IsAuthoritative = true
                };
            }
        }
        catch (XmlException)
        {
            // XML parsing failed - will rely on regex fallback below
        }

        // 2. Regex fallback - only if XML failed or to fill gaps
        var regexBindings = XBindRegex.Matches(xaml).Concat(BindingRegex.Matches(xaml));
        foreach (Match match in regexBindings)
        {
            var path = match.Groups["path"].Value;

            // Deduplicate: If XML already found this binding, skip regex result
            if (extractedBindings.ContainsKey(path))
                continue;

            // Regex results are NOT authoritative - mark as fallback
            extractedBindings[path] = new XamlBindingSource
            {
                Path = path,
                Source = "Regex",
                IsAuthoritative = false
            };
        }

        // 3. Index all unique bindings
        foreach (var binding in extractedBindings.Values)
        {
            await IndexBindingAsync(xamlPath, binding.Path, binding.Source);
        }
    }

    private class XamlBindingSource
    {
        public string Path { get; set; }
        public string Source { get; set; }  // "XML" or "Regex"
        public bool IsAuthoritative { get; set; }
    }

    /// <summary>
    /// Retrieves binding information for impact analysis.
    /// CRITICAL: Non-authoritative bindings (regex-derived) MUST be re-verified before use.
    /// </summary>
    public async Task<XamlBindingInfo> GetBindingAsync(string xamlPath, string bindingPath)
    {
        var binding = await _dbContext.Bindings
            .FirstOrDefaultAsync(b => b.XamlPath == xamlPath && b.BindingPath == bindingPath);
        
        if (binding == null)
            return null;
        
        // ENFORCEMENT: If binding is not authoritative, re-verify before returning
        if (!binding.IsAuthoritative)
        {
            _logger.LogWarning($"Non-authoritative binding detected for {xamlPath}:{bindingPath}. Re-verifying.");
            
            // Re-parse the XAML file to verify the binding exists
            var verifiedBindings = await ExtractBindingsFromXamlAsync(xamlPath);
            
            if (!verifiedBindings.ContainsKey(bindingPath))
            {
                // Binding no longer exists - remove from index
                _logger.LogWarning($"Removing stale non-authoritative binding: {xamlPath}:{bindingPath}");
                await RemoveBindingAsync(xamlPath, bindingPath);
                return null;
            }
            
            // Update binding to authoritative since we just verified it
            binding.IsAuthoritative = true;
            await _dbContext.SaveChangesAsync();
        }
        
        return binding;
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

#### `AgentExecutionContext` Schema

`AgentExecutionContext` is injected into `BuilderContext` before task execution and carries the per-task safety ceilings enforced by `MutationGuard`. Its C# definition:

```csharp
/// <summary>
/// Ceiling contract injected into BuilderContext before each task.
/// All limits are enforced by MutationGuard before any AST patch is applied.
/// </summary>
public record AgentExecutionContext
{
    /// <summary>Maximum AST nodes that may be modified in a single task. Default: 100.</summary>
    public int MaxNodesModifiedPerTask { get; init; } = 100;

    /// <summary>Maximum distinct files that a single task may touch. Default: 5.</summary>
    public int MaxFilesTouchedPerTask { get; init; } = 5;

    /// <summary>
    /// Maximum symbols (methods, classes, properties) whose call-sites may be affected
    /// by a single patch (impact-analysis ceiling). Default: 50.
    /// </summary>
    public int MaxAffectedSymbols { get; init; } = 50;
}
```

> **Source of truth**: `BuilderContext` exposes `MaxFilesTouchedPerTask` and `MaxNodesModifiedPerTask` as computed properties delegating to `ActiveAgentContext` (see [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) §4). `MaxAffectedSymbols` is enforced during the INDEXING stage impact analysis.

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

The system uses a Bounded Retry model with SYSTEM_RESET at cycle 10. If a mutation repeatedly fails the safety guard:

1. **Attempt 1-3 (Soft Rejection)** — Return tailored error (e.g., "Symbol Foo not found") to the Agent.
2. **Attempt 4-9 (Hard Rejection)** — Return "Breaking Change Detected" with impact path. Agent attempts architectural pivot.
3. **Attempt 10+ (Barrier Failure / System Reset)** — **SYSTEM RESET**. The kernel triggers an automatic rollback to the pre-mutation snapshot, clears the AI context (forced amnesia), and forces the Architect agent to generate an entirely different file strategy. The user only ever sees "Optimizing build..."

---

## 11. Impact Analysis Engine

Determines affected symbols before a patch is committed.

```csharp
public class ImpactAnalyzer
{
    public async Task<ImpactAnalysis> AnalyzeChangeAsync(
        string symbolName,
        ChangeType changeType,
        AgentExecutionContext context)
    {
        var analysis = new ImpactAnalysis();
        analysis.AffectedSymbols = await GetAffectedSymbolsAsync(symbolName);

        // Block unsafe mutation
        // NOTE: Threshold is configurable via AgentExecutionContext.MaxAffectedSymbols (default: 50)
        var maxAffectedSymbols = context?.MaxAffectedSymbols ?? 50;
        if (analysis.AffectedSymbols.Count > maxAffectedSymbols)
        {
            analysis.IsSafe = false;
            analysis.Reason = $"Change affects {analysis.AffectedSymbols.Count} symbols (max: {maxAffectedSymbols}). Manual review required.";
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

public class EfCoreRepository<T> : IRepository<T> where T : class
{
    private readonly AppDbContext _context;

    public EfCoreRepository(AppDbContext context) => _context = context;

    public async Task<T> GetByIdAsync(object id)
    {
        // Use EF Core's FindAsync for primary key lookups
        return await _context.Set<T>().FindAsync(id);
    }

    public async Task<IEnumerable<T>> GetAllAsync()
    {
        // Use AsNoTracking for read-only queries to improve performance
        return await _context.Set<T>().AsNoTracking().ToListAsync();
    }

    public async Task AddAsync(T entity)
    {
        await _context.Set<T>().AddAsync(entity);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(T entity)
    {
        _context.Set<T>().Update(entity);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(object id)
    {
        var entity = await GetByIdAsync(id);
        if (entity != null)
        {
            _context.Set<T>().Remove(entity);
            await _context.SaveChangesAsync();
        }
    }
}
```

**Note**: Dapper is not used in generated applications. All data access in Sync AI-generated applications uses EF Core with SQLite as the database provider, following the patterns defined in [DATA_LAYER_GENERATION.md](./DATA_LAYER_GENERATION.md).

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
2. **Request Safety Snapshot from Kernel** — Call `SnapshotService.CreateSnapshot("GraphIntegrityRepair")` via Kernel RPC
3. Wait for Kernel to confirm snapshot creation (snapshot ID returned)
4. **TRUNCATE** graph tables
5. Perform **Full Re-index** from disk
6. Validate Integrity
7. Resume operation

> **INVARIANT**: The Graph Integrity Verifier MUST NOT create snapshots directly. All snapshot creation MUST route through the Kernel's `SnapshotService` to maintain state machine consistency ([AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) §7).

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

| Date       | Change                                                                                                    |
| ---------- | --------------------------------------------------------------------------------------------------------- |
| 2026-03-03 | **AUTONOMOUS BUILD LOOP COVERAGE IMPROVEMENTS**: Added explicit documentation for Unused Reference Removal via Roslyn Formatter.Format() in §1. Clarified that code formatting, using cleanup, and namespace organization are implicit in Roslyn AST transformation pipeline. Coverage accuracy improved from 90% to 100%. |
| 2026-03-03 | **MEDIUM PRIORITY #6**: Consolidated Git-based snapshot documentation into new §7. Moved from EXECUTION_ENVIRONMENT.md to create single authoritative source. Added snapshot triggers, pruning strategy, restore operations, and integrity guarantees. |
| 2026-02-23 | Added Generated Assets Table cross-reference section |
| 2026-02-23 | Added PLATFORM_REQUIREMENTS_ENGINE.md to References  |
