# EXECUTION ENVIRONMENT

> **The Infrastructure Layer: Sandbox, MSBuild, Job Objects, ACL Enforcement & Machine Variability**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> _The Execution Environment is managed by the Runtime Safety Kernel. It enforces boundaries for AI-generated code execution._

---

## Table of Contents

1. [Overview](#1-overview)
2. [Filesystem Sandbox](#2-filesystem-sandbox)
3. [Execution Kernel](#3-execution-kernel)
4. [Process Isolation & Job Objects](#4-process-isolation--job-objects)
5. [Security Boundaries & ACL Enforcement](#5-security-boundaries--acl-enforcement)
6. [Machine Variability Handling](#6-machine-variability-handling)
7. [Embedded Subsystems](#7-embedded-subsystems)
8. [Resource Monitoring](#8-resource-monitoring)
9. [Crash Recovery](#9-crash-recovery)

---

## 1. Overview

The Execution Environment provides the foundational infrastructure for safe, isolated, and deterministic code execution. It bridges Layer 1 (Filesystem) and Layer 2 (Execution Kernel) of the 7-layer architecture.

### Architectural Position

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 7: User Interface (WinUI 3 / XAML)                   │
├─────────────────────────────────────────────────────────────┤
│  Layer 6.5: AI Construction Engine (Primary Brain)          │
├─────────────────────────────────────────────────────────────┤
│  Layer 6.6: AI Service Layer (openai SDK)                   │
├─────────────────────────────────────────────────────────────┤
│  Layer 6: Runtime Safety Kernel                             │
├─────────────────────────────────────────────────────────────┤
│  Layer 4: Code Intelligence (Roslyn)                        │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: Patch Engine                                      │
├─────────────────────────────────────────────────────────────┤
│  Layer 2.5: Packaging & Manifest Engine                     │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Execution Kernel ← THIS SPEC                      │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: Filesystem Sandbox + SQLite Graph DB ← THIS SPEC  │
└─────────────────────────────────────────────────────────────┘
```

### Core Responsibilities

1. **Workspace Isolation**: Each project lives in an isolated sandbox
2. **Build Execution**: In-process MSBuild and NuGet operations
3. **Process Containment**: Job Objects and ACL enforcement for preview execution
4. **Environment Resilience**: Handle machine variability gracefully
5. **Resource Management**: Monitor and enforce limits

---

## 2. Filesystem Sandbox

### 2.1 Purpose

The sandbox ensures that Sync AI never accidentally modifies user files outside the project scope. It acts as a virtualized file system wrapper.

### 2.2 Workspace Structure

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

### 2.3 Security Enforcement

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

### 2.4 Banned Paths

The following paths are explicitly blocked from AI-generated patches:

```csharp
private static readonly HashSet<string> BannedPaths = new()
{
    ".git", ".vs", "bin", "obj",
    ".metadata.json"   // file, not directory
};
```

> **Note:** `*.csproj` files are intentionally excluded from `BannedPaths` — they must remain accessible for build operations.

### 2.5 Snapshot Constraints (Git-Based)

- The system maintains a **Git history** of all successful builds and significant mutations.
- Old snapshots are automatically pruned when the repository size exceeds a threshold (configurable, default 500 MB).
- Disk guard: creation blocked if available disk space < **500 MB**
- Pruning: `SnapshotPruner` uses Git commands to squash or remove old commits, preserving the last N states.
- `SnapshotId` values are Git commit hashes, enabling deterministic rollback and time-travel.

---

## 3. Execution Kernel

### 3.1 Purpose

The Execution Kernel wraps the .NET SDK tools (MSBuild, NuGet) into a managed API. It **never** launches `dotnet.exe` processes, preferring in-process libraries for speed, reliability, and structured error handling.

### 3.2 Key Responsibilities

- **MSBuild Localization**: Uses `Microsoft.Build.Locator` to find the correct SDK without user PATH configuration.
- **NuGet Cache Management**: Maintains a local package cache to avoid redownloading common packages.
- **Build Logger**: Implementation of `ILogger` that captures MSBuild events and converts them into structured definitions.

### 3.3 Implementation

```csharp
public class ExecutionKernel
{
    private readonly ILogger<ExecutionKernel> _logger;
    private readonly FileSystemSandbox _sandbox;
    private static bool _isInitialized;

    public ExecutionKernel(ILogger<ExecutionKernel> logger, FileSystemSandbox sandbox)
    {
        _logger = logger;
        _sandbox = sandbox;
        InitializeMSBuild();
    }

    /// <summary>
    /// One-time initialization of MSBuild Locator
    /// </summary>
    private static void InitializeMSBuild()
    {
        if (!_isInitialized)
        {
            // Locate the embedded SDK/MSBuild instance
            MSBuildLocator.RegisterDefaults();
            _isInitialized = true;
        }
    }

    /// <summary>
    /// Builds project in an ISOLATED workspace copy to prevent mutation race conditions
    /// </summary>
    public async Task<BuildResult> BuildAsync(
        string projectPath,
        string configuration = "Debug")
    {
        // ISOLATION STEP: Copy source to %USERPROFILE%\.syncai\Temp\{BuildId} before build
        var isolatedPath = await _sandbox.CreateIsolatedCopyAsync(projectPath);

        return await Task.Run(() =>
        {
            var projectCollection = new ProjectCollection();
            var buildLogger = new StructuredLogger();

            try
            {
                // Load project into memory
                var project = projectCollection.LoadProject(Path.Combine(isolatedPath, "SyncAIAppBuilder.csproj"));

                // Set properties
                project.SetProperty("Configuration", configuration);
                project.SetProperty("Platform", "Any CPU");

                // Configure logger
                var buildParameters = new BuildParameters(projectCollection)
                {
                    Loggers = new[] { buildLogger },
                    MaxNodeCount = Environment.ProcessorCount // Parallel build
                };

                // Create build request
                var buildRequest = new BuildRequestData(
                    project.CreateProjectInstance(),
                    new[] { "Restore", "Build" } // Run Restore then Build
                );

                // Execute Build
                var result = BuildManager.DefaultBuildManager
                    .Build(buildParameters, buildRequest);

                return new BuildResult
                {
                    Success = result.OverallResult == BuildResultCode.Success,
                    Output = buildLogger.Output,
                    Errors = buildLogger.Errors,
                    ExitCode = result.OverallResult == BuildResultCode.Success ? 0 : 1
                };
            }
            finally
            {
                projectCollection.Dispose();
            }
        });
    }

    /// <summary>
    /// Builds with timeout and cancellation support
    /// </summary>
    public async Task<BuildResult> BuildWithTimeoutAsync(
        string projectPath,
        TimeSpan timeout,
        CancellationToken cancellationToken = default)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        cts.CancelAfter(timeout);

        try
        {
            return await BuildAsync(projectPath, "Debug");
        }
        catch (OperationCanceledException)
        {
            return new BuildResult
            {
                Success = false,
                Errors = $"Build timed out after {timeout.TotalSeconds} seconds",
                TimedOut = true
            };
        }
    }
}
```

### 3.4 Structured Logger

```csharp
private class StructuredLogger : ILogger
{
    public string Output { get; private set; } = string.Empty;
    public string Errors { get; private set; } = string.Empty;
    public string FullLog { get; private set; } = string.Empty;

    public void Initialize(IEventSource eventSource)
    {
        eventSource.ErrorRaised += (s, e) => Errors += $"{e.File}:{e.LineNumber}: error {e.Code}: {e.Message}\n";
        eventSource.WarningRaised += (s, e) => Output += $"{e.File}:{e.LineNumber}: warning {e.Code}: {e.Message}\n";
        eventSource.MessageRaised += (s, e) => FullLog += e.Message + "\n";
    }

    public void Shutdown() { }
    public LoggerVerbosity Verbosity { get; set; }
    public string? Parameters { get; set; }
}
```

---

## 4. Process Isolation & Job Objects

### 4.1 Purpose

Job Objects provide OS-level process grouping and resource enforcement for preview execution.

### 4.2 Job Object Implementation Contract

```csharp
/// <summary>
/// Creates and configures a Windows Job Object for process isolation.
/// This is the mechanized enforcement of OS-level isolation policy.
/// </summary>
public class JobObjectEnforcer : IDisposable
{
    private IntPtr _jobHandle;
    private readonly JobObjectLimits _limits;

    public JobObjectEnforcer(JobObjectLimits limits)
    {
        _limits = limits;
        _jobHandle = CreateJobObject(IntPtr.Zero, null);
        ConfigureLimits();
    }

    private void ConfigureLimits()
    {
        // MEMORY LIMIT: 1GB hard cap
        var memInfo = new JOBOBJECT_BASIC_LIMIT_INFORMATION
        {
            LimitFlags = JOB_OBJECT_LIMIT.JOB_OBJECT_LIMIT_JOB_MEMORY |
                         JOB_OBJECT_LIMIT.JOB_OBJECT_LIMIT_PROCESS_MEMORY,
            JobMemoryLimit = _limits.MaxMemoryBytes,      // 1GB
            ProcessMemoryLimit = _limits.MaxMemoryBytes   // 1GB per process
        };

        // CPU LIMIT: 50% throttle
        var cpuInfo = new JOBOBJECT_CPU_RATE_CONTROL_INFORMATION
        {
            ControlFlags = JOB_OBJECT_CPU_RATE_CONTROL.JOB_OBJECT_CPU_RATE_CONTROL_ENABLE |
                          JOB_OBJECT_CPU_RATE_CONTROL.JOB_OBJECT_CPU_RATE_CONTROL_HARD_CAP,
            CpuRate = _limits.MaxCpuPercent * 100  // 50% = 5000 (scale is 0-10000)
        };

        // CHILD PROCESS RESTRICTION: Block dangerous executables
        var denyList = new JOBOBJECT_BASIC_PROCESS_ID_LIST
        {
            NumberOfProcessIdsInList = 0  // No child processes allowed
        };

        SetInformationJobObject(_jobHandle, JOBOBJECTINFOCLASS.JobObjectBasicLimitInformation,
                               ref memInfo, (uint)Marshal.SizeOf(memInfo));
        SetInformationJobObject(_jobHandle, JOBOBJECTINFOCLASS.JobObjectCpuRateControlInformation,
                               ref cpuInfo, (uint)Marshal.SizeOf(cpuInfo));
    }

    /// <summary>
    /// Assigns a process to the Job Object for enforcement.
    /// </summary>
    public bool AssignProcess(Process process)
    {
        return AssignProcessToJobObject(_jobHandle, process.Handle);
    }

    // P/Invoke signatures for Windows API
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);

    [DllImport("kernel32.dll")]
    private static extern bool SetInformationJobObject(IntPtr hJob, JOBOBJECTINFOCLASS JobObjectInfoClass,
        ref JOBOBJECT_BASIC_LIMIT_INFORMATION lpJobObjectInfo, uint cbJobObjectInfoLength);

    [DllImport("kernel32.dll")]
    private static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

    public void Dispose()
    {
        if (_jobHandle != IntPtr.Zero)
        {
            CloseHandle(_jobHandle);
            _jobHandle = IntPtr.Zero;
        }
    }
}
```

### 4.3 Job Object Limits

```csharp
public record JobObjectLimits
{
    public long MaxMemoryBytes { get; init; } = 1L * 1024 * 1024 * 1024; // 1GB
    public int MaxCpuPercent { get; init; } = 50;  // 50%
    public TimeSpan MaxExecutionTime { get; init; } = TimeSpan.FromMinutes(5);
    public HashSet<string> BlockedExecutables { get; init; } = new()
    {
        "powershell.exe", "cmd.exe", "reg.exe", "mshta.exe", "wscript.exe", "cscript.exe"
    };
}
```

### 4.4 Child Process Deny-List

```csharp
/// <summary>
/// Pre-launch validation that blocks dangerous executables from being spawned.
/// </summary>
public class ChildProcessDenyList
{
    private static readonly HashSet<string> BlockedExecutables = new(StringComparer.OrdinalIgnoreCase)
    {
        "powershell.exe", "powershell", "cmd.exe", "cmd",
        "reg.exe", "reg", "mshta.exe", "mshta",
        "wscript.exe", "cscript.exe", "rundll32.exe"
    };

    public bool IsAllowed(string executableName)
    {
        var name = Path.GetFileNameWithoutExtension(executableName);
        return !BlockedExecutables.Contains(name);
    }

    public void ValidateProcessStart(ProcessStartInfo startInfo)
    {
        if (!IsAllowed(startInfo.FileName))
        {
            throw new SecurityException($"Blocked executable: {startInfo.FileName}. " +
                "This executable is on the deny-list for preview isolation.");
        }
    }
}
```

---

## 5. Security Boundaries & ACL Enforcement

### 5.1 Execution Isolation Enforcement Policy

> **Invariant**: No user code runs with host privileges.

#### Isolation Options (Priority Order)

1. **Windows Sandbox** (Preferred):
   - Fully ephemeral VM
   - No persistence
   - Complete isolation

2. **AppContainer Fallback** (If Sandbox unavailable):
   - `broadFileSystemAccess`: **DENIED** (unless explicitly granted)
   - Host Registry Write: **DENIED**
   - `powershell.exe`, `cmd.exe`, `reg.exe`: **BLOCKED** (Child process restriction)
   - Network: **Restricted** (Outbound only if `internetClient` declared)

3. **Job Object Constraints**:
   - Memory Limit: 1GB (Preview)
   - CPU Limit: 50% (Preview)

### 5.2 File ACL Jail Path Enforcement

```csharp
/// <summary>
/// Enforces file system ACL jail for preview execution.
/// Ensures the generated app can only access its designated workspace.
/// </summary>
public class FileSystemAclJail
{
    private readonly string _workspaceRoot;

    public FileSystemAclJail(string workspaceRoot)
    {
        _workspaceRoot = Path.GetFullPath(workspaceRoot);
    }

    /// <summary>
    /// Creates a restricted ACL that only permits access to the workspace directory.
    /// </summary>
    public void ApplyJailAcl(string targetDirectory)
    {
        var directoryInfo = new DirectoryInfo(targetDirectory);
        var acl = directoryInfo.GetAccessControl();

        // Remove inherited permissions
        acl.SetAccessRuleProtection(true, false);

        // Add explicit read/write for current user ONLY to workspace
        var currentUser = WindowsIdentity.GetCurrent().User;
        acl.AddAccessRule(new FileSystemAccessRule(
            currentUser,
            FileSystemRights.Read | FileSystemRights.Write | FileSystemRights.Delete,
            InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
            PropagationFlags.None,
            AccessControlType.Allow));

        directoryInfo.SetAccessControl(acl);
    }

    /// <summary>
    /// Validates that a path is within the jail boundary.
    /// </summary>
    public bool IsPathWithinJail(string path)
    {
        var fullPath = Path.GetFullPath(path);
        return fullPath.StartsWith(_workspaceRoot, StringComparison.OrdinalIgnoreCase);
    }
}
```

### 5.3 AI-Primary Ownership of Security

> **The AI Construction Engine proposes code, the Runtime Safety Kernel enforces security boundaries.**

| Security Stage | Owner | Description |
|----------------|-------|-------------|
| Code generation | AI Construction Engine | Agent generates code changes |
| Path validation | Runtime Safety Kernel | Hard rejection if path outside sandbox |
| Schema validation | Runtime Safety Kernel | Hard rejection if JSON invalid |
| Symbol validation | Runtime Safety Kernel | Hard rejection if symbol missing |
| Process isolation | Runtime Safety Kernel | Job Objects enforce limits |
| Error recovery | AI Construction Engine | Agent decides how to fix |

### 5.4 AI Trust Boundary & Validation

The Runtime Safety Kernel enforces a strict **Zero-Trust** policy on all AI-generated code.

#### Mandatory Validation Gates

**1. JSON Schema Compliance**
- Output must parse strictly against `TaskGraph` or `Patch` schemas
- Any schema violation triggers immediate rejection
- Invalid JSON results in retry with correction prompt

**2. Path Sandbox Enforcement**
- All paths must be relative to project root
- No absolute paths allowed
- No `..` directory traversal

**3. Symbol Consistency Check**
- Modified methods must exist in Roslyn Index
- Referenced classes must be resolvable
- Breaking changes must be flagged

```csharp
public class AITrustBoundary
{
    private readonly string _projectRoot;
    private readonly RoslynIndexer _indexer;

    // Reuse the canonical BannedPaths definition (see §2.4)
    private static readonly HashSet<string> BannedPaths = FileSystemSandbox.BannedPaths;

    public ValidationResult ValidatePatch(Patch patch)
    {
        // 1. Path validation
        if (!IsPathSafe(patch.FilePath))
        {
            return ValidationResult.Failed($"AI attempted sandbox violation: {patch.FilePath}");
        }

        // 2. Symbol existence
        if (patch.Operation == PatchOperation.MODIFY_METHOD)
        {
            if (!_indexer.MethodExists(patch.TargetClass, patch.TargetMethod))
            {
                return ValidationResult.Failed($"Target method not found: {patch.TargetMethod}");
            }
        }

        // 3. JSON schema validation
        if (!ValidateJsonSchema(patch.Metadata))
        {
            return ValidationResult.Failed("JSON schema validation failed");
        }

        return ValidationResult.Success();
    }

    private bool IsPathSafe(string path)
    {
        // Check for absolute paths
        if (Path.IsPathRooted(path))
            return false;

        // Check for directory traversal
        if (path.Contains(".."))
            return false;

        // Check for banned paths
        var normalizedPath = path.Replace('\\', '/').ToLowerInvariant();
        foreach (var banned in BannedPaths)
        {
            if (normalizedPath.Contains($"/{banned}/") ||
                normalizedPath.StartsWith($"{banned}/") ||
                normalizedPath.EndsWith($"/{banned}") ||
                normalizedPath.Equals(banned, StringComparison.OrdinalIgnoreCase))
                return false;
        }

        // Ensure path is within project root
        var fullPath = Path.GetFullPath(Path.Combine(_projectRoot, path));
        var rootPath = Path.GetFullPath(_projectRoot);
        return fullPath.StartsWith(rootPath, StringComparison.OrdinalIgnoreCase);
    }
}
```

#### Security Invariants

- **Zero Trust**: Never assume AI output is safe
- **Defense in Depth**: Multiple validation layers
- **Fail Closed**: Reject if any check fails
- **Audit Everything**: Log all validation attempts

---

## 6. Machine Variability Handling

### 6.1 The Local-Only Challenge

Unlike cloud environments with fixed infrastructure, local execution must handle:

| Issue                          | Solution                                  |
| ------------------------------ | ----------------------------------------- |
| **Embedded Runtime Corrupted** | App self-repair / Reinstall prompt        |
| **Missing Windows Runtime**    | Detected by MSIX installer                |
| **Antivirus blocking MSBuild** | Sign binaries with trusted cert           |
| **Low disk space**             | Check before build, warn user             |
| **Broken NuGet cache**         | Clear local cache, retry restore          |
| **Limited RAM**                | Use incremental builds, limit parallelism |
| **Slow disk**                  | Use smaller snapshots, avoid full ZIP     |
| **Power loss during build**    | Snapshot before = safe recovery           |

### 6.2 Embedded Runtime Validation

```csharp
public class EmbeddedEnvironmentValidator
{
    private readonly string _embeddedSdkPath;

    public bool ValidateEnvironment()
    {
        // 1. Verify MSBuild assemblies are present
        if (!File.Exists(Path.Combine(_embeddedSdkPath, "Microsoft.Build.dll")))
            return false;

        // 2. Verify .NET Runtime is functional
        // (Self-check handled by app startup)

        return true;
    }
}
```

### 6.3 Antivirus Interference Handling

```csharp
public class AntivirusAwareBuildService
{
    public async Task<BuildResult> BuildWithRetryAsync(string projectPath)
    {
        var maxRetries = 3;
        var delay = TimeSpan.FromSeconds(2);

        for (int i = 0; i < maxRetries; i++)
        {
            try
            {
                return await _buildKernel.BuildAsync(projectPath);
            }
            catch (UnauthorizedAccessException ex)
            {
                // Possibly antivirus blocking
                _logger.LogWarning("Build blocked (attempt {Attempt}): {Error}", i + 1, ex.Message);

                if (i < maxRetries - 1)
                {
                    await Task.Delay(delay);
                    delay = TimeSpan.FromSeconds(delay.TotalSeconds * 2); // Exponential backoff
                }
            }
        }

        // Suggest user add exclusion
        return BuildResult.Failed("Build blocked. Consider adding an antivirus exclusion for the workspace.");
    }
}
```

### 6.4 Resource-Based Adaptive Builds

```csharp
public class AdaptiveBuildService
{
    public async Task<BuildResult> BuildWithAdaptiveSettingsAsync(string projectPath)
    {
        // Get system resources
        var availableMemoryGB = GC.GetTotalMemory(false) / (1024.0 * 1024 * 1024);
        var processorCount = Environment.ProcessorCount;
        var driveInfo = new DriveInfo(Path.GetPathRoot(projectPath));
        var availableDiskGB = driveInfo.AvailableFreeSpace / (1024.0 * 1024 * 1024);

        // Adjust build parameters based on resources
        var buildSettings = new BuildSettings
        {
            MaxParallelTasks = availableMemoryGB < 4 ? 1 : Math.Max(1, processorCount - 1),
            EnableIncrementalBuild = availableDiskGB < 10,
            UseSparseSnapshots = availableDiskGB < 5
        };

        return await _buildKernel.BuildAsync(projectPath, buildSettings);
    }
}
```

### 6.5 Error Handling with Fallbacks

```csharp
public class MachineVariabilityHandler
{
    public async Task<BuildResult> BuildWithFallbacksAsync(
        string projectPath,
        IProgress<BuildPhase>? progress = null)
    {
        // Phase 1: Verify Embedded Environment
        if (!_envValidator.ValidateEnvironment())
        {
             return BuildResult.CriticalFailure("Embedded SDK is corrupted.");
        }

        // Phase 2: Attempt restore (In-Process)
        var restoreResult = await _kernel.BuildAsync(projectPath, "Debug");
        if (!restoreResult.Success)
        {
            // Try clearing cache + retry
            if (restoreResult.HasNuGetConnectionError)
            {
                _logger.LogInformation("Clearing NuGet cache...");
                await ClearNuGetCacheAsync();

                restoreResult = await _kernel.BuildAsync(projectPath, "Debug");
                if (!restoreResult.Success)
                    return restoreResult;
            }
        }

        return restoreResult;
    }

    private async Task<bool> ClearNuGetCacheAsync()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var nugetCache = Path.Combine(localAppData, "NuGet", "v3-cache");

        try
        {
            if (Directory.Exists(nugetCache))
            {
                Directory.Delete(nugetCache, recursive: true);
                _logger.LogInformation("NuGet cache cleared");
            }
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning($"Failed to clear NuGet cache: {ex.Message}");
            return false;
        }
    }
}
```

### 6.6 Critical Stability Constraints

- **Environment Bootstrapping**: Automatically detect missing .NET SDKs and guide the user through installation
- **SDK Variability**: Detect missing .NET workloads (WinUI 3, XAML) and handle version mismatches
- **Resource Intelligence**: Monitor disk space and RAM; disable parallel builds if <4GB
- **External Interference**: Detect and handle Antivirus blocking with "self-repair" strategies
- **Corruption Recovery**: Automated partial project corruption detection and rollback

---

## 7. Embedded Subsystems

### 7.1 Why "Embedded"?

| Component         | Traditional Approach          | Sync AI Embedded Approach                           |
| ----------------- | ----------------------------- | --------------------------------------------------- |
| **Build**         | Shell out to `dotnet CLI`     | `Microsoft.Build.Execution.BuildManager` in-process |
| **NuGet**         | Shell out to `dotnet CLI`     | `NuGet.Commands.RestoreCommand` in-process          |
| **Code Analysis** | External linter               | `Microsoft.CodeAnalysis` (Roslyn) in-process        |
| **Database**      | External DB server            | `Microsoft.Data.Sqlite` embedded                    |
| **Preview**       | External browser              | WinUI 3 `WebView2` or XAML renderer                 |

### 7.2 The 6 Embedded Subsystems

1. **Filesystem Sandbox**: Manages isolated workspaces, enforcing security boundaries
2. **Execution Kernel**: The "engine room" that manages .NET SDK, MSBuild, and NuGet operations
3. **Roslyn Code Intelligence**: Parses code into ASTs, maintains symbol graph
4. **Transactional Patch Engine**: Performs safe, reversible code mutations
5. **SQLite Project Graph**: Persists project structure, symbols, dependencies
6. **Process Sandbox**: Manages isolated execution with resource limits
7. **AI Mini Service**: Managed child process for AI capabilities

### 7.3 AI Mini Service Process

The AI Mini Service is treated as a managed child process.

• Started at application boot.
• Bound to 127.0.0.1 only.
• Restarted on config changes.
• Terminated on SYSTEM_RESET.
• Monitored for crash recovery.

The AI Mini Service does NOT persist configuration to disk.
All configuration is pushed at runtime via POST /api/config.

### 7.3 Architecture Diagram

```text
┌─────────────────────────────────────────────────────────┐
│ SyncAI Process                                          │
│                                                         │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│ │ Execution    │ │ Code         │ │ Patch        │     │
│ │ Kernel       │ │ Intelligence │ │ Engine       │     │
│ │              │ │              │ │              │     │
│ │ MSBuild API  │ │ Roslyn AST   │ │ Transactional│     │
│ │ NuGet API    │ │ Symbol Graph │ │ Writes       │     │
│ │ Process Mgr  │ │ Dep. Anal.   │ │ Rollback     │     │
│ └──────────────┘ └──────────────┘ └──────────────┘     │
│                                                         │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│ │ Filesystem   │ │ SQLite       │ │ Snapshot     │     │
│ │ Sandbox      │ │ Graph DB     │ │ Manager      │     │
│ │              │ │              │ │              │     │
│ │ Isolation    │ │ Symbols      │ │ Versioning   │     │
│ │ Path Safety  │ │ Deps         │ │ Diff/Patch   │     │
│ │ Workspace    │ │ Errors       │ │ Rollback     │     │
│ └──────────────┘ └──────────────┘ └──────────────┘     │
└─────────────────────────────────────────────────────────┘
```

---

## 8. Resource Monitoring

### 8.1 Resource Monitor Service

```csharp
public class ResourceMonitor
{
    public ResourceStatus GetCurrentStatus()
    {
        var memoryInfo = GC.GetGCMemoryInfo();
        var driveInfo = new DriveInfo(Path.GetPathRoot(Environment.CurrentDirectory));

        return new ResourceStatus
        {
            AvailableMemoryGB = memoryInfo.TotalAvailableMemoryBytes / (1024.0 * 1024 * 1024),
            AvailableDiskGB = driveInfo.AvailableFreeSpace / (1024.0 * 1024 * 1024),
            CpuUsagePercent = GetCpuUsage(),
            ActiveProcesses = GetActiveBuildProcesses()
        };
    }

    public bool ShouldThrottle()
    {
        var status = GetCurrentStatus();
        return status.AvailableMemoryGB < 2 || status.AvailableDiskGB < 1;
    }

    public void ApplyThrottling()
    {
        // Reduce parallelism
        // Enable sparse snapshots
        // Increase GC collection
    }
}
```

### 8.2 Disk Space Guard

```csharp
public class DiskSpaceValidator : IDiskSpaceValidator
{
    private const long MinRequiredSpaceBytes = 500L * 1024 * 1024; // 500 MB

    public bool HasSpace(long requiredBytes)
    {
        var drive = new DriveInfo(Path.GetPathRoot(Environment.CurrentDirectory));
        return drive.AvailableFreeSpace >= Math.Max(requiredBytes, MinRequiredSpaceBytes);
    }

    public void EnsureSpace(long requiredBytes)
    {
        if (!HasSpace(requiredBytes))
        {
            throw new InsufficientStorageException(
                $"Insufficient disk space. Required: {requiredBytes / (1024 * 1024)} MB");
        }
    }
}
```

### 8.3 Health Monitoring Configuration

> **INVARIANT**: The Execution Environment MUST define explicit health monitoring thresholds to enable proactive failure detection and graceful degradation.

#### Health Check Configuration

```csharp
public class HealthMonitoringConfig
{
    /// <summary>
    /// Configuration for execution environment health monitoring.
    /// </summary>
    public static readonly HealthThresholds Thresholds = new()
    {
        // Memory thresholds
        MemoryWarningMB = 512,      // Warn when < 512MB available
        MemoryCriticalMB = 256,    // Block operations when < 256MB
        
        // Disk thresholds
        DiskWarningGB = 1.0,       // Warn when < 1GB available
        DiskCriticalGB = 0.5,     // Block operations when < 500MB
        
        // CPU thresholds
        CpuWarningPercent = 80,    // Warn when CPU > 80%
        CpuCriticalPercent = 95,   // Block operations when CPU > 95%
        
        // Health check intervals
        HealthCheckIntervalSeconds = 30,
        ProcessHealthCheckIntervalSeconds = 10,
        
        // Service health
        AIServiceMaxRetries = 3,
        AIServiceRetryDelaySeconds = 5
    };

    public record HealthThresholds
    {
        public long MemoryWarningMB { get; init; }
        public long MemoryCriticalMB { get; init; }
        public double DiskWarningGB { get; init; }
        public double DiskCriticalGB { get; init; }
        public int CpuWarningPercent { get; init; }
        public int CpuCriticalPercent { get; init; }
        public int HealthCheckIntervalSeconds { get; init; }
        public int ProcessHealthCheckIntervalSeconds { get; init; }
        public int AIServiceMaxRetries { get; init; }
        public int AIServiceRetryDelaySeconds { get; init; }
    }
}
```

#### Health Status Classification

| Status | Condition | Action |
|--------|-----------|--------|
| **HEALTHY** | All metrics below warning thresholds | Continue normal operation |
| **DEGRADED** | Any metric exceeds warning threshold | Log warning, continue with monitoring |
| **UNHEALTHY** | Any metric exceeds critical threshold | Block new operations, show warning |

#### Health Monitor Implementation

```csharp
public class ExecutionEnvironmentHealthMonitor
{
    private readonly HealthThresholds _thresholds;
    private HealthStatus _currentStatus = HealthStatus.HEALTHY;
    
    public async Task<HealthStatus> CheckHealthAsync()
    {
        var memoryInfo = GetMemoryInfo();
        var diskInfo = GetDiskInfo();
        var cpuInfo = GetCpuInfo();
        
        // Check critical conditions first
        if (memoryInfo.AvailableMB < _thresholds.MemoryCriticalMB ||
            diskInfo.AvailableGB < _thresholds.DiskCriticalGB ||
            cpuInfo.UsagePercent > _thresholds.CpuCriticalPercent)
        {
            _currentStatus = HealthStatus.UNHEALTHY;
            return _currentStatus;
        }
        
        // Check warning conditions
        if (memoryInfo.AvailableMB < _thresholds.MemoryWarningMB ||
            diskInfo.AvailableGB < _thresholds.DiskWarningGB ||
            cpuInfo.UsagePercent > _thresholds.CpuWarningPercent)
        {
            _currentStatus = HealthStatus.DEGRADED;
            return _currentStatus;
        }
        
        _currentStatus = HealthStatus.HEALTHY;
        return _currentStatus;
    }
    
    public HealthStatus GetCurrentStatus() => _currentStatus;
}

public enum HealthStatus
{
    HEALTHY,
    DEGRADED,
    UNHEALTHY
}
```

---

## 9. Crash Recovery

### 9.1 Boot Safety Controls

Before completing boot, the system performs critical safety checks:

```csharp
await KillOrphanBuildProcessesAsync();
CleanLockFiles();
await TerminateStaleSessionsAsync();
// Check for incomplete session from crash
var incomplete = await _database.GetIncompleteSessionAsync();
if (incomplete != null)
    await HandleCrashRecoveryAsync(incomplete);
```

### 9.2 Crash Recovery Flow

```csharp
private async Task HandleCrashRecoveryAsync(ExecutionSession incomplete)
{
    // 1. Detect incomplete ExecutionSession
    _logger.LogWarning("Detected incomplete session: {SessionId}", incomplete.Id);

    // 2. Rollback to last stable snapshot
    var lastStable = await _database.GetLastStableSnapshotAsync(incomplete.ProjectId);
    await _snapshotManager.RollbackAsync(lastStable.Id);

    // 3. Mark previous version as failed
    await _database.MarkVersionAsFailedAsync(incomplete.Id);

    // 4. Notify user gently
    await ShowToastAsync("We restored your project to a stable version.",
        severity: InfoBarSeverity.Informational);
}
```

### 9.3 Recovery Steps

1. Log the detection of incomplete session
2. Automatically rollback to last stable snapshot
3. Mark the crashed version as failed in history
4. Show gentle notification to user (no technical details)

---

## References

- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — 8-layer overview, global invariants
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — State machine, task lifecycle
- [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) — Roslyn indexing, symbol graph
- [PREVIEW_SYSTEM.md](./PREVIEW_SYSTEM.md) — Preview rendering, sandbox launch
- [WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md](./WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md) — Packaging pipeline
- [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — **AI capabilities via user-configured providers**
- [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md) — Complete TypeScript implementation
- [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) — **NEW: Zero-template asset generation**

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Added PLATFORM_REQUIREMENTS_ENGINE.md to References |
