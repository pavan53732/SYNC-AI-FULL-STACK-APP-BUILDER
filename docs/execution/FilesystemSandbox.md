# Filesystem Sandbox

> **Execution Layer: Workspace Isolation, Security Enforcement, and Snapshot Constraints**
>
> **Parent Document:** [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md)
>
> **Related:** [ProcessIsolation.md](./ProcessIsolation.md) — Job Objects and ACL enforcement

---

## Table of Contents

1. [Purpose](#1-purpose)
2. [Workspace Structure](#2-workspace-structure)
3. [Security Enforcement](#3-security-enforcement)
4. [Banned Paths](#4-banned-paths)
5. [Snapshot Constraints](#5-snapshot-constraints)

---

## 1. Purpose

The sandbox ensures that Sync AI never accidentally modifies user files outside the project scope. It acts as a virtualized file system wrapper.

---

## 2. Workspace Structure

Each project lives in an isolated workspace:

```text
%USERPROFILE%\.syncai\
├── Workspaces/
│   └── {ProjectId}/
│       ├── src/                    ← Generated code
│       ├── .git/                   ← Hidden Git repository for version history
│       ├── .gitignore              ← Standard Git ignore file
│       ├── ProjectState.db         ← Maps prompts to commit SHAs
│       ├── .metadata.json          ← Project metadata
│       ├── packaging/              ← Manifests & Certificates
│       │   ├── Package.appxmanifest
│       │   └── certificate.pfx
│       ├── dist/                   ← Final MSIX Bundles
│       │   └── app.msixbundle
│       └── .build-output/          ← Compiled binaries
├── Temp/
│   ├── build_workspace_001/        ← Isolated copy for build stability
│   ├── build_workspace_002/
│   └── (cleaned after each build)
├── Database/
│   └── sync-ai.db                  ← SQLite graph DB
├── Cache/
│   ├── NuGet/                      ← Local NuGet cache
│   ├── Embeddings/                 ← Vector cache
│   ├── roslyn_symbols/             ← Cached Roslyn symbol data
│   └── dependency_graph/           ← Cached dependency graph data
└── Logs/
    └── execution.log               ← Debug log (hidden from user)
```

---

## 3. Security Enforcement

```csharp
public class FileSystemSandbox
{
    private readonly string _rootPath;
    private readonly IDiskSpaceValidator _diskValidator;

    public FileSystemSandbox(string rootPath)
    {
        _rootPath = Path.GetFullPath(rootPath);
        if (!Directory.Exists(_rootPath)) Directory.CreateDirectory(_rootPath);
    }

    public async Task WriteFileAsync(string relativePath, string content)
    {
        // 1. Security Check
        ValidatePath(relativePath);

        // 2. Resource Check
        if (!_diskValidator.HasSpace(content.Length))
            throw new InsufficientStorageException();

        var fullPath = Path.Combine(_rootPath, relativePath);
        var directory = Path.GetDirectoryName(fullPath);
        if (!Directory.Exists(directory)) Directory.CreateDirectory(directory);

        // 3. Atomic Write Pattern
        var tempPath = fullPath + ".tmp";
        await File.WriteAllTextAsync(tempPath, content);

        // 4. Move with Overwrite (Atomic on NTFS)
        File.Move(tempPath, fullPath, overwrite: true);

        // 5. Register Change for Snapshot
        _snapshotManager.RegisterChange(relativePath);
    }

    private void ValidatePath(string relativePath)
    {
        if (string.IsNullOrWhiteSpace(relativePath)) throw new ArgumentException("Invalid path");

        var fullPath = Path.GetFullPath(Path.Combine(_rootPath, relativePath));
        if (!fullPath.StartsWith(_rootPath, StringComparison.OrdinalIgnoreCase))
        {
            throw new SecurityException($"Access Warning: Path traversal attempt detected: {relativePath}");
        }

        if (IsSystemFile(relativePath))
        {
             throw new SecurityException($"Access Warning: Restricted file access: {relativePath}");
        }
    }
}
```

---

## 4. Banned Paths

The following paths are explicitly blocked from AI-generated patches:

```csharp
private static readonly HashSet<string> BannedPaths = new()
{
    ".git", ".vs", "bin", "obj",
    ".metadata.json"   // file, not directory
};
```

> **Note:** `*.csproj` files are intentionally excluded from `BannedPaths` — they must remain accessible for build operations.

---

## 5. Snapshot Constraints (Git-Based)

- The system maintains a **Git history** of all successful builds and significant mutations.
- Old snapshots are automatically pruned when the repository size exceeds a threshold (configurable, default 500 MB).
- Disk guard: creation blocked if available disk space < **500 MB**
- Pruning: `SnapshotPruner` uses Git commands to squash or remove old commits, preserving the last N states.
- `SnapshotId` values are Git commit hashes, enabling deterministic rollback and time-travel.

---

## References

- [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md) — Parent document
- [ProcessIsolation.md](./ProcessIsolation.md) — Job Objects and ACL enforcement
- [CrashRecovery.md](./CrashRecovery.md) — Snapshot restore mechanisms
- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Database schema

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from EXECUTION_ENVIRONMENT.md as part of documentation reorganization |