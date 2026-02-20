# PROJECT HANDBOOK

> **The Developer's Guide to Structure, Contribution, and Deployment**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> _The AI Construction Engine is the Primary Brain. The Runtime Safety Kernel is the Enforcement Layer._

## Preface: Constructing the Constructor

Sync AI is **a Local AI Full-Stack Windows App Builder**. The AI Construction Engine is the Primary Brain that designs and builds applications. The Runtime Safety Kernel enforces hard boundaries silently.

When contributing, remember:

1.  **We build the Factory, not the Product.** Our code enables the _user_ to be the architect.
2.  **No IDE Exposure.** The user should never see a `.csproj` file or a console window.
3.  **Local-First.** We respect the user's machine and data privacy.

## Table of Contents

1. [Project Directory Structure](#1-project-directory-structure)
2. [Dependencies & Technology Stack](#2-dependencies--technology-stack)
3. [Development Setup](#3-development-setup)
4. [Contribution Guidelines](#4-contribution-guide)
5. [Deployment & Packaging](#5-deployment--packaging)
6. [Design Philosophy & UX Principles](#6-design-philosophy--ux-principles)

---

## 1. Project Directory Structure

### Top-Level Layout

The solution uses a clean separation between the **Builder** (the tool itself) and **User Workspaces** (where apps are generated).

```text
SYNC-AI-FULL-STACK-APP-BUILDER/
│
├── docs/                              # Documentation
│   ├── SYSTEM_ARCHITECTURE.md         # System architecture
│   ├── ORCHESTRATION_ENGINE.md        # Deterministic orchestrator
│   ├── CODE_INTELLIGENCE.md           # Roslyn, indexing, database
│   ├── PROJECT_HANDBOOK.md            # This file
│   └── archive/                       # Archived specifications
│
├── src/                               # Source code
│   │
│   ├── SyncAIAppBuilder/              # Main WinUI 3 application (.NET 8)
│   │   ├── SyncAIAppBuilder.csproj    # WinUI 3 project file
│   │   ├── Program.cs                 # Entry point
│   │   │
│   │   ├── UI/                        # Frontend (WinUI 3 - Thin XAML Layer)
│   │   │   ├── MainWindow.xaml        # Root window (Fluent Design)
│   │   │   ├── MainWindow.xaml.cs     # Code-behind
│   │   │   ├── Pages/                 # Navigation pages
│   │   │   │   ├── EditorPage.xaml
│   │   │   │   ├── PreviewPage.xaml
│   │   │   │   ├── ProjectsPage.xaml
│   │   │   │   └── SettingsPage.xaml
│   │   │   ├── Components/            # Reusable controls
│   │   │   │   ├── PromptEditor.xaml
│   │   │   │   ├── CodeViewer.xaml
│   │   │   │   ├── BuildProgress.xaml
│   │   │   │   └── PreviewPanel.xaml
│   │   │   ├── Dialogs/               # Modal dialogs
│   │   │   │   └── CreateProjectDialog.xaml
│   │   │   └── Resources/             # XAML styling
│   │   │       ├── Styles.xaml
│   │   │       ├── Colors.xaml
│   │   │       ├── Icons.xaml
│   │   │       └── Converters.xaml
│   │   │
│   │   ├── Services/                  # Core Business Logic (7-Layer Architecture)
│   │   │   │
│   │   │   ├── 🔴 Runtime Safety Kernel (Enforcement Layer)
│   │   │   │   ├── Orchestration/
│   │   │   │   │   ├── BuilderReducer.cs
│   │   │   │   │   ├── TaskSchema.cs
│   │   │   │   │   ├── BuilderContext.cs
│   │   │   │   │   ├── BuilderEvent.cs
│   │   │   │   │   ├── RetryController.cs
│   │   │   │   │   ├── ConcurrencyPolicy.cs
│   │   │   │   │   ├── ErrorClassifier.cs
│   │   │   │   │   └── IOrchestrator.cs
│   │   │   │
│   │   │   ├── Layer 1: Blueprint & Intent (AI Construction Engine)
│   │   │   │   ├── IntentService.cs
│   │   │   │   ├── FeatureExtractor.cs
│   │   │   │   ├── SpecValidator.cs
│   │   │   │   └── StackSelector.cs
│   │   │   │
│   │   │   ├── Layer 2: Planning Service
│   │   │   │   ├── PlanningService.cs
│   │   │   │   ├── TaskGraphBuilder.cs
│   │   │   │   └── TaskOrchestrator.cs
│   │   │   │
│   │   │   ├── Layer 3: Code Intelligence
│   │   │   │   ├── CodeIntelligenceService.cs
│   │   │   │   ├── FileIndexer.cs
│   │   │   │   ├── DependencyGraphBuilder.cs
│   │   │   │   ├── EmbeddingService.cs
│   │   │   │   ├── SchemaMapper.cs
│   │   │   │   └── RouteRegistry.cs
│   │   │   │
│   │   │   ├── Layer 4: Multi-Agent System (AI Construction Engine)
│   │   │   │   ├── AgentOrchestrator.cs
│   │   │   │   ├── ArchitectAgent.cs
│   │   │   │   ├── SchemaAgent.cs
│   │   │   │   ├── FrontendAgent.cs
│   │   │   │   ├── BackendAgent.cs
│   │   │   │   ├── IntegrationAgent.cs
│   │   │   │   └── FixAgent.cs
│   │   │   │
│   │   │   ├── Layer 5: Structured Patch Engine (Roslyn)
│   │   │   │   ├── PatchEngine.cs
│   │   │   │   ├── ASTParser.cs
│   │   │   │   ├── PatchApplier.cs
│   │   │   │   └── FormattingPreserver.cs
│   │   │   │
│   │   │   ├── Layer 6: Build & Validation
│   │   │   │   ├── BuildService.cs
│   │   │   │   ├── ErrorClassifier.cs
│   │   │   │   ├── AutoFixEngine.cs
│   │   │   │   └── ValidationLoop.cs
│   │   │   │
│   │   │   ├── Layer 7: Memory & State Management
│   │   │   │   ├── StateManager.cs
│   │   │   │   ├── ProjectMemory.cs
│   │   │   │   ├── PatternMemory.cs
│   │   │   │   ├── ErrorPatternMemory.cs
│   │   │   │   └── SessionContext.cs
│   │   │   │
│   │   │   ├── Legacy / Utility Services
│   │   │   │   ├── ProjectService.cs
│   │   │   │   ├── TemplateService.cs
│   │   │   │   └── ConfigService.cs
│   │   │   │
│   │   │   └── Infrastructure
│   │   │       ├── AIClient.cs
│   │   │       ├── LoggingService.cs
│   │   │       └── DatabaseService.cs
│   │   │
│   │   ├── Models/                    # Data Models & DTOs
│   │   │   ├── Intent/
│   │   │   │   ├── ProjectSpec.cs
│   │   │   │   ├── Feature.cs
│   │   │   │   └── StackConfig.cs
│   │   │   ├── Planning/
│   │   │   │   ├── TaskGraph.cs
│   │   │   │   └── TaskNode.cs
│   │   │   ├── Intelligence/
│   │   │   │   ├── ProjectIndex.cs
│   │   │   │   ├── FileDependency.cs
│   │   │   │   └── CodeEmbedding.cs
│   │   │   ├── Generation/
│   │   │   │   ├── GeneratedCode.cs
│   │   │   │   └── CodePatch.cs
│   │   │   ├── Build/
│   │   │   │   ├── BuildResult.cs
│   │   │   │   └── BuildError.cs
│   │   │   └── State/
│   │   │       ├── ProjectState.cs
│   │   │       └── SessionMemory.cs
│   │   │
│   │   ├── ViewModels/                # MVVM Pattern
│   │   │   ├── MainViewModel.cs
│   │   │   ├── EditorViewModel.cs
│   │   │   ├── ProjectsViewModel.cs
│   │   │   └── PreviewViewModel.cs
│   │   │
│   │   ├── Utils/                     # Utility Functions
│   │   │   ├── FileHelper.cs
│   │   │   ├── PathHelper.cs
│   │   │   ├── RoslynHelper.cs
│   │   │   ├── JsonHelper.cs
│   │   │   └── ValidationHelper.cs
│   │   │
│   │   └── appsettings.json           # Configuration
│   │
│   ├── SyncAIAppBuilder.Tests/        # Unit tests
│   │   ├── SyncAIAppBuilder.Tests.csproj
│   │   ├── Services/
│   │   │   ├── AIServiceTests.cs
│   │   │   ├── CodeGeneratorTests.cs
│   │   │   └── BuildServiceTests.cs
│   │   └── Utils/
│   │       └── HelperTests.cs
│   │
│   └── SyncAIAppBuilder.Core/         # Shared library
│       ├── SyncAIAppBuilder.Core.csproj
│       ├── Constants.cs
│       ├── Enums.cs
│       └── Interfaces/
│           ├── ICodeGenerator.cs
│           ├── IAIService.cs
│           └── IBuildService.cs
│
├── templates/                         # App templates
│   ├── BlankApp/
│   ├── TodoApp/
│   ├── Calculator/
│   ├── WeatherApp/
│   └── DatabaseApp/
│
├── components/                        # Reusable components library
│   ├── Components.csproj
│   ├── Buttons/
│   ├── DataGrid/
│   ├── Forms/
│   └── Navigation/
│
├── ai-prompts/                        # AI system prompts
│   ├── system-prompts/
│   │   ├── xaml-generation.txt
│   │   ├── csharp-generation.txt
│   │   ├── database-schema.txt
│   │   └── api-integration.txt
│   ├── examples/
│   └── prompts-config.json
│
├── scripts/                           # Build & automation scripts
│   ├── build.ps1
│   ├── test.ps1
│   ├── deploy.ps1
│   ├── generate-docs.ps1
│   └── setup-dev.ps1
│
├── .github/                           # GitHub configuration
│   └── workflows/
│       ├── ci.yml
│       └── release.yml
│
├── .gitignore
├── .editorconfig
├── global.json
├── README.md
├── LICENSE
└── SyncAI.sln
```

### User Workspace Layout (Generated Apps)

When a user creates an app, it lives here:

```text
C:\YourBuilder\Workspaces\
├── {ProjectId_001}/
│   ├── src/                          # Generated user code
│   │   ├── SyncAIAppBuilder.csproj
│   │   ├── Program.cs
│   │   ├── MainWindow.xaml
│   │   ├── Pages/
│   │   ├── Services/
│   │   └── Models/
│   │
│   ├── .builder/                     # Internal builder metadata (hidden)
│   │   ├── snapshots/                # Filesystem snapshots (before each task)
│   │   │   ├── snapshot_20260216_120000.zip
│   │   │   ├── snapshot_20260216_120500.zip
│   │   │   └── ...
│   │   ├── diffs/                    # Change diffs between snapshots
│   │   ├── build_temp/               # Temporary build artifacts (cleaned after build)
│   │   │   ├── bin/
│   │   │   ├── obj/
│   │   │   └── ...
│   │   ├── project_graph.db          # SQLite: symbols, dependencies, memory
│   │   ├── build_log.json            # Full build history
│   │   └── state.json                # Last known good orchestrator state
│   │
│   └── .metadata.json                # Project metadata
│
├── {ProjectId_002}/
│   └── ... (same structure)
│
└── Cache/
    ├── roslyn_symbols_cache/        # Roslyn AST cache
    ├── embedding_cache/             # Semantic embeddings cache
    └── nuget_packages_*.cache       # NuGet package cache
```

**Key Points**:

- User code lives in `src/` (version controllable, visible)
- Builder metadata in `.builder/` (hidden, internal management)
- Snapshots created BEFORE each task (not after)
- Diffs tracked for rollback capability
- Build artifacts isolated in temp directory
- SQLite database stores permanent decision graph

### Key File Descriptions

- **`ActionPlan.md`**: (Internal) The current plan the agent is executing for a user request.
- **`implementation_plan.md`**: (Internal) High-level architectural roadmap check-in.
- **`project.db`**: SQLite database storing the app's persistent data.
- **`memory.db`**: SyncAI's memory of the project (history, user preferences, embeddings).

---

## 2. Dependencies & Technology Stack

### Platform & Runtime

| Component        | Technology                | Version      |
| ---------------- | ------------------------- | ------------ |
| **Runtime**      | .NET                      | 8.0 LTS      |
| **Language**     | C#                        | 12           |
| **UI Framework** | WinUI 3 (Windows App SDK) | 1.5+         |
| **Target OS**    | Windows 10/11             | Build 19041+ |
| **Architecture** | x64, ARM64                | -            |

### Core Frameworks & Libraries

| Package                                    | Purpose                                          |
| ------------------------------------------ | ------------------------------------------------ |
| `Microsoft.WindowsAppSDK`                  | WinUI 3 runtime                                  |
| `CommunityToolkit.Mvvm`                    | MVVM pattern, `ObservableObject`, `RelayCommand` |
| `CommunityToolkit.WinUI`                   | Additional WinUI controls                        |
| `Microsoft.Extensions.DependencyInjection` | IoC container                                    |
| `Microsoft.Extensions.Logging`             | Structured logging                               |
| `Microsoft.Extensions.Configuration`       | App settings                                     |

### AI Integration

| Component            | Technology                         |
| -------------------- | ---------------------------------- |
| **AI Engine SDK**    | `z-ai-web-dev-sdk` (built-in)      |
| **Model**            | GPT-4 (configurable)               |
| **Context Protocol** | Structured prompt + code retrieval |

### Code Intelligence

| Component            | Technology                           |
| -------------------- | ------------------------------------ |
| **C# Analysis**      | Microsoft.CodeAnalysis (Roslyn) 4.8+ |
| **XAML Analysis**    | Custom parser + XamlReader           |
| **AST Manipulation** | Roslyn SyntaxRewriter, SyntaxFactory |

### Database & Persistence

| Component      | Technology              |
| -------------- | ----------------------- |
| **Database**   | SQLite 3.x              |
| **ORM**        | Dapper (micro-ORM)      |
| **Connection** | `Microsoft.Data.Sqlite` |
| **Migrations** | Custom migration runner |

### Build & Compilation System

| Component              | Technology                          |
| ---------------------- | ----------------------------------- |
| **Build Tool**         | MSBuild (via `dotnet build`)        |
| **Package Manager**    | NuGet                               |
| **SDK Management**     | .NET SDK detection + guided install |
| **Compilation Target** | `net8.0-windows10.0.19041.0`        |

### Deployment & Distribution

| Format          | Technology                 |
| --------------- | -------------------------- |
| **Primary**     | MSIX package               |
| **Alternative** | Self-contained .exe        |
| **Installer**   | Setup.exe / .msi (Phase 3) |
| **Auto-Update** | MSIX auto-update or custom |

### Development Tools

| Tool                | Purpose                    |
| ------------------- | -------------------------- |
| **IDE**             | Visual Studio 2022         |
| **Version Control** | Git                        |
| **Testing**         | xUnit / NUnit              |
| **Mocking**         | Moq                        |
| **UI Testing**      | Windows Application Driver |
| **Code Coverage**   | Coverage tools (TBD)       |

### Additional NuGet Packages

| Package                                 | Purpose                          |
| --------------------------------------- | -------------------------------- |
| `Newtonsoft.Json` or `System.Text.Json` | JSON serialization               |
| `Serilog` (optional)                    | Advanced structured logging      |
| `Polly`                                 | Retry policies, circuit breakers |
| `FluentValidation`                      | Model validation                 |
| `AutoMapper`                            | Object mapping                   |

### Version Pinning Strategy

All package versions are managed centrally. When the AI generates projects, it uses the same package versions as the builder application to ensure compatibility.

**Version Pinning**:

- Windows App SDK: `1.5.x` (latest stable)
- .NET SDK: `8.0.x` (LTS)
- Roslyn: `4.9.x` (matches .NET 8)
- Community Toolkit: `8.x` (latest stable)

---

## 3. Development Setup

### Prerequisites (For Builder Development)

- **OS**: Windows 10 Build 22621+ or Windows 11
- **.NET SDK**: .NET 8.0.x or later (Required for compiling the builder)
- **Visual Studio 2022**: For contributing to the builder's C# and XAML codebase.
  - Workload: "Windows Desktop Development with C++"
  - Workload: "Desktop Development with .NET"
  - Extension: Visual Studio Project System Tools (for WinUI 3)
- **Windows App SDK**: Included via NuGet (Microsoft.WindowsAppSDK 1.5+)
- **Git**: For version control
- **AI Engine SDK**: Built-in `z-ai-web-dev-sdk` (pre-installed)

### IDE Setup for WinUI 3

**Visual Studio 2022 Extensions to Install**:

1. Go to Extensions → Manage Extensions
2. Search and install:
   - "Windows App SDK Project Templates" (templates for new WinUI 3 projects)
   - "XAML Styler" (auto-format XAML code)
   - "XAML Tools" (IntelliSense for XAML bindings)

**Verify WinUI 3 Workload**:

```bash
dotnet workload list
# Should show: wasm-tools, wasdk, maui
```

### Installation

#### 1. Clone Repository

```bash
git clone https://github.com/yourusername/SYNC-AI-FULL-STACK-APP-BUILDER.git
cd SYNC-AI-FULL-STACK-APP-BUILDER
```

#### 2. Install .NET SDK

Download from: https://dotnet.microsoft.com/download/dotnet/8.0

Verify installation:

```bash
dotnet --version
```

#### 3. Install Dependencies

```bash
cd src/SyncAIAppBuilder
dotnet restore
```

#### 4. Build & Run

```bash
# Build the project
dotnet build

# Run the app
dotnet run
```

#### 5. Configure API Keys

Create `appsettings.json` in `src/SyncAIAppBuilder/`:

```json
{
  "AI": {
    "Engine": "z-ai-web-dev-sdk",
    "Logging": "verbose"
  },
  "Logging": {
    "Level": "Information"
  }
}
```

**Don't commit API keys!** Add to `.gitignore`:

```
appsettings*.json
*.local.json
.env
```

### 🔴 CRITICAL: Implementation Sequence

**IMPORTANT**: The correct implementation order has been validated by production architecture review.

**DO NOT START WITH LAYER 1 (Intent)**. Instead:

#### Phase 1A: Deterministic Orchestrator Core Runtime (MUST BE FIRST)

1. **Orchestrator Core**
   - `BuilderReducer.cs` - Deterministic state transitions
   - `TaskSchema.cs` - Task types, validation strategies, status enums
   - `BuilderContext.cs` - State container
   - `BuilderEvent.cs` - Event record types (immutable)
   - `RetryController.cs` - Retry budget & rules
   - `ConcurrencyPolicy.cs` - Enforce single mutation task
   - `ErrorClassifier.cs` - Error categorization
   - `IOrchestrator.cs` - Interface for all components

**Why First?**: Without deterministic orchestration, downstream components (Roslyn patching, retry loops, error fixing) will produce nondeterministic mutations that silently corrupt code.

#### Phase 1B: Orchestrator Integration

2. Update all downstream services to ask orchestrator permission
3. All state transitions must emit events
4. All mutations must be serialized

#### Phase 2: Orchestrator-Aware Layers

3. **Layer 1** (Intent Service) - Now integrated into orchestrator
4. **Layer 2** (Planning Service) - Emits TaskStarted/TaskCompleted events
5. **Layer 3** (Code Intelligence) - Read-only, can run in parallel
6. **Layer 4** (Agents) - Ask orchestrator before mutation
7. **Layer 5** (Patch Engine) - Serialized through orchestrator
8. **Layer 6** (Validation) - Reports to orchestrator state machine
9. **Layer 7** (Memory) - Reads/writes orchestrator context

**Example Timeline**:

```
Week 1-2: Orchestrator (State Machine, Reducer, Events)
Week 3-4: Layer 1-2 (Intent, Planning) - Integrated with orchestrator
Week 5-6: Layer 3 (Indexing) - Non-blocking reads
Week 7-8: Layer 4 (Agents) - Orchestrator-aware
Week 9-10: Layer 5 (Patching) - Uses orchestrator for mutation serialization
Week 11-12: Layer 6 (Validation) - Reports to orchestrator
Week 13-14: Layer 7 (Memory) - Persists orchestrator state
```

### Local Execution Constraints

Since all execution happens on user's PC, you must handle:

| Issue                                         | Solution                                              |
| --------------------------------------------- | ----------------------------------------------------- |
| **.NET SDK not installed**                    | Pre-build check, guide user to download               |
| **Different SDK versions**                    | Detect version, warn if incompatible, suggest upgrade |
| **Missing workloads**                         | Check for XAML Desktop workload, offer repair         |
| **Broken NuGet cache**                        | Detect corruption, offer cache clear                  |
| **Antivirus interference**                    | Warn user, suggest temp exclusion                     |
| **Low disk space**                            | Check free space, fail gracefully                     |
| **Limited RAM**                               | Disable parallel build if <4GB available              |
| **Network issues (if using cloud AI Engine)** | Retry with exponential backoff                        |

### Pre-Build Validation (Before Every Build)

```csharp
public class BuildKernelValidator
{
    public async Task<ValidationResult> ValidateEnvironmentAsync()
    {
        var result = new ValidationResult();

        // 1. Check .NET SDK is installed
        var dotnetPath = await GetDotNetPathAsync();
        if (dotnetPath == null)
        {
            result.Errors.Add(
                "❌ .NET SDK not found. Download from https://dotnet.microsoft.com/download");
            return result;
        }

        // 2. Check SDK version
        var version = await GetInstalledSdkVersionAsync();
        if (version < new Version("8.0.0"))
        {
            result.Warnings.Add(
                "⚠️  .NET SDK version is older than 8.0. Update for best compatibility.");
        }

        // 3. Check disk space - FATAL THRESHOLD
        var diskSpace = GetAvailableDiskSpace(_projectPath);
        var estimatedPipelineSize = EstimatePipelineSize(_projectPath);

        if (diskSpace < estimatedPipelineSize)
        {
            // Prompt user to free space, then retry
            result.Errors.Add(
                $"❌ INSUFFICIENT DISK SPACE: {diskSpace / 1_000_000_000:F1}GB available, " +
                $"{estimatedPipelineSize / 1_000_000_000:F1}GB required. Free space to continue.");
            result.FatalError = ErrorType.RESOURCE_EXHAUSTION_DISK;
            // System will wait for user to free space, then automatically retry
            return result;
        }
        else if (diskSpace < 1_000_000_000)  // 1 GB - Warning threshold
        {
            result.Warnings.Add(
                $"⚠️  Low disk space: {diskSpace / 1_000_000_000}GB available. Build may fail.");
        }

        // 4. Check RAM
        var ramMB = GC.GetTotalMemory(false) / 1_000_000;
        if (ramMB < 2000)  // 2 GB
        {
            result.Warnings.Add(
                $"⚠️  Low available RAM: ~{ramMB}MB. Performance may be degraded.");
        }

        // 5. Check NuGet cache
        var nugetCacheValid = await ValidateNuGetCacheAsync();
        if (!nugetCacheValid)
        {
            result.Warnings.Add(
                "⚠️  NuGet cache may be corrupted. Consider running 'nuget locals all -clear'");
        }

        return result;
    }
}
```

### Error Classification Strategy (Local-Only)

```csharp
public enum LocalBuildErrorCategory
{
    SDK_VERSION_MISMATCH,
    MISSING_WORKLOAD,
    NUGET_RESTORE_FAILURE,
    COMPILATION_ERROR,
    XAML_BINDING_ERROR,
    RESOURCE_EXHAUSTION,
    ANTIVIRUS_BLOCKED,
    TIMEOUT
}
```

### Performance Optimization

```csharp
public class BuildKernelOptimizer
{
    /// Don't freeze UI while indexing
    public async Task IndexProjectInBackgroundAsync(
        string projectPath,
        IProgress<string> progress,
        CancellationToken cancellation)
    {
        // Run on thread pool, never block DispatcherQueue
        _ = await Task.Run(
            async () =>
            {
                await _roslynService.IndexProjectAsync(projectPath, progress, cancellation);
            },
            cancellation);
    }

    /// Throttle parallel operations based on available resources
    public int GetMaxParallelTasks()
    {
        var availableRam = GC.GetTotalMemory(false);

        if (availableRam < 4_000_000_000)  // < 4 GB
            return 1;  // Sequential only

        if (availableRam < 8_000_000_000)  // < 8 GB
            return 2;  // Max 2 parallel

        return Environment.ProcessorCount;  // Use all cores
    }
}
```

---

## 4. Contribution Guide

### Coding Standards

- **Async/Await**: Use async all the way down. Avoid `.Result` or `.Wait()`.
- **Code Style**: Follow standard C# conventions (PascalCase for public, camelCase for private, `_underscore` for fields).
- **Nullability**: Enable `<Nullable>enable</Nullable>` and handle warnings.

### Branching Strategy

- **`main`**: Stable, production-ready code.
- **`dev`**: Integration branch for current sprint.
- **`feature/*`**: Individual feature branches.

### Testing

- **Unit Tests**: Required for all Core logic (Agents, Parsers, Services).
- **UI Tests**: Manual verification required for XAML changes (until automated UI testing is set up).
- To run tests: `dotnet test`

---

## 5. Deployment & Packaging

### The Build Pipeline

SyncAI acts as a wrapper around the standard MSBuild pipeline.

1.  **Clean**: Remove `bin` and `obj` folders.
2.  **Restore**: `dotnet restore` to get NuGet packages.
3.  **Build**: `dotnet build` for the executable.
4.  **Publish**: Prompts user for "Self-Contained" or "Framework-Dependent".

### Build Output Structure

```text
bin/
├── Debug/
│   └── net8.0-windows10.0.19041.0/
│       ├── SyncAIAppBuilder.exe
│       ├── SyncAIAppBuilder.dll
│       ├── Microsoft.WinUI.dll
│       ├── Microsoft.WindowsAppSDK.dll
│       └── ... (other dependencies)
│
└── Release/
    └── net8.0-windows10.0.19041.0/
        ├── SyncAIAppBuilder.exe
        ├── SyncAIAppBuilder.dll
        └── ... (optimized dependencies)
```

### MSIX Packaging

**Benefits of MSIX**:

| Feature                 | Description                                                  |
| ----------------------- | ------------------------------------------------------------ |
| **Clean Installation**  | No registry pollution, complete uninstall                    |
| **Updates**             | Differential updates via `.appinstaller` (only changed bits) |
| **Resource Management** | Block-level deduplication (shared blocks across apps)        |
| **Security**            | Mandatory code signing, tamper-proof packages                |

### Automated Packaging Pipeline (Layer 2.5)

Sync AI abstracts the complexity of MSIX packaging:

1.  **Manifest Generation**: The system procedurally generates `Package.appxmanifest`, injecting Identity, Publisher, and Visual Elements.
2.  **Capability Inference**: It scans the code (Roslyn) to detect API usage (e.g., `Geolocation`) and automatically adds the required `<Capabilities>`.
3.  **Appx Bundling**:
    ```powershell
    dotnet publish -f net8.0-windows10.0.19041.0 -c Release /p:GenerateAppxPackageOnBuild=true /p:AppxPackageDir=dist/
    ```

### Code Signing

**Development Signing**:

- Visual Studio creates a temporary certificate (`SyncAI_TemporaryKey.pfx`)
- Self-signed for local testing only

**Production Signing**:

- You must sign the MSIX with a trusted certificate (from Sectigo, DigiCert, etc.)
- Microsoft Store processing will sign it for you automatically

**Complete SignTool Command**:

```powershell
SignTool sign /f MyCert.pfx /p Password /fd SHA256 /t http://timestamp.digicert.com MyApp.msix
```

**Local Trust Setup**:
If using a self-signed cert, the certificate must be installed to the "Trusted People" store on the target machine:

```powershell
certutil -addstore "TrustedPeople" MyCert.cer
```

### Deployment Requirements

| Requirement      | Details                                        |
| ---------------- | ---------------------------------------------- |
| **Target OS**    | Windows 10 Version 1809 (Build 17763) or later |
| **Dependencies** | Windows App Runtime (auto-installed)           |
| **Architecture** | x64, ARM64 (x86 deprecated)                    |

### Distribution Channels

1.  **Microsoft Store**: The primary recommended channel (handles updates automatically).
2.  **Sideloading**: Distribute the `.msixbundle` directly. Requires enabling "Developer Mode" or installing the cert.
3.  **Winget**: Submit manifest to Winget repository for CLI installation.

---

## 6. Design Philosophy & UX Principles

### The Central Principle

> **Hide complexity, show only results.**

The user should never see:

- Build errors
- Retry loops
- Stack traces
- Configuration files
- Console windows

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
│                                                              │
│   "I described my app, it built itself."                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      INTERNAL REALITY                           │
│   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐  │
│   │Parse│──►│Plan │──►│Gen  │──►│Valid│──►│Fix? │──►│Final│  │
│   └─────┘   └─────┘   └─────┘   └─────┘   └─────┘   └─────┘  │
│                                     │                          │
│                                     ▼                          │
│                               ┌───────────┐                    │
│                               │ Retry Loop│ (hidden)           │
│                               │ Infinite  │                    │
│                               └───────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

### The 5-Stage Internal Pipeline

| Stage                     | What Happens                             | User Sees                  |
| ------------------------- | ---------------------------------------- | -------------------------- |
| **1. Parse & Understand** | AI analyzes user prompt, extracts intent | "Building..."              |
| **2. Generate**           | Code is generated, files created         | "Building..."              |
| **3. Validate**           | Build attempted, errors caught           | "Building..."              |
| **4. Correct**            | Silent retry with fixes (infinite)       | "Building..."              |
| **5. Finalize**           | Success or graceful failure              | Result or friendly message |

### Design Principles for Lovable-Style Builders

#### Principle 1: Fail Silently, Succeed Loudly

- ❌ Never show error dialogs for recoverable issues
- ❌ Never expose stack traces or technical details
- ✅ Show friendly progress indicators
- ✅ Celebrate success with subtle animations

#### Principle 2: One UI, Multiple Stages

A single progress indicator represents multiple internal stages:

```
[████████░░░░░░░░░░░░] "Building..."

Internally:
  ✓ Parsed intent
  ✓ Generated XAML
  ⟳ Building... (retry attempt)
  ○ Validation pending
  ○ Finalizing
```

#### Principle 3: Intelligent Scoping

- Auto-scope user requests to achievable tasks
- Don't ask "What framework?" - infer from context
- Don't ask "What architecture?" - use defaults
- Only ask when truly ambiguous

#### Principle 4: Opinionated Defaults

Every decision has a default:

| Decision        | Default Choice        |
| --------------- | --------------------- |
| UI Framework    | WinUI 3               |
| Architecture    | MVVM                  |
| Database        | SQLite                |
| Navigation      | Frame-based           |
| State Container | CommunityToolkit.Mvvm |

#### Principle 5: Real Code Ownership

- Generated code is real, not template-based
- Users can modify, extend, and own the code
- No vendor lock-in, no proprietary runtime
- Standard .NET project structure

### Error Handling Strategy

#### User-Facing: Never Show Errors

The user should never see:

- ❌ "Build failed: CS0103 The name 'xyz' does not exist"
- ❌ "NuGet restore failed"
- ❌ "Error in line 42"

Instead, they see:

- ✅ "Still working on it..."
- ✅ "Almost there..."
- ✅ "Taking a bit longer than expected..."

#### System-Level: Categorize and Respond

| Error Type               | System Response                  | User Message                                          |
| ------------------------ | -------------------------------- | ----------------------------------------------------- |
| **Parse Errors**         | Reprompt AI with context         | "Building..."                                         |
| **Generation Errors**    | Regenerate with constraints      | "Building..."                                         |
| **Validation Errors**    | Auto-fix loop (continuous)       | "Building..."                                         |
| **Deployment Errors**    | Retry with clean build           | "Almost done..."                                      |
| **Unrecoverable Errors** | Graceful degradation, save state | "Something went wrong. Your progress has been saved." |

### Observable Behavioral Patterns

| Pattern                       | User Observation                             | Internal Implementation               |
| ----------------------------- | -------------------------------------------- | ------------------------------------- |
| **1. Generation Time**        | "Takes 30-60 seconds"                        | Multi-stage pipeline with retry loops |
| **2. No Errors Shown**        | "It just works or tells me friendly message" | Silent retry with automatic fixes     |
| **3. Surgical Updates**       | "Only changed files update"                  | Roslyn-based AST patching             |
| **4. Real Code**              | "I can read and modify everything"           | Standard .NET project structure       |
| **5. Automatic Dependencies** | "I didn't add any packages"                  | AI infers and adds NuGet packages     |

### The Psychology of "Hidden Complexity"

| Aspect               | Hidden Complexity               | Exposed Complexity                   |
| -------------------- | ------------------------------- | ------------------------------------ |
| **Cognitive Load**   | Low - User focuses on their app | High - User manages build system     |
| **Confidence**       | High - "It just works"          | Low - "Why is it failing?"           |
| **Speed Perception** | Fast - Progress indicators      | Slow - Error debugging               |
| **Trust**            | Built through reliability       | Built through understanding          |
| **Learning Curve**   | Minimal - Immediate results     | Steep - Requires technical knowledge |

### Implementation Checklist

#### UI/UX Layer

- [ ] Single progress indicator for all stages
- [ ] No error dialogs for recoverable errors
- [ ] Friendly progress messages
- [ ] Success animations
- [ ] Graceful failure messages

#### Internal Layers

- [ ] Silent retry loops (infinite until user cancels)
- [ ] Error categorization and auto-fix
- [ ] State persistence between retries
- [ ] Rollback capability

#### Code Generation Pipeline

- [ ] Deterministic output (same input → same output)
- [ ] Incremental updates (don't regenerate everything)
- [ ] Format preservation (don't reformat user code)
- [ ] Idempotent operations (safe to retry)

#### Validation Systems

- [ ] Build validation before showing result
- [ ] Runtime validation hooks
- [ ] Performance validation (startup time)

#### Error Recovery

- [ ] Automatic error classification
- [ ] AI-powered fix suggestions
- [ ] Snapshot-based rollback
- [ ] State recovery after crash

---
