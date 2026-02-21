# SYSTEM ARCHITECTURE

> **The Authoritative Invariant Map: 7-Layer Architecture, Global Constraints, and Layer Boundaries**
>
> _This document defines WHAT layers exist, HOW they interact, and WHAT invariants govern the system. Detailed implementations are delegated to specialized specifications._

**Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) | Sandbox, MSBuild, Job Objects, ACL Enforcement |
| [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) | State Machine, Task Lifecycle, Build System, Retry Logic |
| [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) | Intent Parsing, DAG Generation, Agent Contracts |
| [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) | Roslyn Indexing, Symbol Graph, Database Schema |
| [WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md](./WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md) | Manifest Engine, Capability Inference, MSIX Pipeline |
| [PREVIEW_SYSTEM.md](./PREVIEW_SYSTEM.md) | Preview Rendering, Sandbox Launch |
| [AGENT_EXECUTION_CONTRACT.md](./AGENT_EXECUTION_CONTRACT.md) | Agent Execution Specification |

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [The 7-Layer Architecture](#2-the-7-layer-architecture)
3. [Global Invariants](#3-global-invariants)
4. [Layer Boundaries & Responsibilities](#4-layer-boundaries--responsibilities)
5. [Control & Data Flow](#5-control--data-flow)
6. [Serialization Rules](#6-serialization-rules)
7. [Version Authority](#7-version-authority)
8. [Retry Governance](#8-retry-governance)
9. [Security Model](#9-security-model)
10. [Deployment Model](#10-deployment-model)
11. [Implementation Roadmap](#11-implementation-roadmap)

---

## 1. System Overview

### What is Sync AI?

> **Sync AI is a fully local AI full-stack Windows native app builder** that autonomously designs, generates, compiles, validates, fixes, and packages complete production-ready applications from natural language prompts.

**AI leads the construction. The Runtime Safety Kernel enforces deterministic guarantees.**

See [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) for the complete AI/Kernel relationship.

### Framework & Target

| Attribute | Value |
|-----------|-------|
| **Framework** | WinUI 3 (.NET 8) |
| **Target OS** | Windows 10 Build 22621+ (Windows 11 standard) |
| **Deployment** | MSIX packaging |
| **AI Reasoning** | Cloud API (required) |
| **Build & Execution** | Local-only (no cloud dependency) |

### Core Capabilities

1. **Frontend (Native UI)**: WinUI 3, XAML, MVVM, Theming, Navigation
2. **Application Layer**: Services, Dependency Injection, Validation
3. **Data Layer**: SQLite, Repository Pattern, Schema Migrations
4. **Build System**: Hidden MSBuild, NuGet Restore, XAML Compilation
5. **Runtime**: Live Preview, Hot Reload, Full Compiled Launch
6. **Packaging & Permissions**: Automatic AppxManifest, Capability Inference, MSIX Bundle, Certificate Signing

---

## 2. The 7-Layer Architecture

> **AI-Primary Architecture:** The AI Construction Engine sits at the top, directing all construction. The Runtime Safety Kernel enforces deterministic guarantees.

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 7: User Interface (WinUI 3 / XAML)                   │
│  ─ Prompt input, real-time preview, version timeline         │
├─────────────────────────────────────────────────────────────┤
│  Layer 6.5: AI Construction Engine (PRIMARY INTELLIGENCE)   │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Blueprint Designer    → Adaptive architecture design    ││
│  │ Multi-Agent System    → Specialized code generation     ││
│  │ Planning Engine       → Task graph construction         ││
│  │ Retry Controller      → Error recovery strategy (1-9)   ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  Layer 6: Runtime Safety Kernel (ENFORCEMENT LAYER)         │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Mutation Guard       → Validate before apply            ││
│  │ Snapshot Manager     → Restore points                   ││
│  │ Reset Governor       → Forced Amnesia/Rollback (10+)   ││
│  │ Operation Whitelist  → Only approved operations         ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  Layer 5: Code Intelligence (Roslyn)                         │
│  ─ AST parsing, symbol indexing, impact analysis             │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: Patch Engine                                       │
│  ─ Transactional code mutations, conflict detection          │
├─────────────────────────────────────────────────────────────┤
│  Layer 2.5: Packaging & Manifest Engine                      │
│  ─ Manifest generator, Capability inference, MSIX bundler    │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Execution Kernel                                   │
│  ─ In-process MSBuild, NuGet restore, app execution          │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: Filesystem Sandbox + SQLite Graph DB               │
│  ─ Isolated projects, snapshots, symbol/dependency storage   │
└─────────────────────────────────────────────────────────────┘
```

### AI-Primary Control Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                 AI CONSTRUCTION ENGINE                       │
│                   (Primary Brain)                            │
│                                                              │
│   AI leads construction: proposes, designs, generates        │
│   Owns retry strategy for cycles 1-9                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Proposes mutations
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                RUNTIME SAFETY KERNEL                         │
│                  (Enforcement Layer)                         │
│                                                              │
│   Kernel enforces safety: validates, snapshots, resets       │
│   Owns system resets at cycle 10+                            │
└─────────────────────────────────────────────────────────────┘
```

**See:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) for complete details.

### Layer Ownership Map

| Layer | Primary Responsibility | Detailed Spec |
|-------|------------------------|---------------|
| **Layer 1** | Filesystem isolation, SQLite storage, snapshots | [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) |
| **Layer 2** | MSBuild, NuGet, process management | [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) |
| **Layer 2.5** | Manifest, capabilities, signing | [WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md](./WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md) |
| **Layer 3** | AST patches, conflict detection | [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) |
| **Layer 4** | Roslyn indexing, symbol graph | [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) |
| **Layer 5** | (merged into Layer 6.5) | - |
| **Layer 6** | Runtime Safety Kernel - enforcement, abort authority | [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) |
| **Layer 6.5** | AI Construction Engine - intelligence, generation | [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) |
| **Layer 7** | WinUI 3 shell, user interaction | [UI_IMPLEMENTATION.md](./UI_IMPLEMENTATION.md) |

---

## 3. Global Invariants

> **These invariants are system-level truths that MUST be respected by all components. They are non-negotiable.**

### 3.1 Execution Invariants

| Invariant | Description |
|-----------|-------------|
| **One Active Task** | Only ONE mutation task can be active at a time. No parallel patching. |
| **No Raw File Writes** | All code mutations MUST go through the Roslyn-based Patch Engine. |
| **Snapshot Before Mutation** | A snapshot MUST exist before any patch is applied. |
| **Continuous Retry** | The system retries until success or user cancellation. No max retry limit. |
| **Deterministic Replay** | Event log enables perfect state reconstruction. |

### 3.2 Data Invariants

| Invariant | Description |
|-----------|-------------|
| **Single Source of Truth** | `BuilderContext` is the authoritative state. |
| **Immutable Events** | All events are records (immutable by default). |
| **Atomic Graph Updates** | Database updates are transactional. |
| **Hash-Based Change Detection** | File changes detected via SHA256 hash comparison. |

### 3.3 Security Invariants

| Invariant | Description |
|-----------|-------------|
| **Zero Trust AI** | Never assume AI output is safe. All patches validated. |
| **Path Sandbox** | All paths must be relative to project root. No `..` traversal. |
| **Banned Directories** | `.git`, `.vs`, `bin`, `obj` are off-limits to AI patches. |
| **Operation Whitelist** | Only whitelisted patch operations are permitted. |

### 3.4 Packaging Invariants

| Invariant | Description |
|-----------|-------------|
| **Capability Inference Mandatory** | Capability scan MUST run before every build. |
| **Version Authority** | `BuilderContext.ProjectMetadata["AppVersion"]` is the single source of truth. |
| **Signing Mandatory** | All MSIX packages MUST be signed. |
| **Atomic Packaging** | Packaging is all-or-nothing. Any failure triggers rollback. |

---

## 4. Layer Boundaries & Responsibilities

### 4.1 What Each Layer Does

#### Layer 1: Filesystem Sandbox + SQLite Graph DB

**Owns:**
- Workspace isolation and path validation
- Snapshot creation, compression, and restoration
- SQLite database for symbols, dependencies, errors

**Does NOT Own:**
- Build execution (Layer 2)
- Code indexing (Layer 4)
- Patch application (Layer 3)

**See:** [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) §2

#### Layer 2: Execution Kernel

**Owns:**
- MSBuild invocation via `Microsoft.Build` API
- NuGet restore via `NuGet.Commands` API
- Process management for preview execution

**Does NOT Own:**
- Task scheduling (Layer 6)
- File mutations (Layer 3)
- Error classification (Layer 6)

**See:** [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) §3

#### Layer 2.5: Packaging & Manifest Engine

**Owns:**
- `Package.appxmanifest` generation
- Capability inference from code analysis
- MSIX bundle creation
- Certificate management and signing

**Does NOT Own:**
- Build execution (Layer 2)
- Code analysis for capabilities (uses Layer 4 data)

**See:** [WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md](./WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md)

#### Layer 3: Patch Engine

**Owns:**
- AST-based code mutations via Roslyn
- Conflict detection (hash mismatch, signature mismatch)
- Transactional patch application

**Does NOT Own:**
- Code indexing (Layer 4)
- Build execution (Layer 2)
- AI code generation (Layer 5)

**See:** [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) §6

#### Layer 4: Code Intelligence (Roslyn)

**Owns:**
- C# syntax tree parsing
- Symbol graph construction
- Impact analysis for mutations
- XAML binding index

**Does NOT Own:**
- Applying mutations (Layer 3)
- Task planning (Layer 5)

**See:** [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md)

#### Layer 5: AI Agent Layer

**Owns:**
- Intent parsing and spec generation
- Task graph (DAG) construction
- Multi-agent coordination for code generation

**Does NOT Own:**
- Applying generated code (Layer 3)
- Build execution (Layer 2)
- State management (Layer 6)

**See:** [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md)

#### Layer 6: Orchestrator Engine

**Owns:**
- State machine (`BuilderState` enum)
- Task lifecycle management
- Error classification and retry decisions
- Thread coordination

**Does NOT Own:**
- Code generation (Layer 5)
- File mutations (Layer 3)
- UI rendering (Layer 7)

**See:** [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md)

#### Layer 7: User Interface

**Owns:**
- WinUI 3 shell and navigation
- User input handling
- Progress display
- Preview rendering

**Does NOT Own:**
- State management (Layer 6)
- Business logic (all lower layers)

**See:** [UI_IMPLEMENTATION.md](./UI_IMPLEMENTATION.md)

### 4.2 Cross-Layer Communication Rules

| From Layer | To Layer | Allowed? | Mechanism |
|------------|----------|----------|-----------|
| 7 → 6 | UI → Orchestrator | ✅ Yes | Command objects |
| 6 → 5 | Orchestrator → AI | ✅ Yes | Task dispatch |
| 6 → 3 | Orchestrator → Patch | ✅ Yes | Patch operations |
| 6 → 2 | Orchestrator → Build | ✅ Yes | Build requests |
| 5 → 4 | AI → Roslyn | ✅ Yes | Context queries |
| 3 → 4 | Patch → Roslyn | ✅ Yes | Syntax trees |
| 3 → 1 | Patch → Filesystem | ✅ Yes | File writes |
| 7 → 3 | UI → Patch | ❌ No | - |
| 7 → 2 | UI → Build | ❌ No | - |

**Rule:** UI (Layer 7) ONLY communicates with Orchestrator (Layer 6). All other communication must go through the Orchestrator.

---

## 5. Control & Data Flow

### 5.1 High-Level Flow

```
User Prompt
    ↓
Layer 7: UI captures input → submits GenerateCommand
    ↓
Layer 6: Orchestrator validates, locks workspace, transitions to AI_PLANNING
    ↓
Layer 5: Intent parsing → Spec → Task Graph (DAG)
    ↓
Layer 6: Orchestrator dispatches tasks sequentially
    ↓
Layer 5: AI generates patch
    ↓
Layer 4: Roslyn validates target existence
    ↓
Layer 3: Patch Engine applies AST mutation
    ↓
Layer 4: Incremental re-index
    ↓
Layer 2: Build Service compiles
    ↓
[If errors] → Layer 5: Fix Agent generates correction → retry
    ↓
Layer 2.5: Capability inference → Manifest update → Package → Sign
    ↓
Layer 6: Orchestrator creates snapshot, writes version, releases lock
    ↓
Layer 7: UI shows success, preview refreshes
```

### 5.2 State Machine Overview

```
IDLE → AI_PLANNING → SPEC_PARSED → TASK_GRAPH_READY
    → TASK_EXECUTING → VALIDATING → [RETRYING ↔ TASK_EXECUTING]
    → COMPLETED → IDLE
```

**Detailed State Definitions:** See [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) §3

---

## 6. Serialization Rules

### 6.1 Parallel Operations (✅ Safe)

| Operation | Reasoning |
|-----------|-----------|
| Planning Layer | No shared state, read-only analysis |
| AI Code Generation | Stateless, independent API calls |
| Retrieval & Indexing | Read operations on immutable snapshots |

### 6.2 Serialized Operations (🔒 Must Be Sequential)

| Operation | Reasoning |
|-----------|-----------|
| Patch Application | File system mutations must be atomic |
| Indexing | Symbol graph updates require exclusive lock |
| Restore/Rollback | Cannot overlap with other operations |
| Build | MSBuild requires project lock |
| Snapshot | Disk writes must be ordered |

### 6.3 The Golden Rule

> **"Reads can be parallel. Writes must be serial."**

### 6.4 Thread Types

| Thread | Purpose | Concurrency |
|--------|---------|-------------|
| 🟢 UI Thread | Rendering, user input | Single (main) |
| 🔵 Orchestrator Thread | Sequential execution | Single |
| 🟣 AI Worker Pool | Code generation | Max 2 concurrent |
| 🟡 Patch Worker | File mutations | Single-threaded |
| 🔴 Build Worker | MSBuild compilation | Single (per build) |
| ⚪ Background Maintenance | Cleanup, pruning | Single |

**Detailed Threading Model:** See [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) §8.2

---

## 7. Version Authority

### 7.1 Single Source of Truth

```
BuilderContext.ProjectMetadata["AppVersion"]
```

All version references MUST derive from this value:

- Manifest version
- Snapshot version
- Installer version

### 7.2 Version Increment Rules

| Trigger | Action | Example |
|---------|--------|---------|
| Code Patch | Increment Patch | `1.0.0` → `1.0.1` |
| Capability Change | Increment Minor | `1.0.1` → `1.1.0` |
| Schema Breaking | Increment Major | `1.1.0` → `2.0.0` |

**Rule:** If multiple triggers apply, the **highest order** increment wins.

**Detailed Version Policy:** See [WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md](./WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md) §4.4

---

## 8. Retry Governance

### 8.1 Retry Philosophy (Infinite Silent Retry)

> **AI owns the retry strategy. The Kernel enforces system resets.**

The AI Construction Engine has full flexibility to adapt, retry, and escalate during cycles 1-9. The Runtime Safety Kernel initiates a System Reset at cycle 10+ - rolling back, clearing memory, and retrying with a fresh approach.

### 8.2 Retry Ownership

| Range | Owner | Enforcement | Behavior |
|-------|-------|-------------|----------|
| 1-9 | AI Construction Engine | Strategy flexible | AI adapts, learns, retries |
| 10+ | Runtime Safety Kernel | System Reset + Amnesia | Rollback, wipe memory, fresh approach |

### 8.3 AI Retry Strategy (Cycles 1-9)

The AI Construction Engine may:
- **FIX_LEVEL (1-3)**: Fix Agent handles local token repairs
- **INTEGRATION_LEVEL (4-6)**: Integration Agent handles DI and wiring
- **ARCHITECTURE_LEVEL (7-9)**: Architect Agent re-evaluates the plan

AI selects which agent handles the fix and adapts approach based on errors.

### 8.4 Kernel Enforcement (Cycle 10+)

The Runtime Safety Kernel initiates a SYSTEM RESET:
- Rolls back to `PreMutationSnapshotId`
- Clears all task-scoped memory (Forced AI Amnesia)
- Emits `SystemResetEvent`
- Forces AI to attempt an entirely new architecture path

### 8.5 Stopping Conditions (User Cancellation Only)

The system ONLY stops when:

1. **Success** — Build passes, packaging completes
2. **User Cancellation** — Explicit cancel request

> **INVARIANT**: There is NO hard ceiling abort. The system retries infinitely until success or user cancellation.

**Detailed Retry Logic:** See [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) §7 and [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) §5

---

## 9. Security Model

### 9.1 AI Trust Boundary

All AI-generated content MUST pass these gates:

1. **JSON Schema Compliance** — Output matches `TaskGraph` or `Patch` schema
2. **Path Sandbox Enforcement** — Relative paths only, no traversal
3. **Symbol Consistency Check** — Target symbols exist in Roslyn index

### 9.2 Execution Isolation

| Isolation Method | Use Case |
|------------------|----------|
| Windows Sandbox | Preferred for preview execution |
| AppContainer | Fallback if Sandbox unavailable |
| Job Objects | Resource limits (1GB memory, 50% CPU) |

### 9.3 Banned Directories

AI patches cannot touch:

```
.git, .vs, bin, obj, .metadata.json
```

**Note:** `*.csproj` files are intentionally accessible for build operations.

**Detailed Security Model:** See [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) §5

---

## 10. Deployment Model

### 10.1 Local-First Architecture

| Component | Location | Cloud Required? |
|-----------|----------|-----------------|
| AI Reasoning | Cloud API | **Yes** |
| Build & Compilation | Local PC | No |
| NuGet Restore | Local PC | No (if cached) |
| App Execution | Local PC | No |
| Data Storage | Local SQLite | No |

### 10.2 Distribution

- **Format:** MSIX package
- **Signing:** Mandatory (auto-generated dev cert or user-provided)
- **Updates:** MSIX / AppInstaller

### 10.3 The "Local-Only" Covenant

1. **NO Web-Based Compilers** — All compilation is local MSBuild
2. **NO Browser-Based Runtime** — Strictly WinUI 3 Desktop
3. **NO Centralized Database** — All data stays in `%USERPROFILE%\.syncai\`

---

## 11. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)
- Orchestrator Engine (Layer 6)
- Filesystem Sandbox (Layer 1)
- SQLite Schema (Layer 1)

### Phase 2: Code Intelligence (Weeks 4-6)
- Roslyn Indexing Service (Layer 4)
- Symbol Graph (Layer 4)
- Impact Analysis (Layer 4)

### Phase 3: Mutation Safety (Weeks 7-9)
- Patch Engine (Layer 3)
- Conflict Detection (Layer 3)
- Rollback System (Layer 1)

### Phase 4: Execution (Weeks 10-12)
- Execution Kernel (Layer 2)
- Error Classification (Layer 6)
- Auto-Fix Strategies (Layer 5)

### Phase 5: Production (Weeks 13-15)
- Testing & Hardening
- Packaging Pipeline (Layer 2.5)
- Documentation

**Detailed Roadmap:** See [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) Appendix B

---

## Quick Reference: Where To Find Details

| Topic | Document | Section |
|-------|----------|---------|
| State Machine | ORCHESTRATION_ENGINE.md | §3 |
| Task Schema | ORCHESTRATION_ENGINE.md | §2 |
| Retry Logic | ORCHESTRATION_ENGINE.md | §7 |
| Thread Types | ORCHESTRATION_ENGINE.md | §8.2 |
| Boot Sequence | ORCHESTRATION_ENGINE.md | §8.5 |
| Crash Recovery | ORCHESTRATION_ENGINE.md | §8.7 |
| Database Schema | CODE_INTELLIGENCE.md | §5 |
| Roslyn Indexing | CODE_INTELLIGENCE.md | §3-4 |
| Patch Engine | CODE_INTELLIGENCE.md | §6 |
| XAML Bindings | CODE_INTELLIGENCE.md | §8 |
| Sandbox Implementation | EXECUTION_ENVIRONMENT.md | §2 |
| MSBuild Integration | EXECUTION_ENVIRONMENT.md | §3 |
| Job Objects | EXECUTION_ENVIRONMENT.md | §4 |
| ACL Enforcement | EXECUTION_ENVIRONMENT.md | §5 |
| Machine Variability | EXECUTION_ENVIRONMENT.md | §6 |
| Intent Parsing | AI_AGENTS_AND_PLANNING.md | §2 |
| DAG Planning | AI_AGENTS_AND_PLANNING.md | §3 |
| Agent Contracts | AI_AGENTS_AND_PLANNING.md | §4-5 |
| Manifest Engine | WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md | §2 |
| Capability Inference | WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md | §3 |
| Certificate Policy | WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md | §4.2 |
| Elevation Policy | WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md | §6 |

---

## Document Status

- **Status:** 🔴 CRITICAL FOUNDATION
- **Complexity:** High (distributed system concerns locally)
- **Risk:** CRITICAL if skipped (foundation of reliability)
- **Maintainer:** Architecture Team

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-02-20 | Restructured as authoritative invariant map; extracted details to specialized specs | Architecture Team |
</task_progress>
<task_progress>- [x] Analyze current SYSTEM_ARCHITECTURE.md structure
- [x] Read ORCHESTRATION_ENGINE.md
- [x] Read CODE_INTELLIGENCE.md
- [x] Read WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md
- [x] Create EXECUTION_ENVIRONMENT.md (extract sandbox, MSBuild, Job Objects, ACL, machine variability)
- [x] Create AI_AGENTS_AND_PLANNING.md (extract intent parsing, DAG generation, agent contracts)
- [x] Update ORCHESTRATION_ENGINE.md (add execution lifecycle, thread types, serialization rules)
- [x] Refactor SYSTEM_ARCHITECTURE.md to be the authoritative invariant map
- [ ] Verify cross-references and consistency</task_progress>
</write_to_file>