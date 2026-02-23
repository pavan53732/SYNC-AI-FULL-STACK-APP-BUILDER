# Resource Monitoring

> **Execution Layer: Health Monitoring, Disk Space Guards, and Performance Thresholds**
>
> **Parent Document:** [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md)
>
> **Related:** [MachineVariability.md](./MachineVariability.md) — Adaptive builds

---

## Table of Contents

1. [Resource Monitor Service](#1-resource-monitor-service)
2. [Disk Space Guard](#2-disk-space-guard)
3. [Health Monitoring Configuration](#3-health-monitoring-configuration)
4. [Health Status Classification](#4-health-status-classification)

---

## 1. Resource Monitor Service

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

---

## 2. Disk Space Guard

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

---

## 3. Health Monitoring Configuration

> **INVARIANT**: The Execution Environment MUST define explicit health monitoring thresholds to enable proactive failure detection and graceful degradation.

### Health Check Configuration

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
    };
}
```

---

## 4. Health Status Classification

| Status | Condition | Action |
|--------|-----------|--------|
| **HEALTHY** | All metrics below warning thresholds | Continue normal operation |
| **DEGRADED** | Any metric exceeds warning threshold | Log warning, continue with monitoring |
| **UNHEALTHY** | Any metric exceeds critical threshold | Block new operations, show warning |

### Health Monitor Implementation

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

## References

- [EXECUTION_ENVIRONMENT.md](../EXECUTION_ENVIRONMENT.md) — Parent document
- [MachineVariability.md](./MachineVariability.md) — Adaptive builds
- [CrashRecovery.md](./CrashRecovery.md) — Recovery procedures
- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Health state integration

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from EXECUTION_ENVIRONMENT.md as part of documentation reorganization |