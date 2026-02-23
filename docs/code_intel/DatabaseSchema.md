# Database Schema

> **Code Intelligence Layer: SQLite Graph Database Schema**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [RoslynCompilation.md](./RoslynCompilation.md) — Code indexing

---

## Table of Contents

1. [Project Graph Database](#1-project-graph-database)
2. [File Layer](#2-file-layer)
3. [Syntax Layer](#3-syntax-layer)
4. [Symbol Layer](#4-symbol-layer)
5. [Edge Layer](#5-edge-layer)
6. [XAML Binding Layer](#6-xaml-binding-layer)
7. [Snapshot Layer](#7-snapshot-layer)
8. [Vector Embeddings Layer](#8-vector-embeddings-layer)
9. [Snapshot Storage](#9-snapshot-storage)

---

## 1. Project Graph Database

Multi-layer graph model: File → Syntax → Symbol → Edge → XAML → Version.

---

## 2. File Layer

```sql
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
```

---

## 3. Syntax Layer

```sql
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
```

---

## 4. Symbol Layer

```sql
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
```

---

## 5. Edge Layer

```sql
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
```

---

## 6. XAML Binding Layer

```sql
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
```

---

## 7. Snapshot Layer

```sql
CREATE TABLE snapshots (
    id INTEGER PRIMARY KEY,
    parent_snapshot_id INTEGER,
    created_utc TEXT NOT NULL,
    reason TEXT NOT NULL,          -- 'Pre-Generation', 'Post-Patch', 'Manual'
    FOREIGN KEY(parent_snapshot_id) REFERENCES snapshots(id)
);
```

---

## 8. Vector Embeddings Layer

```sql
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

---

## 9. Snapshot Storage

> **NOTE**: Snapshots are managed via Git. See [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md) §2.5 for the complete Git-based snapshot mechanism.

Snapshots use the project's `.git/` repository for version history:

- **SnapshotId** values are Git commit hashes
- **Rollback** uses `git checkout` to restore previous states
- **Pruning** uses `git gc` and branch management to control repository size
- **No custom compression** needed - Git handles delta compression natively

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document
- [RoslynCompilation.md](./RoslynCompilation.md) — Code indexing
- [GraphIntegrity.md](./GraphIntegrity.md) — Integrity verification
- [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md) — Git-based snapshots

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md as part of documentation reorganization |