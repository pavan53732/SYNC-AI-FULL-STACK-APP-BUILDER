# Development Guide

> [!NOTE]
> This guide is for **contributors developing the SyncAI Explorer tool itself**.
> Users of the completed application do NOT need these tools, as the environment is autonomous and self-contained.

## Getting Started

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

---

## Technology Stack

> [!NOTE]
> This section was previously maintained as a separate `TECHNOLOGY_STACK.md` file. It is now consolidated here as the single source of truth for all technology choices.

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

See [DATABASE_SPECIFICATION.md](DATABASE_SPECIFICATION.md) for complete schema definitions.

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

---

## WinUI 3 Development Patterns

### XAML & Data Binding (INotifyPropertyChanged)

All ViewModels must implement `INotifyPropertyChanged` for XAML binding:

```csharp
// src/SyncAIAppBuilder/ViewModels/EditorViewModel.cs
using CommunityToolkit.Mvvm.ComponentModel;

public partial class EditorViewModel : ObservableObject
{
    [ObservableProperty]
    private string promptText = "";

    [ObservableProperty]
    private bool isGenerating = false;

    public async Task GenerateAsync()
    {
        IsGenerating = true;
        try
        {
            var result = await _aiClient.GenerateAsync(PromptText);
            // Update PromptText automatically notifies XAML bindings
        }
        finally
        {
            IsGenerating = false;
        }
    }
}
```

XAML binding:

```xml
<TextBox Text="{x:Bind ViewModel.PromptText, Mode=TwoWay}" />
<Button IsEnabled="{x:Bind ViewModel.IsGenerating, Mode=OneWay, Converter={StaticResource InverseBoolConverter}}" />
```

### Async/Await & DispatcherQueue (Threading)

WinUI 3 uses `DispatcherQueue` for thread marshaling (not `Dispatcher`):

```csharp
public async Task HandleLongOperationAsync()
{
    // Long operation on background thread
    var result = await Task.Run(() => ExpensiveOperation());

    // Marshal back to UI thread
    DispatcherQueue.TryEnqueue(() =>
    {
        // Update UI properties here
        ResultText = result;
    });
}
```

**Never block the UI thread**: Always use `async/await` for I/O operations.

### MVVM Dependency Injection

Configure services in `Program.cs`:

```csharp
var builder = new HostBuilder()
    .ConfigureServices(services =>
    {
        services.AddSingleton<MainWindow>();
        services.AddSingleton<MainViewModel>();
        services.AddSingleton<IEditorViewModel, EditorViewModel>();
        services.AddSingleton<IAIClient, EngineClient>();
        services.AddSingleton<CodeIntelligenceService>();
        // ... other services
    });
```

Inject in ViewModels:

```csharp
public class EditorViewModel : ObservableObject
{
    private readonly IAIClient _aiClient;

    public EditorViewModel(IAIClient aiClient)
    {
        _aiClient = aiClient;
    }
}
```

### MSIX Packaging for Distribution

WinUI 3 apps are packaged as MSIX:

```xml
<!-- SyncAIAppBuilder.csproj -->
<PropertyGroup>
  <WindowsPackageType>None</WindowsPackageType>
  <PublishProfile>win10-x64</PublishProfile>
</PropertyGroup>
```

Build MSIX for distribution:

```bash
dotnet publish -c Release -r win10-x64 --self-contained false
```

---

## Local Execution Constraints (Response 7 - Developer Requirements)

### Machine Variability Your Builder Must Handle

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

        // 3. Check disk space
        var diskSpace = GetAvailableDiskSpace(_projectPath);
        if (diskSpace < 1_000_000_000)  // 1 GB
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

### Performance Optimization (Local-Only Constraints)

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

    /// Use incremental build, not full rebuild
    public async Task<BuildResult> IncrementalBuildAsync(
        string projectPath,
        CancellationToken cancellation)
    {
        // Let MSBuild determine what changed - don't force full rebuild
        var args = "build --no-incremental:false";  // Enables incremental

        return await _buildKernel.BuildAsync(projectPath, args, cancellation);
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

/// Classify errors and suggest fixes
public class ErrorClassifierLocal
{
    public LocalBuildErrorCategory ClassifyError(string buildOutput)
    {
        if (buildOutput.Contains("MSB4236") && buildOutput.Contains("workload"))
            return LocalBuildErrorCategory.MISSING_WORKLOAD;

        if (buildOutput.Contains("Could not restore"))
            return LocalBuildErrorCategory.NUGET_RESTORE_FAILURE;

        if (buildOutput.Contains("error CS") && !buildOutput.Contains("XC"))
            return LocalBuildErrorCategory.COMPILATION_ERROR;

        if (buildOutput.Contains("XamlCompiler") || buildOutput.Contains("XC0"))
            return LocalBuildErrorCategory.XAML_BINDING_ERROR;

        if (buildOutput.Contains("OutOfMemoryException") || buildOutput.Contains("was not available"))
            return LocalBuildErrorCategory.RESOURCE_EXHAUSTION;

        return LocalBuildErrorCategory.COMPILATION_ERROR;
    }
}
```

---

## Multi-Agent Architecture Implementation

### Understanding the 7-Layer System

See [INTERNAL_ARCHITECTURE.md](INTERNAL_ARCHITECTURE.md) for comprehensive details. This section covers implementation specifics.

### 🔴 CRITICAL: Implementation Sequence (Response 4 - Orchestrator First)

**IMPORTANT**: The correct implementation order has been validated by production architecture review.

**DO NOT START WITH LAYER 1 (Intent)**. Instead:

#### Phase 1A: Deterministic Orchestrator Foundation (MUST BE FIRST)

1. **Orchestrator Core** (See [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md))
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

---

### Layer 3: Code Intelligence with Roslyn Indexing

**Goal**: Index C# code to enable smart retrieval and AST-based modifications.

**Implementation**:

```csharp
// src/SyncAIAppBuilder/Services/CodeIntelligenceService.cs
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

public class CodeIntelligenceService
{
    public async Task IndexProjectAsync(string projectPath)
    {
        var workspace = MSBuildWorkspace.Create();
        var solution = await workspace.OpenSolutionAsync(projectPath);

        foreach (var project in solution.Projects)
        {
            var compilation = await project.GetCompilationAsync();

            // Index all symbols (classes, methods, properties)
            IndexSymbols(compilation.GlobalNamespace);

            // Build dependency graph
            BuildDependencyGraph(solution);

            // Store in SQLite
            await StoreSQLiteAsync(compilation);
        }
    }

    private void IndexSymbols(INamespaceSymbol ns)
    {
        foreach (var symbol in ns.GetMembers())
        {
            if (symbol is INamedTypeSymbol classSymbol)
            {
                // Store metadata: name, namespace, methods, properties
                _db.Insert(new SymbolIndex
                {
                    Name = classSymbol.Name,
                    FullName = classSymbol.ToDisplayString(),
                    Kind = "Class",
                    Methods = classSymbol.GetMembers().OfType<IMethodSymbol>().ToList()
                });
            }
        }
    }
}
```

### Layer 4: Multi-Agent Orchestration

**Template for Creating a New Agent**:

```csharp
// src/SyncAIAppBuilder/Agents/IAgent.cs
public interface IAgent
{
    Task<AgentOutput> GenerateAsync(AgentInput input);
}

// src/SyncAIAppBuilder/Agents/CustomAgent.cs
public class CustomAgent : IAgent
{
    private readonly IAIClient _aiClient;

    public async Task<AgentOutput> GenerateAsync(AgentInput input)
    {
        // 1. Build system prompt for this agent
        var systemPrompt = GetSystemPrompt();

        // 2. Call AI Engine with structured input
        var response = await _aiClient.GenerateAsync(new AI EngineRequest
        {
            SystemPrompt = systemPrompt,
            UserInput = JsonConvert.SerializeObject(input),
            OutputSchema = typeof(AgentOutput) // Enforce structure
        });

        // 3. Parse structured response
        var output = JsonConvert.DeserializeObject<AgentOutput>(response);

        // 4. Validate output
        ValidateOutput(output);

        return output;
    }

    private string GetSystemPrompt()
    {
        return @"You are a C# code generation agent.
Your responsibility: [specific task]
Output format: JSON
{
    ""files"": [...],
    ""changes"": [...]
}
Do NOT output markdown, comments, or explanations.
Output ONLY valid JSON that can be parsed.";
    }
}
```

**Orchestrator Pattern**:

```csharp
// src/SyncAIAppBuilder/Services/AgentOrchestrator.cs
public class AgentOrchestrator
{
    public async Task<ProjectGeneration> ExecuteAsync(
        ProjectSpec spec,
        TaskGraph taskGraph)
    {
        // Stage 1: Architect defines structure
        var architecture = await _architectAgent.GenerateAsync(spec);

        // Stage 2: Parallel agents (no dependencies)
        var tasks = new[]
        {
            _schemaAgent.GenerateAsync(architecture),
            _authAgent.GenerateAsync(architecture)
        };
        await Task.WhenAll(tasks);

        // Stage 3: Dependent agents
        var uiOutput = await _frontendAgent.GenerateAsync(
            new FrontendInput { Architecture = architecture }
        );

        // Stage 4: Integration
        var integrated = await _integrationAgent.GenerateAsync(
            new IntegrationInput {
                Architecture = architecture,
                UI = uiOutput
            }
        );

        // Stage 5: Build & auto-fix
        return await BuildAndValidateAsync(integrated);
    }
}
```

### Layer 5: Roslyn AST-Based Patching

**AST Manipulation for Code Modification**:

```csharp
// src/SyncAIAppBuilder/Services/PatchEngine.cs
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

public class PatchEngine
{
    /// <summary>
    /// Add [Required] attribute to a property without full rewrite
    /// </summary>
    public string AddAttributeToProperty(
        string sourceCode,
        string propertyName,
        string attributeName)
    {
        // Parse to AST
        var tree = CSharpSyntaxTree.ParseText(sourceCode);
        var root = (CompilationUnitSyntax)tree.GetRoot();

        // Find target property
        var targetProperty = root
            .DescendantNodes()
            .OfType<PropertyDeclarationSyntax>()
            .First(p => p.Identifier.Text == propertyName);

        // Create attribute
        var attribute = SyntaxFactory.Attribute(
            SyntaxFactory.IdentifierName(attributeName));

        // Add attribute to property
        var updatedProperty = targetProperty.AddAttributeLists(
            SyntaxFactory.AttributeList(
                SyntaxFactory.SingletonSeparatedList(attribute)));

        // Replace node in tree
        var newRoot = root.ReplaceNode(targetProperty, updatedProperty);

        // Convert back to string (preserves formatting!)
        return newRoot.ToFullString();
    }

    /// <summary>
    /// Add a using statement if not present
    /// </summary>
    public string AddUsingIfMissing(string sourceCode, string namespaceName)
    {
        var tree = CSharpSyntaxTree.ParseText(sourceCode);
        var root = (CompilationUnitSyntax)tree.GetRoot();

        // Check if already present
        var existingUsing = root.Usings
            .FirstOrDefault(u => u.Name.ToString() == namespaceName);

        if (existingUsing != null)
            return sourceCode; // Already present

        // Add using directive
        var newUsing = SyntaxFactory.UsingDirective(
            SyntaxFactory.ParseName(namespaceName));

        var newRoot = root.AddUsings(newUsing);
        return newRoot.ToFullString();
    }
}
```

### Layer 6: Build & Auto-Fix Loop

**Error Classification & Auto-Fix**:

```csharp
// src/SyncAIAppBuilder/Services/AutoFixEngine.cs
public class AutoFixEngine
{
    public async Task<bool> AutoFixAndRetryAsync(
        string projectPath,
        List<CompilerError> errors)
    {
        const int maxRetries = 5;
        int retryCount = 0;

        while (retryCount < maxRetries && errors.Count > 0)
        {
            retryCount++;

            foreach (var error in errors)
            {
                var fixStrategy = ClassifyAndFix(error);

                // Apply the fix
                await fixStrategy.ApplyAsync(projectPath);
            }

            // Rebuild
            var buildResult = await BuildAsync(projectPath);

            if (buildResult.Success)
                return true; // Success!

            errors = buildResult.Errors;
        }

        // Failed after max retries
        return false;
    }

    private IFixStrategy ClassifyAndFix(CompilerError error)
    {
        return error.Code switch
        {
            "CS0106" => new AddUsingFix(error),
            "CS1503" => new AddTypeConversionFix(error),
            "CS0103" => new AddPropertyFix(error),
            _ => new GenericAI EngineFix(error)
        };
    }
}
```

### Layer 7: Semantic Search with Embeddings

**Setup Vector Embeddings**:

```csharp
// src/SyncAIAppBuilder/Services/EmbeddingService.cs
public class EmbeddingService
{
    public async Task IndexCodeWithEmbeddingsAsync(string projectPath)
    {
        var files = Directory.GetFiles(projectPath, "*.cs",
            SearchOption.AllDirectories);

        foreach (var file in files)
        {
            var content = File.ReadAllText(file);

            // Split into semantic chunks
            var chunks = SplitIntoChunks(content);

            foreach (var chunk in chunks)
            {
                // Generate embedding via AI Engine
                var embedding = await _embeddingClient.EmbedAsync(chunk);

                // Store in SQLite
                await _db.InsertEmbeddingAsync(new CodeEmbedding
                {
                    FilePath = file,
                    CodeSection = chunk,
                    Embedding = embedding, // Vector stored as BLOB
                    CreatedAt = DateTime.UtcNow
                });
            }
        }
    }

    /// <summary>
    /// Smart retrieval: semantic search for relevant code
    /// </summary>
    public async Task<List<string>> GetRelevantFilesAsync(
        string userPrompt,
        int topK = 5)
    {
        // Embed the prompt
        var promptEmbedding = await _embeddingClient.EmbedAsync(userPrompt);

        // Semantic search in database (cosine similarity)
        var similarCode = await _db.SearchEmbeddingsAsync(
            promptEmbedding,
            topK);

        return similarCode
            .Select(x => x.FilePath)
            .Distinct()
            .ToList();
    }
}
```

---

## Development Workflow

### 1. Create Feature Branch

```bash
git checkout -b feature/feature-name
```

### 2. Make Changes

**Create new agent:**

```csharp
// src/SyncAIAppBuilder/Agents/MyNewAgent.cs
namespace SyncAIAppBuilder.Agents
{
    public class MyNewAgent : IAgent
    {
        private readonly IAIClient _aiClient;

        public MyNewAgent(IAIClient aiClient)
        {
            _aiClient = aiClient;
        }

        public async Task<AgentOutput> GenerateAsync(AgentInput input)
        {
            // Implementation
        }
    }
}
```

**Add tests:**

```csharp
// src/SyncAIAppBuilder.Tests/Agents/MyNewAgentTests.cs
[TestFixture]
public class MyNewAgentTests
{
    [Test]
    public async Task GenerateAsync_WithValidInput_ReturnsValidOutput()
    {
        // Arrange
        var mockAIClient = new Mock<IAIClient>();
        var agent = new MyNewAgent(mockAIClient.Object);

        // Act
        var result = await agent.GenerateAsync(testInput);

        // Assert
        Assert.That(result, Is.Not.Null);
        Assert.That(result.Files, Is.Not.Empty);
    }
}
```

### 3. Run Tests

```bash
dotnet test src/SyncAIAppBuilder.Tests/SyncAIAppBuilder.Tests.csproj
```

### 4. Build Project

```bash
dotnet build src/SyncAIAppBuilder/SyncAIAppBuilder.csproj
```

### 5. Run Application

```bash
cd src/SyncAIAppBuilder
dotnet run
```

### 6. Commit Changes

```bash
git add .
git commit -m "feat: add feature name"
git push origin feature/feature-name
```

### 7. Create Pull Request

- Go to GitHub repository
- Create PR from your feature branch
- Add description and link issues

---

## Project Structure

### Main Application

```
src/SyncAIAppBuilder/
├── UI/              # WinUI 3 frontend
├── Services/        # Business logic
├── Models/          # Data structures
├── ViewModels/      # MVVM pattern
└── Utils/           # Helper functions
```

### Testing

```
src/SyncAIAppBuilder.Tests/
├── Services/        # Service tests
└── Utils/           # Utility tests
```

---

## Key Classes & Interfaces

### AIService

Handles communication with AI Engine API.

```csharp
public interface IAIService
{
    Task<string> GenerateCodeAsync(string prompt, string context);
    Task<CodeAnalysis> AnalyzeCodeAsync(string code);
}
```

### CodeGeneratorService

Generates XAML and C# code from AI output.

```csharp
public interface ICodeGenerator
{
    Task<GeneratedCode> GenerateAsync(string prompt);
    CodeFile GenerateXAML(UISchema schema);
    CodeFile GenerateCodeBehind(UISchema schema);
}
```

### BuildService

Compiles projects to .exe using MSBuild.

```csharp
public interface IBuildService
{
    Task<BuildResult> BuildAsync(string projectPath);
    Task<bool> ValidateProject(string projectPath);
}
```

### ProjectService

Manages project files and metadata.

```csharp
public interface IProjectService
{
    Task<Project> CreateProjectAsync(string name, string template);
    Task<Project> LoadProjectAsync(string projectPath);
    Task SaveProjectAsync(Project project);
}
```

---

## Common Tasks

### Add a New Page (WinUI 3)

**1. Create XAML:**

```xml
<!-- src/SyncAIAppBuilder/UI/Pages/NewPage.xaml -->
<?xml version="1.0" encoding="utf-8"?>
<Page
    x:Class="SyncAIAppBuilder.UI.Pages.NewPage"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <StackPanel Padding="20">
        <TextBlock Text="New Page Title" FontSize="28" Margin="0,0,0,20"/>
        <Button Content="Click Me" Click="OnButtonClick"/>
    </StackPanel>
</Page>
```

**2. Create Code-behind:**

```csharp
// src/SyncAIAppBuilder/UI/Pages/NewPage.xaml.cs
using Microsoft.UI.Xaml.Controls;

namespace SyncAIAppBuilder.UI.Pages
{
    public sealed partial class NewPage : Page
    {
        public NewPage()
        {
            this.InitializeComponent();
        }

        private void OnButtonClick(object sender, RoutedEventArgs e)
        {
            // Handle click
        }
    }
}
```

**3. Register in Main Navigation:**

```csharp
// In MainWindow.xaml.cs
NavigationView.MenuItems.Add(new NavigationViewItem
{
    Content = "New Page",
    Icon = new SymbolIcon(Symbol.Document)
});
```

---

### Add a New Service

**1. Define Interface:**

```csharp
// src/SyncAIAppBuilder.Core/Interfaces/IMyService.cs
namespace SyncAIAppBuilder.Core.Interfaces
{
    public interface IMyService
    {
        Task<T> GetDataAsync();
        void ProcessData(T data);
    }
}
```

**2. Implement Service:**

```csharp
// src/SyncAIAppBuilder/Services/MyService.cs
using SyncAIAppBuilder.Core.Interfaces;

namespace SyncAIAppBuilder.Services
{
    public class MyService : IMyService
    {
        private readonly ILogger<MyService> _logger;

        public MyService(ILogger<MyService> logger)
        {
            _logger = logger;
        }

        public async Task<T> GetDataAsync()
        {
            _logger.LogInformation("Getting data...");
            // Implementation
        }

        public void ProcessData(T data)
        {
            _logger.LogInformation("Processing data...");
            // Implementation
        }
    }
}
```

**3. Register in DI Container:**

```csharp
// In Program.cs
var services = new ServiceCollection();
services.AddScoped<IMyService, MyService>();
```

---

### Add Unit Tests

```csharp
// src/SyncAIAppBuilder.Tests/Services/MyServiceTests.cs
using NUnit.Framework;
using Moq;

namespace SyncAIAppBuilder.Tests.Services
{
    [TestFixture]
    public class MyServiceTests
    {
        private MyService _service;
        private Mock<ILogger<MyService>> _mockLogger;

        [SetUp]
        public void Setup()
        {
            _mockLogger = new Mock<ILogger<MyService>>();
            _service = new MyService(_mockLogger.Object);
        }

        [Test]
        public async Task GetDataAsync_Returns_ValidData()
        {
            // Arrange

            // Act
            var result = await _service.GetDataAsync();

            // Assert
            Assert.That(result, Is.Not.Null);
        }

        [Test]
        public void ProcessData_WithValidData_Succeeds()
        {
            // Arrange
            var testData = new TestData();

            // Act & Assert
            Assert.DoesNotThrow(() => _service.ProcessData(testData));
        }
    }
}
```

---

## Code Style & Standards

### C# Coding Standards

- Use `async/await` for async operations
- Use `using` statements for resource management
- Follow SOLID principles
- Use meaningful variable names
- Keep methods focused and small (< 50 lines)
- Use null-coalescing operators (`??`)

### XAML Standards

- Use data binding instead of code-behind logic
- Use MVVM pattern
- Keep XAML clean and readable
- Use resources for colors, styles, strings

### Git Commit Messages

```
feat: add user authentication
fix: resolve null reference exception
docs: update README
refactor: simplify code generation logic
test: add tests for AI service
style: format code
chore: update dependencies
```

---

## Debugging

### Debug Application

```bash
# Run in debug mode
dotnet run --configuration Debug

# Or from Visual Studio - Press F5
```

### Common Issues

**Issue: "Cannot find WinUI 3 types"**

- Solution: Install Windows App SDK via Visual Studio
- Run: `dotnet workload restore`

**Issue: "API key not found"**

- Solution: Ensure `appsettings.json` is in correct location
- Check: `src/SyncAIAppBuilder/appsettings.json`

**Issue: "MSBuild not found"**

- Solution: Install Visual Studio Build Tools
- Or: Add `<UseMSBuildFromVS>true</UseMSBuildFromVS>` to .csproj

---

## Performance Tips

1. **Use async/await** - Don't block UI thread
2. **Cache AI responses** - Don't call API for same prompt
3. **Lazy load components** - Load only when needed
4. **Profile with Diagnostics Tool** - Find bottlenecks
5. **Use Release builds** - For performance testing

---

## Documentation

### Code Comments

```csharp
/// <summary>
/// Generates C# code from XAML schema.
/// </summary>
/// <param name="schema">UI schema definition</param>
/// <returns>Generated C# code file</returns>
public CodeFile GenerateCodeBehind(UISchema schema)
{
    // Implementation
}
```

### Update Documentation

When adding features:

1. Update `FEATURES.md`
2. Update `ARCHITECTURE.md` if needed
3. Update this guide with new procedures

---

## Resources

- [WinUI 3 Documentation](https://learn.microsoft.com/en-us/windows/apps/winui/winui3/)
- [.NET Documentation](https://docs.microsoft.com/en-us/dotnet/)
- [Internal API Documentation](file:///c:/Users/pavan/projects/SYNC-AI-FULL-STACK-APP-BUILDER/docs/API_DOCUMENTATION.md)
- [MVVM Pattern Guide](https://docs.microsoft.com/en-us/archive/msdn-magazine/2009/february/patterns-wpf-apps-with-the-model-view-viewmodel-design-pattern)

---

## Support

- Create issue on GitHub for bugs
- Discussions for feature requests
- Wiki for extended documentation
