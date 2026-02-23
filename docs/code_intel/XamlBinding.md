# XAML Binding Index

> **Code Intelligence Layer: XAML ↔ ViewModel Graph for WinUI 3**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [DatabaseSchema.md](./DatabaseSchema.md) — XAML binding storage

---

## Table of Contents

1. [XAML ↔ ViewModel Graph](#1-xaml--viewmodel-graph)
2. [XamlBindingIndexer Implementation](#2-xamlbindingindexer-implementation)

---

## 1. XAML ↔ ViewModel Graph

Special layer for WinUI 3:

- Bindings (`{x:Bind ViewModel.Property}`)
- Commands (`{x:Bind ViewModel.SaveCommand}`)
- Dependency properties
- Resource dictionary references

---

## 2. XamlBindingIndexer Implementation

```csharp
public class XamlBindingIndexer
{
    // Regex fallback for robust parsing when XML is malformed
    private static readonly Regex XBindRegex = new(@"\{x:Bind\s+(?<path>[^,}]+)", RegexOptions.Compiled);
    private static readonly Regex BindingRegex = new(@"\{Binding\s+(?<path>[^,}]+)", RegexOptions.Compiled);

    public async Task IndexXamlFileAsync(string xamlPath)
    {
        var xaml = await File.ReadAllTextAsync(xamlPath);

        // 1. Try robust Regex extraction first (for speed and resilience)
        var regexBindings = XBindRegex.Matches(xaml).Concat(BindingRegex.Matches(xaml));
        foreach (Match match in regexBindings)
        {
            var path = match.Groups["path"].Value;
            await IndexBindingAsync(xamlPath, path, "Regex");
        }

        // 2. Try precise XML parsing (for depth)
        try
        {
            var doc = XDocument.Parse(xaml);
            var xmlBindings = doc.Descendants()
                .SelectMany(e => e.Attributes())
                .Where(a => a.Value.Contains("{x:Bind") || a.Value.Contains("{Binding"))
                .Select(a => ExtractBindingPath(a.Value));

            foreach (var binding in xmlBindings)
            {
                await IndexBindingAsync(xamlPath, binding.Path, "XML");
            }
        }
        catch (XmlException)
        {
            // Fallback to regex-only results if XML is broken
        }
    }
}
```

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document
- [DatabaseSchema.md](./DatabaseSchema.md) — XAML binding storage
- [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md) — WinUI 3 design

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md as part of documentation reorganization |