# USER WORKFLOWS & FEATURES

> **The User Experience: From Prompt to Production**
>
> _Merged from: FEATURES_AND_WORKFLOWS.md, ITERATIVE_REFINEMENT_UX.md, ADVANCED_MODE_SPECIFICATION.md_

---

## Table of Contents

1. [Core Features Overview](#1-core-features-overview)
2. [Primary User Cycle](#2-primary-user-cycle)
3. [Iterative Refinement System](#3-iterative-refinement-system)
4. [Project History & Time Travel](#4-project-history--time-travel)
5. [Advanced Mode & Power Features](#5-advanced-mode--power-features)
6. [Export & Distribution](#6-export--distribution)

---

## 1. Core Features Overview

### The "Lovable" for Desktop Experience

Sync AI brings the "Lovable" experience to Windows Desktop:

1.  **Autonomous Construction**: The user is not a developer; the user is the **architect**. The system is the builder.
2.  **No IDE Required**: Zero exposure to Visual Studio, `.csproj` files, or terminals.
3.  **Local-First & Private**: All code, data, and builds stay on the user's machine.
4.  **End-to-End Responsibility**: The system owns the stack from **Schema → UI → Tests → Packaging**.

It is a **fully autonomous Windows-native software construction system**.

This system does not generate fragments or starter templates.
It constructs **complete, runnable, production-ready Windows-native applications**.

From database schema to MSIX installer, the entire lifecycle is owned by the system.

- **Full Stack**: Generates database schemas (SQLite), backend logic (C#), and native UI (WinUI 3/XAML).
- **End-to-End Lifecycle**: Handles everything from initial scaffolding to final `.msix` packaging.
- **Live Iteration**: Real-time preview with hot-reload capabilities for instant feedback.
- **Data Persistence**: Built-in specialized repositories and reliable database management.

It is not just a UI prototyping tool; it is a full-cycle software construction environment.

### Feature Matrix

| Feature                           | Description                                                       | Technical Implementation                            |
| :-------------------------------- | :---------------------------------------------------------------- | :-------------------------------------------------- |
| **Natural Language Construction** | Build full apps by describing them in plain English.              | Semantic Intent Parsing → Multi-Agent Orchestration |
| **Silent Auto-Fix Loop**          | Compiler errors are detected and fixed without user intervention. | MSBuild Log Parsing + Roslyn Code Fix Providers     |
| **Live Native Preview**           | See changes instantly without manual restarts.                    | Hot Reload / Window Hosting / Shadow Copy           |
| **Project Time Travel**           | Undo/redo entire generations or specific refinement steps.        | Snapshot System (Git-based under the hood)          |
| **One-Click Installer**           | Generate `.msix` installers ready for the Microsoft Store.        | Windows App SDK Build Tools                         |
| **Real Code Ownership**           | You own the C# and XAML. It's not a closed platform.              | Standard .csproj format, no proprietary lock-in     |

### The "No-Code" Illusion

- **Constraint**: Users never see a line of code unless they ask to.
- **Reality**: The system is writing high-quality, documented C# code in the background.

---

## 2. Primary User Cycle

### The Creation Loop

1.  **Intent**
    - User: "Create a task manager with a dark theme."
    - System: Parses intent -> Scaffolds MVVM project -> Generates Database -> Generates UI.
2.  **Visualization**
    - System: Silently compiles -> Launches Preview Window.
    - User: Sees working app (approx. 30-60s for initial generation).
3.  **Refinement**
    - User: "Make the tasks red when overdue."
    - System: Patches specifically the `TaskTemplateSelector` and `TaskViewModel`.
    - User: Sees update (approx. 5-10s).

### Workflow States

1.  **Empty State**: "What would you like to build today?"
2.  **Scaffolding**: "Setting up your workspace..." (File creation)
3.  **Architecting**: "Designing database and UI..." (Agent planning)
4.  **Coding**: "Writing C# and XAML..." (Code generation)
5.  **Verifying**: "Checking for errors..." (Build & Auto-fix)
6.  **Ready**: App is live and interactive.

---

## 3. Iterative Refinement System

### The "Conversation"

Refinement is not just "regenerate". It is a **context-aware patch system**.

#### Refinement Flow

1.  **User Input**: "Add a delete button to the list."
2.  **Context Analysis**:
    - Active File: `TaskList.xaml`
    - Active ViewModel: `TasksViewModel.cs`
3.  **Mutation Strategy**:
    - _Add_ Button to XAML DataTemplate.
    - _Add_ `DeleteCommand` to ViewModel.
    - _Add_ `DeleteTask` method to Repository.
4.  **Execution**:
    - Apply AST patches.
    - Hot Reload if possible, else Recompile.

### Smart Context Detection

The AI knows what you are looking at.

- If user says "Change **this** text", and the preview is open, the AI infers "this" means the visible page.
- If user selects a component in **Advanced Mode** (see below), the scope is narrowed to that component.

### Suggestion Engine

When the user pauses, the AI proactively suggests improvements based on best practices:

- "Would you like to add data persistence?"
- "Should we valid input for the email field?"
- "The color contrast looks low, shall I fix it?"

---

## 4. Project History & Time Travel

### The "Safety Net"

Every successful build creates a **Snapshot**. Users can browse history like a time machine.

### Timeline UI

- **Visual Timeline**: A vertical list of "Generations" and "Refinements".
- **Preview Snapshots**: Hovering over a history item shows a screenshot of what the app looked like then.
- **Restore**: Clicking "Restore" reverts the file system and database to that exact state.

### Technical Implementation

- **Snapshots**: Lightweight git commits (hidden `.git` folder).
- **State Management**: `ProjectState.db` tracks which commit corresponds to which user prompt.
- **Safety**: Current work is always stashed before restoring an old snapshot.

---

## 5. Advanced Mode & Power Features

> **Accessed via `Ctrl+Shift+A` or Settings -> Enable Developer Mode**

For users who want to peek behind the curtain or need granular control.

### The Advanced Panel

When enabled, an overlay panel appears, providing deep insights:

1.  **Orchestrator Logs**
    - Real-time view of what the agents are thinking.
    - "Planning navigation...", "Fixing null reference in MainWindow.xaml.cs..."

2.  **Build Monitor**
    - Raw MSBuild output (usually hidden on success).
    - Performance metrics (Build time, RAM usage).

3.  **Database Explorer**
    - View and query the local SQLite database created for the app.
    - Manually modify data for testing.

4.  **Code View**
    - Read-only (or editable) view of the generated C# and XAML.
    - Syntax highlighting and simple navigation.

### Manual Code Overrides

Users can manually edit files in the **Code View**.

- **Locking**: Users can "Lock" a file to prevent the AI from overwriting manual changes.
- **Hybrid Workflow**: Write complex logic manually, let AI handle the UI boilerplate.

### Multi-Project Management

- **Dashboard**: Grid view of all local projects.
- **Quick Switch**: Switch between projects without restarting the builder.
- **Archiving**: Move old projects to cold storage to keep the workspace clean.

---

## 6. Export & Distribution

### "You Own The Code"

SyncAI is a **bootstrap engine**, not a walled garden.

### Export Options

1.  **Open in Visual Studio**
    - Generates a `.sln` file if missing.
    - Launches VS 2022 with the project.
    - _Result_: Full decoupling from SyncAI.

2.  **Create Installer (.msix)**
    - **One-Click Build**: Uses Windows App SDK build tools to package the app.
    - **Self-Signing**: Automatically generates and trusts a self-signed certificate for local testing.
    - **Store Ready**: Option to prepare manifest for Microsoft Store submission.

3.  **Zip Archive**
    - Clean export of source code (excluding `obj` and `bin` folders).

### Continuous Integration (Future)

- Plans to support "Push to GitHub" directly from the UI.
- Auto-generation of GitHub Actions workflows for CI/CD.

---

### Comparison: Standard vs. Advanced Mode

| Feature            | Standard Mode              | Advanced Mode               |
| :----------------- | :------------------------- | :-------------------------- |
| **UI Focus**       | Preview Window             | Split View (Preview + Code) |
| **Logs**           | "Building..." Spinner      | Full Verbose Logs           |
| **Error Handling** | Auto-Fix / Generic Message | Stack Traces + Fix Attempts |
| **Database**       | Invisible                  | Table Viewer                |
| **File System**    | Hidden                     | File Tree Visible           |

---
