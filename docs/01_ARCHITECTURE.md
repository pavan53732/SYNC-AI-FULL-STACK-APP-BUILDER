# Architecture - System Design

> **Authority**: This document defines the system architecture, subsystem diagrams, and layer boundaries.
> **Status**: High-level system design reference

---

## System Overview

The SyncAI App Builder is a **Windows-native autonomous software construction environment** that generates complete Windows desktop applications from natural language prompts using multi-agent orchestration.

### High-Level Stack

```
┌────────────────────────────────────┐
│ WinUI 3 Desktop App (Control UI)  │
│ - Prompt Console                   │
│ - Project Explorer                 │
│ - Build Status Viewer              │
│ - Logs & Diagnostics               │
└────────────────────────────────────┘
                ↓
┌────────────────────────────────────┐
│ Deterministic Orchestrator        │
│ - State Machine                    │
│ - Task Graph Executor              │
│ - Retry Controller                 │
│ - Event Log                        │
└────────────────────────────────────┘
                ↓
┌────────────────────────────────────┐
│ Execution Kernel (Local Only)       │
│ - Roslyn Indexing Engine           │
│ - Structured Patch Engine          │
│ - MSBuild Runner                   │
│ - NuGet Restore Manager            │
│ - File Sandbox Manager             │
│ - Snapshot + Rollback System       │
└────────────────────────────────────┘
                ↓
┌────────────────────────────────────┐
│ SQLite                             │
│ - Project Graph                    │
│ - Symbol Index                     │
│ - Memory Layers                    │
│ - Error History                    │
└────────────────────────────────────┘
                ↓
      AI Engine (Built-in SDK Generation)
```

---

## The 7-Layer Multi-Agent Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    USER INTERFACE (Minimal)                  │
│              Prompt Input → Live Preview → Deploy            │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────▼────────────┐
        │   Intent & Spec Layer   │ ← Parses natural language → structured JSON
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────┐
        │   Planning Layer (DAG)  │ ← Creates ordered task graph
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────────────┐
        │  Code Intelligence Layer         │ ← Project index, graphs, embeddings
        │  (Indexed Project Graph)         │
        └────────────┬────────────────────┘
                     │
        ┌────────────▼────────────────────┐
        │  Multi-Agent Generation Layer   │ ← 6+ specialized agents
        │  (Orchestrated Agent Stack)     │
        └────────────┬────────────────────┘
                     │
        ┌────────────▼────────────────────┐
        │  Structured Patch Engine (AST)  │ ← Precise surgical code changes
        └────────────┬────────────────────┘
                     │
        ┌────────────▼──────────────────────────┐
        │  Validation & Silent Retry Loop        │ ← Build → Detect → Fix → Retry
        │  (Errors Hidden From User)            │
        └────────────────────┬─────────────────┘
                     │
        ┌────────────▼──────────────────────────┐
        │  State & Memory Layer                 │ ← SQLite-backed persistence
        │  (Project Context, Decisions)         │
        └────────────────────┬─────────────────┘
                     │
        ┌────────────▼──────────────────────────┐
        │  Execution Kernel (Construct Output)  │ ← Build → MSIX → Local Execution
        └──────────────────────────────────────┘
```

---

## Layer Descriptions

### Layer 1: User Interface
- Minimal, clean interface
- Prompt input, live preview, deploy
- WinUI 3 with Fluent Design

### Layer 2: Intent & Spec Layer
- NLP feature extraction
- Stack selection
- Constraint inference
- Dependency mapping

### Layer 3: Planning Layer (DAG)
- Topological task ordering
- Dependency resolution
- Parallelizable work identification

### Layer 4: Code Intelligence Layer
- Project indexing
- Symbol graph
- Dependency tracking
- Semantic embeddings

### Layer 5: Multi-Agent Generation Layer
- Architect Agent - Project structure
- Schema Agent - Database models
- Frontend Agent - XAML UI
- Backend Agent - APIs/services
- Integration Agent - Dependency wiring
- Fix Agent - Build error repair

### Layer 6: Structured Patch Engine
- AST-based transformations
- Minimal code changes
- Preserve formatting & comments

### Layer 7: Validation & Silent Retry
- Build → Detect → Fix → Retry
- All errors hidden from user

---

## Local vs. Cloud Separation

### Local Components (Zero Cloud Dependency)
- ✅ Build system (Embedded Microsoft.Build, NuGet)
- ✅ File system operations (snapshots, rollback)
- ✅ Preview rendering (XAML, code view)
- ✅ Application execution
- ✅ Database (SQLite, local storage)
- ✅ Roslyn code analysis (In-process)

### Cloud Components (Requires Internet)
- ☁️ AI code generation (z-ai-web-dev-sdk)
- ☁️ NuGet package downloads (first-time only)

---

## Project Structure

```
SyncAIAppBuilder/
├── UI/                        # WinUI 3: Prompt Console, Explorer, Logs, Status
├── Orchestrator/              # StateMachine.cs, TaskExecutor.cs, RetryController.cs
├── Kernel/                    # BuildRunner.cs, RoslynIndexer.cs, PatchEngine.cs, SandboxManager.cs
├── Memory/                    # DatabaseContext.cs, GraphRepository.cs (SQLite)
├── Services/                  # IntentService.cs, PlanningService.cs
├── Agents/                    # Specialized AI Agent logic
└── Infrastructure/           # AI Engine Wrapper (z-ai-web-dev-sdk)
```

---

## Related Documents

- [00_CANONICAL_AUTHORITY.md](./00_CANONICAL_AUTHORITY.md) - System invariants
- [02_ORCHESTRATION_AND_EXECUTION.md](./02_ORCHESTRATION_AND_EXECUTION.md) - State machine
- [03_BUILD_AND_MUTATION_KERNEL.md](./03_BUILD_AND_MUTATION_KERNEL.md) - Build kernel

---

**End of Architecture**
