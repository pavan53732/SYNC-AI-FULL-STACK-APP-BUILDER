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
| **Version**           | `17.11.3` (Visual Studio Build Tools 2022 Update 1)                   |
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

| Property            | Value                                                                      |
| ------------------- | -------------------------------------------------------------------------- |
| **Tool**            | `makeappx.exe`, `makepri.exe`                                              |
| **Source**          | Windows 11 SDK `10.0.22621.0`                                              |
| **Version**         | `10.0.22621.3235`                                                          |
| **Bundle Path**     | `{SyncAIRoot}\toolchain\winsdk\bin\10.0.22621.0\x64\`                      |
| **Purpose**         | MSIX package creation (`makeappx`) and resource PRI generation (`makepri`) |
| **Redistributable** | ✅ Yes — Windows SDK redistribution terms                                  |

### VC++ Build Tools

| Property            | Value                                                                     |
| ------------------- | ------------------------------------------------------------------------- |
| **Version**         | `14.41.34120` (Visual Studio Build Tools 2022 Update 1)                   |
| **Architecture**    | `x64` (primary), `arm64` (secondary), `x86` (legacy)                      |
| **Type**            | `build-tools`                                                             |
| **Download Source** | `https://visualstudio.microsoft.com/visual-cpp-build-tools/`              |
| **Redistributable** | ✅ Yes — under Visual Studio redistribution terms                         |
| **Bundle Path**     | `{SyncAIRoot}\toolchain\vc++\`                                            |
| **Primary Binary**  | `VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64\cl.exe`                        |
| **ARM64 Support**   | Requires `Microsoft.VisualStudio.Workload.VCTools` + ARM64 targeting pack |

#### Native Toolchain Components

| Tool | Purpose | Bundle Path |
| ---- | ------- | ----------- |
| **cl.exe** | C/C++ Compiler | `VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64\cl.exe` |
| **link.exe** | Native Linker | `VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64\link.exe` |
| **lib.exe** | Library Manager | `VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64\lib.exe` |
| **rc.exe** | Resource Compiler | `VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64\rc.exe` |
| **mt.exe** | Manifest Tool | `VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64\mt.exe` |
| **vcvarsall.bat** | Environment Setup | `VC\Tools\MSVC\14.41.34120\Auxiliary\Build\vcvarsall.bat` |

#### Windows SDK for Native

| Component | Purpose | Bundle Path |
| --------- | ------- | ----------- |
| **Headers** | C++ Win32 headers | `{SyncAIRoot}\toolchain\winsdk\Include\` |
| **Libraries** | Win32 import libs | `{SyncAIRoot}\toolchain\winsdk\Lib\` |
| **CRT** | C Runtime libraries | `VC\Tools\MSVC\14.41.34120\ucrt\` |

### Toolchain Profiles

| Profile | .NET SDK | MSBuild | MSVC | Windows SDK | Use Case |
| -------- | -------- | -------- | ---- | ----------- | -------- |
| **ManagedOnly** | ✅ | ✅ | ❌ | ⚠️ Optional | WinUI3, WPF, WinForms, Console |
| **NativeOnly** | ❌ | ❌ | ✅ | ✅ | Win32, WinRT |
| **Hybrid** | ✅ | ✅ | ✅ | ✅ | C# + C++ interop |

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
│   │   └── ... (all required packages)
│   │
│   ├── dotnet-tools\                  ← .NET global tools bundle
│   │   └── dotnet-ef.exe              ← EF Core CLI 8.0.11
│   │
│   ├── vc++\                          ← VC++ Build Tools 14.41.34120
│   │   └── VC\Tools\MSVC\14.41.34120\
│   │       ├── bin\Hostx64\x64\       ← x64 compiler tools
│   │       │   ├── cl.exe             ← C/C++ compiler
│   │       │   ├── lib.exe            ← Library manager
│   │       │   ├── link.exe            ← Linker
│   │       │   ├── rc.exe             ← Resource compiler
│   │       │   └── mt.exe             ← Manifest tool
│   │       ├── bin\Hostx64\arm64\     ← ARM64 cross-compiler tools
│   │       │   ├── cl.exe
│   │       │   ├── lib.exe
│   │       │   └── link.exe
│   │       ├── bin\Hostx64\x86\       ← x86 compiler tools
│   │       │   ├── cl.exe
│   │       │   ├── lib.exe
│   │       │   └── link.exe
│   │       ├── lib\x64\               ← x64 CRT and STL libraries
│   │       │   ├── ucrt\              ← Universal C Runtime
│   │       │   └── stdcpp\            ← C++ Standard Library
│   │       ├── lib\arm64\             ← ARM64 CRT and STL libraries
│   │       │   ├── ucrt\              ← Universal C Runtime
│   │       │   └── stdcpp\            ← C++ Standard Library
│   │       └── include\               ← C/C++ headers
│   │           ├── ucrt\              ← CRT headers
│   │           ├── stdlib\            ← STL headers
│   │           └── windows\            ← Win32 headers
│   │
│   ├── winsdk\                        ← Windows SDK (subset for native)
│   │   ├── Include\                   ← SDK headers
│   │   │   └── 10.0.22621.0\         ← Windows 10 headers
│   │   │       ├── um\               ← User-mode headers
│   │   │       └── shared\            ← Shared headers
│   │   └── Lib\                       ← SDK import libraries
│   │       └── 10.0.22621.0\         ← Windows 10 libs
│   │           ├── x64\
│   │           ├── arm64\
│   │           └── x86\
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

### 5.1 Lock File Generation Policy

**Authority**: `toolchain.lock.json` is **not hand-authored**. It is generated exclusively by the toolchain build script at install-preparation time.

- **Single Source of Truth**: `scripts/build-toolchain.ps1` (see §9 for specification)
- **Invalid Values**: Any manually edited hash value in `toolchain.lock.json` is invalid and MUST be rejected by the Toolchain Integrity Validator.
- **Generation Time**: Hashes are computed during installer build pipeline execution, not at documentation time.

```json
{
  "syncAiVersion": "1.0.0",
  "lockedAt": "2026-03-03T05:30:00Z",
  "tools": {
    "dotnet": {
      "version": "8.0.404",
      "path": "toolchain/dotnet/dotnet.exe",
      "sha256": "GENERATED_BY_BUILD_SCRIPT"
    },
    "msbuild": {
      "version": "17.11.3",
      "path": "toolchain/msbuild/MSBuild/Current/Bin/MSBuild.exe",
      "sha256": "GENERATED_BY_BUILD_SCRIPT"
    },
    "dotnetEf": {
      "version": "8.0.11",
      "path": "toolchain/dotnet-tools/dotnet-ef.exe",
      "sha256": "GENERATED_BY_BUILD_SCRIPT"
    },
    "signtool": {
      "version": "10.0.22621.3235",
      "path": "toolchain/winsdk/bin/10.0.22621.0/x64/signtool.exe",
      "sha256": "GENERATED_BY_BUILD_SCRIPT"
    },
    "makeappx": {
      "version": "10.0.22621.3235",
      "path": "toolchain/winsdk/bin/10.0.22621.0/x64/makeappx.exe",
      "sha256": "GENERATED_BY_BUILD_SCRIPT"
    },
    "makepri": {
      "version": "10.0.22621.3235",
      "path": "toolchain/winsdk/bin/10.0.22621.0/x64/makepri.exe",
      "sha256": "GENERATED_BY_BUILD_SCRIPT"
    },
    "nuget": {
      "version": "6.11.0",
      "path": "toolchain/nuget/nuget.exe",
      "sha256": "GENERATED_BY_BUILD_SCRIPT"
    },
    "vcBuildTools": {
      "version": "14.41.34120",
      "path": "toolchain/vc++/VC/Tools/MSVC/14.41.34120/bin/Hostx64/x64/cl.exe",
      "sha256": "GENERATED_BY_BUILD_SCRIPT"
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

> **NOTE**: The `sha256` values above are marked as `GENERATED_BY_BUILD_SCRIPT` to indicate they are placeholders. Real SHA-256 hashes are computed and injected by `scripts/build-toolchain.ps1` at release time.

---

## 6. SDK Acquisition Strategy

### Installer-Time Bundling

The Sync AI installer (`SyncAI-Setup.exe`) acquires all toolchain components at install time using one of two strategies:

| Strategy            | When Used                     | Method                                                      |
| ------------------- | ----------------------------- | ----------------------------------------------------------- |
| **Offline Bundle**  | Installer includes everything | Pre-packed inside installer MSI/MSIX                        |
| **Online Download** | Installer is a bootstrapper   | Downloads each component from official sources during setup |

**Decision**: Offline bundle. The full installer includes all toolchain components pre-packed. This ensures zero internet dependency post-installation.

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

| Component                                 | License                                     | Redistribution Allowed      | Condition                                                               |
| ----------------------------------------- | ------------------------------------------- | --------------------------- | ----------------------------------------------------------------------- |
| `.NET 8 SDK`                              | MIT + Microsoft .NET Library License        | ✅ Yes                      | Include attribution in installer                                        |
| `MSBuild` (Build Tools)                   | Visual Studio EULA                          | ✅ Yes (subset)             | May redistribute build tools subset                                     |
| `Windows SDK` (`signtool`, `makeappx`)    | Windows SDK EULA                            | ✅ Yes (listed tools)       | Must be distributed as-is                                               |
| `VC++ Build Tools`                        | Visual Studio EULA                          | ✅ Yes (subset)             | May redistribute VC++ build tools                                       |
| `EF Core CLI` (`dotnet-ef`)               | MIT                                         | ✅ Yes                      | No conditions                                                           |
| `NuGet packages`                          | Each package's own license                  | ✅ Yes (all MIT/Apache 2.0) | Include license files                                                   |
| `CommunityToolkit.Mvvm`                   | MIT                                         | ✅ Yes                      | No conditions                                                           |
| `CommunityToolkit.WinUI`                  | MIT                                         | ✅ Yes                      | No conditions                                                           |
| `Windows App SDK Runtime (WinAppRuntime)` | Windows App SDK EULA (MIT for OSS portions) | ✅ Yes (self-contained)     | Must set `WindowsAppSdkSelfContained=true`; runtime bundled inside MSIX |
| `Microsoft.Windows.SDK.BuildTools` NuGet  | Windows SDK EULA                            | ✅ Yes (headers/libs)       | **Redistribution analysis required** — see below                        |

### Microsoft.Windows.SDK.BuildTools Redistribution Analysis

The `Microsoft.Windows.SDK.BuildTools` NuGet package (version `10.0.22621.756`) contains:

- **Windows SDK headers** (`.h` files in `Include/` directory)
- **Import libraries** (`.lib` files in `Lib/` directory)
- **WinMD metadata** (`.winmd` files)

**Redistribution Terms**:

1. **Headers and Import Libraries**: MAY be redistributed as part of a bundled toolchain under the Windows SDK EULA, provided they are used solely for build purposes (compilation and linking).
2. **WinMD Files**: MAY be redistributed as runtime dependencies for WinUI 3 applications.
3. **Restriction**: The headers and libraries MUST NOT be extracted and installed system-wide. They must remain in the isolated toolchain folder (`{SyncAIRoot}\toolchain\`) and only be accessible via the `INCLUDE` and `LIB` environment variables during build time.

**Compliance Implementation**:

- Headers are stored at: `{SyncAIRoot}\toolchain\winsdk\Include\`
- Libraries are stored at: `{SyncAIRoot}\toolchain\winsdk\Lib\`
- Environment isolation prevents system-wide registration ([TOOLCHAIN_ISOLATION.md](./TOOLCHAIN_ISOLATION.md) §2)
- This complies with Windows SDK EULA redistribution terms for development tools

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

### Update Rules

| Rule                        | Description                                                                         |
| --------------------------- | ----------------------------------------------------------------------------------- |
| **No auto-update**          | Toolchain is never updated silently; only via full Sync AI installer update         |
| **Major updates only**      | Toolchain versions are updated only with major Sync AI releases                     |
| **Backwards compatibility** | Older projects include `toolchain.lock.json` — build system uses the locked version |
| **User notification**       | If a toolchain update is available, user sees a notification in Sync AI settings    |
| **Version enforcement**     | Startup check blocks operation if installed toolchain version differs from expected | Block operation if toolchain version mismatches installer version         |

### Version Enforcement Mechanism

**Toolchain Version Manifest**: `{SyncAIRoot}\toolchain\version.manifest`

This file is generated by the installer and contains the expected toolchain version:

```json
{
  "installerVersion": "1.0.0",
  "expectedToolchainVersion": "1.0.0",
  "installedAt": "2026-03-03T05:30:00Z",
  "installerHash": "sha256-of-installer-exe"
}
```

**Startup Validation** (`ToolchainVersionValidator.cs`):

```csharp
public class ToolchainVersionValidator
{
    public ValidationResult ValidateToolchainVersion()
    {
        var manifestPath = Path.Combine(_syncAiRoot, "toolchain", "version.manifest");
        
        if (!File.Exists(manifestPath))
        {
            return ValidationResult.Failed(
                "TOOLCHAIN_VERSION_MISSING",
                "Toolchain version manifest not found. Sync AI installation may be incomplete.");
        }
        
        var manifest = JsonSerializer.Deserialize<ToolchainVersionManifest>(File.ReadAllText(manifestPath));
        
        // Compare installed toolchain version against expected version
        if (manifest.ExpectedToolchainVersion != CurrentToolchainVersion)
        {
            return ValidationResult.Failed(
                "TOOLCHAIN_VERSION_MISMATCH",
                $"Toolchain version mismatch. Expected {manifest.ExpectedToolchainVersion}, found {CurrentToolchainVersion}. " +
                $"Please reinstall Sync AI to restore toolchain integrity.");
        }
        
        // Verify installer hash matches (detects tampering)
        var installerHash = ComputeSha256(Path.Combine(_syncAiRoot, "SyncAI-Setup.exe"));
        if (installerHash != manifest.InstallerHash)
        {
            return ValidationResult.Failed(
                "INSTALLER_TAMPERED",
                "Installer hash mismatch. Sync AI installation may have been modified.");
        }
        
        return ValidationResult.Success();
    }
}
```

**Enforcement Behavior**:

- **On Startup**: Validator runs before any build operations
- **If Validation Fails**: 
  - Show blocking error dialog: "Sync AI Toolchain Integrity Violation"
  - Display specific error (version mismatch, missing files, tampering detected)
  - Provide "Reinstall Now" button that downloads latest installer
  - Block all generation and build operations until reinstalled
- **If Validation Passes**: Normal operation proceeds

> **INVARIANT**: The toolchain version check is MANDATORY and CANNOT be bypassed. This prevents users from manually modifying toolchain components and introducing non-deterministic build behavior.

### Version Bump Process

When upgrading the toolchain (e.g., .NET 8 → .NET 9 in a future major release):

```text
1. Update version numbers in this document
2. Rebuild offline installer with new toolchain
3. Update SHA-256 hashes in toolchain.lock reference
4. Update compatibility test matrix
5. Release as new major version of Sync AI
```

### 9.1 Toolchain Build Script

**Script Path**: `scripts/build-toolchain.ps1` (relative to repository root)

**Purpose**: This script is the single source of truth for generating `toolchain.lock.json`. It is executed at installer build time, not at runtime.

**Required Steps**:

1. **Download Components**: Download each component from the official source URL listed in §2.
2. **Verify Authenticode Signature**: Verify the downloaded binary's Authenticode signature against Microsoft's certificate chain using `Get-AuthenticodeSignature`.
3. **Compute SHA-256 Hashes**: Compute SHA-256 of each binary with `Get-FileHash -Algorithm SHA256`.
4. **Write Lock File**: Write the resulting hashes, versions, and paths into `toolchain.lock.json`.
5. **Validate Layout**: Validate the bundled folder layout matches §3 exactly.
6. **Fail on Error**: Fail with exit code 1 if any step fails.

**Output**: The script generates `toolchain.lock.json` with actual SHA-256 hash values replacing the `GENERATED_BY_BUILD_SCRIPT` placeholders.

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

5. Verify Reproducibility (REQUIRED for all builds)
   └── Rebuild with same inputs
   └── Compare output hashes
   └── FAIL if hashes differ
```

### Provenance Metadata Schema

#### build_inputs.json Schema

Captures the complete input state before a build:

```json
{
  "schemaVersion": "1.0",
  "buildId": "uuid",
  "timestamp": "ISO8601",
  "projectId": "uuid",
  "specHash": "sha256 of spec.json",
  "assetHashes": {
    "{relative/path/to/asset}": "sha256"
  },
  "templateHash": "sha256 of MinimalKernelBootstrap/",
  "toolchainLockHash": "sha256 of toolchain.lock.json"
}
```

#### build_outputs.json Schema

Captures all output artifacts after a successful build:

```json
{
  "schemaVersion": "1.0",
  "buildId": "uuid (matches build_inputs.json)",
  "timestamp": "ISO8601",
  "projectId": "uuid",
  "inputHash": "sha256 of build_inputs.json",
  "toolchainLockHash": "sha256 of toolchain.lock.json",
  "outputs": [
    {
      "path": "relative path from workspace root",
      "sha256": "...",
      "sizeBytes": 123456,
      "artifactType": "exe | dll | msix | msixbundle | pdb | pri"
    }
  ],
  "buildDurationMs": 12345,
  "exitCode": 0
}
```

### Generation Contract

| File                | Generated By    | When                                      | Storage Path                          |
| ------------------- | --------------- | ----------------------------------------- | ------------------------------------- |
| `build_inputs.json` | Build Executor  | Before first tool invocation in a build   | `{workspace}\{projectId}\build_inputs.json` |
| `build_outputs.json` | Build Executor | After successful build, before packaging | `{workspace}\{projectId}\build_outputs.json` |

### Consumers

| File                | Consumer                  | Usage                                                                                   |
| ------------------- | ------------------------- | --------------------------------------------------------------------------------------- |
| `build_inputs.json` | Reproducibility Verifier  | Step 5 of Build Reproducibility Pipeline (this section)                                 |
| `build_inputs.json` | Packaging Agent           | Populates provenance metadata in MSIX manifest                                          |
| `build_outputs.json` | MSIX Automation Pipeline | Step 5 of [WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md](./WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md) §4.1 — Artifact Hash Verification |

> **NOTE**: See [WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md](./WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md) §4.1 for the hash verification step that uses `build_outputs.json`.

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
