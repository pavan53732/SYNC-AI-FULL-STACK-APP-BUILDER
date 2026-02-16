# CANONICAL AUTHORITY - Single Source of Truth

> **Status**: Single Source of Truth for all system definitions
> **Purpose**: Define system boundaries, core invariants, and canonical truths
> **Rule**: All other specifications must be consistent with this document. Conflicts indicate a bug in the other specification.

This document is the **single source of truth** for:
1. System boundaries (what IS and IS NOT part of the system)
2. Core invariants (truths that can never change)
3. What the system IS (definition)
4. What the system IS NOT (explicit exclusions)

---

## 🔴 CORE INVARIANTS (Immutable Truths)

These truths are absolute and can NEVER change:

1. **Orchestrator First**: The Deterministic Orchestrator MUST be implemented before any other component
2. **Local-First Build**: All build and execution happens on user's PC (zero cloud dependency for builds)
3. **AI Constraint**: AI Engine NEVER writes files, executes code, runs builds, or accesses filesystem directly
4. **One Mutation at a Time**: Only 1 mutation task at a time (no parallel patching)
5. **Snapshot Before Mutation**: Rollback capability must exist before every mutation
6. **Fail Silently**: Users never see errors; auto-fix happens internally
7. **Real Code Ownership**: Generated code is real C#/XAML, not proprietary format

---

## 📐 SYSTEM BOUNDARIES

### What This System IS

| Boundary | Definition |
|----------|------------|
| **Type** | Windows-native autonomous software construction environment |
| **Platform** | Windows 10/11 desktop (WinUI 3, .NET 8, MSIX) |
| **Output** | Complete, runnable Windows desktop applications |
| **Input** | Natural language prompts |
| **Intelligence** | AI-powered via z-ai-web-dev-sdk |
| **Build Model** | Embedded services (MSBuild, Roslyn, NuGet - all internal) |
| **Deployment** | Local execution, optional GitHub sync |

### What This System IS NOT

| Exclusion | Reason |
|-----------|--------|
| ❌ Web app builder | Platform is Windows desktop only |
| ❌ IDE replacement for manual development | Autonomous construction, not developer tool |
| ❌ Cloud build service | Local-first, zero cloud dependency for builds |
| ❌ Code templates | Generates real, editable code |
| ❌ Learning tool | Production-grade application generation |
| ❌ Visual Studio competitor | Hides all complexity, no IDE exposure |
| ❌ Cloud-hosted service | All execution local |
| ❌ Low-code platform | Full application generation |

---

## 🏗 ARCHITECTURE DEFINITION

### High-Level Architecture

```
┌────────────────────────────────────────────────────┐
│ WinUI 3 Desktop App (Control UI)                  │
│ - Prompt Console                                   │
│ - Project Explorer                                 │
│ - Build Status Viewer                              │
│ - Logs & Diagnostics                               │
└────────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────────┐
│ Deterministic Orchestrator                         │
│ - State Machine                                    │
│ - Task Graph Executor                              │
│ - Retry Controller                                 │
│ - Event Log                                        │
└────────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────────┐
│ Execution Kernel (Local Only)                      │
│ - Roslyn Indexing Engine                          │
│ - Structured Patch Engine                         │
│ - MSBuild Runner                                  │
│ - NuGet Restore Manager                           │
│ - File Sandbox Manager                            │
│ - Snapshot + Rollback System                       │
└────────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────────┐
│ SQLite                                             │
│ - Project Graph                                    │
│ - Symbol Index                                     │
│ - Memory Layers                                    │
│ - Error History                                    │
└────────────────────────────────────────────────────┘
                        ↓
      AI Engine (Built-in SDK Generation)
```

### Core Architectural Components

#### 1️⃣ Deterministic Orchestrator (Mandatory Foundation)
- **Purpose**: Prevent silent corruption through strict state control
- **Key Features**:
  - Pure reducer function state machine
  - Task graph executor with explicit dependencies
  - Built-in retry controller with budget tracking
  - Perfect replay from event logs

#### 2️⃣ Execution Kernel (6 Embedded Subsystems)
1. **Filesystem Sandbox** - Isolated project workspaces
2. **Roslyn Code Intelligence** - AST parsing and analysis
3. **Structured Patch Engine** - Precise surgical modifications
4. **MSBuild Runner** - Hidden compilation service
5. **NuGet Restore Manager** - Automatic dependency handling
6. **Snapshot System** - Mutation safety with rollback

#### 3️⃣ The 7-Layer Multi-Agent Architecture
1. **Intent & Specification Layer** - Prompt → Structured JSON
2. **Planning Layer** - Task graph generation (DAG)
3. **Code Intelligence Layer** - Project-wide semantic index
4. **Multi-Agent Generation Layer** - Specialized code generators
5. **Structured Patch Engine** - AST-based surgical modifications
6. **Validation & Silent Retry Loop** - Automatic error fixing
7. **State & Memory Layer** - Persistent architectural decisions

### Key Architectural Patterns
- **Event Sourcing**: All mutations via append-only event log
- **CQRS**: Separate command (mutation) and query paths
- **Structured Patches**: AST-based edits over full rewrites
- **Silent Retries**: Error fixing without user exposure
- **Embedded Services**: No external tool dependencies

> Source: Adapted from `docs/archive/ARCHITECTURE.md`

```
Layer 1: USER INTERFACE (Minimal)
         Prompt Input → Live Preview → Deploy

Layer 2: Intent & Spec Layer
         Parses natural language → structured JSON

Layer 3: Planning Layer (DAG)
         Creates ordered task graph

Layer 4: Code Intelligence Layer
         Project index, graphs, embeddings

Layer 5: Multi-Agent Generation Layer
         6+ specialized agents (orchestrated)

Layer 6: Structured Patch Engine (AST)
         Precise surgical code changes

Layer 7: Validation & Silent Retry Loop
         Build → Detect → Fix → Retry (hidden)

Layer 8: State & Memory Layer
         SQLite-backed persistence

Layer 9: Execution Kernel
         Build → MSIX → Local Execution
```

---

## ⚙️ TECHNOLOGY STACK (Canonical)

### Primary Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Language | C# | .NET 8.0+ |
| UI Framework | WinUI 3 | Windows App SDK |
| Database | SQLite | Microsoft.Data.Sqlite |
| Code Analysis | Roslyn | Microsoft.CodeAnalysis.* |
| Build System | MSBuild | Embedded API (no CLI) |
| AI Integration | z-ai-web-dev-sdk | Built-in |
| Logging | Serilog | Latest stable |
| DI Container | Microsoft.Extensions.DependencyInjection | Latest stable |

### UI Framework Details

- **WinUI 3** (Windows App SDK, .NET 8, MSIX deployment)
- **Fluent Design System**
- **Target**: Windows 10 Build 22621+ (Windows 11 standard)

### AI Engine Constraints

> **CRITICAL**: The AI Engine NEVER:
> - Writes files directly
> - Executes code
> - Runs builds
> - Accesses the filesystem

The AI Engine **ONLY** returns structured JSON generation output. All file operations are handled by the Patch Engine.

---

## 🎯 DESIGN PHILOSOPHY & UX PRINCIPLES

### Core Design Principle
> **"Hide complexity, show only results."**

**Implementation**:
- **5-Stage Internal Pipeline** (hidden from user):
  1. **Parse & Understand**: NLP → Structured JSON spec
  2. **Generate**: Multiple agents produce source files
  3. **Validate**: MSBuild compilation + static analysis
  4. **Correct**: Auto-fix errors + retry (max 5x)
  5. **Finalize**: Prepare for preview/deployment

**User Experience vs Internal Reality**:
```
USER VIEW                                INTERNAL REALITY
─────────────────────────────────────────────────────────
Prompt input                             NLP parsing + intent extraction
[Spinner...]                            Architecture design + generation
                                        Build + validation + auto-fix
✅ Working app preview                  Final validation + preview
```

### Key UX Principles

1. **Fail Silently, Succeed Loudly**
   - Errors classified and auto-fixed internally
   - Only success states shown to user

2. **One UI, Multiple Hidden Stages**
   - Single spinner for entire pipeline
   - Complex stages execute invisibly

3. **Intelligent Scoping**
   - Impact analysis before regeneration
   - Only modify affected modules

4. **Opinionated Defaults**
   - Constrained stack choices for reliability
   - Enforced best practices and conventions

5. **Real Code Ownership**
   - Generates actual C#/XAML (not proprietary format)
   - Export to GitHub/IDE without lock-in

> Source: Adapted from `docs/archive/DESIGN_PHILOSOPHY.md`

---

## 🛠 FEATURE DEFINITIONS

### Core Features (MVP)

| Feature | Description | Implementation Details |
|---------|-------------|-------------------------|
| **Intent Parsing** | NLP → Structured JSON | Feature extraction, conflict detection |
| **Task Planning** | DAG creation | Dependency resolution, sequencing |
| **Multi-Agent Gen** | 6 specialized agents | Architect, Schema, Frontend, Backend, Integration, Fix |
| **Structured Patches** | AST-based edits | Preserves formatting, surgical changes |
| **Silent Retry Loop** | Compile → Fix → Retry | Max 5 retries, hidden from user |
| **Live Preview** | Real-time UI updates | XAML hot-reload without full build |

### Advanced Features

| Feature | Status | Description |
|---------|--------|-------------|
| **Smart Components** | Planned | 50+ pre-built UI components |
| **Database Scaffold** | Planned | SQLite + EF Core migrations |
| **Testing Framework** | Planned | xUnit test generation |
| **Version Control** | Planned | Git integration + auto-commit |
| **Cloud Sync** | Future | Optional project backup |

**Observable System Behaviors**:
- Complex apps generate in 30-60s
- Updates are surgical (only affect relevant modules)
- Dependencies managed automatically
- Code quality consistent via validation
- Real code ownership with no lock-in

> Source: Consolidated from `docs/archive/FEATURES.md`

---

## 🔧 CORE SUBSYSTEMS & TECHNICAL FOUNDATIONS

### Embedded Services (Non-Negotiable)

1. **Filesystem Sandbox**
   - Isolated project workspaces
   - Versioned snapshots
   - Rollback capability

2. **Roslyn Code Intelligence** 
   - AST parsing
   - Semantic analysis
   - Impact assessment

3. **Structured Patch Engine**
   - Surgical code modifications
   - Merge-friendly diffs
   - Format preservation

4. **MSBuild Service**
   - Hidden compilation
   - Dependency resolution
   - Error reporting

5. **Project Graph (SQLite)**
   - Architecture decisions
   - Symbol index
   - Error history

6. **Process Sandbox**
   - Resource limits
   - Timeout enforcement
   - Isolation security

> Source: Cross-referenced from `ARCHITECTURE.md` and `DESIGN_PHILOSOPHY.md`

All subsystems are **embedded services**, NOT external CLI tools:

### 1. Filesystem Sandbox
- Isolated projects
- Snapshots for rollback
- Versioned builds

### 2. Execution Kernel
- Manages .NET SDK, MSBuild, NuGet
- All hidden in managed code

### 3. Roslyn Code Intelligence
- AST parsing
- Symbol graph
- Impact analysis

### 4. Transactional Patch Engine
- Safe mutations
- Conflict detection
- Rollback capability

### 5. SQLite Project Graph
- Persistent memory
- Symbols, dependencies, decisions, errors

### 6. Process Sandbox
- Isolated execution
- Resource limits
- Timeout management

---

## 📋 FEATURE DEFINITIONS

### Core Features (MVP)

| Feature | Description |
|---------|-------------|
| Intent Parsing | NLP → structured JSON specification |
| Task Planning | DAG creation with dependency resolution |
| Code Intelligence | File index, dependency graph, embeddings |
| Multi-Agent Generation | 6 specialized agents (Architect, Schema, Frontend, Backend, Integration, Fix) |
| AST Patch Engine | Surgical code modifications |
| Silent Retry Loop | Build → Detect → Fix → Retry (hidden) |
| Live Preview | Real-time XAML compilation |
| One-Click Build | Automated .exe generation |
| Project Memory | SQLite-backed persistence |

### The Agent Stack

1. **Architect Agent** - Defines project structure
2. **Schema Agent** - Generates database models
3. **Frontend Agent** - Generates XAML UI
4. **Backend Agent** - Generates APIs/services
5. **Integration Agent** - Wires dependencies
6. **Fix Agent** - Repairs build errors

---

### Intent & Specification Layer

Transforms unstructured user prompts into structured, machine-readable specifications:

**Input Example:**
```
"Build a CRM with authentication, role-based access, 
customer database, and analytics dashboard"
```

**Processing Pipeline:**
1. **NLP Feature Extraction** - Identify requested features
2. **Stack Selection** - Choose appropriate tech stack
3. **Constraint Inference** - Deduce implicit requirements (e.g., auth implies session management)
4. **Dependency Mapping** - Identify feature interdependencies
5. **Validation** - Check for conflicts or impossibilities

**Output (Structured JSON):**
```json
{
  "projectType": "windows-desktop-app",
  "projectName": "CRM System",
  "features": [
    {
      "id": "authentication",
      "type": "auth",
      "subType": "windows-auth",
      "dependencies": ["user-database"],
      "priority": 1
    }
  ],
  "stack": {
    "ui": "WinUI3",
    "backend": ".NET8",
    "database": "SQLite"
  }
}
```

---

### Code Intelligence Layer

Maintains semantic index for intelligent, impact-aware code generation:

**File Index Structure:**
```json
{
  "files": [{
    "path": "Models/Customer.cs",
    "type": "class",
    "dependencies": ["System.Data", "DbContext"],
    "exports": ["Customer", "CustomerValidator"],
    "imports": ["System", "System.ComponentModel.DataAnnotations"]
  }]
}
```

**Dependency Graph:**
```
Customer.cs → imports: DbContext, Validator → used by: CustomerService.cs
CustomerService.cs → imports: Customer.cs, ILogger → used by: CustomerController.cs
```

**Smart Retrieval Strategy:**
- Embed prompt to vector
- Search embeddings for top 5 relevant files (~2000 lines)
- Send ONLY relevant context to AI Engine
- Never dump entire project (solves context window limits)

---

### Data Flow Architecture

```
User Prompt
    ↓
Intent Parser → Structured Spec
    ↓
Planning Service → Task Graph (DAG)
    ↓
Code Intelligence (Indexing) → Project Context
    ↓
Multi-Agent Orchestrator
    ├─ Architect Agent
    ├─ Schema Agent
    ├─ Frontend Agent
    ├─ Backend Agent
    ├─ Integration Agent
    └─ Fix Agent (parallel execution where possible)
    ↓
Structured Patch Engine (Roslyn AST)
    ↓
Build System (MSBuild)
    ├─ [If errors] → Fix Agent → Retry
    └─ Success? → Show to user
    ↓
Live Preview / Deploy
```

---

### Observable System Behaviors (User Experience Truths)

These behaviors MUST be consistent and observable:

| Behavior | Expected | Why |
|----------|----------|-----|
| **Generation Time** | 30-60s cold, 5-15s refinement | Multi-stage pipeline running |
| **Error Visibility** | 0% to user | Auto-fix happens internally |
| **Update Scope** | Surgical changes only | Impact analysis before regeneration |
| **Code Ownership** | 100% real C#/XAML | Not proprietary format |
| **Dependencies** | Automatic tracking | System tracks across modules |

**User Experience Reality:**
- User sees: "Working app in 30-60 seconds"
- Internal reality: Parse → Generate → Validate → Fix → Retry → Success (hidden)
- Result: User never sees errors, only success

---

## 🚫 EXPLICIT SYSTEM EXCLUSIONS

These are explicitly OUT OF SCOPE:

| Exclusion | Rationale |
|-----------|------------|
| Web application generation | Windows desktop only |
| Manual code editing | Autonomous, not developer tool |
| Cloud compilation | Local-first architecture |
| Visual Studio integration | No IDE required |
| Cross-platform (Linux/Mac) | Windows-native focus |
| Real-time collaboration | Single-user autonomous operation |
| Plugin marketplace | Phase 2+ feature |
| Cloud storage | Local-first, privacy-focused |

---

## 📊 STATE MACHINE DEFINITION

### Orchestrator States (Canonical)

```
IDLE → SPEC_PARSED → TASK_GRAPH_READY → TASK_EXECUTING → VALIDATING → RETRYING → COMPLETED / FAILED
```

### State Transition Rules

| From State | To State | Trigger |
|------------|----------|---------|
| IDLE | SPEC_PARSED | Valid spec generated |
| SPEC_PARSED | TASK_GRAPH_READY | DAG created |
| TASK_GRAPH_READY | TASK_EXECUTING | Task dispatched |
| TASK_EXECUTING | VALIDATING | Task completed |
| VALIDATING | RETRYING | Errors detected |
| RETRYING | TASK_EXECUTING | Fix applied |
| VALIDATING | COMPLETED | No errors |
| ANY | FAILED | Max retries exceeded |

---

## 🔗 CROSS-REFERENCE INDEX

| Document | Topic | Relationship |
|----------|-------|--------------|
| [01_ARCHITECTURE.md](./01_ARCHITECTURE.md) | System architecture | High-level design |
| [02_ORCHESTRATION_AND_EXECUTION.md](./02_ORCHESTRATION_AND_EXECUTION.md) | Deterministic orchestrator | **FOUNDATION** - Must implement first |
| [03_BUILD_AND_MUTATION_KERNEL.md](./03_BUILD_AND_MUTATION_KERNEL.md) | Build & patch engine | Code mutations |
| [04_INDEXING_AND_MEMORY.md](./04_INDEXING_AND_MEMORY.md) | SQLite persistence | Data layer |
| [05_UI_SYSTEM.md](./05_UI_SYSTEM.md) | UI states & UX | User interface |
| [06_PROJECT_LAYOUT_AND_DEPLOYMENT.md](./06_PROJECT_LAYOUT_AND_DEPLOYMENT.md) | Folder structure | Deployment |
| [API_CONTRACTS.md](./API_CONTRACTS.md) | API definitions | Integration points |
| [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) | Onboarding | Getting started |

---

## ⚖️ CONFLICT RESOLUTION

### Rule: CANONICAL AUTHORITY Prevails

When any other specification document conflicts with this CANONICAL_AUTHORITY.md:

1. **This document wins** - It defines immutable truths
2. **The other document is wrong** - It must be updated
3. **Document the conflict** - Log as issue for resolution

### Invariant Violations = Critical Bugs

Any implementation that violates:
- AI Engine constraints
- Local-first build model
- One mutation at a time rule
- Snapshot-before-mutation rule

...is a **critical bug** and must be fixed immediately.

---

## 🛡️ SECURITY & COMPLIANCE

### Security Requirements

| Area | Requirement |
|------|-------------|
| **API Communication** | HTTPS/TLS for all AI Engine communication |
| **API Key Management** | Secure storage via environment variables or Windows Credential Manager |
| **Code Validation** | All generated code validated before compilation |
| **Input Sanitization** | User prompts sanitized before processing |
| **Rate Limiting** | API calls throttled to prevent abuse |
| **Code Signing** | Generated executables signed with Authenticode (when deployed) |
| **Privacy** | User prompts NOT stored; local-first data handling |

### Compliance Principles

- **Data Privacy**: No cloud storage of user data; all projects local
- **Code Ownership**: Users own 100% of generated code
- **Audit Trail**: Event log captures all operations for debugging
- **SBOM**: Software Bill of Materials generated for deployments

---

## 📈 PERFORMANCE REQUIREMENTS

### Timing Targets

| Operation | Target | Notes |
|-----------|--------|-------|
| Cold Generation | < 60 seconds | First-time app generation |
| Refinement | < 15 seconds | Incremental changes |
| Build | < 30 seconds | Standard project |
| Preview Refresh | < 2 seconds | XAML hot-reload |

### Resource Management

| Resource | Constraint |
|----------|------------|
| **Memory** | Monitor and disable parallel builds if < 4GB RAM |
| **Disk** | Warn when < 1GB free |
| **Process** | Timeout management on all operations |
| **Concurrency** | One mutation at a time (enforced) |

### Optimization Strategies

- **Semantic Caching**: Store embeddings, reuse for similar prompts
- **Incremental Builds**: Only recompile changed modules
- **Smart Retrieval**: Send ~2-5 relevant files, not entire project
- **Parallel Agents**: Execute independent agents concurrently

---

## 📝 DOCUMENT CONTROL

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 1.0 | 2026-02-16 | System | Initial canonical authority |
| 1.1 | 2026-02-17 | System | Merged content from ARCHITECTURE.md, DESIGN_PHILOSOPHY.md, TECHNOLOGY_STACK.md, FEATURES.md |

**This document is the single source of truth. All other specifications must be consistent with it.**

---

# 📋 DOCUMENTATION GOVERNANCE RULES

> **Authority**: These rules are binding on all documentation in this repository.

## Single Definition Rules

Every critical system element must exist in **exactly one** document:

| Element | Authority Document |
|----------|-------------------|
| **Orchestrator state machine** | [02_ORCHESTRATION_AND_EXECUTION.md](./02_ORCHESTRATION_AND_EXECUTION.md) |
| **Mutation rules** | [03_BUILD_AND_MUTATION_KERNEL.md](./03_BUILD_AND_MUTATION_KERNEL.md) |
| **Graph schema** | [04_INDEXING_AND_MEMORY.md](./04_INDEXING_AND_MEMORY.md) |
| **UI states** | [05_UI_SYSTEM.md](./05_UI_SYSTEM.md) |
| **Execution flow** | [02_ORCHESTRATION_AND_EXECUTION.md](./02_ORCHESTRATION_AND_EXECUTION.md) |

## Governance Rules

1. Every invariant must exist in exactly one document.
2. Orchestrator state machine defined only in 02_ORCHESTRATION_AND_EXECUTION.md.
3. Mutation rules defined only in 03_BUILD_AND_MUTATION_KERNEL.md.
4. Graph schema defined only in 04_INDEXING_AND_MEMORY.md.
5. UI states defined only in 05_UI_SYSTEM.md.
6. No duplication of execution flow across documents.
7. Subsystem docs may not redefine system invariants.
8. New specifications must reference existing authority documents.

## Document Hierarchy

```
CANONICAL_AUTHORITY.md       ← System Law (this file)
├── 01_ARCHITECTURE.md        ← Subsystem diagram
├── 02_ORCHESTRATION_AND_EXECUTION.md  ← State machine, execution
├── 03_BUILD_AND_MUTATION_KERNEL.md    ← Build, Roslyn, patches
├── 04_INDEXING_AND_MEMORY.md          ← SQLite, graph
├── 05_UI_SYSTEM.md                   ← UI states, UX
├── 06_PROJECT_LAYOUT_AND_DEPLOYMENT.md ← Folders, MSIX
├── 07_API_CONTRACTS.md               ← Interfaces, JSON
├── DEVELOPMENT_GUIDE.md               ← Onboarding
└── archive/                          ← Historical references
```
