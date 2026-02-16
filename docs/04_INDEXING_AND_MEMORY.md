# Indexing and Memory

> **Authority**: This document defines the SQLite schema, graph model, symbol graph, snapshot graph, incremental indexing, and background maintenance.
> **Status**: Data persistence layer

---

## Part 1: SQLite Schema

### Core Tables

```sql
-- Projects
CREATE TABLE projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    path TEXT NOT NULL,
    created_at DATETIME,
    updated_at DATETIME
);

-- Files
CREATE TABLE files (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    file_path TEXT,
    content_hash TEXT,
    content_size INT,
    indexed_at DATETIME,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Symbols
CREATE TABLE symbols (
    id TEXT PRIMARY KEY,
    file_id TEXT,
    symbol_name TEXT,
    symbol_kind TEXT,
    line_number INT,
    namespace TEXT,
    FOREIGN KEY (file_id) REFERENCES files(id)
);

-- Dependencies
CREATE TABLE dependencies (
    id TEXT PRIMARY KEY,
    source_file_id TEXT,
    target_symbol_id TEXT,
    dependency_type TEXT,
    FOREIGN KEY (source_file_id) REFERENCES files(id),
    FOREIGN KEY (target_symbol_id) REFERENCES symbols(id)
);

-- Build Errors (for pattern matching)
CREATE TABLE build_errors (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    error_code TEXT,
    error_message TEXT,
    file_id TEXT,
    line_number INT,
    solution TEXT,
    occurrence_count INT,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Architectural Decisions
CREATE TABLE architectural_decisions (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    decision_type TEXT,
    decision_value TEXT,
    reasoning TEXT,
    applied_at DATETIME,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Embeddings (for semantic search)
CREATE TABLE embeddings (
    id TEXT PRIMARY KEY,
    file_id TEXT,
    embedding BLOB,
    embedding_model TEXT,
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

-- Execution Log
CREATE TABLE execution_log (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    event_type TEXT,
    event_data JSON,
    timestamp DATETIME,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);
```

---

## Part 2: Graph Model

### Symbol Graph

The symbol graph tracks relationships between code elements:

```
Customer.cs
  ├─ imports: DbContext
  ├─ imports: Validator
  └─ used by: CustomerService.cs
  
CustomerService.cs
  ├─ imports: Customer.cs
  ├─ imports: ILogger
  └─ used by: CustomerController.cs
  
CustomerController.cs
  ├─ imports: CustomerService.cs
  └─ user-accessible routes: /api/customers/*
```

### Dependency Graph

```json
{
  "files": [
    {
      "path": "Models/Customer.cs",
      "type": "class",
      "dependencies": ["System.Data", "DbContext"],
      "exports": ["Customer", "CustomerValidator"]
    }
  ]
}
```

---

## Part 3: Incremental Indexing

### Strategy

Only re-index changed files, not entire project:

```csharp
public class IncrementalIndexer
{
    public async Task IndexChangedFilesAsync(string projectPath)
    {
        var changedFiles = await GetChangedFilesAsync(projectPath);
        
        foreach (var file in changedFiles)
        {
            await IndexFileAsync(file);
        }
        
        await UpdateDependencyGraphAsync(changedFiles);
    }
    
    private async Task<List<string>> GetChangedFilesAsync(string projectPath)
    {
        var files = Directory.GetFiles(projectPath, "*.cs", SearchOption.AllDirectories);
        var changed = new List<string>();
        
        foreach (var file in files)
        {
            var currentHash = ComputeHash(file);
            var lastHash = await GetLastIndexedHashAsync(file);
            
            if (currentHash != lastHash)
            {
                changed.Add(file);
            }
        }
        
        return changed;
    }
}
```

---

## Part 4: Background Maintenance

### Tasks

1. **Snapshot Pruning** - Remove old snapshots beyond retention limit
2. **SQLite VACUUM** - Optimize database periodically
3. **Disk Usage Monitoring** - Warn when space is low
4. **Index Consistency Check** - Verify graph integrity

### Background Worker

```csharp
public class BackgroundMaintenance
{
    private readonly Timer _maintenanceTimer;
    
    public void StartMaintenance()
    {
        _maintenanceTimer = new Timer(
            callback: RunMaintenanceAsync,
            state: null,
            dueTime: TimeSpan.FromMinutes(5),
            period: TimeSpan.FromMinutes(10)
        );
    }
    
    private async void RunMaintenanceAsync(object state)
    {
        if (_orchestrator.CurrentState != OrchestratorState.IDLE)
            return;
        
        await Task.Run(async () =>
        {
            await _snapshotPruner.PruneOldSnapshotsAsync();
            await _database.VacuumAsync();
            await _resourceMonitor.CheckDiskUsageAsync();
            await _indexer.ValidateConsistencyAsync();
        });
    }
}
```

---

## Part 5: Integrity Verification

### Graph Consistency Checks

```csharp
public async Task<bool> ValidateGraphIntegrityAsync(string projectId)
{
    // 1. Check for orphaned symbols (symbol without file)
    var orphanedSymbols = await _db.QueryAsync(@"
        SELECT s.* FROM symbols s
        LEFT JOIN files f ON s.file_id = f.id
        WHERE f.id IS NULL");
    
    if (orphanedSymbols.Any())
        return false;
    
    // 2. Check for broken dependencies (missing target)
    var brokenDeps = await _db.QueryAsync(@"
        SELECT d.* FROM dependencies d
        LEFT JOIN symbols t ON d.target_symbol_id = t.id
        WHERE t.id IS NULL");
    
    if (brokenDeps.Any())
        return false;
    
    return true;
}
```

---

## Related Documents

- [00_CANONICAL_AUTHORITY.md](./00_CANONICAL_AUTHORITY.md) - System invariants
- [02_ORCHESTRATION_AND_EXECUTION.md](./02_ORCHESTRATION_AND_EXECUTION.md) - State machine

---

**End of Indexing and Memory**
