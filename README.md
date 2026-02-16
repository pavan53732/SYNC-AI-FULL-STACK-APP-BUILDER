# SyncAI Explorer

**The Autonomous Software Construction Environment for Windows**

## Overview
SyncAI Explorer is a comprehensive **Windows-native autonomous software construction environment** that generates complete desktop applications end-to-end using natural language prompts. 

Built on a **deterministic multi-agent orchestration** model, the system abstracts away all developer tooling (.NET SDK, MSBuild, Roslyn) as internal bundled services, delivering a professional-grade development experience with **No IDE Required**.

## Mission: From Prompt to Product
Unlike traditional code generators or IDE plugins, SyncAI Explorer operates as a self-contained constructor. It handles the entire lifecycle—Architecting, Coding, Validating, and Error-Fixing—silently and locally on your machine, surfacing only the final successful application.

## Key Principles
*   **Autonomous Construction**: The environment builds the app, you provide the intent.
*   **No IDE Required**: All tooling is embedded; users never open a compiler or CLI.
*   **Real Code Ownership**: Generates production-grade C# and XAML that you own and can export.
*   **Silent Error Fixing**: Internal validation loops catch and fix build errors before you see them.

## Documentation
- [Architecture](docs/ARCHITECTURE.md)
- [Design Philosophy](docs/DESIGN_PHILOSOPHY.md)
- [User Workflow](docs/USER_WORKFLOW.md)
- [Internal Specs](docs/ORCHESTRATOR_SPECIFICATION.md)