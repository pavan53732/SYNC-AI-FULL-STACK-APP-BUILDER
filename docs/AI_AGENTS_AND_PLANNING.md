# AI AGENTS AND PLANNING

> **The AI Construction Engine: Blueprint Design, Adaptive Planning & Multi-Agent Coordination**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> _The AI Construction Engine is the PRIMARY BRAIN. It designs adaptive blueprints, learns from errors, and owns the entire construction strategy. The Runtime Safety Kernel enforces hard boundaries silently._

---

## Table of Contents

1. [Overview](#1-overview)
2. [AI Architecture Blueprint Model](#2-ai-architecture-blueprint-model)
3. [Adaptive Planning Layer](#3-adaptive-planning-layer)
4. [Multi-Agent Specifications](#4-multi-agent-specifications)
5. [Agent Execution Contracts](#5-agent-execution-contracts)
6. [Agent Orchestration Pattern](#6-agent-orchestration-pattern)
7. [Retry Ownership](#7-retry-ownership)
8. [AI Engine Integration](#8-ai-engine-integration)

---

## 1. Overview

The AI Construction Engine transforms unstructured user prompts into adaptive architectural blueprints and coordinates multiple specialized agents to generate complete, runnable applications.

### Core Responsibilities

1. **Blueprint Design**: AI creates adaptive architectural blueprints
2. **Intent Understanding**: Natural language → semantic understanding
3. **Adaptive Planning**: Task graphs that evolve based on build feedback
4. **Agent Coordination**: Orchestrate multiple specialized agents
5. **Code Generation**: Produce syntactically correct C#/XAML code
6. **Self-Correction**: AI learns from errors and adapts strategy

### AI-Primary Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  AI CONSTRUCTION ENGINE (Primary Brain)                     │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Blueprint Designer    → Adaptive architecture design    ││
│  │ Multi-Agent System    → Specialized code generation     ││
│  │ Planning Engine       → Task graph construction         ││
│  │ Retry Controller      → Error recovery strategy (1-9)   ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  RUNTIME SAFETY KERNEL (Enforcement Layer)                  │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Mutation Guard       → Validate before apply            ││
│  │ Snapshot Manager     → Restore points                   ││
│  │ Reset Governor       → Forced Amnesia/Rollback (10+)    ││
│  │ Operation Whitelist  → Only approved operations         ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## 2. AI Architecture Blueprint Model

### Blueprint Structure

```
AI ARCHITECTURE BLUEPRINT
├── Architecture Intent Model
│   ├── User Intent (semantic understanding)
│   ├── Implicit Requirements (AI-inferred)
│   └── Constraint Set (user + system constraints)
│
├── Component Graph
│   ├── UI Components (pages, dialogs, controls)
│   ├── Services (business logic, data access)
│   └── Models (entities, DTOs, view models)
│
├── Domain Model
├── Service Contracts
├── Navigation Graph
└── Cross-Cutting Concerns
```

### Adaptive Blueprint Evolution

The blueprint **evolves** during construction:

```
Initial Blueprint (v1)
       ↓
Build Attempt #1 → Errors detected
       ↓
AI analyzes errors, adapts blueprint
       ↓
Revised Blueprint (v2)
       ↓
Build Succeeds → Final Blueprint locked
```

---

## 3. Adaptive Planning Layer

### Task Graph Structure

```text
Task {
  id: "setup-auth",
  type: "infrastructure",
  description: "Configure Windows Authentication",
  dependencies: ["init-project"],
  files_to_create: ["Models/User.cs", "Services/AuthService.cs"],
  validation_strategy: "compile-check"
}
```

### DAG Execution Model (IMPORTANT - Fixes Contradiction 6)

> **The DAG shows PLANNING dependencies, NOT execution parallelism.**
>
> - The AI Planner may identify tasks that are theoretically parallelizable
> - BUT the Runtime Safety Kernel executes them SEQUENTIALLY
> - This ensures deterministic state and safe rollback
> - One task at a time via `BuilderContext.CurrentTaskId`

```text
init-project [0]
    ↓
setup-database [1]
    ↓
    ├─→ define-models [2] (PLANNED parallel)
    ├─→ setup-auth [2]    (PLANNED parallel)
    └─→ db-migrations [2] (PLANNED parallel)

EXECUTION IS SEQUENTIAL:
init-project → setup-database → define-models → setup-auth → db-migrations
```

---

## 4. Multi-Agent Specifications

### The Agent Stack

| Agent | Responsibility |
| ----- | -------------- |
| **Architect** | Define overall app structure |
| **Schema** | Generate database models and migrations |
| **Frontend** | Generate UI components and pages |
| **Backend** | Generate API routes and services |
| **Integration** | Wire dependencies together |
| **Fix** | Detect and repair build failures |

### Agent Output Contracts

Each agent produces structured JSON output that the Orchestrator validates.

---

## 5. Agent Execution Contracts

### Patch Definition Contract

```json
{
  "type": "object",
  "properties": {
    "filePatches": {
      "array": {
        "items": {
          "type": "object",
          "properties": {
            "path": { "type": "string" },
            "changes": {
              "type": "array",
              "items": {
                "type": "object",
                "required": ["action", "content"],
                "properties": {
                  "action": {
                    "enum": [
                      "ADD_CLASS", "ADD_METHOD", "ADD_PROPERTY", "ADD_FIELD",
                      "MODIFY_METHOD_BODY", "INSERT_USING", "REMOVE_MEMBER"
                    ]
                  },
                  "targetSymbol": { "type": "string" },
                  "content": { "type": "string" }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

---

## 6. Agent Orchestration Pattern

### Orchestration Logic (FIXED - No Internal Loops)

```python
# Conceptual Orchestration Logic
# IMPORTANT: Agents do NOT manage their own retries

async def orchestrate_generation(spec, task_graph):
    for task in task_graph.sequential_execution():  # SEQUENTIAL, not parallel
        context = await retrieval_service.get_context(task)

        # 1. Select Specialist Agent
        agent = agent_factory.get_agent(task.type)

        # 2. Generate Candidate Code (ONE ATTEMPT ONLY)
        candidate = await agent.generate(spec, context)

        # 3. Submit to Orchestrator for validation
        # Orchestrator manages all retries, not the agent
        result = await orchestrator.submit_candidate(candidate, task)

        # Orchestrator decides: commit, retry, or abort
        if result.status == "COMMITTED":
            continue
        elif result.status == "RETRY":
            # Orchestrator will invoke agent again
            continue
        elif result.status == "ABORT":
            break
```

---

## 7. Retry Ownership (CRITICAL - Fixes Contradiction 4)

> **INVARIANT**: The Orchestrator is the ONLY component that manages retry loops. Agents MUST NOT have internal retry loops.

### Agent Behavior Rules

| Rule | Description |
|------|-------------|
| **Single Attempt** | Agents attempt to fix ONCE and return |
| **No Internal Loops** | Agents MUST NOT contain `while attempts < X` loops |
| **Return Results** | Agents return success/failure to Orchestrator |
| **Orchestrator Decides** | Only Orchestrator decides if retry happens |

### Wrong Pattern (FORBIDDEN)

```python
# ❌ FORBIDDEN - Agent internal retry loop
async def fix_agent(error):
    attempts = 0
    while attempts < 3:  # ❌ NO INTERNAL LOOPS
        fix = generate_fix(error)
        if validate(fix):
            return fix
        attempts += 1
    return None
```

### Correct Pattern (REQUIRED)

```python
# ✅ CORRECT - Single attempt, Orchestrator manages retries
async def fix_agent(error):
    # ONE ATTEMPT ONLY
    fix = await generate_fix(error)
    return FixResult(
        candidate=fix,
        confidence=calculate_confidence(fix)
    )
    # Orchestrator decides if retry is needed
```

### Orchestrator Retry Flow

```
1. Agent generates candidate
2. Orchestrator validates candidate
3. If validation fails:
   a. Orchestrator logs failure to EventLog
   b. Orchestrator increments retry count
   c. Orchestrator decides retry strategy
   d. Orchestrator invokes agent again
4. If retry count >= 10:
   a. Orchestrator aborts
   b. Rolls back to PreMutationSnapshotId
```

### Retry Governance Contract (Infinite Silent Retry)

| Retry Range | Owner | Description |
|-------------|-------|-------------|
| 1-9 | AI Construction Engine | AI adapts strategy |
| 10+ | Runtime Safety Kernel | System Reset (Rollback + Amnesia + Retry) |

> **INVARIANT**: There is NO abort. The system NEVER stops on its own. Only user cancellation ends execution.

---

## 8. AI Engine Integration

### Separation of Concerns

| Component | Responsibility | Does NOT Do |
|-----------|---------------|-------------|
| **AI Engine** | Generate code patches (JSON) | ❌ Write files, Manage retries |
| **Orchestrator** | Manage state, retries, validation | ❌ Generate code |
| **Patch Engine** | Apply patches to workspace | ❌ Generate code, Manage retries |

### Operation Whitelist

Only whitelisted operations are permitted:

```csharp
private static readonly HashSet<string> AllowedOperations = new()
{
    "ADD_CLASS", "MODIFY_METHOD", "ADD_PROPERTY",
    "ADD_DEPENDENCY", "UPDATE_XAML", "DELETE_FILE"
};
```

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-21 | Removed internal retry loops from agents (Fixes Contradiction 4) |
| 2026-02-21 | Added sequential execution clarification for DAG (Fixes Contradiction 6) |
| 2026-02-21 | Added Retry Ownership invariant section |

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 7-layer overview, global invariants
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine, retry controller
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn indexing, symbol graph