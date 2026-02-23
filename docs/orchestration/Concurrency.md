# Concurrency

> **Orchestration Layer: Thread Types, Locking Strategy, and Execution Ordering**
>
> **Parent Document:** [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md)
>
> **Related:** [StateMachine.md](./StateMachine.md) — Builder states and transitions

---

## Table of Contents

1. [Named Thread Types](#1-named-thread-types)
2. [Phase Flow](#2-phase-flow)
3. [Concurrency Matrix](#3-concurrency-matrix)
4. [Locking Strategy](#4-locking-strategy)
5. [DAG Execution Clarification](#5-dag-execution-clarification)

---

## 1. Named Thread Types

| Thread | Color | Purpose | Concurrency |
|--------|-------|---------|-------------|
| 🟢 UI Thread | Green | Rendering, user input, never blocks | Single (main) |
| 🔵 Orchestrator Thread | Blue | Sequential execution, state machine | Single |
| 🟣 AI Worker Thread Pool | Purple | AI code generation tasks | Max 2 concurrent |
| 🟡 Patch Worker Thread | Yellow | File mutations, requires exclusive file lock | Single-threaded |
| 🔴 Build Worker Thread | Red | MSBuild compilation, isolated | Single (per build) |
| ⚪ Background Maintenance | White | Low priority cleanup | Single |

---

## 2. Phase Flow

### Phase 1 — Spec Parsing (Orchestrator Thread)

### Phase 2 — Task Graph Construction (Orchestrator Thread)

### Phase 3 — Task Execution Loop (SERIALIZED)
1. AI_GENERATING - AI generates code
2. CREATING_SNAPSHOT - Snapshot BEFORE mutation
3. MUTATION_GUARD - Validate safety
4. PATCHING - Apply transformation
5. INDEXING - Update semantic graph
6. CAPABILITY_SCAN - Proactive capability inference
7. BUILDING - Compile
8. VALIDATING - Check integrity

### Phase 4 — Finalization (Orchestrator Thread)

### Phase 5 — Packaging & Signing (Mandatory)

---

## 3. Concurrency Matrix

| Operation | Can Run With | Cannot Run With | Lock Type |
|-----------|--------------|-----------------|-----------|
| **Patching (Mutation)** | Nothing | All other operations | Exclusive Write Lock |
| **Indexing** | Read queries | Mutation, Build | Exclusive Write Lock |
| **Building** | Nothing | All other operations | Exclusive Build Lock |
| **Read Queries** | All read operations | Mutation | Shared Read Lock |
| **AI Generation** | Other AI Generation | Mutation, Build | None (stateless) |

```csharp
public class ConcurrencyPolicy
{
    public static LockType GetRequiredLock(OperationType operation) => operation switch
    {
        OperationType.Mutation => LockType.ExclusiveWrite,
        OperationType.Indexing => LockType.ExclusiveWrite,
        OperationType.Build => LockType.ExclusiveBuild,
        OperationType.ReadQuery => LockType.SharedRead,
        OperationType.AIGeneration => LockType.None,
        _ => LockType.SharedRead
    };
}
```

---

## 4. Locking Strategy

### Single-Writer, Multi-Reader

**Thread Roles**
- **Indexing Writer**: 1 Thread (Exclusive)
- **Patch Writer**: 1 Thread (Exclusive)
- **Build Runner**: 1 Thread (Exclusive)
- **Readers (UI/AI)**: Concurrent allowed

**Locking Mechanisms**
1. **Workspace Lock**: Mutex `Global\Workspace_{ProjectId}` ensures only one ExecutionSession active per project.
2. **Graph Write Lock**: SQLite `BEGIN IMMEDIATE TRANSACTION` blocks other writers, allows readers (WAL mode).
3. **File Locking**: Patch Engine locks target file during read-modify-write cycle.

**Execution Ordering Rule (Strict)**
`PATCH → INDEX → BUILD → COMMIT`

---

## 5. DAG Execution Clarification

> **The DAG shows PLANNING dependencies, not EXECUTION parallelism.**
>
> - Tasks at the same DAG level indicate they CAN theoretically run in parallel
> - BUT the Orchestrator executes them SEQUENTIALLY (one at a time)
> - This ensures deterministic state and safe rollback
> - `BuilderContext.CurrentTaskId` is always a single value, not a list

```csharp
// DAG planner outputs parallelizable structure
// Orchestrator flattens to sequential execution

public class SequentialExecutionStrategy
{
    public IEnumerable<Task> FlattenForExecution(TaskGraph dag)
    {
        // Topological sort ensures dependencies are respected
        // But execution is strictly sequential
        foreach (var task in dag.TopologicalSort())
        {
            yield return task;
        }
    }
}
```

---

## References

- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Parent document
- [StateMachine.md](./StateMachine.md) — Builder states and transitions
- [SnapshotAuthority.md](./SnapshotAuthority.md) — Transaction management
- [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md) — Process isolation

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from ORCHESTRATION_ENGINE.md as part of documentation reorganization |