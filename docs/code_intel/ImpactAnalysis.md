# Impact Analysis Engine

> **Code Intelligence Layer: Pre-Patch Symbol Impact Assessment**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [PatchEngine.md](./PatchEngine.md) — Patch application | [GraphIntegrity.md](./GraphIntegrity.md) — Post-patch verification

---

## Table of Contents

1. [Purpose](#1-purpose)
2. [ImpactAnalyzer Implementation](#2-impactanalyzer-implementation)
3. [Threshold Configuration](#3-threshold-configuration)
4. [Integration with Patch Flow](#4-integration-with-patch-flow)

---

## 1. Purpose

The **Impact Analysis Engine** determines which symbols are transitively affected by a proposed code change *before* the patch is committed to disk. This is the last safety gate between intent and mutation.

> **INVARIANT**: No patch is applied without a passing impact analysis. If `IsSafe == false`, the patch is rejected and the agent is returned a structured error indicating the scope of the blast radius.

---

## 2. ImpactAnalyzer Implementation

```csharp
public class ImpactAnalyzer
{
    private readonly ICodeIndexer _indexer;

    public async Task<ImpactAnalysis> AnalyzeChangeAsync(
        string symbolName,
        ChangeType changeType,
        AgentExecutionContext context)
    {
        var analysis = new ImpactAnalysis();
        analysis.AffectedSymbols = await GetAffectedSymbolsAsync(symbolName);

        // Block unsafe mutation
        // NOTE: Threshold is configurable via AgentExecutionContext.MaxAffectedSymbols (default: 50)
        var maxAffectedSymbols = context?.MaxAffectedSymbols ?? 50;
        if (analysis.AffectedSymbols.Count > maxAffectedSymbols)
        {
            analysis.IsSafe = false;
            analysis.Reason =
                $"Change affects {analysis.AffectedSymbols.Count} symbols " +
                $"(max: {maxAffectedSymbols}). Manual review required.";
        }
        else
        {
            analysis.IsSafe = true;
        }

        return analysis;
    }

    private async Task<List<string>> GetAffectedSymbolsAsync(string symbolName)
    {
        // Walk the symbol_edges graph transitively from the target symbol
        return await _indexer.GetTransitiveDependentsAsync(symbolName);
    }
}
```

### ImpactAnalysis Model

```csharp
public class ImpactAnalysis
{
    public bool IsSafe { get; set; } = true;
    public string? Reason { get; set; }
    public List<string> AffectedSymbols { get; set; } = new();
}
```

---

## 3. Threshold Configuration

| Setting | Default | Description |
|---|---|---|
| `MaxAffectedSymbols` | 50 | Maximum symbols transitively impacted before the patch is blocked |
| `MaxNodesModifiedPerTask` | Defined in `AgentExecutionContext` | AST node budget per task |
| `MaxFilesTouchedPerTask` | Defined in `AgentExecutionContext` | File-touch budget per task |

Thresholds are set on `AgentExecutionContext` at task-dispatch time by the Orchestration Engine. Agents cannot override them.

---

## 4. Integration with Patch Flow

Impact analysis runs **before** `PatchEngine.ApplyPatchAsync()`:

```
Agent Patch Request
       ↓
ImpactAnalyzer.AnalyzeChangeAsync()
       ↓ IsSafe == false → Return error to agent (retry or escalate)
       ↓ IsSafe == true
MutationGuard.IsSafePatchAsync()
       ↓
PatchEngine.ApplyPatchAsync()
       ↓
GraphIntegrityVerifier (post-patch)
```

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document (section 11)
- [PatchEngine.md](./PatchEngine.md) — Patch application layer
- [GraphIntegrity.md](./GraphIntegrity.md) — Post-patch verification
- [AGENT_EXECUTION_CONTRACT.md](../AGENT_EXECUTION_CONTRACT.md) — `AgentExecutionContext` definition

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md §11 as part of documentation reorganization |
