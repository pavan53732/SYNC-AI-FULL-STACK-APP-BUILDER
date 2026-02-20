# AGENT EXECUTION CONTRACT

> **The Law of Agents: Isolation, Permissions, and Memory Scoping**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> _Agents are owned and operated by the AI Construction Engine. The Runtime Safety Kernel enforces their boundaries._

---

## Table of Contents

1. [Core Philosophy](#1-core-philosophy)
2. [Agent Execution Context](#2-agent-execution-context)
3. [File Access Contracts](#3-file-access-contracts)
4. [Memory Scoping Rules](#4-memory-scoping-rules)
5. [Enforcement Mechanisms](#5-enforcement-mechanisms)

---

## 1. Core Philosophy

To prevent "autonomy drift" and ensuring deterministic system behavior, all agents operate under a **Bounded Execution Contract**.

*   **No Universal Access**: An agent can only touch files relevant to its role.
*   **No Shared Writable Memory**: Agents cannot overwrite global state.
*   **No Infinite Loops**: Resource budgets are enforced per-execution.

---

## 2. Agent Execution Context

The `AgentExecutionContext` is the immutable "ID card" and "Limit Set" passed to every agent invocation.

```csharp
public record AgentExecutionContext
{
    // Identity
    public AgentRole Role { get; init; }
    public string TaskId { get; init; }
    
    // Constraints
    public IReadOnlyList<string> AllowedFilePatterns { get; init; } // e.g., ["**/*.cs"]
    public IReadOnlyList<string> RestrictedFiles { get; init; }     // e.g., ["Program.cs"]
    public bool ReadOnlySemanticGraph { get; init; }                // Can it trigger re-indexing?
    
    // Resources
    public int MaxPatchOperations { get; init; } = 50;              // Max mutations per run
    public int TokenBudget { get; init; } = 8000;                   // Max tokens for reasoning
    
    // Memory Scope
    public MemoryScope MemoryScope { get; init; }
    
    // Safety Ceilings
    public int MaxFilesTouchedPerTask { get; init; } = 10;
    public int MaxNodesModifiedPerTask { get; init; } = 500;
}

public enum AgentRole
{
    ARCHITECT,
    SCHEMA,
    FRONTEND,
    BACKEND,
    INTEGRATION,
    FIXER
}
```

---

## 3. File Access Contracts

Each agent role has a pre-defined "sandbox" of allowed file operations. Attempts to write outside this sandbox trigger a `SANDBOX_ESCAPE_ATTEMPT` error.

| Agent | Allowed Write Patterns | Forbidden |
| :--- | :--- | :--- |
| **Architect** | `docs/**/*.md`, `README.md`, `*.sln` | `*.cs`, `*.xaml` |
| **Schema** | `Models/**/*.cs`, `Data/Migrations/**/*.cs` | `Controllers/*`, `Views/*` |
| **Frontend** | `Views/**/*.xaml`, `ViewModels/**/*.cs` | `Services/*`, `Data/*` |
| **Backend** | `Services/**/*.cs`, `Controllers/**/*.cs` | `Views/*`, `App.xaml` |
| **Integration** | `Program.cs`, `App.xaml.cs` (DI wiring) | Core Models |
| **Fixer** | *Target File Only* (Scoped to error source) | Anything else |

**Enforcement:**
The `PatchEngine` validates every `write` operation against the `AllowedFilePatterns` of the active context.

---

## 4. Memory Scoping Rules

Memory interactions are strictly scoped to prevent cross-contamination between parallel thoughts or sequential tasks.

```csharp
public enum MemoryScope
{
    // Global Read-Only: Standard Library, Project Context
    GLOBAL_READONLY,
    
    // Task Scoped: Shared only within the current Task ID
    TASK_SCOPED,
    
    // Agent Scoped: Private scratchpad for the agent instance
    AGENT_SCOPED
}
```

### Read/Write Matrix

| Scope | Architect | Schema | Frontend | Backend | Fixer |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Global** | READ | READ | READ | READ | READ |
| **Task** | WRITE | READ | READ | READ | READ |
| **Agent** | PRIVATE | PRIVATE | PRIVATE | PRIVATE | PRIVATE |

*   **Task Memory**: Used to pass the "Spec" or "Plan" down. Only `Architect` writes the plan. Others read it.
*   **Agent Memory**: Used for internal reasoning ("Chain of Thought"). Discarded after execution.

### 4.1 Memory Lifecycle Enforcement

To prevent state leakage, memory is cleared according to the following deterministic rules:

1.  **AGENT_SCOPED**: Wiped immediately upon task completion (Success or Failure).
2.  **TASK_SCOPED**: Wiped upon Task Graph completion or on `RETRY_STAGE.ARCHITECTURE_LEVEL` escalation.
3.  **GLOBAL_READONLY**: Persists for the duration of the Session.

### 4.2 Retry Cycle Memory Rules (CRITICAL)

> **INVARIANT**: Memory lifecycle during retries is strictly defined to prevent state leakage across retry attempts.

| Retry Stage | AGENT_SCOPED | TASK_SCOPED | RETRY_SCOPED |
|-------------|--------------|-------------|--------------|
| FIX_LEVEL (1-3) | Cleared after each attempt | **Retained** | Cleared after each attempt |
| INTEGRATION_LEVEL (4-6) | Cleared after each attempt | **Retained** | Cleared after each attempt |
| ARCHITECTURE_LEVEL (7-9) | Cleared after each attempt | **Retained** | Cleared after each attempt |
| ABORT (10+) | Cleared | **Cleared** | Cleared |

### Memory Clearing Sequence

```
RETRY ATTEMPT (1-9):
┌─────────────────────────────────────────┐
│ 1. Clear RETRY_SCOPED memory            │
│ 2. Clear AGENT_SCOPED memory            │
│ 3. RETAIN TASK_SCOPED memory            │
│ 4. Execute retry with fresh agent state │
└─────────────────────────────────────────┘

ABORT (Cycle 10+):
┌─────────────────────────────────────────┐
│ 1. Clear RETRY_SCOPED memory            │
│ 2. Clear AGENT_SCOPED memory            │
│ 3. Clear TASK_SCOPED memory             │
│ 4. Rollback to LastStableSnapshotHash   │
│ 5. Emit BuildFailedEvent                │
└─────────────────────────────────────────┘
```

### Implementation

```csharp
public class RetryMemoryPolicy
{
    /// <summary>
    /// Called BEFORE each retry attempt to prepare memory state.
    /// </summary>
    public void PrepareRetryMemory(RetryStage stage, string projectId)
    {
        // Always clear RETRY and AGENT scopes
        _memoryLifecycleManager.DisposeScope(MemoryScope.RETRY, projectId);
        _memoryLifecycleManager.DisposeScope(MemoryScope.AGENT, projectId);

        // Only clear TASK scope on ABORT
        if (stage == RetryStage.ABORT)
        {
            _memoryLifecycleManager.DisposeScope(MemoryScope.TASK, projectId);
        }
        // Otherwise TASK_SCOPED is RETAINED for retry continuity
    }
}
```

### Rationale

| Memory Scope | Behavior During Retry | Reason |
|--------------|----------------------|--------|
| RETRY_SCOPED | Always cleared | Isolates each retry attempt; prevents error cascade |
| AGENT_SCOPED | Always cleared | Agent gets fresh context each attempt; prevents reasoning contamination |
| TASK_SCOPED | Retained until ABORT | Preserves task plan and context for adaptive retry; cleared on abort to prevent corrupt state persistence |

---

## 5. Enforcement Mechanisms

### 5.1 AI-Primary Ownership of Enforcement

> **The AI Construction Engine proposes, the Runtime Safety Kernel enforces.**

The enforcement mechanisms follow the AI-Primary model:

| Enforcement Type | Owner | Description |
|------------------|-------|-------------|
| File sandbox | Runtime Safety Kernel | Hard rejection if violated |
| Mutation ceilings | Runtime Safety Kernel | Hard limits enforced before commit |
| Token budget | Runtime Safety Kernel | Hard timeout if exceeded |
| Retry strategy | AI Construction Engine | Agents decide how to adapt |
| Error recovery | AI Construction Engine | Agents decide fix approach |

### 5.2 The Sandbox Guard

Before any `IPatchTransaction` is committed, the `MutationGuard` verifies:

1.  **File Path Check**: Is the target file in `AllowedFilePatterns`?
2.  **Budget Check**: Has `MaxPatchOperations` been exceeded?
3.  **Delta Check**: Have `MaxFilesTouchedPerTask` or `MaxNodesModifiedPerTask` been exceeded?
4.  **Semantic Check**: Does the change violate `ReadOnlySemanticGraph` (if set)?

```csharp
public class MutationGuard
{
    public void Validate(IPatchTransaction transaction, AgentExecutionContext context)
    {
        if (!context.AllowedFilePatterns.Any(p => Match(p, transaction.FilePath)))
        {
            throw new SecurityException($"Agent {context.Role} attempted to modify forbidden file: {transaction.FilePath}");
        }
    }
}
```

### 5.2 Token & Resource Limits

Agents are invoked with hard limits.

*   **Token Limit**: Truncation or error if exceeded.
*   **Time Limit**: Hard timeout (e.g., 60s) kills the agent process.
