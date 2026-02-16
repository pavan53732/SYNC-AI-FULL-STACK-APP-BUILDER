# Project Layout and Deployment

> **Authority**: This document defines folder layout, .builder folder, snapshot storage, MSIX packaging, and certificate model.
> **Status**: Project structure and deployment

---

## Part 1: Project Folder Structure

### Builder Workspace Root

```
Builder Workspace Root
├── Projects/
│   ├── Project_A/
│   │   ├── src/
│   │   ├── bin/build/
│   │   ├── .snapshots/
│   │   │   ├── snapshot_001.zip
│   │   │   ├── snapshot_002.zip
│   │   │   └── snapshot_003.zip
│   │   └── .diffs/
│   │       ├── diff_001-002.patch
│   │       └── diff_002-003.patch
│   │
│   └── Project_B/
│       └── ... (same structure)
│
├── Temp/
│   ├── build_workspace_001/
│   ├── build_workspace_002/
│   └── (clean after each build)
│
└── Cache/
    ├── roslyn_symbols/
    ├── embeddings/
    └── dependency_graph/
```

---

## Part 2: .builder Folder

Each project contains a `.builder` folder for internal system data:

```
Project/
├── src/
├── .builder/
│   ├── config.json           # Project configuration
│   ├── snapshots/            # ZIP archives of project state
│   ├── graph.db             # SQLite project graph
│   ├── symbols/              # Cached Roslyn symbols
│   └── embeddings/           # Vector embeddings
└── (project files)
```

---

## Part 3: Snapshot Storage

### Snapshot Structure
- Format: ZIP archives
- Location: `.builder/snapshots/`
- Naming: `snapshot_{taskId}_{timestamp}.zip`
- Contents: All source files (excludes bin/, obj/)

### Snapshot Rules
- Create before every mutation
- Mark as committed on success
- Keep for rollback on failure
- Prune after project closure

---

## Part 4: MSIX Packaging

### Build Output
```
Project/
├── bin/
│   ├── Debug/
│   │   └── win-x64/
│   │       └── SyncAIApp.exe
│   └── Release/
│       └── win-x64/
│           └── SyncAIApp.exe
└── AppPackages/
    └── SyncAIApp_1.0.0.0_x64.msix
```

### MSIX Configuration

```xml
<Package
  xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10">
  
  <Identity
    Name="SyncAI.AppBuilder"
    Publisher="CN=YourPublisher"
    Version="1.0.0.0" />
    
  <Properties>
    <DisplayName>SyncAI App Builder</DisplayName>
    <PublisherDisplayName>Your Company</PublisherDisplayName>
  </Properties>
</Package>
```

---

## Part 5: Certificate Model

### Development
- Self-signed certificate for local testing
- Visual Studio generates automatically

### Production
- Code signing certificate from trusted CA
- Required for MSIX distribution
- Publisher identity must match certificate

---

## Part 6: Deployment Options

### Option A: Local Desktop
- Direct .exe execution
- No installation required
- Best for development/testing

### Option B: MSIX Package
- Windows Store distribution
- Sideloading support
- Automatic updates

### Option C: Hybrid
- Default: Local builds
- Optional: Cloud build agent
- Offline capability

---

## Related Documents

- [00_CANONICAL_AUTHORITY.md](./00_CANONICAL_AUTHORITY.md) - System invariants
- [03_BUILD_AND_MUTATION_KERNEL.md](./03_BUILD_AND_MUTATION_KERNEL.md) - Build kernel

---

**End of Project Layout and Deployment**
