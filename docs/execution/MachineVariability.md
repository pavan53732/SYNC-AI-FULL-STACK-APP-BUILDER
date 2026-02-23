# Machine Variability

> **Execution Layer: Environment Resilience and Adaptive Build Strategies**
>
> **Parent Document:** [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md)
>
> **Related:** [ExecutionKernel.md](./ExecutionKernel.md) — Build operations

---

## Table of Contents

1. [The Local-Only Challenge](#1-the-local-only-challenge)
2. [Embedded Runtime Validation](#2-embedded-runtime-validation)
3. [Antivirus Interference Handling](#3-antivirus-interference-handling)
4. [Resource-Based Adaptive Builds](#4-resource-based-adaptive-builds)
5. [Error Handling with Fallbacks](#5-error-handling-with-fallbacks)
6. [Critical Stability Constraints](#6-critical-stability-constraints)

---

## 1. The Local-Only Challenge

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

---

## 2. Embedded Runtime Validation

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

---

## 3. Antivirus Interference Handling

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

---

## 4. Resource-Based Adaptive Builds

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

---

## 5. Error Handling with Fallbacks

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

---

## 6. Critical Stability Constraints

- **Environment Bootstrapping**: Automatically detect missing .NET SDKs and guide the user through installation
- **SDK Variability**: Detect missing .NET workloads (WinUI 3, XAML) and handle version mismatches
- **Resource Intelligence**: Monitor disk space and RAM; disable parallel builds if <4GB
- **External Interference**: Detect and handle Antivirus blocking with "self-repair" strategies
- **Corruption Recovery**: Automated partial project corruption detection and rollback

---

## References

- [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md) — Parent document
- [ExecutionKernel.md](./ExecutionKernel.md) — Build operations
- [ResourceMonitoring.md](./ResourceMonitoring.md) — Resource tracking
- [CrashRecovery.md](./CrashRecovery.md) — Recovery procedures

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from EXECUTION_ENVIRONMENT.md as part of documentation reorganization |