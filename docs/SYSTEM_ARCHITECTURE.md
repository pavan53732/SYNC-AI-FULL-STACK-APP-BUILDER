# SYSTEM ARCHITECTURE

> **The Authoritative Invariant Map: 8-Layer Architecture, Global Constraints, and Layer Boundaries**
>
> _This document defines WHAT layers exist, HOW they interact, and WHAT invariants govern the system. Detailed implementations are delegated to specialized specifications._

**Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) | **AI capabilities via user-configured OpenAI-compatible providers** |
| [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md) | **NEW: Complete AI mini service implementation** |
| [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) | **NEW: Zero-template approach - Platform requirements & asset generation** |
| [BRANDING_INFERENCE_HEURISTICS.md](./BRANDING_INFERENCE_HEURISTICS.md) | **NEW: Intelligent brand derivation from user intent** |
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
2. [The 8-Layer Architecture](#2-the-8-layer-architecture)
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
| **AI Reasoning** | **Local AI Mini Service (openai SDK) — User-configured providers** |
| **Build & Execution** | Local-only (no cloud dependency) |

### Core Capabilities

1. **Frontend (Native UI)**: WinUI 3, XAML, MVVM, Theming, Navigation
2. **Application Layer**: Services, Dependency Injection, Validation
3. **Data Layer**: SQLite, Repository Pattern, Schema Migrations
4. **Build System**: Hidden MSBuild, NuGet Restore, XAML Compilation
5. **Runtime**: Live Preview, Hot Reload, Full Compiled Launch
6. **Packaging & Permissions**: Automatic AppxManifest, Capability Inference, MSIX Bundle, Certificate Signing
7. **AI Capabilities**: LLM, Vision, Image Generation, Web Search — via user-configured OpenAI-compatible providers

---

## 2. The 8-Layer Architecture

> **AI-Primary Architecture:** The AI Construction Engine sits at the top, directing all construction. The Runtime Safety Kernel enforces deterministic guarantees. The AI Service Layer provides AI capabilities via user-configured OpenAI-compatible providers.

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
│  │ AI Service Client     → HTTP client to Layer 6.6        ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  Layer 6.6: AI Service Layer (NEW)                          │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Local HTTP Service    → localhost:3001                  ││
│  │ openai SDK            → User-configured providers       ││
│  │ LLM / Vision / Image  → All AI capabilities             ││
│  │ Search                → User-configured                  ││
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

### AI-Primary Control Hierarchy (Updated)

```
┌─────────────────────────────────────────────────────────────┐
│                 AI CONSTRUCTION ENGINE                       │
│                   (Primary Brain)                            │
│                                                              │
│   AI leads construction: proposes, designs, generates        │
│   Owns retry strategy for cycles 1-9                         │
│   Communicates with AI Service Layer (Layer 6.6)             │
└─────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            │                                   │
            │ HTTP (localhost:3001)             │ Proposes mutations
            ▼                                   ▼
┌───────────────────────────┐   ┌─────────────────────────────┐
│    AI SERVICE LAYER       │   │    RUNTIME SAFETY KERNEL    │
│    (Layer 6.6)            │   │    (Enforcement Layer)       │
│                           │   │                              │
│ openai SDK              │   │ Kernel enforces safety:      │
│ User-configured         │   │ validates, snapshots, resets │
│                           │   │ Owns system resets at 10+    │
│ LLM, Vision, Image Gen,   │   │                              │
│ Search                    │   │                              │
└───────────────────────────┘   └─────────────────────────────┘
```

**See:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) for complete details.
**See:** [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) for AI capabilities.

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
| **Layer 6.6** | **AI Service Layer - openai SDK, user-configured providers** | [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) |
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
| **User-Configured AI** | AI capabilities via user-configured OpenAI-compatible providers |

### 3.4 Packaging Invariants

| Invariant | Description |
|-----------|-------------|
| **Capability Inference Mandatory** | Capability scan MUST run before every build. |
| **Version Authority** | `BuilderContext.ProjectMetadata["AppVersion"]` is the single source of truth. |
| **Signing Mandatory** | All MSIX packages MUST be signed. |
| **Atomic Packaging** | Packaging is all-or-nothing. Any failure triggers rollback. |

### 3.5 AI Service Invariants

| Invariant | Description |
|-----------|-------------|
| **User-Configured Providers** | Users configure AI providers via Settings > AI Settings |
| **Local Service Only** | AI mini service runs on localhost:3001 only |
| **Automatic Startup** | Desktop app starts AI service if not running |
| **Health Monitoring** | Desktop app monitors AI service health |

### 3.X Global AI Configuration Invariant (NEW)

> INVARIANT: AI configuration is GLOBAL to the installation.
> It is NOT project-scoped.

• Stored encrypted at:
  %USERPROFILE%\.syncai\Config\ai.config.enc

• Encrypted using Windows DPAPI (CurrentUser scope).
• Loaded and validated at application startup.
• Blueprint design MUST NOT begin unless AIConfigState == VALIDATED.

The AI Mini Service does NOT persist configuration to disk.
All configuration is pushed at runtime via POST /api/config.

Changing AI configuration forces:
1. SYSTEM_RESET
2. Mini-service restart
3. Revalidation before resuming execution

### 3.Y AIConfigState Formal Definition (CENTRALIZED)

> **This enum MUST be defined in Layer 6 (Runtime Safety Kernel domain model).**
> All references to AIConfigState across documentation MUST reference this canonical definition.

```csharp
public enum AIConfigState
{
    /// <summary>
    /// No AI configuration has been provided yet.
    /// User has not configured any AI providers in Settings > AI Settings.
    /// </summary>
    NOT_CONFIGURED,
    
    /// <summary>
    /// Configuration has been provided but not yet validated.
    /// POST /api/config has been called with provider details.
    /// </summary>
    CONFIGURED,
    
    /// <summary>
    /// Configuration has been validated successfully.
    /// Test LLM call succeeded. Blueprint design is now permitted.
    /// </summary>
    VALIDATED,
    
    /// <summary>
    /// Configuration was provided but validation failed.
    /// Invalid API key, unreachable endpoint, or quota exceeded.
    /// </summary>
    INVALID,
    
    /// <summary>
    /// AI Mini Service is not running or not reachable.
    /// Service health check failed.
    /// </summary>
    SERVICE_UNAVAILABLE
}
```

**State Transition Rules:**

| From State | Trigger | To State |
|------------|---------|----------|
| NOT_CONFIGURED | User saves AI Settings | CONFIGURED |
| CONFIGURED | POST /api/config succeeds + test call passes | VALIDATED |
| CONFIGURED | POST /api/config fails | INVALID |
| CONFIGURED | Mini-service stops responding | SERVICE_UNAVAILABLE |
| VALIDATED | Mini-service stops responding | SERVICE_UNAVAILABLE |
| VALIDATED | User changes AI Settings | CONFIGURED |
| INVALID | User saves new AI Settings | CONFIGURED |
| SERVICE_UNAVAILABLE | Mini-service restarts + becomes healthy | CONFIGURED |

**Critical Invariant:** `BLUEPRINT_DESIGN` state transition is BLOCKED unless `AIConfigState == VALIDATED`.

---

### 3.Z Deterministic AI Parameter Lock

> **To ensure reproducible AI behavior, these parameters are LOCKED and CANNOT be changed by agents.**

| Parameter | Locked Value | Rationale |
|-----------|--------------|-----------|
| `temperature` | `0.0` | Deterministic output for reproducible builds |
| `top_p` | `1.0` | Use full probability distribution |
| `presence_penalty` | `0.0` | No repetition penalty for code generation |
| `frequency_penalty` | `0.0` | No frequency-based repetition penalty |

> **INVARIANT**: Agents CANNOT override these locked values. Any request passing different values MUST be rejected by the AI Mini Service.

---

### 3.W Encryption Specification (MANDATORY)

> **AI configuration MUST be encrypted at rest using Windows DPAPI.**

| Aspect | Specification |
|--------|---------------|
| **Encryption Algorithm** | Windows DPAPI (Data Protection API) |
| **Scope** | CurrentUser (only the same Windows user can decrypt) |
| **File Path** | `%USERPROFILE%\.syncai\Config\ai.config.enc` |
| **Format** | Encrypted binary blob (no plain JSON ever written to disk) |
| **Key Management** | Windows manages key lifecycle automatically |

**Encryption Flow:**

```
1. User enters API keys in Settings > AI Settings
2. Desktop app encrypts using DPAPI (CurrentUser scope)
3. Encrypted blob written to ai.config.enc
4. On startup: DPAPI decrypts in memory only
5. Decrypted config pushed to Mini Service via POST /api/config
6. In-memory config cleared on app shutdown
```


---

## 3.6 AI Capabilities Definition

### Goal

> **Sync AI builds ANY Windows native desktop application from natural language.**

### Base Technologies (Fixed Foundation)

These are the **non-negotiable** technologies that ALL generated apps use:

| Technology | Purpose | Why Fixed |
|------------|---------|-----------|
| **WinUI 3** | UI Framework | Modern Windows native UI |
| **C# 12** | Language | .NET 8 ecosystem |
| **XAML** | UI Markup | WinUI 3 standard |
| **.NET 8** | Runtime | Long-term support |
| **SQLite** | Local Database | Built into Windows |
| **MVVM** | Architecture | Proven pattern for XAML apps |
| **MSIX** | Packaging | Windows standard installer |

**This is what the "Hidden System Prompt" (Constraint Documents) defines.**

### Extended Capabilities (Unlimited - User's Custom Idea)

The AI can add ANY additional capability based on the user's idea:

| Capability | Examples |
|------------|----------|
| **NuGet Packages** | CommunityToolkit, Newtonsoft.Json, SkiaSharp, etc. |
| **Windows APIs** | File system, Networking, Bluetooth, Media, etc. |
| **Cloud Services** | REST APIs, Authentication, Real-time sync |
| **Third-party Libraries** | Charts, PDF, Image processing, etc. |
| **Custom UI Designs** | Any layout, theme, animation |

### What Sync AI Can Build

| Category | Example Apps |
|----------|--------------|
| ✅ Productivity | Notes, Tasks, Calendars, Time tracking |
| ✅ Business | CRM, Inventory, Invoicing, POS |
| ✅ Media | Players, Editors, Viewers, Converters |
| ✅ Utility | File managers, System tools, Launchers |
| ✅ Social | Chat clients, Feed readers, Community apps |
| ✅ Education | Learning apps, Quizzes, Flashcards |
| ✅ Health | Fitness tracking, Medical records, Diet apps |
| ✅ Finance | Budgeting, Expenses, Investment tracking |
| ✅ Creative | Drawing, Design tools, Music creation |
| ✅ Games | 2D games, Puzzles, Arcade |
| ✅ E-commerce | Shopping apps, Inventory, Order management |
| ✅ Communication | Email clients, Messaging, VoIP |
| ✅ Developer Tools | Code editors, DB managers, API testers |

### What Sync AI Does NOT Build

| Category | Reason |
|----------|--------|
| ❌ Web Apps | This is a Windows native builder |
| ❌ Mobile Apps (iOS/Android) | Windows desktop only |
| ❌ Console Apps | GUI apps only |
| ❌ Linux/macOS Apps | Windows only |
| ❌ Backend Services | Client apps only |

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  USER PROMPT: "Build me a fitness app with charts"          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Step 1: Hidden System Prompt (Constraint Documents)        │
│  ├── Use WinUI 3 for UI                                    │
│  ├── Use MVVM architecture                                 │
│  ├── Use SQLite for local database                         │
│  └── Follow Windows packaging rules                        │
│                                                             │
│  Step 2: AI Generation (User's Custom Idea)                │
│  ├── Views/FitnessPage.xaml (charts, progress cards)       │
│  ├── ViewModels/FitnessViewModel.cs (logic)                │
│  ├── Models/Workout.cs (data)                              │
│  ├── Services/FitnessService.cs (functionality)            │
│  └── NuGet: CommunityToolkit.WinUI.Controls (charts)       │
│                                                             │
│  RESULT: User's custom fitness app                         │
│  - Built on BASE TECH STACK                                │
│  - Extended with USER'S SPECIFIC NEEDS                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

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
- AI code generation (Layer 6.5)

**See:** [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) §6

#### Layer 4: Code Intelligence (Roslyn)

**Owns:**
- C# syntax tree parsing
- Symbol graph construction
- Impact analysis for mutations
- XAML binding index

**Does NOT Own:**
- Applying mutations (Layer 3)
- Task planning (Layer 6.5)

**See:** [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md)

#### Layer 5: AI Agent Layer (Merged into Layer 6.5)

**See:** [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md)

#### Layer 6: Runtime Safety Kernel

**Owns:**
- State machine (`BuilderState` enum)
- Task lifecycle management
- Error classification and retry decisions
- Thread coordination
- **AIConfigState** - Canonical ownership (see §3.Y)
  - Persisted in BuilderContext (in-memory only)
  - NOT persisted to disk
  - Part of event log (immutable events)
  - Transitions triggered by: User settings change, service health, validation results

**Does NOT Own:**
- Code generation (Layer 6.5)
- File mutations (Layer 3)
- UI rendering (Layer 7)

**See:** [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md)

#### Layer 6.5: AI Construction Engine

**Owns:**
- Intent parsing and spec generation
- Task graph (DAG) construction
- Multi-agent coordination for code generation
- Retry strategy (cycles 1-9)
- AI Service Client for Layer 6.6 communication

**Does NOT Own:**
- Applying generated code (Layer 3)
- Build execution (Layer 2)
- State management (Layer 6)
- AI model inference (Layer 6.6)

**See:** [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md)

#### Layer 6.6: AI Service Layer (NEW)

**Owns:**
- LLM (Chat Completions) for code generation
- Image Generation for visual assets
- Vision Language Model for UI analysis
- Web Search for documentation lookup
- All communication with user-configured OpenAI-compatible providers

**Does NOT Own:**
- Code generation logic (Layer 6.5)
- State management (Layer 6)
- File mutations (Layer 3)

**See:** [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) and [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md)

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
| 6 → 6.5 | Orchestrator → AI Engine | ✅ Yes | Task dispatch |
| 6.5 → 6.6 | AI Engine → AI Service | ✅ Yes | HTTP REST API |
| 6 → 3 | Orchestrator → Patch | ✅ Yes | Patch operations |
| 6 → 2 | Orchestrator → Build | ✅ Yes | Build requests |
| 6.5 → 4 | AI → Roslyn | ✅ Yes | Context queries |
| 3 → 4 | Patch → Roslyn | ✅ Yes | Syntax trees |
| 3 → 1 | Patch → Filesystem | ✅ Yes | File writes |
| 7 → 3 | UI → Patch | ❌ No | - |
| 7 → 2 | UI → Build | ❌ No | - |
| 6.6 → External | AI Service → User-configured providers | ✅ Yes | HTTPS |

**Rule:** UI (Layer 7) ONLY communicates with Orchestrator (Layer 6). All other communication must go through the Orchestrator.

**Rule:** AI Construction Engine (Layer 6.5) communicates with AI Service Layer (Layer 6.6) via HTTP to localhost:3001.

---

## 5. Control & Data Flow

### 5.1 High-Level Flow (Updated)

```
User Prompt
    ↓
Layer 7: UI captures input → submits GenerateCommand
    ↓
Layer 6: Orchestrator validates, locks workspace, transitions to AI_PLANNING
    ↓
Layer 6.5: Intent parsing → Spec → Task Graph (DAG)
    ↓
Layer 6: Orchestrator dispatches tasks sequentially
    ↓
Layer 6.5: AI generates patch (via Layer 6.6)
    ↓
Layer 6.6: AI Service processes LLM request (user-configured provider)
    ↓
Layer 4: Roslyn validates target existence
    ↓
Layer 3: Patch Engine applies AST mutation
    ↓
Layer 4: Incremental re-index
    ↓
Layer 2: Build Service compiles
    ↓
[If errors] → Layer 6.5: Fix Agent generates correction → Layer 6.6 → retry
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
| AI Code Generation | Stateless, independent HTTP calls to Layer 6.6 |
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
| 🟣 AI Worker Pool | Code generation (HTTP to Layer 6.6) | Max 2 concurrent |
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

### 9.4 AI Service Security (NEW)

| Aspect | Implementation |
|--------|---------------|
| **Binding** | localhost only (127.0.0.1) |
| **Port** | 3001 (configurable) |
| **Authentication** | Not required (local service) |
| **API Keys** | User-configured per model slot in Settings > AI Settings |

---

## 10. Deployment Model

### 10.1 Local-First Architecture (Updated)

| Component | Location | Cloud Required? |
|-----------|----------|-----------------|
| **AI Reasoning** | **Local AI Mini Service (openai SDK)** | **User-configured providers** |
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
4. **User-Configured AI** — AI capabilities via user-configured OpenAI-compatible providers

---

## 11. Implementation Roadmap

### Phase 0: AI Service Foundation (NEW - Weeks 0-1)
- Set up AI Mini Service (Bun + openai SDK)
- Implement all API endpoints (LLM, Image, Vision, Search)
- Create C# client for Layer 6.6 communication
- Test all AI capabilities

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
- Auto-Fix Strategies (Layer 6.5)

### Phase 5: Production (Weeks 13-15)
- Testing & Hardening
- Packaging Pipeline (Layer 2.5)
- Documentation

**Detailed Roadmap:** See [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) Appendix B

---

## Quick Reference: Where To Find Details

| Topic | Document | Section |
|-------|----------|---------|
| **AI Service Layer** | AI_SERVICE_LAYER.md | All |
| **AI Mini Service Code** | AI_MINI_SERVICE_IMPLEMENTATION.md | All |
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
| 2026-02-24 | **Added Section 3.6: AI Capabilities Definition** - Base Tech Stack, Extended Capabilities, What Sync AI Can/Cannot Build | Architecture Team |
| 2026-02-24 | **Removed Cost Control Layer** - simplified AI service | Architecture Team |
| 2026-02-24 | **Updated AI Service Invariants** | Architecture Team |
| 2026-02-23 | **BREAKING: Replaced z-ai-web-dev-sdk with openai SDK** - 3-slot user-configured providers | Architecture Team |
| 2026-02-23 | **Removed TTS/ASR features** - Simplified to LLM, Vision, Image Gen, Search | Architecture Team |
| 2026-02-22 | **Added Layer 6.6: AI Service Layer** | Architecture Team |
| 2026-02-22 | Added AI Service cross-references | Architecture Team |
| 2026-02-22 | Added AI Service cross-references | Architecture Team |
| 2026-02-20 | Restructured as authoritative invariant map; extracted details to specialized specs | Architecture Team |
