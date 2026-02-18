# PROJECT HANDBOOK

> **The Developer's Guide to Structure, Contribution, and Deployment**
>
> _Merged from: PROJECT_STRUCTURE.md, DEVELOPMENT_GUIDE.md, DEPLOYMENT.md_

---

## Preface: Constructing the Constructor

Sync AI is **not** an AI coding assistant. It is an **Autonomous Software Construction System**.

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

---

## 1. Project Directory Structure

### Top-Level Layout

The solution uses a clean separation between the **Builder** (the tool itself) and **User Workspaces** (where apps are generated).

```text
SYNC-AI-FULL-STACK-APP-BUILDER/
├── .github/                 # CI/CD Workflows
├── docs/                    # Documentation (Master Files)
├── src/                     # Source Code
│   ├── SyncAI.Core/         # Shared logic, Agents, Roslyn Services
│   ├── SyncAI.UI/           # WinUI 3 Frontend / Shell
│   ├── SyncAI.Orchestrator/ # State Machine & Build Engine
│   └── SyncAI.Tests/        # NUnit Test Projects
├── templates/               # Project Templates (Base scaffolding)
├── tools/                   # Helper scripts
└── SyncAI.sln               # Main Solution File
```

### User Workspace Layout (Generated Apps)

When a user creates an app, it lives here:

```text
C:\Users\%USER%\.syncai\workspaces\
└── [ProjectName]/
    ├── .syncai/             # Project Memory (SQLite, Logs, Snapshots)
    ├── src/
    │   ├── App.xaml         # Entry Point
    │   ├── MainWindow.xaml  # Main Shell
    │   ├── ViewModels/      # MVVM Logic
    │   ├── Views/           # UI Pages
    │   ├── Models/          # Data Entities
    │   └── Services/        # Data Access & Logic
    ├── assets/              # Images, Icons
    └── [ProjectName].csproj # Project Definition
```

### Key File Descriptions

- **`ActionPlan.md`**: (Internal) The current plan the agent is executing for a user request.
- **`implementation_plan.md`**: (Internal) High-level architectural roadmap check-in.
- **`project.db`**: SQLite database storing the app's persistent data.
- **`memory.db`**: SyncAI's memory of the project (history, user preferences, embeddings).

---

## 2. Dependencies & Technology Stack

### Core Frameworks

- **Target Framework**: .NET 8 (`net8.0-windows10.0.19041.0`)
- **UI Framework**: WinUI 3 (Windows App SDK 1.5+)
- **Language**: C# 12

### Key NuGet Packages

- **`Microsoft.WindowsAppSDK`**: Core WinUI support.
- **`CommunityToolkit.Mvvm`**: Source generators for `[ObservableProperty]` and `[RelayCommand]`.
- **`Microsoft.CodeAnalysis.CSharp`**: Roslyn compiler for AST manipulation and parsing.
- **`Dapper`**: Micro-ORM for SQLite interactions.
- **`Microsoft.Data.Sqlite`**: Database engine.
- **`Microsoft.Extensions.DependencyInjection`**: IoC Container.
- **`Serilog`**: Logging infrastructure.

---

## 3. Development Setup

### Prerequisites

1.  **Windows 10 (1809+) or Windows 11**.
2.  **Visual Studio 2022** (Community or higher).
    - Workload: _.NET Desktop Development_.
    - Optional: _Windows App SDK C# Templates_.
3.  **.NET 8 SDK**.

### First Run

1.  Clone the repository.
2.  Open `SyncAI.sln` in Visual Studio.
3.  Right-click `SyncAI.UI` -> **Set as Startup Project**.
4.  Press **F5** to build and debug.

### Local Configuration

- **`appsettings.local.json`**: Store your local LLM API keys here (e.g., OpenAI, Anthropic, or Local LLM endpoint). _This file is git-ignored._

```json
{
  "AI": {
    "Provider": "OpenAI",
    "ApiKey": "sk-..."
  },
  "Sandbox": {
    "Enabled": false,
    "Path": "C:\\Temp\\SyncAI_Sandbox"
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

### Creating an MSIX Installer

To distribute the _Builder_ itself or for a user to distribute their _Generated App_:

1.  **Manifest**: Ensure `Package.appxmanifest` has unique Identity and Publisher.
2.  **Packaging Project**: Use the `wapproj` (Windows Application Packaging Project) if available, or single-project MSIX in .NET 6+.
3.  **Command**:
    ```powershell
    dotnet publish -f net8.0-windows10.0.19041.0 -c Release /p:GenerateAppxPackageOnBuild=true
    ```

### Code Signing

- **Development**: Visual Studio creates a temporary certificate (`SyncAI_TemporaryKey.pfx`).
- **Production**: You must sign the MSIX with a trusted certificate (from Sectigo, DigiCert, etc.) or the Microsoft Store processing will sign it for you.
- **Local Trust**: If using a self-signed cert, the certificate must be installed to the "Trusted People" store on the target machine.

### Distribution Channels

1.  **Microsoft Store**: The primary recommended channel (handles updates automatically).
2.  **Sideloading**: Distribute the `.msixbundle` directly. Requires enabling "Developer Mode" or installing the cert.
3.  **Winget**: Submit manifest to Winget repository for CLI installation.

---
