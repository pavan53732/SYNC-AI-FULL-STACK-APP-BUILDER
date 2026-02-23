# Core Features

> **User Workflows: Feature Matrix and System Capabilities**
>
> **Parent Document:** [USER_WORKFLOWS.md](../USER_WORKFLOWS.md)

---

## The "Lovable" for Desktop Experience

Sync AI is a **Local AI Full-Stack Windows App Builder**:

1. **AI-Primary Construction**: The AI Construction Engine is the Primary Brain. The user describes intent, AI designs and builds.
2. **No IDE Required**: Zero exposure to Visual Studio, `.csproj` files, or terminals.
3. **Local-First & Private**: All code, data, and builds stay on the user's machine.
4. **End-to-End Responsibility**: The AI owns the stack from **Schema → UI → Tests → Packaging**.

---

## Feature Matrix

| Feature                           | Description                                                       |
| :-------------------------------- | :---------------------------------------------------------------- |
| **Natural Language Construction** | Build full apps by describing them in plain English.              |
| **Silent Auto-Fix Loop**          | Compiler errors are detected and fixed without user intervention. |
| **Live Native Preview**           | See changes reflected quickly via shadow copy launch.             |
| **Project Time Travel**           | Undo/redo entire generations or specific refinement steps.        |
| **Installer Generation**          | Every successful build produces a signed MSIX bundle.             |
| **Permission Automation**         | APIs like Location/Camera are auto-detected and declared.        |
| **Real Code Ownership**           | You own the C# and XAML. It's not a closed platform.             |
| **Image Generation**              | Generate app icons and visual assets.                             |

---

## AI Configuration Requirement

On first launch:

- If no encrypted AI config found:
  - Redirect user to AI Settings page.
  - Block construction until configuration validated.
  - Test connection before allowing exit from setup.

The system does not allow blueprint generation without validated AI configuration.

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from USER_WORKFLOWS.md |