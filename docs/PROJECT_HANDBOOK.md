# PROJECT HANDBOOK

> **The Developer's Guide to Structure, Contribution, and Deployment**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> _The AI Construction Engine is the Primary Brain. The Runtime Safety Kernel is the Enforcement Layer._

---

## Table of Contents

1. [Project Directory Structure](#1-project-directory-structure)
2. [Layer Architecture (Canonical Definition)](#2-layer-architecture-canonical-definition)
3. [Dependencies & Technology Stack](#3-dependencies--technology-stack)
4. [Development Setup](#4-development-setup)
5. [Contribution Guidelines](#5-contribution-guidelines)
6. [Deployment & Packaging](#6-deployment--packaging)
7. [Design Philosophy & UX Principles](#7-design-philosophy--ux-principles)

---

## 1. Project Directory Structure

### Top-Level Layout

The solution uses a clean separation between the **Builder** (the tool itself) and **User Workspaces** (where apps are generated).

```text
SYNC-AI-FULL-STACK-APP-BUILDER/
│
├── docs/                              # Documentation
│   ├── SYSTEM_ARCHITECTURE.md         # System architecture (CANONICAL)
│   ├── ORCHESTRATION_ENGINE.md        # Deterministic orchestrator
│   ├── CODE_INTELLIGENCE.md           # Roslyn, indexing, database
│   ├── PROJECT_HANDBOOK.md            # This file
│   ├── AI_RUNTIME_MODEL.md            # AI Construction Engine vs Runtime Safety Kernel
│   ├── AI_AGENTS_AND_PLANNING.md      # Multi-agent specifications
│   ├── AI_SERVICE_LAYER.md            # AI capabilities via z-ai-web-dev-sdk (NO API KEYS!)
│   ├── AI_MINI_SERVICE_IMPLEMENTATION.md  # Complete TypeScript implementation
│   ├── PLATFORM_REQUIREMENTS_ENGINE.md    # Zero-template approach - platform requirements
│   ├── BRANDING_INFERENCE_HEURISTICS.md   # Intelligent brand derivation from user intent
│   ├── EXECUTION_ENVIRONMENT.md       # Sandbox, MSBuild, filesystem isolation
│   ├── PREVIEW_SYSTEM.md              # Preview rendering, sandbox launch
│   ├── UI_IMPLEMENTATION.md           # WinUI 3 design philosophy, page specs
│   ├── USER_WORKFLOWS.md              # User experience workflows
│   ├── WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md  # Packaging pipeline
│   ├── AGENT_EXECUTION_CONTRACT.md    # Agent execution context, file access contracts
│   └── archive/                       # Archived specifications
│
├── src/                               # Source code
│   │
│   ├── SyncAIAppBuilder/              # Main WinUI 3 application (.NET 8)
│   │   ├── SyncAIAppBuilder.csproj    # WinUI 3 project file
│   │   ├── Program.cs                 # Entry point
│   │   │
│   │   ├── UI/                        # Layer 7: WinUI 3 (Thin XAML Layer)
│   │   │   ├── MainWindow.xaml
│   │   │   ├── Pages/
│   │   │   ├── Components/
│   │   │   └── Resources/
│   │   │
│   │   ├── Services/                  # Core Business Logic
│   │   │   │
│   │   │   ├── 🔴 Runtime Safety Kernel (Layer 6)
│   │   │   │   ├── Orchestration/
│   │   │   │   │   ├── BuilderReducer.cs
│   │   │   │   │   ├── TaskSchema.cs
│   │   │   │   │   ├── BuilderContext.cs
│   │   │   │   │   ├── RetryController.cs
│   │   │   │   │   └── IOrchestrator.cs
│   │   │   │
│   │   │   ├── 🟣 AI Construction Engine (Layer 6.5)
│   │   │   │   ├── Agents/
│   │   │   │   │   ├── ArchitectAgent.cs
│   │   │   │   │   ├── FrontendAgent.cs
│   │   │   │   │   ├── BackendAgent.cs
│   │   │   │   │   └── FixAgent.cs
│   │   │   │   └── Planning/
│   │   │   │       ├── BlueprintDesigner.cs
│   │   │   │       └── TaskGraphBuilder.cs
│   │   │   │
│   │   │   ├── 🟡 Code Intelligence (Layer 5)
│   │   │   │   ├── RoslynService.cs
│   │   │   │   ├── CodeIndexer.cs
│   │   │   │   └── SymbolGraphBuilder.cs
│   │   │   │
│   │   │   ├── 🟠 Patch Engine (Layer 3)
│   │   │   │   ├── PatchEngine.cs
│   │   │   │   └── ASTParser.cs
│   │   │   │
│   │   │   ├── 🟤 Packaging Engine (Layer 2.5)
│   │   │   │   ├── ManifestEngine.cs
│   │   │   │   └── CapabilityInference.cs
│   │   │   │
│   │   │   ├── 🔵 Execution Kernel (Layer 2)
│   │   │   │   ├── BuildService.cs
│   │   │   │   └── NuGetService.cs
│   │   │   │
│   │   │   └── 🟢 Filesystem Sandbox (Layer 1)
│   │   │       ├── SandboxManager.cs
│   │   │       └── SnapshotService.cs
│   │   │
│   │   ├── Models/
│   │   ├── ViewModels/
│   │   └── Utils/
│   │
│   └── SyncAIAppBuilder.Tests/
│
├── templates/
├── ai-prompts/
└── scripts/
```

---

## 2. Layer Architecture (Canonical Definition)

> **IMPORTANT**: This section aligns with `SYSTEM_ARCHITECTURE.md`. The layer definitions here are the SINGLE SOURCE OF TRUTH.

### The 8-Layer Architecture (Infrastructure-Up Model)

| Layer | Name | Responsibility | Directory |
|-------|------|----------------|-----------|
| **Layer 1** | Filesystem Sandbox + SQLite | Isolated storage, snapshots | `Services/🟢 Filesystem Sandbox/` |
| **Layer 2** | Execution Kernel | MSBuild, NuGet, process management | `Services/🔵 Execution Kernel/` |
| **Layer 2.5** | Packaging Engine | Manifest, capability inference, MSIX | `Services/🟤 Packaging Engine/` |
| **Layer 3** | Patch Engine | AST mutations, conflict detection | `Services/🟠 Patch Engine/` |
| **Layer 5** | Code Intelligence | Roslyn indexing, symbol graph | `Services/🟡 Code Intelligence/` |
| **Layer 6** | Runtime Safety Kernel | State machine, retry logic, enforcement | `Services/🔴 Runtime Safety Kernel/` |
| **Layer 6.5** | AI Construction Engine | Primary brain, code generation | `Services/🟣 AI Construction Engine/` |
| **Layer 6.6** | **AI Service Layer** | **z-ai-web-dev-sdk - NO API KEYS!** | `Assets/ai-service.exe` |
| **Layer 7** | User Interface | WinUI 3 shell | `UI/` |

> **Layer 6.6 (AI Service Layer)**: Provides all AI capabilities via z-ai-web-dev-sdk.
> The compiled `ai-service.exe` runs as a hidden background process on localhost:3001.
> **NO API KEYS REQUIRED** - SDK handles authentication automatically!

### Layer Communication Rules

```
Layer 7 (UI) ──────────────────→ Layer 6 (Orchestrator) ONLY
                                   │
                                   ↓
Layer 6.5 (AI Engine) ←──────── Layer 6 (Orchestrator)
                                   │
                                   ↓
Layer 5 (Code Intelligence) ←─── Layer 6 (Orchestrator)
                                   │
                                   ↓
Layer 3 (Patch Engine) ←──────── Layer 6 (Orchestrator)
                                   │
                                   ↓
Layer 2 (Build) ←─────────────── Layer 6 (Orchestrator)
                                   │
                                   ↓
Layer 1 (Filesystem) ←────────── Layer 6 (Orchestrator)
```

**Key Rule**: UI (Layer 7) ONLY communicates with Orchestrator (Layer 6). Never bypass the Orchestrator.

---

## 3. Dependencies & Technology Stack

### Base Tech Stack (Fixed Foundation)

> **These are the non-negotiable technologies that ALL generated apps use.**
>
> **This is what the "Hidden System Prompt" defines - the FRAMEWORK RULES.**

| Technology | Purpose | Why Fixed |
|------------|---------|-----------|
| **WinUI 3** | UI Framework | Modern Windows native UI |
| **C# 12** | Language | .NET 8 ecosystem |
| **XAML** | UI Markup | WinUI 3 standard |
| **.NET 8** | Runtime | Long-term support |
| **SQLite** | Local Database | Built into Windows |
| **MVVM** | Architecture | Proven pattern for XAML apps |
| **MSIX** | Packaging | Windows standard installer |

### Extended Capabilities (Unlimited)

> **The AI can add ANY additional capability based on user's custom idea.**

| Capability | Examples |
|------------|----------|
| **NuGet Packages** | CommunityToolkit, Newtonsoft.Json, SkiaSharp, etc. |
| **Windows APIs** | File system, Networking, Bluetooth, Media, etc. |
| **Cloud Services** | REST APIs, Authentication, Real-time sync |
| **Third-party Libraries** | Charts, PDF, Image processing, etc. |
| **Custom UI Designs** | Any layout, theme, animation |

### Platform & Runtime

| Component | Technology | Version |
|-----------|------------|---------|
| **Runtime** | .NET | 8.0 LTS |
| **Language** | C# | 12 |
| **UI Framework** | WinUI 3 (Windows App SDK) | 1.5+ |
| **Target OS** | Windows 10/11 | Build 19041+ |

### Code Intelligence

| Component | Technology |
|-----------|------------|
| **C# Analysis** | Microsoft.CodeAnalysis (Roslyn) 4.8+ |
| **AST Manipulation** | Roslyn SyntaxRewriter, SyntaxFactory |

### AI Capabilities (Layer 6.6)

| Component | Technology |
|-----------|------------|
| **AI SDK** | z-ai-web-dev-sdk (NO API KEYS!) |
| **Runtime** | Bun (compiled to standalone .exe) |
| **Capabilities** | LLM, Image Gen, TTS, ASR, VLM, Web Search |
| **Communication** | HTTP on localhost:3001 |

### Database & Persistence

| Component | Technology |
|-----------|------------|
| **Database** | SQLite 3.x |
| **ORM** | Dapper (micro-ORM) |

---

## 4. Development Setup

### Prerequisites

- **OS**: Windows 10 Build 22621+ or Windows 11
- **.NET SDK**: .NET 8.0.x or later
- **Visual Studio 2022**: With Windows Desktop Development workload

### Installation

```bash
git clone https://github.com/yourusername/SYNC-AI-FULL-STACK-APP-BUILDER.git
cd SYNC-AI-FULL-STACK-APP-BUILDER
dotnet restore
dotnet build
```

### 🔴 CRITICAL: Implementation Sequence

**DO NOT START WITH LAYER 1**. The correct order:

#### Phase 1A: Runtime Safety Kernel (MUST BE FIRST)
- `BuilderReducer.cs` - Deterministic state transitions
- `TaskSchema.cs` - Task types, validation strategies
- `BuilderContext.cs` - State container
- `RetryController.cs` - Retry budget & rules
- `IOrchestrator.cs` - Interface for all components

**Why First?**: Without deterministic orchestration, downstream components will produce nondeterministic mutations.

#### Phase 1B: Orchestrator Integration
- Update all downstream services to ask orchestrator permission
- All state transitions must emit events
- All mutations must be serialized

#### Phase 2: Orchestrator-Aware Layers
- Layer 5 (Code Intelligence) - Read-only, can run in parallel
- Layer 3 (Patch Engine) - Serialized through orchestrator
- Layer 6.5 (AI Agents) - Ask orchestrator before mutation

---

## 5. Contribution Guidelines

### Coding Standards

- **Async/Await**: Use async all the way down. Avoid `.Result` or `.Wait()`.
- **Nullability**: Enable `<Nullable>enable</Nullable>`
- **Layer Boundaries**: Never bypass the Orchestrator

### Branching Strategy

- **`main`**: Stable, production-ready code
- **`feature/*`**: Individual feature branches

---

## 6. Deployment & Packaging

### MSIX Packaging

The system automatically generates `Package.appxmanifest` with:
- Identity injection
- Capability inference (Roslyn-based)
- Visual elements

### Code Signing

**Development**: Visual Studio creates temporary certificate
**Production**: Sign with trusted certificate (Sectigo, DigiCert)

---

## 7. Design Philosophy & UX Principles

### The Central Principle

> **Hide complexity, show only results.**

The user should never see:
- Build errors
- Retry loops
- Stack traces
- Configuration files

The user should only see:
- Working applications
- Progress indicators
- Success confirmations

### User View vs Internal Reality

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER VIEW                                │
│   ┌─────────┐      ┌─────────┐      ┌─────────────────────────┐│
│   │ Prompt  │ ───► │ Building│ ───► │ Working App             ││
│   │         │      │ (30s)   │      │                         ││
│   └─────────┘      └─────────┘      └─────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      INTERNAL REALITY                           │
│   Orchestrator manages:                                         │
│   - State transitions (all logged)                              │
│   - Retry loops (infinite, continuous)                          │
│   - Snapshots (before every mutation)                           │
│   - Capability inference (proactive for Release)                │
│   - System resets (at cycle 10+ with forced amnesia)            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-24 | **Added "Base Tech Stack (Fixed Foundation)" section** - Defines non-negotiable technologies |
| 2026-02-24 | **Added "Extended Capabilities (Unlimited)" section** - AI can add any capability based on user's idea |
| 2026-02-23 | Updated docs tree with all 12 documentation files |
| 2026-02-23 | Added PLATFORM_REQUIREMENTS_ENGINE.md and BRANDING_INFERENCE_HEURISTICS.md to docs list |
| 2026-02-22 | Added Layer 6.6 (AI Service Layer) with z-ai-web-dev-sdk - NO API KEYS! |
| 2026-02-22 | Added AI capabilities section to technology stack |
| 2026-02-22 | Added AI_SERVICE_LAYER.md and AI_MINI_SERVICE_IMPLEMENTATION.md references |
| 2026-02-21 | Unified layer definitions with SYSTEM_ARCHITECTURE.md (Fixes Contradiction 2) |
| 2026-02-21 | Updated directory structure to use infrastructure-up layer model |