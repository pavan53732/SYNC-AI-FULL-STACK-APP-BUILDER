# Project Layout & Subsystems

## User Workspace Directory Structure (Local Execution)

This document outlines the directory layout for the **SyncAI Explorer** project. The structure is designed to separate the **Autonomous Construction Engine** from the user interface and the generated project sandbox.

### User Workspace Layout

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

**Key Points**:
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
│   ├── INTERNAL_ARCHITECTURE.md       # Multi-agent system details
│   ├── INTERNAL_EXECUTION_ARCHITECTURE.md # Internal subsystems
│   ├── LOCAL_EXECUTION_ARCHITECTURE.md # Local-only deployment
│   ├── ORCHESTRATOR_SPECIFICATION.md  # Deterministic orchestrator
│   ├── TECHNOLOGY_STACK.md            # Tech choices (WinUI 3)
│   ├── FEATURES.md                    # Feature roadmap
│   ├── PROJECT_STRUCTURE.md           # This file
│   ├── DEVELOPMENT_GUIDE.md           # Development setup
│   ├── API_DOCUMENTATION.md           # API specs
│   ├── DEPLOYMENT.md                  # Deployment guide (MSIX)
│   ├── DESIGN_PHILOSOPHY.md           # UX design principles
│   ├── USER_WORKFLOW.md               # User behavior & workflow
│   └── AI_ENGINE_OUTPUT_CONTRACTS.md  # AI Engine output schemas
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
│   │   │       ├── AIClient.cs                  # AI Engine wrapper (z-ai-web-dev-sdk)
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
| `AIService.cs` | Calls AI Engine API |
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
<PackageReference Include="z-ai-web-dev-sdk" Version="latest" />

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
    "Engine": "z-ai-web-dev-sdk",
    "Logging": "verbose"
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

---

## .csproj File Examples

### Main WinUI 3 Application (.csproj)

**File**: `src/SyncAIAppBuilder/SyncAIAppBuilder.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows10.0.19041.0</TargetFramework>
    <TargetPlatformMinVersion>10.0.17763.0</TargetPlatformMinVersion>
    <RootNamespace>SyncAIAppBuilder</RootNamespace>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <Platforms>x86;x64;ARM64</Platforms>
    <RuntimeIdentifiers>win-x86;win-x64;win-arm64</RuntimeIdentifiers>
    <PublishProfile>win-$(Platform).pubxml</PublishProfile>
    <UseWinUI>true</UseWinUI>
    <EnableMsixTooling>true</EnableMsixTooling>
    <Nullable>enable</Nullable>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>

  <ItemGroup>
    <!-- Windows App SDK (WinUI 3) -->
    <PackageReference Include="Microsoft.WindowsAppSDK" Version="1.5.240311000" />
    <PackageReference Include="Microsoft.Windows.SDK.BuildTools" Version="10.0.22621.756" />
    
    <!-- Roslyn Code Analysis -->
    <PackageReference Include="Microsoft.CodeAnalysis.CSharp" Version="4.9.2" />
    <PackageReference Include="Microsoft.CodeAnalysis.CSharp.Workspaces" Version="4.9.2" />
    
    <!-- Dependency Injection -->
    <PackageReference Include="Microsoft.Extensions.DependencyInjection" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Logging" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Logging.Console" Version="8.0.0" />
    
    <!-- SQLite Database -->
    <PackageReference Include="Microsoft.Data.Sqlite" Version="8.0.2" />
    <PackageReference Include="Dapper" Version="2.1.28" />
    
    <!-- JSON Serialization -->
    <PackageReference Include="System.Text.Json" Version="8.0.2" />
    
    <!-- AI SDK -->
    <PackageReference Include="z-ai-web-dev-sdk" Version="1.0.0" />
    
    <!-- Community Toolkit -->
    <PackageReference Include="CommunityToolkit.Mvvm" Version="8.2.2" />
    <PackageReference Include="CommunityToolkit.WinUI.UI.Controls" Version="7.1.2" />
  </ItemGroup>

  <ItemGroup>
    <!-- Project References -->
    <ProjectReference Include="..\SyncAIAppBuilder.Core\SyncAIAppBuilder.Core.csproj" />
  </ItemGroup>

  <ItemGroup>
    <!-- XAML Files -->
    <Page Update="UI\MainWindow.xaml">
      <Generator>MSBuild:Compile</Generator>
    </Page>
    <Page Update="UI\Pages\EditorPage.xaml">
      <Generator>MSBuild:Compile</Generator>
    </Page>
    <Page Update="UI\Pages\PreviewPage.xaml">
      <Generator>MSBuild:Compile</Generator>
    </Page>
    <Page Update="UI\Pages\ProjectsPage.xaml">
      <Generator>MSBuild:Compile</Generator>
    </Page>
    <Page Update="UI\Pages\SettingsPage.xaml">
      <Generator>MSBuild:Compile</Generator>
    </Page>
  </ItemGroup>

  <ItemGroup>
    <!-- Assets -->
    <Content Include="Assets\**\*">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Content>
  </ItemGroup>
</Project>
```

### Core Library (.csproj)

**File**: `src/SyncAIAppBuilder.Core/SyncAIAppBuilder.Core.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>SyncAIAppBuilder.Core</RootNamespace>
    <Nullable>enable</Nullable>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>

  <ItemGroup>
    <!-- Roslyn Code Analysis -->
    <PackageReference Include="Microsoft.CodeAnalysis.CSharp" Version="4.9.2" />
    <PackageReference Include="Microsoft.CodeAnalysis.CSharp.Workspaces" Version="4.9.2" />
    
    <!-- Logging -->
    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="8.0.0" />
    
    <!-- SQLite -->
    <PackageReference Include="Microsoft.Data.Sqlite" Version="8.0.2" />
    <PackageReference Include="Dapper" Version="2.1.28" />
    
    <!-- JSON -->
    <PackageReference Include="System.Text.Json" Version="8.0.2" />
    
    <!-- AI SDK -->
    <PackageReference Include="z-ai-web-dev-sdk" Version="1.0.0" />
  </ItemGroup>
</Project>
```

### Unit Tests (.csproj)

**File**: `tests/SyncAIAppBuilder.Tests/SyncAIAppBuilder.Tests.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
    <Nullable>enable</Nullable>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>

  <ItemGroup>
    <!-- Testing Frameworks -->
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.9.0" />
    <PackageReference Include="MSTest.TestAdapter" Version="3.2.2" />
    <PackageReference Include="MSTest.TestFramework" Version="3.2.2" />
    <PackageReference Include="coverlet.collector" Version="6.0.1" />
    
    <!-- Mocking -->
    <PackageReference Include="Moq" Version="4.20.70" />
    
    <!-- Assertions -->
    <PackageReference Include="FluentAssertions" Version="6.12.0" />
  </ItemGroup>

  <ItemGroup>
    <!-- Project References -->
    <ProjectReference Include="..\..\src\SyncAIAppBuilder.Core\SyncAIAppBuilder.Core.csproj" />
    <ProjectReference Include="..\..\src\SyncAIAppBuilder\SyncAIAppBuilder.csproj" />
  </ItemGroup>
</Project>
```

### Generated User Project (.csproj)

**File**: `Workspaces/{ProjectId}/src/GeneratedApp.csproj`

This is the .csproj file that the AI generates for user projects:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows10.0.19041.0</TargetFramework>
    <TargetPlatformMinVersion>10.0.17763.0</TargetPlatformMinVersion>
    <RootNamespace>GeneratedApp</RootNamespace>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <Platforms>x86;x64;ARM64</Platforms>
    <UseWinUI>true</UseWinUI>
    <EnableMsixTooling>true</EnableMsixTooling>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <!-- Windows App SDK -->
    <PackageReference Include="Microsoft.WindowsAppSDK" Version="1.5.240311000" />
    <PackageReference Include="Microsoft.Windows.SDK.BuildTools" Version="10.0.22621.756" />
    
    <!-- Community Toolkit (commonly used) -->
    <PackageReference Include="CommunityToolkit.Mvvm" Version="8.2.2" />
    <PackageReference Include="CommunityToolkit.WinUI.UI.Controls" Version="7.1.2" />
    
    <!-- SQLite (if database features requested) -->
    <PackageReference Include="Microsoft.Data.Sqlite" Version="8.0.2" />
    
    <!-- Additional packages added by AI as needed -->
  </ItemGroup>

  <ItemGroup>
    <!-- XAML Files (generated by AI) -->
    <Page Include="MainWindow.xaml" />
    <!-- Additional XAML pages added by AI -->
  </ItemGroup>
</Project>
```

### Key .csproj Properties Explained

| Property | Purpose | Value |
|----------|---------|-------|
| `TargetFramework` | .NET version + Windows SDK | `net8.0-windows10.0.19041.0` |
| `TargetPlatformMinVersion` | Minimum Windows version | `10.0.17763.0` (Windows 10 1809) |
| `UseWinUI` | Enable WinUI 3 support | `true` |
| `EnableMsixTooling` | Enable MSIX packaging | `true` |
| `Nullable` | Enable nullable reference types | `enable` |
| `LangVersion` | C# language version | `latest` |
| `Platforms` | Supported CPU architectures | `x86;x64;ARM64` |

### Package Version Management

All package versions are managed centrally. When the AI generates projects, it uses the same package versions as the builder application to ensure compatibility.

**Version Pinning Strategy**:
- Windows App SDK: `1.5.x` (latest stable)
- .NET SDK: `8.0.x` (LTS)
- Roslyn: `4.9.x` (matches .NET 8)
- Community Toolkit: `8.x` (latest stable)

---
