# Performance Optimizations

> **Code Intelligence Layer: Compilation Reuse, SQLite Tuning & Indexing Strategy**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [RoslynCompilation.md](./RoslynCompilation.md) | [DatabaseSchema.md](./DatabaseSchema.md)

---

## Table of Contents

1. [Compilation Model Reuse](#1-compilation-model-reuse)
2. [SQLite Optimizations](#2-sqlite-optimizations)
3. [Incremental Indexing](#3-incremental-indexing)

---

## 1. Compilation Model Reuse

### Rule

> **Do NOT** create a new `CSharpCompilation` for every patch.
> **Do** replace only the changed `SyntaxTree` in the existing `Compilation`.

Creating a full compilation from scratch is expensive (seconds for large projects). Differential replacement is O(file count) cheaper.

```csharp
public class CompilationCache
{
    private CSharpCompilation? _cachedCompilation;

    /// <summary>
    /// Update the compilation when a single file changes.
    /// Replaces the old SyntaxTree in place — does NOT rebuild from scratch.
    /// </summary>
    public CSharpCompilation UpdateFile(string filePath, SyntaxTree newTree)
    {
        if (_cachedCompilation == null)
            throw new InvalidOperationException("Compilation not initialized.");

        // Find and replace the old tree for this file
        var oldTree = _cachedCompilation.SyntaxTrees
            .FirstOrDefault(t => t.FilePath == filePath);

        _cachedCompilation = oldTree != null
            ? _cachedCompilation.ReplaceSyntaxTree(oldTree, newTree)
            : _cachedCompilation.AddSyntaxTrees(newTree);

        return _cachedCompilation;
    }
}
```

---

## 2. SQLite Optimizations

### WAL Mode (Write-Ahead Logging)

Enabled at database open time. Allows concurrent readers during writes — critical for the Single-Writer, Multi-Reader model.

```sql
PRAGMA journal_mode = WAL;
```

### Composite Indexes

Frequently joined queries use composite indexes:

```sql
-- Used by edge traversal queries (most frequent query in graph walk)
CREATE INDEX idx_edges_composite
    ON symbol_edges(from_symbol_id, edge_type, snapshot_id);

-- Used by GetSymbolsForFile queries
CREATE INDEX idx_symbol_nodes_file_snapshot
    ON symbol_nodes(file_id, snapshot_id);
```

### Weekly Vacuum

An auto-maintenance task compacts the WAL and reclaims unused pages:

```csharp
// Runs once per week via BackgroundTask
public async Task VacuumAsync()
{
    await _db.ExecuteAsync("PRAGMA wal_checkpoint(TRUNCATE);");
    await _db.ExecuteAsync("VACUUM;");
}
```

---

## 3. Incremental Indexing

Only re-index files that have changed since the last snapshot, using file hash comparison:

```csharp
public async Task IncrementalIndexAsync(string projectPath, int snapshotId)
{
    var allFiles = Directory.GetFiles(projectPath, "*.cs", SearchOption.AllDirectories);

    foreach (var file in allFiles)
    {
        var currentHash = ComputeHash(file);
        var storedHash  = await _db.GetFileHashAsync(file, snapshotId - 1);

        if (currentHash != storedHash)
        {
            // Only index changed files
            await IndexFileAsync(file, snapshotId);
        }
    }
}
```

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document (section 14)
- [RoslynCompilation.md](./RoslynCompilation.md) — Full compilation model
- [DatabaseSchema.md](./DatabaseSchema.md) — Schema and index definitions

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md §14 as part of documentation reorganization |
