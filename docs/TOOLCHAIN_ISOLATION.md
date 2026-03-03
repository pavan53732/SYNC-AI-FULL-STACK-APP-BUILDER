# TOOLCHAIN ISOLATION

> **Sync AI Toolchain Isolation Architecture: How Bundled Tools Are Completely Isolated from the Host System**
>
> **Why This Exists**: Sync AI bundles its own complete toolchain (.NET SDK, MSBuild, Windows SDK tools). This document defines exactly how those bundled tools are invoked in a way that is **completely isolated** from anything installed on the user's machine — ensuring deterministic, reproducible builds on any Windows machine regardless of what development tools the user has or hasn't installed.
>
> **Related Core Documents:**
>
> - [TOOLCHAIN_MANIFEST.md](./TOOLCHAIN_MANIFEST.md) — Pinned tool versions and folder layout
> - [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — Layer 5: Build Execution Sandbox
> - [PROJECT_ARCHETYPE_RESOLUTION.md](./PROJECT_ARCHETYPE_RESOLUTION.md) — Framework selection affecting toolchain
> - [REPAIR_PATTERNS.md](./REPAIR_PATTERNS.md) — Build error repair using isolated tools

---

## Table of Contents

1. [Isolation Mandate](#1-isolation-mandate)
2. [Environment Variable Override Model](#2-environment-variable-override-model)
3. [PATH Isolation](#3-path-isolation)
4. [MSBuild Isolation](#4-msbuild-isolation)
5. [NuGet Isolation](#5-nuget-isolation)
5.1. [Native Toolchain (MSVC) Isolation](#51-native-toolchain-msvc-isolation)
6. [Process Launch Contract](#6-process-launch-contract)
7. [Registry Isolation](#7-registry-isolation)
8. [Workspace Isolation](#8-workspace-isolation)
9. [Coexistence Rules](#9-coexistence-rules)
10. [Isolation Verification](#10-isolation-verification)

---

## 1. Isolation Mandate

> **ABSOLUTE INVARIANT**: Every tool invocation by Sync AI's Build Executor must operate in a fully controlled environment. No build operation may succeed or fail based on what is installed on the user's machine outside of Sync AI's toolchain directory.

### The Core Problem Without Isolation

Without isolation, the following disasters can happen:

| Scenario                                         | What Goes Wrong                                          |
| ------------------------------------------------ | -------------------------------------------------------- |
| User has .NET 6 SDK on PATH                      | `dotnet build` uses .NET 6, not Sync AI's bundled .NET 8 |
| User has VS 2019 MSBuild registered              | WinUI 3 XAML compiler not found (requires MSBuild 17+)   |
| User's `NUGET_PACKAGES` env var points elsewhere | NuGet restores wrong package versions                    |
| User's global `NuGet.config` has a private feed  | Build fails with authentication errors                   |
| User's `DOTNET_ROOT` points to a different SDK   | Wrong runtime used                                       |
| Two Sync AI projects build simultaneously        | MSBuild uses shared temp folders, corrupting builds      |

Isolation prevents all of these.

---

## 2. Environment Variable Override Model

Before launching any build tool process, the Build Executor constructs a **fully controlled environment block** that overrides all relevant environment variables. The host process's environment is not inherited for variables in the override list.

### Controlled Environment Variables

```csharp
// Build Executor: ConstructIsolatedEnvironment()
var isolatedEnv = new Dictionary<string, string>
{
    // ── .NET SDK Isolation ────────────────────────────────────────────────
    ["DOTNET_ROOT"]          = @"{SyncAIRoot}\toolchain\dotnet",
    ["DOTNET_MULTILEVEL_LOOKUP"] = "0",   // ← CRITICAL: prevents fallback to system .NET
    ["DOTNET_NOLOGO"]        = "1",
    ["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1",
    ["DOTNET_SKIP_FIRST_TIME_EXPERIENCE"] = "1",

    // ── MSBuild Isolation ──────────────────────────────────────────────────
    ["MSBUILD_EXE_PATH"]     = @"{SyncAIRoot}\toolchain\msbuild\MSBuild\Current\Bin\MSBuild.exe",
    ["MSBuildSDKsPath"]      = @"{SyncAIRoot}\toolchain\dotnet\sdk\8.0.404\Sdks",
    ["VSINSTALLDIR"]         = @"{SyncAIRoot}\toolchain\msbuild",   // ← prevents VS detection
    ["VisualStudioVersion"]  = "17.0",

    // ── NuGet Isolation ───────────────────────────────────────────────────
    ["NUGET_PACKAGES"]       = @"{SyncAIRoot}\toolchain\nuget-cache",
    ["NUGET_HTTP_CACHE_PATH"] = @"{workspace}\{projectId}\.nuget\http-cache",
    ["NUGET_PLUGINS_CACHE_PATH"] = @"{workspace}\{projectId}\.nuget\plugins-cache",
    ["NUGET_FALLBACK_PACKAGES"] = @"{SyncAIRoot}\toolchain\nuget-cache",

    // ── Workspace Isolation ───────────────────────────────────────
    ["TEMP"]                 = @"{workspace}\{projectId}\tmp",
    ["TMP"]                  = @"{workspace}\{projectId}\tmp",
    ["LOCALAPPDATA"]         = @"{workspace}\{projectId}\.localappdata",
    // ── AppData/ProgramData Isolation ─────────────────────────────
    // Prevents MSBuild and .NET tooling from reading/writing the user's real AppData.
    // Without these overrides, NuGet plugin caches, MSBuild extension paths, and
    // dotnet tool manifests from the host can leak into the isolated build environment.
    ["APPDATA"]              = @"{workspace}\{projectId}\.appdata",
    ["PROGRAMDATA"]          = @"{workspace}\{projectId}\.programdata",

    // ── VC++ Compiler Isolation (CRITICAL for cl.exe) ───────────────────────
    // cl.exe does NOT use PATH to locate headers or libraries. It reads INCLUDE,
    // LIB, and LIBPATH exclusively. Without these, cl.exe falls back to system-
    // registered SDK paths (via registry), violating the isolation invariant.
    // DOTNET_MULTILEVEL_LOOKUP=0 alone does NOT prevent this fallback for native compilation.
    ["INCLUDE"]              = @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\include;{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\atlmfc\include;{SyncAIRoot}\toolchain\winsdk\Include\10.0.22621.0\ucrt;{SyncAIRoot}\toolchain\winsdk\Include\10.0.22621.0\shared;{SyncAIRoot}\toolchain\winsdk\Include\10.0.22621.0\um;{SyncAIRoot}\toolchain\winsdk\Include\10.0.22621.0\winrt",
    ["LIB"]                  = @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\lib\x64;{SyncAIRoot}\toolchain\winsdk\Lib\10.0.22621.0\ucrt\x64;{SyncAIRoot}\toolchain\winsdk\Lib\10.0.22621.0\um\x64",
    ["LIBPATH"]              = @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\lib\x64;{SyncAIRoot}\toolchain\dotnet\shared\Microsoft.NETCore.App\8.0.11",
    ["WindowsSdkDir"]        = @"{SyncAIRoot}\toolchain\winsdk\",
    ["WindowsSdkVersion"]    = "10.0.22621.0",
    ["VCToolsInstallDir"]    = @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\",

    // ── PATH Isolation (see Section 3) ────────────────────────────────────
    ["PATH"]                 = BuildIsolatedPath(),

    // ── Telemetry + Noise Suppression ──────────────────────────────────────
    ["DOTNET_CLI_UI_LANGUAGE"] = "en-US",
    ["MSBUILDDISABLENODEREUSE"] = "1",    // ← prevents MSBuild node-reuse across projects
    ["MSBUILDNOINPROCNODE"]  = "1",
};
```

### DOTNET_MULTILEVEL_LOOKUP = 0 (Critical)

This is the single most important variable. Setting it to `0` tells the .NET host:

> "Do NOT look in `Program Files\dotnet` or any other system location for SDKs. Only use what is in `DOTNET_ROOT`."

Without this, the user's system .NET installation can override Sync AI's bundled SDK.

---

## 3. PATH Isolation

The `PATH` environment variable for child build processes is constructed from scratch. **The host machine's PATH is not inherited.**

```csharp
private static string BuildIsolatedPath()
{
    // Only these directories appear in PATH for build processes
    var paths = new[]
    {
        @"{SyncAIRoot}\toolchain\dotnet",              // dotnet.exe
        @"{SyncAIRoot}\toolchain\msbuild\MSBuild\Current\Bin", // MSBuild.exe
        @"{SyncAIRoot}\toolchain\winsdk\bin\10.0.22621.0\x64", // signtool, makeappx
        @"{SyncAIRoot}\toolchain\nuget",               // nuget.exe
        @"{SyncAIRoot}\toolchain\dotnet-tools",        // dotnet-ef.exe
        @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64", // VC++ x64 compiler tools
        @"C:\Windows\System32",                        // Required for basic Win32 APIs
        @"C:\Windows",                                 // Required for basic Win32 APIs
    };
    return string.Join(";", paths);
}
```

### Why `C:\Windows\System32` Is Included

MSBuild and the .NET runtime require core Windows DLLs (`kernel32.dll`, `ntdll.dll`, etc.) which are always at `System32`. These are OS components, not user-installed tools, and are safe to include.

### What Is Excluded From PATH

| Excluded                                     | Reason                                  |
| -------------------------------------------- | --------------------------------------- |
| `C:\Program Files\dotnet`                    | User's system .NET — must not interfere |
| `C:\Program Files (x86)\MSBuild`             | Old MSBuild versions                    |
| `C:\Program Files\Microsoft Visual Studio\*` | User's VS installation                  |
| `%USERPROFILE%\.dotnet\tools`                | User's global .NET tools                |
| All user-defined PATH entries                | Non-deterministic — excluded by default |

---

## 4. MSBuild Isolation

### Preventing MSBuild from Finding Visual Studio

MSBuild performs **Visual Studio detection** by looking for VS installations in the registry and known file system paths. If it finds the user's VS installation, it may prefer that over Sync AI's toolchain.

To prevent this, the following MSBuild properties are set on every build invocation:

```bash
# MSBuild invocation template (executed by Build Executor)
{SyncAIRoot}\toolchain\msbuild\MSBuild\Current\Bin\MSBuild.exe \
    {projectFile} \
    /t:Restore;Build \
    /p:Configuration=Release \
    /p:Platform=x64 \
    /p:RestorePackagesPath={SyncAIRoot}\toolchain\nuget-cache \
    /p:MSBuildSDKsPath={SyncAIRoot}\toolchain\dotnet\sdk\8.0.404\Sdks \
    /p:NuGetPackageRoot={SyncAIRoot}\toolchain\nuget-cache \
    /p:DirectoryBuildPropsPath=NUL \
    /p:DirectoryBuildTargetsPath=NUL \
    /nodeReuse:false \             ← prevents node reuse across projects
    /maxcpucount:1 \               ← single-threaded for determinism
    /nologo \
    /verbosity:minimal \
    /binaryLogger:{workspace}\{projectId}\logs\msbuild.binlog
```

### Directory.Build.props Mitigation (CRITICAL)

The properties `/p:DirectoryBuildPropsPath=NUL` and `/p:DirectoryBuildTargetsPath=NUL` prevent MSBuild from importing user-defined `Directory.Build.props` and `Directory.Build.targets` files from parent directories.

**Why this is required**: MSBuild automatically imports these files from all parent directories up to the drive root, regardless of environment isolation. If a user has `C:\Users\{user}\Directory.Build.props`, it would be imported into every Sync AI build, potentially breaking builds or introducing unwanted behavior.

By setting these properties to `NUL`, we explicitly tell MSBuild to skip importing these files, ensuring complete build isolation.

### MSBUILDDISABLENODEREUSE

Setting `MSBUILDDISABLENODEREUSE=1` prevents MSBuild from keeping worker nodes alive between builds. This is essential because:

1. If a previous build used a different `MSBuildSDKsPath`, lingering nodes may use stale SDK resolution
2. Simultaneous builds of different projects won't share (and corrupt) MSBuild state

### Binary Logger

Every build produces a `.binlog` file at `{workspace}\{projectId}\logs\msbuild.binlog`. This is consumed by:

- The Fix Agent (structured error parsing — more reliable than stdout parsing)
- The Diagnostic System (for error reporting and user-facing messages)

---

## 5. NuGet Isolation

### The Offline-First NuGet Cache

All NuGet packages are pre-populated in `{SyncAIRoot}\toolchain\nuget-cache\` at install time. Builds use this cache as the **only** package source.

```xml
<!-- Generated NuGet.config per workspace — overrides all user NuGet configs -->
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <!-- ONLY source: the bundled offline cache -->
    <clear/>
    <add key="SyncAI-Local-Cache"
         value="{SyncAIRoot}\toolchain\nuget-cache"
         protocolVersion="3"/>
  </packageSources>
  <config>
    <add key="globalPackagesFolder"
         value="{SyncAIRoot}\toolchain\nuget-cache"/>
    <add key="repositoryPath"
         value="{workspace}\{projectId}\packages"/>
  </config>
  <packageRestore>
    <add key="enabled" value="True"/>
    <add key="automatic" value="True"/>
  </packageRestore>
</configuration>
```

This `NuGet.config` is placed at the **solution root** of every generated project, overriding any user-level or machine-level NuGet configuration.

### Why `<clear/>` Is Critical

The `<clear/>` directive removes **all** default and user-configured package sources (including `nuget.org`) before adding the local cache. Without `<clear/>`, NuGet might still attempt to reach `nuget.org` for missing packages.

### Offline Package Cache Population

At install time, Sync AI's installer runs a package hydration step:

```powershell
# Installer step: populate offline NuGet cache
& "{SyncAIRoot}\toolchain\dotnet\dotnet.exe" nuget add source `
    https://api.nuget.org/v3/index.json `
    --name nuget-org

# Restore a reference project to hydrate all dependencies
& "{SyncAIRoot}\toolchain\dotnet\dotnet.exe" restore `
    "{InstallerRoot}\seed-project\SeedProject.csproj" `
    --packages "{SyncAIRoot}\toolchain\nuget-cache"

# Lock down to offline after hydration
# (NuGet.config in workspace projects will have <clear/> + local only)
```

---

## 5.1 Native Toolchain (MSVC) Isolation

> **CRITICAL**: Native C++ builds (Win32, WinRT, Hybrid) require special isolation beyond .NET builds. The MSVC compiler does NOT use PATH for header/library discovery — it relies exclusively on INCLUDE, LIB, and LIBPATH environment variables, plus registry-based SDK detection.

### MSVC Environment Setup

For native builds, the Build Executor invokes `vcvarsall.bat` equivalent logic manually:

```csharp
// Native Build Executor: SetupNativeEnvironment()
var nativeEnv = new Dictionary<string, string>
{
    // VC++ Tools
    ["VCToolsInstallDir"] = @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\",
    ["VCToolsVersion"] = "14.41.34120",
    
    // Windows SDK
    ["WindowsSdkDir"] = @"{SyncAIRoot}\toolchain\winsdk\",
    ["WindowsSdkVersion"] = "10.0.22621.0",
    ["WindowsSDKVersion"] = "10.0.22621.0",
    
    // Include paths (CRITICAL - cl.exe reads this exclusively)
    ["INCLUDE"] = String.Join(";",
        @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\include",
        @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\atlmfc\include",
        @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\crt\src",
        @"{SyncAIRoot}\toolchain\winsdk\Include\10.0.22621.0\ucrt",
        @"{SyncAIRoot}\toolchain\winsdk\Include\10.0.22621.0\shared",
        @"{SyncAIRoot}\toolchain\winsdk\Include\10.0.22621.0\um",
        @"{SyncAIRoot}\toolchain\winsdk\Include\10.0.22621.0\winrt"),
    
    // Library paths (CRITICAL - link.exe reads this exclusively)
    ["LIB"] = String.Join(";",
        @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\lib\x64",
        @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\lib\arm64",
        @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\atlmfc\lib\x64",
        @"{SyncAIRoot}\toolchain\winsdk\Lib\10.0.22621.0\ucrt\x64",
        @"{SyncAIRoot}\toolchain\winsdk\Lib\10.0.22621.0\um\x64",
        @"{SyncAIRoot}\toolchain\winsdk\Lib\10.0.22621.0\winrt\x64"),
    
    // Library manager paths
    ["LIBPATH"] = String.Join(";",
        @"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\lib\x64",
        @"{SyncAIRoot}\toolchain\dotnet\shared\Microsoft.NETCore.App\8.0.11"),
    
    // Disable incremental linking for determinism
    ["CL"] = "/Zi /Gy /Gw /Brepro",
    ["LINK"] = "/INCREMENTAL:NO /DEBUG:NONE",
};
```

### MSVC Compiler Invocation

```bash
# Native C++ build invocation (Win32/WinRT/Hybrid)
{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64\cl.exe \
    /c \
    /Fo"{workspace}\{projectId}\build\{filename}.obj" \
    /Zi \
    /Gy \
    /Gw \
    /Brepro \
    /W3 \
    /permissive- \
    /std:c++20 \
    "{sourcefile}.cpp"

# Native linker invocation
{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64\link.exe \
    /OUT:"{workspace}\{projectId}\build\{appname}.exe" \
    /LIBPATH:"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\lib\x64" \
    /LIBPATH:"{SyncAIRoot}\toolchain\winsdk\Lib\10.0.22621.0\um\x64" \
    /INCREMENTAL:NO \
    /DEBUG:NONE \
    {objfiles}
```

### Deterministic Native Build Flags

| Flag | Purpose |
| ---- | ------- |
| `/Brepro` | Produce reproducible binaries (timestamp neutral) |
| `/Zi` | Full debug information (not /Z7 which embeds in OBJ) |
| `/Gy` | Function-level linking (enables /Gw) |
| `/Gw` | Whole program optimization across translation units |
| `/INCREMENTAL:NO` | Disable incremental linking for clean builds |

### Resource Compiler Isolation

```bash
# RC.exe for native resource compilation
{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\bin\Hostx64\x64\rc.exe \
    /r \
    /fo"{output}.res" \
    "{input}.rc"
```

### Registry Isolation for Native

The MSVC compiler searches the Windows Registry for SDK locations. We must block this:

```csharp
// Registry isolation is handled at process launch:
// - CreateProcess() with restricted registry view
// - Or redirect HKLM/HKCU to empty hive
// See Section 7 for full registry isolation details.
```

---

## 6. Process Launch Contract

All processes spawned by the Build Executor must follow this contract:

```csharp
// Build Executor: LaunchToolProcess()
public static async Task<BuildResult> LaunchToolProcess(
    string executablePath,
    string arguments,
    string workingDirectory,
    string projectId)
{
    var psi = new ProcessStartInfo
    {
        FileName = executablePath,
        Arguments = arguments,
        WorkingDirectory = workingDirectory,
        UseShellExecute = false,       // ← MUST be false for env override
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        CreateNoWindow = true,
    };

    // Apply isolated environment — overwrite, do NOT inherit
    psi.Environment.Clear();   // ← clears inherited environment
    foreach (var (key, value) in ConstructIsolatedEnvironment(projectId))
        psi.Environment[key] = value;

    // Job Object enforcement (from EXECUTION_ENVIRONMENT.md §4 — Process Isolation)
    // FAIL-CLOSED: If Job Object attachment fails after start, terminate immediately
    using var process = new Process { StartInfo = psi, EnableRaisingEvents = true };

    // Step 1: Start the process
    process.Start();
    ProcessTracker.Add(process);

    // Step 2: Attempt Job Object attachment after startup
    if (!AttachToJobObject(process))
    {
        // FAIL-CLOSED: Terminate immediately if attachment fails
        if (!process.HasExited)
        {
            process.Kill(entireProcessTree: true);
        }
        throw new IsolationException(
            "Job Object attachment failed after process start. " +
            "Process terminated immediately. " +
            "Capability-requiring runs MUST have Job Object isolation.");
    }

    var stdout = await process.StandardOutput.ReadToEndAsync();
    var stderr = await process.StandardError.ReadToEndAsync();
    await process.WaitForExitAsync();

    return new BuildResult
    {
        ExitCode = process.ExitCode,
        Stdout = stdout,
        Stderr = stderr,
        Success = process.ExitCode == 0
    };
}
```

### Critical: `psi.Environment.Clear()`

This call removes **all inherited environment variables** from the parent process before applying the controlled set. This is the fundamental mechanism that achieves isolation.

Without `Clear()`, all of the user's environment variables would be inherited, including `PATH`, `DOTNET_ROOT`, `NUGET_PACKAGES`, etc.

---

## 7. Registry Isolation

MSBuild and the .NET host occasionally query the Windows Registry for SDK detection. The following registry paths may be consulted:

| Registry Path                                  | Queried By                | Mitigation                                                 |
| ---------------------------------------------- | ------------------------- | ---------------------------------------------------------- |
| `HKLM\SOFTWARE\dotnet\Setup\InstalledVersions` | .NET host                 | Overridden by `DOTNET_ROOT` + `DOTNET_MULTILEVEL_LOOKUP=0` |
| `HKLM\SOFTWARE\Microsoft\VisualStudio\*`       | MSBuild VS detection      | Overridden by `VSINSTALLDIR` env var                       |
| `HKLM\SOFTWARE\Microsoft\MSBuild\*`            | MSBuild version detection | Overridden by direct path invocation                       |
| `HKCU\SOFTWARE\NuGet\*`                        | NuGet client              | Overridden by workspace-level `NuGet.config`               |

> **Phase 1 Approach**: Environment variable overrides are sufficient to prevent registry-based tool detection for the Phase 1 tool set. Full registry virtualization (using mechanisms like `RegCreateKeyEx` redirection) is a Phase 2 consideration for extreme isolation scenarios.

---

## 8. Workspace Isolation

Every project generation session runs in its own completely isolated workspace directory:

```text
{SyncAIRoot}\workspace\
└── {ProjectId}\                    ← UUID per session
    ├── src\                        ← Generated source code
    │   ├── {AppName}.sln
    │   ├── {AppName}.App\
    │   ├── {AppName}.Core\
    │   └── {AppName}.Data\
    ├── build\                      ← MSBuild output (bin/ obj/)
    ├── packages\                   ← NuGet package restore directory
    ├── tmp\                        ← TEMP/TMP override for this project
    ├── .localappdata\              ← LOCALAPPDATA override for this project
    ├── .nuget\                     ← NuGet HTTP and plugin caches
    │   ├── http-cache\
    │   └── plugins-cache\
    ├── logs\                       ← Build logs
    │   ├── msbuild.binlog
    │   ├── dotnet-ef.log
    │   └── ai-agent.log
    ├── snapshots\                  ← Runtime Safety Kernel snapshots
    ├── NuGet.config                ← Workspace-level NuGet isolation config
    └── toolchain.lock.json         ← Exact tool versions used for this project
```

### No Cross-Project Contamination

Two projects building simultaneously share:

- `{SyncAIRoot}\toolchain\*` (read-only — tools only)
- `{SyncAIRoot}\toolchain\nuget-cache\` (read-only — package cache only)

They do NOT share:

- `workspace\{projectId}\*` (completely private per session)
- Any temp directories
- Any MSBuild node processes (`/nodeReuse:false`)

---

## 9. Coexistence Rules

Sync AI's isolation model is designed to coexist safely with user-installed development tools:

| User Has Installed            | Impact on Sync AI                             | Impact on User's Tools           |
| ----------------------------- | --------------------------------------------- | -------------------------------- |
| Visual Studio 2022            | None                                          | None (Sync AI uses separate env) |
| .NET 8 SDK (system)           | None (Sync AI uses its own)                   | None                             |
| .NET 6 SDK (system)           | None                                          | None                             |
| Another version of MSBuild    | None                                          | None                             |
| A custom NuGet source         | None (Sync AI uses `<clear/>`)                | None                             |
| `DOTNET_ROOT` set system-wide | None (`DOTNET_MULTILEVEL_LOOKUP=0` overrides) | Not affected                     |

> **INVARIANT**: Sync AI's builds must never modify the user's system PATH, registry, or globally installed tools. Sync AI is a guest on the user's machine and must not alter the host environment.

---

## 10. Isolation Verification

The **Toolchain Isolation Verifier** runs as part of Sync AI's diagnostic suite to confirm isolation is functioning correctly.

### Verification Test Suite

```csharp
// ToolchainIsolationVerifier.RunAllChecks()

// Test 1: dotnet.exe version matches bundled version
var dotnetVersion = await LaunchToolProcess(
    @"{SyncAIRoot}\toolchain\dotnet\dotnet.exe",
    "--version", workDir, testProjectId);
Assert(dotnetVersion.Stdout.Trim() == "8.0.404");

// Test 2: MSBuild version matches bundled version
var msbuildVersion = await LaunchToolProcess(
    @"{SyncAIRoot}\toolchain\msbuild\MSBuild\Current\Bin\MSBuild.exe",
    "-version", workDir, testProjectId);
Assert(msbuildVersion.Stdout.Contains("17.11"));

// Test 3: No user NuGet sources visible
var nugetSources = await LaunchToolProcess(
    @"{SyncAIRoot}\toolchain\dotnet\dotnet.exe",
    "nuget list source", workDir, testProjectId);
Assert(nugetSources.Stdout.Contains("SyncAI-Local-Cache"));
Assert(!nugetSources.Stdout.Contains("nuget.org")); // ← must NOT be visible

// Test 4: PATH does not contain system dotnet
var pathValue = GetChildProcessEnvVar("PATH", testProjectId);
Assert(!pathValue.Contains(@"C:\Program Files\dotnet"));
Assert(pathValue.Contains(@"{SyncAIRoot}\toolchain\dotnet"));

// Test 5: DOTNET_MULTILEVEL_LOOKUP is 0
var multilookup = GetChildProcessEnvVar("DOTNET_MULTILEVEL_LOOKUP", testProjectId);
Assert(multilookup == "0");

// Test 6: INCLUDE environment variable contains bundled VC++ headers
var includeValue = GetChildProcessEnvVar("INCLUDE", testProjectId);
Assert(includeValue.Contains(@"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\include"));
Assert(includeValue.Contains(@"{SyncAIRoot}\toolchain\winsdk\Include\10.0.22621.0\ucrt"));
Assert(!includeValue.Contains(@"C:\Program Files (x86)\Windows Kits\")); // ← must NOT contain system paths

// Test 7: LIB environment variable contains bundled VC++ libraries
var libValue = GetChildProcessEnvVar("LIB", testProjectId);
Assert(libValue.Contains(@"{SyncAIRoot}\toolchain\vc++\VC\Tools\MSVC\14.41.34120\lib\x64"));
Assert(libValue.Contains(@"{SyncAIRoot}\toolchain\winsdk\Lib\10.0.22621.0\ucrt\x64"));
Assert(!libValue.Contains(@"C:\Program Files (x86)\Windows Kits\")); // ← must NOT contain system paths
```

### Verification Outcomes

| Test                       | Pass       | Fail Action                       |
| -------------------------- | ---------- | --------------------------------- |
| dotnet version match       | ✅ Proceed | 🔴 Block builds + alert user      |
| MSBuild version match      | ✅ Proceed | 🔴 Block builds + alert user      |
| No external NuGet sources  | ✅ Proceed | 🔴 Block builds + alert user      |
| PATH isolation confirmed   | ✅ Proceed | 🟡 Warn + continue (non-critical) |
| DOTNET_MULTILEVEL_LOOKUP=0 | ✅ Proceed | 🔴 Block builds + alert user      |
| INCLUDE isolation          | ✅ Proceed | 🔴 Block builds + alert user      |
| LIB isolation              | ✅ Proceed | 🔴 Block builds + alert user      |

---

## Change Log

| Date       | Change                                                       |
| ---------- | ------------------------------------------------------------ |
| 2026-03-03 | Initial creation — complete toolchain isolation architecture |

---

## References

- [TOOLCHAIN_MANIFEST.md](./TOOLCHAIN_MANIFEST.md) — Bundled tool versions and folder layout
- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — Build Execution Sandbox (Layer 5)
- [REPAIR_PATTERNS.md](./REPAIR_PATTERNS.md) — Build error repair using isolated tools
- [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Runtime Safety Kernel context
