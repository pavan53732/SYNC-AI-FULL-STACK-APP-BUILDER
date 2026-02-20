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
6. [Abort Authority](#6-abort-authority)
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
│   • Enforces hard ceilings (max 10 cycles)                  │
│   • Owns abort authority                                     │
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
| **Abort Authority** | Hard stop at cycle 10+ |
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
3. **10 Retry Hard Ceiling** — System stops, not loops forever
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
│  • Hard abort enforced                                       │
│  • Automatic rollback to last stable snapshot               │
│  • User notification                                         │
│  • Non-negotiable, deterministic, final                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Retry Table

| Range | Owner | Enforcement | Behavior |
|-------|-------|-------------|----------|
| 1-9 | AI Construction Engine | Strategy flexible | AI adapts, learns, retries |
| 10+ | Runtime Kernel | Hard abort + rollback | System stops, user notified |

### AI Retry Strategy (Cycles 1-9)

The AI Construction Engine may:
- Escalate to different agents (Fix → Integration → Architect)
- Change generation approach
- Simplify the target
- Request more context

### Kernel Enforcement (Cycle 10+)

The Runtime Kernel:
- Stops all mutations immediately
- Rolls back to `LastStableSnapshotHash`
- Emits `BuildFailedEvent`
- Clears task-scoped memory
- Awaits user intervention

---

## 6. Abort Authority

### Who Can Abort?

| Trigger | Authority | Action |
|---------|-----------|--------|
| AI gives up (cycle 9) | AI Engine | Requests abort |
| Hard ceiling (cycle 10) | Kernel | Forced abort |
| User cancellation | User | Immediate abort |
| Safety violation | Kernel | Immediate abort |
| Resource exhaustion | Kernel | Immediate abort |

### Abort Sequence

```
1. Kernel receives abort trigger
2. Stop all AI operations
3. Rollback to LastStableSnapshotHash
4. Clear task-scoped memory
5. Emit BuildFailedEvent
6. Transition to FAILED state
7. Notify user with actionable message
```

---

## 7. Snapshot Authority

### Who Controls Snapshots?

| Operation | Authority | Reason |
|-----------|-----------|--------|
| Create snapshot | Kernel | Before every mutation |
| Restore snapshot | Kernel | On rollback/abort |
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
        │ Commit          Rollback ────────┘
        │ Snapshot        to Previous
        │
        ▼
   Continue
```

### Snapshot Invariants

1. **Snapshot Before Mutation** — Non-negotiable
2. **Atomic Switch** — No partial states
3. **Hash Verification** — Integrity guaranteed
4. **Maximum 50 per project** — Automatic pruning

---

## 8. Control Flow Diagram

### Complete Flow

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
          │                         │    Return to    ABORT
          │                         │       AI     + Rollback
          ▼                         ▼
    AI Adapts                  User Sees
    Strategy                  Working App
```

---

## Summary

### AI Construction Engine (Primary Brain)
- Understands, designs, generates, adapts
- Owns retry strategy (1-9)
- Creative, flexible, intelligent

### Runtime Safety Kernel (Enforcement Layer)
- Validates, enforces, guarantees
- Owns abort authority (10+)
- Deterministic, strict, protective

### The Contract
> AI proposes, Kernel validates.
> AI adapts, Kernel enforces.
> AI creates, Kernel guarantees.

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — Layer definitions
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine
- [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Agent coordination
- [AGENT_EXECUTION_CONTRACT.md](./AGENT_EXECUTION_CONTRACT.md) — Sandbox constraints