# Indexing Architecture Specification

**Purpose**: Define two distinct indexing approaches and recommend hybrid architecture  
**Context**: Lovable-level (lightweight, web) vs Enterprise-level (deep, deterministic, Windows-native)

---

## Core Philosophy

> **Lovable likely uses**: Shallow + summary + retrieval + retry loop
> 
> **You are building**: Deep semantic + deterministic + local execution

**Different scale. Different guarantees.**

---

## PART 1: Lovable-Level Indexing System (Full-Weight Production)

### Design Goals

Optimized for:
- Fast iteration
- Controlled stack (React, Next.js, etc.)
- Web-scale projects
- Simplicity + speed
- Moderate size codebases (< 100K LOC)

**Not meant for**: 500K LOC enterprise systems

**Philosophy**:
- Lightweight
- Retrieval-friendly
- Schema-aware
- Fast to recompute
- AI-optimized
- Not overly rigid

---

### Architecture Overview

```
File Scanner
   ↓
Syntax Extractor (Lightweight AST)
   ↓
Symbol Catalog
   ↓
Dependency Mapper
   ↓
Semantic Project Summary Builder
   ↓
Vector + Structured Hybrid Index
```

---

### 1. File-Level Index

**Store**:
```sql
CREATE TABLE files (
    id TEXT PRIMARY KEY,
    path TEXT NOT NULL,
    type TEXT NOT NULL, -- component, api, model, config
    last_modified DATETIME,
    hash TEXT
);
```

**Purpose**: Fast lookups only. No deep semantic graph.

**Implementation**:
```csharp
public class FileLevelIndex
{
    public async Task IndexFileAsync(string filePath)
    {
        var fileInfo = new FileInfo(filePath);
        var hash = ComputeFileHash(filePath);
        
        await _database.ExecuteAsync(@"
            INSERT OR REPLACE INTO files (id, path, type, last_modified, hash)
            VALUES (@id, @path, @type, @lastModified, @hash)",
            new
            {
                id = Guid.NewGuid().ToString(),
                path = filePath,
                type = DetermineFileType(filePath),
                lastModified = fileInfo.LastWriteTimeUtc,
                hash
            });
    }
}
```

---

### 2. Symbol-Level Index (Shallow)

**Extract**:
- Classes
- Functions
- Components
- API routes
- Database models

**Store**:
```sql
CREATE TABLE symbols (
    id TEXT PRIMARY KEY,
    file_id TEXT NOT NULL,
    name TEXT NOT NULL,
    kind TEXT NOT NULL, -- class, function, component, route, model
    exported BOOLEAN,
    FOREIGN KEY (file_id) REFERENCES files(id)
);
```

**No full AST tree storage. Only signature metadata.**

**Implementation**:
```csharp
public class SymbolExtractor
{
    public async Task<List<Symbol>> ExtractSymbolsAsync(string filePath)
    {
        var code = await File.ReadAllTextAsync(filePath);
        var symbols = new List<Symbol>();
        
        // Lightweight parsing (regex or simple AST)
        var classMatches = Regex.Matches(code, @"class\s+(\w+)");
        foreach (Match match in classMatches)
        {
            symbols.Add(new Symbol
            {
                Name = match.Groups[1].Value,
                Kind = "class",
                Exported = code.Contains($"export class {match.Groups[1].Value}")
            });
        }
        
        // Similar for functions, components, etc.
        
        return symbols;
    }
}
```

---

### 3. Dependency Mapping (Shallow)

**Track**:
- Imports
- Exports
- Route usage
- DB usage

**Store**:
```sql
CREATE TABLE dependencies (
    id TEXT PRIMARY KEY,
    from_symbol_id TEXT NOT NULL,
    to_symbol_id TEXT NOT NULL,
    relation_type TEXT NOT NULL, -- import, export, route, db
    FOREIGN KEY (from_symbol_id) REFERENCES symbols(id),
    FOREIGN KEY (to_symbol_id) REFERENCES symbols(id)
);
```

**Graph is flat and shallow.**

---

### 4. Project Summary Builder (Critical)

**Build compressed summary**:
```sql
CREATE TABLE project_summary (
    id TEXT PRIMARY KEY,
    framework TEXT, -- React, Next.js, Vue
    auth_type TEXT, -- Supabase, Auth0, Firebase
    database_type TEXT, -- PostgreSQL, MongoDB, Supabase
    entities TEXT, -- JSON array
    routes TEXT, -- JSON array
    api_endpoints TEXT, -- JSON array
    ui_pages TEXT -- JSON array
);
```

**This is what AI sees first.**

**Implementation**:
```csharp
public class ProjectSummaryBuilder
{
    public async Task<ProjectSummary> BuildSummaryAsync(string projectPath)
    {
        var summary = new ProjectSummary
        {
            Framework = DetectFramework(projectPath),
            AuthType = DetectAuthType(projectPath),
            DatabaseType = DetectDatabaseType(projectPath),
            Entities = await ExtractEntitiesAsync(projectPath),
            Routes = await ExtractRoutesAsync(projectPath),
            ApiEndpoints = await ExtractApiEndpointsAsync(projectPath),
            UiPages = await ExtractUiPagesAsync(projectPath)
        };
        
        await _database.SaveProjectSummaryAsync(summary);
        
        return summary;
    }
}
```

**Example Summary**:
```json
{
  "framework": "React + Supabase",
  "auth_type": "Email/password via Supabase",
  "database_type": "PostgreSQL (Supabase)",
  "entities": [
    { "name": "Users", "fields": ["id", "email", "profile"] },
    { "name": "Projects", "fields": ["id", "name", "owner_id"] },
    { "name": "Tasks", "fields": ["id", "title", "status", "project_id"] }
  ],
  "routes": [
    { "path": "/dashboard", "component": "Dashboard" },
    { "path": "/projects", "component": "ProjectList" },
    { "path": "/tasks", "component": "TaskBoard" }
  ],
  "api_endpoints": [
    { "path": "/api/projects", "method": "GET" },
    { "path": "/api/tasks", "method": "POST" }
  ],
  "ui_pages": ["Dashboard", "ProjectList", "TaskBoard"]
}
```

---

### 5. Hybrid Retrieval Model

**When AI request occurs**:

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

---

### 6. Vector Layer (Optional but Powerful)

**Store embeddings for**:
- Files
- Symbols
- Documentation strings

**Used for semantic retrieval only. Structured graph remains primary anchor.**

**Implementation**:
```csharp
public class VectorIndex
{
    private readonly IEmbeddingService _embeddingService;
    
    public async Task IndexFileEmbeddingAsync(string filePath)
    {
        var content = await File.ReadAllTextAsync(filePath);
        var embedding = await _embeddingService.GenerateEmbeddingAsync(content);
        
        await _database.ExecuteAsync(@"
            INSERT INTO file_embeddings (file_id, embedding)
            VALUES (@fileId, @embedding)",
            new { fileId = GetFileId(filePath), embedding });
    }
    
    public async Task<List<string>> SemanticSearchAsync(string query, int topK = 5)
    {
        var queryEmbedding = await _embeddingService.GenerateEmbeddingAsync(query);
        
        // Cosine similarity search
        var results = await _database.QueryAsync<string>(@"
            SELECT file_id
            FROM file_embeddings
            ORDER BY cosine_similarity(embedding, @queryEmbedding) DESC
            LIMIT @topK",
            new { queryEmbedding, topK });
        
        return results.ToList();
    }
}
```

---

### Characteristics

| Feature               | Lovable-Level |
| --------------------- | ------------- |
| AST depth             | Shallow       |
| Index speed           | Very fast     |
| Re-index strategy     | Incremental   |
| Storage weight        | Low           |
| AI optimization       | High          |
| Determinism           | Moderate      |
| Large-scale readiness | Medium        |

---

### When This Model Works Best

- ✅ Controlled stack (React, Next.js, Vue)
- ✅ Predictable architecture
- ✅ UI + API apps
- ✅ < 100K LOC

**This is realistic for Lovable-style web systems.**

---

## PART 2: Deep Enterprise-Level Indexing System

### Design Goals

Built for:
- Windows-native complex apps
- Multi-module enterprise systems
- 200K+ LOC
- Deterministic refactoring
- Safety-critical builds

**This is much heavier.**

**Philosophy**:
- Full AST representation
- Cross-file resolution
- Deterministic impact analysis
- Safe mutation guarantee
- Refactor-aware
- Version-aware
- Incremental but strict

---

### Architecture Overview

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

---

### 1. Full Syntax Tree Storage

**Store**:
- Full AST for each file
- Syntax node identifiers
- Node spans
- Type resolution info

**Not just names — actual tree.**

**Implementation**:
```csharp
public class FullSyntaxTreeIndex
{
    private ConcurrentDictionary<string, SyntaxTree> _syntaxTrees = new();
    
    public async Task IndexFileAsync(string filePath)
    {
        var code = await File.ReadAllTextAsync(filePath);
        var tree = CSharpSyntaxTree.ParseText(code, path: filePath);
        
        _syntaxTrees[filePath] = tree;
        
        // Store tree metadata
        var root = await tree.GetRootAsync();
        await _database.ExecuteAsync(@"
            INSERT OR REPLACE INTO syntax_trees (file_path, root_kind, span_start, span_end)
            VALUES (@filePath, @rootKind, @spanStart, @spanEnd)",
            new
            {
                filePath,
                rootKind = root.Kind().ToString(),
                spanStart = root.Span.Start,
                spanEnd = root.Span.End
            });
        
        // Store all syntax nodes
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

### 2. Compilation Model Graph

**Use Roslyn to build**:
- Full semantic model
- Type binding resolution
- Interface implementation graph
- Inheritance tree
- Extension method resolution
- Partial class merging

**This allows**:
- True refactor safety
- Symbol relocation
- Rename safety

**Implementation**:
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
        
        foreach (var node in root.DescendantNodes())
        {
            var symbolInfo = model.GetSymbolInfo(node);
            if (symbolInfo.Symbol != null)
            {
                await _database.ExecuteAsync(@"
                    INSERT INTO semantic_symbols (node_id, symbol_name, symbol_kind, type_name)
                    VALUES (@nodeId, @symbolName, @symbolKind, @typeName)",
                    new
                    {
                        nodeId = GetNodeId(node),
                        symbolName = symbolInfo.Symbol.Name,
                        symbolKind = symbolInfo.Symbol.Kind.ToString(),
                        typeName = symbolInfo.Symbol.ContainingType?.Name
                    });
            }
        }
    }
}
```

---

### 3. Bidirectional Dependency Graph

**Store**:
```sql
CREATE TABLE symbol_nodes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    file_path TEXT NOT NULL,
    namespace TEXT
);

CREATE TABLE symbol_edges (
    id TEXT PRIMARY KEY,
    from_symbol_id TEXT NOT NULL,
    to_symbol_id TEXT NOT NULL,
    edge_type TEXT NOT NULL, -- inheritance, call, inject, bind, reference, override, generic_constraint
    FOREIGN KEY (from_symbol_id) REFERENCES symbol_nodes(id),
    FOREIGN KEY (to_symbol_id) REFERENCES symbol_nodes(id)
);

CREATE TABLE file_nodes (
    id TEXT PRIMARY KEY,
    path TEXT NOT NULL
);

CREATE TABLE file_edges (
    id TEXT PRIMARY KEY,
    from_file_id TEXT NOT NULL,
    to_file_id TEXT NOT NULL,
    edge_type TEXT NOT NULL, -- import, reference
    FOREIGN KEY (from_file_id) REFERENCES file_nodes(id),
    FOREIGN KEY (to_file_id) REFERENCES file_nodes(id)
);

CREATE TABLE xaml_nodes (
    id TEXT PRIMARY KEY,
    file_path TEXT NOT NULL,
    element_type TEXT NOT NULL
);

CREATE TABLE binding_edges (
    id TEXT PRIMARY KEY,
    xaml_node_id TEXT NOT NULL,
    viewmodel_symbol_id TEXT NOT NULL,
    binding_type TEXT NOT NULL, -- property, command, event
    FOREIGN KEY (xaml_node_id) REFERENCES xaml_nodes(id),
    FOREIGN KEY (viewmodel_symbol_id) REFERENCES symbol_nodes(id)
);
```

**Edges include**:
- Inheritance
- Call
- Inject
- Bind
- Reference
- Override
- Generic constraint

**Graph must be directional and reversible.**

---

### 4. XAML ↔ ViewModel Graph

**Special layer for WinUI 3**:
- Bindings (`{x:Bind ViewModel.Property}`)
- Commands (`{x:Bind ViewModel.SaveCommand}`)
- Dependency properties
- Resource dictionary references

**Without this, WinUI refactors break.**

**Implementation**:
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
            // Find corresponding ViewModel symbol
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
    }
}
```

---

### 5. Impact Analysis Engine

**Before patch**:

```csharp
public class ImpactAnalyzer
{
    public async Task<ImpactAnalysis> AnalyzeChangeAsync(string symbolName, ChangeType changeType)
    {
        var analysis = new ImpactAnalysis();
        
        // 1. Determine affected symbols
        var affectedSymbols = await GetAffectedSymbolsAsync(symbolName);
        analysis.AffectedSymbols = affectedSymbols;
        
        // 2. Determine dependent files
        var dependentFiles = await GetDependentFilesAsync(symbolName);
        analysis.DependentFiles = dependentFiles;
        
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
        // Query bidirectional graph
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

**This is enterprise-grade safety.**

---

### 6. Versioned Knowledge Graph

**Store per snapshot**:
- Graph delta
- Symbol addition/removal
- Dependency change

**Allows**:
- Deep diff
- Evolution analysis
- Rollback validation

**Schema**:
```sql
CREATE TABLE graph_snapshots (
    id TEXT PRIMARY KEY,
    snapshot_id TEXT NOT NULL,
    timestamp DATETIME,
    FOREIGN KEY (snapshot_id) REFERENCES snapshots(id)
);

CREATE TABLE graph_deltas (
    id TEXT PRIMARY KEY,
    graph_snapshot_id TEXT NOT NULL,
    delta_type TEXT NOT NULL, -- symbol_added, symbol_removed, edge_added, edge_removed
    symbol_id TEXT,
    edge_id TEXT,
    FOREIGN KEY (graph_snapshot_id) REFERENCES graph_snapshots(id)
);
```

---

### 7. Deterministic Retrieval Layer

**AI context built from**:

```csharp
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
    var trimmedContext = await _tokenManager.TrimContextAsync(context.ToString(), maxTokens: 8000);
    
    return trimmedContext;
}
```

**No guesswork.**

---

### Characteristics

| Feature               | Enterprise-Level |
| --------------------- | ---------------- |
| AST depth             | Full             |
| Semantic resolution   | Full             |
| Refactor safety       | High             |
| Index speed           | Slower           |
| Memory footprint      | Higher           |
| Determinism           | Very High        |
| Large-scale readiness | Excellent        |

---

## Key Differences

| Category          | Lovable-Level    | Enterprise-Level  |
| ----------------- | ---------------- | ----------------- |
| AST               | Shallow metadata | Full tree storage |
| Graph depth       | Flat             | Multi-layer       |
| Binding awareness | Minimal          | Full (XAML ↔ VM)  |
| Impact analysis   | Basic            | Deterministic     |
| Refactor safety   | Medium           | Strong            |
| Token control     | Summary-based    | Graph-based       |
| Performance       | Fast             | Heavy             |
| Memory usage      | Low              | High              |
| Scalability       | < 100K LOC       | 200K+ LOC         |

---

## Recommended Hybrid Architecture

For your **local-only, WinUI 3, deterministic, full-stack Windows builder**, use:

> **Enterprise-Level Core + Lovable-Level Retrieval Optimization**

### Hybrid Model Components:

1. ✅ **Full Roslyn semantic graph** (Enterprise)
2. ✅ **XAML binding graph** (Enterprise)
3. ✅ **Snapshot-aware indexing** (Enterprise)
4. ✅ **Lightweight project summary** (Lovable)
5. ✅ **Hybrid structured + semantic retrieval** (Lovable)
6. ✅ **Strict mutation guard** (Enterprise)

### This gives:
- ✅ Safety (deterministic refactoring)
- ✅ Scalability (200K+ LOC)
- ✅ AI efficiency (token optimization)
- ✅ Local execution stability (no cloud dependency)

---

## Implementation Strategy

### Phase 1: Core Enterprise Index
```csharp
// Full Roslyn compilation model
var compilation = await _compilationBuilder.BuildCompilationAsync(projectPath);

// Bidirectional dependency graph
await _dependencyGraphBuilder.BuildGraphAsync(compilation);

// XAML binding graph
await _xamlIndexer.IndexXamlFilesAsync(projectPath);
```

### Phase 2: Lovable-Style Optimization
```csharp
// Lightweight project summary
var summary = await _summaryBuilder.BuildSummaryAsync(projectPath);

// Hybrid retrieval
var context = await _retriever.PrepareHybridContextAsync(prompt, projectId);
```

### Phase 3: Safety Layer
```csharp
// Impact analysis before mutation
var impact = await _impactAnalyzer.AnalyzeChangeAsync(symbolName, changeType);

if (!impact.IsSafe)
{
    throw new UnsafeMutationException(impact.Reason);
}
```

---

## Final Insight

**Lovable likely uses**:
- Shallow indexing
- Summary-based retrieval
- Retry loop for safety

**You are building**:
- Deep semantic indexing
- Deterministic impact analysis
- Local execution guarantees

**Different scale. Different guarantees.**

---

## References

- [BACKGROUND_SYSTEMS_SPECIFICATION.md](./BACKGROUND_SYSTEMS_SPECIFICATION.md) - Hidden systems
- [EXECUTION_LIFECYCLE_SPECIFICATION.md](./EXECUTION_LIFECYCLE_SPECIFICATION.md) - Execution flow
- [LOVABLE_COMPARISON.md](./LOVABLE_COMPARISON.md) - Lovable vs Enterprise comparison
