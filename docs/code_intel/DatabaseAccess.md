# Database Access Layer

> **Code Intelligence Layer: Repository Pattern & Dapper Implementation**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [DatabaseSchema.md](./DatabaseSchema.md) — Full table & index definitions

---

## Table of Contents

1. [Repository Pattern](#1-repository-pattern)
2. [Dapper Implementation](#2-dapper-implementation)
3. [Connection Management](#3-connection-management)
4. [Transaction Strategy](#4-transaction-strategy)

---

## 1. Repository Pattern

All database access goes through typed repository interfaces. No raw SQL is scattered across the codebase outside of the repository implementations.

```csharp
public interface IRepository<T> where T : class
{
    Task<T>              GetByIdAsync(object id);
    Task<IEnumerable<T>> GetAllAsync();
    Task<T>              AddAsync(T entity);
    Task                 UpdateAsync(T entity);
    Task                 DeleteAsync(object id);
}
```

> **NOTE**: The full database schema (tables, indexes, snapshot layer) is defined in [DatabaseSchema.md](./DatabaseSchema.md). This file covers only the access patterns.

---

## 2. Dapper Implementation

```csharp
public class DapperRepository<T> : IRepository<T> where T : class
{
    private readonly IDbConnection _connection;

    public DapperRepository(IDbConnection connection)
    {
        _connection = connection;
    }

    public async Task<T> GetByIdAsync(object id)
    {
        var tableName = typeof(T).Name + "s";
        return await _connection.QuerySingleOrDefaultAsync<T>(
            $"SELECT * FROM {tableName} WHERE Id = @Id",
            new { Id = id });
    }

    public async Task<IEnumerable<T>> GetAllAsync()
    {
        var tableName = typeof(T).Name + "s";
        return await _connection.QueryAsync<T>($"SELECT * FROM {tableName}");
    }

    public async Task<T> AddAsync(T entity)
    {
        // Insert via Dapper Contrib or manual SQL
        await _connection.InsertAsync(entity);
        return entity;
    }

    public async Task UpdateAsync(T entity)
    {
        await _connection.UpdateAsync(entity);
    }

    public async Task DeleteAsync(object id)
    {
        var tableName = typeof(T).Name + "s";
        await _connection.ExecuteAsync(
            $"DELETE FROM {tableName} WHERE Id = @Id",
            new { Id = id });
    }
}
```

---

## 3. Connection Management

SQLite connections are opened once per session and kept alive for the workspace lifetime. WAL mode is enabled at open time:

```csharp
public class ProjectDatabase : IDisposable
{
    private readonly SqliteConnection _connection;

    public ProjectDatabase(string dbPath)
    {
        _connection = new SqliteConnection($"Data Source={dbPath}");
        _connection.Open();

        // Enable WAL for concurrent reader/single-writer access
        _connection.Execute("PRAGMA journal_mode = WAL;");
        _connection.Execute("PRAGMA foreign_keys = ON;");
    }

    public void Dispose() => _connection.Dispose();
}
```

---

## 4. Transaction Strategy

**Atomic writes**: All patch-related writes (symbol upserts, edge updates, snapshot creation) are wrapped in a single `BEGIN IMMEDIATE TRANSACTION`:

```csharp
public async Task CommitPatchResultAsync(PatchResult result, int snapshotId)
{
    using var transaction = _connection.BeginTransaction(IsolationLevel.Serializable);
    try
    {
        await UpsertSymbolsAsync(result.UpdatedSymbols, snapshotId, transaction);
        await UpsertEdgesAsync(result.UpdatedEdges, snapshotId, transaction);
        await InsertSnapshotAsync(snapshotId, transaction);

        transaction.Commit();
    }
    catch
    {
        transaction.Rollback();
        throw;
    }
}
```

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document (section 13)
- [DatabaseSchema.md](./DatabaseSchema.md) — Table definitions, indexes, snapshot schema
- [Performance.md](./Performance.md) — SQLite tuning (WAL, composite indexes, vacuum)

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md §13 as part of documentation reorganization |
