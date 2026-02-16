# Project Structure (WinUI 3)

## User Workspace Directory Structure (Response 7 - Local Execution)

All generated projects live in user's workspace:

```
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

**Key Points** (Response 7):
- User code lives in `src/` (version controllable, visible)
- Builder metadata in `.builder/` (hidden, internal management)
- Snapshots created BEFORE each task (not after)
- Diffs tracked for rollback capability
- Build artifacts isolated in temp directory
- SQLite database stores permanent decision graph

---

## Builder Application Directory Structure

```
SYNC-AI-FULL-STACK-APP-BUILDER/
│
├── docs/                              # Documentation
│   ├── ARCHITECTURE.md                # System architecture
│   ├── TECHNOLOGY_STACK.md            # Tech choices (WinUI 3)
│   ├── FEATURES.md                    # Feature roadmap
│   ├── PROJECT_STRUCTURE.md           # This file
│   ├── DEVELOPMENT_GUIDE.md           # Development setup
│   ├── API_DOCUMENTATION.md           # API specs
│   └── DEPLOYMENT.md                  # Deployment guide (MSIX)
│
├── src/                               # Source code
│   │
│   ├── SyncAIAppBuilder/              # Main WinUI 3 application (.NET 8)
│   │   ├── SyncAIAppBuilder.csproj    # WinUI 3 project file (Windows App SDK)
│   │   ├── Program.cs                 # Entry point (WinUI app bootstrap)
│   │   │
│   │   ├── UI/                        # Frontend (WinUI 3 - Thin XAML Layer)
│   │   │   ├── MainWindow.xaml        # Root window (Fluent Design)
│   │   │   ├── MainWindow.xaml.cs     # Code-behind
│   │   │   ├── Pages/                 # Navigation pages
│   │   │   │   ├── EditorPage.xaml    # Prompt editor
│   │   │   │   ├── EditorPage.xaml.cs
│   │   │   │   ├── PreviewPage.xaml   # Code preview
│   │   │   │   ├── PreviewPage.xaml.cs
│   │   │   │   ├── ProjectsPage.xaml  # Project list
│   │   │   │   ├── ProjectsPage.xaml.cs
│   │   │   │   ├── SettingsPage.xaml  # Settings
│   │   │   │   └── SettingsPage.xaml.cs
│   │   │   ├── Components/            # Reusable controls
│   │   │   │   ├── PromptEditor.xaml           # XAML input box
│   │   │   │   ├── PromptEditor.xaml.cs
│   │   │   │   ├── CodeViewer.xaml            # Syntax highlighting
│   │   │   │   ├── CodeViewer.xaml.cs
│   │   │   │   ├── BuildProgress.xaml         # Progress indicator
│   │   │   │   ├── BuildProgress.xaml.cs
│   │   │   │   ├── PreviewPanel.xaml          # Live preview
│   │   │   │   └── PreviewPanel.xaml.cs
│   │   │   ├── Dialogs/               # Modal dialogs
│   │   │   │   ├── CreateProjectDialog.xaml
│   │   │   │   └── CreateProjectDialog.xaml.cs
│   │   │   └── Resources/             # XAML styling
│   │   │       ├── Styles.xaml        # App-wide styles
│   │   │       ├── Colors.xaml        # Fluent Design colors
│   │   │       ├── Icons.xaml         # Symbol icons
│   │   │       └── Converters.xaml    # Value converters
│   │   │
│   │   ├── Services/                  # Core Business Logic (7-Layer Architecture)
│   │   │   │
│   │   │   ├── 🔴 FOUNDATION: Orchestration Core (IMPLEMENT FIRST)
│   │   │   │   ├── Orchestration/
│   │   │   │   │   ├── BuilderReducer.cs         # Deterministic state transitions
│   │   │   │   │   ├── TaskSchema.cs             # Task types, status enums
│   │   │   │   │   ├── BuilderContext.cs         # State container
│   │   │   │   │   ├── BuilderEvent.cs           # Event types (replayable)
│   │   │   │   │   ├── RetryController.cs        # Retry budget & rules
│   │   │   │   │   ├── ConcurrencyPolicy.cs      # Mutation serialization
│   │   │   │   │   ├── ErrorClassifier.cs        # Error categorization
│   │   │   │   │   └── IOrchestrator.cs          # Interface for all components
│   │   │   │
│   │   │   ├── Layer 1: Intent & Specification
│   │   │   │   ├── IntentService.cs           # Parse prompt → Structured spec
│   │   │   │   ├── FeatureExtractor.cs       # Extract features from text
│   │   │   │   ├── SpecValidator.cs          # Validate spec for conflicts
│   │   │   │   └── StackSelector.cs          # Choose appropriate tech stack
│   │   │   │
│   │   │   ├── Layer 2: Planning Service
│   │   │   │   ├── PlanningService.cs        # Create task DAG
│   │   │   │   ├── TaskGraphBuilder.cs       # Build dependency graph
│   │   │   │   └── TaskOrchestrator.cs       # Manage task execution
│   │   │   │
│   │   │   ├── Layer 3: Code Intelligence
│   │   │   │   ├── CodeIntelligenceService.cs # Project indexing & retrieval
│   │   │   │   ├── FileIndexer.cs            # Index file symbols
│   │   │   │   ├── DependencyGraphBuilder.cs # Build dependency graph
│   │   │   │   ├── EmbeddingService.cs       # Semantic search embeddings
│   │   │   │   ├── SchemaMapper.cs           # Database schema indexing
│   │   │   │   └── RouteRegistry.cs          # API endpoint tracking
│   │   │   │
│   │   │   ├── Layer 4: Multi-Agent Orchestrator
│   │   │   │   ├── AgentOrchestrator.cs          # Coordinate all agents
│   │   │   │   ├── ArchitectAgent.cs            # Define structure
│   │   │   │   ├── SchemaAgent.cs               # DB models
│   │   │   │   ├── FrontendAgent.cs             # XAML UI generation
│   │   │   │   ├── BackendAgent.cs              # Services & APIs
│   │   │   │   ├── IntegrationAgent.cs          # Wire dependencies
│   │   │   │   └── FixAgent.cs                  # Auto-error fixing
│   │   │   │
│   │   │   ├── Layer 5: Structured Patch Engine (Roslyn)
│   │   │   │   ├── PatchEngine.cs               # AST-based patching
│   │   │   │   ├── ASTParser.cs                 # Parse code to AST
│   │   │   │   ├── PatchApplier.cs              # Apply surgical changes
│   │   │   │   └── FormattingPreserver.cs       # Maintain code style
│   │   │   │
│   │   │   ├── Layer 6: Build & Validation
│   │   │   │   ├── BuildService.cs              # MSBuild wrapper
│   │   │   │   ├── ErrorClassifier.cs           # Classify build errors
│   │   │   │   ├── AutoFixEngine.cs             # Auto-fix strategies
│   │   │   │   └── ValidationLoop.cs            # Retry loop
│   │   │   │
│   │   │   ├── Layer 7: Memory & State Management
│   │   │   │   ├── StateManager.cs              # Persistent project state
│   │   │   │   ├── ProjectMemory.cs             # Stack decisions, patterns
│   │   │   │   ├── PatternMemory.cs             # Naming, routing conventions
│   │   │   │   ├── ErrorPatternMemory.cs        # Common error solutions
│   │   │   │   └── SessionContext.cs            # User preferences, history
│   │   │   │
│   │   │   ├── Legacy / Utility Services
│   │   │   │   ├── ProjectService.cs            # Project file management
│   │   │   │   ├── TemplateService.cs           # Template handling
│   │   │   │   └── ConfigService.cs             # Configuration
│   │   │   │
│   │   │   └── Infrastructure
│   │   │       ├── AIClient.cs                  # Claude/GPT API wrapper
│   │   │       ├── LoggingService.cs            # Structured logging (Serilog)
│   │   │       └── DatabaseService.cs           # SQLite backend (indexing, memory)
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
│   │   │   ├── RoslynHelper.cs                 # Roslyn utilities
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
│   │   ├── template.json
│   │   ├── MainWindow.xaml
│   │   └── MainWindow.xaml.cs
│   │
│   ├── TodoApp/
│   │   ├── template.json
│   │   ├── MainWindow.xaml
│   │   ├── MainWindow.xaml.cs
│   │   ├── Models/
│   │   └── ViewModels/
│   │
│   ├── Calculator/
│   │   ├── template.json
│   │   ├── MainWindow.xaml
│   │   └── MainWindow.xaml.cs
│   │
│   ├── WeatherApp/
│   │   └── ... (similar structure)
│   │
│   └── DatabaseApp/
│       └── ... (similar structure)
│
├── components/                        # Reusable components library
│   ├── Components.csproj
│   ├── Buttons/
│   │   ├── CustomButton.xaml
│   │   └── CustomButton.xaml.cs
│   ├── DataGrid/
│   │   ├── AdvancedDataGrid.xaml
│   │   └── AdvancedDataGrid.xaml.cs
│   ├── Forms/
│   │   └── FormBuilder.cs
│   └── Navigation/
│       └── MenuBar.xaml
│
├── ai-prompts/                        # AI system prompts
│   ├── system-prompts/
│   │   ├── xaml-generation.txt
│   │   ├── csharp-generation.txt
│   │   ├── database-schema.txt
│   │   └── api-integration.txt
│   ├── examples/
│   │   ├── simple-app.txt
│   │   ├── database-app.txt
│   │   └── api-integration.txt
│   └── prompts-config.json
│
├── examples/                          # Example generated projects
│   ├── HelloWorld/
│   ├── TodoMvc/
│   ├── Calculator/
│   └── WeatherApp/
│
├── scripts/                           # Build & automation scripts
│   ├── build.ps1                      # PowerShell build script
│   ├── test.ps1                       # Run tests
│   ├── deploy.ps1                     # Deployment script
│   ├── generate-docs.ps1              # Generate documentation
│   └── setup-dev.ps1                  # Dev environment setup
│
├── .github/                           # GitHub configuration
│   └── workflows/
│       ├── ci.yml                     # CI pipeline
│       └── release.yml                # Release pipeline
│
├── .gitignore                         # Git ignore rules
├── .editorconfig                      # Editor configuration
├── global.json                        # .NET SDK version
├── README.md                          # Project readme
└── LICENSE                            # License file
```

---

## File Descriptions

### Core Application (WinUI 3)

| File | Purpose |
|------|---------|
| `SyncAIAppBuilder.csproj` | WinUI 3 project (Windows App SDK, .NET 8) |
| `Program.cs` | WinUI app entry point (WinUIEx extensions) |
| `MainWindow.xaml` | Root window (Fluent Design System) |
| `MainWindow.xaml.cs` | Code-behind for root window |

### Services (Business Logic)

| Service | Responsibility |
|---------|-----------------|
| `AIService.cs` | Calls Claude/GPT APIs |
| `CodeGeneratorService.cs` | Generates XAML/C# code |
| `BuildService.cs` | Compiles projects to .exe |
| `ProjectService.cs` | Manages project files |
| `TemplateService.cs` | Handles project templates |

### Models (Data Structures)

| Model | Represents |
|-------|-----------|
| `Project.cs` | A single project |
| `CodeAnalysis.cs` | Generated code info |
| `Template.cs` | App template metadata |

### ViewModels (MVVM)

| ViewModel | Purpose |
|-----------|---------|
| `EditorViewModel.cs` | Prompt editor page logic |
| `ProjectsViewModel.cs` | Projects list logic |
| `PreviewViewModel.cs` | Preview page logic |

---

## Naming Conventions

### C# Code
- **Namespaces**: `SyncAIAppBuilder.Services`, `SyncAIAppBuilder.Models`
- **Classes**: `PascalCase` (e.g., `AIService`)
- **Methods**: `PascalCase` (e.g., `GenerateCode()`)
- **Properties**: `PascalCase` (e.g., `ProjectName`)
- **Private fields**: `_camelCase` (e.g., `_logger`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `MAX_RETRIES`)

### XAML
- **Names**: `x:Name="controlName"` in camelCase
- **Events**: `Event="OnEventName"`
- **Styles**: `Style="{StaticResource StyleName}"`

### Files
- **Code files**: `.cs` (e.g., `AIService.cs`)
- **XAML files**: `.xaml` (e.g., `MainWindow.xaml`)
- **Tests**: `*Tests.cs` (e.g., `AIServiceTests.cs`)
- **Config**: `.json` or `.xml`

---

## Build Output

```
bin/
├── Debug/
│   ├── net8.0-windows/
│   │   ├── SyncAIAppBuilder.exe
│   │   ├── SyncAIAppBuilder.dll
│   │   └── ... (dependencies)
│   └── ...
└── Release/
    └── ... (optimized builds)
```

---

## Project Dependencies

### Project Dependencies (WinUI 3)

#### NuGet Packages

```xml
<!-- WinUI 3 Framework (Windows App SDK) -->
<PackageReference Include="Microsoft.WindowsAppSDK" Version="1.5.0" />
<PackageReference Include="WinUIEx" Version="0.20.1" />

<!-- MVVM & Dependency Injection -->
<PackageReference Include="CommunityToolkit.Mvvm" Version="8.2.2" />
<PackageReference Include="Microsoft.Extensions.DependencyInjection" Version="8.0.0" />
<PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="8.0.0" />

<!-- AI Integration -->
<PackageReference Include="Anthropic.SDK" Version="latest" />

<!-- Code Analysis & Generation (Roslyn) -->
<PackageReference Include="Microsoft.CodeAnalysis.CSharp" Version="4.8.0" />
<PackageReference Include="Microsoft.CodeAnalysis.Analyzers" Version="3.3.4" />

<!-- Database (SQLite) -->
<PackageReference Include="Microsoft.Data.Sqlite" Version="8.0.0" />

<!-- Logging -->
<PackageReference Include="Serilog" Version="3.1.1" />
<PackageReference Include="Serilog.Sinks.File" Version="5.0.0" />

<!-- Testing -->
<PackageReference Include="xUnit" Version="2.6.6" />
<PackageReference Include="Moq" Version="4.20.70" />
<PackageReference Include="FluentAssertions" Version="6.12.0" />
```

#### Target Framework & Properties

```xml
<Project Sdk="Microsoft.NET.Sdk.WindowsDesktop">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows10.0.22621.0</TargetFramework>
    <RootNamespace>SyncAIAppBuilder</RootNamespace>
    <UseWinUI>true</UseWinUI>
    <StartupObject>SyncAIAppBuilder.Program</StartupObject>
  </PropertyGroup>
</Project>
```

---

## Development Workflow

### File Organization by Feature
When adding a new feature, create files in:
1. `Models/` - Define data structures
2. `Services/` - Implement business logic
3. `ViewModels/` - Add MVVM logic
4. `UI/Pages/` or `UI/Components/` - Create UI
5. `Tests/` - Add unit tests

### Example: Adding "Export to MSIX" Feature
```
Models/ExportConfig.cs
Services/ExportService.cs
ViewModels/ExportViewModel.cs
UI/Pages/ExportPage.xaml
UI/Pages/ExportPage.xaml.cs
Tests/Services/ExportServiceTests.cs
```

---

## Database Schema (SQLite)

```sql
-- Projects table
CREATE TABLE Projects (
    Id TEXT PRIMARY KEY,
    Name TEXT NOT NULL,
    Description TEXT,
    TemplateName TEXT,
    CreatedDate DATETIME,
    ModifiedDate DATETIME,
    ProjectPath TEXT NOT NULL
);

-- Project History
CREATE TABLE ProjectHistory (
    Id TEXT PRIMARY KEY,
    ProjectId TEXT,
    Timestamp DATETIME,
    Action TEXT,
    CodeSnapshot TEXT,
    FOREIGN KEY (ProjectId) REFERENCES Projects(Id)
);
```

---

## Configuration Files

### appsettings.json
```json
{
  "AI": {
    "Provider": "anthropic",
    "ApiKey": "***",
    "Model": "claude-3-sonnet"
  },
  "Build": {
    "OutputDirectory": "./output",
    "CleanBeforeBuild": true
  },
  "Logging": {
    "Level": "Information"
  }
}
```

### global.json
```json
{
  "sdk": {
    "version": "8.0.0",
    "rollForward": "latestMinor"
  }
}
```
