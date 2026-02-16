# SYSTEM ARCHITECTURE

> **The Big Picture: 7-Layer Architecture, Deployment Model, Process Lifecycle & Hidden Background Systems**
>
> _Merged from: ARCHITECTURE.md, EXECUTION_ARCHITECTURE.md, EXECUTION_LIFECYCLE_SPECIFICATION.md, BACKGROUND_SYSTEMS_SPECIFICATION.md_

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [The 7-Layer Architecture](#2-the-7-layer-architecture)
3. [Intent & Specification Layer](#3-intent--specification-layer)
4. [Planning Layer (Task Graph / DAG)](#4-planning-layer-task-graph--dag)
5. [Multi-Agent Specifications](#5-multi-agent-specifications)
6. [Data Flow](#6-data-flow)
7. [AI Engine Integration with Preview System](#7-ai-engine-integration-with-preview-system)
8. [Validation & Silent Retry Loop](#8-validation--silent-retry-loop)
9. [Memory & State Layer](#9-memory--state-layer)
10. [Embedded Subsystems](#10-embedded-subsystems)
11. [Execution Lifecycle](#11-execution-lifecycle)
12. [Background Systems](#12-background-systems)
13. [Threading & Concurrency Model](#13-threading--concurrency-model)
14. [Security & Isolation](#14-security--isolation)
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

Sync AI is a **local-first, AI-powered full-stack application builder** for Windows. It is a WinUI 3 desktop application that generates, builds, previews, and iterates on .NET applications — all in-process, with no external CLI calls.

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

---

## 2. The 7-Layer Architecture

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
}
```

**Example Index Entry**:

```json
{
  "path": "Models/Customer.cs",
  "type": "class",
  "dependencies": ["System.Data", "DbContext"],
  "exports": ["Customer", "CustomerValidator"],
  "size_bytes": 2048
}
```

#### Layer 5: AI Agent Layer

**Purpose**: Multi-agent code generation.

| Agent        | Responsibility                         |
| ------------ | -------------------------------------- |
| **Planner**  | Decomposes user prompt into task graph |
| **Coder**    | Generates C#/XAML per task             |
| **Fixer**    | Patches code after build errors        |
| **Reviewer** | Validates architectural consistency    |

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

## 3. Intent & Specification Layer

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

---

## 6. Data Flow

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

## 8. Validation & Silent Retry Loop

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

## 9. Memory & State Layer

### Purpose

Preserve architectural decisions and context across iterations, preventing architectural drift.

### What Gets Remembered

#### Project Memory

```jsonjson
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

````sql
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

### The 6 Embedded Subsystems

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
    private readonly string _projectRoot;
    private readonly string _tempWorkspace;

    /// Create snapshot of current state (for rollback)
    public async Task<string> CreateSnapshotAsync(string projectId)
    {
        var snapshotDir = Path.Combine(_projectRoot, projectId, ".snapshots");
        var snapshotId = $"snapshot_{DateTime.Now:yyyyMMdd_HHmmss}";
        var snapshotPath = Path.Combine(snapshotDir, $"{snapshotId}.zip");

        // ZIP all project files (excluding bin/obj)
        // Implementation details...
        return snapshotPath;
    }

    /// Rollback to previous snapshot
    public async Task RollbackToSnapshotAsync(string projectId, string snapshotPath)
    {
        var projectSrc = Path.Combine(_projectRoot, projectId, "src");
        Directory.Delete(projectSrc, recursive: true);
        ZipFile.ExtractToDirectory(snapshotPath, projectSrc);
    }
}
```

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
```

---

### 11. Execution Lifecycle

````

### Environment Validation Detail

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
````

### Task Execution Lifecycle (Generate Command)

When user types a prompt and hits "Generate", this is the full lifecycle:

```text
User Prompt
    ↓
┌─ PLANNING ──────────────────────────────────┐
│  AI Planner decomposes prompt into tasks     │
│  Orchestrator builds task graph              │
│  Snapshot created (pre-mutation baseline)    │
└──────────────────────────────────────────────┘
    ↓
┌─ GENERATING ────────────────────────────────┐
│  AI Coder generates code per task            │
│  Patch Engine applies changes (Roslyn AST)   │
│  Code Intelligence re-indexes symbols        │
└──────────────────────────────────────────────┘
    ↓
┌─ BUILDING ──────────────────────────────────┐
│  NuGet restore (in-process)                  │
│  MSBuild compile (in-process)                │
│  Structured error capture                    │
└──────────────────────────────────────────────┘
    ↓
┌─ ERROR? ────────────────────────────────────┐
│  YES → Classify error                        │
│       → AI Fix Agent patches                 │
│       → Re-build (retry up to 3 times)       │
│  NO  → Continue to commit                    │
└──────────────────────────────────────────────┘
    ↓
┌─ COMMITTING ────────────────────────────────┐
│  Commit snapshot                             │
│  Update version timeline                     │
│  Update preview                              │
│  Log execution to database                   │
└──────────────────────────────────────────────┘
    ↓
User sees: Updated App Preview ✅
```

### Crash Recovery

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

### A. Continuous Indexer

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

### B. Snapshot Pruning

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
}
```

### C. Resource Monitor

**Runs**: Continuous background thread
**Purpose**: Watch system resources and throttle operations

```csharp
public class ResourceMonitor
{
    private readonly Timer _timer;

    public ResourceMonitor(string workspacePath)
    {
        _timer = new Timer(CheckResources, null, TimeSpan.Zero, TimeSpan.FromSeconds(30));
    }

    private void CheckResources(object? state)
    {
        var memoryUsage = GC.GetTotalMemory(forceFullCollection: false);
        var diskSpace = new DriveInfo(Path.GetPathRoot(_workspacePath)).AvailableFreeSpace;

        if (memoryUsage > 1_500_000_000) // 1.5GB
        {
            _eventAggregator.Publish(new MemoryPressureEvent());
            GC.Collect(2, GCCollectionMode.Optimized);
        }

        if (diskSpace < 500_000_000) // 500MB
        {
            _eventAggregator.Publish(new LowDiskSpaceEvent());
        }
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

### 13. Threading & Concurrency Model

```text
│ ─ User interactions, progress display │
├─────────────────────────────────────────────┤
│ Worker Thread Pool │
│ ┌─────────────────────────────────────┐ │
│ │ AI Worker │ Plan + Generate code │ │
│ │ Build Worker │ MSBuild + NuGet │ │
│ │ Patch Worker │ Roslyn AST mutations │ │
│ │ Index Worker │ Symbol graph updates │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ Background Services │
│ ─ Snapshot pruning, resource monitor, │
│ continuous indexer, token budget guard │
└─────────────────────────────────────────────┘

```

### WinUI 3 Threading Pattern

```csharp
// Update UI from background task
await DispatcherQueue.EnqueueAsync(() =>
{
    BuildProgressText = "Compiling...";
    BuildPercentage = 45;
});
```

---

## 14. Security & Isolation

### Challenge: Generated Code Is Untrusted

The builder generates code that runs on the user's PC. Security boundaries must be enforced.

### Explicit Constraints

| ❌ FORBIDDEN                                            | ✅ ALLOWED                          |
| ------------------------------------------------------- | ----------------------------------- |
| Arbitrary shell execution (`cmd.exe`, `powershell.exe`) | Whitelisted dotnet commands only    |
| Elevated privileges (`runas`)                           | Standard user context               |
| Registry writes                                         | Isolated file access within project |
| Directory traversal (`../../`)                          | Path validation within sandbox      |

### Implementation

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

### Compliance & Data Privacy
- **User prompts not stored** (privacy-first)
- **Generated code validated** before compilation
- **API keys in secure storage** (Azure Key Vault / env vars)
- **Rate limiting** on API calls
- **Input sanitization**
```

---

## 15. Machine Variability Handling

### The Local-Only Challenge

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

### Error Handling with Fallbacks

```csharp
public class MachineVariabilityHandler
{
    public async Task<BuildResult> BuildWithFallbacksAsync(
        string projectPath,
        IProgress<BuildPhase>? progress = null)
    {
        // ... (implementation hidden)
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

- **Semantic Caching**: Store embeddings, reuse for similar prompts
- **Parallel Agents**: Execute independent agents concurrently
- **Incremental Builds**: Only recompile changed modules
- **Smart Retrieval**: Send ~2-5 relevant files, not entire project

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
