# Safety & Performance Specification

**Purpose**: Define the hard guarantees for mutation safety, concurrency, performance at scale, and graph integrity.  
**Context**: "Enterprise-Grade" safeguards for the WinUI 3 autonomous builder.

---

## 1. Mutation Safety Guard

**Goal**: Prove the mutation will not destabilize the graph **BEFORE** application.

The guard sits between the AI's proposal and the Patch Engine.

```
AI Patch Proposal → [Mutation Safety Guard] → Patch Engine
```

### Layer 1: Target Existence Validation

**Checks**:

- Does the target symbol actually exist?
- Does the snapshot ID match the active snapshot?
- Does the file hash match the expected state?

**Action**: If any check fails → **REJECT** immediately (Stale Context).

### Layer 2: Impact Radius Calculation

**Algorithm**:

1. Query `symbol_edges` for the target symbol.
2. Traverse **Outgoing** edges (depth=2).
3. Traverse **Incoming** edges (depth=1).
4. Identify all affected symbols, files, and XAML bindings.

**Output**: `MutationScope` object.

### Layer 3: Breaking Change Detection

**Logic**: If the patch modifies public contracts:

- Method signatures
- Interface definitions
- Constructor parameters (Dependency Injection)
- ViewModel properties bound in XAML

**Action**: Simulate resolution of dependent symbols. If any become unresolved → **BLOCK**.

### Layer 4: AST Simulation (Dry Run)

**Process**:

1. Clone the SyntaxTree in memory.
2. Apply the patch transformation.
3. Build a temporary compilation context.
4. Validate:
   - Type resolution
   - Symbol references
   - Binding validity

**Action**: If compilation errors (diagnostics) appear → **REJECT**.

### Layer 5: Deterministic Snapshot Pre-Commit

**Process**:

1. Freeze graph state.
2. Apply patch in a temp/sandbox directory.
3. Run `dotnet build` (or design-time build).
4. Only commit if successful.

---

## 2. Guard Failure Escalation (Constraint Violation)

What happens when the Mutation Guard REJECTS the AI's proposal?

**Policy**: The AI does not get infinite retries.

### Escalation Path

1.  **Attempt 1 (Soft Rejection)**
    - **Action**: Return tailored error to AI with specific constraint (e.g., "Symbol Foo not found").
    - **Goal**: AI corrects context or imports.

2.  **Attempt 2 (Hard Rejection)**
    - **Action**: Return "Breaking Change Detected" with impact path.
    - **Goal**: AI refactors to avoid breaking public API.

3.  **Attempt 3 (Barrier Failure)**
    - **Action**: **STOP AUTOMATION**.
    - **UI State**: Transition to `INTERVENTION_REQUIRED` (or `SOFT_RECOVERY`).
    - **User Prompt**: "I cannot safely apply this change because it breaks dependencies [X, Y]. Should I: (A) Force apply? (B) Revert? (C) Create new file instead?"

---

## 2. Concurrency Safety Model

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

## 3. Performance Optimization (100K+ LOC)

**Goal**: Support large Windows apps without freezing the UI.

### A. Compilation Model Reuse

- **Don't** create new `CSharpCompilation` for every patch.
- **Do** utilize Roslyn's `CreateScriptCompilation` or standard incremental updates.
- Replace only the changed `SyntaxTree` in the existing `Compilation`.

### B. Lazy Graph Traversal

- **Limit** traversal depth (max 2-3 levels).
- **Limit** symbol count per retrieval.
- Only load semantic models for files in the `MutationScope`.

### C. SQLite Optimization

- **Composite Indexes**:
  ```sql
  CREATE INDEX idx_edges_composite ON symbol_edges(from_id, type);
  ```
- **WAL Mode**: Enable Write-Ahead Logging for concurrency.
- **Weekly Vacuum**: Auto-maintenance task.

### D. Snapshot Compression

- Store **Binary Diffs** or Git-style object storage instead of full file copies.
- Only materialize full files on Restore.

### E. Symbol Caching Layer (RAM)

- Cache frequently accessed symbols (e.g., `MainViewModel`, `App.xaml.cs`).
- Cache hot dependency edges.
- Invalidate cache entries on file modification.

### F. Retrieval Throttling

- Hard Cap: Max 200 symbols per context.
- Hard Cap: Max 8KB of source code per prompt.
- Force AI to request "More Context" if needed, rather than dumping everything.

---

## 4. Automated Graph Integrity Verifier

**Run triggers**: Boot, Post-Restore, Post-Crash, Weekly.

### Checks

1.  **File ↔ Symbol Consistency**
    - Recompute file hash via IO.
    - Compare with DB hash.
    - Mismatch? → **Re-index File**.

2.  **Edge Validity**
    - Verify `from_id` and `to_id` exist in `symbols` table.
    - Orphan edge? → **Delete**.

3.  **XAML Binding Validation**
    - Verify `viewmodel_symbol_id` exists.
    - Verify property name matches ViewModel symbol name.
    - Broken? → **Flag for Rebuild**.

4.  **Snapshot Chain**
    - Verify `parent_snapshot_id` links form a valid tree.
    - No cycles, no gaps.

### Self-Healing Repair Strategy

**If corruption detected**:

1. Lock Workspace.
2. Create "Safety Snapshot" (backup current state).
3. **TRUNCATE** graph tables (files, symbols, edges).
4. Perform **Full Re-index** from disk.
5. Validate Integrity.
6. Resume operation.

**User Feedback**: "Restoring project integrity..." (Non-blocking toast).

---

## 5. System Maturity Level

By implementing these 4 systems, we move beyond "template generators" to a **Deterministic Windows-Native Construction Kernel**.

| Feature            | Hobby/Web Builder        | Sync AI (Production)    |
| :----------------- | :----------------------- | :---------------------- |
| **Mutation Check** | Regex/LLM Validation     | 5-Layer Semantic Guard  |
| **Concurrency**    | Race Conditions Probable | Single-Writer Mutex     |
| **Scaling**        | Fails > 10K LOC          | Optimized for 100K+ LOC |
| **Reliability**    | "It works often"         | Automated Self-Healing  |

---

## References

- [DATABASE_SPECIFICATION.md](./DATABASE_SPECIFICATION.md)
- [EXECUTION_LIFECYCLE_SPECIFICATION.md](./EXECUTION_LIFECYCLE_SPECIFICATION.md)
- [INDEXING_ARCHITECTURE_SPECIFICATION.md](./INDEXING_ARCHITECTURE_SPECIFICATION.md)
