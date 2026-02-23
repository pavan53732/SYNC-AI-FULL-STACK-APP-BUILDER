# Export & Packaging

> **User Workflows: MSIX Generation, Asset Export, and Code Ownership**
>
> **Parent Document:** [USER_WORKFLOWS.md](../USER_WORKFLOWS.md)

---

## Installer Generation

Every successful build automatically generates:

- **MSIX Package**: Ready for distribution
- **Auto-signed**: Test certificate for local testing
- **Store-ready**: Can be signed with production certificate

---

## Export Options

| Option              | Description                                    |
| :------------------ | :--------------------------------------------- |
| **MSIX Installer**  | Full package for sideloading                   |
| **Source Code**     | Complete Visual Studio solution                |
| **Project Archive** | .zip of entire project including history       |

---

## Code Ownership

The generated code is yours:

- Standard WinUI 3 / .NET structure
- No proprietary runtime dependencies
- Can be opened in Visual Studio
- Can be modified manually
- Can be migrated to other platforms

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from USER_WORKFLOWS.md |