# Patch Engine

> **Code Intelligence Layer: AST Mutations, Patch Operations, and Safety Guards**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [ConflictDetection.md](./ConflictDetection.md) — Patch failures

---

## Table of Contents

1. [Allowed Patch Operations](#1-allowed-patch-operations)
2. [PatchEngine Implementation](#2-patchengine-implementation)
3. [Mutation Safety Guards](#3-mutation-safety-guards)

---

## 1. Allowed Patch Operations

LLM must NOT return full files. Only structured patch operations:

```csharp
public enum PatchOperationType
{
    ADD_CLASS,
    ADD_METHOD,
    ADD_PROPERTY,
    ADD_FIELD,
    MODIFY_METHOD_BODY,
    MODIFY_PROPERTY,
    INSERT_USING,
    REMOVE_MEMBER,
    DELETE_FILE,              // Remove file from project
    UPDATE_XAML_NODE,
    ADD_XAML_ELEMENT,
    MODIFY_XAML_ATTRIBUTE
}
```

---

## 2. PatchEngine Implementation

```csharp
public class PatchEngine : IPatchEngine
{
    private readonly ILogger<PatchEngine> _logger;
    private readonly ICodeIndexer _indexer;
    private readonly AdhocWorkspace _workspace;

    public async Task<PatchResult> ApplyPatchAsync(PatchOperation patch)
    {
        // 1. Validate patch
        var validation = await ValidatePatchAsync(patch);
        if (!validation.IsValid) return PatchResult.Failed(validation.ErrorMessage);

        // 2. Parse to syntax tree
        var filePath = patch.TargetFile;
        var sourceText = await File.ReadAllTextAsync(filePath);
        var tree = CSharpSyntaxTree.ParseText(sourceText);
        var root = await tree.GetRootAsync();

        // 3. Apply transformation based on operation type
        var newRoot = patch.OperationType switch
        {
            PatchOperationType.ADD_CLASS => ApplyAddClass(root, (AddClassPayload)patch.Payload),
            PatchOperationType.ADD_METHOD => ApplyAddMethod(root, (AddMethodPayload)patch.Payload),
            _ => throw new NotSupportedException()
        };

        // 4. Validate syntax & format
        var formatted = Formatter.Format(newRoot, _workspace);
        await File.WriteAllTextAsync(filePath, formatted.ToFullString());
        await _indexer.IndexFileAsync(filePath);

        return PatchResult.Success(ComputeFileHash(formatted.ToFullString()));
    }
}
```

---

## 3. Mutation Safety Guards

### Patch Delta Ceiling

To prevent catastrophic regeneration, the `MutationGuard` enforces a limit on the scale of transformation allowed per task.

```csharp
public class MutationGuard
{
    private readonly ICodeIndexer _indexer;

    public async Task<bool> IsSafePatchAsync(string filePath, SyntaxNode newRoot, AgentExecutionContext context)
    {
        var oldRoot = await _indexer.GetSyntaxRootAsync(filePath);
        var diff = ComputeAstDiff(oldRoot, newRoot);

        // Ceiling Enforcement
        if (diff.NodesModified > context.MaxNodesModifiedPerTask)
            throw new MutationLimitExceededException($"Mutation too large: {diff.NodesModified} nodes");

        if (diff.FilesTouched > context.MaxFilesTouchedPerTask)
            throw new MutationLimitExceededException($"Too many files: {diff.FilesTouched} files");

        return true;
    }
}
```

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document
- [IndexingArchitecture.md](./IndexingArchitecture.md) — Mutation mode enforcement
- [ConflictDetection.md](./ConflictDetection.md) — Patch failures
- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Agent execution context

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md as part of documentation reorganization |