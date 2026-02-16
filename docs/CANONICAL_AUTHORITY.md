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

### The 7-Layer Multi-Agent Architecture

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

## 🎯 DESIGN PHILOSOPHY

### The Central Principle

> **"Hide complexity, show only results."**

- **User Experience**: Simple and clean
- **System Complexity**: Extensive and sophisticated

### The 5-Stage Internal Pipeline (Hidden from User)

```
Stage 1: Parse & Understand
         Input: Natural language prompt
         Output: Structured specification JSON

Stage 2: Generate
         Input: Structured specification
         Output: Generated source files

Stage 3: Validate
         Input: Generated source files
         Output: Build report

Stage 4: Correct (if errors)
         Input: Build report with errors
         Output: Fixed source files OR fallback

Stage 5: Finalize
         Input: Validated source files
         Output: Ready-to-preview application
```

### Observable Behavioral Patterns

| Pattern | User Sees | System Does |
|---------|-----------|-------------|
| **Generation** | Spinner 30-60s | Multi-stage validation |
| **Errors** | Never shown | Auto-fix + retry |
| **Updates** | Surgical changes | Impact analysis |
| **Code** | Real, editable | Generated C#/XAML |
| **Dependencies** | Automatic | Tracked across modules |

### Error Handling Strategy

**User-Facing**: Never Show Errors
- ❌ No compilation errors
- ❌ No build failures
- ❌ No missing dependencies
- ❌ No type mismatches

**System-Level**: Extensive Error Handling
- ✅ Parse errors → Retry with fallback
- ✅ Generation errors → Classify + auto-fix
- ✅ Validation errors → Target fix + retry (5x)
- ✅ Unrecoverable → Graceful fallback

---

## 🔧 CORE SUBSYSTEMS (6 Required)

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
| ORCHESTRATOR_SPECIFICATION.md | Deterministic orchestrator | **FOUNDATION** - Must implement first |
| EXECUTION_ARCHITECTURE.md | 6 embedded subsystems | Implements execution model |
| USER_WORKFLOW.md | Observable user behavior | User perspective |
| DESIGN_PHILOSOPHY.md | UX principles | Hide complexity |
| DATABASE_SPECIFICATION.md | Data persistence | SQLite schema |
| API_CONTRACTS.md | API definitions | Integration points |

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

## 📝 DOCUMENT CONTROL

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 1.0 | 2026-02-16 | System | Initial canonical authority |

**This document is the single source of truth. All other specifications must be consistent with it.**
