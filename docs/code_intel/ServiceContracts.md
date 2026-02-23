# Service Contracts

> **Code Intelligence Layer: Public Interfaces for IRoslynService & IPatchEngine**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [RoslynCompilation.md](./RoslynCompilation.md) | [PatchEngine.md](./PatchEngine.md)

---

## Table of Contents

1. [Code Intelligence Service — IRoslynService](#1-code-intelligence-service--iroslynservice)
2. [Patch Engine — IPatchEngine](#2-patch-engine--ipatchengine)
3. [Stability Guarantee](#3-stability-guarantee)

---

## 1. Code Intelligence Service — `IRoslynService`

Primary interface for all Roslyn-based code analysis operations. Consumed by AI agents via the Retrieval Pipeline.

```csharp
public interface IRoslynService
{
    /// <summary>
    /// Fully index a project directory into the symbol graph.
    /// Creates a new snapshot on completion.
    /// </summary>
    Task<ProjectGraph> IndexProjectAsync(string path);

    /// <summary>
    /// Find all usages of the given symbol across all indexed files.
    /// Used by the Impact Analysis Engine.
    /// </summary>
    Task<List<Symbol>> FindUsagesAsync(ISymbol symbol);

    /// <summary>
    /// Retrieve the semantic model for a specific file.
    /// Used by agents to reason about type information.
    /// </summary>
    Task<SemanticModel> GetSemanticModelAsync(string filePath);
}
```

---

## 2. Patch Engine — `IPatchEngine`

Primary interface for all code mutation operations. Used exclusively by the Orchestration Engine — never called directly by agents.

```csharp
public interface IPatchEngine
{
    /// <summary>
    /// Apply a single structured patch operation.
    /// Runs impact analysis and mutation guard checks before writing to disk.
    /// </summary>
    Task<PatchResult> ApplyPatchAsync(PatchOperation patch);

    /// <summary>
    /// Validate a patch without applying it.
    /// Used by the Orchestrator to pre-screen agent output.
    /// </summary>
    Task<PatchValidationResult> ValidatePatchAsync(PatchOperation patch);

    /// <summary>
    /// Apply a batch of patch operations atomically.
    /// All patches succeed or all are rolled back.
    /// </summary>
    Task<BatchPatchResult> ApplyPatchBatchAsync(PatchOperation[] patches);
}
```

---

## 3. Stability Guarantee

> **These interfaces are STABLE**. Breaking changes require a major version increment and must be approved by the Architect agent before implementation.

Any service registered in the DI container that implements `IRoslynService` or `IPatchEngine` must satisfy the full contract, including preconditions (e.g., full-semantic mode enforcement, snapshot creation before mutation).

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document (section 16)
- [RoslynCompilation.md](./RoslynCompilation.md) — `IRoslynService` implementation details
- [PatchEngine.md](./PatchEngine.md) — `IPatchEngine` implementation details
- [ImpactAnalysis.md](./ImpactAnalysis.md) — Pre-patch safety check called inside `ApplyPatchAsync`

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md §16 as part of documentation reorganization |
