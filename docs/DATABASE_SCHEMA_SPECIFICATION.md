# Enterprise Semantic Graph - Database Schema & Algorithms

**Purpose**: Define the exact SQLite schema, update algorithms, and retrieval strategies for the deterministic enterprise graph.  
**Context**: Backend for `INDEXING_ARCHITECTURE_SPECIFICATION.md`

---

## 1. Exact SQLite Schema

We design a **multi-layer graph model** normalized and indexed for performance.

### Core Architecture
- **File Layer**: Physical file tracking
- **Syntax Layer**: Roslyn syntax nodes
- **Symbol Layer**: Semantic symbols
- **Edge Layer**: Relationships (calls, inherits, etc.)
- **XAML Layer**: UI bindings
- **Version Layer**: Snapshots and history

---

### Table 1: files

Tracks physical files in the workspace.

```sql
CREATE TABLE files (
    id INTEGER PRIMARY KEY,
    path TEXT NOT NULL UNIQUE,
    hash TEXT NOT NULL,          -- SHA256 for incremental detection
    last_modified_utc TEXT NOT NULL,
    language TEXT NOT NULL,      -- 'cs', 'xaml', 'xml', 'json'
    snapshot_id INTEGER NOT NULL -- Current snapshot ownership
);

CREATE INDEX idx_files_snapshot ON files(snapshot_id);
CREATE INDEX idx_files_path ON files(path);
```

### Table 2: syntax_nodes

Stores structural nodes (Class, Method, Property) from Roslyn AST.

```sql
CREATE TABLE syntax_nodes (
    id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,
    kind TEXT NOT NULL,          -- 'ClassDeclaration', 'MethodDeclaration'
    name TEXT,                   -- Simple name
    span_start INTEGER,
    span_end INTEGER,
    parent_node_id INTEGER,
    FOREIGN KEY(file_id) REFERENCES files(id)
);

CREATE INDEX idx_syntax_file ON syntax_nodes(file_id);
CREATE INDEX idx_syntax_name ON syntax_nodes(name);
```

### Table 3: symbols

Semantic layer (Roslyn resolved symbols).

```sql
CREATE TABLE symbols (
    id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,
    syntax_node_id INTEGER,
    name TEXT NOT NULL,
    fully_qualified_name TEXT NOT NULL, -- 'Namespace.Class.Method'
    kind TEXT NOT NULL,          -- 'NamedType', 'Method', 'Property'
    return_type TEXT,
    accessibility TEXT,          -- 'Public', 'Private', 'Internal'
    is_static INTEGER,           -- Boolean
    is_abstract INTEGER,         -- Boolean
    snapshot_id INTEGER NOT NULL,
    FOREIGN KEY(file_id) REFERENCES files(id)
);

CREATE INDEX idx_symbols_fqn ON symbols(fully_qualified_name);
CREATE INDEX idx_symbols_snapshot ON symbols(snapshot_id);
```

### Table 4: symbol_edges

Directed graph of semantic relationships.

```sql
CREATE TABLE symbol_edges (
    id INTEGER PRIMARY KEY,
    from_symbol_id INTEGER NOT NULL,
    to_symbol_id INTEGER NOT NULL,
    edge_type TEXT NOT NULL,     -- 'CALLS', 'INHERITS', 'IMPLEMENTS', 'REFERENCES', 'INJECTS'
    snapshot_id INTEGER NOT NULL,
    FOREIGN KEY(from_symbol_id) REFERENCES symbols(id),
    FOREIGN KEY(to_symbol_id) REFERENCES symbols(id)
);

CREATE INDEX idx_symbol_edges_from ON symbol_edges(from_symbol_id);
CREATE INDEX idx_symbol_edges_to ON symbol_edges(to_symbol_id);
```

### Table 5: xaml_bindings

Connects UI layer to Semantic layer.

```sql
CREATE TABLE xaml_bindings (
    id INTEGER PRIMARY KEY,
    xaml_file_id INTEGER NOT NULL,
    viewmodel_symbol_id INTEGER NOT NULL,
    binding_property TEXT NOT NULL, -- Property path in XAML
    binding_target TEXT NOT NULL,   -- Target property on UI element
    snapshot_id INTEGER NOT NULL,
    FOREIGN KEY(xaml_file_id) REFERENCES files(id),
    FOREIGN KEY(viewmodel_symbol_id) REFERENCES symbols(id)
);

CREATE INDEX idx_xaml_vm ON xaml_bindings(viewmodel_symbol_id);
```

### Table 6: snapshots

Tracks orchestration states.

```sql
CREATE TABLE snapshots (
    id INTEGER PRIMARY KEY,
    created_utc TEXT NOT NULL,
    reason TEXT NOT NULL,        -- 'Pre-Generation', 'Post-Patch', 'Manual'
    parent_snapshot_id INTEGER
);
```

### Table 7: versions

User-facing timeline.

```sql
CREATE TABLE versions (
    id INTEGER PRIMARY KEY,
    snapshot_id INTEGER NOT NULL,
    summary TEXT NOT NULL,       -- 'Added Authentication', 'Fixed Build Error'
    build_status TEXT NOT NULL,  -- 'Success', 'Failed'
    created_utc TEXT NOT NULL,
    FOREIGN KEY(snapshot_id) REFERENCES snapshots(id)
);
```

---

## 2. Graph Update Algorithm

Must be **deterministic** and **transactional**.

### Scenario A: On File Change (Single File Mutation)

```csharp
public async Task UpdateGraphForFileAsync(string filePath, string newContent)
{
    using var transaction = _connection.BeginTransaction();
    
    try 
    {
        // 1. Create new snapshot ID context
        // (Assuming orchestrator already created snapshot record)

        // 2. Clear old records for this file in current snapshot context
        // Note: In a real system, we might version rows. 
        // For strict snapshot isolation, we treat specific snapshot_id as active set.
        await ClearFileRecordsAsync(filePath, currentSnapshotId);

        // 3. Parse with Roslyn
        var syntaxTree = CSharpSyntaxTree.ParseText(newContent);
        var root = await syntaxTree.GetRootAsync();

        // 4. Extract & Insert Syntax Nodes
        foreach (var node in root.DescendantNodes())
        {
            if (IsIndexable(node)) InsertSyntaxNode(node);
        }

        // 5. Resolve Semantic Model
        var semanticModel = _compilation.GetSemanticModel(syntaxTree);

        // 6. Insert Symbols
        foreach (var symbol in ExtractSymbols(semanticModel))
        {
            InsertSymbol(symbol);
        }

        // 7. Resolve & Insert Edges
        // Requires looking up other symbols in DB to find 'to_symbol_id'
        foreach (var edge in ResolveEdges(semanticModel))
        {
            InsertEdge(edge);
        }

        // 8. Handle XAML (if applicable)
        if (IsXaml(filePath))
        {
            UpdateXamlBindings(filePath, newContent);
        }

        transaction.Commit();
    }
    catch
    {
        transaction.Rollback();
        throw;
    }
}
```

### Scenario B: On Snapshot Restore

```
1. Rollback file system (IO operation)
2. Set Active Snapshot ID in Orchestrator
3. DB remains untouched (historical data preserved)
4. No re-indexing required (unless integrity check fails)
```

### Scenario C: Full Rebuild (Corruption Recovery)

```
1. Delete all graph records (TRUNCATE)
2. Iterate all files in workspace
3. Batch insert files
4. Batch processing of syntax/semantics
```

---

## 3. Incremental Indexing Strategy

### Trigger Conditions
- Orchestrator Startup (Check cleanliness)
- Post-Patch Application
- Manual User Trigger

### A. Hash-Based Detection
Before parsing logic:

```csharp
var currentHash = ComputeSha256(fileContent);
var storedHash = await _db.GetFileHashAsync(filePath);

if (currentHash == storedHash) 
{
    return; // SKIP - No changes
}
```

### B. Symbol Diff Strategy
When a file is modified, we only update:
1.  Symbols defined in **that file**
2.  Incoming edges **to** those symbols (re-validation)

### C. Dependency Revalidation
If `Symbol A` is removed:
1.  Query `symbol_edges` where `to_symbol_id == A`
2.  Identify all `from_symbol_id` (Dependents)
3.  Mark dependent files for **Semantic Re-Check**
4.  (Optional) Block mutation if breaking change detected without fix.

---

## 4. AI Retrieval Pipeline

Optimized for **Token Efficiency** and **Relevance**.

### Stage 1: Intent Classification
Input: "Fix bug in LoginViewModel"
Output: 
- Target Symbol: `LoginViewModel`
- Operation: `Modification`

### Stage 2: Impact Analysis (Graph Traversal)
```sql
-- Incoming Edges (Who uses LoginViewModel?)
SELECT from_symbol_id FROM symbol_edges 
WHERE to_symbol_id = @target_id AND depth <= 1;

-- Outgoing Edges (What does LoginViewModel use?)
SELECT to_symbol_id FROM symbol_edges 
WHERE from_symbol_id = @target_id AND depth <= 2;
```

### Stage 3: Context Assembly (Prioritized Order)
1.  **System Rules** (WinUI constraints)
2.  **Project Summary** (High-level architecture)
3.  **Target Symbol Definition** (Full code of `LoginViewModel`)
4.  **Direct Dependencies** (Interfaces, Services used)
5.  **XAML Bindings** (Corresponding `LoginPage.xaml`)
6.  **Error Context** (If in fix mode)

### Stage 4: Token Trimming
Stop adding dependencies when budget (e.g., 8000 tokens) is reached.

---

## 5. Why This Architecture?

1.  **Roslyn-Backed**: Relies on compiler truth, not regex.
2.  **Deterministic**: Same input always yields same graph state.
3.  **Snapshot-Safe**: DB state aligns perfectly with file system snapshots.
4.  **Token-Efficient**: Graph traversal prevents dumping entire codebases into LLM.
5.  **WinUI-Specific**: First-class handling of XAML bindings prevents MVVM drift.

---

## References
- [INDEXING_ARCHITECTURE_SPECIFICATION.md](./INDEXING_ARCHITECTURE_SPECIFICATION.md)
- [BACKGROUND_SYSTEMS_SPECIFICATION.md](./BACKGROUND_SYSTEMS_SPECIFICATION.md)
