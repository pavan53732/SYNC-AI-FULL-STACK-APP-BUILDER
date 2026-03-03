# TOOLCHAIN MANIFEST

> **Sync AI Bundled Toolchain Authority: Pinned Versions, Folder Layout, and Redistribution Policy**
>
> **Why This Exists**: Sync AI is a Local AI Full-Stack Windows Native App Builder. Like "Lovable for desktop apps", it must work on a **completely clean Windows machine** with no Visual Studio, no .NET SDK, and no development tools installed. Every tool required to design, generate, compile, validate, fix, and package Windows applications is **bundled inside Sync AI's own installer** and owned exclusively by the builder.
>
> **Related Core Documents:**
>
> - [TOOLCHAIN_ISOLATION.md](./TOOLCHAIN_ISOLATION.md) — How bundled tools are isolated from system tools
> - [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — Layer 5: Build Execution Sandbox
> - [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — What is being built with these tools
> - [REPAIR_PATTERNS.md](./REPAIR_PATTERNS.md) — Build error recovery requiring these tools

---

## Table of Contents

1. [Bundling Mandate](#1-bundling-mandate)
2. [Canonical Toolchain Versions](#2-canonical-toolchain-versions)
3. [Bundled Toolchain Folder Layout](#3-bundled-toolchain-folder-layout)
4. [Tool Roles and Responsibilities](#4-tool-roles-and-responsibilities)
5. [Toolchain Lock File](#5-toolchain-lock-file)
6. [SDK Acquisition Strategy](#6-sdk-acquisition-strategy)
7. [Redistribution Policy](#7-redistribution-policy)
8. [Toolchain Integrity Validation](#8-toolchain-integrity-validation)
9. [Toolchain Update Policy](#9-toolchain-update-policy)

---

## 1. Bundling Mandate

> **ABSOLUTE INVARIANT**: Sync AI MUST NOT depend on any toolchain component installed on the host machine. Every compilation, packaging, and signing operation uses exclusively the tools from Sync AI's own bundled toolchain directory.

### Why Bundling is Non-Negotiable

| Scenario                              | Without Bundling (BROKEN)     | With Bundling (CORRECT)         |
| ------------------------------------- | ----------------------------- | ------------------------------- |
| User has no Visual Studio             | Build fails                   | Build succeeds                  |
| User has VS 2019 (wrong version)      | XAML compiler mismatch errors | Correct version always used     |
| User updates their .NET SDK           | Breaks existing projects      | Isolated — not affected         |
| CI/CD clean machine                   | Fails                         | Works identically               |
| User has conflicting MSBuild versions | Non-deterministic builds      | Deterministic every time        |
| Path pollution from user tools        | Random build failures         | Isolated PATH — no interference |

### Comparison to Analogous Systems

| Product            | What It Bundles                                                             |
| ------------------ | --------------------------------------------------------------------------- |
| **Lovable** (web)  | Node.js, npm, Vite, TypeScript compiler                                     |
| **Android Studio** | JDK, Gradle, Android SDK, AVD tools                                         |
| **Xcode**          | LLVM Clang, Swift toolchain, iOS SDK                                        |
| **Sync AI** (THIS) | .NET SDK, MSBuild, Windows App SDK Build Tools, WinAppSDK runtime, signtool |

---

## 2. Canonical Toolchain Versions

These are the **pinned, locked versions** used by Sync AI. They must not be changed without a formal toolchain version bump and compatibility validation.

### .NET SDK

| Property            | Value                                               |
| ------------------- | --------------------------------------------------- |
| **Version**         | `8.0.404`                                           |
| **Channel**         | `.NET 8 LTS`                                        |
| **Architecture**    | `x64` (primary), `arm64` (secondary)                |
| **Type**            | `sdk` (includes runtime + build tools + dotnet CLI) |
| **Download Source** | `https://dotnet.microsoft.com/download/dotnet/8.0`  |
| **Redistributable** | ✅ Yes — under .NET redistribution terms            |
| **Bundle Path**     | `{SyncAIRoot}\toolchain\dotnet\`                    |

### MSBuild

| Property              | Value                                                                 |
| --------------------- | --------------------------------------------------------------------- |
| **Version**           | `17.11.3` (Visual Studio Build Tools 2022 Update 1)                  |
| **Source**            | Visual Studio Build Tools 2022 (workload: `.NET desktop build tools`) |
| **Architecture**      | x64                                                                   |
| **Required Workload** | `.NET SDK Build Tools`                                                |
| **Bundle Path**       | `{SyncAIRoot}\toolchain\msbuild\`                                     |
| **Primary Binary**    | `MSBuild.exe` at `toolchain\msbuild\MSBuild\Current\Bin\MSBuild.exe`  |

> **Note**: MSBuild 17.x ships embedded in the .NET 8 SDK as well (`dotnet build` invokes MSBuild internally). For direct MSBuild invocation with full WinUI 3 XAML compiler support, the standalone MSBuild from Build Tools 2022 is required.

### Windows App SDK (WinUI 3)

| Property                 | Value                                                            |
| ------------------------ | ---------------------------------------------------------------- |
| **Version**              | `1.5.250211001`                                                  |
| **NuGet Package**        | `Microsoft.WindowsAppSDK` `1.5.250211001`                        |
| **Build Tools Package**  | `Microsoft.Windows.SDK.BuildTools` `10.0.22621.756`              |
| **XAML Compiler**        | Included in `Microsoft.WindowsAppSDK` NuGet                      |
| **Runtime**              | Must be installed on user's machine OR bundled as self-contained |
| **Self-Contained Mode**  | ✅ Enabled via `WindowsAppSdkSelfContained=true` in `.csproj`    |
| **NuGet Restore Source** | Local NuGet cache at `{SyncAIRoot}\toolchain\nuget-cache\`       |

> **CRITICAL**: `WindowsAppSdkSelfContained=true` means the generated MSIX package bundles the WinUI 3 runtime. The end-user machine does NOT need Windows App SDK installed to run the generated app.

### Signing Tools

| Property            | Value                                                                             |
| ------------------- | --------------------------------------------------------------------------------- |
| **Tool**            | `signtool.exe`                                                                    |
| **Source**          | Windows 11 SDK `10.0.22621.0`                                                     |
| **Version**         | `10.0.22621.3235`                                                                 |
| **Bundle Path**     | `{SyncAIRoot}\toolchain\winsdk\bin\10.0.22621.0\x64\signtool.exe`                 |
| **Purpose**         | MSIX package signing for sideload distribution                                    |
| **Certificate**     | Self-signed certificate auto-generated per project (dev signing)                  |
| **Redistributable** | ✅ Yes — `signtool.exe` is redistributable under Windows SDK redistribution terms |

### NuGet CLI

| Property          | Value                                                                            |
| ----------------- | -------------------------------------------------------------------------------- |
| **Version**       | `6.11.0`                                                                         |
| **Bundle Path**   | `{SyncAIRoot}\toolchain\nuget\nuget.exe`                                         |
| **Purpose**       | Package restore fallback (primary restore is via `dotnet restore`)               |
| **Offline Cache** | `{SyncAIRoot}\toolchain\nuget-cache\` — pre-populated with all required packages |

### EF Core CLI (dotnet-ef)

| Property            | Value                                               |
| ------------------- | --------------------------------------------------- |
| **Version**         | `8.0.11`                                            |
| **Type**            | .NET local tool                                     |
| **Bundle Path**     | `{SyncAIRoot}\toolchain\dotnet-tools\dotnet-ef.exe` |
| **Purpose**         | Migration generation and application                |
| **Redistributable** | ✅ Yes — MIT licensed open source                   |

### MSIX Packaging Tools

| Property            | Value                                                                               |
| ------------------- | ----------------------------------------------------------------------------------- |
| **Tool**            | `makeappx.exe`, `makepri.exe`                                                      |
| **Source**          | Windows 11 SDK `10.0.22621.0`                                                       |
| **Version**         | `10.0.22621.3235`                                                                   |
| **Bundle Path**     | `{SyncAIRoot}\toolchain\winsdk\bin\10.0.22621.0\x64\`                               |
| **Purpose**         | MSIX package creation (`makeappx`) and resource PRI generation (`makepri`)         |
| **Redistributable** | ✅ Yes — Windows SDK redistribution terms                                           |

### VC++ Build Tools

| Property            | Value                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------- |
| **Version**         | `14.41.34120` (Visual Studio Build Tools 2022 Update 1)                              |
| **Architecture**    | `x64` (primary), `arm64` (secondary)                                                  |
| **Type**            | `build-tools`                                                                         |
| **Download Source** | `https://visualstudio.microsoft.com/visual-cpp-build-tools/`                         |
| **Redistributable** | ✅ Yes — under Visual Studio redistribution terms                                     |
| **Bundle Path**     | `{SyncAIRoot}\toolchain\vc++\`                                                        |
| **Primary Binary** | `VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64\cl.exe`                                    |
| **ARM64 Support**   | Requires `Microsoft.VisualStudio.Workload.VCTools` + ARM64 targeting pack            |

---

## 3. Bundled Toolchain Folder Layout

```text
{SyncAIRoot}\                          ← Sync AI installation root
├── SyncAI.exe                         ← Main application executable
├── toolchain\                         ← BUNDLED — never modified by user
│   │
│   ├── dotnet\                        ← .NET 8 SDK (full SDK bundle)
│   │   ├── dotnet.exe                 ← Entry point: dotnet build, dotnet publish, dotnet ef
│   │   ├── sdk\8.0.404\               ← SDK version folder
│   │   ├── shared\                    ← .NET runtimes
│   │   │   ├── Microsoft.NETCore.App\8.0.11\
│   │   │   └── Microsoft.WindowsDesktop.App\8.0.11\
│   │   └── packs\                     ← Targeting packs
│   │
│   ├── msbuild\                       ← Standalone MSBuild 17.11
│   │   └── MSBuild\Current\Bin\
│   │       └── MSBuild.exe
│   │
│   ├── winsdk\                        ← Windows 11 SDK 10.0.22621.0 (subset)
│   │   └── bin\10.0.22621.0\x64\
│   │       ├── signtool.exe
│   │       ├── makeappx.exe
│   │       └── makepri.exe            ← Resource PRI file generator
│   │
│   ├── nuget\                         ← NuGet CLI
│   │   └── nuget.exe
│   │
│   ├── nuget-cache\                   ← Pre-populated offline NuGet package cache
│   │   ├── microsoft.windowsappsdk\1.5.250211001\
│   │   ├── microsoft.windows.sdk.buildtools\10.0.22621.756\
│   │   ├── microsoft.entityframeworkcore.sqlite\8.0.11\
│   │   ├── communitytoolkit.mvvm\8.3.2\
│   │   ├── communitytoolkit.winui.ui.controls\7.1.2\
│   │   └── ... (all Phase 1 required packages)
│   │
│   ├── dotnet-tools\                  ← .NET global tools bundle
│   │   └── dotnet-ef.exe              ← EF Core CLI 8.0.11
│   │
│   ├── vc++\                          ← VC++ Build Tools 14.41.34120
│   │   └── VC\Tools\MSVC\14.41.34120\
│   │       ├── bin\Hostx64\x64\       ← x64 compiler tools
│   │       │   ├── cl.exe             ← C/C++ compiler
│   │       │   ├── lib.exe            ← Library manager
│   │       │   └── link.exe            ← Linker
│   │       ├── bin\Hostx64\arm64\     ← ARM64 cross-compiler tools
│   │       │   ├── cl.exe
│   │       │   ├── lib.exe
│   │       │   └── link.exe
│   │       ├── lib\x64\               ← x64 CRT and STL libraries
│   │       │   ├── ucrt\              ← Universal C Runtime
│   │       │   └── stdcpp\            ← C++ Standard Library
│   │       └── lib\arm64\             ← ARM64 CRT and STL libraries
│   │           ├── ucrt\              ← Universal C Runtime
│   │           └── stdcpp\            ← C++ Standard Library
│   │       └── include\               ← C/C++ headers
│   │           └── ucrt\              ← CRT headers
│   │           └── stdlib\            ← STL headers
│   │
│   └── certs\                         ← Certificate management
│       ├── sync-ai-dev.pfx            ← Dev signing certificate template
│       └── cert-gen.ps1               ← Self-signed cert generator per project
│
├── workspace\                         ← Per-project build workspaces (runtime-created)
│   └── {ProjectId}\                   ← Isolated workspace per generation session
│
└── logs\                              ← Build logs + AI agent logs
```

---

## 4. Tool Roles and Responsibilities

| Tool            | Invoked By      | Purpose                                                   | Key Commands                                            |
| --------------- | --------------- | --------------------------------------------------------- | ------------------------------------------------------- |
| `dotnet.exe`    | Build Executor  | Restore, build, publish                                   | `dotnet restore`, `dotnet build`, `dotnet publish`      |
| `MSBuild.exe`   | Build Executor  | WinUI 3 XAML compilation (XAML compiler requires MSBuild) | `MSBuild /t:Build /p:Platform=x64`                      |
| `dotnet-ef.exe` | Schema Agent    | EF Core migration generation + application                | `dotnet ef migrations add`, `dotnet ef database update` |
| `signtool.exe`  | Packaging Agent | MSIX package signing                                      | `signtool sign /fd sha256 /f cert.pfx ...`              |
| `makeappx.exe`  | Packaging Agent | MSIX bundle creation                                      | `makeappx pack /d {outputDir} /p {app.msix}`            |
| `makepri.exe`   | Packaging Agent | Windows resource PRI generation                           | `makepri new /pr {outDir} /cf priconfig.xml`            |
| `nuget.exe`     | Build Executor  | Package restore fallback                                  | `nuget restore -PackagesDirectory {cache}`              |
| `cert-gen.ps1`  | Cert Manager    | Per-project self-signed cert creation                     | `New-SelfSignedCertificate ...`                         |

---

## 5. Toolchain Lock File

Every project workspace generated by Sync AI contains a `toolchain.lock.json` file that records the exact tool versions used to build it. This guarantees reproducibility and audit capability.

```json
{
  "syncAiVersion": "1.0.0",
  "lockedAt": "2026-03-03T05:30:00Z",
  "tools": {
    "dotnet": {
      "version": "8.0.404",
      "path": "toolchain/dotnet/dotnet.exe",
      "sha256": "a1b2c3d4..."
    },
    "msbuild": {
      "version": "17.11.3",
      "path": "toolchain/msbuild/MSBuild/Current/Bin/MSBuild.exe",
      "sha256": "e5f6a7b8..."
    },
    "dotnetEf": {
      "version": "8.0.11",
      "path": "toolchain/dotnet-tools/dotnet-ef.exe",
      "sha256": "c9d0e1f2..."
    },
    "signtool": {
      "version": "10.0.22621.3235",
      "path": "toolchain/winsdk/bin/10.0.22621.0/x64/signtool.exe",
      "sha256": "a3b4c5d6..."
    },
    "makeappx": {
      "version": "10.0.22621.3235",
      "path": "toolchain/winsdk/bin/10.0.22621.0/x64/makeappx.exe",
      "sha256": "e7f8a9b0..."
    },
    "makepri": {
      "version": "10.0.22621.3235",
      "path": "toolchain/winsdk/bin/10.0.22621.0/x64/makepri.exe",
      "sha256": "f1a2b3c4..."
    },
    "nuget": {
      "version": "6.11.0",
      "path": "toolchain/nuget/nuget.exe",
      "sha256": "d4e5f6a7..."
    },
    "vcBuildTools": {
      "version": "14.41.34120",
      "path": "toolchain/vc++/VC/Tools/MSVC/14.41.34120/bin/Hostx64/x64/cl.exe",
      "sha256": "b1c2d3e4..."
    }
  },
  "nugetPackages": {
    "Microsoft.WindowsAppSDK": "1.5.250211001",
    "Microsoft.Windows.SDK.BuildTools": "10.0.22621.756",
    "Microsoft.EntityFrameworkCore.Sqlite": "8.0.11",
    "CommunityToolkit.Mvvm": "8.3.2",
    "CommunityToolkit.WinUI.UI.Controls": "7.1.2"
  }
}
```

---

## 6. SDK Acquisition Strategy

### Installer-Time Bundling

The Sync AI installer (`SyncAI-Setup.exe`) acquires all toolchain components at install time using one of two strategies:

| Strategy            | When Used                     | Method                                                      |
| ------------------- | ----------------------------- | ----------------------------------------------------------- |
| **Offline Bundle**  | Installer includes everything | Pre-packed inside installer MSI/MSIX                        |
| **Online Download** | Installer is a bootstrapper   | Downloads each component from official sources during setup |

**Phase 1 Decision**: Offline bundle. The full installer includes all toolchain components pre-packed. This ensures zero internet dependency post-installation.

### Installer Size Estimate

| Component                               | Size (approx.) |
| --------------------------------------- | -------------- |
| .NET 8 SDK (x64)                        | ~220 MB        |
| MSBuild + Build Tools subset            | ~80 MB         |
| Windows SDK subset (signtool, makeappx) | ~15 MB         |
| NuGet cache (all required packages)     | ~150 MB        |
| EF Core CLI + dotnet-tools              | ~25 MB         |
| Sync AI app itself + AI service         | ~50 MB         |
| **Total**                               | **~540 MB**    |

> This is comparable to VS Code (~100 MB) + typical extension packs. Fully acceptable for a professional builder tool.

---

## 7. Redistribution Policy

Sync AI bundles the following components under their respective redistribution licenses:

| Component                              | License                              | Redistribution Allowed      | Condition                           |
| -------------------------------------- | ------------------------------------ | --------------------------- | ----------------------------------- |
| `.NET 8 SDK`                           | MIT + Microsoft .NET Library License | ✅ Yes                      | Include attribution in installer    |
| `MSBuild` (Build Tools)                | Visual Studio EULA                   | ✅ Yes (subset)             | May redistribute build tools subset |
| `Windows SDK` (`signtool`, `makeappx`) | Windows SDK EULA                     | ✅ Yes (listed tools)       | Must be distributed as-is           |
| `VC++ Build Tools`                     | Visual Studio EULA                   | ✅ Yes (subset)             | May redistribute VC++ build tools    |
| `EF Core CLI` (`dotnet-ef`)            | MIT                                  | ✅ Yes                      | No conditions                       |
| `NuGet packages`                       | Each package's own license           | ✅ Yes (all MIT/Apache 2.0) | Include license files               |
| `CommunityToolkit.Mvvm`                | MIT                                  | ✅ Yes                      | No conditions                       |
| `CommunityToolkit.WinUI`               | MIT                                  | ✅ Yes                      | No conditions                       |

### License File Requirement

All redistributed licenses must be stored at:

```text
{SyncAIRoot}\toolchain\licenses\
├── dotnet-sdk.txt
├── msbuild.txt
├── windows-sdk.txt
├── ef-core.txt
└── nuget-packages.txt
```

And must be accessible from the Sync AI "About" / "Legal" screen.

---

## 8. Toolchain Integrity Validation

At every Sync AI startup, the **Toolchain Integrity Validator** performs the following checks:

```text
On Sync AI Launch:

1. Verify toolchain\ folder exists
2. For each critical binary (dotnet.exe, MSBuild.exe, signtool.exe):
   a. Check file exists
   b. Check SHA-256 hash matches toolchain.lock reference
   c. Check version via CLI flag (e.g., dotnet --version, MSBuild -version)
3. If any check fails:
   a. Mark toolchain as CORRUPT
   b. Show user: "Sync AI installation is damaged. Please reinstall."
   c. Block all build operations until reinstalled
4. If all checks pass:
   a. Mark toolchain as READY
   b. Log versions to diagnostic log
   c. Proceed to normal startup
```

### Validation Result States

| State              | Meaning                            | User Experience                    |
| ------------------ | ---------------------------------- | ---------------------------------- |
| `READY`            | All tools present and hashes match | Normal operation                   |
| `VERSION_MISMATCH` | Binary exists but version differs  | Warning + continue (soft error)    |
| `MISSING`          | Binary not found                   | Block operation + reinstall prompt |
| `CORRUPT`          | SHA-256 hash mismatch              | Block operation + reinstall prompt |

---

## 9. Toolchain Update Policy

### Phase 1 Rules

| Rule                        | Description                                                                         |
| --------------------------- | ----------------------------------------------------------------------------------- |
| **No auto-update**          | Toolchain is never updated silently; only via full Sync AI installer update         |
| **Major updates only**      | Toolchain versions are updated only with major Sync AI releases                     |
| **Backwards compatibility** | Older projects include `toolchain.lock.json` — build system uses the locked version |
| **User notification**       | If a toolchain update is available, user sees a notification in Sync AI settings    |

### Version Bump Process

When upgrading the toolchain (e.g., .NET 8 → .NET 9 in a future major release):

```text
1. Update version numbers in this document
2. Rebuild offline installer with new toolchain
3. Update SHA-256 hashes in toolchain.lock reference
4. Update compatibility test matrix
5. Release as new major version of Sync AI
```

---

## 9. Artifact Reproducibility

> **INVARIANT**: All build artifacts MUST be reproducible from identical inputs using locked toolchain versions.

### Reproducibility Requirements

| Requirement | Description | Implementation |
| ----------- | | ------------- |
| **Input Hash** | Capture hash of all inputs (spec, assets, templates) | Store in `build_inputs.json` |
| **Toolchain Lock** | Use pinned tool versions from `toolchain.lock.json` | Mandatory for all builds |
| **Output Hash** | Generate SHA-256 for each output artifact | Store in `build_outputs.json` |
| **Provenance Metadata** | Track lineage from input to output | Include in MSIX manifest |

### Build Reproducibility Pipeline

```text
1. Capture Input State
   └── Hash spec.json, assets/, templates/
   └── Store as build_inputs.json

2. Lock Toolchain
   └── Use toolchain.lock.json versions
   └── Verify tool binaries match locked hashes

3. Build Artifact
   └── Execute build with locked toolchain
   └── Capture all output files

4. Generate Output Hashes
   └── SHA-256 each output binary
   └── Store in build_outputs.json

5. Verify Reproducibility (MANDATORY for release builds)
   └── Rebuild with same inputs
   └── Compare output hashes
   └── FAIL if hashes differ
```

### Provenance Metadata Schema

```json
{
  "buildId": "uuid",
  "timestamp": "ISO8601",
  "inputHash": "sha256",
  "toolchainLock": "sha256 of toolchain.lock.json",
  "outputs": [
    {
      "path": "app.exe",
      "sha256": "...",
      "size": 123456
    },
    {
      "path": "app.msix",
      "sha256": "...",
      "size": 789012
    }
  ]
}
```

> **NOTE**: Documentation version examples (like MSBuild `17.11.3`) MUST be auto-generated from `toolchain.lock.json` to ensure consistency.

---

## Change Log

| Date       | Change                                                                               |
| ---------- | ------------------------------------------------------------------------------------ |
| 2026-03-03 | Initial creation — complete toolchain manifest with versions, layout, redistribution |

---

## References

- [TOOLCHAIN_ISOLATION.md](./TOOLCHAIN_ISOLATION.md) — How bundled tools are isolated from system tools
- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — Build Execution Sandbox (Layer 5)
- [REPAIR_PATTERNS.md](./REPAIR_PATTERNS.md) — Build failure recovery using these tools
- [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — What is compiled with these tools
