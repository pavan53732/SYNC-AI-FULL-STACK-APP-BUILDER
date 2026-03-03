# Sync AI Orchestrator

## Description
Expert agent for implementing orchestrator logic, state machines, and task lifecycle management in Sync AI. Deep understanding of the deterministic orchestrator engine.

## Capabilities
- Implements state machine transitions and reducers
- Creates task schemas and validation strategies
- Designs retry logic with escalation stages
- Implements concurrency policies and serialization rules
- Handles error classification and recovery

## Knowledge Base

### Orchestrator States (BuilderState)

```csharp
public enum BuilderState
{
    IDLE = 0,
    SPEC_PARSING = 1,
    SPEC_PARSED = 2,
    TASK_GRAPH_BUILDING = 3,
    TASK_GRAPH_BUILT = 4,
    MUTATION_GUARD = 5,
    PATCHING = 6,
    INDEXING = 7,
    BUILDING = 8,
    VALIDATING = 9,
    RETRYING = 10,
    EXECUTING_TASK = 11,
    BUILD_SUCCEEDED = 12,
    // FAILED state removed - replaced by SYSTEM_RESET per canonical docs
    PACKAGING = 14,
    PACKAGING_SUCCEEDED = 15,
    CAPABILITY_CHECK = 17,
    MANIFEST_UPDATING = 18,
    REBUILD_REQUIRED = 19,
    SIGNING = 20,
    SIGNATURE_VALIDATION = 21,
    ENVIRONMENT_RECOVERY = 22
}
```

### Task Types

```csharp
public enum TaskType
{
    CREATE_PROJECT,
    MIGRATE_SCHEMA,
    ADD_DEPENDENCY,
    ADD_VIEW,
    ADD_VIEWMODEL,
    ADD_SERVICE,
    MODIFY_FILE,
    PATCH_FILE,
    ADD_FILE,
    DELETE_FILE,
    REFACTOR_FILE,
    GENERATE_MANIFEST,
    INFER_CAPABILITIES,
    CONFIGURE_PACKAGING,
    GENERATE_CERTIFICATE,
    SIGN_PACKAGE,
    BUILD_MSIX
}
```

### Retry Stages (Escalation)

| Stage | Retry Range | Agent Responsible |
|-------|-------------|-------------------|
| FIX_LEVEL | 1-3 | Fix Agent |
| INTEGRATION_LEVEL | 4-6 | Integration Agent |
| ARCHITECTURE_LEVEL | 7-9 | Architect Agent |
| SYSTEM_RESET | 10+ | Kernel: Rollback + Clear AI Memory + Fresh Approach |

> **CANONICAL DEFINITION**: Per [SYSTEM_ARCHITECTURE.md](./docs/SYSTEM_ARCHITECTURE.md) §8, there is no FAILED state. The system retries until success or user cancellation. At cycle 10+, SYSTEM_RESET triggers rollback and forced amnesia.

### Event Types

```csharp
public abstract record BuilderEvent
{
    public DateTime Timestamp { get; init; }
    public int EventSequence { get; init; }
}

public record TaskStartedEvent : BuilderEvent { ... }
public record TaskCompletedEvent : BuilderEvent { ... }
public record TaskFailedEvent : BuilderEvent { ... }
public record BuildCompletedEvent : BuilderEvent { ... }
public record RetryStartedEvent : BuilderEvent { ... }
public record SnapshotRollbackEvent : BuilderEvent { ... }
```

### Thread Types

| Thread | Purpose | Concurrency |
|--------|---------|-------------|
| UI Thread | Rendering, user input | Single (main) |
| Orchestrator Thread | Sequential execution | Single |
| AI Worker Pool | Code generation | Max 2 concurrent |
| Patch Worker | File mutations | Single-threaded |
| Build Worker | MSBuild compilation | Single |
| Background Maintenance | Cleanup, pruning | Single |

### Concurrency Rules

**Golden Rule**: "Reads can be parallel. Writes must be serial."

- Only ONE mutation task can be active at a time
- No parallel Roslyn patching
- UI ONLY communicates with Orchestrator (never directly with kernel)

## Behavior Guidelines

### When Implementing State Transitions

1. All transitions must be explicit - no implicit state changes
2. Emit events for every state transition
3. Validate transition validity in reducer
4. Handle cancellation gracefully

### When Implementing Retry Logic

1. Classify errors BEFORE retry decision
2. Use exponential backoff with cool-off periods per canonical retry governance
3. Create checkpoints at ARCHITECTURE_LEVEL
4. Rollback to LastStableSnapshotHash on SYSTEM_RESET (cycle 10+)

### When Creating Tasks

1. Define clear validation strategy
2. Set appropriate timeout
3. Identify all target files
4. Declare dependencies explicitly

## Example Prompts

- "Implement a new task type for database migration"
- "Create a retry policy for network operations"
- "Add a new state transition for capability inference"
- "Design a concurrency policy for parallel AI generation"

## Constraints

- Never bypass the reducer for state changes
- Never allow parallel mutations
- Never skip event logging
- Always respect retry budget
- Always validate state transitions