# SYSTEM ARCHITECTURE

> **The Big Picture: 7-Layer Architecture, Deployment Model, Process Lifecycle & Hidden Background Systems**
>
> _Merged from: ARCHITECTURE.md, EXECUTION_ARCHITECTURE.md, EXECUTION_LIFECYCLE_SPECIFICATION.md, BACKGROUND_SYSTEMS_SPECIFICATION.md_
>
> **Related Documentation**:
>
> - [ORCHESTRATION_ENGINE.md](ORCHESTRATION_ENGINE.md) (Orchestrator Logic)
> - [CODE_INTELLIGENCE.md](CODE_INTELLIGENCE.md) (Roslyn & Indexing)
> - [UI_IMPLEMENTATION.md](UI_IMPLEMENTATION.md) (Frontend Specs)
> - [PREVIEW_SYSTEM.md](PREVIEW_SYSTEM.md) (Live Preview)
> - [USER_WORKFLOWS.md](USER_WORKFLOWS.md) (User Flows)
> - [PROJECT_HANDBOOK.md](PROJECT_HANDBOOK.md) (Dev Guide)

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [The 7-Layer Architecture](#2-the-7-layer-architecture)
3. [Intent and Specification Layer](#3-intent-and-specification-layer)
4. [Planning Layer (Task Graph / DAG)](#4-planning-layer-task-graph-dag)
5. [Multi-Agent Specifications](#5-multi-agent-specifications)
6. [Data Flow](#6-data-flow)
7. [AI Engine Integration with Preview System](#7-ai-engine-integration-with-preview-system)
8. [Validation and Silent Retry Loop](#8-validation-and-silent-retry-loop)
9. [Memory and State Layer](#9-memory-and-state-layer)
10. [Embedded Subsystems](#10-embedded-subsystems)
11. [Execution Lifecycle](#11-execution-lifecycle)
12. [Background Systems](#12-background-systems)
13. [Threading and Concurrency Model](#13-threading-and-concurrency-model)
14. [Security and Isolation](#14-security-and-isolation)
15. [Machine Variability Handling](#15-machine-variability-handling)
16. [Deployment Model](#16-deployment-model)
17. [Builder Project Structure](#17-builder-project-structure)
18. [Module Structure](#18-module-structure)
19. [System-Level Stack](#19-system-level-stack)
20. [Implementation Roadmap](#20-implementation-roadmap)
21. [Key Architectural Decisions](#21-key-architectural-decisions)
22. [Performance Considerations](#22-performance-considerations)
23. [Comparison with Traditional Approaches](#23-comparison-with-traditional-approaches)
24. [Future Evolution](#24-future-evolution)

---

## 1. System Overview

### What is Sync AI?

### What is Sync AI?

Sync AI is a **local-first, AI-powered full-stack application builder** for Windows. It is a **Windows-native autonomous software construction environment** that generates, builds, previews, and iterates on .NET applications — all in-process, with no external CLI calls.

**Mission**: To deliver a seamless, production-grade development experience where complexity is hidden, and the user prompts for results, not code.

### Core Philosophy

> "Complexity is hidden — not absent."

The user sees a simple prompt → app interface. Behind the scenes, 10+ subsystems orchestrate code generation, compilation, error recovery, and preview — all invisibly.

### Architecture Principles

| Principle              | Implementation                                    |
| ---------------------- | ------------------------------------------------- |
| **Local-First**        | All processing runs on the user's Windows machine |
| **Embedded Execution** | MSBuild, NuGet, Roslyn — all in-process via APIs  |
| **Deterministic**      | State machine governs every operation             |
| **Reversible**         | Snapshot system enables rollback at any point     |
| **Isolated**           | Each project runs in a sandboxed directory        |
| **Hidden Complexity**  | User never sees logs, retries, or internal state  |

### Core Principle: The Autonomous Construction Environment

> **"Fully internal" does NOT mean "no tools exist"**
>
> It means: All tools are **embedded services**, not user-facing developer utilities.
> Users never open an IDE, run CLI commands, or manage build systems.

**The Lovable Model (Reference)**:
Lovable feels completely "internal" and seamless, but behind the scenes it manages a Node runtime, package manager, and dev server.

**Sync AI's Windows Equivalent**:

- **Embeds .NET SDK**: No "Install .NET" step for users.
- **Manages MSBuild**: Direct API calls, no `dotnet build` CLI.
- **Wraps XAML Compilation**: Hidden behind the Preview System.
- **Controls NuGet**: In-process restoration and caching.

**Users never see these tools.** They are managed entirely by the orchestrator. This "No IDE Required" model ensures that the complexity of the .NET ecosystem is fully abstracted.

### "No IDE Required" Philosophy

The system is built as an **autonomous software construction environment**, not a developer utility.

- **Zero Tooling Exposure**: Users never open Visual Studio, run `dotnet build`, or manage NuGet manually.
- **Embedded Services**: The .NET SDK, MSBuild, and Roslyn are **internal bundled services**, not external user tools.
- **Developer-Free Workflow**: The Orchestrator and Patch Engine handle all file edits and debugging silently.
- **The Goal**: A self-contained constructor where the only external dependency is the Cloud AI reasoning.

#### Comparison: Sync AI vs. Lovable vs. Visual Studio

| Feature          | Visual Studio    | Lovable (Web)       | Sync AI (Windows)          |
| :--------------- | :--------------- | :------------------ | :------------------------- |
| **Execution**    | Developer manual | Cloud Container     | **Local Embedded**         |
| **Build System** | Explicit MSBuild | Hidden Node.js      | **Hidden MSBuild**         |
| **State**        | Files on Disk    | Ephemeral Container | **Persistent Sandbox**     |
| **Role**         | Tool for Humans  | Web App Builder     | **Autonomous Constructor** |

---

## 2. The 7-Layer Architecture

### High-Level Two-Layer View

Before diving into the 7 layers, it's critical to understand the separation between the **UI Layer** (User Experience) and the **Kernel Layer** (Execution Logic).

```mermaid
graph TD
    subgraph UI_Layer [User Interface Layer]
        Prompt[Prompt Console]
        Preview[Live Preview]
        Timeline[Version Timeline]
    end

    subgraph Kernel_Layer [Execution Kernel Layer]
        Orchestrator[Orchestrator Engine]
        Roslyn[Roslyn Indexer]
        Build[MSBuild System]
        Sandbox[Filesystem Sandbox]
    end

    UI_Layer -->|Intent| Kernel_Layer
    Kernel_Layer -->|Events/Status| UI_Layer
    Kernel_Layer -->|App Output| Preview
```

### Detailed 7-Layer Stack

```text
┌─────────────────────────────────────────────────────────────┐
│  Layer 7: User Interface (WinUI 3 / XAML)                   │
│  ─ Prompt input, real-time preview, version timeline         │
├─────────────────────────────────────────────────────────────┤
│  Layer 6: Orchestrator Engine                                │
│  ─ Task decomposition, state machine, retry logic            │
├─────────────────────────────────────────────────────────────┤
│  Layer 5: AI Agent Layer                                     │
│  ─ Multi-agent code generation, prompt engineering           │
├─────────────────────────────────────────────────────────────┤
│  Layer 4: Code Intelligence (Roslyn)                         │
│  ─ AST parsing, symbol indexing, impact analysis             │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: Patch Engine                                       │
│  ─ Transactional code mutations, conflict detection          │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Execution Kernel                                   │
│  ─ In-process MSBuild, NuGet restore, dotnet run             │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: Filesystem Sandbox + SQLite Graph DB               │
│  ─ Isolated projects, snapshots, symbol/dependency storage   │
└─────────────────────────────────────────────────────────────┘
```

### Layer Details

#### Layer 1: Filesystem Sandbox + SQLite Graph DB

**Purpose**: Isolated workspace management and persistent storage.

- Each project lives in `%AppData%/SyncAI/Workspaces/{ProjectId}/`
- Snapshots stored as compressed diffs before every mutation
- SQLite stores: files, symbols, dependencies, errors, architectural decisions, execution logs

**Workspace Structure**:

```text
%AppData%/SyncAI/
├── Workspaces/
│   └── {ProjectId}/
│       ├── src/                    ← Generated code
│       ├── .snapshots/             ← Version history
│       ├── .metadata.json          ← Project metadata
│       └── .build-output/          ← Compiled binaries
├── Database/
│   └── sync-ai.db                  ← SQLite graph DB
├── Cache/
│   ├── NuGet/                      ← Local NuGet cache
│   └── Embeddings/                 ← Vector cache
└── Logs/
    └── execution.log               ← Debug log (hidden from user)
```

#### Layer 2: Execution Kernel

**Purpose**: In-process build and run capabilities.

```csharp
public class ExecutionKernel
{
    private readonly BuildManager _buildManager;  // Microsoft.Build

    public async Task<BuildResult> BuildAsync(string projectPath, string config)
    {
        var buildParams = new BuildParameters
        {
            MaxNodeCount = Environment.ProcessorCount,
            MemoryLimit = 512 * 1024 * 1024  // 512MB limit
        };

        var request = new BuildRequestData(projectPath, globalProperties, null, new[] { "Build" }, null);

        _buildManager.BeginBuild(buildParams);
        var result = _buildManager.PendBuildRequest(request);

        return new BuildResult
        {
            Success = result.OverallResult == BuildResultCode.Success,
            Errors = result.ResultsByTarget.Values
                .SelectMany(r => r.Items.Where(i => i.ItemSpec.Contains("error")))
                .ToList(),
            Duration = stopwatch.Elapsed
        };
    }
}
```

**Key Capabilities**:

- `dotnet restore` → In-process NuGet restore via `NuGet.Commands`
- `dotnet build` → In-process MSBuild via `Microsoft.Build`
- `dotnet run` → Managed `Process` with output capture
- Structured error output (not raw CLI text)

#### Layer 3: Patch Engine

**Purpose**: Transactional, conflict-detecting, reversible code mutations.

```csharp
public interface IPatchTransaction : IAsyncDisposable
{
    Task AddAttributeAsync(string className, string attributeName);
    Task CommitAsync();
    Task RollbackAsync();
}
```

**Guarantees**:

- **Atomic**: Entire patch succeeds or fails
- **Reversible**: Snapshot available for rollback
- **Conflict-Free**: Detect overlapping changes
- **Auditable**: Track every patch

#### Implementation Pattern: Transactional Patch Engine

```csharp
public class TransactionalPatchEngine
{
    private readonly FileSystemSandbox _sandbox;
    private Stack<ISnapshot> _undoStack = new();

    /// Begin patch operation
    public async Task<IPatchTransaction> BeginPatchAsync(string filePath)
    {
        // Create snapshot before patching
        var snapshot = await _sandbox.CreateSnapshotAsync(Path.GetDirectoryName(filePath)!);
        return new PatchTransaction(filePath, snapshot, _undoStack);
    }
}

public class PatchTransaction : IPatchTransaction
{
    private readonly string _filePath;
    private List<Patch> _patches = new();
    private bool _committed = false;

    public async Task AddAttributeAsync(string className, string attributeName)
    {
        // Rosslyn SyntaxTree manipulation...
        var syntax = CSharpSyntaxTree.ParseText(await File.ReadAllTextAsync(_filePath));
        var root = syntax.GetCompilationUnitSyntax();
        // ... (Find class, add attribute via SyntaxFactory) ...
        _patches.Add(new Patch { Type = PatchType.AddAttribute, NewContent = newRoot.ToFullString() });
    }

    public async Task CommitAsync()
    {
        if (_committed) throw new InvalidOperationException("Already committed");
        // Write all patches to file
        await File.WriteAllTextAsync(_filePath, _patches.Last().NewContent);
        _committed = true;
    }

    public async Task RollbackAsync()
    {
        // Restore from snapshot if needed
    }
}
```

**Key Comparison: Traditional vs AST**:
Validation that simple LLM rewrites destroy code (formatting, comments), while AST patches (Roslyn) preserve structure safe for production.

```csharp
// Only modify target node implies:
// - Comments preserved
// - Formatting preserved
// - Minimal diffs
```

#### Layer 4: Code Intelligence (Roslyn)

**Purpose**: Deep understanding of generated code.

- Parse C# into AST (Abstract Syntax Trees)
- Detect breaking changes before build

#### Implementation: Roslyn Code Intelligence Service

```csharp
public class RoslynCodeIntelligenceService
{
    private readonly string _projectPath;
    private Compilation? _cachedCompilation;
    private Dictionary<string, ISymbol>? _symbolIndex;

    /// Build or update symbol index (Async, non-blocking)
    public async Task IndexProjectAsync()
    {
        var workspace = MSBuildWorkspace.Create();
        var project = await workspace.OpenProjectAsync(_projectPath);
        var compilation = await project.GetCompilationAsync();

        _cachedCompilation = compilation;
        _symbolIndex = new Dictionary<string, ISymbol>();

        // Recursively index all symbols in the global namespace
        IndexSymbolsRecursive(compilation.GlobalNamespace);
    }

    /// Analyze impact of changing a file
    public async Task<FileImpactAnalysis> AnalyzeChangeImpactAsync(string filePath)
    {
        // 1. Find syntax tree for file
        // 2. Find all symbols declared in file
        // 3. Find all REFERENCES to those symbols in other files
        var dependentFiles = await FindDependentFiles(filePath);

        return new FileImpactAnalysis
        {
            FilePath = filePath,
            AffectedFiles = dependentFiles,
            ImpactLevel = dependentFiles.Count > 20 ? ImpactLevel.High : ImpactLevel.Low
        };
    }

    /// Incremental Re-Indexing Strategy (Detail)
    public async Task IncrementalIndexFileAsync(string filePath)
    {
        // 1. Parse only the changed file
        var tree = await CSharpSyntaxTree.ParseTextAsync(File.ReadAllText(filePath));

        // 2. Update SyntaxTree Cache
        _syntaxTrees[filePath] = tree;

        // 3. Extract Symbols (Parallel)
        var root = await tree.GetRootAsync();
        var declaredSymbols = ExtractSymbols(root);

        // 4. Update the Symbol Graph (Atomic Swap)
        await _symbolGraph.UpdateSymbolsAsync(filePath, declaredSymbols);
    }
}
```

### detailed Schema

#### File Index

```json
{
  "files": [
    {
      "path": "Models/Customer.cs",
      "type": "class",
      "dependencies": ["System.Data", "DbContext"],
      "exports": ["Customer", "CustomerValidator"],
      "imports": ["System", "System.ComponentModel.DataAnnotations"],
      "size_bytes": 2048,
      "last_modified": "2026-02-16"
    }
  ]
}
```

#### Dependency Graph

```text
Customer.cs
  ├─ imports: DbContext
  ├─ imports: Validator
  └─ used by: CustomerService.cs

CustomerService.cs
  ├─ imports: Customer.cs
  ├─ imports: ILogger
  └─ used by: CustomerController.cs

CustomerController.cs
  ├─ imports: CustomerService.cs
  └─ user-accessible routes: /api/customers/*
```

#### Route Registry

```json
{
  "routes": [
    {
      "path": "/api/customers",
      "method": "GET",
      "handler": "CustomerController.GetAll",
      "auth_required": true,
      "roles": ["admin", "manager"]
    },
    {
      "path": "/api/customers/{id}",
      "method": "GET",
      "handler": "CustomerController.GetById",
      "auth_required": true,
      "roles": ["admin", "manager"]
    }
  ]
}
```

#### Database Schema Map

```json
{
  "tables": [
    {
      "name": "customers",
      "columns": [
        { "name": "id", "type": "int", "pk": true },
        { "name": "name", "type": "string", "nullable": false },
        { "name": "email", "type": "string", "unique": true }
      ],
      "relationships": [{ "foreign_key": "contact_id", "references": "contacts.id" }],
      "models_using": ["Customer.cs"]
    }
  ]
}
```

#### Layer 5: AI Agent Layer

**Purpose**: Multi-agent code generation.

| Agent | Responsibility |
| ----- | -------------- |

### 5.1 Agent Architecture Pattern

```mermaid
graph TD
    User[User Prompt] --> Planner

    subgraph "AI Agent Swarm"
        Planner[Architect Agent] -->|Task Graph| Orchestrator
        Orchestrator -->|Dispatch| Coder[Coder Agent]
        Orchestrator -->|Dispatch| Reviewer[Reviewer Agent]

        Coder -->|Code| Fixer[Fixer Agent]
        Reviewer -->|Critique| Fixer

        Fixer -->|Patch| System[System Core]
    end

    System -->|Build Result| Orchestrator
    Orchestrator -->|Status| UI
```

| **Planner** | Decomposes user prompt into task graph |
| **Coder** | Generates C#/XAML per task |
| **Fixer** | Patches code after build errors |
| **Reviewer** | Validates architectural consistency |

> **Note**: See [Section 3](#3-multi-agent-specifications) for detailed JSON contracts and input/output examples.

#### Layer 6: Orchestrator Engine

**Purpose**: The brain — deterministic state machine governing all operations.

**Purpose**: The brain — deterministic state machine governing all operations.

**🔴 CRITICAL FOUNDATION: Must Implement First**
Without deterministic orchestration, Roslyn indexing and patching will create nondeterministic mutation loops that silently corrupt code.

- **State Transitions**: `IDLE` → `SPEC_PARSED` → `TASK_GRAPH_READY` → `TASK_EXECUTING` → `VALIDATING` → `RETRYING` → `COMPLETED` / `FAILED`.
- **Constraint**: Only 1 mutation task at time (no parallel patching)

See [ORCHESTRATION_ENGINE.md](ORCHESTRATION_ENGINE.md) for complete details.

#### Layer 7: User Interface

**Purpose**: Thin WinUI 3 shell — hides all internal complexity.

- Single prompt input
- Real-time build progress (spinner, not logs)
- App preview (XAML renderer or full launch)
- Version timeline slider

---

## 3. Intent and Specification Layer

### Purpose

Transform unstructured user prompts into structured, machine-readable specifications that prevent hallucination and ensure consistency.

### Process

**Input:**

```
"Build a CRM with authentication, role-based access,
customer database, and analytics dashboard"
```

**Processing:**

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
    },
    {
      "id": "rbac",
      "type": "access-control",
      "roles": ["admin", "manager", "user"],
      "dependencies": ["authentication"],
      "priority": 2
    },
    {
      "id": "customer-database",
      "type": "data-model",
      "tables": ["customers", "contacts", "interactions"],
      "dependencies": ["database-setup"],
      "priority": 1
    },
    {
      "id": "analytics-dashboard",
      "type": "ui",
      "components": ["charts", "metrics", "filters"],
      "dependencies": ["customer-database", "rbac"],
      "priority": 3
    }
  ],
  "stack": {
    "ui": "WinUI3",
    "backend": ".NET8",
    "database": "SQLite",
    "auth": "Windows Authentication"
  },
  "constraints": {
    "maxComplexity": "medium",
    "requiredPackages": ["Microsoft.UI.Xaml", "System.Data.Sqlite"],
    "incompatibleFeatures": []
  }
}
```

### Benefits

- **No hallucination** - Features derived from extraction, not free-form
- **Explicit dependencies** - Clear what depends on what
- **Conflict detection** - Catch contradictory requirements early
- **Stack consistency** - All modules use same tech choices

---

## 4. Planning Layer (Task Graph / DAG)

### Purpose

Convert feature spec into an ordered, executable task graph where dependencies are explicit and parallelizable work is identified.

### Task Graph Structure

```text
Task {
  id: "setup-auth",
  type: "infrastructure",
  description: "Configure Windows Authentication",
  dependencies: ["init-project"],
  files_to_create: ["Models/User.cs", "Services/AuthService.cs"],
  validation_strategy: "compile-check",
  expected_artifacts: [
    "AuthService class",
    "User model",
    "Authentication middleware"
  ]
}
```

### Example DAG for CRM App

```text
init-project [0]
    ↓
setup-database [1]
    ↓
    ├─→ define-models [2]
    │   ├─→ customer-model
    │   ├─→ contact-model
    │   └─→ interaction-model
    │
    ├─→ setup-auth [2]
    │   ├─→ auth-service
    │   └─→ user-model
    │
    └─→ db-migrations [2]
        ├─→ create-tables
        └─→ seed-data

generate-ui [3]
    ├─→ login-page (requires: setup-auth)
    ├─→ dashboard-page (requires: setup-database)
    └─→ customer-table (requires: define-models)

wire-api-routes [4]
    ├─→ auth-routes (requires: setup-auth)
    ├─→ customer-crud (requires: customer-model)
    ├─→ analytics-routes (requires: setup-database)
    └─→ rbac-middleware (requires: setup-auth)

validation & fix [5]
    → compile & test
    → detect errors
    → auto-fix
    → retry
```

### Key Insights

- **Parallelizable work** - Tasks at same level can run concurrently
- **Dependencies clear** - Prevents race conditions
- **Validation points** - Each task has success criteria
- **Rollback safe** - Can retry individual tasks

---

## 5. Multi-Agent Specifications

### Purpose

Decompose complex app generation into specialized agents, each with narrow responsibility and deterministic output schema.

### The Agent Stack

#### 1. Architect Agent

**Responsibility:** Define overall app structure

**Input:**

```json
{
  "spec": {...},
  "task": "design-project-structure"
}
```

**Output:**

```json
{
  "project_structure": {
    "Models": ["Customer.cs", "Contact.cs"],
    "Services": ["CustomerService.cs", "AuthService.cs"],
    "UI": ["MainWindow.xaml", "CustomerPage.xaml"],
    "Database": ["DbContext.cs"]
  },
  "design_patterns": ["MVVM", "Repository", "Dependency Injection"]
}
```

#### 2. Schema Agent

**Responsibility:** Generate database models and migrations

**Input:**

```json
{
  "entities": [
    {
      "name": "Customer",
      "properties": [
        { "name": "id", "type": "int", "pk": true },
        { "name": "name", "type": "string" }
      ]
    }
  ]
}
```

**Output:**

```csharp
// Generated Customer.cs
[Table("customers")]
public class Customer
{
    [Key]
    public int Id { get; set; }

    [Required]
    [StringLength(200)]
    public string Name { get; set; }
}
```

#### 3. Frontend Agent

**Responsibility:** Generate UI components and pages

**Input:**

```json
{
  "pages": [
    {
      "name": "CustomerPage",
      "components": ["DataGrid", "Form", "Button"],
      "data_binding": "customer"
    }
  ]
}
```

**Output:**

```xaml
<Page x:Class="CRM.CustomerPage">
  <Grid>
    <DataGrid ItemsSource="{Binding Customers}" />
    <Button Content="Add" Click="OnAdd" />
  </Grid>
</Page>
```

#### 4. Backend Agent

**Responsibility:** Generate API routes and services

**Input:**

```json
{
  "routes": [
    {
      "path": "/api/customers",
      "methods": ["GET", "POST"],
      "auth_required": true
    }
  ]
}
```

**Output:**

```csharp
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CustomersController : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<CustomerDto>>> GetAll()
    {
        return await _service.GetAllAsync();
    }
}
```

#### 5. Integration Agent

**Responsibility:** Wire dependencies together

**Input:**

```json
{
  "dependencies": {
    "CustomerController": ["CustomerService"],
    "CustomerService": ["ICustomerRepository", "ILogger"]
  }
}
```

**Output:**

```csharp
// Updates Program.cs
services.AddScoped<ICustomerRepository, CustomerRepository>();
services.AddScoped<CustomerService>();
services.AddScoped<CustomersController>();
```

#### 6. Fix Agent

**Responsibility:** Detect and repair build failures

**Input:**

```json
{
  "error": "CS1503: Cannot convert type 'string' to 'int'",
  "file": "Models/Customer.cs",
  "line": 15,
  "context": "public int CustomerId { get; set; } = customerId;"
}
```

**Output:**

```csharp
// Fix suggestion
public int CustomerId { get; set; } = int.Parse(customerId);
// or
public int CustomerId { get; set; } = Convert.ToInt32(customerId);
```

### 5.2 Agent Orchestration Pattern

Detailed interaction logic between agents:

```python
# Conceptual Orchestration Logic
async def orchestrate_generation(spec, task_graph):
    for task in task_graph.topological_sort():
        context = await retrieval_service.get_context(task)

        # 1. Select Specialist Agent
        agent = agent_factory.get_agent(task.type)

        # 2. Generate Candidate Code
        candidate = await agent.generate(spec, context)

        # 3. Apply via Patch Engine (Dry Run)
        if not await patch_engine.validate(candidate):
            # 4. Self-Correction Loop
            attempts = 0
            while attempts < 3:
                error = patch_engine.get_last_error()
                candidate = await fix_agent.fix(candidate, error)
                if await patch_engine.validate(candidate):
                    break
                attempts += 1

        # 5. Commit if Valid
        if await patch_engine.validate(candidate):
            await patch_engine.commit(candidate)
```

### 5.3 Detailed Agent Orchestration Flow

**Stage 1: Planning & Structure**

```python
arch_output = architect_agent(spec)
results['architecture'] = arch_output
```

**Stage 2: Parallel Generation (tasks with no deps)**

```python
schema_output = schema_agent(spec)
auth_output = backend_agent(spec, auth_tasks)
results['schema'] = schema_output
results['auth'] = auth_output
```

**Stage 3: UI Generation (needs auth context)**

```python
ui_output = frontend_agent(spec, auth_output)
results['ui'] = ui_output
```

**Stage 4: Integration (wires everything)**

```python
integration_output = integration_agent(results)
results['integration'] = integration_output
```

**Stage 5: Build & Validate**

```python
build_result = validate_and_build()
```

**Stage 6: Auto-fix if needed**

```python
if build_result.has_errors:
    for error in build_result.errors:
        fix_output = fix_agent(error, results)
        apply_fix(fix_output)
    # Retry build
    build_result = validate_and_build()

return results, build_result
```

**Note**: All agent communications are handled through the `z-ai-web-dev-sdk`.

### 5.4 Agent Input/Output Contracts

#### Architect Agent Contract

**Input Schema:**

```json
{
  "spec": {
    "projectType": "windows-desktop-app",
    "features": [...],
    "stack": {...}
  },
  "task": "design-project-structure"
}
```

**Output Schema:**

```json
{
  "project_structure": {
    "Models": ["Customer.cs", "Contact.cs"],
    "Services": ["CustomerService.cs", "AuthService.cs"],
    "UI": ["MainWindow.xaml", "CustomerPage.xaml"],
    "Database": ["DbContext.cs"]
  },
  "design_patterns": ["MVVM", "Repository", "Dependency Injection"],
  "naming_conventions": {
    "models": "PascalCase",
    "private_fields": "_camelCase"
  }
}
```

#### Schema Agent Contract

**Input Schema:**

```json
{
  "entities": [
    {
      "name": "Customer",
      "properties": [
        { "name": "id", "type": "int", "pk": true },
        { "name": "name", "type": "string" }
      ]
    }
  ]
}
```

**Output Schema:**

```csharp
// Generated Customer.cs
[Table("customers")]
public class Customer
{
    [Key]
    public int Id { get; set; }

    [Required]
    [StringLength(200)]
    public string Name { get; set; }
}
```

#### Fix Agent Contract

**Input Schema:**

```json
{
  "error": "CS1503: Cannot convert type 'string' to 'int'",
  "file": "Models/Customer.cs",
  "line": 15,
  "context": "public int CustomerId { get; set; } = customerId;"
}
```

**Output Schema:**

```json
{
  "fix_type": "type_conversion",
  "suggestions": [
    {
      "code": "public int CustomerId { get; set; } = int.Parse(customerId);",
      "confidence": 0.85
    },
    {
      "code": "public int CustomerId { get; set; } = Convert.ToInt32(customerId);",
      "confidence": 0.9
    }
  ]
}
```

---

## 6. Data Flow and Orchestration

### 6.1 Deterministic Orchestrator Engine

The Orchestrator is the deterministic "brain" that governs all operations. It ensures that the system never enters an invalid state.

**State Machine Transitions**:

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> SPEC_PARSED: User Prompt
    SPEC_PARSED --> TASK_GRAPH_READY: AI Planning
    TASK_GRAPH_READY --> TASK_EXECUTING: Dispatch
    TASK_EXECUTING --> VALIDATING: Patch Applied
    VALIDATING --> RETRYING: Error Detected
    RETRYING --> TASK_EXECUTING: Fix Applied
    VALIDATING --> COMPLETED: Build Success
    RETRYING --> FAILED: Max Retries Exceeded
    COMPLETED --> IDLE: Ready
    FAILED --> IDLE: Reset
```

**Key Responsibilities**:

- **Concurrency Control**: Enforces "One Mutation at a Time" rule.
- **Retry Budget**: Tracks attempts (Max 3 per task, Max 10 total).
- **Error Classification**: Maps huge MSBuild logs to actionable error codes.
- **Timeout Management**: Kills hung processes after 60s.

### 6.2 Application Data Flow

```text
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
    └─ [Parallel execution where possible]
    ↓
Structured Patch Engine (Roslyn)
    ├─ Parse to AST
    ├─ Apply patches
    └─ Preserve formatting
    ↓
Build System (MSBuild)
    ├─ Compile
    ├─ [If errors] → Fix Agent → Retry
    └─ Success? → Show to user
    ↓
Live Preview / Deploy
```

**Key Insight**: What looks like "instant generation" is actually:

- Multiple agents working in parallel via the **AI Engine**
- Smart context retrieval (not full project dump)
- Automatic error fixing (hidden from user)
- Silent retries (only success shown)

- Silent retries (only success shown)

---

## 7. AI Engine Integration with Preview System

### Overview

The AI Engine generates code, but **never directly renders or displays it**. The Preview System is a separate layer that consumes AI-generated code and provides visual feedback to users.

### Integration Architecture

```
User Prompt → Orchestrator → AI Engine (Patches) → Roslyn Engine (Apply) → Preview Service (Render)
```

### Preview Modes (Parallel Support)

1. **Embedded XAML Preview**: `XamlReader.Load()` for instant visual feedback of UI components.
2. **Code View**: Syntax-highlighted read-only view of the generated source.
3. **Full Launch**: `MSBuild` compile & `Process.Start()` to run the actual executables.

### Key Separation of Concerns

| Component           | Responsibility               | Does NOT Do                      |
| ------------------- | ---------------------------- | -------------------------------- |
| **AI Engine**       | Generate code patches (JSON) | ❌ Write files, Render preview   |
| **Roslyn Engine**   | Apply patches to workspace   | ❌ Generate code, Render preview |
| **Preview Service** | Render/display code          | ❌ Generate code, Modify files   |

---

## 8. Validation and Silent Retry Loop

### Purpose

Transform potential errors into invisible internal retries, surfacing only final success to the user.

### The Loop

```text
Generate → Install Deps → Compile → Check Errors → Auto-Fix → Retry
```

### Error Classifier Strategy

```csharp
public enum ErrorType
{
    SyntaxError,           // CS1002
    MissingDependency,     // Package not found
    TypeMismatch,          // CS1503
    MissingReference,      // CS0106
    ...
}
```

**Auto-Fix Examples**:

- **Syntax Error**: Insert missing `;` via AST patch.
- **Missing Using**: Add `using Namespace;` if symbol not found.
- **Build Failure**: Running `dotnet add package` for missing nugets.

---

## 9. Memory and State Layer

### Purpose

Preserve architectural decisions and context across iterations, preventing architectural drift.

### What Gets Remembered

#### Project Memory

```json
{
  "project_id": "crm-app-001",
  "stack_decisions": {
    "ui_framework": "WinUI3",
    "database": "SQLite",
    "auth_provider": "Windows-Auth",
    "orm": "Entity Framework Core"
  },
  "architectural_decisions": {
    "pattern": "MVVM",
    "dependency_injection": "Microsoft.Extensions.DependencyInjection",
    "logging": "Serilog"
  },
  "naming_conventions": {
    "models": "PascalCase",
    "private_fields": "_camelCase",
    "public_properties": "PascalCase"
  }
}
```

#### Pattern Memory

```json
{
  "file_naming": {
    "models": "Models/{EntityName}.cs",
    "services": "Services/{EntityName}Service.cs",
    "controllers": "Controllers/{EntityName}Controller.cs",
    "views": "UI/Pages/{PageName}.xaml"
  },
  "routing_style": {
    "api_base": "/api",
    "verb_placement": "method-based",
    "resource_naming": "plural"
  },
  "code_style": {
    "async_by_default": true,
    "nullable_enabled": true,
    "use_records": false
  }
}
```

#### Error Memory

```json
{
  "error_signatures": [
    {
      "error_code": "CS1503",
      "pattern": "Cannot convert type 'string' to 'int'",
      "successful_fix": "Convert.ToInt32(value)",
      "occurrence_count": 12
    },
    {
      "error_code": "CS0103",
      "pattern": "The name 'ILogger' does not exist",
      "successful_fix": "Add using Microsoft.Extensions.Logging;",
      "occurrence_count": 8
    }
  ]
}
```

### Storage Schema

````markdown
### Detailed Storage Schema (SQLite)

```sql
-- Core project data
CREATE TABLE projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    path TEXT NOT NULL,
    created_at DATETIME,
    updated_at DATETIME
);

-- Architectural Decisions (prevent drift)
CREATE TABLE architectural_decisions (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    topic TEXT,          -- e.g., "Pattern", "Logging"
    decision TEXT,       -- e.g., "MVVM", "Serilog"
    rationale TEXT,      -- e.g., "Standard for WinUI 3"
    made_at DATETIME,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Snapshot Graph (Reversibility)
CREATE TABLE snapshots (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    label TEXT,          -- e.g., "Added Customer Model"
    parent_snapshot_id TEXT,
    timestamp DATETIME,
    is_stable BOOLEAN,   -- True if build succeeded
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- File index (for change detection)
CREATE TABLE files (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    file_path TEXT,
    content_hash TEXT,
    content_size INT,
    indexed_at DATETIME,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Symbol index (Code Intelligence)
CREATE TABLE symbols (
    id TEXT PRIMARY KEY,
    file_id TEXT,
    symbol_name TEXT,
    symbol_kind TEXT,  -- class, method, property
    line_number INT,
    namespace TEXT,
    FOREIGN KEY (file_id) REFERENCES files(id)
);

-- Dependencies (Impact Analysis)
CREATE TABLE dependencies (
    id TEXT PRIMARY KEY,
    source_file_id TEXT,
    target_symbol_id TEXT,
    dependency_type TEXT,  -- references, inherits
    FOREIGN KEY (source_file_id) REFERENCES files(id),
    FOREIGN KEY (target_symbol_id) REFERENCES symbols(id)
);

-- Build errors knowledge base
CREATE TABLE build_errors (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    error_code TEXT,  -- CS0123
    error_message TEXT,
    file_id TEXT,
    line_number INT,
    solution TEXT,  -- Validated fix
    occurrence_count INT,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Execution log (Deterministic Replay)
CREATE TABLE execution_log (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    event_type TEXT,  -- task_started, build_failed
    event_data JSON,
    timestamp DATETIME,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Semantic Embeddings (For RAG)
CREATE TABLE embeddings (
    id TEXT PRIMARY KEY,
    file_id TEXT,
    code_snippet TEXT,
    vector BLOB,      -- 1536-dim float array
    model_version TEXT,
    indexed_at DATETIME,
    FOREIGN KEY (file_id) REFERENCES files(id)
);
```
````

#### Graph Service Implementation

```csharp
public class ProjectGraphService
{
    private readonly SQLiteConnection _db;

    /// Get all symbols in project
    public async Task<List<Symbol>> GetProjectSymbolsAsync(string projectId)
    {
        return await _db.QueryAsync<Symbol>(
            @"SELECT s.* FROM symbols s
              JOIN files f ON s.file_id = f.id
              WHERE f.project_id = @projectId",
            new { projectId });
    }

    /// Find previous solutions for error
    public async Task<List<ErrorSolution>> FindErrorSolutionsAsync(string errorCode)
    {
        return await _db.QueryAsync<ErrorSolution>(
            @"SELECT error_message, solution FROM build_errors
              WHERE error_code = @errorCode
              ORDER BY occurrence_count DESC
              LIMIT 5",
            new { errorCode });
    }
}
```

````

---

## 10. Embedded Subsystems

### Why "Embedded"?

Unlike cloud builders that call external services, Sync AI runs everything locally as in-process .NET libraries:

| Component         | Traditional Approach          | Sync AI Embedded Approach                           |
| ----------------- | ----------------------------- | --------------------------------------------------- |
| **Build**         | Shell out to `dotnet build`   | `Microsoft.Build.Execution.BuildManager` in-process |
| **NuGet**         | Shell out to `dotnet restore` | `NuGet.Commands.RestoreCommand` in-process          |
| **Code Analysis** | External linter               | `Microsoft.CodeAnalysis` (Roslyn) in-process        |
| **Database**      | External DB server            | `Microsoft.Data.Sqlite` embedded                    |
| **Preview**       | External browser              | WinUI 3 `WebView2` or XAML renderer                 |

### 7.1 Preview System Data Flow

The Preview System is **NOT** just a `WebView2`. It is a bidirectional communication channel that enables "Edit-and-Continue" style workflows.

```mermaid
sequenceDiagram
    participant UI as WinUI 3 Shell
    participant WS as WebSocket Server
    participant App as Running App (WebView2)
    participant DOM as DOM Mutation Observer

    UI->>WS: 1. Inject sync.js
    WS->>App: 2. Establish Connection
    App->>DOM: 3. Observe Changes

    rect rgb(200, 255, 200)
    Note right of UI: User clicks element in Preview
    App->>WS: 4. ElementClicked(xpath)
    WS->>UI: 5. NavigateToSource(file, line)
    end

    rect rgb(200, 220, 255)
    Note right of UI: AI modifies CSS
    UI->>WS: 6. HotReload(css)
    WS->>App: 7. InjectCSS(new_css)
    App-->>UI: 8. RenderConfirmed
    end
```

#### Key Components:
1.  **sync-client.js**: Injected into the running app. Captures clicks, errors, and console logs.
2.  **BridgeService**: A local WebSocket server that routes messages between the running app and the Builder.
3.  **SourceMapper**: Translates DOM elements back to their creation location in Razor/XAML files.

### The 6 Embedded Subsystems

The architecture relies on 6 critical internal subsystems that must be implemented as embedded services:

1.  **Filesystem Sandbox**: Manages isolated workspaces, enforcing security boundaries and ensuring no cross-project contamination. It handles snapshot creation and atomic writes.
2.  **Execution Kernel**: The "engine room" that manages the .NET SDK, MSBuild, and NuGet operations in-process. It abstracts CLI complexity.
3.  **Roslyn Code Intelligence**: The "brain" that parses code into ASTs, maintains the symbol graph, and performs impact analysis for every change.
4.  **Transactional Patch Engine**: The "surgeon" that performs safe, reversible code mutations using AST manipulation, ensuring no syntax errors are introduced.
5.  **SQLite Project Graph**: The "memory" that persists the project's structure, symbols, dependencies, and execution history for intelligent decision-making.
6.  **Process Sandbox**: The "supervisor" that manages isolated execution of the generated app, enforcing resource limits and timeout policies.

### 10.1 Filesystem Sandbox (Deep Dive)

**Overview**:
The sandbox ensures that Sync AI never accidentally modifying user files outside the project scope. It acts as a virtualized file system wrapper.

**Key Responsibilities**:
- **Path Validation**: Rejects any path containing `..` or pointing outside `%AppData%/SyncAI/Workspaces/{Id}`.
- **Atomic Writes**: Uses `.tmp` files and `MoveFileEx` to ensure files are never half-written.
- **Snapshotting**: Differential compression of the entire workspace state before every mutation.

```csharp
public class FileSystemSandbox
{
    private readonly string _rootPath;
    private readonly IDiskSpaceValidator _diskValidator;

    public FileSystemSandbox(string rootPath)
    {
        _rootPath = Path.GetFullPath(rootPath);
        if (!Directory.Exists(_rootPath)) Directory.CreateDirectory(_rootPath);
    }

    public async Task WriteFileAsync(string relativePath, string content)
    {
        // 1. Security Check
        ValidatePath(relativePath);

        // 2. Resource Check
        if (!_diskValidator.HasSpace(content.Length))
            throw new InsufficientStorageException();

        var fullPath = Path.Combine(_rootPath, relativePath);
        var directory = Path.GetDirectoryName(fullPath);
        if (!Directory.Exists(directory)) Directory.CreateDirectory(directory);

        // 3. Atomic Write Pattern
        var tempPath = fullPath + ".tmp";
        await File.WriteAllTextAsync(tempPath, content);

        // 4. Move with Overwrite (Atomic on NTFS)
        File.Move(tempPath, fullPath, overwrite: true);

        // 5. Register Change for Snapshot
        _snapshotManager.RegisterChange(relativePath);
    }

    private void ValidatePath(string relativePath)
    {
        if (string.IsNullOrWhiteSpace(relativePath)) throw new ArgumentException("Invalid path");

        var fullPath = Path.GetFullPath(Path.Combine(_rootPath, relativePath));
        if (!fullPath.StartsWith(_rootPath, StringComparison.OrdinalIgnoreCase))
        {
            throw new SecurityException($"Access Warning: Path traversal attempt detected: {relativePath}");
        }

        if (IsSystemFile(relativePath))
        {
             throw new SecurityException($"Access Warning: Restricted file access: {relativePath}");
        }
    }

    public async Task<ISnapshot> CreateSnapshotAsync(string label)
    {
        // 1. Acquire Global Lock
        using (await _lock.AcquireAsync())
        {
            // 2. Compute Diff (New - Old)
            var diff = _diffEngine.ComputeDiff(_lastSnapshot, _currentWorkspace);

            // 3. Compress & Store
            var snapshotId = await _storage.SaveAsync(diff);

            // 4. Update Pointer
            _lastSnapshot = snapshotId;
            return new Snapshot(snapshotId, label, DateTime.UtcNow);
        }
    }
}
```

### 10.2 Execution Kernel (Deep Dive)

**Overview**:
The Execution Kernel wraps the .NET SDK tools (MSBuild, NuGet) into a managed API. It avoids launching `dotnet.exe` processes where possible, preferring in-process libraries for speed and control.

**Key Responsibilities**:
- **MSBuild Localization**: Uses `Microsoft.Build.Locator` to find the correct SDK without user PATH configuration.
- **NuGet Cache Management**: Maintained a local package cache to avoid redownloading common packages.
- **Build Logger**: Implementation of `ILogger` that captures MSBuild events and converts them into structural definition (Error Code, File, Line).

```csharp
public class ExecutionKernel
{
    public async Task<BuildResult> BuildAsync(string projectPath)
    {
        // 1. Verify SDK
        if (!MSBuildLocator.IsRegistered) MSBuildLocator.RegisterDefaults();

        // 2. Prepare Request
        var projectCollection = new ProjectCollection();
        var buildParams = new BuildParameters(projectCollection)
        {
            Loggers = { new StructuredLogger() } // Captures errors structually
        };

        // 3. Execute In-Process
        var buildResult = BuildManager.DefaultBuildManager.Build(
            buildParams,
            new BuildRequestData(projectPath, new Dictionary<string, string>(), null, new[] { "Build" }, null)
        );

        return new BuildResult(buildResult);
    }
}
```

```text

┌─────────────────────────────────────────────────────────┐
│ SyncAI Process │
│ │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│ │ Execution │ │ Code │ │ Patch │ │
│ │ Kernel │ │ Intelligence│ │ Engine │ │
│ │ │ │ │ │ │ │
│ │ MSBuild API │ │ Roslyn AST │ │ Transactional│ │
│ │ NuGet API │ │ Symbol Graph │ │ Writes │ │
│ │ Process Mgr │ │ Dep. Anal. │ │ Rollback │ │
│ └──────────────┘ └──────────────┘ └──────────────┘ │
│ │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│ │ Filesystem │ │ SQLite │ │ Snapshot │ │
│ │ Sandbox │ │ Graph DB │ │ Manager │ │
│ │ │ │ │ │ │ │
│ │ Isolation │ │ Symbols │ │ Versioning │ │
│ │ Path Safety │ │ Deps │ │ Diff/Patch │ │
│ │ Workspace │ │ Errors │ │ Rollback │ │
│ └──────────────┘ └──────────────┘ └──────────────┘ │
└─────────────────────────────────────────────────────────┘

````

### 10.1 FileSystem Sandbox

#### Core Implementation

The sandbox enforces isolation, preventing cross-project contamination and enabling safe rollbacks.

```csharp
public class FileSystemSandbox
{
    private readonly string _projectRoot; // e.g. "C:\Users\John\SyncAIProjects"

    /// <summary>
    /// Validates if a file path is safe to write to (Sandbox Containment)
    /// </summary>
    public bool IsPathSafe(string path)
    {
        var fullPath = Path.GetFullPath(path);
        var workspacePath = Path.GetFullPath(_projectRoot);

        // 1. Ensure path is within workspace root
        if (!fullPath.StartsWith(workspacePath, StringComparison.OrdinalIgnoreCase))
            return false;

        // 2. Block directory traversal attempts
        if (fullPath.Contains(".."))
            return false;

        // 3. Block system files
        if (Path.GetFileName(fullPath).StartsWith("."))
            return false;

        return true;
    }

    /// <summary>
    /// Writes content atomically within the sandbox
    /// </summary>
    public async Task WriteFileAsync(string projectId, string relativePath, string content)
    {
        var fullPath = Path.Combine(_projectRoot, projectId, relativePath);

        if (!IsPathSafe(fullPath))
        {
            throw new SecurityException($"Sandbox Violation: Attempted write to {fullPath}");
        }

        Directory.CreateDirectory(Path.GetDirectoryName(fullPath));
        await File.WriteAllTextAsync(fullPath, content);
    }

    /// <summary>
    /// Silently cleans build artifacts (bin/obj) to free space or reset state
    /// </summary>
    public void CleanBuildArtifacts(string projectId)
    {
        var projectDir = Path.Combine(_projectRoot, projectId);
        var bin = Path.Combine(projectDir, "bin");
        var obj = Path.Combine(projectDir, "obj");

        if (Directory.Exists(bin)) Directory.Delete(bin, true);
        if (Directory.Exists(obj)) Directory.Delete(obj, true);
    }
```

    /// Rollback to previous snapshot
    public async Task RollbackToSnapshotAsync(string projectId, string snapshotPath)
    {
        var projectSrc = Path.Combine(_projectRoot, projectId, "src");
        Directory.Delete(projectSrc, recursive: true);
        ZipFile.ExtractToDirectory(snapshotPath, projectSrc);
    }

}

````

#### Local-Only Enhancements

- **Disk Space Validation**: `DiskSpaceValidator` checks for sufficient space before snapshots.
- **Path Validation**: Prevents directory traversal attacks.
- **Snapshot Compression**: Excludes `bin`, `obj`, `.vs` to save space.

### 10.2 Execution Kernel (In-Process MSBuild)

#### Direct API Implementation

Instead of shelling out to CLI, we use `Microsoft.Build` APIs directly for performance and control.

```csharp
public class ExecutionKernel
{
    /// <summary>
    /// Builds project using Microsoft.Build APIs (No CLI)
    /// </summary>
    public async Task<BuildResult> BuildAsync(string projectPath, string configuration = "Debug")
    {
        return await Task.Run(() =>
        {
            var projectCollection = new ProjectCollection();
            try
            {
                var project = projectCollection.LoadProject(projectPath);
                project.SetProperty("Configuration", configuration);

                var buildParameters = new BuildParameters(projectCollection)
                {
                    Loggers = new[] { new StructuredLogger() },
                    MaxNodeCount = Environment.ProcessorCount
                };

                var buildRequest = new BuildRequestData(
                    project.CreateProjectInstance(),
                    new[] { "Restore", "Build" } // Restore + Build in one go
                );

                var result = BuildManager.DefaultBuildManager.Build(buildParameters, buildRequest);
                return new BuildResult { Success = result.OverallResult == BuildResultCode.Success };
            }
            finally { projectCollection.Dispose(); }
        });
    }
}
````

---

### 10.3 Patch Engine & Mutation Safety Guard

The Patch Engine is the "heart" of the builder, responsible for safely applying AI-generated changes.

#### The 5-Layer Mutation Shield (Safety Guard)

Before any patch is written to disk, it must pass a rigorous 5-layer safety check to prevent build breaks and runtime instability.

| Layer                    | Check                                        | Action on Failure               |
| :----------------------- | :------------------------------------------- | :------------------------------ |
| **1. Target Validation** | Does the file/symbol exist? Has it changed?  | **REJECT** (Stale Context)      |
| **2. Impact Radius**     | Calculate outgoing/incoming edges (Depth=2). | **ANALYZE** (Determine Scope)   |
| **3. Breaking Change**   | Does it modify public contracts or DI?       | **BLOCK** (If deps break)       |
| **4. AST Simulation**    | Dry-run apply on in-memory syntax tree.      | **REJECT** (Syntax Errors)      |
| **5. Pre-Commit Build**  | Run design-time build in sandbox.            | **REJECT** (Compilation Errors) |

#### Implementation

````csharp
public async Task<bool> ValidatePatchAsync(Patch patch)
{
    // Simulate AST modification in memory first
    var tree = await CSharpSyntaxTree.ParseTextAsync(File.ReadAllText(patch.FilePath));
    var root = await tree.GetRootAsync();

    try
    {
        var modifiedRoot = ApplyPatchToNode(root, patch);

        // Validate syntax tree (Layer 4)
        var diagnostics = modifiedRoot.GetDiagnostics();
        if (diagnostics.Any(d => d.Severity == DiagnosticSeverity.Error))
        {
            return false; // Syntax error caught before disk write
        }

        // specific semantic checks (Layers 1-3)...

```csharp
        return true;
    }
    catch
    {
        return false;
    }
}
````

### 10.4 Roslyn Code Intelligence (Deep Dive)

**Overview**: The brain that parses code into ASTs, maintains the symbol graph, and performs impact analysis.

**Key Responsibilities**:

- **Symbol Extraction**: Identifies classes, methods, properties, and their relationships.
- **Impact Analysis**: Determines which files need re-compilation or re-validation after a change.
- **Semantic Search**: Generates embeddings for code snippets to support AI retrieval.

```csharp
public class RoslynCodeIntelligence
{
    public async Task<ImpactReport> AnalyzeImpactAsync(string filePath)
    {
        var tree = await _syntaxCache.GetTreeAsync(filePath);
        var semanticModel = await _compilation.GetSemanticModelAsync(tree);

        // Find dependent files
        var symbol = semanticModel.GetDeclaredSymbol(tree.GetRoot());
        var references = await SymbolFinder.FindReferencesAsync(symbol, _solution);

        return new ImpactReport
        {
            DirectDependents = references.Select(r => r.Location.SourceTree.FilePath).Distinct(),
            RiskLevel = CalculateRisk(references.Count())
        };
    }
}
```

### 10.5 SQLite Project Graph (Deep Dive)

**Overview**: The persistent memory that records the project's structure, symbols, dependencies, and execution history.

**Key Responsibilities**:

- **Graph Persistence**: Stores the DAG of tasks and their statuses.
- **Symbol Indexing**: fast lookups for "Where is class X defined?".
- **Audit Trail**: Records every mutation, error, and fix for debugging and rollback.

**Schema Highlights**:

- `Symbols`: (Name, FileId, Type, Span)
- `Dependencies`: (SourceId, TargetId, Type)
- `TaskHistory`: (TaskId, Prompt, Result, Duration)

### 10.6 Process Sandbox (Deep Dive)

**Overview**: The supervisor that manages isolated execution of the generated app, enforcing resource limits and timeout policies.

**Key Responsibilities**:

- **Resource Quotas**: Limits CPU time and memory usage per build/run.
- **Timeout Enforcement**: Kills processes that hang (e.g., infinite loops).
- **Environment Sanitation**: Clears environment variables to prevent leakage.

```csharp
public class ProcessSandbox
{
    public async Task<int> RunSafeAsync(ProcessStartInfo info, TimeSpan timeout)
    {
        using var process = Process.Start(info);
        using var cts = new CancellationTokenSource(timeout);

        try
        {
            await process.WaitForExitAsync(cts.Token);
            return process.ExitCode;
        }
        catch (OperationCanceledException)
        {
            process.Kill(entireProcessTree: true);
            throw new TimeoutException($"Process exceeded {timeout.TotalSeconds}s limit");
        }
    }
}
```

---

### 11. Execution Lifecycle

### 11.1 Environment Validation Detail

```csharp
public async Task<ValidationResult> ValidateEnvironmentAsync()
{
    var results = new List<ValidationIssue>();

    // 1. Verify embedded .NET SDK
    var sdkValid = await VerifyEmbeddedSdkAsync();
    if (!sdkValid)
    {
        results.Add(new ValidationIssue("Embedded SDK corrupted", Severity.Critical));
    }

    // 2. Verify MSBuild
    var msbuildPath = await FindMSBuildAsync();
    if (msbuildPath == null)
    {
        results.Add(new ValidationIssue("MSBuild not accessible", Severity.Critical));
    }

    // 3. Verify NuGet integrity
    var nugetValid = await ValidateNuGetAsync();
    if (!nugetValid)
    {
        results.Add(new ValidationIssue("NuGet configuration issue", Severity.Warning));
    }

    // 4. Check disk space
    var availableGB = GetAvailableDiskSpace();
    if (availableGB < 1.0)
    {
        results.Add(new ValidationIssue("Low disk space", Severity.Warning));
    }

    // 5. Initialize SQLite connection
    await _database.InitializeAsync();

    return new ValidationResult(results);
}
```

### 11.2 Full Hidden Background Execution Lifecycle

When user types a prompt and hits "Generate", the system executes a 6-phase lifecycle. Phases 1-5 run on background threads.

### 11.3 Six-Thread Architecture

The system uses a deterministic threading model with 6 specialized thread types:

#### Thread Types and Responsibilities

**🟢 1. UI Thread (DispatcherQueue)**

- **Handles**: Rendering, button clicks, ViewModel updates, animations, status updates
- **Never blocks**: All heavy operations offloaded to worker threads
- **Implementation**:

```csharp
// All UI updates must use DispatcherQueue
private async Task UpdateUIAsync(Action action)
{
    await _dispatcherQueue.EnqueueAsync(action);
}
```

**🔵 2. Orchestrator Thread**

- **Single background thread** responsible for:
  - State machine transitions
  - Task queue management
  - Retry controller
  - Lock control
- **Must be sequential** - No parallel task execution
- **Implementation**:

```csharp
public class Orchestrator
{
    private readonly Thread _orchestratorThread;
    private readonly BlockingCollection<ExecutionSession> _executionQueue;

    public Orchestrator()
    {
        _executionQueue = new BlockingCollection<ExecutionSession>();

        _orchestratorThread = new Thread(OrchestratorLoop)
        {
            Name = "Orchestrator",
            IsBackground = true,
            Priority = ThreadPriority.AboveNormal
        };

        _orchestratorThread.Start();
    }

    private void OrchestratorLoop()
    {
        foreach (var session in _executionQueue.GetConsumingEnumerable())
        {
            try
            {
                ExecuteSessionAsync(session).Wait();
            }
            catch (Exception ex)
            {
                HandleExecutionErrorAsync(session, ex).Wait();
            }
        }
    }
}
```

**🟣 3. AI Worker Thread Pool**

- **Used for**: SDK API calls, context preparation, JSON validation
- **Parallel safe** (but limit concurrency to 2 max)
- **Implementation**:

```csharp
private static readonly SemaphoreSlim _aiConcurrencyLimit = new(2, 2);

public async Task<AIResponse> CallAIAsync(AIRequest request)
{
    await _aiConcurrencyLimit.WaitAsync();

    try
    {
        return await Task.Run(async () =>
        {
            return await _aiClient.GenerateAsync(request);
        });
    }
    finally
    {
        _aiConcurrencyLimit.Release();
    }
}
```

**🟡 4. Patch Worker Thread**

- **Handles**: Roslyn parsing, AST transformations, graph updates
- **Single-threaded** to prevent file race conditions
- **Implementation**:

```csharp
public class PatchEngine
{
    private readonly SemaphoreSlim _patchLock = new(1, 1);

    public async Task<PatchResult> ApplyPatchAsync(Patch patch)
    {
        await _patchLock.WaitAsync();

        try
        {
            return await Task.Run(async () =>
            {
                // Roslyn operations here
                return await ApplyPatchInternalAsync(patch);
            });
        }
        finally
        {
            _patchLock.Release();
        }
    }
}
```

**🔴 5. Build Worker Thread**

- **Handles**: dotnet restore, dotnet build, log parsing
- **Must run isolated. Must be killable.**
- **Implementation**:

```csharp
public class BuildKernel
{
    private Process _currentBuildProcess;

    public async Task<BuildResult> BuildProjectAsync(string projectPath)
    {
        return await Task.Run(async () =>
        {
            _currentBuildProcess = new Process { /* ... */ };

            try
            {
                return await ExecuteBuildAsync();
            }
            finally
            {
                _currentBuildProcess = null;
            }
        });
    }

    public void CancelBuild()
    {
        _currentBuildProcess?.Kill();
    }
}
```

**⚪ 6. Background Maintenance Thread**

- **Low priority thread**:
  - Snapshot pruning
  - SQLite vacuum
  - Disk usage monitoring
  - Index consistency check
- **Runs when idle only**
- **Implementation**:

```csharp
public class BackgroundMaintenance
{
    private readonly Timer _maintenanceTimer;

    public void StartMaintenance()
    {
        _maintenanceTimer = new Timer(
            callback: RunMaintenanceAsync,
            state: null,
            dueTime: TimeSpan.FromMinutes(5),
            period: TimeSpan.FromMinutes(10)
        );
    }

    private async void RunMaintenanceAsync(object state)
    {
        // Only run if orchestrator is idle
        if (_orchestrator.CurrentState != OrchestratorState.IDLE)
            return;

        await Task.Run(async () =>
        {
            await _snapshotPruner.PruneOldSnapshotsAsync();
            await _database.VacuumAsync();
            await _resourceMonitor.CheckDiskUsageAsync();
            await _indexer.ValidateConsistencyAsync();
        });
    }
}
```

### 11.4 Thread Communication Model

**Use**:

- Channels or BlockingCollection
- Immutable command objects
- Event-driven architecture
- CancellationToken everywhere

**Never**:

- Share mutable state across threads
- Allow patch + build concurrently
- Allow two builds at once

**Implementation**:

```csharp
// Immutable command
public record GenerateCommand(string Prompt, string ProjectId);

// Event-driven
public class EventAggregator
{
    private readonly ConcurrentDictionary<Type, List<Delegate>> _subscribers = new();

    public void Subscribe<T>(Action<T> handler)
    {
        _subscribers.GetOrAdd(typeof(T), _ => new List<Delegate>()).Add(handler);
    }

    public async Task PublishAsync<T>(T @event)
    {
        if (_subscribers.TryGetValue(typeof(T), out var handlers))
        {
            foreach (var handler in handlers.Cast<Action<T>>())
            {
                await Task.Run(() => handler(@event));
            }
        }
    }
}
```

### 11.5 Complete Boot Sequence (6 Stages)

When user launches the app:

#### Stage 1: App Startup (UI Thread)

```csharp
protected override async void OnLaunched(LaunchActivatedEventArgs args)
{
    // 1. Initialize WinUI window
    _window = new MainWindow();

    // 2. Show splash screen
    _window.Content = new SplashScreen { Status = "Preparing environment…" };
    _window.Activate();

    // 3. Start background initialization
    await InitializeApplicationAsync();
}
```

#### Stage 2: Environment Validation (Background Thread)

```csharp
private async Task<ValidationResult> ValidateEnvironmentAsync()
{
    var results = new List<ValidationIssue>();

    // 1. Check .NET SDK availability
    var sdkVersion = await GetDotNetSdkVersionAsync();
    if (sdkVersion == null)
    {
        results.Add(new ValidationIssue(".NET SDK not found", Severity.Critical));
    }

    // 2. Validate MSBuild path
    var msbuildPath = await FindMSBuildAsync();
    if (msbuildPath == null)
    {
        results.Add(new ValidationIssue("MSBuild not accessible", Severity.Critical));
    }

    // 3. Verify NuGet integrity
    var nugetValid = await ValidateNuGetAsync();
    if (!nugetValid)
    {
        results.Add(new ValidationIssue("NuGet configuration issue", Severity.Warning));
    }

    // 4. Check disk space
    var availableGB = GetAvailableDiskSpace();
    if (availableGB < 1.0)
    {
        results.Add(new ValidationIssue("Low disk space", Severity.Warning));
    }

    // 5. Validate workspace folder
    if (!Directory.Exists(_workspacePath))
    {
        Directory.CreateDirectory(_workspacePath);
    }

    // 6. Initialize SQLite connection
    await _database.InitializeAsync();

    return new ValidationResult(results);
}
```

#### Stage 3: Load Project Registry (Background Thread)

```csharp
private async Task LoadProjectRegistryAsync()
{
    // 1. Read Workspaces directory
    var projectDirs = Directory.GetDirectories(_workspacePath);

    foreach (var projectDir in projectDirs)
    {
        // 2. Load metadata.json
        var metadataPath = Path.Combine(projectDir, ".metadata.json");

        if (File.Exists(metadataPath))
        {
            var metadata = await JsonSerializer.DeserializeAsync<ProjectMetadata>(
                File.OpenRead(metadataPath)
            );

            // 3. Validate snapshots
            var snapshotsValid = await ValidateSnapshotsAsync(metadata.Id);

            // 4. Validate graph integrity
            var graphValid = await ValidateGraphIntegrityAsync(metadata.Id);

            if (!snapshotsValid || !graphValid)
            {
                // Attempt auto-repair
                await AttemptAutoRepairAsync(metadata.Id);
            }

            // Add to registry
            _projectRegistry.Add(metadata);
        }
    }
}
```

#### Stage 4: Initialize Services

```csharp
private void InitializeServices()
{
    // Orchestrator
    _orchestrator = new Orchestrator(_database, _eventAggregator);

    // RoslynIndexer
    _roslynIndexer = new RoslynIndexer(_database);

    // PatchEngine
    _patchEngine = new PatchEngine(_roslynIndexer, _database);

    // BuildKernel
    _buildKernel = new BuildKernel();

    // SnapshotManager
    _snapshotManager = new SnapshotManager(_database, _workspacePath);

    // AIClient (z-ai-web-dev-sdk)
    _aiClient = new AIClient(apiKey: _configuration["AI:ApiKey"]);

    // ResourceMonitor
    _resourceMonitor = new ResourceMonitor(_workspacePath);
    _resourceMonitor.StartMonitoring();
}
```

#### Stage 5: Warm-Up Index

```csharp
private async Task WarmUpIndexAsync()
{
    var lastProject = await _database.GetLastOpenedProjectAsync();

    if (lastProject != null)
    {
        // 1. Pre-load symbol graph
        await _roslynIndexer.IndexProjectAsync(lastProject.WorkspacePath);

        // 2. Pre-cache dependency tree
        await _database.CacheDependencyTreeAsync(lastProject.Id);

        // 3. Prepare AI context
        await _aiContextCache.PrepareContextAsync(lastProject.WorkspacePath);

        // This reduces first-generation latency
    }
}
```

#### Stage 6: UI Ready

```csharp
private async Task FinalizeBootAsync()
{
    // 1. Fade out splash
    await SplashScreen.FadeOutAsync(duration: 300);

    // 2. Show main window
    _window.Content = new MainPage();

    // 3. Set initial state
    var lastProject = await _database.GetLastOpenedProjectAsync();

    if (lastProject != null)
    {
        await _uiStateManager.TransitionToAsync(UIState.PREVIEW_READY);
        await LoadProjectAsync(lastProject.Id);
    }
    else
    {
        await _uiStateManager.TransitionToAsync(UIState.EMPTY_IDLE);
    }
}
```

### 11.6 Execution Phases

#### Phase 0: Pre-Execution Guard (UI Thread)

- **Validation**: Checks if Orchestrator is IDLE.
- **Lock**: Acquires workspace lock.
- **Session Init**: Creates `ExecutionSession` with unique ID.
- **UI Update**: Sets status to "Thinking...".

#### Phase 1: AI Planning (Worker Thread)

- **Context Retrieval**: Pulls relevant snippets from Vector DB.
- **Symbol Resolution**: Queries SQLite for referenced symbols.
- **Planner Agent**: Generates Task Graph (DAG).
- **Validation**: Checks for circular dependencies in tasks.

#### Phase 2: Task Execution Loop (Orchestrator Thread)

- **Topological Sort**: Orders tasks by dependency.
- **Snapshot**: Creates `pre-task` snapshot.
- **Dispatch**: Sends tasks to Worker Pool.

#### Phase 3: Patch Application (Worker Thread)

- **Code Gen**: AI Coder produces C# code.
- **AST Parsing**: Roslyn parses code to SyntaxTree.
- **Mutation**: Applies changes to existing files via `SyntaxRewriter`.
- **Atomic Write**: Saves to `.tmp` then moves to target.

#### Phase 4: Build Execution (Worker Thread)

- **Restore**: `dotnet restore` (in-process).
- **Build**: `dotnet build` (in-process).
- **Error Capture**: StructuredLogger intercepts errors.

#### Phase 5: Silent Retry Loop (AI Fix Worker)

_Only if Build fails (max 3 times)_

- **Analysis**: Classifies error (Syntax vs Logic).
- **Fix Gen**: AI Fixer proposes solution.
- **Patch**: Applies fix.
- **Retry**: Jumps back to Phase 4.

#### Phase 6: Finalization (Orchestrator Thread)

- **Commit**: Marks session as Success.
- **Preview**: Updates Live Preview.
- **Unlock**: Releases workspace lock.

```mermaid
sequenceDiagram
    participant UI as UI Thread
    participant Orch as Orchestrator
    participant Worker as Worker Thread
    participant Kernel as Build Kernel

    UI->>Orch: Submit Prompt
    Orch->>Worker: Phase 1: Plan
    Worker-->>Orch: Task Graph
    loop For Each Task
        Orch->>Worker: Phase 3: Patch
        Worker->>Kernel: Phase 4: Build
        Kernel-->>Orch: Result (Success/Fail)
        alt Fail
            Orch->>Worker: Phase 5: Silent Retry
        end
    end
    Orch->>UI: Phase 6: Finalize (Update Preview)
```

### 11.7 Crash Recovery Flow

If the application previously crashed mid-build:

```csharp
private async Task HandleCrashRecoveryAsync(ExecutionSession incompleteSession)
{
    // 1. Detect incomplete ExecutionSession
    _logger.LogWarning("Detected incomplete session: {SessionId}", incompleteSession.Id);

    // 2. Rollback to last stable snapshot
    var lastStableSnapshot = await _database.GetLastStableSnapshotAsync(
        incompleteSession.ProjectId
    );
    await _snapshotManager.RollbackAsync(lastStableSnapshot.Id);

    // 3. Mark previous version as failed
    await _database.MarkVersionAsFailedAsync(incompleteSession.Id);

    // 4. Notify user gently
    await ShowToastAsync(
        "We restored your project to a stable version.",
        severity: InfoBarSeverity.Informational
    );
}
```

### 11.8 Safety Controls During Boot

**Must enforce**:

```csharp
private async Task EnforceSafetyControlsAsync()
{
    // 1. No orphan build processes
    await KillOrphanBuildProcessesAsync();

    // 2. Clean leftover lock files
    CleanLockFiles();

    // 3. Terminate stale sessions
    await TerminateStaleSessionsAsync();

    // 4. Validate last incomplete execution
    var incompleteSession = await _database.GetIncompleteSessionAsync();

    if (incompleteSession != null)
    {
        // 5. Rollback partial snapshot if crash occurred
        await HandleCrashRecoveryAsync(incompleteSession);
    }
}
```

### 11.9 Detailed State Machine Transitions

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> AI_PLANNING: Submit Prompt
    AI_PLANNING --> SPEC_PARSED: Parse Complete
    SPEC_PARSED --> TASK_GRAPH_READY: Graph Built
    TASK_GRAPH_READY --> TASK_EXECUTING: Dispatch Task
    TASK_EXECUTING --> VALIDATING: Patch Applied
    VALIDATING --> RETRYING: Error Detected
    RETRYING --> TASK_EXECUTING: Fix Applied
    VALIDATING --> COMPLETED: Build Success
    RETRYING --> FAILED: Max Retries Exceeded
    COMPLETED --> IDLE: Ready
    FAILED --> IDLE: Reset
```

**State Descriptions**:

| State              | Description                       | User Visible?                               |
| ------------------ | --------------------------------- | ------------------------------------------- |
| `IDLE`             | Waiting for user input            | Yes (empty state)                           |
| `AI_PLANNING`      | Generating task graph from prompt | No (shows "Thinking...")                    |
| `SPEC_PARSED`      | Structured specification ready    | No                                          |
| `TASK_GRAPH_READY` | DAG of tasks prepared             | No                                          |
| `TASK_EXECUTING`   | Applying patches, generating code | No (shows "Building...")                    |
| `VALIDATING`       | Running build, checking output    | No                                          |
| `RETRYING`         | Auto-fixing errors                | No (shows "Optimizing..." after 3 attempts) |
| `COMPLETED`        | Success, ready for preview        | Yes (shows preview)                         |
| `FAILED`           | Retry budget exhausted            | Yes (shows error message)                   |

### 11.10 Complete 6-Phase Execution Lifecycle (Full Implementation)

#### Phase 0: Pre-Execution Guard

```csharp
public async Task<bool> ValidateEnvironmentAsync()
{
    // 1. Check SDK
    if (!await _sdkValidator.IsInstalledAsync("8.0")) return false;

    // 2. Check Resources
    if (_resourceMonitor.GetAvailableMemory() < 2048)
        throw new ResourceException("Insufficient RAM");

    // 3. Check Lock
    using var lock = await _lockManager.AcquireAsync("Project.Lock");
    if (!lock.IsAcquired) return false;

    return true;
}
```

#### Phase 1: Planning (Context & Token Trimming)

```csharp
public async Task<TaskGraph> PlanAsync(string prompt)
{
    // 1. Retrieve Context
    var context = await _ragService.RetrieveAsync(prompt);

    // 2. Trim to Budget
    var trimmed = _tokenGuard.Trim(context, maxTokens: 8000);

    // 3. AI Generation
    return await _plannerAgent.GenerateGraphAsync(prompt, trimmed);
}
```

#### Phase 2: Patch Application (AST Transformation)

```csharp
public async Task ApplyPatchesAsync(IEnumerable<CodePatch> patches)
{
    foreach (var patch in patches)
    {
        // 1. Create Snapshot
        await _snapshotManager.CreateSnapshotAsync();

        // 2. Apply AST Transform
        var tree = await _roslyn.GetSyntaxTreeAsync(patch.File);
        var newRoot = _patchEngine.Apply(tree, patch);

        // 3. Format & Write
        var formatted = _formatter.Format(newRoot);
        await File.WriteAllTextAsync(patch.File, formatted);
    }
}
```

#### Phase 3: Build Execution (Isolated Kernel)

```csharp
public async Task<BuildResult> ExecuteBuildAsync()
{
    var startInfo = new ProcessStartInfo
    {
        FileName = "dotnet",
        Arguments = "build --no-incremental",
        RedirectStandardOutput = true
    };

    // Run in Sandbox
    return await _processSandbox.RunAsync(startInfo, timeout: TimeSpan.FromMinutes(2));
}
```

#### Phase 4: Silent Retry Loop (Auto-Fix)

```csharp
public async Task<bool> ExecuteWithRetryAsync()
{
    for (int i = 0; i < 3; i++)
    {
        var result = await ExecuteBuildAsync();
        if (result.Success) return true;

        // AI Fix
        var fix = await _fixerAgent.AnalyzeAndFixAsync(result.Errors);
        await ApplyPatchesAsync(fix.Patches);
    }
    return false;
}
```

#### Phase 5: Finalization (Commit)

```csharp
public async Task FinalizeAsync(bool success)
{
    if (success)
    {
        await _snapshotManager.CommitAsync("Build Success");
        _ui.UpdatePreview();
    }
    else
    {
        await _snapshotManager.RollbackAsync();
        _ui.ShowError("Build Failed");
    }
}
```

### 11.11 6-Thread Threading Model (Complete Implementation)

#### 1. UI Thread (Main)

```csharp
// Only for rendering. Never block.
public void UpdateStatus(string text)
{
    _dispatcher.TryEnqueue(() => StatusLabel.Text = text);
}
```

#### 2. Orchestrator Thread (State Machine)

```csharp
// Serializes all state changes
public class OrchestratorWorker
{
    private readonly Channel<BuilderEvent> _inbox;

    public async Task ProcessLoopAsync()
    {
        await foreach (var evt in _inbox.Reader.ReadAllAsync())
        {
            var newState = _reducer.Reduce(_currentState, evt);
            _currentState = newState;
            NotifyObservers(newState); // Updates UI
        }
    }
}
```

### 11.12 Detailed Boot Sequence

**Objective**: Ensure a valid, safe state before the user can even type a prompt.

```mermaid
sequenceDiagram
    participant Launch as App Launch
    participant Env as Env Validator
    participant Lock as Workspace Lock
    participant State as State Machine
    participant UI as UI Thread

    Launch->>Env: 1. Validate Prereqs
    Env-->>Launch: SDK 8.0 OK?

    alt Missing SDK
        Launch-->>UI: Show "Install SDK" Dialog
    else Valid SDK
        Launch->>Lock: 2. Acquire Global Mutex

        alt Locked
            Lock-->>UI: Show "App Already Running"
        else Acquired
            Launch->>State: 3. Hydrate State (Load Last Project)
            State->>UI: 4. Show "Ready"
        end
    end
```

**Code Implementation**:

```csharp
public async Task BootAsync()
{
    // 1. Splash Screen
    _ui.ShowSplash("Initializing Kernel...");

    // 2. Environment Check
    var envReport = await _envValidator.ValidateAsync();
    if (!envReport.IsValid)
    {
        _ui.ShowErrorDialog("Environment Error", envReport.Message);
        return; // Halt
    }

    // 3. Workspace Lock
    if (!_mutex.WaitOne(0))
    {
        _ui.ShowErrorDialog("Conflict", "Another instance is running.");
        return; // Halt
    }

    // 4. Load Previous Session
    var lastProject = _settings.LastProjectId;
    if (lastProject != null)
    {
        await _orchestrator.LoadProjectAsync(lastProject);
    }
    else
    {
        _ui.NavigateToWelcome();
    }
}
```

### 12.6 All 5 Background Processes (Complete Implementations)

#### 1. Project Graph Synchronization

```csharp
public async Task SyncLoopAsync(CancellationToken ct)
{
    while (!ct.IsCancellationRequested)
    {
        var changes = _fileWatcher.GetAccumulatedChanges();
        if (changes.Any())
        {
            // Debounce: Wait 500ms for more changes
            await Task.Delay(500, ct);

            // Reconcile Graph
            await _graphService.ReconcileAsync(changes);
            _ui.UpdateExplorer();
        }
    }
}
```

#### 2. Incremental Indexing

```csharp
public async Task IndexingLoopAsync(Channel<string> fileQueue)
{
    await foreach (var file in fileQueue.Reader.ReadAllAsync())
    {
        // 1. Parse SDT
        var tree = await _roslyn.ParseAsync(file);

        // 2. Extract Symbols
        var symbols = _symbolExtractor.Extract(tree);

        // 3. Update SQLite
        using var tx = _db.BeginTransaction();
        _db.UpdateSymbols(file, symbols);
        tx.Commit();
    }
}
```

#### 3. Snapshot Pruning

```csharp
public async Task PruneSnapshotsAsync()
{
    // Keep max 50 snapshots
    var allSnapshots = _db.Snapshots.OrderByDescending(s => s.Date).ToList();
    if (allSnapshots.Count > 50)
    {
        var toDelete = allSnapshots.Skip(50);
        foreach (var s in toDelete)
        {
            // Delete diff file
            File.Delete(Path.Combine(_storePath, s.Id + ".diff"));
            // Delete content record
            _db.Snapshots.Remove(s);
        }
        await _db.SaveChangesAsync();
    }
}
```

#### 4. AI Context Preparation

```csharp
public async Task<Context> PrepareContextAsync(string prompt)
{
    // 1. Find relevant files (Vector Search + Symbol Match)
    var files = await _retriever.FindRelevantAsync(prompt);

    // 2. Read contents
    var contents = await _fileSystem.ReadFilesAsync(files);

    // 3. Summarize if too large
    if (_tokenCounter.Count(contents) > 32000)
    {
        return await _summarizer.SummarizeAsync(contents);
    }

    return new Context(contents);
}
```

#### 5. Environment Validation

```csharp
public async Task<bool> ValidateEnvAsync()
{
    bool sdkOk = await _process.RunAsync("dotnet --version").Success;
    bool diskOk = _disk.AvailableFreeSpace > 1_000_000_000; // 1GB
    bool writeOk = _fileSystem.CanWrite(_workspacePath);

    return sdkOk && diskOk && writeOk;
}
```

### 13. Hidden Safety Mechanisms (All 4 Systems)

#### 1. Operation Whitelist

```csharp
private static readonly HashSet<string> AllowedBinaries = new()
{
    "dotnet", "git", "npm"
};

public void EnsureSafeCommand(string fileName)
{
    if (!AllowedBinaries.Contains(fileName))
        throw new SecurityException($"Unauthorized binary: {fileName}");
}
```

#### 2. Dry-Run Patch Validation

```csharp
public bool ValidatePatchSafety(SyntaxTree original, SyntaxTree patched)
{
    // Ensure no destructive changes (e.g., deleting entire classes)
    var diagnostics = patched.GetDiagnostics();
    if (diagnostics.Any(d => d.Severity == DiagnosticSeverity.Error))
        return false;

    // Simple heuristic: Line count shouldn't drop by > 50%
    if (patched.Length < original.Length * 0.5)
        return false;

    return true;
}
```

#### 3. Retry Budget Controller

```csharp
public async Task<bool> CanRetryAsync(string taskId)
{
    var retries = await _db.GetRetryCountAsync(taskId);
    if (retries >= 3)
    {
        // Switch to "Active User Intervention" mode
        return false;
    }
    return true; // Silent retry allowed
}
```

#### 4. Token Budget Guard

```csharp
public string EnforceTokenLimit(string prompt, int maxTokens)
{
    var count = _tokenizer.Count(prompt);
    if (count <= maxTokens) return prompt;

    // Truncate middle, preserve start/end
    return _tokenizer.TruncateMiddle(prompt, maxTokens);
}
```

### 14. Machine Variability & Local Constraints

**Challenge**: Runs on user's machine, not a controlled cloud container.

#### 14.1 Resource Limitations

- **Low RAM**: If < 4GB, disable concurrent builds and reduce AI context window to 4k.
- **Slow Disk**: If HDD detected, increase I/O timeouts from 5s to 30s.
- **Offline**: If no internet, disable AI agents but allow local builds.

#### 14.2 Antivirus Interference

- **Symptom**: `AccessDenied` on `bin/` or `obj/` folders.
- **Mitigation**:
  1. Detect `UnauthorizedAccessException`.
  2. Wait 500ms (backoff).
  3. Retry file operation (up to 5 times).
  4. If failed, prompt user to exclude workspace folder.

#### 14.3 Corrupted Runtime

- **Symptom**: `dotnet build` fails with obscure SDK errors.
- **Mitigation**:
  - Built-in "Doctor" command runs `dotnet --info` and checks `global.json`.
  - Auto-generates `global.json` pointing to bundled/verified SDK version.

### 15. Security & Isolation for Untrusted Code

**Principle**: Treat generated code as untrusted until validated.

#### 15.1 Path Sanitization

- **Rule**: No operation can ever touch files outside `{WorkspaceRoot}`.
- **Mechanism**: `FileSystemSandbox` enforces `Path.GetFullPath(path).StartsWith(root)`.

#### 15.2 Forbidden Operations

- **System Access**: No `Registry`, `Process.Start` (except allowed list), `Socket` (bind).
- **Reflection**: Pre-scan code for `System.Reflection` usages that invoke dangerous types.

#### 15.3 Build Isolation

- **Process**: Builds run in a distinct process tree.
- **User**: Runs as current user (cannot drop privileges easily on Windows without admin), but limited by **Job Object** limits (RAM/CPU/Time).

#### 15.4 Network Sandbox

- **Firewall**: In future, Windows Firewall rules invoked to block outbound connections from debug process unless explicitly allowed (localhost only).
  }
  }
  }

````

#### 3. AI Worker Pool (Parallel)

```csharp
// Parallel AI calls
Parallel.ForEach(agents, agent =>
{
    var intent = agent.Analyze(prompt);
    _orchestrator.Dispatch(new AgentResultParams(intent));
});
````

#### 4. Patch Worker (Single-Writer)

```csharp
// Exclusive file access
public async Task ModifyGraphAsync(Action<Workspace> mutation)
{
    await _writeLock.WaitAsync();
    try {
        mutation(_workspace);
    } finally {
        _writeLock.Release();
    }
}
```

#### 5. Build Worker (External Process)

```csharp
// Waits on external process
public async Task BuildAsync()
{
    var process = Process.Start("dotnet", "build");
    await process.WaitForExitAsync(); // Async wait, doesn't block thread
}
```

#### 6. Background Maintenance (Low Priority)

```csharp
// Cleanup tasks
public async Task MaintenanceLoopAsync()
{
    while (!_cts.IsCancellationRequested)
    {
        await Task.Delay(TimeSpan.FromMinutes(30));
        await _snapshotPruner.PruneOldSnapshotsAsync();
        await _db.VacuumAsync();
    }
}
```

### 11.2 Execution Session Management

Every user action triggers an `ExecutionSession`. This ensures tractability and cancellation.

```csharp
public class ExecutionSession
{
    public Guid Id { get; } = Guid.NewGuid();
    public string ProjectId { get; init; }
    public string Prompt { get; init; }
    public DateTime StartTime { get; } = DateTime.UtcNow;
    public SessionStatus Status { get; set; } = SessionStatus.Running;
    public CancellationTokenSource Cts { get; } = new();

    // Track detailed phase for UI progress
    public ExecutionPhase CurrentPhase { get; set; }

    // History of what this session changed
    public List<string> ModifiedFiles { get; } = new();

    public void Cancel() => Cts.Cancel();
}
```

### Safety Controls During Boot

```csharp
private async Task EnforceSafetyControlsAsync()
{
    await KillOrphanBuildProcessesAsync();      // No orphan build processes
    CleanLockFiles();                            // Clean leftover lock files
    await TerminateStaleSessionsAsync();         // Terminate stale sessions

    var incompleteSession = await _database.GetIncompleteSessionAsync();
    if (incompleteSession != null)
    {
        await HandleCrashRecoveryAsync(incompleteSession);
    }
}
```

---

## 12. Background Systems

> These systems run invisibly. The user never knows they exist.

### 12.1 Continuous Indexer

**Runs**: After every successful patch or build
**Purpose**: Keep the symbol graph up-to-date for AI context

```csharp
public class ContinuousIndexer
{
    private readonly RoslynIndexer _indexer;
    private readonly IEventAggregator _events;

    public ContinuousIndexer(RoslynIndexer indexer, IEventAggregator events)
    {
        _indexer = indexer;
        _events = events;

        // Subscribe to file change events
        _events.Subscribe<FileChangedEvent>(OnFileChanged);
        _events.Subscribe<BuildCompletedEvent>(OnBuildCompleted);
    }

    private async void OnFileChanged(FileChangedEvent e)
    {
        // Re-index only changed files
        await _indexer.IndexFileAsync(e.FilePath);
    }

    private async void OnBuildCompleted(BuildCompletedEvent e)
    {
        if (e.Success)
        {
            // Full project re-index after successful build
            await _indexer.IndexProjectAsync(e.ProjectPath);
        }
    }
}
```

### 12.2 Project Graph Synchronization

**Purpose**: Ensure SQLite graph matches file system

**Implementation**:

```csharp
public class ProjectGraphSync
{
    private FileSystemWatcher _watcher;

    public void StartWatching(string projectPath)
    {
        _watcher = new FileSystemWatcher(projectPath)
        {
            NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite,
            Filter = "*.cs",
            IncludeSubdirectories = true
        };

        _watcher.Changed += OnFileChanged;
        _watcher.Created += OnFileCreated;
        _watcher.Deleted += OnFileDeleted;

        _watcher.EnableRaisingEvents = true;
    }

    private async void OnFileChanged(object sender, FileSystemEventArgs e)
    {
        // Reconcile state silently
        await _database.UpdateFileMetadataAsync(e.FullPath);
        await _indexer.IncrementalIndexFileAsync(e.FullPath);
    }
}
```

### 12.3 AI Context Preparation & Caching

**Purpose**: Pre-build retrieval data for faster AI calls

**Implementation**:

```csharp
public class AIContextCache
{
    public async Task PrepareContextAsync(string projectPath)
    {
        // Cache relevant files
        var relevantFiles = await _indexer.GetRelevantFilesAsync(projectPath);
        _cache.Set($"relevant_files_{projectPath}", relevantFiles);

        // Cache symbol references
        var symbols = await _indexer.GetSymbolGraphAsync();
        _cache.Set($"symbols_{projectPath}", symbols);

        // Pre-trim tokens
        var trimmedContext = await _tokenManager.TrimContextAsync(relevantFiles);
        _cache.Set($"trimmed_context_{projectPath}", trimmedContext);

        // So AI call is fast
    }
}
```

### 12.4 Snapshot Pruning Automation

**Runs**: Every 30 minutes or when disk usage exceeds threshold
**Purpose**: Prevent unbounded disk growth

```csharp
public class SnapshotPruner
{
    private const int MaxSnapshotsPerProject = 50;
    private const long MaxSnapshotSizeMB = 500;

    public async Task PruneAsync(string projectId)
    {
        var snapshots = await _database.GetSnapshotsAsync(projectId);

        // Keep latest 50
        if (snapshots.Count > MaxSnapshotsPerProject)
        {
            var toDelete = snapshots
                .OrderBy(s => s.CreatedAt)
                .Take(snapshots.Count - MaxSnapshotsPerProject);

            foreach (var snapshot in toDelete)
            {
                await _snapshotManager.DeleteSnapshotAsync(snapshot.Id);
            }
        }
    }

    public async Task ArchiveOldSnapshotsAsync(string projectId)
    {
        var snapshots = await _database.GetSnapshotsAsync(projectId);

        if (snapshots.Count > MaxSnapshots)
        {
            var toArchive = snapshots
                .OrderBy(s => s.Timestamp)
                .Take(snapshots.Count - MaxSnapshots);

            foreach (var snapshot in toArchive)
            {
                await ArchiveSnapshotAsync(snapshot.Id);
            }

            // Silent operation
            _logger.LogInformation("Archived {Count} old snapshots", toArchive.Count());
        }
    }
}
```

### 12.5 Resource Monitoring System

**Runs**: Continuous background thread
**Purpose**: Watch system resources and throttle operations

```csharp
public class ResourceMonitor
{
    private readonly Timer _timer;
    private readonly string _workspaceRoot;

    public ResourceMonitor(string workspaceRoot)
    {
        _workspaceRoot = workspaceRoot;
        _timer = new Timer(CheckResources, null, TimeSpan.Zero, TimeSpan.FromSeconds(30));
    }

    private void CheckResources(object? state)
    {
        // Check disk space
        var driveInfo = new DriveInfo(Path.GetPathRoot(_workspaceRoot));
        var availableGB = driveInfo.AvailableFreeSpace / (1024.0 * 1024 * 1024);

        if (availableGB < 1.0)
        {
            // Surface to user
            _uiStateManager.ShowLowDiskSpaceWarning();
        }

        // Check memory
        var memoryUsage = GC.GetTotalMemory(forceFullCollection: false);
        var diskSpace = new DriveInfo(Path.GetPathRoot(_workspaceRoot)).AvailableFreeSpace;

        if (memoryUsage > 1_500_000_000) // 1.5GB
        {
            _eventAggregator.Publish(new MemoryPressureEvent());
            GC.Collect(2, GCCollectionMode.Optimized);
        }

        if (diskSpace < 500_000_000) // 500MB
        {
            _eventAggregator.Publish(new LowDiskSpaceEvent());
        }

        // Check memory
        var memoryMB = memoryUsage / (1024.0 * 1024);

        if (memoryMB > 1000)
        {
            // Log internally, don't show to user yet
            _logger.LogWarning("High memory usage: {MemoryMB} MB", memoryMB);
        }

        // Check SDK
        var sdkValid = await ValidateSdkAsync();
        if (!sdkValid)
        {
            _uiStateManager.ShowSdkIssueWarning();
        }

        // All checks run silently unless threshold crossed
    }
}
```

### D. Token Budget Guard

**Purpose**: Prevents sending entire project to AI, controls context overflow

```csharp
public class TokenBudgetGuard
{
    private const int MaxTokensPerRequest = 8000;

    public async Task<string> TrimContextAsync(List<string> files)
    {
        var context = new StringBuilder();
        var tokenCount = 0;

        foreach (var file in files.OrderByDescending(f => _relevanceScorer.Score(f)))
        {
            var fileContent = await File.ReadAllTextAsync(file);
            var fileTokens = _tokenizer.CountTokens(fileContent);

            if (tokenCount + fileTokens > MaxTokensPerRequest)
            {
                var trimmed = _tokenizer.TrimToTokenLimit(fileContent, MaxTokensPerRequest - tokenCount);
                context.AppendLine(trimmed);
                break;
            }

            context.AppendLine(fileContent);
            tokenCount += fileTokens;
        }

        return context.ToString();
    }
}
```

### What the User Should NEVER See (Normal Mode)

- ❌ Task graph
- ❌ Patch operations
- ❌ Roslyn AST tree
- ❌ MSBuild raw output
- ❌ NuGet logs
- ❌ Snapshot IDs
- ❌ Retry counts
- ❌ File diffs by default

**All of this exists. But hidden.**

---

### 13. Threading and Concurrency Model

### 13.1 Threading Diagram

```mermaid
graph TD
    UI[Main UI Thread]
    Orch[Orchestrator Worker]
    Roslyn[Roslyn Single-Writer]
    Pool[ThreadPool Agents]

    UI -->|Async Command| Orch
    Orch -->|Dispatch Task| Pool
    Pool -->|Request Write| Roslyn
    Roslyn -->|Update Index| SQLite[(Project Graph)]
    Orch -->|Update Status| UI
```

### 13.2 Threading Roles & Rules

**Roles:**

- **UI Thread (DispatcherQueue)**: Handles all rendering, user input, and animations. Never blocked.
- **Orchestrator Worker**: Manages the state machine and task delegation.
- **Roslyn Single-Writer**: Exclusive thread for all indexing and graph mutations to ensure consistency.
- **Background Agents**: Thread pool for build (MSBuild), AI planning, and telemetry.

**Concurrency Rules:**

1.  **Single-Writer, Multi-Reader**: Only one thread (Patch Engine) can modify the graph/files at a time. Multiple threads (UI, AI) can read.
2.  **Workspace Lock**: Uses a global mutex `Global\Workspace_{ProjectId}` to prevent multiple app instances from opening the same project.
3.  **Strict Ordering**: `PATCH → INDEX → BUILD → COMMIT`. No overlapping steps.

### WinUI 3 Threading Pattern

```csharp
// Update UI from background task
public void UpdateStatus(string message)
{
    _dispatcherQueue.TryEnqueue(() =>
    {
        StatusText.Text = message;
        LoadingSpinner.IsActive = true;
    });
}
```

await DispatcherQueue.EnqueueAsync(() =>
{
BuildProgressText = "Compiling...";
BuildPercentage = 45;
});

````

---

## 14. Security and Isolation

### 14.1 Challenge: Generated Code Is Untrusted

The builder generates code that runs on the user's PC. Security boundaries must be enforced.

### 14.2 Explicit Constraints

| ❌ FORBIDDEN                                            | ✅ ALLOWED                          |
| ------------------------------------------------------- | ----------------------------------- |
| Arbitrary shell execution (`cmd.exe`, `powershell.exe`) | Whitelisted dotnet commands only    |
| Elevated privileges (`runas`)                           | Standard user context               |
| Registry writes                                         | Isolated file access within project |
| Directory traversal (`../../`)                          | Path validation within sandbox      |

### 14.3 Security Boundary Implementation

```csharp
public class SecurityBoundary
{
    private readonly string _projectRootPath;

    private static readonly HashSet<string> AllowedCommands = new()
    {
        "dotnet restore",
        "dotnet build",
        "dotnet run",
        "dotnet publish",
        "dotnet test",
        "dotnet clean"
    };

    public bool IsPathAllowed(string filePath)
    {
        var fullPath = Path.GetFullPath(filePath);
        var rootPath = Path.GetFullPath(_projectRootPath);

        return fullPath.StartsWith(rootPath, StringComparison.OrdinalIgnoreCase)
            && !fullPath.Contains("..");
    }

    public bool CanExecute(string command)
    {
        return AllowedCommands.Any(allowed =>
            command.StartsWith(allowed, StringComparison.OrdinalIgnoreCase));
    }
}
```

### 14.4 Operation Whitelist (LLM Constraints)

To prevent "jailbreak" attempts by the LLM, we enforce a strict whitelist of allowed operations. The LLM cannot execute arbitrary code or shell commands.

```csharp
public class OperationWhitelist
{
    private static readonly HashSet<string> AllowedOperations = new()
    {
        "ADD_CLASS",
        "MODIFY_METHOD",
        "ADD_PROPERTY",
        "ADD_DEPENDENCY",
        "UPDATE_XAML",
        "DELETE_FILE",
        "MOVE_FILE"
    };

    public bool IsOperationAllowed(string operation)
    {
        return AllowedOperations.Contains(operation);
    }

    public bool IsDependencySafe(string packageName)
    {
        // Check against known safe packages
        // Reject packages with known vulnerabilities
        return _safetyChecker.IsPackageSafe(packageName);
    }
}
```

### 14.5 Dry-Run Patch Validation

**Before applying patch**: Simulate AST modification, validate syntax tree, check node existence

**Implementation**:
```csharp
public async Task<bool> ValidatePatchAsync(Patch patch)
{
    // Simulate AST modification
    var tree = await CSharpSyntaxTree.ParseTextAsync(File.ReadAllText(patch.FilePath));
    var root = await tree.GetRootAsync();

    try
    {
        var modifiedRoot = ApplyPatchToNode(root, patch);

        // Validate syntax tree
        var diagnostics = modifiedRoot.GetDiagnostics();
        if (diagnostics.Any(d => d.Severity == DiagnosticSeverity.Error))
        {
            return false;
        }

        // Check node existence
        if (patch.Operation == PatchOperation.MODIFY_METHOD)
        {
            var method = FindMethod(root, patch.MethodName);
            if (method == null)
            {
                return false;
            }
        }

        return true;
    }
    catch
    {
        return false;
    }
}
```

### 14.6 Retry Budget Controller

**Prevents**: Infinite AI retry loops, endless build cycles, resource exhaustion

**Implementation**:
```csharp
public class RetryController
{
    private const int SilentRetryLimit = 3;
    private const int TotalRetryLimit = 10;

    public async Task<BuildResult> BuildWithRetryAsync(string projectPath)
    {
        for (int attempt = 1; attempt <= TotalRetryLimit; attempt++)
        {
            var result = await _buildKernel.BuildProjectAsync(projectPath);

            if (result.Success)
            {
                // Silent success
                _logger.LogInformation("Build succeeded on attempt {Attempt}", attempt);
                return result;
            }

            // Log internally
            _logger.LogWarning("Build failed on attempt {Attempt}: {Error}", attempt, result.Error);

            // Update UI state based on attempt count
            if (attempt > SilentRetryLimit)
            {
                // Show "Optimizing build…" to user
                _uiStateManager.TransitionTo(UIState.SOFT_RECOVERY);
            }

            // Get AI fix
            var fix = await _aiEngine.GenerateFixAsync(result.Error);

            // Apply patch
            await _patchEngine.ApplyPatchAsync(fix.Patch);

            // Exponential backoff
            await Task.Delay(TimeSpan.FromSeconds(Math.Pow(2, attempt - 1)));
        }

        // Retry budget exhausted
        return BuildResult.Failed("Retry limit exceeded");
    }
}
```

### Compliance & Data Privacy

- **User prompts not stored** (privacy-first)
- **Generated code validated** before compilation
- **API keys in secure storage** (Azure Key Vault / env vars)
- **Rate limiting** on API calls
- **Input sanitization**

````

---

## 15. Machine Variability Handling

### 15.1 The Local-Only Challenge

Unlike cloud environments with fixed infrastructure, local execution must handle:

| Issue                          | Solution                                  |
| ------------------------------ | ----------------------------------------- |
| **Embedded Runtime Corrupted** | App self-repair / Reinstall prompt        |
| **Missing Windows Runtime**    | Detected by MSIX installer                |
| **Antivirus blocking MSBuild** | Sign binaries with trusted cert           |
| **Low disk space**             | Check before build, warn user             |
| **Broken NuGet cache**         | Clear local cache, retry restore          |
| **Limited RAM**                | Use incremental builds, limit parallelism |
| **Slow disk**                  | Use smaller snapshots, avoid full ZIP     |
| **Power loss during build**    | Snapshot before = safe recovery           |

### 15.2 Embedded Runtime Validation

**Implementation**:

```csharp
public class EmbeddedEnvironmentValidator
{
    private readonly string _embeddedSdkPath;

    public bool ValidateEnvironment()
    {
        // 1. Verify MSBuild assemblies are present
        if (!File.Exists(Path.Combine(_embeddedSdkPath, "Microsoft.Build.dll")))
            return false;

        // 2. Verify .NET Runtime is functional
        // (Self-check handled by app startup)

        return true;
    }
}
```

### 15.3 Antivirus Interference Handling

**Problem**: Antivirus software may block MSBuild or NuGet operations

**Solutions**:

1. **Sign binaries with trusted certificate**
2. **Provide user guidance for exclusions**
3. **Detect and retry with delays**

**Implementation**:

```csharp
public class AntivirusAwareBuildService
{
    public async Task<BuildResult> BuildWithRetryAsync(string projectPath)
    {
        var maxRetries = 3;
        var delay = TimeSpan.FromSeconds(2);

        for (int i = 0; i < maxRetries; i++)
        {
            try
            {
                return await _buildKernel.BuildAsync(projectPath);
            }
            catch (UnauthorizedAccessException ex)
            {
                // Possibly antivirus blocking
                _logger.LogWarning("Build blocked (attempt {Attempt}): {Error}", i + 1, ex.Message);

                if (i < maxRetries - 1)
                {
                    await Task.Delay(delay);
                    delay = TimeSpan.FromSeconds(delay.TotalSeconds * 2); // Exponential backoff
                }
            }
        }

        // Suggest user add exclusion
        return BuildResult.Failed("Build blocked. Consider adding an antivirus exclusion for the workspace.");
    }
}
```

### 15.4 Resource-Based Adaptive Builds

**Implementation**:

```csharp
public class AdaptiveBuildService
{
    public async Task<BuildResult> BuildWithAdaptiveSettingsAsync(string projectPath)
    {
        // Get system resources
        var availableMemoryGB = GC.GetTotalMemory(false) / (1024.0 * 1024 * 1024);
        var processorCount = Environment.ProcessorCount;
        var driveInfo = new DriveInfo(Path.GetPathRoot(projectPath));
        var availableDiskGB = driveInfo.AvailableFreeSpace / (1024.0 * 1024 * 1024);

        // Adjust build parameters based on resources
        var buildSettings = new BuildSettings
        {
            MaxParallelTasks = availableMemoryGB < 4 ? 1 : Math.Max(1, processorCount - 1),
            EnableIncrementalBuild = availableDiskGB < 10,
            UseSparseSnapshots = availableDiskGB < 5
        };

        return await _buildKernel.BuildAsync(projectPath, buildSettings);
    }
}
```

### 15.5 Error Handling with Fallbacks

```csharp
public class MachineVariabilityHandler
{
    public async Task<BuildResult> BuildWithFallbacksAsync(
        string projectPath,
        IProgress<BuildPhase>? progress = null)
    {
        // Phase 1: Verify Embedded Environment
        if (!_envValidator.ValidateEnvironment())
        {
             return BuildResult.CriticalFailure("Embedded SDK is corrupted.");
        }

        // Phase 2: Attempt restore (In-Process)
        var restoreResult = await _kernel.BuildAsync(projectPath, "Debug"); // Restore is part of build targets
        if (!restoreResult.Success)
        {
            // Try clearing cache + retry
            if (restoreResult.HasNuGetConnectionError)
            {
                _logger.LogInformation("Clearing NuGet cache...");
                await ClearNuGetCacheAsync();

                restoreResult = await _kernel.BuildAsync(projectPath, "Debug");
                if (!restoreResult.Success)
                    return restoreResult;
            }
        }

        return restoreResult;
    }

    private async Task<bool> ClearNuGetCacheAsync()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var nugetCache = Path.Combine(localAppData, "NuGet", "v3-cache");

        try
        {
            if (Directory.Exists(nugetCache))
            {
                Directory.Delete(nugetCache, recursive: true);
                _logger.LogInformation("NuGet cache cleared");
            }
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning($"Failed to clear NuGet cache: {ex.Message}");
            return false;
        }
    }
}
```

### Critical Stability Constraints

The kernel must detect and mitigate machine variability that cloud-based systems typically avoid:

- **Environment Bootstrapping**: Automatically detect missing .NET SDKs and **guide the user through installation** or install automatically.
- **SDK Variability**: Detect missing .NET workloads (WinUI 3, XAML) and handle version mismatches.
- **Resource Intelligence**: Monitor disk space and RAM (disable parallel builds if <4GB); warn when system resources are critically low.
- **External Interference**: Detect and handle Antivirus blocking builds or NuGet cache corruption with "self-repair" strategies.
- **Corruption Recovery**: Automated partial project corruption detection and rollback via the snapshot system.

---

## 16. Deployment Model

### Detailed Comparison: Cloud vs. Local Build Model

| Factor                 | Cloud Build (e.g., Lovable/Replit) | Sync AI (Local-First)        |
| :--------------------- | :--------------------------------- | :--------------------------- |
| **Execution Location** | Remote Docker Container            | **Local User Process**       |
| **Latency**            | Network RTT + Container Boot       | **Zero (In-Process)**        |
| **Offline Capable**    | No                                 | **Yes (After AI reasoning)** |
| **Data Privacy**       | Code lives on server               | **Code stays on device**     |
| **Cost**               | High (Compute/Hosting)             | **Zero (User Hardware)**     |
| **Access to Hardware** | Abstracted/Virtual                 | **Native (GPU/File/USB)**    |
| **Persistence**        | Ephemeral (sleeps)                 | **Permanent (Filesystem)**   |
| **Ecosystem**          | Web/Node.js primarily              | **Full .NET Desktop**        |
| **Interop**            | Web APIs only                      | **COM/Win32/Local APIs**     |
| **Dependencies**       | NPM / CDN                          | **Local NuGet Cache**        |
| **Debugging**          | Browser Console                    | **Attached Debugger**        |
| **Distribution**       | Web URL                            | **MSIX / EXE**               |

### Choice A: Local Desktop Application (Current)

| Aspect               | Detail                    |
| -------------------- | ------------------------- |
| **UI**               | WinUI 3 on user's machine |
| **Orchestrator**     | On user's machine         |
| **Execution Kernel** | On user's machine         |
| **Database**         | On user's disk (SQLite)   |

**Pros**: No network latency, user owns all code, works offline, no cloud costs
**Cons**: Requires .NET 8 SDK embedded, large disk space, update distribution complexity

### Choice B: Hybrid (Future)

| Aspect           | Detail                                |
| ---------------- | ------------------------------------- |
| **UI**           | WinUI 3 on local machine              |
| **Orchestrator** | Pluggable (local or cloud)            |
| **Execution**    | Local default, cloud option for scale |
| **Database**     | Local cache + cloud sync              |

### 16.1 Detailed Local vs Cloud Comparison

**Latency Analysis**:

```
Cloud Build:
- Network RTT: 50-200ms
- Container Boot: 2-5s
- Cold Start: 5-10s
- Total: 7-15s overhead

Local Build:
- Process Spawn: 50-100ms
- MSBuild Init: 200-500ms
- Total: 250-600ms overhead
```

**Cost Analysis**:

```
Cloud Build (per user/month):
- Compute: $20-50
- Storage: $5-10
- Network: $2-5
- Total: $27-65/user/month

Local Build:
- Compute: $0 (user hardware)
- Storage: $0 (user disk)
- Network: $0 (only AI API)
- Total: $0 + AI API costs
```

### 16.2 Hybrid Architecture Details

**Implementation**:

```csharp
public class HybridExecutionService
{
    private readonly IExecutionService _localService;
    private readonly IExecutionService _cloudService;

    public async Task<BuildResult> ExecuteAsync(BuildRequest request)
    {
        // Determine execution location based on:
        // 1. Project size
        // 2. Available local resources
        // 3. User preference
        // 4. Network connectivity

        var location = DetermineExecutionLocation(request);

        return location switch
        {
            ExecutionLocation.Local => await _localService.ExecuteAsync(request),
            ExecutionLocation.Cloud => await _cloudService.ExecuteAsync(request),
            ExecutionLocation.Hybrid => await ExecuteHybridAsync(request),
            _ => await _localService.ExecuteAsync(request)
        };
    }

    private async Task<BuildResult> ExecuteHybridAsync(BuildRequest request)
    {
        // AI planning in cloud
        var plan = await _cloudService.PlanAsync(request);

        // Local execution
        var result = await _localService.ExecuteAsync(plan);

        // Sync state to cloud
        await _cloudService.SyncStateAsync(result);

        return result;
    }
}
```

### 16.3 Update Distribution Mechanisms

**MSIX Auto-Update**:

```csharp
public class UpdateService
{
    private readonly HttpClient _httpClient;
    private readonly string _updateUrl = "https://api.syncai.app/updates";

    public async Task<UpdateInfo> CheckForUpdatesAsync()
    {
        var currentVersion = Assembly.GetExecutingAssembly().GetName().Version;

        var response = await _httpClient.GetAsync($"{_updateUrl}/check?version={currentVersion}");
        var updateInfo = await response.Content.ReadFromJsonAsync<UpdateInfo>();

        return updateInfo;
    }

    public async Task DownloadAndInstallAsync(UpdateInfo update)
    {
        // Download MSIX bundle
        var bundlePath = await DownloadBundleAsync(update.DownloadUrl);

        // Verify signature
        if (!await VerifySignatureAsync(bundlePath))
        {
            throw new SecurityException("Invalid update signature");
        }

        // Trigger MSIX update
        var process = Process.Start(new ProcessStartInfo
        {
            FileName = "msixmgr.exe",
            Arguments = $"-AddPackage {bundlePath}",
            UseShellExecute = true
        });

        await process.WaitForExitAsync();
    }
}
```

**Update Channels**:

```csharp
public enum UpdateChannel
{
    Stable,      // Production releases
    Beta,        // Pre-release testing
    Canary       // Latest development builds
}

public class UpdateChannelService
{
    public UpdateChannel GetCurrentChannel()
    {
        return _configuration.GetValue<UpdateChannel>("UpdateChannel");
    }

    public async Task<IEnumerable<UpdateInfo>> GetAvailableUpdatesAsync()
    {
        var channel = GetCurrentChannel();
        var url = channel switch
        {
            UpdateChannel.Stable => "https://api.syncai.app/updates/stable",
            UpdateChannel.Beta => "https://api.syncai.app/updates/beta",
            UpdateChannel.Canary => "https://api.syncai.app/updates/canary",
            _ => "https://api.syncai.app/updates/stable"
        };

        return await _httpClient.GetFromJsonAsync<IEnumerable<UpdateInfo>>(url);
    }
}
```

### WinUI 3 Stack

- **Framework**: WinUI 3 (.NET 8)
- **Target OS**: Windows 10 Build 22621+ (Windows 11 standard)
- **Deployment**: MSIX packaging
- **UI Pattern**: MVVM Toolkit (Microsoft recommended)
- **DI**: Built-in dependency injection
- **SDK**: WinAppSDK 1.5+

```text
SyncAIAppBuilder.sln
├── SyncAIAppBuilder.Orchestration/       (Class library)
├── SyncAIAppBuilder.ExecutionKernel/     (Class library)
├── SyncAIAppBuilder.CodeIntelligence/    (Class library)
└── SyncAIAppBuilder.Desktop/             (WinUI 3 App)
    ├── App.xaml(.cs)
    ├── MainWindow.xaml(.cs)
    ├── Views/
    └── ViewModels/
```

---

## 17. Builder Project Structure

The builder application itself is partitioned to ensure clean separation between the user interface, the deterministic engine, and the local execution kernel.

```text
SyncAIAppBuilder/
├── UI/                        # WinUI 3: Prompt Console, Explorer, Logs, Status
├── Orchestrator/              # StateMachine.cs, TaskExecutor.cs, RetryController.cs
├── Kernel/                    # BuildRunner.cs, RoslynIndexer.cs, PatchEngine.cs, SandboxManager.cs
├── Memory/                    # DatabaseContext.cs, GraphRepository.cs (SQLite)
├── Services/                  # IntentService.cs, PlanningService.cs
├── Agents/                    # Specialized AI Agent logic for code generation
└── Infrastructure/            # AI Engine Wrapper (z-ai-web-dev-sdk)
```

---

## 18. Module Structure

```text
SYNC-AI-FULL-STACK-APP-BUILDER/
├── docs/                              # Documentation
│   ├── SYSTEM_ARCHITECTURE.md         # System design (this file)
│   ├── PROJECT_HANDBOOK.md            # Internal guide
│   └── ...
│
├── src/
│   ├── SyncAIAppBuilder/              # Main WinUI 3 app
│   │   ├── UI/                        # User interface (thin layer)
│   │   ├── Services/
│   │   │   ├── IntentService.cs       # Intent & spec parsing
│   │   │   ├── PlanningService.cs     # Task graph generation
│   │   │   ├── CodeIntelligenceService.cs  # Project indexing
│   │   │   ├── AgentOrchestrator.cs   # Multi-agent coordination
│   │   │   ├── PatchEngine.cs         # AST-based patching
│   │   │   ├── BuildService.cs        # MSBuild wrapper
│   │   │   ├── ErrorClassifier.cs     # Error categorization
│   │   │   ├── FixAgent.cs            # Auto-error fixing
│   │   │   └── StateManager.cs        # Persistent memory
│   │   ├── Agents/
│   │   │   ├── ArchitectAgent.cs
│   │   │   ├── SchemaAgent.cs
│   │   │   ├── FrontendAgent.cs
│   │   │   ├── BackendAgent.cs
│   │   │   └── IntegrationAgent.cs
│   │   ├── Models/
│   │   ├── ViewModels/
│   │   └── Utils/
│   │
│   ├── SyncAIAppBuilder.Core/         # Shared interfaces
│   │   ├── Interfaces/
│   │   │   ├── IAgent.cs
│   │   │   ├── ICodeGenerator.cs
│   │   │   ├── IPatchEngine.cs
│   │   │   ├── IStateManager.cs
│   │   │   └── ...
│   │   ├── Models/
│   │   └── Enums/
│   │
│   └── SyncAIAppBuilder.Tests/
│
├── templates/                         # Working templates
├── ai-agents/                         # Agent prompts
├── scripts/                           # Build automation
└── README.md
```

---

## 19. System-Level Stack

Complete stack when fully internalized:

```text
┌──────────────────────────────────────────────────┐
│          WinUI 3 Frontend (Thin Layer)           │
│    (Prompt input, progress, app preview)         │
└──────────────┬───────────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────┐
│       Orchestrator API / HTTP Layer              │
│   (Task dispatch, status queries, results)       │
└──────────────┬───────────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────┐
│         Orchestrator Engine (State Machine)      │
│  (Task graph, retries, error classification)     │
└──────────────┬───────────────────────────────────┘
               │
    ┌──────────┼──────────┐
    │          │          │
┌───▼───┐  ┌──▼───┐  ┌──▼─────┐
│ Code  │  │Patch │  │Execute │
│ Intel │  │Engine│  │Kernel  │
├───────┤  ├──────┤  ├────────┤
│Roslyn │  │Trans-│  │MSBuild │
│Indexer│  │action│  │NuGet   │
│Symbol │  │Writes│  │DotNet  │
│Graph  │  │Rollb │  │Process │
└───┬───┘  └──┬───┘  └───┬────┘
    │         │          │
    └─────────┼──────────┘
              │
    ┌─────────▼────────────┐
    │   File System        │
    │   Sandbox            │
    ├──────────────────────┤
    │ Isolated Projects    │
    │ Snapshots + Diffs    │
    │ Temp Workspaces      │
    └────────┬─────────────┘
             │
    ┌────────▼──────────────┐
    │  SQLite Graph DB      │
    ├───────────────────────┤
    │ Symbols               │
    │ Dependencies          │
    │ Errors                │
    │ Decisions             │
    │ Execution Log         │
    └───────────────────────┘
```

---

### 20. Implementation Roadmap

#### Phase 1: Foundation (Weeks 1-3)

1. **Filesystem Sandbox**: Isolation, Snapshots, Rollback.
2. **Orchestrator**: State Machine, Task Graph, Kernel hooks.
3. **Project Graph DB**: SQLite schema for Symbols, Files, Errors.

#### Phase 2: Code Intelligence (Weeks 4-6)

4. **Roslyn Indexing**: Symbol extraction, Dependency graph.
5. **Impact Analysis**: Change detection.
6. **Embedding Integration**: Semantic search.

#### Phase 3: Mutation Safety (Weeks 7-9)

7. **Patch Engine**: Transactional AST-based writes.
8. **Conflict Detection**: Prevent overlapping edits.
9. **Rollback System**: Automated recovery.

#### Phase 4: Execution & Recovery (Weeks 10-12)

10. **Execution Kernel**: In-process MSBuild/NuGet.
11. **Error Classification**: Structured diagnostics.
12. **Auto-Fix Strategies**: Self-healing loops.

#### Phase 5: Production & UI (Weeks 13-15)

13. **Testing & Hardening**: Stress tests, variability handling.
14. **Deployment Model**: MSIX packaging, Auto-update.
15. **WinUI 3 Polish**: Fluent Design, Animations.

### Threading Model

**Roles:**

- **UI Thread (DispatcherQueue)**: Handles all rendering, user input, and animations. Never blocked.
- **Orchestrator Worker**: Manages the state machine and task delegation.
- **Roslyn Single-Writer**: Exclusive thread for all indexing and graph mutations to ensure consistency.
- **Background Agents**: Thread pool for build (MSBuild), AI planning, and telemetry.

**Concurrency Rules:**

1.  **Single-Writer, Multi-Reader**: Only one thread (Patch Engine) can modify the graph/files at a time. Multiple threads (UI, AI) can read.
2.  **Workspace Lock**: Uses a global mutex `Global\Workspace_{ProjectId}` to prevent multiple app instances from opening the same project.
3.  **Strict Ordering**: `PATCH → INDEX → BUILD → COMMIT`. No overlapping steps.

### Phase 1: Foundation

1. Filesystem Sandbox (week 1)
2. Orchestrator (week 2-3) — with Execution Kernel hooks
3. Project Graph DB (week 3)

### Phase 2: Code Intelligence

4. Roslyn Indexing Service (week 4-5)
5. Impact Analysis (week 5)
6. Embedding Integration (week 6)

### Phase 3: Mutation Safety

7. Patch Engine (transaction-based) (week 7-8)
8. Conflict Detection (week 8)
9. Rollback System (week 9)

### Phase 4: Execution

10. Execution Kernel (managed .NET) (week 10-11)
11. Error Classification (week 11)
12. Auto-Fix Strategies (week 12)

### Phase 5: Production

13. Testing & Hardening (week 13-14)
14. Deployment Model (week 14-15)
15. Documentation (ongoing)

### Internalization Checklist

- ✅ Filesystem Sandbox (isolated projects, snapshots, rollback)
- ✅ Execution Kernel (managed .NET, MSBuild, NuGet)
- ✅ Code Intelligence (Roslyn indexing, symbol graph)
- ✅ Patch Engine (transactional, conflict-detecting, reversible)
- ✅ Orchestrator (deterministic state machine, task graph)
- ✅ Memory Layer (SQLite project graph, error patterns, decisions)
- ✅ Process Isolation (each build isolated, resource limits)
- ✅ Error Classification (before retry, actionable fixes)
- ✅ Snapshot Support (rollback capability)
- ✅ Deployment Model (local, cloud, or hybrid)

---

> **Status**: 🟢 Architecture Finalized — Ready for Implementation
> **Framework**: WinUI 3 (.NET 8)
> **Target OS**: Windows 10 Build 22621+
> **Deployment**: MSIX packaging

---

---

## 21. Key Architectural Decisions

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

---

## 22. Performance Considerations

### 22.1 Semantic Caching Strategy

**Purpose**: Store embeddings, reuse for similar prompts

**Implementation**:

```csharp
public class SemanticCache
{
    private readonly ConcurrentDictionary<string, CacheEntry> _cache = new();

    public async Task<T> GetOrGenerateAsync<T>(
        string key,
        Func<Task<T>> generator,
        TimeSpan? expiration = null)
    {
        if (_cache.TryGetValue(key, out var entry) && !entry.IsExpired)
        {
            return (T)entry.Value;
        }

        var value = await generator();
        _cache[key] = new CacheEntry(value, expiration ?? TimeSpan.FromMinutes(30));

        return value;
    }
}
```

### 22.2 Parallel Agent Execution

**Purpose**: Execute independent agents concurrently

**Implementation**:

```csharp
public async Task<Dictionary<string, AgentOutput>> ExecuteAgentsInParallelAsync(
    List<IAgent> agents)
{
    var results = new Dictionary<string, AgentOutput>();
    var tasks = new List<Task<(string Name, AgentOutput Output)>>();

    foreach (var agent in agents)
    {
        tasks.Add(Task.Run(async () =>
        {
            var output = await agent.ExecuteAsync();
            return (agent.Name, output);
        }));
    }

    var completed = await Task.WhenAll(tasks);

    foreach (var (name, output) in completed)
    {
        results[name] = output;
    }

    return results;
}
```

### 22.3 Incremental Build Patterns

**Purpose**: Only recompile changed modules

**Implementation**:

```csharp
public class IncrementalBuildService
{
    private readonly Dictionary<string, DateTime> _fileTimestamps = new();

    public async Task<BuildResult> BuildIncrementalAsync(string projectPath)
    {
        var changedFiles = GetChangedFiles(projectPath);

        if (changedFiles.Count == 0)
        {
            return BuildResult.Skipped("No changes detected");
        }

        // Only rebuild affected projects
        var affectedProjects = GetAffectedProjects(changedFiles);

        foreach (var project in affectedProjects)
        {
            await BuildProjectAsync(project);
        }

        UpdateTimestamps(changedFiles);

        return BuildResult.Success();
    }

    private List<string> GetChangedFiles(string projectPath)
    {
        var changedFiles = new List<string>();
        var allFiles = Directory.GetFiles(projectPath, "*.cs", SearchOption.AllDirectories);

        foreach (var file in allFiles)
        {
            var lastWrite = File.GetLastWriteTimeUtc(file);

            if (!_fileTimestamps.TryGetValue(file, out var timestamp) || lastWrite > timestamp)
            {
                changedFiles.Add(file);
            }
        }

        return changedFiles;
    }
}
```

### 22.4 Smart Context Retrieval

**Purpose**: Send ~2-5 relevant files, not entire project

**Implementation**:

```csharp
public class SmartContextRetrieval
{
    private const int MaxContextFiles = 5;
    private const int MaxTokensPerFile = 2000;

    public async Task<List<string>> GetRelevantContextAsync(
        string query,
        string projectPath)
    {
        // 1. Parse query for key terms
        var keyTerms = ExtractKeyTerms(query);

        // 2. Query symbol graph for relevant files
        var relevantSymbols = await _database.QuerySymbolsAsync(keyTerms);

        // 3. Rank by relevance
        var rankedFiles = relevantSymbols
            .GroupBy(s => s.FilePath)
            .OrderByDescending(g => g.Count())
            .Take(MaxContextFiles)
            .Select(g => g.Key)
            .ToList();

        // 4. Trim each file to relevant sections
        var context = new List<string>();
        foreach (var file in rankedFiles)
        {
            var content = await GetRelevantSectionsAsync(file, keyTerms);
            context.Add(TrimToTokenLimit(content, MaxTokensPerFile));
        }

        return context;
    }
}
```

### 22.5 Performance Optimization Summary

| Strategy                | Benefit                        | Implementation Complexity |
| ----------------------- | ------------------------------ | ------------------------- |
| **Semantic Caching**    | Reduces AI API calls by 40-60% | Medium                    |
| **Parallel Agents**     | 2-3x faster generation         | Low                       |
| **Incremental Builds**  | 5-10x faster rebuilds          | High                      |
| **Smart Retrieval**     | Stays within token limits      | Medium                    |
| **Background Indexing** | Instant context availability   | Medium                    |
| **Connection Pooling**  | Reduces database overhead      | Low                       |

---

## 23. Comparison with Traditional Approaches

| Aspect                    | Simple Generator                  | Our Multi-Agent System    |
| ------------------------- | --------------------------------- | ------------------------- |
| Code quality              | Medium (hallucinates)             | High (controlled)         |
| Build errors              | Frequent                          | Rare (auto-fixes)         |
| User experience           | See errors                        | See only success          |
| Stack reliability         | Chaotic                           | Curated & stable          |
| Iteration speed           | Fast on first pass, slow on fixes | Consistent                |
| Scalability               | Poor (context overload)           | Good (smart retrieval)    |
| Architectural consistency | Drifts over time                  | Maintained (memory layer) |

---

## 24. Future Evolution

### Phase 2: Advanced

- Template marketplace
- Custom agents for domain-specific code
- Team collaboration
- Performance profiling

### Phase 3: Production-Grade

- Cloud compilation
- Automated testing
- Security scanning
- SLA-backed reliability

---

---

# Why This Approach Works

The key insight from analyzing Lovable and similar systems:

> **The smoothness is not from simplicity — it's from sophisticated, hidden orchestration.**

Every "magic" moment (code that "just works", instant fixes, no visible errors) is the result of:

- Structured specifications (prevent hallucination)
- Multi-agents (decompose complexity)
- Smart indexing (stay in context)
- Silent retry loops (hide failures)
- Persistent memory (maintain consistency)

This is what separates production AI tools from basic generators.

---

## References

- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine, task lifecycle, build system, retry, concurrency
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn, indexing, DB schema, mutation safety
- [UI_IMPLEMENTATION.md](./UI_IMPLEMENTATION.md) — XAML specs, visual state machine
- [USER_WORKFLOWS.md](./USER_WORKFLOWS.md) — Features, refinement flows
- [PREVIEW_SYSTEM.md](./PREVIEW_SYSTEM.md) — Preview rendering, sandbox launch
- [PROJECT_HANDBOOK.md](./PROJECT_HANDBOOK.md) — Project structure, dev setup, deployment

````

---

## 25. API Contracts & Interface Specifications

### Internal Service Interfaces

**Orchestrator Service (`IOrchestrator`)**
The central control point for all mutations.
- `Task<BuilderState> DispatchAsync(BuilderEvent @event)`: Dispatches an event to the state machine.
- `Task<TaskResult> ExecuteTaskAsync(TaskDefinition task)`: Entry point for agents to request work execution.
- `BuilderContext GetCurrentContext()`: Returns the current immutable state of the builder.

**Code Intelligence Service (`IRoslynService`)**
Provides AST-based analysis and indexing.
- `Task<ProjectGraph> IndexProjectAsync(string path)`: Recursively indexes symbols in a .NET project.
- `Task<List<Symbol>> FindUsagesAsync(ISymbol symbol)`: Finds all references to a specific symbol.
- `Task<SemanticModel> GetSemanticModelAsync(string filePath)`: Returns the Roslyn semantic model for a file.

**Patch Engine (`IPatchEngine`)**
Surgically modifies source code.
- `Task<string> ApplyPatchAsync(string filePath, PatchDefinition patch)`: Applies an AST-based patch.
- `Task<bool> ValidatePatchAsync(string filePath, PatchDefinition patch)`: Checks for conflicts.

**Execution Kernel (`IExecutionKernel`)**
Manages the isolated .NET execution environment.
- `Task<BuildResult> BuildAsync(string projectPath)`: Runs an isolated MSBuild process.
- `Task<TestResult> RunTestsAsync(string projectPath)`: Executes unit tests.
- `Task<ExecutionResult> RunAppAsync(string projectPath)`: Launches the app in a controlled environment.

### AI Engine Output Contracts

**1. Project Specification Contract (`ProjectSpec`)**
High-level structural definition of the application.
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "projectId": { "type": "string" },
    "projectName": { "type": "string" },
    "stack": {
      "type": "object",
      "properties": {
        "ui": { "enum": ["WinUI3", "WPF", "Console"] },
        "language": { "const": "C#" },
        "framework": { "const": ".NET 8.0" },
        "database": { "enum": ["SQLite", "None"] }
      },
      "required": ["ui", "language", "framework"]
    },
    "features": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "type": { "type": "string" },
          "description": { "type": "string" },
          "dependencies": { "type": "array", "items": { "type": "string" } }
        },
        "required": ["id", "type", "description"]
      }
    }
  },
  "required": ["projectId", "projectName", "stack", "features"]
}
````

**2. Task Graph Contract (`TaskGraph`)**
Ordered sequence of construction steps.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "tasks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "type": { "enum": ["INFRASTRUCTURE", "MODEL", "SERVICE", "UI", "INTEGRATION", "FIX"] },
          "description": { "type": "string" },
          "targetFiles": { "type": "array", "items": { "type": "string" } },
          "dependencies": { "type": "array", "items": { "type": "string" } },
          "validationStrategy": { "enum": ["COMPILE", "UNIT_TEST", "XAML_PARSE"] }
        },
        "required": ["id", "type", "description", "targetFiles", "dependencies"]
      }
    }
  },
  "required": ["tasks"]
}
```

**3. Patch Engine Contract (`CodePatch`)**
Targeted modifications for the Patch Engine.

```json
{
  "type": "object",
  "properties": {
    "filePatches": {
      "array": {
        "items": {
          "type": "object",
          "properties": {
            "path": { "type": "string" },
            "changes": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "action": {
                    "enum": [
                      "ADD_CLASS",
                      "ADD_METHOD",
                      "ADD_PROPERTY",
                      "ADD_FIELD",
                      "MODIFY_METHOD_BODY",
                      "MODIFY_PROPERTY",
                      "INSERT_USING",
                      "REMOVE_MEMBER",
                      "UPDATE_XAML_NODE",
                      "ADD_XAML_ELEMENT",
                      "MODIFY_XAML_ATTRIBUTE"
                    ]
                  },
                  "targetSymbol": { "type": "string" },
                  "content": { "type": "string" }
                },
                "required": ["action", "content"]
              }
            }
          }
        }
      }
    }
  }
}
```

````

---

## 26. Database Specification

### Database Architecture
The system uses **SQLite** for all local data persistence. Each component has its own database file to ensure separation of concerns and enable independent backups.

**File Location**: `C:\Users\{User}\AppData\Local\SyncAIAppBuilder\Workspaces\{ProjectId}\.builder\`
- `application.db`: Application-level data (settings, projects list)
- `project_graph.db`: Symbol index, dependencies, Roslyn data
- `orchestrator.db`: State machine, event log, task history
- `build_history.db`: Build results, error classifications

### Complete Database Schemas

#### 1. Application Database (`application.db`)
```sql
CREATE TABLE Projects (
    Id TEXT PRIMARY KEY,
    Name TEXT NOT NULL,
    WorkspacePath TEXT NOT NULL UNIQUE,
    CreatedDate DATETIME NOT NULL,
    LastOpenedDate DATETIME,
    HealthStatus TEXT DEFAULT 'Unknown'
);

CREATE TABLE Settings (
    Key TEXT PRIMARY KEY,
    Value TEXT NOT NULL,
    Category TEXT,
    ModifiedDate DATETIME NOT NULL
);
````

#### 2. Project Graph Database (`project_graph.db`)

**Files Table**

```sql
CREATE TABLE files (
    id INTEGER PRIMARY KEY,
    path TEXT NOT NULL UNIQUE,
    hash TEXT NOT NULL,
    last_modified_utc TEXT NOT NULL,
    language TEXT NOT NULL,
    snapshot_id INTEGER NOT NULL
);
```

**Symbols Table**

```sql
CREATE TABLE symbols (
    id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    fully_qualified_name TEXT NOT NULL,
    kind TEXT NOT NULL,
    return_type TEXT,
    accessibility TEXT,
    snapshot_id INTEGER NOT NULL,
    FOREIGN KEY(file_id) REFERENCES files(id)
);
```

**Symbol Edges Table**

```sql
CREATE TABLE symbol_edges (
    id INTEGER PRIMARY KEY,
    from_symbol_id INTEGER NOT NULL,
    to_symbol_id INTEGER NOT NULL,
    edge_type TEXT NOT NULL, -- 'CALLS', 'INHERITS', 'IMPLEMENTS'
    snapshot_id INTEGER NOT NULL
);
```

#### 3. Orchestrator Database (`orchestrator.db`)

**Tasks Table**

```sql
CREATE TABLE Tasks (
    Id TEXT PRIMARY KEY,
    TaskType TEXT NOT NULL,
    Status TEXT NOT NULL,
    CreatedDate DATETIME NOT NULL,
    RetryCount INTEGER DEFAULT 0,
    Payload TEXT,
    Result TEXT
);
```

**Task Events (Event Sourcing)**

```sql
CREATE TABLE TaskEvents (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    TaskId TEXT NOT NULL,
    EventType TEXT NOT NULL,
    Timestamp DATETIME NOT NULL,
    EventData TEXT
);

-- Missing Tables from Deep Specification

CREATE TABLE ArchitecturalDecisions (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    SnapshotId INTEGER NOT NULL,
    DecisionType TEXT NOT NULL, -- 'PATTERN', 'LIBRARY', 'STRUCTURE'
    Reasoning TEXT NOT NULL,
    Context TEXT,
    Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE NamingConventions (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Context TEXT NOT NULL, -- 'ViewModel', 'Service', 'Test'
    Pattern TEXT NOT NULL, -- 'Regex'
    Example TEXT,
    Enforced INTEGER DEFAULT 1
);

CREATE TABLE ErrorHistory (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    ErrorCode TEXT NOT NULL,
    Frequency INTEGER DEFAULT 1,
    FirstSeen DATETIME DEFAULT CURRENT_TIMESTAMP,
    LastSeen DATETIME DEFAULT CURRENT_TIMESTAMP,
    SuccessfulFix TEXT -- 'PATCH_JSON' that solved it
);
```

#### 4. Build History Database (`build_history.db`)

**Build Results**

```sql
CREATE TABLE BuildResults (
    Id TEXT PRIMARY KEY,
    TaskId TEXT,
    Success INTEGER NOT NULL,
    DurationMs INTEGER NOT NULL,
    BuildLog TEXT
);
```

**Build Errors**

```sql
CREATE TABLE BuildErrors (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    BuildResultId TEXT NOT NULL,
    ErrorCode TEXT,
    Severity TEXT NOT NULL,
    Message TEXT NOT NULL,
    FilePath TEXT,
    LineNumber INTEGER
);
```

### Graph Update Algorithm

Updates must be **deterministic** and **transactional**.

**Scenario: On Single File Mutation**

1. **Begin Transaction**
2. **Clear Old Records**: Delete symbols/edges for file in current snapshot context.
3. **Parse & Insert**: Parse syntax tree, insert new nodes, symbols, and resolve edges.
4. **Commit Transaction**

If any step fails, the transaction rolls back, ensuring the graph never enters an inconsistent state.

### AI Retrieval Pipeline

Optimized for token efficiency.

1. **Intent Classification**: Identify target symbol and operation.
2. **Impact Analysis**: Query `symbol_edges` to find immediate dependencies (depth 1) and dependents.
3. **Context Assembly**: Prioritize System Rules > Target Code > Direct Dependencies > Error Context.
4. **Token Trimming**: Stop adding context when budget is reached.

```

---

## 27. Core Development Guide

> [!NOTE]
> This guide is for **contributors developing the SyncAI Explorer tool itself**.

### 27.1 Guided Implementation Sequence (Critical Path)
**WARNING**: Do not start with UI or Intent. The system must be built bottom-up to ensure determinism.

1.  **Phase 1: Deterministic Foundation**
    *   Implement `BuilderReducer.cs` (Pure functions only).
    *   Define `TaskSchema.cs` and immutable `BuilderEvent.cs`.
    *   Implement `IOrchestrator` interface.
    *   *Why?* Prevents "state spaghetti" in later complex agents.

2.  **Phase 2: The Graph Brain**
    *   Implement `SQLite` schema (Section 26).
    *   Implement `RoslynService.cs` (Indexing only).
    *   *Why?* Agents need a queryable world model before they can act.

3.  **Phase 3: Safe Mutation**
    *   Implement `PatchEngine.cs` (AST manipulation).
    *   Implement `SnapshotManager.cs` (Rollback).
    *   *Why?* AI will make mistakes. We need a safety net before turning it on.

4.  **Phase 4: Execution Kernel**
    *   Implement `BuildService.cs` (MSBuild wrapper).
    *   Implement `ProcessSandbox.cs`.

5.  **Phase 5: Agents & AI**
    *   Only NOW do we connect the actual LLM `ArchitectAgent`, `CoderAgent`.

### 27.2 WinUI 3 Patterns
*   **Threading**: Use `DispatcherQueue.TryEnqueue` for ALL UI updates. Never blocks.
*   **Binding**: Use `x:Bind` (compiled binding) for performance.
*   **DI**: Register services in `App.xaml.cs` (Microsoft.Extensions.DependencyInjection).
*   **MVVM**: Inherit from `ObservableObject` (CommunityToolkit.Mvvm).

### 27.3 Local Constraints & Optimization
*   **Memory**: If RAM < 8GB, disable parallel builds (`GetMaxParallelTasks`).
*   **Disk**: Warn if free space < 2GB. Prune snapshots aggressively.
*   **Nuget**: Detect corrupted local caches (`dotnet nuget locals all -clear`).
*   **Process**: Every async method MUST accept a `CancellationToken`.

### 27.4 Core Dev Workflow
*   **API Keys**: Never commit to git. Use `appsettings.local.json`.
*   **Validation**: Run `BuildKernelValidator` before every build.
*   **Logs**: Use structured logging (`Serilog`) for tracing deterministic flows.

```

---

## 28. Implementation Roadmap

### 28.1 Phase 1: Core Infrastructure (Weeks 1-4)

- [ ] **Project Setup**
  - Initialize WinUI 3 project structure
  - Configure MSIX packaging
  - Set up CI/CD pipeline

- [ ] **Database Layer**
  - Design SQLite schema
  - Implement `ProjectRegistry`
  - Create migration system

- [ ] **Basic UI Shell**
  - Main window layout
  - Navigation framework
  - Theme system

### 28.2 Phase 2: AI Integration (Weeks 5-8)

- [ ] **SDK Integration**
  - Integrate `z-ai-web-dev-sdk`
  - Implement retry logic
  - Add token budget management

- [ ] **Agent System**
  - Implement `ArchitectAgent`
  - Implement `SchemaAgent`
  - Implement `BackendAgent`
  - Implement `FrontendAgent`
  - Implement `IntegrationAgent`
  - Implement `FixAgent`

- [ ] **Context System**
  - Implement `RoslynIndexer`
  - Create context retrieval logic
  - Build dependency graph

### 28.3 Phase 3: Build System (Weeks 9-12)

- [ ] **Build Kernel**
  - Implement `BuildKernel`
  - Add error parsing
  - Create build isolation

- [ ] **Patch Engine**
  - Implement `PatchEngine`
  - Add Roslyn integration
  - Create dry-run validation

- [ ] **Snapshot System**
  - Implement `SnapshotManager`
  - Add rollback capability
  - Create pruning logic

### 28.4 Phase 4: Polish & Safety (Weeks 13-16)

- [ ] **Error Handling**
  - Implement retry controller
  - Add crash recovery
  - Create user-friendly error messages

- [ ] **Performance**
  - Optimize database queries
  - Add caching layers
  - Implement background indexing

- [ ] **Security**
  - Implement operation whitelist
  - Add path validation
  - Create security boundary

### 28.5 Phase 5: Testing & Deployment (Weeks 17-20)

- [ ] **Testing**
  - Unit tests for core components
  - Integration tests for AI pipeline
  - End-to-end tests for user flows

- [ ] **Documentation**
  - API documentation
  - User guide
  - Architecture documentation

- [ ] **Deployment**
  - MSIX package creation
  - App signing
  - Store submission preparation

### 28.6 Module Dependency Mapping

```mermaid
graph TD
    A[UI Layer] --> B[Orchestrator]
    B --> C[AI Engine]
    B --> D[Patch Engine]
    B --> E[Build Kernel]
    B --> F[Snapshot Manager]

    C --> G[Context Service]
    G --> H[Roslyn Indexer]
    G --> I[SQLite Database]

    D --> H
    D --> I

    E --> J[MSBuild]
    E --> I

    F --> I

    K[Security Boundary] --> D
    K --> E

    L[Resource Monitor] --> B
    L --> I
```

### 28.7 Risk Mitigation Strategies

| Risk                         | Mitigation                                                                |
| ---------------------------- | ------------------------------------------------------------------------- |
| **AI API instability**       | Implement retry logic, fallback to cached responses, graceful degradation |
| **Build system complexity**  | Use well-tested MSBuild APIs, extensive logging, isolation                |
| **Performance degradation**  | Profile early, implement caching, background processing                   |
| **User data loss**           | Snapshot system, crash recovery, auto-save                                |
| **Security vulnerabilities** | Operation whitelist, path validation, security audits                     |
| **Platform compatibility**   | Test on multiple Windows versions, handle missing features gracefully     |

---

## 29. Error Handling Architecture

### 29.1 Error Handling Philosophy

1. **User Never Sees Technical Details** - All errors translated to user-friendly messages
2. **Silent Recovery When Possible** - Retry automatically before showing errors
3. **Actionable Guidance** - Every error message includes next steps
4. **Preserve User Work** - Never lose user data, always snapshot before risky operations
5. **Graceful Degradation** - System remains usable even with partial failures

### 29.2 Error Severity Levels

| Level        | User Impact           | UI Indicator        | Action Required      |
| ------------ | --------------------- | ------------------- | -------------------- |
| **Info**     | None                  | Blue info icon      | None                 |
| **Warning**  | Minor, non-blocking   | Yellow warning icon | Optional user action |
| **Error**    | Blocking, recoverable | Red error icon      | User must resolve    |
| **Critical** | System-level failure  | Red with alert      | Immediate attention  |

### 29.3 Detailed Error Classification

#### Build Error Types

```csharp
public enum BuildErrorType
{
    // C# Compiler Errors (CS0001-CS9999)
    CSharpSyntaxError,              // CS1001-CS1999: Syntax errors
    CSharpSemanticError,            // CS0001-CS0999: Type/member errors
    CSharpNullabilityWarning,       // CS8600-CS8999: Nullable reference warnings

    // XAML Errors (XDG0001-XDG9999)
    XamlParseError,                 // XDG0001-XDG0999: XML/XAML syntax
    XamlBindingError,               // XDG1000-XDG1999: Data binding
    XamlResourceError,              // XDG2000-XDG2999: Resource resolution

    // NuGet Errors (NU0001-NU9999)
    NuGetPackageNotFound,           // NU1101: Package doesn't exist
    NuGetVersionConflict,           // NU1107: Version conflict
    NuGetRestoreFailed,             // NU1000: General restore failure

    // MSBuild Errors (MSB0001-MSB9999)
    MSBuildProjectFileError,        // MSB4000-MSB4999: .csproj issues
    MSBuildTargetError,             // MSB3000-MSB3999: Build target failures

    // SDK Errors
    SdkNotFound,                    // .NET SDK not installed
    SdkVersionMismatch,             // Wrong SDK version

    // Timeout
    BuildTimeout,                   // Build exceeded timeout

    // Unknown
    UnknownBuildError
}
```

#### AI Engine Error Types

```csharp
public enum AIErrorType
{
    // API Errors
    ApiKeyMissing,                  // No API key configured
    ApiKeyInvalid,                  // Invalid API key
    ApiRateLimitExceeded,           // Too many requests
    ApiQuotaExceeded,               // Monthly quota exceeded
    ApiNetworkError,                // Network connectivity issue
    ApiTimeout,                     // Request timeout

    // Response Errors
    InvalidJsonResponse,            // Malformed JSON
    SchemaValidationFailed,         // Response doesn't match schema
    EmptyResponse,                  // No content returned

    // Content Errors
    ContentPolicyViolation,         // Prompt violates content policy
    TokenLimitExceeded,             // Prompt too long

    // Model Errors
    ModelNotAvailable,              // Selected model unavailable
    ModelDeprecated,                // Model no longer supported

    UnknownAIError
}
```

### 29.4 Retry Strategy with Exponential Backoff

```csharp
public class RetryPolicy
{
    public int MaxRetries { get; set; } = 3;
    public TimeSpan InitialDelay { get; set; } = TimeSpan.FromSeconds(1);
    public double BackoffMultiplier { get; set; } = 2.0;
    public TimeSpan MaxDelay { get; set; } = TimeSpan.FromSeconds(30);

    public async Task<T> ExecuteAsync<T>(
        Func<Task<T>> operation,
        Func<Exception, bool> shouldRetry)
    {
        var attempt = 0;
        var delay = InitialDelay;

        while (true)
        {
            try
            {
                return await operation();
            }
            catch (Exception ex) when (shouldRetry(ex) && attempt < MaxRetries)
            {
                attempt++;
                _logger.LogWarning(ex, "Attempt {Attempt} failed, retrying in {Delay}ms",
                    attempt, delay.TotalMilliseconds);

                await Task.Delay(delay);
                delay = TimeSpan.FromMilliseconds(
                    Math.Min(delay.TotalMilliseconds * BackoffMultiplier, MaxDelay.TotalMilliseconds));
            }
        }
    }
}
```

### 29.5 Retry Decision Matrix

| Error Type          | Retry? | Max Retries | Strategy             |
| ------------------- | ------ | ----------- | -------------------- |
| **Network Errors**  | ✅ Yes | 3           | Exponential backoff  |
| **API Rate Limit**  | ✅ Yes | 5           | Fixed delay (60s)    |
| **Syntax Errors**   | ✅ Yes | 3           | AI re-generation     |
| **Build Timeout**   | ✅ Yes | 1           | Increase timeout     |
| **SDK Not Found**   | ❌ No  | 0           | User must install    |
| **API Key Invalid** | ❌ No  | 0           | User must fix        |
| **Disk Full**       | ❌ No  | 0           | User must free space |

### 29.6 Auto-Fix Strategies

```csharp
public class BuildErrorRecoveryService
{
    public async Task<RecoveryResult> RecoverFromBuildErrorAsync(BuildError error)
    {
        return error.ErrorType switch
        {
            BuildErrorType.CSharpSyntaxError => await RecoverFromSyntaxErrorAsync(error),
            BuildErrorType.XamlParseError => await RecoverFromXamlErrorAsync(error),
            BuildErrorType.NuGetPackageNotFound => await RecoverFromNuGetErrorAsync(error),
            BuildErrorType.BuildTimeout => await RecoverFromTimeoutAsync(error),
            _ => RecoveryResult.Failed("No recovery strategy available")
        };
    }

    private async Task<RecoveryResult> RecoverFromSyntaxErrorAsync(BuildError error)
    {
        // 1. Extract error context
        var context = await ExtractErrorContextAsync(error);

        // 2. Ask AI to fix
        var fixPrompt = $@"
            The following code has a syntax error:

            File: {error.FilePath}
            Line: {error.LineNumber}
            Error: {error.Message}

            Code context:
            {context}

            Please provide a patch to fix this error.
        ";

        var patch = await _aiEngine.GeneratePatchAsync(fixPrompt);

        // 3. Apply patch
        var result = await _patchEngine.ApplyPatchAsync(patch);

        if (result.Success)
        {
            return RecoveryResult.Success("Syntax error fixed automatically");
        }

        return RecoveryResult.Failed("Unable to fix syntax error automatically");
    }
}
```

### 29.7 Circuit Breaker Pattern

```csharp
public class CircuitBreaker
{
    private int _failureCount;
    private DateTime _lastFailureTime;
    private CircuitState _state = CircuitState.Closed;

    private readonly int _failureThreshold = 5;
    private readonly TimeSpan _timeout = TimeSpan.FromMinutes(1);

    public async Task<T> ExecuteAsync<T>(Func<Task<T>> operation)
    {
        if (_state == CircuitState.Open)
        {
            if (DateTime.UtcNow - _lastFailureTime > _timeout)
            {
                _state = CircuitState.HalfOpen;
            }
            else
            {
                throw new CircuitBreakerOpenException("Circuit breaker is open");
            }
        }

        try
        {
            var result = await operation();

            if (_state == CircuitState.HalfOpen)
            {
                _state = CircuitState.Closed;
                _failureCount = 0;
            }

            return result;
        }
        catch (Exception ex)
        {
            _failureCount++;
            _lastFailureTime = DateTime.UtcNow;

            if (_failureCount >= _failureThreshold)
            {
                _state = CircuitState.Open;
            }

            throw;
        }
    }
}

public enum CircuitState
{
    Closed,     // Normal operation
    Open,       // Failing, reject all requests
    HalfOpen    // Testing if service recovered
}
```

### 29.8 Global Exception Handler

```csharp
public class GlobalExceptionHandler
{
    public void Initialize()
    {
        // Catch unhandled exceptions
        AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
        TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;
        Application.Current.UnhandledException += OnApplicationUnhandledException;
    }

    private void OnUnhandledException(object sender, UnhandledExceptionEventArgs e)
    {
        var ex = e.ExceptionObject as Exception;
        _logger.LogCritical(ex, "Unhandled exception in AppDomain");

        // Show crash dialog
        ShowCrashDialog(ex);

        // Save crash dump
        SaveCrashDump(ex);
    }

    private void OnApplicationUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        _logger.LogError(e.Exception, "Unhandled UI exception");

        // Mark as handled to prevent crash
        e.Handled = true;

        // Show error dialog
        ShowErrorDialog(e.Exception);
    }
}
```

---

## 30. UI Framework Specifics

### 30.1 WinUI 3 Integration Patterns

**Application Structure**:

```csharp
public partial class App : Application
{
    private Window? _window;
    private IHost? _host;

    public App()
    {
        InitializeComponent();

        // Build dependency injection container
        _host = Host.CreateDefaultBuilder()
            .ConfigureServices((context, services) =>
            {
                // Core services
                services.AddSingleton<IOrchestrator, Orchestrator>();
                services.AddSingleton<IAIEngine, AIEngine>();
                services.AddSingleton<IPatchEngine, PatchEngine>();
                services.AddSingleton<IBuildKernel, BuildKernel>();

                // ViewModels
                services.AddTransient<MainViewModel>();
                services.AddTransient<ProjectViewModel>();
                services.AddTransient<SettingsViewModel>();
            })
            .Build();

        this.UnhandledException += App_UnhandledException;
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        _window.Activate();
    }
}
```

### 30.2 MVVM Toolkit Usage

**ViewModel Base**:

```csharp
public partial class MainViewModel : ObservableObject
{
    private readonly IOrchestrator _orchestrator;

    [ObservableProperty]
    private string _promptText = string.Empty;

    [ObservableProperty]
    private bool _isGenerating = false;

    [ObservableProperty]
    private ProjectState _projectState = ProjectState.Empty;

    public MainViewModel(IOrchestrator orchestrator)
    {
        _orchestrator = orchestrator;
    }

    [RelayCommand]
    private async Task GenerateAsync()
    {
        if (string.IsNullOrWhiteSpace(PromptText))
            return;

        IsGenerating = true;

        try
        {
            await _orchestrator.ExecuteAsync(PromptText);
        }
        finally
        {
            IsGenerating = false;
        }
    }
}
```

**Data Binding**:

```xml
<Page x:Class="SyncAI.Views.MainPage"
      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:vm="using:SyncAI.ViewModels">

    <Grid>
        <TextBox Text="{x:Bind ViewModel.PromptText, Mode=TwoWay}"
                 PlaceholderText="Describe your application..."
                 AcceptsReturn="True"
                 TextWrapping="Wrap" />

        <Button Command="{x:Bind ViewModel.GenerateCommand}"
                Content="Generate"
                IsEnabled="{x:Bind ViewModel.IsGenerating, Converter={StaticResource InverseBooleanConverter}, Mode=OneWay}" />

        <ProgressRing IsActive="{x:Bind ViewModel.IsGenerating, Mode=OneWay}"
                      Visibility="{x:Bind ViewModel.IsGenerating, Converter={StaticResource BooleanToVisibilityConverter}, Mode=OneWay}" />
    </Grid>
</Page>
```

### 30.3 DispatcherQueue Threading

**Thread-Safe UI Updates**:

```csharp
public class UIService
{
    private readonly DispatcherQueue _dispatcherQueue;

    public UIService()
    {
        _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
    }

    public async Task UpdateUIAsync(Action action)
    {
        if (_dispatcherQueue.HasThreadAccess)
        {
            action();
        }
        else
        {
            var tcs = new TaskCompletionSource<bool>();

            _dispatcherQueue.TryEnqueue(() =>
            {
                try
                {
                    action();
                    tcs.SetResult(true);
                }
                catch (Exception ex)
                {
                    tcs.SetException(ex);
                }
            });

            await tcs.Task;
        }
    }

    public async Task<T> RunOnUIThreadAsync<T>(Func<T> func)
    {
        if (_dispatcherQueue.HasThreadAccess)
        {
            return func();
        }

        var tcs = new TaskCompletionSource<T>();

        _dispatcherQueue.TryEnqueue(() =>
        {
            try
            {
                tcs.SetResult(func());
            }
            catch (Exception ex)
            {
                tcs.SetException(ex);
            }
        });

        return await tcs.Task;
    }
}
```

**Background Operation with UI Updates**:

```csharp
public async Task GenerateWithProgressAsync(string prompt)
{
    await Task.Run(async () =>
    {
        // Background thread
        var result = await _aiEngine.GenerateAsync(prompt);

        // Update UI
        await _uiService.UpdateUIAsync(() =>
        {
            StatusText = "Applying changes...";
        });

        await _patchEngine.ApplyAsync(result.Patch);

        // Update UI again
        await _uiService.UpdateUIAsync(() =>
        {
            StatusText = "Building project...";
        });

        var buildResult = await _buildKernel.BuildAsync();

        // Final UI update
        await _uiService.UpdateUIAsync(() =>
        {
            if (buildResult.Success)
            {
                StatusText = "Build successful!";
                ProjectState = ProjectState.Ready;
            }
            else
            {
                StatusText = $"Build failed: {buildResult.Error}";
                ProjectState = ProjectState.Error;
            }
        });
    });
}
```

### 30.4 MSIX Deployment Details

**Package Configuration**:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities">

    <Identity Name="SyncAI.Builder"
              Publisher="CN=SyncAI Inc."
              Version="1.0.0.0" />

    <Properties>
        <DisplayName>Sync AI Builder</DisplayName>
        <PublisherDisplayName>SyncAI Inc.</PublisherDisplayName>
        <Logo>Assets\StoreLogo.png</Logo>
    </Properties>

    <Dependencies>
        <TargetDeviceFamily Name="Windows.Universal" MinVersion="10.0.17763.0" MaxVersionTested="10.0.22621.0" />
        <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.22621.0" />
    </Dependencies>

    <Resources>
        <Resource Language="en-US" />
    </Resources>

    <Applications>
        <Application Id="App"
                    Executable="SyncAI.Builder.exe"
                    EntryPoint="$targetentrypoint$">
            <uap:VisualElements DisplayName="Sync AI Builder"
                              Description="AI-powered application builder"
                              BackgroundColor="transparent"
                              Square150x150Logo="Assets\Square150x150Logo.png"
                              Square44x44Logo="Assets\Square44x44Logo.png">
                <uap:DefaultTile Wide310x150Logo="Assets\Wide310x150Logo.png"
                               Square71x71Logo="Assets\SmallTile.png"
                               Square310x310Logo="Assets\LargeTile.png" />
            </uap:VisualElements>
        </Application>
    </Applications>

    <Capabilities>
        <rescap:Capability Name="runFullTrust" />
        <Capability Name="internetClient" />
    </Capabilities>
</Package>
```

**Build Configuration**:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows10.0.22621.0</TargetFramework>
    <TargetPlatformMinVersion>10.0.17763.0</TargetPlatformMinVersion>
    <RootNamespace>SyncAI.Builder</RootNamespace>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <Platforms>x86;x64;ARM64</Platforms>
    <RuntimeIdentifiers>win-x86;win-x64;win-arm64</RuntimeIdentifiers>
    <UseWinUI>true</UseWinUI>
    <WindowsPackageType>MSIX</WindowsPackageType>
    <WindowsAppSDKSelfContained>true</WindowsAppSDKSelfContained>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.WindowsAppSDK" Version="1.4.231008000" />
    <PackageReference Include="Microsoft.Windows.SDK.BuildTools" Version="10.0.22621.756" />
    <PackageReference Include="CommunityToolkit.Mvvm" Version="8.2.2" />
    <PackageReference Include="Microsoft.Extensions.Hosting" Version="8.0.0" />
  </ItemGroup>
</Project>
```

### 30.5 UI State Management

**State Enums**:

```csharp
public enum ProjectState
{
    Empty,          // No project loaded
    Loading,        // Opening project
    Ready,          // Idle, project loaded
    Generating,     // AI planning/coding
    Building,       // Compiler running
    Error,          // Failed state
    Preview         // Running app
}
```

**State Transition Logic**:

```csharp
public void TransitionTo(ProjectState newState)
{
    // Validate transition
    if (_currentState == ProjectState.Building && newState == ProjectState.Generating)
        throw new InvalidOperationException("Cannot switch to generation during build");

    _currentState = newState;

    // Update Commands
    GenerateCommand.NotifyCanExecuteChanged();
    BuildCommand.NotifyCanExecuteChanged();

    // Update Visuals
    StatusText = _stateDescriptionMap[newState];
}
```

**State Machine**:

```csharp
public enum UIState
{
    EmptyIdle,           // No project loaded
    PreviewReady,        // Project loaded, ready to generate
    Generating,          // AI generation in progress
    Building,            // Build in progress
    Previewing,          // Showing generated preview
    SoftRecovery,        // Retrying after errors
    HardFailure          // Critical error, user intervention needed
}

public class UIStateManager
{
    private UIState _currentState = UIState.EmptyIdle;
    private readonly DispatcherQueue _dispatcherQueue;

    public event EventHandler<UIStateChangedEventArgs>? StateChanged;

    public UIState CurrentState
    {
        get => _currentState;
        private set
        {
            if (_currentState != value)
            {
                var oldState = _currentState;
                _currentState = value;
                StateChanged?.Invoke(this, new UIStateChangedEventArgs(oldState, value));
            }
        }
    }

    public async Task TransitionToAsync(UIState newState)
    {
        if (!IsValidTransition(CurrentState, newState))
        {
            throw new InvalidOperationException($"Invalid transition from {CurrentState} to {newState}");
        }

        await _dispatcherQueue.EnqueueAsync(() =>
        {
            CurrentState = newState;
        });
    }

    private bool IsValidTransition(UIState from, UIState to)
    {
        return (from, to) switch
        {
            (UIState.EmptyIdle, UIState.Generating) => true,
            (UIState.PreviewReady, UIState.Generating) => true,
            (UIState.Generating, UIState.Building) => true,
            (UIState.Building, UIState.Previewing) => true,
            (UIState.Building, UIState.SoftRecovery) => true,
            (UIState.SoftRecovery, UIState.Building) => true,
            (UIState.SoftRecovery, UIState.HardFailure) => true,
            (UIState.Previewing, UIState.PreviewReady) => true,
            (UIState.HardFailure, UIState.PreviewReady) => true,
            _ => false
        };
    }
}
```
