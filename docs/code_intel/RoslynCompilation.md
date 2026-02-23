# Roslyn Compilation

> **Code Intelligence Layer: Full Compilation Model and Code Indexer**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [IndexingArchitecture.md](./IndexingArchitecture.md) — Indexing policy

---

## Table of Contents

1. [Full Compilation Builder](#1-full-compilation-builder)
2. [Code Indexer Interface](#2-code-indexer-interface)
3. [Graph Update Algorithms](#3-graph-update-algorithms)

---

## 1. Full Compilation Builder

```csharp
public class CompilationModelBuilder
{
    public async Task<Compilation> BuildCompilationAsync(string projectPath)
    {
        var syntaxTrees = new List<SyntaxTree>();
        var csFiles = Directory.GetFiles(projectPath, "*.cs", SearchOption.AllDirectories);

        foreach (var file in csFiles)
        {
            var code = await File.ReadAllTextAsync(file);
            var tree = CSharpSyntaxTree.ParseText(code, path: file);
            syntaxTrees.Add(tree);
        }

        var compilation = CSharpCompilation.Create(
            assemblyName: "ProjectCompilation",
            syntaxTrees: syntaxTrees,
            references: GetMetadataReferences(),
            options: new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary)
        );

        return compilation;
    }
}
```

---

## 2. Code Indexer Interface

```csharp
public interface ICodeIndexer
{
    Task IndexFileAsync(string filePath);
    Task IndexProjectAsync(string projectPath);
    Task<List<SymbolReference>> FindReferencesAsync(string symbolName);
    Task<FileDependencyGraph> GetDependencyGraphAsync(string filePath);
}
```

---

## 3. Graph Update Algorithms

Triggered by `FileSystemWatcher` or IDE event:

1. Create new snapshot ID (e.g., `Snapshot_N+1`).
2. Clear old records for this file in current snapshot context.
3. Parse with Roslyn to generate new `SyntaxTree`.
4. Extract & Insert Syntax Nodes (`syntax_nodes`).
5. Insert Symbols (`symbol_nodes`).
6. Resolve & Insert Edges (`symbol_edges`).
7. Commit transaction (Atomic Switch).

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document
- [IndexingArchitecture.md](./IndexingArchitecture.md) — Indexing policy
- [DatabaseSchema.md](./DatabaseSchema.md) — Index storage
- [PatchEngine.md](./PatchEngine.md) — Mutation operations

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md as part of documentation reorganization |