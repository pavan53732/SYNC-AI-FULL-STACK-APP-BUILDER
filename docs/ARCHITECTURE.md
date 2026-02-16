# Windows Native App Builder - Architecture

## Project Overview
A comprehensive AI-powered **Windows-native autonomous software construction environment** that generates complete Windows desktop applications end-to-end using natural language prompts. This system leverages **multi-agent orchestration**, **structured specifications**, and **silent retry loops** to deliver a seamless, production-grade experience.

**See [EXECUTION_ARCHITECTURE.md](EXECUTION_ARCHITECTURE.md) for the 6 required embedded subsystems and local-only deployment architecture.**

**See [USER_WORKFLOW.md](USER_WORKFLOW.md) for observable user behavior and what happens behind the scenes.**

**See [DESIGN_PHILOSOPHY.md](DESIGN_PHILOSOPHY.md) for UX design principles: hide complexity, show only results.**

🔴 **See [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) for the CRITICAL FOUNDATION: deterministic orchestrator that must be implemented FIRST.**

---

## 🏗 System Architecture (The Local Builder)

You are building a **Windows‑native autonomous construction system**. The system is organized into **7 Multi-Agent Layers** managed by a **Deterministic Orchestrator**, supported by **6 Kernel Subsystems**.

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
│ Execution Kernel (Local Only)     │
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

**AI Engine constraints**: It never writes files, executes code, runs builds, or accesses the filesystem directly. It only returns structured JSON generation output.

---

## System Architecture Overview

### 🔴 FOUNDATION: Deterministic Orchestrator (Must Implement First)

**Critical Discovery**: Without deterministic orchestration, Roslyn indexing and patching will create nondeterministic mutation loops that silently corrupt code.

- **Responsibility**: Control all state transitions, ensure no implicit states, serialize all mutations
- **Core**: State machine reducer (pure function, deterministic)
- **State Machine Transitions**: `IDLE` → `SPEC_PARSED` → `TASK_GRAPH_READY` → `TASK_EXECUTING` → `VALIDATING` → `RETRYING` → `COMPLETED` / `FAILED`.
- **Guarantee**: Perfect replay from event log, no silent corruption
- **Rules**: One mutation task at a time, max retry budget per task, snapshot before every mutation, rollback on failure.
- **Constraint**: Only 1 mutation task at time (no parallel patching)
- **See**: [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) for complete details

---

## 🚫 The "No IDE Required" Philosophy
The system is built as an **autonomous software construction environment**, not a developer utility.

*   **Zero Tooling Exposure**: Users never open Visual Studio, run `dotnet build`, or manage NuGet manually.
*   **Embedded Services**: The .NET SDK, MSBuild, and Roslyn are **internal bundled services**, not external user tools.
*   **Developer-Free Workflow**: The Orchestrator and Patch Engine handle all file edits and debugging silently.
*   **The Goal**: A self-contained constructor where the only external dependency is the Cloud AI reasoning.

---

### 🔴 FOUNDATION: 6 Required Internal Subsystems (Embedded, Not External)

**Critical Principle**: "Fully internal" means all tools are **embedded services**, not external CLI tools. Users never see build systems, compilers, or runtimes.

Your builder contains:

1. **Filesystem Sandbox** - Isolated projects, snapshots for rollback, versioned builds
2. **Execution Kernel** - Manages .NET SDK, MSBuild, NuGet (all hidden in managed code)
3. **Roslyn Code Intelligence** - AST parsing, symbol graph, impact analysis
4. **Transactional Patch Engine** - Safe mutations with conflict detection and rollback
5. **SQLite Project Graph** - Persistent memory of symbols, dependencies, decisions, errors
6. **Process Sandbox** - Isolated execution, resource limits, timeout management

**See**: [EXECUTION_ARCHITECTURE.md](EXECUTION_ARCHITECTURE.md) for complete specifications and implementation patterns

**User Experience**: 
```
Prompt → Result (30-60 seconds)
(6 embedded subsystems working silently)
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
        │  Code Intelligence Layer        │ ← Project index, graphs, embeddings
        │  (Indexed Project Graph)        │
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
        │  Validation & Silent Retry Loop       │ ← Build → Detect → Fix → Retry
        │  (Errors Hidden From User)           │
        └────────────┬──────────────────────────┘
                     │
        ┌────────────▼──────────────────────────┐
        │  State & Memory Layer                 │ ← SQLite-backed persistence
        │  (Project Context, Decisions)        │
        └────────────┬──────────────────────────┘
                     │
        ┌────────────▼──────────────────────────┐
        │  Execution Kernel (Construct Output)  │ ← Build → MSIX → Local Execution
        └──────────────────────────────────────┘
```

---

## 1️⃣ Intent & Specification Layer

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

## 2️⃣ Planning Layer (Task Graph / DAG)

### Purpose
Convert feature spec into an ordered, executable task graph where dependencies are explicit and parallelizable work is identified.

### Task Graph Structure

```
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

```
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

## 3️⃣ Code Intelligence Layer (Indexed Project Graph)

### Purpose
Maintain a semantic index of the entire project for intelligent, impact-aware code generation and modification.

### What Gets Indexed

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
```
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
        {"name": "id", "type": "int", "pk": true},
        {"name": "name", "type": "string", "nullable": false},
        {"name": "email", "type": "string", "unique": true}
      ],
      "relationships": [
        {"foreign_key": "contact_id", "references": "contacts.id"}
      ],
      "models_using": ["Customer.cs"]
    }
  ]
}
```

### Storage Implementation

**SQLite Schema:**
```sql
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

CREATE TABLE dependency_graph (
  id INTEGER PRIMARY KEY,
  source_file TEXT NOT NULL,
  target_file TEXT NOT NULL,
  dep_type TEXT,  -- 'imports', 'uses', 'references'
  FOREIGN KEY (source_file) REFERENCES file_index(file_path)
);

CREATE TABLE embeddings (
  id INTEGER PRIMARY KEY,
  file_path TEXT,
  code_section TEXT,
  embedding BLOB,  -- Vector embedding for semantic search
  FOREIGN KEY (file_path) REFERENCES file_index(file_path)
);
```

### Semantic Retrieval

For prompt: *"Add customer validation"*

1. **Embed prompt** - Convert to vector
2. **Search embeddings** - Find related code sections
3. **Rank by relevance** - Use similarity score
4. **Include context** - Add dependent files
5. **Build context window** - Only relevant code to AI Engine

Result: AI Engine never sees full project, only ~2-5 relevant files.

---

## 4️⃣ Multi-Agent Generation Layer

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
        {"name": "id", "type": "int", "pk": true},
        {"name": "name", "type": "string"}
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

### Agent Orchestration

```python
def orchestrate_generation(spec, task_graph):
    results = {}
    
    # Stage 1: Planning & Structure
    arch_output = architect_agent(spec)
    results['architecture'] = arch_output
    
    # Stage 2: Parallel Generation (tasks with no deps)
    schema_output = schema_agent(spec)
    auth_output = backend_agent(spec, auth_tasks)
    results['schema'] = schema_output
    results['auth'] = auth_output
    
    # Stage 3: UI Generation (needs auth context)
    ui_output = frontend_agent(spec, auth_output)
    results['ui'] = ui_output
    
    # Stage 4: Integration (wires everything)
    integration_output = integration_agent(results)
    results['integration'] = integration_output
    
    # Stage 5: Build & Validate
    build_result = validate_and_build()
    
    # Stage 6: Auto-fix if needed
    if build_result.has_errors:
        for error in build_result.errors:
            fix_output = fix_agent(error, results)
            apply_fix(fix_output)
        # Retry build
        build_result = validate_and_build()
    
    return results, build_result
```

**Note**: All agent communications are handled through the `z-ai-web-dev-sdk`.

---

## 5️⃣ Structured Patch Engine (AST-Based)

### Purpose
Make surgical, targeted code modifications without full file rewrites or losing formatting.

### Traditional Approach (❌ Bad)
```
User: "Add validation to Customer model"

Old approach:
- Retrieve entire Customer.cs file
- Send to AI Engine with "rewrite this"
- AI Engine regenerates entire file
- Lose comments, formatting, developer notes
- Risk introducing bugs
```

### AST-Based Approach (✅ Good)

**Step 1: Parse to AST (Abstract Syntax Tree)**
```
Customer.cs
│
├─ Class: Customer
│   ├─ Property: Id (int)
│   ├─ Property: Name (string)
│   └─ Property: Email (string)
```

**Step 2: Identify Target Node**
```
Goal: Add [Required] annotation to Name property
Target: Property node "Name"
```

**Step 3: Generate Minimal Patch**
```csharp
// Only modify this:
- public string Name { get; set; }
+ [Required]
+ public string Name { get; set; }
```

**Step 4: Apply Patch**
```
AST update → Recompile AST to source → Preserve formatting
```

**Step 5: Preserve Everything Else**
```csharp
// Comments preserved
public class Customer
{
    /// <summary>Unique customer ID</summary>
    public int Id { get; set; }
    
    /// <summary>Customer full name</summary>
    [Required]  // ← Only addition
    public string Name { get; set; }
    
    // Custom init logic (preserved)
    public Customer() { /* ... */ }
}
```

### Implementation (Roslyn-based for C#)

```csharp
public class StructuredPatchEngine
{
    public async Task<CodeFile> ApplyPatchAsync(
        CodeFile originalFile, 
        PatchRequest patch)
    {
        // Parse to AST
        var tree = CSharpSyntaxTree.ParseText(originalFile.Content);
        var root = (CompilationUnitSyntax)tree.GetRoot();
        
        // Find target node
        var targetProperty = root
            .DescendantNodes()
            .OfType<PropertyDeclarationSyntax>()
            .First(p => p.Identifier.Text == patch.PropertyName);
        
        // Add attribute
        var attribute = SyntaxFactory.Attribute(
            SyntaxFactory.IdentifierName("Required"));
        var newProperty = targetProperty
            .AddAttributeLists(
                SyntaxFactory.AttributeList(
                    SyntaxFactory.SingletonSeparatedList(attribute)));
        
        // Replace in tree
        var newRoot = root.ReplaceNode(targetProperty, newProperty);
        
        // Convert back to source
        return new CodeFile
        {
            Content = newRoot.ToFullString(),
            Path = originalFile.Path
        };
    }
}
```

### Benefits
- ✅ Minimal changes
- ✅ Preserve formatting & comments
- ✅ No accidental deletions
- ✅ Merge-friendly for version control
- ✅ Fast and deterministic

---

## 6️⃣ Validation & Silent Retry Loop

### Purpose
Transform potential errors into invisible internal retries, surfacing only final success to the user.

### The Loop

```
Generate Code
    ↓
Install Dependencies
    ↓
Compile (MSBuild)
    ↓
[Check for errors]
    ├─ NO ERRORS? → Success (show to user)
    │
    └─ ERRORS? → Classify & Fix
        ├─ Syntax Error → Fix Agent
        ├─ Missing dependency → Auto-install
        ├─ Type mismatch → Type fixer
        ├─ Missing reference → Add using
        └─ Build error → Rebuild & retry
        
        After fix → Recompile
            ├─ Success? → Return to user ✅
            └─ Still errors? → Re-analyze & retry
```

### Error Classifier

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

**Syntax Error:**
```
Error: Missing ';' at line 15
Fix: Insert ';' using AST patch
```

**Type Mismatch:**
```
Error: Cannot convert 'string' to 'int'
Fix: Insert Convert.ToInt32() or Parse()
```

**Missing Using:**
```
Error: Type 'ILogger' not found
Fix: Add 'using Microsoft.Extensions.Logging;'
```

**Build Failure:**
```
Error: Package 'Newtonsoft.Json' not found
Fix: Run 'dotnet add package Newtonsoft.Json'
Retry build
```

### User Experience

**User sees:**
```
Input: "Add user validation"
Output: [spinner for 2-3 seconds]
        ✅ Success - Added DataAnnotations validation
```

**But internally:**
```
1st attempt: Syntax error in validator
2nd attempt: Missing using statement
3rd attempt: ✅ Success
(All hidden, only final shown)
```

---

## 7️⃣ Memory & State Layer

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

```sql
CREATE TABLE project_memory (
  project_id TEXT PRIMARY KEY,
  stack_decisions JSON,
  architectural_decisions JSON,
  naming_conventions JSON,
  created_at DATETIME,
  updated_at DATETIME
);

CREATE TABLE pattern_memory (
  id INTEGER PRIMARY KEY,
  project_id TEXT,
  pattern_type TEXT,  -- 'file_naming', 'routing', 'code_style'
  pattern_data JSON,
  FOREIGN KEY (project_id) REFERENCES project_memory(project_id)
);

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

## Data Flow

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

---

## Technology Stack
(See [TECHNOLOGY_STACK.md](TECHNOLOGY_STACK.md))

---

## Key Architectural Decisions

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

## 🧱 Builder Project Structure
The builder application itself is partitioned to ensure clean separation between the user interface, the deterministic engine, and the local execution kernel.

```
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

## ⚠️ Critical Stability Constraints (Local-Only Handling)
The kernel must detect and mitigate machine variability that cloud-based systems typically avoid:
- **Environment Bootstrapping**: Automatically detect missing .NET SDKs and **guide the user through installation** or install automatically.
- **SDK Variability**: Detect missing .NET workloads (WinUI 3, XAML) and handle version mismatches.
- **Resource Intelligence**: Monitor disk space and RAM (disable parallel builds if <4GB); warn when system resources are critically low.
- **External Interference**: Detect and handle Antivirus blocking builds or NuGet cache corruption with "self-repair" strategies.
- **Corruption Recovery**: Automated partial project corruption detection and rollback via the snapshot system.

---

## Module Structure

```
SYNC-AI-FULL-STACK-APP-BUILDER/
├── docs/                              # Documentation
│   ├── ARCHITECTURE.md                # System design (this file)
│   ├── EXECUTION_ARCHITECTURE.md      # Embedded subsystems & local deployment
│   ├── TECHNOLOGY_STACK.md
│   ├── FEATURES.md
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

## Security & Compliance

- User prompts not stored (privacy-first)
- Generated code validated before compilation
- API keys in secure storage (Azure Key Vault / env vars)
- Rate limiting on API calls
- Input sanitization

---

## Performance Considerations

- **Semantic Caching**: Store embeddings, reuse for similar prompts
- **Parallel Agents**: Execute independent agents concurrently
- **Incremental Builds**: Only recompile changed modules
- **Smart Retrieval**: Send ~2-5 relevant files, not entire project

---

## Comparison with Traditional Approaches

| Aspect | Simple Generator | Our Multi-Agent System |
|--------|------------------|------------------------|
| Code quality | Medium (hallucinates) | High (controlled) |
| Build errors | Frequent | Rare (auto-fixes) |
| User experience | See errors | See only success |
| Stack reliability | Chaotic | Curated & stable |
| Iteration speed | Fast on first pass, slow on fixes | Consistent |
| Scalability | Poor (context overload) | Good (smart retrieval) |
| Architectural consistency | Drifts over time | Maintained (memory layer) |

---

## Future Evolution

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

## References

For deeper technical details:
- [EXECUTION_ARCHITECTURE.md](EXECUTION_ARCHITECTURE.md) - Complete embedded subsystems & local deployment
- [API_CONTRACTS.md](API_CONTRACTS.md) - Formal JSON output contracts
- [FEATURES.md](FEATURES.md) - Feature roadmap
- [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) - Implementation guide

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
