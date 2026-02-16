# API Contracts & Interface Specifications

This document describes the internal service-to-service interfaces and AI Engine output contracts for the SYNC-AI-FULL-STACK-APP-BUILDER. All services follow the 7-layer architecture and are managed by the Deterministic Orchestrator.

---

## Part 1: Internal Service Interfaces

### Orchestrator Service (`IOrchestrator`)

The Orchestrator is the central control point for all mutations.

#### Methods
- `Task<BuilderState> DispatchAsync(BuilderEvent @event)`: Dispatches an event to the state machine.
- `Task<TaskResult> ExecuteTaskAsync(TaskDefinition task)`: Entry point for agents to request work execution.
- `BuilderContext GetCurrentContext()`: Returns the current immutable state of the builder.

### Code Intelligence Service (`IRoslynService`)

Provides AST-based analysis and indexing.

#### Methods
- `Task<ProjectGraph> IndexProjectAsync(string path)`: Recursively indexes symbols in a .NET project.
- `Task<List<Symbol>> FindUsagesAsync(ISymbol symbol)`: Finds all references to a specific symbol.
- `Task<SemanticModel> GetSemanticModelAsync(string filePath)`: Returns the Roslyn semantic model for a file.

### Patch Engine (`IPatchEngine`)

Surgically modifies source code.

#### Methods
- `Task<string> ApplyPatchAsync(string filePath, PatchDefinition patch)`: Applies an AST-based patch and returns the modified content.
- `Task<bool> ValidatePatchAsync(string filePath, PatchDefinition patch)`: Checks if a patch can be applied without conflicts.

### Execution Kernel (`IExecutionKernel`)

Manages the isolated .NET execution environment.

#### Methods
- `Task<BuildResult> BuildAsync(string projectPath)`: Runs an isolated MSBuild process.
- `Task<TestResult> RunTestsAsync(string projectPath)`: Executes unit tests.
- `Task<ExecutionResult> RunAppAsync(string projectPath)`: Launches the app in a controlled environment.

---

## Part 2: AI Engine Output Contracts

**Status**: Draft - Addressing Architectural Gap (Response 1 Validation)  
**Scope**: Formal JSON Schemas for all AI Engine-generated artifacts.

### Overview
To maintain deterministic control, all AI Engine outputs must adhere to strict JSON schemas. The Orchestrator validates every AI Engine response against these contracts before proceeding to the next stage. Any validation failure triggers a silent retry or a structured error state.

---

### 1️⃣ Project Specification Contract (`ProjectSpec`)
**Source**: Intent Service (Layer 1)  
**Purpose**: High-level structural definition of the application.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "projectId": { "type": "string" },
    "projectName": { "type": "string" },
    "stack": {
      "type": "object",
      "properties": {
        "ui": { "enum": ["WinUI3", "WPF", "Console"] },
        "language": { "const": "C#" },
        "framework": { "const": ".NET 8.0" },
        "database": { "enum": ["SQLite", "None"] }
      },
      "required": ["ui", "language", "framework"]
    },
    "features": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "type": { "type": "string" },
          "description": { "type": "string" },
          "dependencies": { "type": "array", "items": { "type": "string" } }
        },
        "required": ["id", "type", "description"]
      }
    }
  },
  "required": ["projectId", "projectName", "stack", "features"]
}
```

---

### 2️⃣ Task Graph Contract (`TaskGraph`)
**Source**: Planning Service (Layer 2)  
**Purpose**: Ordered sequence of construction steps.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "tasks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "type": { "enum": ["INFRASTRUCTURE", "MODEL", "SERVICE", "UI", "INTEGRATION", "FIX"] },
          "description": { "type": "string" },
          "targetFiles": { "type": "array", "items": { "type": "string" } },
          "dependencies": { "type": "array", "items": { "type": "string" } },
          "validationStrategy": { "enum": ["COMPILE", "UNIT_TEST", "XAML_PARSE"] }
        },
        "required": ["id", "type", "description", "targetFiles", "dependencies"]
      }
    }
  },
  "required": ["tasks"]
}
```

---

### 3️⃣ Patch Engine Contract (`CodePatch`)
**Source**: Generation Agents (Layer 4)  
**Purpose**: Targeted modifications for the Patch Engine (Layer 5).

```json
{
  "type": "object",
  "properties": {
    "filePatches": {
      "array": {
        "items": {
          "type": "object",
          "properties": {
            "path": { "type": "string" },
            "changes": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "action": { "enum": ["ADD_CLASS", "ADD_METHOD", "ADD_PROPERTY", "ADD_FIELD", "MODIFY_METHOD_BODY", "MODIFY_PROPERTY", "INSERT_USING", "REMOVE_MEMBER", "UPDATE_XAML_NODE", "ADD_XAML_ELEMENT", "MODIFY_XAML_ATTRIBUTE"] },
                  "targetSymbol": { "type": "string" },
                  "content": { "type": "string" }
                },
                "required": ["action", "content"]
              }
            }
          }
        }
      }
    }
  }
}
```

---

### 4️⃣ Validation Rules
1. **Schema Check**: All AI Engine responses must pass JSON Schema validation.
2. **Path Resolution**: Files referenced in tasks must exist in the workspace or be marked for creation.
3. **Dependency Integrity**: Task graph must be an acyclic (DAG).
4. **Symbol Existence**: Patches targeting existing symbols must verify those symbols via the Code Intelligence Layer.
