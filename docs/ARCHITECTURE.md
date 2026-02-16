# Windows Native App Builder - Architecture

## Project Overview
A comprehensive AI-powered Windows native application builder that generates complete Windows desktop applications end-to-end using natural language prompts. This system leverages **multi-agent orchestration**, **structured specifications**, and **silent retry loops** to deliver a seamless, production-grade experience.

**See [INTERNAL_ARCHITECTURE.md](INTERNAL_ARCHITECTURE.md) for detailed technical breakdown of the multi-agent system.**

**See [INTERNAL_EXECUTION_ARCHITECTURE.md](INTERNAL_EXECUTION_ARCHITECTURE.md) for the 6 required embedded subsystems that make this fully internal.**

**See [LOCAL_EXECUTION_ARCHITECTURE.md](LOCAL_EXECUTION_ARCHITECTURE.md) for desktop-only deployment: handling machine variability, filesystem sandbox, security isolation.**

**See [USER_WORKFLOW.md](USER_WORKFLOW.md) for observable user behavior and what happens behind the scenes.**

**See [DESIGN_PHILOSOPHY.md](DESIGN_PHILOSOPHY.md) for UX design principles: hide complexity, show only results.**

🔴 **See [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) for the CRITICAL FOUNDATION: deterministic orchestrator that must be implemented FIRST.**

## System Architecture

### 🔴 FOUNDATION: Deterministic Orchestrator (Must Implement First)

**Critical Discovery**: Without deterministic orchestration, Roslyn indexing and patching will create nondeterministic mutation loops that silently corrupt code.

- **Responsibility**: Control all state transitions, ensure no implicit states, serialize all mutations
- **Core**: State machine reducer (pure function, deterministic)
- **Guarantee**: Perfect replay from event log, no silent corruption
- **Constraint**: Only 1 mutation task at time (no parallel patching)
- **See**: [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) for complete details

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

**See**: [INTERNAL_EXECUTION_ARCHITECTURE.md](INTERNAL_EXECUTION_ARCHITECTURE.md) for complete specifications and implementation patterns

**User Experience**: 
```
Prompt → Result (30-60 seconds)
(6 embedded subsystems working silently)
```

---

### 1. User-Facing Layer (Minimal UI)

**What the user sees:**
- Prompt input field
- Live preview of generated app
- Project list
- Deploy button

**What's hidden:**
- Multi-stage orchestration (6 layers)
- AI agent coordination
- Automatic error fixing
- Build retry loops

### 2. Core Processing Layers

#### Layer 1: Intent & Specification
- **Responsibility**: Parse natural language → structured JSON spec
- **Prevents**: Hallucinated features, contradictory requirements
- **Output**: Machine-readable feature list with dependencies

#### Layer 2: Planning Layer (Task Graph/DAG)
- **Responsibility**: Create ordered execution plan
- **Enables**: Parallel work, dependency management
- **Output**: Task graph with serialization points

#### Layer 3: Code Intelligence (Project Index)
- **Responsibility**: Maintain semantic index of entire project
- **Enables**: Smart retrieval, impact analysis, safe modifications
- **Storage**: SQLite with embeddings for semantic search
- **Tracks**: File index, dependency graph, route registry, schema map

#### Layer 4: Multi-Agent Generation
- **Responsibility**: Decompose complex generation into specialized agents
- **Agents**:
  - **Architect Agent** - defines structure
  - **Schema Agent** - generates DB models
  - **Frontend Agent** - generates XAML UI
  - **Backend Agent** - generates APIs
  - **Integration Agent** - wires dependencies
  - **Fix Agent** - repairs build failures
- **Output**: Structured patches, not full file rewrites

#### Layer 5: Structured Patch Engine (AST-Based)
- **Responsibility**: Apply targeted code modifications
- **Technology**: Roslyn for C# AST manipulation
- **Benefit**: Preserves formatting, comments, developer notes
- **vs. Traditional**: Surgical edits instead of full rewrites

#### Layer 6: Validation & Silent Retry Loop
- **Responsibility**: Auto-detect and fix build errors
- **Hidden**: All errors and retries from user
- **Shows**: Only final success
- **Loop**: Generate → Compile → Detect → Fix → Retry

#### Layer 7: Memory & State
- **Responsibility**: Preserve architectural decisions and context
- **Stores**: Project config, stack decisions, naming conventions, error patterns
- **Enables**: Architectural consistency across iterations

---

## Detailed Component Architecture

### Frontend (WinUI 3 User Interface)
- **Technology**: WinUI 3 (Windows App SDK, .NET 8, XAML)
- **Responsibility**: Minimal, beautiful UI
- **Features**:
  - Prompt editor
  - Live preview
  - Project manager
  - Simple build button
- **Reality**: UI is thin wrapper around sophisticated backend
- **Deployment**: MSIX package (modern Windows app installer)

### Intent & Specification Service
- **Technology**: Claude API + NLP
- **Responsibility**: Convert prompt to structured spec
- **Output Example**:
```json
{
  "projectType": "windows-desktop-app",
  "features": [...],
  "stack": {...},
  "constraints": {...}
}
```

### Planning Service
- **Responsibility**: Create task dependency graph
- **Output**: Ordered list of parallelizable tasks

### Code Intelligence Layer
- **Storage**: SQLite database with:
  - File index (symbols, exports, imports)
  - Dependency graph (file → file relationships)
  - Embeddings (semantic code search)
  - Route registry (all API endpoints)
  - Schema map (database structure)
- **Usage**: Smart file retrieval for LLM context

### Multi-Agent Orchestrator
- **Technology**: .NET + Claude API
- **Responsibility**: Coordinate 6 specialized agents
- **Strategy**: Sequential with parallelizable stages

### Structured Patch Engine
- **Technology**: Roslyn (C# compiler APIs)
- **Responsibility**: Parse code to AST, apply patches, recompile
- **Benefit**: Minimal, merge-friendly changes

### Build & Validation Service
- **Technology**: MSBuild + custom error classifier
- **Responsibility**: Compile, detect errors, trigger fixes
- **If Errors**: Call Fix Agent, automatically retry

### Memory & State Manager
- **Storage**: SQLite tables for:
  - Project state (stack decisions)
  - Pattern memory (naming conventions)
  - Error patterns (common fixes)
  - Session context (conversation history)

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
- Multiple agents working in parallel
- Smart context retrieval (not full project dump)
- Automatic error fixing (hidden from user)
- Silent retries (only success shown)

---

## Technology Stack
(See [TECHNOLOGY_STACK.md](TECHNOLOGY_STACK.md))

---

## Key Architectural Decisions

### 1. Multi-Agent Over Monolithic LLM
- **Why**: Specialized agents produce better code than single generalist LLM
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
- **Why**: Solves LLM context window limits
- **Strategy**: Embed code → Search semantically → Send only relevant files
- **Result**: Stable generation as project grows

### 5. Silent Retry Loop Over Error Bubbling
- **Why**: Perfect user experience (no visible errors)
- **How**: Auto-classify errors → Apply fixes → Retry until success

### 6. Persistent Memory Over Stateless Generation
- **Why**: Ensures architectural consistency across iterations
- **Stores**: Stack decisions, patterns, error solutions

---

## Module Structure

```
SYNC-AI-FULL-STACK-APP-BUILDER/
├── docs/                              # Documentation
│   ├── ARCHITECTURE.md                # System design (this file)
│   ├── INTERNAL_ARCHITECTURE.md       # Multi-agent details
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
- [INTERNAL_ARCHITECTURE.md](INTERNAL_ARCHITECTURE.md) - Complete multi-agent breakdown
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
