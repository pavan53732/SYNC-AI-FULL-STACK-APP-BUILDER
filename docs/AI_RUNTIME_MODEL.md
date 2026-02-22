# AI RUNTIME MODEL

> **The Architecture of AI-Primary Construction with Deterministic Safety**
>
> _Defines the relationship between the AI Construction Engine and Runtime Safety Kernel._

---

## Table of Contents

1. [Overview](#1-overview)
2. [AI Construction Engine](#2-ai-construction-engine)
3. [Runtime Safety Kernel](#3-runtime-safety-kernel)
4. [Mutation Execution Boundary](#4-mutation-execution-boundary)
5. [Retry Ownership](#5-retry-ownership)
6. [Cancellation Authority](#6-cancellation-authority)
7. [Snapshot Authority](#7-snapshot-authority)
8. [Control Flow Diagram](#8-control-flow-diagram)

---

## 1. Overview

Sync AI is a **Local AI Full-Stack Windows Native App Builder** that autonomously designs and constructs complete applications from natural language with deterministic runtime safety guarantees.

### The Two Pillars

```
┌─────────────────────────────────────────────────────────────┐
│                 AI CONSTRUCTION ENGINE                       │
│                     (Primary Brain)                          │
│                                                              │
│   • Understands user intent                                  │
│   • Designs architecture                                     │
│   • Generates code                                           │
│   • Plans execution strategy                                 │
│   • Owns retry strategy (cycles 1-9)                        │
│   • Adapts and learns                                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Proposes mutations
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                RUNTIME SAFETY KERNEL                         │
│                    (Enforcement Layer)                       │
│                                                              │
│   • Validates all mutations                                  │
│   • Enforces deterministic execution                         │
│   • Manages snapshots and rollback                           │
│   • Enforces state recovery (Rollbacks on stuck loops)      │
│   • Owns system resets                                       │
│   • Guarantees system integrity                              │
└─────────────────────────────────────────────────────────────┘
```

### Key Principle

> **AI leads, Kernel enforces.**
>
> The AI Construction Engine is the primary intelligence that designs and builds.
> The Runtime Safety Kernel ensures all operations are deterministic, safe, and recoverable.

---

## 1.1 Capability Inference Timing Matrix (Canonical)

> **INVARIANT**: This is the single canonical definition of capability inference timing. All other documents must reference this section.

### Two-Phase Capability Model

The system uses fundamentally different capability inference timing for Preview vs Packaging:

| Phase | Mode | Capability Inference Timing | Rationale |
|-------|------|----------------------------|-----------|
| **Preview (Debug)** | Reactive | After build (on failure only) | Fast iteration; only infer if build fails due to missing capability |
| **Packaging (Release)** | Proactive | Before build | Optimize for success; infer capabilities early to minimize retry cycles |

### Debug Preview Pipeline (Reactive Model)

```
1. PRE-BUILD FAST SCAN (Optional)
   └── Quick Roslyn scan for obvious capability-requiring namespaces
   └── If found AND missing from manifest → Inject immediately

2. BUILD (Debug)
   └── Generate binaries

3. ROSLYN REINDEX
   └── Update semantic model

4. BUILD FAILURE CHECK (Reactive Inference)
   └── IF build failed with capability-related error:
       ├── Run FULL Capability Inference scan
       ├── Inject missing capabilities to manifest
       └── Rebuild (continuous retry until success or user cancellation)

5. MANIFEST EVALUATION (Post-Build)
   └── IF manifest changed during build → Inject → Rebuild
   └── IF no change → Proceed

6. LAUNCH
   └── Execute in isolated environment
```

> **Key Difference**: Preview allows "build → detect → fix → rebuild" cycle because iteration speed matters more than perfection.

### Release Packaging Pipeline (Proactive Model)

```
1. CAPABILITY_SCAN (MANDATORY first step)
   └── Full semantic analysis BEFORE any build

2. MANIFEST_UPDATE
   └── Inject all detected capabilities

3. VERSION_SYNC
   └── Align version numbers

4. BUILD_RELEASE
   └── Build with complete manifest

5. PACKAGE_CREATE
   └── Generate MSIX

6. SIGN
   └── Apply code signature

7. VERIFY
   └── Validate signature integrity
```

> **INVARIANT**: For Packaging, capability inference MUST run BEFORE build. Missing capabilities cause build failures that require retry. Proactive inference minimizes these failures.

### Cross-Document References

- **PREVIEW_SYSTEM.md** — Implements Debug Preview Pipeline
- **ORCHESTRATION_ENGINE.md** — State machine references CAPABILITY_CHECK state
- **WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md** — Implements Release Packaging Pipeline

---

## 2. AI Construction Engine

### Role
**Primary Intelligence** — The brain of the system

### Responsibilities

| Function | Description |
|----------|-------------|
| **Intent Understanding** | Parses natural language and extracts requirements |
| **Architecture Design** | Creates adaptive execution plans |
| **Code Generation** | Produces C#, XAML, SQL through multi-agent coordination |
| **Strategy Selection** | Chooses approach based on context |
| **Retry Strategy** | Owns retry decisions (cycles 1-9) |
| **Adaptation** | Learns from errors and adjusts |

### AI Agent Stack

```
AI Construction Engine
    │
    ├── Architect Agent      → Designs structure
    ├── Schema Agent         → Generates data models
    ├── Frontend Agent       → Creates UI components
    ├── Backend Agent        → Implements services
    ├── Integration Agent    → Wires dependencies
    └── Fix Agent            → Repairs errors
```

### Flexibility Within Bounds

The AI Construction Engine has full creative freedom within these constraints:
- Target platform: WinUI 3 / .NET 8
- Database: SQLite
- Architecture: MVVM pattern
- All mutations must pass Kernel validation

### Hidden System Prompt (Constraint Documents)

> **The Hidden System Prompt is NOT about limiting user's ideas. It defines the FRAMEWORK RULES.**

The "Hidden System Prompt" is implemented as **Constraint Documents** that the AI reads:

| Constraint Document | What It Defines |
|---------------------|-----------------|
| `SYSTEM_ARCHITECTURE.md` | Base Tech Stack (WinUI 3, .NET 8, SQLite, MVVM, MSIX) |
| `ORCHESTRATION_ENGINE.md` | State machine rules, retry behavior |
| `AI_AGENTS_AND_PLANNING.md` | Agent output contracts, task types |
| `CODE_INTELLIGENCE.md` | Patch operations whitelist |
| `WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md` | Manifest rules, capability inference |

**What the Hidden System Prompt defines (FRAMEWORK RULES):**
- ✅ Always use WinUI 3 (not WPF, not ASP.NET)
- ✅ Always use MVVM pattern
- ✅ Always use SQLite for local database
- ✅ Always generate valid MSIX packages
- ✅ Always follow Windows packaging rules

**What the Hidden System Prompt does NOT define (USER'S IDEA):**
- ❌ What the app does (user's custom functionality)
- ❌ What the UI looks like (user's custom design)
- ❌ What features to include (user's custom requirements)
- ❌ What APIs to connect to (user's custom integrations)

### Base Project Template (Minimal Kernel Bootstrap)

> **The Base Project Template provides EMPTY project structure. AI fills it with user's custom idea.**

```
┌─────────────────────────────────────────────────────────────┐
│  BASE PROJECT TEMPLATE (Minimal Kernel Bootstrap)           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📄 ProjectName.csproj                                      │
│  └── Configuration ONLY (targets .NET 8, WinUI 3)           │
│      NO functionality - just project settings               │
│                                                             │
│  📄 App.xaml                                                │
│  └── EMPTY - AI generates user's custom app resources       │
│                                                             │
│  📄 App.xaml.cs                                             │
│  └── Minimal bootstrap code - AI extends                    │
│                                                             │
│  📄 MainWindow.xaml                                         │
│  └── EMPTY - AI generates user's custom UI                  │
│                                                             │
│  📄 Package.appxmanifest                                    │
│  └── Skeleton with placeholders - AI fills capabilities     │
│                                                             │
│  ════════════════════════════════════════════════════════   │
│  ALL FUNCTIONALITY IS GENERATED BY AI                       │
│  BASED ON USER'S CUSTOM IDEA                                │
│  ════════════════════════════════════════════════════════   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Why Base Project Template is needed:**
- ✅ Guarantees valid `.csproj` configuration
- ✅ Guarantees correct SDK wiring
- ✅ Guarantees project can be opened in Visual Studio
- ✅ Guarantees correct packaging scaffold
- ✅ Reduces failure rate for project creation

**What the template does NOT contain:**
- ❌ No pre-built features
- ❌ No pre-built UI components
- ❌ No pre-built business logic
- ❌ No limitations on user's custom idea

---

## 3. Runtime Safety Kernel

### Role
**Enforcement Layer** — Guarantees deterministic, safe execution

### Responsibilities

| Function | Description |
|----------|-------------|
| **Mutation Validation** | Verifies all patches before application |
| **Deterministic Execution** | Ensures reproducible results |
| **Snapshot Management** | Creates/restores file system states |
| **System Resets** | Rollbacks with forced amnesia at cycle 10+ |
| **Resource Enforcement** | Memory, disk, time limits |
| **Security Enforcement** | Sandbox boundaries, path validation |

### Kernel Components

```
Runtime Safety Kernel
    │
    ├── Orchestrator         → State machine enforcement
    ├── Patch Engine         → AST validation & application
    ├── Sandbox Manager      → Filesystem isolation
    ├── Snapshot System      → Version control & rollback
    └── Build Validator      → Compilation verification
```

### Invariants (Non-Negotiable)

These are the differentiation moat — they never change:

1. **AST-Only Mutation** — No raw file writes
2. **Snapshot Rollback** — Every mutation is reversible
3. **Continuous Resilience** — System resets context and rolls back on stuck loops, but never stops until user cancels
4. **Manifest Pre-Build Inference** — Capabilities known before release build
5. **Sandbox Enforcement** — No escape from workspace
6. **Certificate Validation** — All packages signed
7. **Zero Trust AI** — All output validated

---

## 4. Mutation Execution Boundary

### The Boundary Contract

```
AI Engine                    Runtime Kernel
    │                             │
    │  1. Propose Mutation        │
    │  ─────────────────────────> │
    │                             │
    │  2. Validate                │
    │  <───────────────────────── │
    │     (approve/reject)        │
    │                             │
    │  3. If approved:            │
    │     Create Snapshot         │
    │     Apply Mutation          │
    │     Validate Result         │
    │                             │
    │  4. Return Result           │
    │  <───────────────────────── │
    │     (success/failure)       │
```

### Boundary Rules

| Rule | Enforcement |
|------|-------------|
| AI proposes, Kernel disposes | All mutations pass through Kernel |
| No direct file access | AI never touches filesystem directly |
| No bypass | Even internal agents go through Kernel |
| Full audit trail | Every mutation logged |

---

## 5. Retry Ownership

### Division of Authority

The retry process is split between AI and Kernel:

```
┌─────────────────────────────────────────────────────────────┐
│                    RETRY OWNERSHIP                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Cycles 1-9: AI CONSTRUCTION ENGINE                          │
│  ────────────────────────────────                            │
│  • AI decides retry strategy                                 │
│  • AI selects which agent handles fix                        │
│  • AI adapts approach based on error                         │
│  • Flexible, intelligent, adaptive                           │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Cycle 10+: RUNTIME SAFETY KERNEL                            │
│  ─────────────────────────────────                            │
│  • System Reset enforced                                     │
│  • Automatic rollback to pre-mutation snapshot               │
│  • AI Agent memory & context completely wiped                │
│  • Task restarted from scratch (Infinite continuous loop)    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Retry Table

| Range | Owner | Enforcement | Behavior |
|-------|-------|-------------|----------|
| 1-9 | AI Construction Engine | Strategy flexible | AI adapts, learns, retries |
| 10+ | Runtime Kernel | System Reset + Amnesia | Rollback, wipe memory, fresh approach |

### AI Retry Strategy (Cycles 1-9)

The AI Construction Engine may:
- Escalate to different agents (Fix → Integration → Architect)
- Change generation approach
- Simplify the target
- Request more context

### Kernel Enforcement (Cycle 10+)

The Runtime Kernel:
- Rolls back to `PreMutationSnapshotId`
- Clears all task-scoped memory (Forced AI Amnesia)
- Emits `SystemResetEvent`
- Forces AI to attempt an entirely new architecture path
- **Never stops** - always retries with fresh context

---

## 6. Cancellation Authority

### Who Can Stop Execution?

| Trigger | Authority | Action |
|---------|-----------|--------|
| User clicks cancel | User | Immediate cancellation, transition to CANCELLED |
| Hard loop detected (10+) | Kernel | System Reset (Rollback + Wipe Memory + Retry) |
| Safety violation | Kernel | System Reset (Rollback + Try new approach) |

> **INVARIANT**: There is NO terminal FAILED state. The only way to stop execution is user cancellation.

### Cancellation Sequence

```
1. User clicks "Cancel" button
2. Kernel receives UserCancelledEvent
3. Stop all AI operations immediately
4. Rollback to LastStableSnapshotHash
5. Clear task-scoped memory
6. Transition to CANCELLED state
7. User sees "Build cancelled"
```

---

## 7. Snapshot Authority

### Who Controls Snapshots?

| Operation | Authority | Reason |
|-----------|-----------|--------|
| Create snapshot | Kernel | Before every mutation |
| Restore snapshot | Kernel | On rollback/system reset |
| Delete snapshot | Kernel | On pruning/archival |
| List snapshots | UI (read-only) | User time-travel |

### Snapshot Lifecycle

```
AI Proposes Mutation
        │
        ▼
Kernel Creates Snapshot ──────────────────┐
        │                                  │
        ▼                                  │
Kernel Validates Mutation                  │
        │                                  │
        ├─── Valid ───> Apply Mutation     │
        │                  │               │
        │                  ▼               │
        │            Success?              │
        │              │                   │
        │    ─────────┴─────────           │
        │    │                │            │
        │   Yes              No            │
        │    │                │            │
        │    ▼                ▼            │
        │ Commit          System Reset ────┘
        │ Snapshot        (Rollback + Clear Memory)
        │                       │
        ▼                       ▼
   Continue               Retry with New Approach
```

### Snapshot Invariants

1. **Snapshot Before Mutation** — Non-negotiable
2. **Atomic Switch** — No partial states
3. **Hash Verification** — Integrity guaranteed
4. **Maximum 50 per project** — Automatic pruning

---

## 8. Control Flow Diagram

### Complete Flow (Infinite Silent Retry Model)

```
User Prompt
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                 AI CONSTRUCTION ENGINE                       │
│                                                              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │   Parse      │──▶│   Design     │──▶│   Plan       │    │
│  │   Intent     │   │ Architecture │   │ Execution    │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│                                              │               │
│  ┌──────────────┐   ┌──────────────┐        │               │
│  │   Generate   │◀──│   Select     │◀───────┘               │
│  │   Code       │   │   Agents     │                        │
│  └──────────────┘   └──────────────┘                        │
│         │                                                    │
└─────────┼────────────────────────────────────────────────────┘
          │ Proposes mutations
          ▼
┌─────────────────────────────────────────────────────────────┐
│                RUNTIME SAFETY KERNEL                         │
│                                                              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │   Validate   │──▶│   Snapshot   │──▶│   Apply      │    │
│  │   Mutation   │   │   Create     │   │   Patch      │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│         │                                    │               │
│         │ Rejected                            │               │
│         ▼                                    ▼               │
│  ┌──────────────┐                     ┌──────────────┐      │
│  │   Reject     │                     │   Validate   │      │
│  │   + Error    │                     │   Build      │      │
│  └──────────────┘                     └──────────────┘      │
│         │                                    │               │
│         │                                    │               │
└─────────┼────────────────────────────────────┼───────────────┘
          │                                    │
          │ Retry (1-9)                        │ Success/Fail
          ▼                                    ▼
    Return to AI                         Return Result
          │                                    │
          │                                    ▼
          │                           ┌──────────────┐
          │                           │   Success?   │
          │                           └──────────────┘
          │                                 │
          │                         ────────┴───────
          │                         │              │
          │                        Yes             No
          │                         │              │
          │                         ▼              ▼
          │                    Commit         Cycle 10+?
          │                    Snapshot            │
          │                         │         ──────┴─────
          │                         │         │           │
          │                         │        No          Yes
          │                         │         │           │
          │                         │         ▼           ▼
          │                         │    Return to    SYSTEM RESET
          │                         │       AI     + Rollback
          │                         │              + Clear Memory
          ▼                         ▼              │
    AI Adapts                  User Sees          ▼
    Strategy                  Working App    Retry with
                                             New Approach
                                                   │
                                                   └──► (Infinite Loop
                                                        until success or
                                                        user cancellation)

  ╔═══════════════════════════════════════════════════════════════╗
  ║  USER CANCELLATION (Only way to stop)                        ║
  ╠═══════════════════════════════════════════════════════════════╣
  ║  Any State ──→ User Clicks Cancel ──→ CANCELLED              ║
  ╚═══════════════════════════════════════════════════════════════╝
```

---

## Summary

### AI Construction Engine (Primary Brain)
- Understands, designs, generates, adapts
- Owns retry strategy (1-9)
- Creative, flexible, intelligent

### Runtime Safety Kernel (Enforcement Layer)
- Validates, enforces, guarantees
- Owns system resets (10+)
- Deterministic, resilient, protective

### The Contract
> AI proposes, Kernel validates.
> AI adapts, Kernel enforces.
> AI creates, Kernel guarantees.
> **System never stops - only user cancellation ends execution.**

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — Layer definitions
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine
- [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Agent coordination
- [AGENT_EXECUTION_CONTRACT.md](./AGENT_EXECUTION_CONTRACT.md) — Sandbox constraints
- [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — **AI capabilities via z-ai-web-dev-sdk (NO API KEYS!)**
- [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md) — Complete AI service implementation

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-24 | **Added "Hidden System Prompt (Constraint Documents)" section** - Explains framework rules vs user's idea |
| 2026-02-24 | **Added "Base Project Template (Minimal Kernel Bootstrap)" section** - Explains empty structure scaffolding |
| 2026-02-22 | Added AI Service Layer references (Layer 6.6) |
| 2026-02-22 | Added NO API KEYS requirement |
| 2026-02-21 | Converted to Infinite Silent Retry model |
| 2026-02-21 | Replaced "Hard Abort" with "System Reset + Forced Amnesia" |
| 2026-02-21 | Added Cancellation Authority section (only way to stop) |
| 2026-02-21 | Removed FAILED state from all diagrams |