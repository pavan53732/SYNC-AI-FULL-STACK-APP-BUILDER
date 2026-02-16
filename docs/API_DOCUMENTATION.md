# Internal API Documentation

This document describes the internal service-to-service interfaces for the SYNC-AI-FULL-STACK-APP-BUILDER. All services follow the 7-layer architecture and are managed by the Deterministic Orchestrator.

## Orchestrator Service (`IOrchestrator`)

The Orchestrator is the central control point for all mutations.

### Methods
- `Task<BuilderState> DispatchAsync(BuilderEvent @event)`: Dispatches an event to the state machine.
- `Task<TaskResult> ExecuteTaskAsync(TaskDefinition task)`: Entry point for agents to request work execution.
- `BuilderContext GetCurrentContext()`: Returns the current immutable state of the builder.

## Code Intelligence Service (`IRoslynService`)

Provides AST-based analysis and indexing.

### Methods
- `Task<ProjectGraph> IndexProjectAsync(string path)`: Recursively indexes symbols in a .NET project.
- `Task<List<Symbol>> FindUsagesAsync(ISymbol symbol)`: Finds all references to a specific symbol.
- `Task<SemanticModel> GetSemanticModelAsync(string filePath)`: Returns the Roslyn semantic model for a file.

## Patch Engine (`IPatchEngine`)

Surgically modifies source code.

### Methods
- `Task<string> ApplyPatchAsync(string filePath, PatchDefinition patch)`: Applies an AST-based patch and returns the modified content.
- `Task<bool> ValidatePatchAsync(string filePath, PatchDefinition patch)`: Checks if a patch can be applied without conflicts.

## Execution Kernel (`IExecutionKernel`)

Manages the isolated .NET execution environment.

### Methods
- `Task<BuildResult> BuildAsync(string projectPath)`: Runs an isolated MSBuild process.
- `Task<TestResult> RunTestsAsync(string projectPath)`: Executes unit tests.
- `Task<ExecutionResult> RunAppAsync(string projectPath)`: Launches the app in a controlled environment.
