# Indexing Architecture

> **Code Intelligence Layer: Indexing Policy, Mutation Mode Enforcement, and Symbol Extraction**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [RoslynCompilation.md](./RoslynCompilation.md) — Full compilation model

---

## Table of Contents

1. [Core Principle: No Raw File Writes](#1-core-principle-no-raw-file-writes)
2. [Indexing Policy](#2-indexing-policy)
3. [Mutation Mode Enforcement](#3-mutation-mode-enforcement)
4. [What Must Be Indexed](#4-what-must-be-indexed)
5. [Lightweight Indexing](#5-lightweight-indexing)

---

## 1. Core Principle: No Raw File Writes

### ❌ FORBIDDEN Operations

```csharp
// ❌ NEVER DO THIS - String replacement
var code = File.ReadAllText("MyClass.cs");
code = code.Replace("oldMethod", "newMethod");
File.WriteAllText("MyClass.cs", code);

// ❌ NEVER DO THIS - Regex replacement
var code = File.ReadAllText("MyClass.cs");
code = Regex.Replace(code, pattern, replacement);
File.WriteAllText("MyClass.cs", code);

// ❌ NEVER DO THIS - Direct file overwrite
File.WriteAllText("MyClass.cs", llmGeneratedCode);
```

### ✅ REQUIRED Approach

```csharp
// ✅ ALWAYS DO THIS - Roslyn AST transformation
var tree = CSharpSyntaxTree.ParseText(File.ReadAllText("MyClass.cs"));
var root = await tree.GetRootAsync();

// Apply transformation
var newRoot = root.ReplaceNode(oldNode, newNode);

// Format and write
var formatted = Formatter.Format(newRoot, workspace);
File.WriteAllText("MyClass.cs", formatted.ToFullString());
```

---

## 2. Indexing Policy

The system uses a **tiered indexing approach** optimized for different scenarios:

**Full Semantic Mode** (Default for Production Operations):
- Full Roslyn AST, symbol graph, and cross-file resolution.
- Required for all mutation operations and capability inference.
- Ensures consistent, deterministic behavior for code changes.

**Lightweight Mode** (Initial Scans and Quick Lookups):
- Shallow metadata index for fast project overview.
- Used for initial project discovery and UI listings.
- Automatically upgraded to Full Semantic when mutations are needed.

---

## 3. Mutation Mode Enforcement (INVARIANT)

> **CRITICAL**: All mutation operations MUST use Full Semantic Mode. Lightweight Mode is strictly FORBIDDEN for any operation that modifies code.

```csharp
public class MutationModeEnforcer
{
    /// <summary>
    /// Called BEFORE any patch operation. Throws if not in Full Semantic Mode.
    /// </summary>
    public void EnsureFullSemanticModeForMutation(IndexingMode currentMode)
    {
        if (currentMode != IndexingMode.FULL_SEMANTIC)
        {
            throw new InvalidOperationException(
                "MUTATION_REQUIRES_FULL_SEMANTIC: " +
                "All mutation operations require Full Semantic Mode. " +
                "Current mode: " + currentMode + ". " +
                "Call UpgradeToFullSemanticModeAsync() before attempting mutations.");
        }
    }
}

public enum IndexingMode
{
    LIGHTWEIGHT,    // Shallow metadata only
    FULL_SEMANTIC   // Complete Roslyn AST + symbol graph
}
```

---

## 4. What Must Be Indexed

- **Classes** — Name, namespace, base class, interfaces
- **Methods** — Signature, parameters, return type, accessibility
- **Properties** — Type, getter/setter, accessibility
- **Fields** — Type, accessibility, initializer
- **Interfaces** — Members, inheritance
- **Inheritance graph** — Class hierarchy
- **Dependency graph** — File-to-file dependencies
- **XAML binding references** — x:Name, Binding paths, x:Bind paths

---

## 5. Lightweight Indexing

For smaller projects or initial scans, we use a "shallow" index.

### Symbol-Level Index (Shallow)

Lightweight symbol extraction using regex — no full AST required.

```csharp
public class SymbolExtractor
{
    public async Task<List<Symbol>> ExtractSymbolsAsync(string filePath)
    {
        var code = await File.ReadAllTextAsync(filePath);
        var symbols = new List<Symbol>();

        // Lightweight parsing (regex) - C# syntax patterns
        var classMatches = Regex.Matches(code, @"(?:public|internal|private|protected)?\s*(?:partial\s+)?class\s+(\w+)");
        foreach (Match match in classMatches)
        {
            symbols.Add(new Symbol
            {
                Name = match.Groups[1].Value,
                Kind = "class",
                Exported = match.Value.Contains("public") || match.Value.Contains("internal")
            });
        }

        var methodMatches = Regex.Matches(code, @"(?:public|private|protected|internal)\s+(?:static\s+)?(?:async\s+)?(?:[\w<>]+)\s+(\w+)\s*\(");
        foreach (Match match in methodMatches)
        {
            symbols.Add(new Symbol
            {
                Name = match.Groups[1].Value,
                Kind = "method",
                Exported = match.Value.Contains("public")
            });
        }

        return symbols;
    }
}
```

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document
- [RoslynCompilation.md](./RoslynCompilation.md) — Full compilation model
- [DatabaseSchema.md](./DatabaseSchema.md) — Index storage
- [PatchEngine.md](./PatchEngine.md) — Mutation operations

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md as part of documentation reorganization |