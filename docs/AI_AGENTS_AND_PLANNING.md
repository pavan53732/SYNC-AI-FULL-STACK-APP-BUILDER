# AI AGENTS AND PLANNING

> **The AI Construction Engine: Blueprint Design, Adaptive Planning & Multi-Agent Coordination**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> **Generation Specification Documents:**
>
> - [STRUCTURED_SPEC_FORMAT.md](./STRUCTURED_SPEC_FORMAT.md) — Canonical JSON schema for the spec output of the Architect Agent
> - [DATA_LAYER_GENERATION.md](./DATA_LAYER_GENERATION.md) — EF Core + SQLite code generation rules (Schema Agent)
> - [UI_GENERATION_RULES.md](./UI_GENERATION_RULES.md) — UI generation rules (framework-specific: WinUI/WPF/WinForms/WinRT)
> - [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — Multi-framework solution structure being built
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
│  │ AI Service Client     → HTTP client to Layer 6.6        ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  AI SERVICE LAYER (Layer 6.6) - User-Configured Providers   │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ openai SDK            → LLM / Vision / Image Gen         ││
│  │ localhost:3001        → Hidden background service        ││
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

> **CRITICAL**: All AI capabilities are provided via the **openai SDK** through the AI Service Layer (Layer 6.6).
> Users configure their AI providers (model name, base URL, API key) in **Settings > AI Settings**.

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

> **INVARIANT**: The Architect Agent's final output (Application Specification) MUST conform to the
> canonical JSON schema defined in [STRUCTURED_SPEC_FORMAT.md](./STRUCTURED_SPEC_FORMAT.md).
> No code generation agent may accept a spec that fails schema validation.
> The Runtime Safety Kernel validates the spec before dispatching any generation agents.

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

| Agent                    | Responsibility                                                                                       | AI Capability Used                            |
| ------------------------ | ---------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| **Architect**            | Define overall app structure and directories                                                         | LLM (Chat)                                    |
| **Planner**              | Converts blueprint into an ordered DAG Task Graph (Read-Only)                                        | LLM (Chat)                                    |
| **Schema**               | Generate database models and migrations                                                              | LLM (Chat)                                    |
| **Frontend**             | Generate UI components, pages, and **ALL VISUAL ASSETS**                                             | LLM (Chat) + Image Gen (icons, logos, splash) |
| **Backend**              | Generate API routes and services                                                                     | LLM (Chat)                                    |
| **Integration**          | Wire dependencies together (DI, Startup)                                                             | LLM (Chat)                                    |
| **Capability Inference** | Updates `Package.appxmanifest` with inferred capabilities (uses static Roslyn analysis from Layer 4) | **Static Analysis (no LLM)**                  |
| **Fix**                  | Detect and repair build failures                                                                     | LLM (Chat) + Web Search (docs)                |

> **All agents communicate with the AI Service Layer (Layer 6.6) via HTTP to localhost:3001**
>
> **CRITICAL: The Frontend Agent uses Branding Inference Heuristics to derive visual identity.**
>
> **NO TEMPLATES FOR VISUAL ASSETS - All icons, logos, and splash screens are generated from first principles using:**
>
> - [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) — Zero-template approach for visual assets
> - [BRANDING_INFERENCE_HEURISTICS.md](./BRANDING_INFERENCE_HEURISTICS.md) — Intelligent brand derivation from user intent
>
> **NOTE: Base Project Template (Minimal Kernel Bootstrap) IS USED for project structure:**
>
> - Valid `.csproj` configuration (targets .NET 8, WinUI 3)
> - Empty `App.xaml` and `App.xaml.cs`
> - Empty `MainWindow.xaml`
> - Skeleton `Package.appxmanifest`
>
> This template provides ONLY the empty project scaffolding. AI generates ALL functionality based on user's custom idea.
>
> See: [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) for complete API documentation

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
                      "ADD_CLASS",
                      "ADD_METHOD",
                      "ADD_PROPERTY",
                      "ADD_FIELD",
                      "MODIFY_METHOD_BODY",
                      "INSERT_USING",
                      "REMOVE_MEMBER"
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
        # Note: The system NEVER aborts. It relies on infinite staged retries or user cancellation.
```

---

## 7. Retry Ownership (CRITICAL - Fixes Contradiction 4)

> **INVARIANT**: The Orchestrator is the ONLY component that manages retry loops. Agents MUST NOT have internal retry loops.

### Agent Behavior Rules

| Rule                     | Description                                        |
| ------------------------ | -------------------------------------------------- |
| **Single Attempt**       | Agents attempt to fix ONCE and return              |
| **No Internal Loops**    | Agents MUST NOT contain `while attempts < X` loops |
| **Return Results**       | Agents return success/failure to Orchestrator      |
| **Orchestrator Decides** | Only Orchestrator decides if retry happens         |

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
   a. Orchestrator initiates SYSTEM_RESET
   b. Rolls back to PreMutationSnapshotId
   c. Clears all task-scoped memory (Forced Amnesia)
   d. Retries with entirely new approach
```

### Retry Governance Contract (Bounded Retry)

| Retry Range | Owner                  | Description                               |
| ----------- | ---------------------- | ----------------------------------------- |
| 1-9         | AI Construction Engine | AI adapts strategy                        |
| 10+         | Runtime Safety Kernel  | System Reset (Rollback + Amnesia + Retry) |

Retries 1–9 are owned by the AI Construction Engine.
System-level resets (10+) are owned by the Runtime Safety Kernel. See ORCHESTRATION_ENGINE.md.

> **INVARIANT**: There is NO abort. The system NEVER stops on its own. Only user cancellation ends execution.

---

## 8. AI Engine Integration

### Separation of Concerns

| Component        | Responsibility                    | Does NOT Do                      |
| ---------------- | --------------------------------- | -------------------------------- |
| **AI Engine**    | Generate code patches (JSON)      | ❌ Write files, Manage retries   |
| **Orchestrator** | Manage state, retries, validation | ❌ Generate code                 |
| **Patch Engine** | Apply patches to workspace        | ❌ Generate code, Manage retries |

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

| Date       | Change                                                                                                                           |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 2026-02-23 | **BREAKING: Replaced z-ai-web-dev-sdk with openai SDK** - user-configured providers                                              |
| 2026-02-24 | **Clarified "NO TEMPLATES" statement** - No templates for VISUAL ASSETS, but Base Project Template IS used for project structure |
| 2026-02-24 | Added explanation of Minimal Kernel Bootstrap (empty .csproj, App.xaml, MainWindow.xaml, Package.appxmanifest)                   |
| 2026-02-23 | Added references to Platform Requirements Engine and Branding Inference Heuristics                                               |
| 2026-02-23 | Updated Frontend Agent to include ALL VISUAL ASSETS generation                                                                   |
| 2026-02-23 | Added NO TEMPLATES note - all assets generated from first principles                                                             |
| 2026-02-22 | Added AI Service Layer (Layer 6.6) integration                                                                                   |
| 2026-02-22 | Added AI Service Client to agent architecture diagram                                                                            |
| 2026-02-22 | Added AI capability mapping to agent stack table                                                                                 |
| 2026-02-21 | Removed internal retry loops from agents (Fixes Contradiction 4)                                                                 |
| 2026-02-21 | Added sequential execution clarification for DAG (Fixes Contradiction 6)                                                         |
| 2026-02-21 | Added Retry Ownership invariant section                                                                                          |

---

## References

- [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — **AI capabilities via user-configured providers**
- [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md) — Complete TypeScript implementation
- [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) — **NEW: Zero-template approach - Platform requirements & asset generation**
- [BRANDING_INFERENCE_HEURISTICS.md](./BRANDING_INFERENCE_HEURISTICS.md) — **NEW: Intelligent brand derivation from user intent**
- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 8-layer overview, global invariants
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine, retry controller
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn indexing, symbol graph
