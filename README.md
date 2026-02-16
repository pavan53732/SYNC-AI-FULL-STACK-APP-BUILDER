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

### Core Architecture
- [**Architecture**](docs/ARCHITECTURE.md) - Complete system architecture with 7-layer multi-agent design
- [**Execution Architecture**](docs/EXECUTION_ARCHITECTURE.md) - 6 embedded subsystems & local deployment
- [**Orchestrator Specification**](docs/ORCHESTRATOR_SPECIFICATION.md) - Deterministic state machine (critical foundation)

### Design & Workflow
- [**Design Philosophy**](docs/DESIGN_PHILOSOPHY.md) - UX principles: hide complexity, show results
- [**User Workflow**](docs/USER_WORKFLOW.md) - Observable behavior & behind-the-scenes operations

### Technical Specifications
- [**API Contracts**](docs/API_CONTRACTS.md) - Internal service APIs & AI Engine output schemas
- [**Technology Stack**](docs/TECHNOLOGY_STACK.md) - Complete tech stack breakdown
- [**Project Structure**](docs/PROJECT_STRUCTURE.md) - Codebase organization
- [**Features**](docs/FEATURES.md) - Feature roadmap & capabilities

### Implementation
- [**Development Guide**](docs/DEVELOPMENT_GUIDE.md) - Implementation guide for developers
- [**Deployment**](docs/DEPLOYMENT.md) - Deployment strategies & configurations