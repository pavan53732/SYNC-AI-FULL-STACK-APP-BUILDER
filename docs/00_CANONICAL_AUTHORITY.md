# CANONICAL AUTHORITY - Single Source of Truth

> **Status**: Single Source of Truth for all system definitions
> **Purpose**: Define system boundaries, core invariants, and canonical truths
> **Rule**: All other specifications must be consistent with this document. Conflicts indicate a bug in the other specification.

## 📋 TABLE OF CONTENTS

- [CORE INVARIANTS](#core-invariants-immutable-truths)
- [SYSTEM BOUNDARIES](#system-boundaries)
- [ARCHITECTURE DEFINITION](#architecture-definition)
- [TECHNOLOGY STACK](#technology-stack-canonical)
- [CODE GENERATION RULES](#code-generation-rules)
- [CRITICAL STABILITY CONSTRAINTS](#critical-stability-constraints)
- [DESIGN PHILOSOPHY](#design-philosophy--ux-principles)
- [ERROR HANDLING STRATEGY](#error-handling-strategy)
- [FEATURE DEFINITIONS](#feature-definitions)
- [SUCCESS METRICS](#success-metrics)
- [SQLITE SCHEMA DEFINITIONS](#sqlite-schema-definitions)
- [ERROR CLASSIFIER IMPLEMENTATION](#error-classifier-implementation)
- [USER WORKFLOWS](#user-workflows)
- [KEY ARCHITECTURAL DECISIONS](#key-architectural-decisions)
- [BUILDER PROJECT STRUCTURE](#builder-project-structure)
- [CORE SUBSYSTEMS](#core-subsystems--technical-foundations)
- [CHANGE HISTORY](#change-history)

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

| Boundary         | Definition                                                  |
| ---------------- | ----------------------------------------------------------- |
| **Type**         | Windows-native autonomous software construction environment |
| **Platform**     | Windows 10/11 desktop (WinUI 3, .NET 8, MSIX)               |
| **Output**       | Complete, runnable Windows desktop applications             |
| **Input**        | Natural language prompts                                    |
| **Intelligence** | AI-powered via z-ai-web-dev-sdk                             |
| **Build Model**  | Embedded services (MSBuild, Roslyn, NuGet - all internal)   |
| **Deployment**   | Local execution, optional GitHub sync                       |

### What This System IS NOT

| Exclusion                                 | Reason                                        |
| ----------------------------------------- | --------------------------------------------- |
| ❌ Web app builder                        | Platform is Windows desktop only              |
| ❌ IDE replacement for manual development | Autonomous construction, not developer tool   |
| ❌ Cloud build service                    | Local-first, zero cloud dependency for builds |
| ❌ Code templates                         | Generates real, editable code                 |
| ❌ Learning tool                          | Production-grade application generation       |
| ❌ Visual Studio competitor               | Hides all complexity, no IDE exposure         |
| ❌ Cloud-hosted service                   | All execution local                           |
| ❌ Low-code platform                      | Full application generation                   |

---

## 🏗 ARCHITECTURE DEFINITION

### The "No IDE Required" Philosophy

The system is an **autonomous software construction environment**, not a developer utility:

| Principle                   | Description                                                                          |
| --------------------------- | ------------------------------------------------------------------------------------ |
| **Zero Tooling Exposure**   | Users never open Visual Studio, run `dotnet build`, or manage NuGet manually         |
| **Embedded Services**       | .NET SDK, MSBuild, Roslyn are **internal bundled services**, not external user tools |
| **Developer-Free Workflow** | Orchestrator and Patch Engine handle all file edits and debugging silently           |
| **The Goal**                | Self-contained constructor where the only external dependency is Cloud AI reasoning  |

### High-Level Architecture

```text
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

```text
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
        │  Code Intelligence Layer        │ ← Project index, graphs, embeddings
        └────────────┬────────────────────┘
                     │
        ┌────────────▼────────────────────┐
        │  Multi-Agent Generation Layer   │ ← 6+ specialized agents
        └────────────┬────────────────────┘
                     │
        ┌────────────▼────────────────────┐
        │  Structured Patch Engine (AST)  │ ← Precise surgical code changes
        └────────────┬────────────────────┘
                     │
        ┌────────────▼──────────────────────────┐
        │  Validation & Silent Retry Loop       │ ← Build → Detect → Fix → Retry
        └────────────┬──────────────────────────┘
                     │
        ┌────────────▼──────────────────────────┐
        │  State & Memory Layer                 │ ← SQLite-backed persistence
        └────────────┬──────────────────────────┘
                     │
        ┌────────────▼──────────────────────────┐
        │  Execution Kernel (Construct Output)  │ ← Build → MSIX → Local Execution
        └──────────────────────────────────────┘
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

### Planning Layer (Task Graph / DAG)

Convert feature spec into an ordered, executable task graph:

**Task Structure:**

```json
{
  "id": "setup-auth",
  "type": "infrastructure",
  "description": "Configure Windows Authentication",
  "dependencies": ["init-project"],
  "files_to_create": ["Models/User.cs", "Services/AuthService.cs"],
  "validation_strategy": "compile-check",
  "expected_artifacts": ["AuthService class", "User model", "Authentication middleware"]
}
```

**Example DAG (CRM App):**

```
init-project [0]
    ↓
setup-database [1]
    ├─→ define-models [2]     (customer, contact, interaction)
    ├─→ setup-auth [2]        (auth-service, user-model)
    └─→ db-migrations [2]     (create-tables, seed-data)

generate-ui [3]
    ├─→ login-page            (requires: setup-auth)
    ├─→ dashboard-page        (requires: setup-database)
    └─→ customer-table        (requires: define-models)

wire-api-routes [4]           (auth, CRUD, analytics, RBAC middleware)

validation & fix [5]          (compile → detect → auto-fix → retry)
```

**Key Insights**: Parallelizable work at same level, explicit dependencies prevent races, each task has validation criteria, individual rollback safe.

### Multi-Agent Generation Layer (6 Agents)

| Agent           | Responsibility           | Input                       | Output                                                             |
| --------------- | ------------------------ | --------------------------- | ------------------------------------------------------------------ |
| **Architect**   | Define project structure | Spec JSON                   | `project_structure` + `design_patterns` (MVVM, Repository, DI)     |
| **Schema**      | Generate DB models       | Entity definitions          | C# model classes with `[Table]`, `[Key]`, `[Required]` annotations |
| **Frontend**    | Generate UI              | Page + component spec       | XAML pages with data binding                                       |
| **Backend**     | Generate APIs/services   | Route definitions           | `[ApiController]` classes with auth                                |
| **Integration** | Wire dependencies        | Dependency map              | DI registration in `Program.cs`                                    |
| **Fix**         | Repair build errors      | Error code + context + file | Fix suggestion (type conversion, using, attribute)                 |

**Agent Orchestration Strategy:**

```
Phase 1: Architect defines structure
Phase 2: Schema + Backend agents run in PARALLEL
Phase 3: Frontend agent uses output from Phase 2
Phase 4: Integration agent wires everything
Phase 5: Compile → If errors → Fix agent → Retry
```

All agent communications handled through the `z-ai-web-dev-sdk`.

### Structured Patch Engine (AST-Based)

**Traditional Approach (❌ Bad):** Retrieve entire file → Send to AI "rewrite this" → Lose comments, formatting → Risk bugs

**AST-Based Approach (✅ Good):**

1. **Parse to AST** — `CSharpSyntaxTree.ParseText()`
2. **Identify Target Node** — Find specific property/class/method
3. **Generate Minimal Patch** — Only the change needed
4. **Apply via Roslyn** — `root.ReplaceNode(target, modified)`
5. **Preserve Everything** — Comments, formatting, developer notes intact

```csharp
public class StructuredPatchEngine
{
    public async Task<CodeFile> ApplyPatchAsync(CodeFile originalFile, PatchRequest patch)
    {
        var tree = CSharpSyntaxTree.ParseText(originalFile.Content);
        var root = (CompilationUnitSyntax)tree.GetRoot();
        var targetProperty = root.DescendantNodes()
            .OfType<PropertyDeclarationSyntax>()
            .First(p => p.Identifier.Text == patch.PropertyName);
        var attribute = SyntaxFactory.Attribute(SyntaxFactory.IdentifierName("Required"));
        var newProperty = targetProperty.AddAttributeLists(
            SyntaxFactory.AttributeList(SyntaxFactory.SingletonSeparatedList(attribute)));
        var newRoot = root.ReplaceNode(targetProperty, newProperty);
        return new CodeFile { Content = newRoot.ToFullString(), Path = originalFile.Path };
    }
}
```

**Benefits**: ✅ Minimal diffs ✅ Preserve formatting & comments ✅ No accidental deletions ✅ Merge-friendly ✅ Deterministic

### Memory & State Layer

**Purpose**: Preserve architectural decisions and context across iterations, preventing architectural drift.

**Project Memory (stack + architecture + naming):**

```json
{
  "project_id": "crm-app-001",
  "stack_decisions": { "ui_framework": "WinUI3", "database": "SQLite", "orm": "EF Core" },
  "architectural_decisions": {
    "pattern": "MVVM",
    "di": "Microsoft.Extensions.DI",
    "logging": "Serilog"
  },
  "naming_conventions": { "models": "PascalCase", "private_fields": "_camelCase" }
}
```

**Pattern Memory (file naming + routing + code style):**

```json
{
  "file_naming": {
    "models": "Models/{Entity}.cs",
    "services": "Services/{Entity}Service.cs",
    "views": "UI/Pages/{Page}.xaml"
  },
  "routing_style": {
    "api_base": "/api",
    "verb_placement": "method-based",
    "resource_naming": "plural"
  },
  "code_style": { "async_by_default": true, "nullable_enabled": true, "use_records": false }
}
```

**Error Memory (learn from past fixes):**

```json
{
  "error_signatures": [
    {
      "error_code": "CS1503",
      "pattern": "Cannot convert 'string' to 'int'",
      "fix": "Convert.ToInt32(value)",
      "occurrences": 12
    },
    {
      "error_code": "CS0103",
      "pattern": "'ILogger' does not exist",
      "fix": "Add using Microsoft.Extensions.Logging;",
      "occurrences": 8
    }
  ]
}
```

### Key Architectural Patterns

- **Event Sourcing**: All mutations via append-only event log
- **CQRS**: Separate command (mutation) and query paths
- **Structured Patches**: AST-based edits over full rewrites
- **Silent Retries**: Error fixing without user exposure
- **Embedded Services**: No external tool dependencies

> Source: Adapted from `docs/archive/ARCHITECTURE.md`

---

## ⚙️ TECHNOLOGY STACK (Canonical)

### Primary Stack

| Component      | Technology                               | Version                        |
| -------------- | ---------------------------------------- | ------------------------------ |
| Language       | C#                                       | .NET 8.0.100+ (LTS)            |
| UI Framework   | WinUI 3                                  | Windows App SDK 1.4.231219000+ |
| Database       | SQLite                                   | Microsoft.Data.Sqlite          |
| Code Analysis  | Roslyn                                   | Microsoft.CodeAnalysis.\*      |
| Build System   | MSBuild                                  | Embedded API (no CLI)          |
| AI Integration | z-ai-web-dev-sdk                         | Built-in                       |
| Logging        | Serilog                                  | Latest stable                  |
| DI Container   | Microsoft.Extensions.DependencyInjection | Latest stable                  |
| HTTP           | HttpClient                               | Built-in (async-first)         |
| Configuration  | Microsoft.Extensions.Configuration       | .json file-based               |
| Serialization  | System.Text.Json                         | Async-safe, UTF-8              |
| Testing        | xUnit                                    | Modern, async-friendly         |

### UI Framework Details

- **WinUI 3** (Windows App SDK, .NET 8, MSIX deployment)
- **Fluent Design System**
- **Target**: Windows 10 Build 22621+ (Windows 11 standard)
- **Threading**: Async/await patterns, DispatcherQueue for UI thread
- **Binding**: INotifyPropertyChanged, MVVM compatible
- **Runtime**: .NET Runtime (managed, GC)

### WinUI 3 NuGet Packages

| Package                                  | Purpose                   |
| ---------------------------------------- | ------------------------- |
| Microsoft.WindowsAppSDK                  | Core WinUI 3 framework    |
| Microsoft.Windows.AppNotifications       | System notifications      |
| Microsoft.Windows.AppWindowsAdapters     | Multi-window support      |
| CommunityToolkit.WinUI                   | XAML controls and helpers |
| CommunityToolkit.Mvvm                    | MVVM patterns and DI      |
| Microsoft.Extensions.DependencyInjection | Service container         |

### Build & Package Management

- **MSBuild**: Embedded API (no CLI exposed to user)
- **.NET CLI**: `dotnet` commands managed via Execution Kernel
- **NuGet API**: Programmatic package management (no manual install)

### Database Stack

| Database           | Use Case    | Notes                                          |
| ------------------ | ----------- | ---------------------------------------------- |
| **SQLite**         | MVP default | Zero-config, embedded, perfect for local-first |
| SQL Server Express | Alternative | For complex data scenarios                     |
| PostgreSQL         | Cloud-based | If cloud compilation added in future           |

> **Recommendation**: Start with SQLite for MVP. Expand options in Phase 2+.

### Version Control Integration

- **Git**: LibGit2Sharp for programmatic access
- **Semantic Versioning**: Applied to all generated apps
- **GitHub/GitLab API**: Optional cloud sync

### Installation Requirements

**Required for Operation** (self-managed by system):

- Windows 10 Build 22621+ (or Windows 11)
- .NET 8 SDK
- Admin access (for initial setup only)

> **Note**: Users do NOT need Visual Studio or manual SDK configuration.

**Optional Tools**:

- Docker Desktop (for containerized preview)
- GitHub CLI (for cloud sync)
- Azure CLI (for cloud deployment)
- Windows 11 SDK (for advanced platform APIs)

### AI Engine Constraints

> **CRITICAL**: The AI Engine NEVER:
>
> - Writes files directly
> - Executes code
> - Runs builds
> - Accesses the filesystem

The AI Engine **ONLY** returns structured JSON generation output. All file operations are handled by the Patch Engine.

### AI Prompting Strategy

- **System Prompts**: Define code generation rules and constraints
- **Few-shot Examples**: Provide patterns for common code structures
- **Chain-of-thought**: Use for complex logic generation
- **Structured Output**: Always request JSON for parsing

---

## 📐 CODE GENERATION RULES

> **MANDATORY**: These rules are enforced for all code generation:

| Technology        | Rule                                         | Rationale                                   |
| ----------------- | -------------------------------------------- | ------------------------------------------- |
| **Roslyn**        | **REQUIRED** for all mutations               | AST-based editing preserves formatting      |
| **StringBuilder** | Allowed for _new_ file templates only        | Efficient string construction for new files |
| **Regex**         | **STRICTLY FORBIDDEN** for code modification | Unreliable for AST-level changes            |

### Code Generation Constraints

```csharp
// ✅ CORRECT: Using Roslyn for modifications
var tree = CSharpSyntaxTree.ParseText(originalFile.Content);
var root = (CompilationUnitSyntax)tree.GetRoot();
var newProperty = targetProperty.AddAttributeLists(...);

// ❌ WRONG: Using Regex for code modification
var modified = Regex.Replace(code, @"public (\w+) (\w+)", "new $1 $2");
```

---

## ⚠️ CRITICAL STABILITY CONSTRAINTS

The kernel must detect and mitigate machine variability that cloud-based systems typically avoid:

### Environment Bootstrapping

- **SDK Detection**: Automatically detect missing .NET SDKs
- **Guided Installation**: Guide user through installation or install automatically
- **Workload Detection**: Detect missing .NET workloads (WinUI 3, XAML)
- **Version Mismatch Handling**: Handle version mismatches gracefully

### Resource Intelligence

- **Memory Monitoring**: Disable parallel builds if < 4GB RAM available
- **Disk Space Warning**: Warn when < 1GB free disk space
- **Process Limits**: Enforce timeout management on all operations

### External Interference Handling

- **Antivirus Detection**: Detect and handle Antivirus blocking builds
- **NuGet Cache Recovery**: Self-repair strategies for cache corruption
- **Build Environment Validation**: Verify build tools before operations

### Corruption Recovery

- **Snapshot System**: Automated partial project corruption detection
- **Rollback Capability**: Rollback via snapshot system on failure
- **State Recovery**: Restore to last known good state

---

## 🎯 DESIGN PHILOSOPHY & UX PRINCIPLES

### Core Design Principle

> **"Hide complexity, show only results."**
>
> Smooth UX does not mean the system is simple.
> It means the system is sophisticated AND the UI abstracts away the details.
> **The Goal**: A completely autonomous construction environment where the user never needs to touch an IDE, CLI, or compiler logs.

### 5-Stage Internal Pipeline (Detailed)

| Stage | Name                   | Processing Steps                                                                                                            |
| ----- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **1** | **Parse & Understand** | NLP intent extraction → Feature mapping → Feature decomposition → Conflict detection → Stack constraint analysis            |
| **2** | **Generate**           | Architecture design → Schema Agent → Frontend Agent + Backend Agent (parallel) → Integration Agent → Dependency scaffolding |
| **3** | **Validate**           | AST validation → Import verification → Dependency resolution → Type checking → MSBuild compilation                          |
| **4** | **Correct**            | Classify error → Match fix strategy (using/type/package/syntax/config) → Apply fix → Re-validate → Retry (max 5x)           |
| **5** | **Finalize**           | Code formatting → Checksum generation → Preview bundle creation → Deployment config → GitHub sync metadata                  |

### Why This Design Works

**Perceived Simplicity** (user's view):

```
Enter prompt → See working app → Edit → Done
```

**Actual Robustness** (system reality):

```
Multi-stage pipeline → Automatic error handling → Silent validation →
Self-correcting code → Graceful fallbacks → Perfect output
```

### User Experience vs Internal Reality

```
USER VIEW                                INTERNAL REALITY
─────────────────────────────────────────────────────────
Prompt input                             NLP parsing + intent extraction
                                         Feature mapping + decomposition
[Spinner...]                             Architecture design + generation
                                         Syntax validation + dependency resolution
                                         Build compilation + error detection
                                         Auto-fix execution + re-compilation
✅ Working app preview                   Preview rendering + deployment prep
```

### Key UX Principles

1. **Fail Silently, Succeed Loudly**
   - Internal errors? Classify and auto-fix
   - Still broken after 5 retries? Fallback to simpler generation
   - Missing SDK/Tooling? Auto-bootstrap or guide silently
   - Only success states shown to user
   - Never show compile logs or raw MSBuild output

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

### Observable Behavioral Patterns

| Pattern                                | Evidence                              | Internal Mechanism                               |
| -------------------------------------- | ------------------------------------- | ------------------------------------------------ |
| **Generation Takes Reasonable Time**   | 30-60s cold, 5-15s refine             | Multi-agent parallel execution + validation loop |
| **No Errors Ever Shown**               | User sees only ✅                     | Silent validation + auto-fix + retry             |
| **Updates Are Surgical**               | Changed code only, rest untouched     | AST-based patch engine (not full rewrites)       |
| **Code is Real and Editable**          | C#/XAML opens in Visual Studio        | No proprietary formats, no lock-in               |
| **Dependency Management is Automatic** | NuGet packages appear, SDK configures | Execution Kernel handles all tooling             |

### Implementation Checklist

**UI/UX Layer:**

- [ ] Show spinner during generation
- [ ] Display only success states
- [ ] Never expose raw errors
- [ ] Show progress indicators
- [ ] Render live preview on completion

**Internal Layers:**

- [ ] Structured logging for all operations
- [ ] Error classification engine
- [ ] Auto-fix strategy matcher
- [ ] Retry loop with budget tracking
- [ ] Fallback generation for unrecoverable errors

**Code Generation Pipeline:**

- [ ] Stage 1: Intent parsing with NLP
- [ ] Stage 2: Multi-agent generation
- [ ] Stage 3: AST + MSBuild validation
- [ ] Stage 4: Error correction loop
- [ ] Stage 5: Finalization + preview

**Validation Systems:**

- [ ] AST syntax validation
- [ ] Import/using verification
- [ ] Dependency resolution
- [ ] Type checking
- [ ] Full MSBuild compilation

### Psychology of Hidden Complexity

| Aspect                     | Effect                                   |
| -------------------------- | ---------------------------------------- |
| **Reduced Cognitive Load** | Users don't see 50 pieces of information |
| **Increased Confidence**   | No errors visible = system works         |
| **Speed Perception**       | Spinner is brief, feels instant          |
| **Trust Building**         | Consistently works, no surprises         |

### Comparison: Hidden vs Exposed Complexity

| Aspect               | Hidden Complexity (Our Approach) | Exposed Complexity (Traditional) |
| -------------------- | -------------------------------- | -------------------------------- |
| **UX**               | Simple prompt → result           | IDE + CLI + debugging            |
| **Error Visibility** | 0% (internal handling)           | 100% (user sees all)             |
| **Time to Result**   | 30-60 seconds                    | Hours to days                    |
| **Reliability**      | Self-correcting                  | User-dependent                   |
| **Satisfaction**     | High ("it just works")           | Variable (skill-dependent)       |

### Comparison: Lovable.dev vs Windows Native Builder

| Aspect             | Lovable.dev (Web)      | Windows Native Builder        |
| ------------------ | ---------------------- | ----------------------------- |
| **Generate**       | React/Next.js web apps | WinUI 3 native desktop apps   |
| **Validate**       | Browser-based preview  | Local MSBuild + XAML preview  |
| **Deploy**         | Cloud hosting          | Local MSIX / .exe             |
| **Philosophy**     | AI-first web builder   | AI-powered native constructor |
| **Error Handling** | Visible to user        | Completely hidden             |

> Source: Adapted from `docs/archive/DESIGN_PHILOSOPHY.md`

---

## 🚨 ERROR HANDLING STRATEGY

### User-Facing: Never Show Errors

Users NEVER see:

- Compilation errors
- Build failures
- Missing dependencies
- Type mismatches
- Syntax errors

### System-Level: Extensive Error Handling

#### 1. Parse Errors

- Retry with NLP fallback
- Use simpler interpretation
- Default features if failed

#### 2. Generation Errors

- Log error + context
- Classify error type
- Apply auto-fix
- Regenerate affected section
- Revalidate

#### 3. Validation Errors

- Classify (syntax, type, config, etc.)
- Identify root cause
- Apply targeted fix
- Recompile
- Retry (up to 5x)

#### 4. Deployment Errors

- Fallback to local preview
- Suggest manual fixes if necessary
- Offer support

#### 5. Unrecoverable Errors

- Show user: "Something went wrong"
- Suggest: "Try simpler prompt" or "Contact support"
- Preserve work (auto-save)

---

## 🛠 FEATURE DEFINITIONS

### Core Features (MVP) — Full Checklist

#### 1. Intent Parsing

- [x] Natural language → structured JSON spec
- [x] Feature extraction and mapping
- [x] Conflict detection and resolution
- [x] Stack constraint analysis

#### 2. Task Planning (DAG)

- [x] Dependency graph creation
- [x] Parallel task identification
- [x] Validation point insertion
- [x] Rollback safety per task

#### 3. Code Intelligence & Indexing

- [x] Full project AST indexing (Roslyn)
- [x] Symbol resolution and cross-references
- [x] Dependency graph maintenance
- [x] Semantic search via embeddings

#### 4. Multi-Agent Code Generation

- [x] **Architect Agent** — defines project structure
- [x] **Schema Agent** — generates database models
- [x] **Frontend Agent** — generates XAML UI
- [x] **Backend Agent** — generates API/services
- [x] **Integration Agent** — wires dependencies
- [x] **Fix Agent** — repairs build errors

All agents powered by `z-ai-web-dev-sdk`. Each agent produces structured patches, not full files.

#### 5. Structured Patch Engine (AST)

- [x] Roslyn-based AST parsing
- [x] Surgical node-level modifications
- [x] Comment and formatting preservation
- [x] Deterministic patch application

#### 6. Silent Validation & Retry Loop

- [x] MSBuild compilation
- [x] Error detection & classification
- [x] Automatic error fixing (syntax, type, using, package, config)
- [x] Transparent retries (max 5, hidden from user)
- [x] Final success notification only

**User sees**: [spinner] → ✅ Success (no intermediate errors)

#### 7. Project Memory

- [x] Stack decisions persistence
- [x] Naming convention tracking
- [x] Error solution caching
- [x] Session context preservation

#### 8. Live Preview

- [x] Compile XAML in-process
- [x] Display preview without full build
- [x] Interactive preview mode
- [x] Hot-reload on code changes

#### 9. One-Click Build & Deploy

- [x] Automated MSBuild compilation
- [x] .exe packaging
- [x] MSIX generation
- [x] Run from app directly

#### 10. Project Management

- [x] Create new projects from prompt
- [x] Project history and versioning
- [x] Export to standard formats
- [x] Snapshot system for safety
- [x] Recent project list

#### 11. Environment Bootstrapping & Self-Repair

- [x] .NET SDK detection and guided install
- [x] NuGet cache self-repair
- [x] Missing workload detection (WinUI 3, XAML)
- [x] Low-resource mitigation (RAM, disk)
- [x] Version mismatch handling

#### 12. Real Code Export & Portability

- [x] C# source code export (actual files)
- [x] XAML export (standard format)
- [x] ZIP download of full project
- [x] GitHub sync (push to repo)
- [x] Visual Studio compatibility (opens in VS)
- [x] Standalone execution (runs without builder)
- [x] Post-export development (continue in IDE)

### Phase 2: Advanced Features (Planned)

| #   | Feature                     | Description                  | Key Sub-Features                                                                                      |
| --- | --------------------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------- |
| 12  | **Smart Component Library** | 50+ pre-built UI components  | Forms, data display, navigation, dialogs, rich text, date/color pickers, marketplace search           |
| 13  | **Data & Database**         | Full database integration    | Schema generation, SQLite/EF Core, CRUD (Repository pattern), migrations, relationships, seed data    |
| 14  | **API Integration**         | REST API scaffolding         | HTTP client generation, auth helpers (JWT, OAuth, Windows Auth), Swagger/OpenAPI import               |
| 15  | **State Management**        | MVVM + reactive patterns     | DI auto-wiring, Observable properties, ICommand, Event aggregation, Rx.NET                            |
| 16  | **Testing Framework**       | Automated test generation    | xUnit, mocks (Moq), UI automation (Windows App Driver), coverage reporting                            |
| 17  | **Version Control**         | Full Git integration         | Init, auto-commit on generation, diff visualization, GitHub/GitLab, branch management                 |
| 18  | **Code Quality**            | Static analysis + formatting | SonarQube integration, code formatting, pattern enforcement, security scanning, duplication detection |

### Phase 3: Production Features (Future)

| #   | Feature                    | Description           | Key Sub-Features                                                                               |
| --- | -------------------------- | --------------------- | ---------------------------------------------------------------------------------------------- |
| 19  | **Marketplace**            | Template ecosystem    | Template store, component marketplace, code snippets, ratings, community contributions         |
| 20  | **Team Collaboration**     | Multi-user workflows  | Shared workspaces, real-time collaboration, code review, permissions, activity logs            |
| 21  | **Advanced Build Options** | Distribution pipeline | MSIX + .msi installer gen, code signing, auto-update mechanism, release notes generation       |
| 22  | **Cloud Features**         | Cloud-enhanced ops    | Cloud storage, backup, cross-device sync, cloud compilation, usage analytics                   |
| 23  | **IDE Integration**        | External IDE bridges  | VS Code extension, Visual Studio extension, live sync, debug support                           |
| 24  | **Performance Tools**      | Optimization suite    | Build time optimization, memory profiling, leak detection, startup analysis, UI responsiveness |

### Observable System Behaviors

These behaviors are **evidence of hidden sophistication**, not simplicity:

| Behavior                          | What User Sees              | Internal Mechanism                                            |
| --------------------------------- | --------------------------- | ------------------------------------------------------------- |
| Complex apps generate in seconds  | 30-60s generation time      | Parallel agents + cached embeddings + incremental compilation |
| Incremental updates are surgical  | Only changed files modified | AST-based patch engine with impact analysis                   |
| Dependencies appear automatically | NuGet packages just work    | Execution Kernel + NuGet API + dependency resolution          |
| Code quality is consistent        | Clean, formatted output     | Roslyn formatting + pattern enforcement + naming conventions  |
| Code is real and portable         | Opens in Visual Studio      | Standard C#/XAML, no proprietary formats                      |
| Error-free user experience        | Never see compiler errors   | Silent validation loop + auto-fix + retry                     |

### Constraints & Limitations (Current MVP)

| Constraint        | Current               | Future                        |
| ----------------- | --------------------- | ----------------------------- |
| **Platform**      | Windows only          | Multi-platform (Phase 4)      |
| **Languages**     | .NET / C# / XAML only | Other languages (Phase 4)     |
| **Components**    | 30-50 UI components   | 200+ (Phase 2 marketplace)    |
| **Collaboration** | Single user only      | Team workspaces (Phase 3)     |
| **Cloud**         | Local-first only      | Optional cloud sync (Phase 3) |

---

## 📊 SUCCESS METRICS

### Timing Targets

| Operation       | Target       | Notes                     |
| --------------- | ------------ | ------------------------- |
| Cold Generation | < 60 seconds | First-time app generation |
| Refinement      | < 15 seconds | Incremental changes       |
| Build           | < 30 seconds | Standard project          |
| Preview Refresh | < 2 seconds  | XAML hot-reload           |

### Quality Targets

| Metric                      | Target | Notes                              |
| --------------------------- | ------ | ---------------------------------- |
| **Syntax Validity**         | > 95%  | Generated code compiles first pass |
| **Build Success**           | > 99%  | Auto-fix handles rest              |
| **Error Visibility**        | 0%     | No errors shown to user            |
| **Runtime Success**         | > 90%  | Validates expected behavior        |
| **Real Code Generation**    | 100%   | Not templates, actual C#/XAML      |
| **Export Portability**      | 100%   | Code runs outside builder          |
| **User Satisfaction**       | 4.5+   | Star rating target                 |
| **Documentation Coverage**  | 100%   | All features documented            |
| **No Broken Code to Users** | 100%   | Enforced via silent retry loop     |

---

## 🗄️ SQLITE SCHEMA DEFINITIONS

### Code Intelligence Tables

```sql
-- File Index for semantic tracking
CREATE TABLE file_index (
  id TEXT PRIMARY KEY,
  file_path TEXT UNIQUE NOT NULL,
  file_type TEXT,
  export_symbols TEXT,  -- JSON array
  import_symbols TEXT,  -- JSON array
  size_bytes INTEGER,
  checksum TEXT,
  last_analyzed DATETIME
);

-- Dependency Graph for relationships
CREATE TABLE dependency_graph (
  id INTEGER PRIMARY KEY,
  source_file TEXT NOT NULL,
  target_file TEXT NOT NULL,
  dep_type TEXT,  -- 'imports', 'uses', 'references'
  FOREIGN KEY (source_file) REFERENCES file_index(file_path)
);

-- Embeddings for semantic search
CREATE TABLE embeddings (
  id INTEGER PRIMARY KEY,
  file_path TEXT,
  code_section TEXT,
  embedding BLOB,  -- Vector embedding for semantic search
  FOREIGN KEY (file_path) REFERENCES file_index(file_path)
);
```

### Memory Layer Tables

```sql
-- Project Memory (architectural decisions)
CREATE TABLE project_memory (
  project_id TEXT PRIMARY KEY,
  stack_decisions JSON,
  architectural_decisions JSON,
  naming_conventions JSON,
  created_at DATETIME,
  updated_at DATETIME
);

-- Pattern Memory (coding patterns)
CREATE TABLE pattern_memory (
  id INTEGER PRIMARY KEY,
  project_id TEXT,
  pattern_type TEXT,  -- 'file_naming', 'routing', 'code_style'
  pattern_data JSON,
  FOREIGN KEY (project_id) REFERENCES project_memory(project_id)
);

-- Error Memory (error solutions)
CREATE TABLE error_memory (
  id INTEGER PRIMARY KEY,
  project_id TEXT,
  error_code TEXT,
  error_pattern TEXT,
  successful_fix TEXT,
  occurrence_count INTEGER,
  last_seen DATETIME,
  FOREIGN KEY (project_id) REFERENCES project_memory(project_id)
);
```

---

## 🔧 ERROR CLASSIFIER IMPLEMENTATION

### ErrorType Enum

```csharp
public enum ErrorType
{
    SyntaxError,           // CS1002, etc.
    MissingDependency,     // Package not found
    TypeMismatch,          // CS1503
    MissingReference,      // CS0106
    UndefinedVariable,     // CS0103
    InvalidRoute,          // Custom domain error
    ConfigError,           // Missing settings
    SchemaConflict         // DB schema mismatch
}
```

### ErrorClassifier Class

```csharp
public class ErrorClassifier
{
    public ErrorType Classify(string errorCode, string message)
    {
        return errorCode switch
        {
            "CS1002" => ErrorType.SyntaxError,
            "CS1503" => ErrorType.TypeMismatch,
            "CS0103" => ErrorType.UndefinedVariable,
            "CS0106" => ErrorType.MissingReference,
            _ => ErrorType.Unknown
        };
    }
}
```

### Auto-Fix Strategies

| Error Code | Error              | Fix Strategy                          |
| ---------- | ------------------ | ------------------------------------- |
| CS1002     | Missing ';'        | Insert ';' using AST patch            |
| CS1503     | Type mismatch      | Insert Convert.ToInt32() or Parse()   |
| CS0106     | Missing reference  | Add using statement                   |
| CS0103     | Undefined variable | Add field definition or check imports |

---

## 🔄 USER WORKFLOWS

### Workflow 1: Prompt to Deployed App

```text
1. User enters prompt
2. [System: Parse → Generate → Validate]
3. User sees working app in 30-60 seconds
4. User previews, tests app
5. User refines with prompts or manual edits
6. User exports to GitHub or downloads
7. User deploys or continues development
```

### Workflow 2: Incremental Refinement

```text
1. Start with base app
2. User: "Add dark mode"
3. [System: Analyze impact → Regenerate themes → Validate]
4. Preview updates in 5-15 seconds
5. Repeat with new requests
6. Each iteration improves app without breaking existing code
```

### Workflow 3: Export & Independence

```text
1. Generate app
2. Export to GitHub (automatic sync)
3. Take code, open in Visual Studio
4. Modify code locally (add features, customize)
5. Deploy as .exe/.msi independently
6. App not needed anymore (code is yours)
```

---

## 🏗 KEY ARCHITECTURAL DECISIONS

### 1. Multi-Agent Over Monolithic AI Engine

- **Why**: Specialized agents produce better code than single generalist AI Engine
- **Benefit**: Easier to control output, debug, test
- **Tradeoff**: More orchestration complexity (but hidden from user)

### 2. Structured Specs Over Free-Form Generation

- **Why**: Prevents hallucinated features and contradictions
- **Process**: Parse prompt → Extract features → Validate → Generate spec

### 3. AST Patches Over Full Rewrites

- **Why**: Preserves code quality, comments, formatting
- **Technology**: Roslyn for C# manipulation
- **Benefit**: Minimal diffs, merge-friendly, safer

### 4. Smart Retrieval Over Full Context

- **Why**: Solves AI Engine context window limits
- **Strategy**: Embed code → Search semantically → Send only relevant files
- **Result**: Stable generation as project grows

### 5. Silent Retry Loop Over Error Bubbling

- **Why**: Perfect user experience (no visible errors)
- **How**: Auto-classify errors → Apply fixes → Retry until success

### 6. Persistent Memory Over Stateless Generation

- **Stores**: Stack decisions, patterns, error solutions
- **Benefit**: Consistent architecture across iterations

---

## 📁 BUILDER PROJECT STRUCTURE

```
SyncAIAppBuilder/
├── UI/                        # WinUI 3: Prompt Console, Explorer, Logs, Status
├── Orchestrator/              # StateMachine.cs, TaskExecutor.cs, RetryController.cs
├── Kernel/                    # BuildRunner.cs, RoslynIndexer.cs, PatchEngine.cs, SandboxManager.cs
├── Memory/                    # DatabaseContext.cs, GraphRepository.cs (SQLite)
├── Services/                  # IntentService.cs, PlanningService.cs
│   ├── IntentService.cs
│   ├── PlanningService.cs
│   ├── CodeGenerationService.cs
│   ├── ValidationService.cs
│   ├── PreviewService.cs
│   ├── BuildService.cs
│   ├── DeploymentService.cs
│   ├── MemoryService.cs
│   └── ErrorRecoveryService.cs
├── Agents/
│   ├── ArchitectAgent.cs
│   ├── SchemaAgent.cs
│   ├── FrontendAgent.cs
│   ├── BackendAgent.cs
│   └── FixAgent.cs
├── Infrastructure/            # AI Engine Wrapper (z-ai-web-dev-sdk)
└── Tests/                     # xUnit test project
```

### Full Repository Layout

```
SYNC-AI-FULL-STACK-APP-BUILDER/
├── src/
│   ├── SyncAIAppBuilder/           # Main WinUI 3 application
│   │   ├── UI/                     # XAML pages + view models
│   │   ├── Kernel/                 # Build, Roslyn, Patch, Sandbox
│   │   ├── Services/               # Intent, Planning, CodeGen, Validation
│   │   ├── Agents/                 # AI agent implementations
│   │   ├── Memory/                 # SQLite context + repositories
│   │   └── Infrastructure/         # AI SDK wrapper
│   ├── SyncAIAppBuilder.Core/      # Shared interfaces and models
│   │   └── Interfaces/
│   │       ├── IOrchestrator.cs
│   │       ├── IPatchEngine.cs
│   │       ├── ICodeIntelligence.cs
│   │       ├── IBuildRunner.cs
│   │       └── IProjectMemory.cs
│   └── SyncAIAppBuilder.Tests/     # xUnit test project
├── templates/                       # Starter project templates
├── ai-agents/                       # AI agent prompt configurations
├── scripts/                         # Build and deployment scripts
├── docs/                            # Documentation (this file)
└── tools/                           # Development utilities
```

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

---

## Intent & Specification Layer

Transforms unstructured user prompts into structured, machine-readable specifications:

**Input Example:**

```
"Build a CRM with authentication, role-based access,
customer database, and analytics dashboard"
```

**Processing Pipeline:**

1. **NLP Feature Extraction** - Identify requested features
2. **Stack Selection** - Choose appropriate tech stack
3. **Constraint Inference** - Deduce implicit requirements
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
  "files": [
    {
      "path": "Models/Customer.cs",
      "type": "class",
      "dependencies": ["System.Data", "DbContext"],
      "exports": ["Customer", "CustomerValidator"],
      "imports": ["System", "System.ComponentModel.DataAnnotations"]
    }
  ]
}
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

## 🚫 EXPLICIT SYSTEM EXCLUSIONS

These are explicitly OUT OF SCOPE:

| Exclusion                  | Rationale                        |
| -------------------------- | -------------------------------- |
| Web application generation | Windows desktop only             |
| Manual code editing        | Autonomous, not developer tool   |
| Cloud compilation          | Local-first architecture         |
| Visual Studio integration  | No IDE required                  |
| Cross-platform (Linux/Mac) | Windows-native focus             |
| Real-time collaboration    | Single-user autonomous operation |
| Plugin marketplace         | Phase 2+ feature                 |
| Cloud storage              | Local-first, privacy-focused     |

---

## 📊 STATE MACHINE DEFINITION

### Orchestrator States (Canonical)

```
IDLE → SPEC_PARSED → TASK_GRAPH_READY → TASK_EXECUTING → VALIDATING → RETRYING → COMPLETED / FAILED
```

### State Transition Rules

| From State       | To State         | Trigger              |
| ---------------- | ---------------- | -------------------- |
| IDLE             | SPEC_PARSED      | Valid spec generated |
| SPEC_PARSED      | TASK_GRAPH_READY | DAG created          |
| TASK_GRAPH_READY | TASK_EXECUTING   | Task dispatched      |
| TASK_EXECUTING   | VALIDATING       | Task completed       |
| VALIDATING       | RETRYING         | Errors detected      |
| RETRYING         | TASK_EXECUTING   | Fix applied          |
| VALIDATING       | COMPLETED        | No errors            |
| ANY              | FAILED           | Max retries exceeded |

---

## 🔗 CROSS-REFERENCE INDEX

| Document                                                                     | Topic                      | Relationship                          |
| ---------------------------------------------------------------------------- | -------------------------- | ------------------------------------- |
| [01_ARCHITECTURE.md](./01_ARCHITECTURE.md)                                   | System architecture        | High-level design                     |
| [02_ORCHESTRATION_AND_EXECUTION.md](./02_ORCHESTRATION_AND_EXECUTION.md)     | Deterministic orchestrator | **FOUNDATION** - Must implement first |
| [03_BUILD_AND_MUTATION_KERNEL.md](./03_BUILD_AND_MUTATION_KERNEL.md)         | Build & patch engine       | Code mutations                        |
| [04_INDEXING_AND_MEMORY.md](./04_INDEXING_AND_MEMORY.md)                     | SQLite persistence         | Data layer                            |
| [05_UI_SYSTEM.md](./05_UI_SYSTEM.md)                                         | UI states & UX             | User interface                        |
| [06_PROJECT_LAYOUT_AND_DEPLOYMENT.md](./06_PROJECT_LAYOUT_AND_DEPLOYMENT.md) | Folder structure           | Deployment                            |
| [API_CONTRACTS.md](./API_CONTRACTS.md)                                       | API definitions            | Integration points                    |
| [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md)                               | Onboarding                 | Getting started                       |

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

| Area                   | Requirement                                                            |
| ---------------------- | ---------------------------------------------------------------------- |
| **API Communication**  | HTTPS/TLS for all AI Engine communication                              |
| **API Key Management** | Secure storage via environment variables or Windows Credential Manager |
| **Code Validation**    | All generated code validated before compilation                        |
| **Input Sanitization** | User prompts sanitized before processing                               |
| **Rate Limiting**      | API calls throttled to prevent abuse                                   |
| **Code Signing**       | Generated executables signed with Authenticode (when deployed)         |
| **Privacy**            | User prompts NOT stored; local-first data handling                     |

### Compliance Principles

- **Data Privacy**: No cloud storage of user data; all projects local
- **Code Ownership**: Users own 100% of generated code
- **Audit Trail**: Event log captures all operations for debugging
- **SBOM**: Software Bill of Materials generated for deployments

---

## 🧪 TESTING & QUALITY ASSURANCE

### Testing Stack

| Type                    | Technology                          | Purpose               |
| ----------------------- | ----------------------------------- | --------------------- |
| **Unit Testing**        | xUnit / NUnit                       | Core logic validation |
| **Integration Testing** | Test Containers                     | Component integration |
| **UI Testing**          | Windows Application Driver / Appium | WinUI 3 automation    |
| **Load Testing**        | k6                                  | Performance testing   |

### Quality Targets

| Metric              | Target | Notes                              |
| ------------------- | ------ | ---------------------------------- |
| **Syntax Validity** | > 95%  | Generated code compiles first pass |
| **Build Success**   | > 99%  | Auto-fix handles rest              |
| **Runtime Success** | > 90%  | Validates expected behavior        |

---

## 📡 MONITORING & LOGGING

### Logging Architecture

| Component             | Technology                    | Purpose                  |
| --------------------- | ----------------------------- | ------------------------ |
| **Logging Framework** | Serilog                       | Structured logging       |
| **Log Aggregation**   | Seq                           | Log viewer for debugging |
| **Error Tracking**    | Sentry / Application Insights | Exception monitoring     |

### Logging Requirements

- **All Operations**: Every mutation logged with timestamp
- **Error Capture**: Full stack traces with context
- **Performance Metrics**: Timing for all pipeline stages
- **Audit Trail**: Event sourcing for perfect replay

---

## 📦 DISTRIBUTION & DEPLOYMENT

### Package Formats

| Format                    | Description            | Use Case             |
| ------------------------- | ---------------------- | -------------------- |
| **MSIX**                  | Modern Windows package | Primary distribution |
| **Windows App Installer** | Auto-update capable    | Sideloading          |
| **Microsoft Store**       | Store distribution     | Public releases      |
| **Direct Download**       | Self-hosted MSIX       | Enterprise teams     |

### DevOps Options

| Tool               | Purpose            |
| ------------------ | ------------------ |
| **GitHub Actions** | CI/CD pipeline     |
| **Azure DevOps**   | Alternative CI/CD  |
| **AppVeyor**       | Windows-focused CI |

### Code Signing

- **Authenticode**: Required for all distributed executables
- **Certificate**: Must be from trusted CA or self-signed for testing
- **Timestamp**: Long-term validity with timestamping

---

## 👁️ PREVIEW SYSTEM

### Preview Modes (3 Parallel)

The Preview System renders generated code without user seeing internal complexity:

| Mode              | Technology          | Description                |
| ----------------- | ------------------- | -------------------------- |
| **Embedded XAML** | XamlReader.Load()   | Instant UI rendering       |
| **Code View**     | Syntax Highlighting | Formatted source display   |
| **Full Launch**   | Process.Start()     | Running .exe in new window |

### Integration Architecture

```text
User Prompt
    ↓
Deterministic Orchestrator
    ↓
AI Engine (z-ai-web-dev-sdk) → Returns JSON patches
    ↓
Roslyn Patch Engine → Applies AST mutations
    ↓
┌─────────────────────────────┐
│     Preview System          │
│  ┌──────────┬──────┬──────┐ │
│  │Embedded  │Code  │Full  │ │
│  │XAML      │View  │Launch│ │
│  └──────────┴──────┴──────┘ │
└─────────────────────────────┘
```

### Data Flow During Preview

1. **Code Generated** → Roslyn validates AST → XAML extracted
2. **Preview Triggered** → `XamlReader.Load()` renders UI in-process
3. **User Sees** → Live preview of generated application

### Separation of Concerns

| Component        | Does                      | Does NOT                |
| ---------------- | ------------------------- | ----------------------- |
| **AI Engine**    | Generate JSON patches     | Write files, run builds |
| **Roslyn**       | Apply AST mutations       | UI rendering            |
| **Preview**      | Render XAML, display code | Compile, modify files   |
| **Build**        | MSBuild → .exe            | UI rendering            |
| **Orchestrator** | Control all flow          | Generate code           |

### Preview Update Triggers

| Trigger               | Action                     | Delay          |
| --------------------- | -------------------------- | -------------- |
| New code generated    | Full preview refresh       | 500ms debounce |
| Code patch applied    | Incremental preview update | 500ms debounce |
| User requests refresh | Force re-render            | Immediate      |

```csharp
// Debounced preview updates
private CancellationTokenSource _previewCts;

private async Task UpdatePreviewAsync(string xamlContent)
{
    _previewCts?.Cancel();
    _previewCts = new CancellationTokenSource();
    await Task.Delay(500, _previewCts.Token);
    var content = XamlReader.Load(xamlContent);
    await DispatcherQueue.EnqueueAsync(() => PreviewPanel.Content = content);
}
```

### Error Handling in Preview

```text
XAML Parse Error (XamlParseException)
    ↓
Log error internally → DO NOT show to user
    ↓
Attempt auto-fix (common XAML issues)
    ↓
Retry render → If success → Show preview
    ↓
If still fails → Show last successful preview with "Updating..." indicator
```

---

## ⚡ PERFORMANCE CONSIDERATIONS

| Strategy               | Description                                                | Impact                       |
| ---------------------- | ---------------------------------------------------------- | ---------------------------- |
| **Semantic Caching**   | Store prompt embeddings, reuse for similar requests        | Reduces AI calls by ~40%     |
| **Parallel Agents**    | Execute independent agents concurrently (Schema + Backend) | Cuts generation time ~50%    |
| **Incremental Builds** | Only recompile changed modules via Roslyn                  | Build times < 5s for patches |
| **Smart Retrieval**    | Send ~2-5 relevant files to AI, not entire project         | Stays within context window  |
| **Preview Debouncing** | 500ms delay before preview refresh                         | Prevents UI thrashing        |

---

## 📊 COMPARISON WITH TRADITIONAL APPROACHES

| Aspect                | Windows Native Builder       | Traditional IDE            |
| --------------------- | ---------------------------- | -------------------------- |
| **Code Quality**      | Consistent (Roslyn-enforced) | Variable (developer skill) |
| **Build Errors**      | Auto-fixed silently          | Developer must debug       |
| **User Experience**   | Prompt → working app         | Hours of coding + testing  |
| **Stack Reliability** | Opinionated, tested          | Arbitrary, inconsistent    |
| **Iteration Speed**   | Seconds (incremental)        | Minutes to hours           |
| **Scalability**       | Parallel agents              | Manual refactoring         |
| **Arch Consistency**  | Memory-enforced patterns     | Documentation + reviews    |

---

## 🗺️ FUTURE EVOLUTION / ROADMAP

| Phase             | Focus        | Key Features                                                                 |
| ----------------- | ------------ | ---------------------------------------------------------------------------- |
| **Phase 1 (MVP)** | Core Builder | 12 features, single user, Windows desktop, local-first                       |
| **Phase 2**       | Advanced     | Smart components, database, testing, version control, code quality           |
| **Phase 3**       | Production   | Marketplace, team collab, cloud features, IDE integration, performance tools |
| **Phase 4**       | Scale        | Multi-platform, other languages, enterprise features, SLA-backed reliability |

---

## 📝 DOCUMENT CONTROL

| Version | Date       | Author | Change                                                                                                                                                                                                                                                                                                                               |
| ------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1.0     | 2026-02-16 | System | Initial canonical authority                                                                                                                                                                                                                                                                                                          |
| 1.1     | 2026-02-17 | System | Merged content from archive docs - Testing, Monitoring, Distribution, Preview System                                                                                                                                                                                                                                                 |
| 1.2     | 2026-02-17 | System | Complete gap analysis - Added all missing canonical content                                                                                                                                                                                                                                                                          |
| 1.3     | 2026-02-17 | System | Added Code Generation Rules, Critical Stability Constraints, Error Classifier, SQLite Schema, Success Metrics, Error Handling Strategy, User Workflows, Key Architectural Decisions                                                                                                                                                  |
| 2.0     | 2026-02-17 | System | Full gap fill: Architecture (No IDE, DAG, Agent I/O, Patch Engine, Memory Layer), Tech Stack (libraries, DB alternatives, installation), Design Philosophy (pipeline, patterns, checklists, comparisons), Features (12 MVP + Phase 2/3), Preview System (integration, data flow, triggers, errors), Performance, Roadmap, Comparison |

**This document is the single source of truth. All other specifications must be consistent with it.**

---

# 📋 DOCUMENTATION GOVERNANCE RULES

> **Authority**: These rules are binding on all documentation in this repository.

## Single Definition Rules

Every critical system element must exist in **exactly one** document:

| Element                        | Authority Document                                                       |
| ------------------------------ | ------------------------------------------------------------------------ |
| **Orchestrator state machine** | [02_ORCHESTRATION_AND_EXECUTION.md](./02_ORCHESTRATION_AND_EXECUTION.md) |
| **Mutation rules**             | [03_BUILD_AND_MUTATION_KERNEL.md](./03_BUILD_AND_MUTATION_KERNEL.md)     |
| **Graph schema**               | [04_INDEXING_AND_MEMORY.md](./04_INDEXING_AND_MEMORY.md)                 |
| **UI states**                  | [05_UI_SYSTEM.md](./05_UI_SYSTEM.md)                                     |
| **Execution flow**             | [02_ORCHESTRATION_AND_EXECUTION.md](./02_ORCHESTRATION_AND_EXECUTION.md) |

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
