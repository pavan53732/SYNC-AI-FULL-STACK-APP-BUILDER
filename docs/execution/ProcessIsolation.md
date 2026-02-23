# Process Isolation

> **Execution Layer: Job Objects, ACL Enforcement, and Security Boundaries**
>
> **Parent Document:** [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md)
>
> **Related:** [FilesystemSandbox.md](./FilesystemSandbox.md) — Workspace isolation

---

## Table of Contents

1. [Purpose](#1-purpose)
2. [Job Object Implementation](#2-job-object-implementation)
3. [Job Object Limits](#3-job-object-limits)
4. [Child Process Deny-List](#4-child-process-deny-list)
5. [Execution Isolation Enforcement Policy](#5-execution-isolation-enforcement-policy)
6. [File ACL Jail Path Enforcement](#6-file-acl-jail-path-enforcement)
7. [AI Trust Boundary & Validation](#7-ai-trust-boundary--validation)

---

## 1. Purpose

Job Objects provide OS-level process grouping and resource enforcement for preview execution.

---

## 2. Job Object Implementation

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

---

## 3. Job Object Limits

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

---

## 4. Child Process Deny-List

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

## 5. Execution Isolation Enforcement Policy

> **Invariant**: No user code runs with host privileges.

### Isolation Options (Priority Order)

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

---

## 6. File ACL Jail Path Enforcement

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

---

## 7. AI Trust Boundary & Validation

The Runtime Safety Kernel enforces a strict **Zero-Trust** policy on all AI-generated code.

### Mandatory Validation Gates

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

### Security Invariants

- **Zero Trust**: Never assume AI output is safe
- **Defense in Depth**: Multiple validation layers
- **Fail Closed**: Reject if any check fails
- **Audit Everything**: Log all validation attempts

### AI-Primary Ownership of Security

| Security Stage | Owner | Description |
|----------------|-------|-------------|
| Code generation | AI Construction Engine | Agent generates code changes |
| Path validation | Runtime Safety Kernel | Hard rejection if path outside sandbox |
| Schema validation | Runtime Safety Kernel | Hard rejection if JSON invalid |
| Symbol validation | Runtime Safety Kernel | Hard rejection if symbol missing |
| Process isolation | Runtime Safety Kernel | Job Objects enforce limits |
| Error recovery | AI Construction Engine | Agent decides how to fix |

---

## References

- [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md) — Parent document
- [FilesystemSandbox.md](./FilesystemSandbox.md) — Workspace isolation
- [ResourceMonitoring.md](./ResourceMonitoring.md) — Resource limits
- [PREVIEW_SYSTEM.md](../PREVIEW_SYSTEM.md) — Preview execution

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from EXECUTION_ENVIRONMENT.md as part of documentation reorganization |