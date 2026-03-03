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

- **No Universal Access**: An agent can only touch files relevant to its role.
- **No Shared Writable Memory**: Agents cannot overwrite global state.
- **No Infinite Loops**: Resource budgets are enforced per-execution.
- **AI Service Communication**: All AI capabilities come from Layer 6.6 (AI Service Layer) via user-configured providers.

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
    public int MaxAffectedSymbols { get; init; } = 50;        // Max symbols allowed in impact analysis
}

> **INVARIANT**: TokenBudget MUST be enforced at the AI Mini Service level.
> Agents cannot exceed the global token ceiling.
> The global token ceiling defined by the Orchestrator MUST override any per-agent TokenBudget.
> Agent-level budgets are upper bounds, not guarantees.

### 2.1 Token Budget Propagation Flow

The TokenBudget flows from the Orchestrator to the AI Mini Service as follows:

```

Orchestrator (BuilderContext)
│
├── ActiveAgentContext.TokenBudget (default: 8000)
│
▼
AI Service Client (C#)
│
├── HTTP POST to /api/chat
│ {
│ "messages": [...],
│ "max_tokens": context.TokenBudget // ← Injected here
│ }
│
▼
AI Mini Service (TypeScript)
│
├── Receives max_tokens in request body
├── Enforces via LOCKED_PARAMS (see AI_MINI_SERVICE_IMPLEMENTATION.md)
├── effectiveMaxTokens = Math.min(request.max_tokens, LOCKED_PARAMS.max_tokens)
│
▼
OpenAI-compatible Provider

```

**Key Points:**
1. The `AgentExecutionContext.TokenBudget` is set by the Orchestrator when creating the context
2. The AI Service Client includes it as `max_tokens` in the HTTP request
3. The AI Mini Service enforces it via the `LOCKED_PARAMS` mechanism
4. If the request exceeds the provider's maximum, the mini-service caps it at the effective limit

public enum AgentRole
{
    ARCHITECT,
    PLANNER,               // NEW: Read-only DAG creation
    SCHEMA,
    FRONTEND,
    BACKEND,
    INTEGRATION,
    CAPABILITY_INFERENCE,  // NEW: Manifest manipulation
    FIXER
}
```

---

## 3. File Access Contracts

Each agent role has a pre-defined "sandbox" of allowed file operations. Attempts to write outside this sandbox trigger a `SANDBOX_ESCAPE_ATTEMPT` error.

| Agent                    | Allowed Write Patterns                                              | Forbidden                                      |
| :----------------------- | :------------------------------------------------------------------ | :--------------------------------------------- |
| **Architect**            | `docs/**/*.md`, `README.md`, `*.sln`                                | `*.cs`, `*.xaml`, `Package.appxmanifest`       |
| **Planner**              | **NONE (Read-Only)**                                                | **ALL FILES** (Can only emit JSON Task Graphs) |
| **Schema**               | `Models/**/*.cs`, `Data/Migrations/**/*.cs`                         | `Controllers/*`, `Views/*`                     |
| **Frontend**             | `Views/**/*.xaml`, `ViewModels/**/*.cs`                             | `Services/*`, `Data/*`                         |
| **Backend**              | `Services/**/*.cs`, `Controllers/**/*.cs`                           | `Views/*`, `App.xaml`                          |
| **Integration**          | `Program.cs`, `App.xaml.cs` (DI wiring)                             | Core Models, Views                             |
| **Capability Inference** | `Package.appxmanifest` ONLY                                         | `*.cs`, `*.xaml`                               |
| **Fixer**                | _Target File Only_ (Scoped to error source via ErrorClassification) | Anything outside error scope                   |

**Enforcement:**
The `PatchEngine` validates every `write` operation against the `AllowedFilePatterns` of the active context. If the `PLANNER` agent attempts a write operation, the Kernel instantly throws a `SANDBOX_ESCAPE_ATTEMPT` error.

> **Code Generation Rules by Agent Role**:
>
> - **Schema agent** generates EF Core + SQLite code following [DATA_LAYER_GENERATION.md](./DATA_LAYER_GENERATION.md)
> - **Frontend agent** generates WinUI 3 XAML + ViewModels following [UI_GENERATION_RULES.md](./UI_GENERATION_RULES.md)
> - **Architect agent** outputs a spec conforming to [STRUCTURED_SPEC_FORMAT.md](./STRUCTURED_SPEC_FORMAT.md)
> - **All agents** use the bundled toolchain paths defined in [TOOLCHAIN_MANIFEST.md](./TOOLCHAIN_MANIFEST.md)

### 3.1 Fixer Agent Scope Rules

> **INVARIANT**: The Fixer agent is only allowed to modify files that are directly referenced in the error message, as determined by the `ErrorClassification` system defined in [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) Section 6.

The Fixer's allowed write patterns are dynamically determined at runtime based on:

1. **ErrorClassification.FilePath** — The primary file where the error occurred
2. **ErrorClassification.LineNumber** — Used to identify related code blocks
3. **Error auto-fix strategy** — May include additional related files (e.g., ViewModel when View has binding error)

**Example ErrorClassification for Fixer Scoping:**

```csharp
var classification = new ErrorClassification
{
    Type = ErrorType.BUILD_ERROR,
    Message = "CS0103: The name 'UserViewModel' does not exist in 'MainPage.xaml.cs'",
    FilePath = "Views/MainPage.xaml.cs",
    LineNumber = 42,
    AutoFixStrategy = "Add missing using directive or create ViewModel"
};

// Fixer is allowed to modify:
// - Views/MainPage.xaml.cs (primary error source)
// - ViewModels/UserViewModel.cs (if creation is needed - determined by auto-fix strategy)
```

**Runtime Enforcement:**
The `MutationGuard` receives the `ErrorClassification` and builds a temporary `AllowedFilePatterns` list specifically for the Fixer agent's current invocation.

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
    AGENT_SCOPED,

    // Retry Scoped: Isolated per-retry attempt, always cleared between attempts
    RETRY_SCOPED
}
```

### Read/Write Matrix

| Scope      | Architect | Planner | Schema  | Frontend | Backend | Capability | Fixer   |
| :--------- | :-------- | :------ | :------ | :------- | :------ | :--------- | :------ |
| **Global** | READ      | READ    | READ    | READ     | READ    | READ       | READ    |
| **Task**   | WRITE     | WRITE   | READ    | READ     | READ    | READ       | READ    |
| **Agent**  | PRIVATE   | PRIVATE | PRIVATE | PRIVATE  | PRIVATE | PRIVATE    | PRIVATE |

- **Task Memory**: Used to pass the "Spec" or "Plan" down. Only the `Architect` and `Planner` write the plan. The execution agents (Frontend, Backend, etc.) only read it.
- **Agent Memory**: Used for internal reasoning ("Chain of Thought"). Discarded after execution.

### 4.1 Memory Lifecycle Enforcement

To prevent state leakage, memory is cleared according to the following deterministic rules:

1.  **AGENT_SCOPED**: Wiped immediately upon task completion (Success or Failure).
2.  **TASK_SCOPED**: Wiped upon Task Graph completion or on `RETRY_STAGE.ARCHITECTURE_LEVEL` escalation.
3.  **GLOBAL_READONLY**: Persists for the duration of the Session.

### 4.2 Retry Cycle Memory Rules (CRITICAL)

> **INVARIANT**: Memory lifecycle during retries is strictly defined to prevent state leakage across retry attempts. Per Retry Budget Contract, retry is BOUNDED. SYSTEM_RESET at cycle 10+ clears memory and retries with a fresh approach.

| Retry Stage              | AGENT_SCOPED               | TASK_SCOPED  | RETRY_SCOPED               |
| ------------------------ | -------------------------- | ------------ | -------------------------- |
| FIX_LEVEL (1-3)          | Cleared after each attempt | **Retained** | Cleared after each attempt |
| INTEGRATION_LEVEL (4-6)  | Cleared after each attempt | **Retained** | Cleared after each attempt |
| ARCHITECTURE_LEVEL (7-9) | Cleared after each attempt | **Retained** | Cleared after each attempt |
| SYSTEM_RESET (10+)       | Cleared                    | **Cleared**  | Cleared (Forced Amnesia)   |

### Memory Clearing Sequence

```
RETRY ATTEMPT (1-9):
┌─────────────────────────────────────────┐
│ 1. Clear RETRY_SCOPED memory            │
│ 2. Clear AGENT_SCOPED memory            │
│ 3. RETAIN TASK_SCOPED memory            │
│ 4. Execute retry with fresh agent state │
└─────────────────────────────────────────┘

SYSTEM RESET (Cycle 10+):
┌─────────────────────────────────────────┐
│ 1. Clear RETRY_SCOPED memory            │
│ 2. Clear AGENT_SCOPED memory            │
│ 3. Clear TASK_SCOPED memory (Amnesia)   │
│ 4. Rollback to PreMutationSnapshotId    │
│ 5. Restart task with entirely new plan  │
└─────────────────────────────────────────┘

NOTE: Per Retry Budget Contract (see ORCHESTRATION_ENGINE.md), retry is BOUNDED. SYSTEM_RESET at cycle 10+ enforces the ceiling. Only AI_SERVICE_UNAVAILABLE/DEGRADED have infinite retry.
Only user cancellation stops execution.
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
        // Always clear RETRY_SCOPED and AGENT_SCOPED scopes
        _memoryLifecycleManager.DisposeScope(MemoryScope.RETRY_SCOPED, projectId);
        _memoryLifecycleManager.DisposeScope(MemoryScope.AGENT_SCOPED, projectId);

        // On SYSTEM_RESET, clear TASK_SCOPED scope (Forced Amnesia)
        if (stage == RetryStage.SYSTEM_RESET)
        {
            _memoryLifecycleManager.DisposeScope(MemoryScope.TASK_SCOPED, projectId);
        }
        // Otherwise TASK_SCOPED is RETAINED for retry continuity
    }
}
```

### Rationale

| Memory Scope | Behavior During Retry       | Reason                                                                                         |
| ------------ | --------------------------- | ---------------------------------------------------------------------------------------------- |
| RETRY_SCOPED | Always cleared              | Isolates each retry attempt; prevents error cascade                                            |
| AGENT_SCOPED | Always cleared              | Agent gets fresh context each attempt; prevents reasoning contamination                        |
| TASK_SCOPED  | Retained until SYSTEM_RESET | Preserves task plan for adaptive retry; cleared on SYSTEM_RESET to force entirely new approach |

---

## 5. Enforcement Mechanisms

### 5.1 AI-Primary Ownership of Enforcement

> **The AI Construction Engine proposes, the Runtime Safety Kernel enforces.**

The enforcement mechanisms follow the AI-Primary model:

| Enforcement Type  | Owner                        | Description                                      |
| ----------------- | ---------------------------- | ------------------------------------------------ |
| File sandbox      | Runtime Safety Kernel        | Hard rejection if violated                       |
| Mutation ceilings | Runtime Safety Kernel        | Hard limits enforced before commit               |
| Token budget      | Runtime Safety Kernel        | Hard timeout if exceeded                         |
| Code manipulation | Runtime Safety Kernel        | No unstructured string manipulation (see NOTE)  |
| Retry strategy    | AI Construction Engine       | Agents decide how to adapt                       |
| Error recovery    | AI Construction Engine       | Agents decide fix approach                       |
| AI capabilities   | AI Service Layer (Layer 6.6) | LLM, Vision, Image Gen, Search - user-configured |

> **NOTE: No Unstructured Code Manipulation**: All code modifications MUST use structured transformations:
> - **C#**: Roslyn AST transformation + `Formatter.Format()` → `File.WriteAllTextAsync()`
> - **XAML**: XML parsing (`XDocument`) → modification → `XDocument.Save()` or `File.WriteAllTextAsync()`
> 
> Direct string replacement, regex-based code modification, or LLM output written directly to files is FORBIDDEN.
> See [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) §1 for the complete invariant definition.

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

- **Token Limit**: Truncation or error if exceeded.
- **Time Limit**: Hard timeout (e.g., 60s) kills the agent process.

---

## References

- [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — **AI capabilities via user-configured providers**
- [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md) — Complete TypeScript implementation
- [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — AI Construction Engine vs Runtime Safety Kernel
- [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Multi-agent coordination
- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 8-layer architecture
