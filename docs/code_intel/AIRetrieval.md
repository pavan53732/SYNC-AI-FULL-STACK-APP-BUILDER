# AI Retrieval Pipeline

> **Code Intelligence Layer: Context Assembly for AI Agents**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [IndexingArchitecture.md](./IndexingArchitecture.md) — Symbol graph | [DatabaseSchema.md](./DatabaseSchema.md) — Storage schema

---

## Table of Contents

1. [Purpose](#1-purpose)
2. [Context Assembly — Prioritized Order](#2-context-assembly--prioritized-order)
3. [Retrieval Strategy](#3-retrieval-strategy)
4. [Vector Search Integration](#4-vector-search-integration)

---

## 1. Purpose

The AI Retrieval Pipeline is responsible for assembling the **context window** that is sent to an AI agent for each code-generation or mutation task. Context is assembled based on *relevance*, not arbitrary token limits.

> **PRINCIPLE**: The AI model manages its own context window constraints. All relevant symbols and files are included to ensure complete understanding. Irrelevant files are excluded to reduce noise and cost.

---

## 2. Context Assembly — Prioritized Order

Context is assembled by priority. Higher-priority items are always included; lower-priority items may be truncated if the agent's token budget has been reached.

| Priority | Slot | Content |
|---|---|---|
| 1 | **System Rules** | WinUI 3 constraints, mutation rules, invariants |
| 2 | **Project Summary** | High-level architecture overview |
| 3 | **Target Symbol Definition** | Full source of the symbol being modified |
| 4 | **Direct Dependencies** | Interfaces, services, and base classes referenced by the target |
| 5 | **XAML Bindings** | Corresponding XAML file if the target is a ViewModel |

---

## 3. Retrieval Strategy

```csharp
public class AIContextAssembler
{
    private readonly ICodeIndexer _indexer;

    public async Task<AIContext> AssembleContextAsync(
        string targetSymbol,
        AgentExecutionContext executionContext)
    {
        var context = new AIContext();

        // 1. System rules (always included, static)
        context.SystemRules = await LoadSystemRulesAsync();

        // 2. Project summary
        context.ProjectSummary = await _indexer.GetProjectSummaryAsync(
            executionContext.ProjectPath);

        // 3. Target symbol source
        context.TargetSymbol = await _indexer.GetSymbolSourceAsync(targetSymbol);

        // 4. Direct dependencies (interfaces, base classes, injected services)
        var deps = await _indexer.GetDirectDependenciesAsync(targetSymbol);
        context.Dependencies = deps;

        // 5. XAML bindings (if ViewModel)
        if (context.TargetSymbol.Kind == "ViewModel")
        {
            context.XamlFile = await _indexer.GetBoundXamlFileAsync(targetSymbol);
        }

        return context;
    }
}
```

---

## 4. Vector Search Integration

File embeddings stored in the `file_embeddings` table (see [DatabaseSchema.md](./DatabaseSchema.md)) enable semantic similarity search for large projects where brute-force graph traversal is too slow.

```csharp
public class VectorRetriever
{
    public async Task<List<string>> FindSimilarFilesAsync(
        string targetSymbol,
        int topK = 5)
    {
        var queryEmbedding = await _embeddingService.EmbedAsync(targetSymbol);

        // Cosine similarity search over file_embeddings table
        return await _db.QuerySimilarAsync(queryEmbedding, topK);
    }
}
```

> **NOTE**: Vector search supplements (does not replace) the graph-based retrieval described above. Graph traversal is always used first; vector search is used to surface additional relevant files that are not directly linked in the symbol graph.

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document (section 12)
- [IndexingArchitecture.md](./IndexingArchitecture.md) — Symbol graph and indexing architecture
- [DatabaseSchema.md](./DatabaseSchema.md) — `file_embeddings` table schema
- [AGENT_EXECUTION_CONTRACT.md](../AGENT_EXECUTION_CONTRACT.md) — `AgentExecutionContext` token budget

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md §12 as part of documentation reorganization |
