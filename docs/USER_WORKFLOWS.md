# USER WORKFLOWS & FEATURES

> **The User Experience: From Prompt to Production**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> _Users interact with the AI Construction Engine. The Runtime Safety Kernel handles all enforcement silently.

---

## Table of Contents

1. [Core Features Overview](#1-core-features-overview)
2. [Primary User Cycle](#2-primary-user-cycle)
3. [Iterative Refinement System](#3-iterative-refinement-system)
4. [Project History & Time Travel](#4-project-history--time-travel)
5. [Advanced Mode & Power Features](#5-advanced-mode--power-features)
6. [Export & Distribution](#6-export--distribution)
7. [Design Philosophy & UX Principles](#7-design-philosophy--ux-principles)
8. [Error Handling Strategy](#8-error-handling-strategy)

---

## 1. Core Features Overview

### The "Lovable" for Desktop Experience

Sync AI is a **Local AI Full-Stack Windows App Builder**:

1.  **AI-Primary Construction**: The AI Construction Engine is the Primary Brain. The user describes intent, AI designs and builds.
2.  **No IDE Required**: Zero exposure to Visual Studio, `.csproj` files, or terminals.
3.  **Local-First & Private**: All code, data, and builds stay on the user's machine.
4.  **End-to-End Responsibility**: The AI owns the stack from **Schema → UI → Tests → Packaging**.

The **AI Construction Engine** creates adaptive blueprints and generates complete applications. The **Runtime Safety Kernel** enforces hard boundaries silently.

This system does not generate fragments or starter templates.
It constructs **complete, runnable, production-ready Windows-native applications**.

From database schema to MSIX installer, the entire lifecycle is owned by the system.

- **Full Stack**: Generates database schemas (SQLite), backend logic (C#), and native UI (WinUI 3/XAML).
- **End-to-End Lifecycle**: Handles everything from initial scaffolding to final `.msix` packaging.
- **Live Iteration**: Real-time preview via shadow copy launch (app restarts in <2s for changes).
- **Data Persistence**: Built-in specialized repositories and reliable database management.

It is not just a UI prototyping tool; it is a full-cycle software construction environment.

### Feature Matrix

| Feature                           | Description                                                       | Technical Implementation                            |
| :-------------------------------- | :---------------------------------------------------------------- | :-------------------------------------------------- |
| **Natural Language Construction** | Build full apps by describing them in plain English.              | Semantic Intent Parsing → Multi-Agent Orchestration |
| **Silent Auto-Fix Loop**          | Compiler errors are detected and fixed without user intervention. | MSBuild Log Parsing + Roslyn Code Fix Providers     |
| **Live Native Preview**           | See changes reflected quickly via shadow copy launch.             | Shadow Copy Launch / Window Hosting                 |
| **Project Time Travel**           | Undo/redo entire generations or specific refinement steps.        | Snapshot System (Git-based under the hood)          |
| **Installer Generation**          | Every successful build produces a signed MSIX bundle.             | Windows App SDK Build Tools + MSIX                  |
| **Permission Automation**         | APIs like Location/Camera are auto-detected and declared.         | Roslyn AST Scanning → Capability Injection          |
| **Real Code Ownership**           | You own the C# and XAML. It's not a closed platform.              | Standard .csproj format, no proprietary lock-in     |
| **Image Generation**              | Generate app icons and visual assets.                             | openai SDK Image Gen - user-configured              |

### The "No-Code" Illusion

- **Constraint**: Users never see a line of code unless they ask to.
- **Reality**: The system is writing high-quality, documented C# code in the background.

### Environment Bootstrapping & Self-Repair

The system automatically manages the development environment:

- **Automatic .NET SDK Detection**: System checks for compatible SDK on launch
- **Guided SDK Installation**: If SDK missing or outdated, guided setup flow initiates
- **NuGet Cache Corruption Detection**: Detects and repairs corrupted NuGet caches
- **Self-Repair Strategy**: Automatic recovery from build environment issues
- **Low-Resource Mitigation**: RAM/Disk constraints detected and handled gracefully
- **AI Service Auto-Start**: AI Mini Service starts automatically with the app (Layer 6.6)
- **User-Configured AI**: Users set up their AI providers in Settings > AI Settings

### AI Configuration Requirement

On first launch:

• If no encrypted AI config found:
  → Redirect user to AI Settings page.
  → Block construction until configuration validated.
  → Test connection before allowing exit from setup.

The system does not allow blueprint generation without validated AI configuration.

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
5.  **Generating Assets**: "Creating app icons and branding..." (Asset generation via AI)
6.  **Verifying**: "Checking for errors..." (Build & Auto-fix)
7.  **Packaging**: "Signing and bundling..." (Manifest generation)
8.  **Ready**: App is live and interactive.

### Asset Generation Phase (NEW)

> **Related**: [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) — Zero-template approach
>
> **Related**: [BRANDING_INFERENCE_HEURISTICS.md](./BRANDING_INFERENCE_HEURISTICS.md) — Intelligent brand derivation

The system automatically generates visual assets without templates:

| Asset Type | Generated From | User Message |
|------------|----------------|--------------|
| **App Icons** | Domain + App Name | "Generating app icons..." |
| **Tile Logos** | Brand inference | "Creating tile logos..." |
| **Splash Screen** | Color psychology | "Preparing splash screen..." |
| **Store Logo** | Style derivation | "Creating store assets..." |

**User sees**: Simple progress indicator with current asset being generated.
**User NEVER sees**: Image generation prompts, AI model details, fallback retries.

### Observable System Behaviors

Based on evidence-driven analysis:

1. **Complex Apps Generate in 30-60 Seconds**: Initial generation takes 30-60s; refinements take 5-15s. Multi-stage pipeline (parsing → architecture → generation → validation).

2. **Intelligent Incremental Updates**: User says "Change button colors" → Only CSS/styles regenerate. Impact analysis prevents unnecessary regeneration.

3. **Dependency Management Is Automatic**: Generated code includes `.csproj` with all dependencies. No manual NuGet package addition required.

4. **Code Quality Is Consistent**: Generated apps deploy and run successfully. Every output goes through build validation before showing to user.

5. **Real Code Ownership**: Users can download and run code locally. Code works in IDE (Visual Studio, VS Code). Output is actual C# + XAML, not proprietary format.

6. **Error-Free User Experience**: Users never see compilation errors. Errors are fixed silently before preview shown.

### Architecture Implied By Behavior

**Input Processing Pipeline**:

```
Natural Language Prompt
    ↓
[Semantic Parser]
    ↓
Structured Intent Objects
{
  "features": ["auth", "crud", "api"],
  "entities": ["User", "Product"],
  "screens": ["Dashboard", "List", "Detail"]
}
```

**Generation Pipeline**:

```
Intent Objects
    ↓
[Architect] → Project structure
    ↓
[CodeGen Agents] → Frontend code (parallel)
                → Backend code (parallel)
                → DB schema (parallel)
    ↓
[Integration] → Wire together (.csproj, API routes, DB migrations)
    ↓
Generated Files (Real C# / XAML code)
```

**Validation Pipeline**:

```
Generated Code
    ↓
[Syntax Check] - Parse & compile
    ↓
[Build Check] - dotnet restore check
    ↓
[Dependency Check] - Missing NuGet packages?
    ↓
[Type Check] - Roslyn/C# compiler errors?
    ↓
[Preview Build] - Build for Windows
    ↓
[Success?] → Show preview OR Auto-fix & retry
```

**Update Pipeline (For Refinements)**:

```
User says: "Change to dark mode"
    ↓
[Impact Analysis] - Which files affected?
    ↓
[Scoped Regen] - Regenerate only CSS, theme
                 Leave API/DB/Auth alone
    ↓
[Merge] - Integrate into existing code
    ↓
[Validate] - Build check
    ↓
[Preview] - Updated live
```

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
    - Shadow copy launch (rebuild and relaunch in <2s).

### Smart Context Detection

The AI knows what you are looking at.

- If user says "Change **this** text", and the preview is open, the AI infers "this" means the visible page.
- If user selects a component in **Advanced Mode** (see below), the scope is narrowed to that component.

### Suggestion Engine

When the user pauses, the AI proactively suggests improvements based on best practices:

- "Would you like to add data persistence?"
- "Should we valid input for the email field?"
- "The color contrast looks low, shall I fix it?"

### Refinement Flow State Machine

```
IDLE
  ↓ (user sends message)
USER_MESSAGE
  ↓ (orchestrator processes)
AI_PLANNING (hidden from user)
  ↓ (orchestrator executes)
APPLYING_CHANGES (maps to UI State: BUILDING)
  ↓ (build succeeds)
PREVIEW_UPDATE (maps to UI State: PREVIEW_READY)
```

**User sees**:

- "Updating your app…" (with shimmer)
- Preview updates smoothly
- No task names, no file operations

### Layout Transition for Refinement

When "Improve this app" is clicked:

1. **Preview panel animates**: Height transitions from 100% → 60% (200ms duration)
2. **Conversation panel slides in**: From bottom, 160ms duration
3. **System message appears**: "You can add features, redesign layouts, or modify behavior."

### Refinement Failure UX

**Extended Recovery** (retries ongoing):

- Message: "Working on that change…"
- Silent retry continues automatically
- User can cancel at any time

**User Cancellation**:

- Message: "Change cancelled. Your project is ready for your next prompt."
- No error state entered
- System returns to idle, ready for new input

> **Note**: There is no "Hard Failure" state. The system retries continuously until success or user cancellation.

**Never show**: Compiler output, stack traces, file paths, technical errors

---

## 4. Project History & Time Travel

### The "Safety Net"

Every successful build creates a **Snapshot**. Users can browse history like a time machine.

> **Note**: Snapshots are implemented via a hidden Git repository. See [EXECUTION_ENVIRONMENT.md](./EXECUTION_ENVIRONMENT.md) §2.5 for Git-based snapshot constraints and pruning behavior.

### Timeline UI

- **Visual Timeline**: A vertical list of "Generations" and "Refinements".
- **Preview Snapshots**: Hovering over a history item shows a screenshot of what the app looked like then.
- **Restore**: Clicking "Restore" reverts the file system and database to that exact state.

### Technical Implementation

- **Snapshots**: Lightweight git commits (hidden `.git` folder).
- **State Management**: `ProjectState.db` tracks which commit corresponds to which user prompt.
- **Safety**: Current work is always stashed before restoring an old snapshot.

### Timeline Micro-Animations

**On hover**:

- Scale: 1.02f
- Elevation: `Translation(0, -2, 8)`

**On click**:

- Accent border: 2px
- Details panel slides down: 180ms

**Smooth scroll snap**:

- `VerticalSnapPointsType="Mandatory"`
- `VerticalSnapPointsAlignment="Near"`

### Restore Flow

When user clicks "Restore This Version":

1. **Confirmation dialog**: "Restore app to this version?" with Primary=Restore, Close=Cancel
2. **Execute restore**: `_snapshotService.RestoreAsync(snapshotId)`
3. **Silent rebuild**: `_orchestrator.RebuildCurrentProjectAsync()`
4. **Refresh preview**: `RefreshPreviewAsync()`
5. **Success toast**: "Restored successfully."

**User does NOT see**: File operations, snapshot mechanics, build process

---

## 5. Advanced Mode & Power Features

> **Accessed via `Ctrl+Shift+A` or Settings -> Enable Developer Mode**

For users who want to peek behind the curtain or need granular control.

### Activation Methods

- **Keyboard Shortcut**: `Ctrl + Shift + A` (primary method)
- **Settings Toggle**: Settings → Enable Developer Mode toggle
- **Easter Egg**: Click status dot 5 times (optional)

### The Advanced Panel

**Layout Specifications**:

- Default height: 320px
- Resizable: Up to 50% screen height
- Background: Neutral subtle dark acrylic
- Collapse/Expand animation: 200ms

**Design Rules** (Advanced Mode must):

- ❌ Never auto-open
- ❌ Never interrupt workflow
- ❌ Never steal focus
- ❌ Never display by default
- ✅ Only appear when explicitly activated
- ✅ Remain collapsed until user expands

When enabled, a collapsible bottom drawer appears with six tabs:

#### Tab 1: Orchestrator

- **Current State**: Displays active orchestrator state
- **Active Task ID**: Shows currently executing task identifier
- **Retry Count**: Number of retry attempts for current operation
- **State Transition History**: Minimal vertical event list
  ```
  IDLE → SPEC_PARSED → EXECUTING → VALIDATING → COMPLETED
  ```

#### Tab 2: Task Queue

- **Pending Tasks**: Queued tasks waiting for execution
- **Executing Tasks**: Currently running tasks with progress
- **Completed Tasks**: Finished tasks with duration
- **Task Dependencies**: Visual indicator of task relationships
- **Status Icons**: Visual status indicators per task

#### Tab 3: Patch Log

- **File Modified**: Path to modified file
- **Operation Type**: Add / Modify / Delete (with color badge)
- **Timestamp**: When the patch was applied
- **Success/Conflict Status**: Green checkmark or warning indicator
- **Expandable Details**: Full path, status message

#### Tab 4: Build Output

- **MSBuild Console Output**: Raw build output (Cascadia Code font)
- **Compiler Warnings**: Warning messages highlighted
- **Errors (if any)**: Error details when build fails
- **Copy Button**: Copy entire output to clipboard

#### Tab 5: Snapshot Manager

- **Snapshot ID**: Unique identifier (monospace font)
- **Timestamp**: When snapshot was created
- **Trigger Reason**: Why snapshot was created (e.g., "Pre-Generation", "Post-Patch")
- **Actions per snapshot**:
  - "Restore" button (accent style)
  - "View Diff" button
  - "Delete" button

#### Tab 6: System Health

Green / Yellow / Red status indicators for:

- **.NET SDK**: Version + health status
- **Disk Space**: Available space + health status
- **Memory Usage**: RAM usage + health status
- **NuGet Status**: Cache health + connectivity
- **Antivirus Interference**: Detection of AV blocking operations

### Manual Code Overrides

Users can manually edit files in the **Code View**.

- **Locking**: Users can "Lock" a file to prevent the AI from overwriting manual changes.
- **Hybrid Workflow**: Write complex logic manually, let AI handle the UI boilerplate.

### Multi-Project Management

- **Dashboard**: Grid view of all local projects.
- **Quick Switch**: Switch between projects without restarting the builder.
- **Archiving**: Move old projects to cold storage to keep the workspace clean.

#### Switching Projects Flow

1. **Fade out current**: 120ms transition
2. **Load new project**: `_orchestrator.LoadProjectAsync(projectId)`
3. **Restore last tab state**: Remember which tab was open
4. **Fade in new**: 160ms transition

**No reload flicker** — seamless transition.

#### Project Filters

- **Search**: AutoSuggestBox, 300px width, placeholder "Search projects…"
- **Sort flyout options**: Last Modified, Name, Health, Size
- **View flyout options**: Grid View, List View

#### Archive System

**Archive workflow**:

1. Move project to `WorkspacesPath/Archive/{projectName}`
2. Update metadata: `IsArchived = true`
3. Remove from main view
4. Show toast: "{projectName} archived"

**Archived projects**: Hidden from main view, accessible via "Show Archived" toggle

#### Safe Delete UX

**Confirmation modal**:

1. Title: "Delete this project permanently?"
2. Message: "This action cannot be undone."
3. Prompt: "Type the project name to confirm:"
4. TextBox: User must type exact project name
5. Delete button only enabled when input matches

**Prevents accidental deletion** — requires typed confirmation.

### Performance Optimization UX

#### Three Performance States

**🟢 Normal Operation**:

- User sees nothing
- System monitors silently in background

**🟡 Soft Performance Warning**:

- **Trigger**: Build takes > 30 seconds
- **UI**: InfoBar with message "Build is taking longer than usual…"
- **Action button**: "Optimize Build" → opens optimization panel

**🔴 Critical Resource Issue**:

- **Trigger**: Disk space < 1GB
- **UI**: Warning InfoBar with message "Low disk space may affect builds."
- **Action button**: "Free Space" → opens disk cleanup

#### Optimize Build Panel

When "Optimize Build" is clicked:

```
□ Clean temporary build files      [checked]
□ Re-index project graph           [checked]
□ Clear NuGet cache                [checked]
□ Compact SQLite database          [checked]
□ Remove old snapshots             [checked]

[Run All Optimizations]  [Cancel]
```

#### Snapshot Size Management

**If snapshots exceed 5GB**:

- Gentle notification: "Old versions will be automatically archived."
- Non-alarmist tone
- Archive runs in background

---

## 6. Export & Distribution

### "You Own The Code"

SyncAI is a **bootstrap engine**, not a walled garden.

### Export Options

1.  **Open in Visual Studio**
    - Generates a `.sln` file if missing.
    - Launches VS 2022 with the project.
    - _Result_: Full decoupling from SyncAI.

2.  **Installer Generation (Mandatory Phase)**
    - **Policy**: Every successful build automatically produces a signed MSIX bundle.
    - **Automated Manifests**: Identity and Publisher fields are auto-filled.
    - **Smart Capabilities**: Permissions (e.g., Internet, Location) are injected based on code usage.
    - **Signing**: Automatically signs with the project-scoped certificate.
    - **Store Ready**: Manifest is always compliant with Microsoft Store schemas.

3.  **Zip Archive**
    - Clean export of source code (excluding `obj` and `bin` folders).

### Packaging State Machine

```
CONFIGURE (user fills form: App Name, Publisher, Version, Icon)
  ↓
PACKAGING (MSBuild packaging profile execution)
  ↓
SIGNING (certificate signing)
  ↓
VERIFYING (validation of package integrity)
  ↓
READY (installer available for download/install)
```

### On Packaging Success

**Success panel displays**:

- Green checkmark FontIcon (`\uE73E`)
- File name of generated MSIX
- Three action buttons:
  - "Open Folder" — Opens containing directory
  - "Install Now" — Launches the installer
  - "Share" — Opens system share sheet

### On Packaging Failure

**Failure panel displays**:

- Friendly translated message (not raw error)
- "Retry" button
- Collapsed Expander with technical details (for debugging)

### Advanced Build Options

Additional packaging formats (for power users):

- **MSIX Packaging**: Default Windows Store format
- **Installer Generation**: Setup.exe, .msi formats
- **Code Signing**: Automatic signing with project certificate
- **Auto-Update Capability**: Generate update manifests
- **Release Notes Generation**: Auto-generate from commit history

### Continuous Integration (Future)

- Plans to support "Push to GitHub" directly from the UI.
- Auto-generation of GitHub Actions workflows for CI/CD.

---

## 7. Design Philosophy & UX Principles

### The Central Principle

> **Hide complexity, show only results.**
>
> Smooth UX does not mean the system is simple.
> It means the system is sophisticated AND the UI abstracts away the details.

### The 5 Design Principles

#### Principle 1: Fail Silently, Succeed Loudly

- **Internal errors?** Classify and auto-fix.
- **Still broken after 5 retries?** Fallback to simpler generation.
- **Missing SDK/Tooling?** Auto-bootstrap or guide silently.
- **Only show success states** to the user.
- **Never show compile logs** or raw MSBuild output.

#### Principle 2: One UI, Multiple Stages

- Show single spinner for entire pipeline
- Multiple stages happen invisibly
- Users don't know about parsing, generation, validation
- Single preview result shown

#### Principle 3: Intelligent Scoping

- Impact analysis before regeneration
- Only touch affected modules
- Preserve untouched code
- Merge generated with existing

#### Principle 4: Opinionated Defaults

- Constrain stack choices (WinUI3 + .NET 8 + SQLite)
- Use opinionated templates
- Enforce naming conventions
- Pre-configure best practices

#### Principle 5: Real Code Ownership

- Generate actual C#, XAML, SQL (not proprietary format)
- Export to GitHub
- Download as ZIP
- Continue in IDE
- Deploy independently

### Psychology of Hidden Complexity

Why this design works:

1. **Reduced Cognitive Load**: Users don't see 50 pieces of information. One clear result (working app). Feels magical and effortless.

2. **Increased Confidence**: No errors = system works. No "failed" attempts visible. Always shows success.

3. **Speed Perception**: Spinner is brief. No intermediate steps. Feels instant.

4. **Trust Building**: Consistently works. No surprises. Professional experience.

### Comparison: Hidden vs Exposed Complexity

| Aspect                    | Hidden Complexity   | Exposed Complexity      |
| ------------------------- | ------------------- | ----------------------- |
| **User Experience**       | Smooth, magical     | Confusing, overwhelming |
| **Error Visibility**      | 0%                  | 100% (frustrating)      |
| **Time to Working App**   | Fast (steps hidden) | Slow (debugging)        |
| **Perceived Reliability** | High (always works) | Low (errors visible)    |
| **System Underneath**     | Same                | Same                    |
| **User Satisfaction**     | High                | Low                     |

---

## 8. Error Handling Strategy

### User-Facing: Never Show Errors

```
User never sees:
- Compilation errors
- Build failures
- Missing dependencies
- Type mismatches
- Syntax errors
```

### System-Level: Extensive Error Handling

The system handles 5 categories of errors internally:

#### 1. Parse Errors

- **Response**: Retry with NLP fallback
- **Fallback**: Use simpler interpretation
- **Last resort**: Default features if parsing fails

#### 2. Generation Errors

- **Response**: Log error + context
- **Action**: Classify error type
- **Recovery**: Apply auto-fix, regenerate affected section
- **Validation**: Revalidate after fix

#### 3. Validation Errors

- **Classification**: syntax, type, config, etc.
- **Action**: Identify root cause
- **Fix**: Apply targeted fix
- **Loop**: Recompile, apply staged retry (1-9 AI loops, 10+ System Reset)

#### 4. Deployment Errors

- **Response**: Fallback to local preview
- **Assistance**: Suggest manual fixes if necessary
- **Support**: Offer help options

#### 5. Extended Recovery (User Informed)

- **User message**: "This is taking longer than expected. Optimizing…"
- **Action**: User can cancel and modify prompt
- **Safety**: Preserve work (auto-save)
- **Continuous retry**: System keeps trying until success or cancellation

> **Note**: There are no "Unrecoverable Errors" from the system's perspective. All errors trigger continuous retry. Only user cancellation stops the process.

### Automatic Error Detection & Fixing

**Error Classification**:

- Syntax errors (CS1002, CS1003)
- Type mismatches (CS1503)
- Missing references (CS0106)
- Undefined variables (CS0103)
- Build failures
- Configuration errors

**Auto-Fix Strategies**:

- Insert missing using statements
- Add type conversions (`int.Parse`, `Convert.ToInt32`)
- Add missing attributes (`[Required]`, `[StringLength]`)
- Fix method signatures
- Add missing properties

**Retry Logic**: Continuous retry with exponential backoff until success or user cancellation

**Fix Success Tracking**: Remember solutions for future errors

> **Note**: The system never stops retrying on its own. The only terminal states are success or user-initiated cancellation.

---

### Comparison: Standard vs. Advanced Mode

| Feature            | Standard Mode              | Advanced Mode               |
| :----------------- | :------------------------- | :-------------------------- |
| **UI Focus**       | Preview Window             | Split View (Preview + Code) |
| **Logs**           | "Building..." Spinner      | Full Verbose Logs           |
| **Error Handling** | Auto-Fix / Generic Message | Stack Traces + Fix Attempts |
| **Database**       | Invisible                  | Table Viewer                |
| **File System**    | Hidden                     | File Tree Visible           |

### 8.1 Environment Failure States

The system monitors for environment conditions that require user intervention. All states trigger continuous retry with user notification.

| State                   | Detection                        | Recovery Strategy                              | User Message                                                        |
| :---------------------- | :------------------------------- | :--------------------------------------------- | :------------------------------------------------------------------ |
| **LOW_DISK_SPACE**      | Free space < 500MB               | Prompt user to free space, wait, retry         | "Disk space critical. Please free up space to continue."            |
| **NO_ADMIN_PRIVILEGE**  | Admin required but denied        | Request UAC elevation, wait for retry          | "Admin checks failed. Please restart as Administrator."             |
| **SDK_MISSING**         | `dotnet --version` fails         | Trigger SDK download flow, wait, retry         | ".NET SDK not found. Downloading installer..."                      |
| **SDK_CORRUPTED**       | Build fails with known SDK error | Repair/Reinstall SDK, retry                    | "SDK appears corrupted. Attempting repair..."                       |
| **CERTIFICATE_EXPIRED** | Date > Expiry                    | Regenerate & Re-sign, retry                    | "Certificate expired. Renewing security credentials..."             |
| **NUGET_CACHE_CORRUPT** | Restore fails repeatedly         | `dotnet nuget locals all --clear`, retry       | "Clearing corrupted package cache..."                               |

> **Key Principle**: The system NEVER gives up on its own. All environment states trigger retry loops that continue until success or explicit user cancellation. The system prompts for user intervention when needed, then continues retrying automatically.
>
> **Retry Distinction**:
> - **Mutation Retry Ceiling**: Code mutation cycles are bounded (max 10 retries per task) with staged escalation through Fix → Integration → Architecture levels before abort.
> - **Environment Recovery Loops**: Unbounded — disk space recovery, SDK installation, NuGet cache repair continue until resolved or user cancels.
> - This distinction ensures deterministic code safety while maintaining resilience for environmental issues.

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Added "Generating Assets" workflow state (step 5) |
| 2026-02-23 | Added Asset Generation Phase section with PLATFORM_REQUIREMENTS_ENGINE.md and BRANDING_INFERENCE_HEURISTICS.md references |
| 2026-02-23 | Added asset generation user messaging table |
