# Technology Stack

## Backend / Core Logic

### Language & Framework
- **Primary Language**: C# (.NET 8.0+)
- **Runtime**: .NET Runtime (managed, GC)
- **IDE**: Visual Studio 2022 (primary), VS Code with C# Dev Kit
- **Architecture**: Multi-layer with Orchestrator (deterministic state machine)

### Core Libraries
- **Orchestration**: Custom state machine (events, reducers, task dispatch)
- **HTTP Client**: HttpClient (built-in, async-first)
- **AI Integration**: Anthropic SDK for Claude API
- **Code Analysis**: Roslyn (Microsoft.CodeAnalysis.* NuGet packages)
- **Configuration**: Microsoft.Extensions.Configuration (.json files)
- **Dependency Injection**: Microsoft.Extensions.DependencyInjection (service container)
- **Logging**: Serilog + Serilog.Sinks.File (local file logging)
- **JSON Serialization**: System.Text.Json (async-safe, UTF-8)
- **Testing**: xUnit (modern, async-friendly)
- **Database**: SQLite (Microsoft.Data.Sqlite)

---

## Frontend / UI

### Framework: WinUI 3 (Confirmed Choice)
- **Framework**: Windows App SDK (WinUI 3)
- **Language**: C# + XAML
- **Target**: Windows 10 Build 22621+ (Windows 11 standard)
- **Deployment**: MSIX package format
- **Modern Design**: Fluent Design System
- **Threading**: Async/await patterns, DispatcherQueue
- **Binding**: INotifyPropertyChanged, MVVM compatible
- **Package Manager**: NuGet (Windows App SDK packages)

#### WinUI 3 Key NuGet Packages
```
Microsoft.WindowsAppSDK (latest stable, e.g., 1.4.x)
Microsoft.Windows.AppNotifications (notifications)
Microsoft.Windows.AppWindowsAdapters (multi-window)
CommunityToolkit.WinUI (XAML controls, helpers)
CommunityToolkit.Mvvm (MVVM patterns, dependency injection)
Microsoft.Extensions.DependencyInjection (service container)
```

---

## AI Integration

### LLM Providers
- **Primary**: Anthropic Claude API (Claude 3+ models)
- **Alternative**: OpenAI GPT-4 / GPT-4o
- **Local Option**: Ollama + Llama 2/Mistral (for privacy)

### Prompting Strategy
- System prompts for code generation
- Few-shot examples for patterns
- Chain-of-thought for complex logic
- Structured output (JSON) for parsing

---

## Code Generation & Build

### XAML/C# Generation
- **Roslyn**: For C# code generation and analysis
- **StringBuilder**: For template-based generation
- **Regex**: For code manipulation

### Build System
- **MSBuild**: .NET project compilation
- **.NET CLI**: dotnet commands for building
- **Project SDK**: Microsoft.NET.Sdk (modern format)

### Package Management
- **NuGet**: For dependency management
- **NuGet API**: Programmatic package management

---

## Database (Optional)

### For Storing Projects/Templates
- **SQLite**: Lightweight, file-based
- **SQL Server Express**: Heavier, enterprise
- **PostgreSQL**: If cloud-based backend

**Recommendation**: Start with SQLite for MVP

---

## Version Control & Collaboration

- **Git**: VCS
- **GitHub/GitLab API**: Integration
- **Semantic Versioning**: For generated apps

---

## DevOps & Deployment

### Build & Release
- **GitHub Actions**: CI/CD
- **Azure DevOps**: Alternative
- **AppVeyor**: Azure pipelines

### Distribution (WinUI 3 / MSIX)
- **MSIX Format**: Modern Windows app package (encrypted, versioned, rollback-safe)
- **Windows App Installer**: Auto-update capable (.appinstaller files)
- **Microsoft Store**: Optional distribution channel (simplified installation)
- **Direct Download**: Self-hosted MSIX (enterprise teams)
- **Code Signing**: Authenticode certificates for trust

**WinUI 3 Standard**: MSIX deployment with Windows App Installer for updates

---

## Development Tools

- **Git**: Version control
- **Visual Studio 2022**: Primary IDE
- **VS Code**: Light editor + extensions
- **Postman / Thunder Client**: API testing
- **Docker** (optional): For local dev environment

---

## Testing Stack

- **Unit Testing**: NUnit / xUnit
- **Integration Testing**: Test containers
- **UI Testing**: Appium / Windows Application Driver
- **Load Testing**: k6 or Apache JMeter

---

## Monitoring & Logging

- **Logging**: Serilog + Seq (log aggregation)
- **Error Tracking**: Sentry or Application Insights
- **Analytics**: Custom telemetry (privacy-respecting)

---

## Compliance & Security

- **HTTPS/TLS**: For API communication
- **API Key Management**: Azure Key Vault or local secure storage
- **Code Signing**: Authenticode for .exe files
- **SBOM**: Software Bill of Materials generation

---

## Summary Installation (WinUI 3)

### Required for Development
```
- Windows 10 Build 22621+ or Windows 11
- .NET 8.0 SDK or later
- Visual Studio 2022 (Community/Professional/Enterprise)
  - Workload: Windows Desktop Development with C++
  - Extension: Windows App SDK templates
  - Extension: XAML tooling for WinUI
- Git
- Administrator access (for MSIX installation/testing)
```

### Optional
```
- Docker Desktop (for build environment consistency)
- GitHub CLI (for repository management)
- Azure CLI (for cloud integrations, if needed)
- Windows 11 SDK (latest, for advanced features)
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│         User Interface (WinUI 3)                │
│    - Prompt Editor                              │
│    - Live Preview                               │
│    - Project Manager                            │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│      Backend (.NET 8 / C# Console)              │
│    - Project Manager                            │
│    - AI Integration (Claude API)                │
│    - Code Generator (Roslyn)                    │
└──────────────────┬──────────────────────────────┘
                   │
    ┌──────────────┴──────────────┐
    │                             │
┌───▼─────────────┐      ┌────────▼────────┐
│  Build System   │      │ Template Engine │
│  (MSBuild)      │      │  (Code Gen)     │
│  (.NET CLI)     │      │                 │
└─────────────────┘      └─────────────────┘
```
