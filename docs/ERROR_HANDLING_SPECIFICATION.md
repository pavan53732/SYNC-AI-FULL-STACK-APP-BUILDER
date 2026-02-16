# Error Handling Specification - User Experience & Recovery

**Purpose:** Define comprehensive error handling strategy, classification taxonomy, recovery procedures, and user messaging.  
**Scope:** All error scenarios across UI, Build, AI, and Orchestrator layers.  
**Framework:** .NET 8, WinUI 3

---

## 1. Error Handling Philosophy

### Core Principles

1. **User Never Sees Technical Details** - All errors translated to user-friendly messages
2. **Silent Recovery When Possible** - Retry automatically before showing errors
3. **Actionable Guidance** - Every error message includes next steps
4. **Preserve User Work** - Never lose user data, always snapshot before risky operations
5. **Graceful Degradation** - System remains usable even with partial failures

### Error Severity Levels

| Level | User Impact | UI Indicator | Action Required |
|-------|-------------|--------------|-----------------|
| **Info** | None | Blue info icon | None |
| **Warning** | Minor, non-blocking | Yellow warning icon | Optional user action |
| **Error** | Blocking, recoverable | Red error icon | User must resolve |
| **Critical** | System-level failure | Red with alert | Immediate attention |

---

## 2. Error Classification Taxonomy

### 2.1 Build Errors

```csharp
public enum BuildErrorType
{
    // C# Compiler Errors (CS0001-CS9999)
    CSharpSyntaxError,              // CS1001-CS1999: Syntax errors
    CSharpSemanticError,            // CS0001-CS0999: Type/member errors
    CSharpNullabilityWarning,       // CS8600-CS8999: Nullable reference warnings
    
    // XAML Errors (XDG0001-XDG9999)
    XamlParseError,                 // XDG0001-XDG0999: XML/XAML syntax
    XamlBindingError,               // XDG1000-XDG1999: Data binding
    XamlResourceError,              // XDG2000-XDG2999: Resource resolution
    
    // NuGet Errors (NU0001-NU9999)
    NuGetPackageNotFound,           // NU1101: Package doesn't exist
    NuGetVersionConflict,           // NU1107: Version conflict
    NuGetRestoreFailed,             // NU1000: General restore failure
    
    // MSBuild Errors (MSB0001-MSB9999)
    MSBuildProjectFileError,        // MSB4000-MSB4999: .csproj issues
    MSBuildTargetError,             // MSB3000-MSB3999: Build target failures
    
    // SDK Errors
    SdkNotFound,                    // .NET SDK not installed
    SdkVersionMismatch,             // Wrong SDK version
    
    // Timeout
    BuildTimeout,                   // Build exceeded timeout
    
    // Unknown
    UnknownBuildError
}
```

### 2.2 AI Engine Errors

```csharp
public enum AIErrorType
{
    // API Errors
    ApiKeyMissing,                  // No API key configured
    ApiKeyInvalid,                  // Invalid API key
    ApiRateLimitExceeded,           // Too many requests
    ApiQuotaExceeded,               // Monthly quota exceeded
    ApiNetworkError,                // Network connectivity issue
    ApiTimeout,                     // Request timeout
    
    // Response Errors
    InvalidJsonResponse,            // Malformed JSON
    SchemaValidationFailed,         // Response doesn't match schema
    EmptyResponse,                  // No content returned
    
    // Content Errors
    ContentPolicyViolation,         // Prompt violates content policy
    TokenLimitExceeded,             // Prompt too long
    
    // Model Errors
    ModelNotAvailable,              // Selected model unavailable
    ModelDeprecated,                // Model no longer supported
    
    UnknownAIError
}
```

### 2.3 File System Errors

```csharp
public enum FileSystemErrorType
{
    PathNotFound,                   // Directory/file doesn't exist
    PathTooLong,                    // Path exceeds Windows limit
    AccessDenied,                   // Permission denied
    DiskFull,                       // Insufficient disk space
    FileInUse,                      // File locked by another process
    InvalidFileName,                // Invalid characters in name
    SnapshotCreationFailed,         // Failed to create snapshot
    SnapshotRestoreFailed,          // Failed to restore snapshot
    UnknownFileSystemError
}
```

### 2.4 Roslyn/Patch Errors

```csharp
public enum PatchErrorType
{
    TargetNotFound,                 // Class/method not found
    SignatureMismatch,              // Method signature changed
    FileHashMismatch,               // File modified since patch created
    SyntaxError,                    // Generated code has syntax errors
    DuplicateMember,                // Member already exists
    ConflictDetected,               // Merge conflict
    ValidationFailed,               // Patch validation failed
    UnknownPatchError
}
```

### 2.5 Orchestrator Errors

```csharp
public enum OrchestratorErrorType
{
    InvalidStateTransition,         // Illegal state machine transition
    TaskExecutionFailed,            // Task failed to execute
    RetryBudgetExceeded,            // Max retries reached
    DependencyFailed,               // Dependent task failed
    TimeoutExceeded,                // Operation timeout
    CancellationRequested,          // User cancelled
    UnknownOrchestratorError
}
```

---

## 3. Error Handling Strategies

### 3.1 Retry Strategy

```csharp
public class RetryPolicy
{
    public int MaxRetries { get; set; } = 3;
    public TimeSpan InitialDelay { get; set; } = TimeSpan.FromSeconds(1);
    public double BackoffMultiplier { get; set; } = 2.0;
    public TimeSpan MaxDelay { get; set; } = TimeSpan.FromSeconds(30);
    
    public async Task<T> ExecuteAsync<T>(
        Func<Task<T>> operation,
        Func<Exception, bool> shouldRetry)
    {
        var attempt = 0;
        var delay = InitialDelay;
        
        while (true)
        {
            try
            {
                return await operation();
            }
            catch (Exception ex) when (shouldRetry(ex) && attempt < MaxRetries)
            {
                attempt++;
                _logger.LogWarning(ex, "Attempt {Attempt} failed, retrying in {Delay}ms", 
                    attempt, delay.TotalMilliseconds);
                
                await Task.Delay(delay);
                delay = TimeSpan.FromMilliseconds(
                    Math.Min(delay.TotalMilliseconds * BackoffMultiplier, MaxDelay.TotalMilliseconds));
            }
        }
    }
}
```

### 3.2 Retry Decision Matrix

| Error Type | Retry? | Max Retries | Strategy |
|------------|--------|-------------|----------|
| **Network Errors** | ✅ Yes | 3 | Exponential backoff |
| **API Rate Limit** | ✅ Yes | 5 | Fixed delay (60s) |
| **Syntax Errors** | ✅ Yes | 3 | AI re-generation |
| **Build Timeout** | ✅ Yes | 1 | Increase timeout |
| **SDK Not Found** | ❌ No | 0 | User must install |
| **API Key Invalid** | ❌ No | 0 | User must fix |
| **Disk Full** | ❌ No | 0 | User must free space |

---

## 4. Error Recovery Procedures

### 4.1 Build Error Recovery

```csharp
public class BuildErrorRecoveryService
{
    public async Task<RecoveryResult> RecoverFromBuildErrorAsync(BuildError error)
    {
        return error.ErrorType switch
        {
            BuildErrorType.CSharpSyntaxError => await RecoverFromSyntaxErrorAsync(error),
            BuildErrorType.XamlParseError => await RecoverFromXamlErrorAsync(error),
            BuildErrorType.NuGetPackageNotFound => await RecoverFromNuGetErrorAsync(error),
            BuildErrorType.BuildTimeout => await RecoverFromTimeoutAsync(error),
            _ => RecoveryResult.Failed("No recovery strategy available")
        };
    }
    
    private async Task<RecoveryResult> RecoverFromSyntaxErrorAsync(BuildError error)
    {
        // 1. Extract error context
        var context = await ExtractErrorContextAsync(error);
        
        // 2. Ask AI to fix
        var fixPrompt = $@"
            The following code has a syntax error:
            
            File: {error.FilePath}
            Line: {error.LineNumber}
            Error: {error.Message}
            
            Code context:
            {context}
            
            Please provide a patch to fix this error.
        ";
        
        var patch = await _aiEngine.GeneratePatchAsync(fixPrompt);
        
        // 3. Apply patch
        var result = await _patchEngine.ApplyPatchAsync(patch);
        
        if (result.Success)
        {
            return RecoveryResult.Success("Syntax error fixed automatically");
        }
        
        return RecoveryResult.Failed("Unable to fix syntax error automatically");
    }
    
    private async Task<RecoveryResult> RecoverFromNuGetErrorAsync(BuildError error)
    {
        // Extract package name from error message
        var packageName = ExtractPackageName(error.Message);
        
        // Try to find alternative package version
        var availableVersions = await _nugetService.GetAvailableVersionsAsync(packageName);
        
        if (availableVersions.Any())
        {
            var latestStable = availableVersions
                .Where(v => !v.IsPrerelease)
                .OrderByDescending(v => v.Version)
                .FirstOrDefault();
            
            if (latestStable != null)
            {
                // Update package reference
                await _projectService.UpdatePackageVersionAsync(packageName, latestStable.Version);
                return RecoveryResult.Success($"Updated {packageName} to version {latestStable.Version}");
            }
        }
        
        return RecoveryResult.Failed($"Package {packageName} not found in NuGet");
    }
}

public class RecoveryResult
{
    public bool Success { get; set; }
    public string Message { get; set; }
    public object Data { get; set; }
    
    public static RecoveryResult Success(string message, object data = null) =>
        new RecoveryResult { Success = true, Message = message, Data = data };
    
    public static RecoveryResult Failed(string message) =>
        new RecoveryResult { Success = false, Message = message };
}
```

### 4.2 Snapshot Rollback

```csharp
public class SnapshotRollbackService
{
    public async Task<RollbackResult> RollbackToLastGoodStateAsync(string projectId)
    {
        // Find last committed snapshot
        var lastGoodSnapshot = await _snapshotRepository.GetLastCommittedSnapshotAsync(projectId);
        
        if (lastGoodSnapshot == null)
        {
            return RollbackResult.Failed("No good snapshot found");
        }
        
        try
        {
            // Restore snapshot
            await _fileSystemSandbox.RestoreSnapshotAsync(projectId, lastGoodSnapshot.FilePath);
            
            // Re-index files
            await _codeIndexer.IndexProjectAsync(projectId);
            
            _logger.LogInformation("Rolled back project {ProjectId} to snapshot {SnapshotId}", 
                projectId, lastGoodSnapshot.Id);
            
            return RollbackResult.Success($"Restored to snapshot from {lastGoodSnapshot.CreatedDate}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Rollback failed for project {ProjectId}", projectId);
            return RollbackResult.Failed($"Rollback failed: {ex.Message}");
        }
    }
}
```

---

## 5. User-Facing Error Messages

### 5.1 Error Message Templates

```csharp
public class ErrorMessageProvider
{
    private readonly Dictionary<BuildErrorType, ErrorMessageTemplate> _buildErrorMessages = new()
    {
        [BuildErrorType.CSharpSyntaxError] = new ErrorMessageTemplate
        {
            Title = "Code Syntax Error",
            Message = "There's a syntax error in the generated code.",
            UserAction = "The system will attempt to fix this automatically. If the problem persists, try rephrasing your prompt.",
            Icon = "Error",
            Severity = ErrorSeverity.Error
        },
        
        [BuildErrorType.SdkNotFound] = new ErrorMessageTemplate
        {
            Title = ".NET SDK Required",
            Message = "The .NET 8.0 SDK is not installed on your system.",
            UserAction = "Please download and install the .NET 8.0 SDK from the link below.",
            ActionButton = new ActionButton
            {
                Text = "Download .NET SDK",
                Url = "https://dotnet.microsoft.com/download/dotnet/8.0"
            },
            Icon = "Warning",
            Severity = ErrorSeverity.Critical
        },
        
        [BuildErrorType.BuildTimeout] = new ErrorMessageTemplate
        {
            Title = "Build Timeout",
            Message = "The build is taking longer than expected.",
            UserAction = "The system will retry with a longer timeout. For complex projects, this may take a few minutes.",
            Icon = "Clock",
            Severity = ErrorSeverity.Warning
        }
    };
    
    public ErrorMessageTemplate GetMessageTemplate(BuildErrorType errorType)
    {
        return _buildErrorMessages.TryGetValue(errorType, out var template)
            ? template
            : GetDefaultTemplate();
    }
    
    private ErrorMessageTemplate GetDefaultTemplate() => new()
    {
        Title = "Unexpected Error",
        Message = "An unexpected error occurred.",
        UserAction = "Please try again. If the problem persists, check the logs for more details.",
        Icon = "Error",
        Severity = ErrorSeverity.Error
    };
}

public class ErrorMessageTemplate
{
    public string Title { get; set; }
    public string Message { get; set; }
    public string UserAction { get; set; }
    public ActionButton ActionButton { get; set; }
    public string Icon { get; set; }
    public ErrorSeverity Severity { get; set; }
}

public class ActionButton
{
    public string Text { get; set; }
    public string Url { get; set; }
    public Action OnClick { get; set; }
}
```

### 5.2 Error Dialog UI

```xaml
<ContentDialog x:Name="ErrorDialog"
               Title="{x:Bind ViewModel.ErrorTitle}"
               PrimaryButtonText="{x:Bind ViewModel.PrimaryButtonText}"
               CloseButtonText="Close">
    <StackPanel Spacing="16">
        <!-- Error Icon -->
        <FontIcon Glyph="{x:Bind ViewModel.ErrorIcon}"
                  FontSize="48"
                  Foreground="{x:Bind ViewModel.ErrorColor}"/>
        
        <!-- Error Message -->
        <TextBlock Text="{x:Bind ViewModel.ErrorMessage}"
                   TextWrapping="Wrap"
                   Style="{StaticResource BodyTextBlockStyle}"/>
        
        <!-- User Action -->
        <InfoBar Severity="{x:Bind ViewModel.Severity}"
                 IsOpen="True"
                 Title="What to do next"
                 Message="{x:Bind ViewModel.UserAction}"/>
        
        <!-- Action Button (if applicable) -->
        <HyperlinkButton Content="{x:Bind ViewModel.ActionButtonText}"
                         NavigateUri="{x:Bind ViewModel.ActionButtonUrl}"
                         Visibility="{x:Bind ViewModel.HasActionButton}"/>
        
        <!-- Technical Details (Expandable) -->
        <Expander Header="Technical Details"
                  IsExpanded="False">
            <ScrollViewer MaxHeight="200">
                <TextBlock Text="{x:Bind ViewModel.TechnicalDetails}"
                           FontFamily="Consolas"
                           FontSize="12"
                           IsTextSelectionEnabled="True"/>
            </ScrollViewer>
        </Expander>
    </StackPanel>
</ContentDialog>
```

---

## 6. Logging Strategy

### 6.1 Log Levels

```csharp
public class ErrorLogger
{
    private readonly ILogger _logger;
    
    public void LogError(Exception ex, string message, params object[] args)
    {
        // Log to file
        _logger.LogError(ex, message, args);
        
        // Log to database for analytics
        _errorRepository.AddAsync(new ErrorLog
        {
            Timestamp = DateTime.UtcNow,
            Level = "Error",
            Message = string.Format(message, args),
            Exception = ex.ToString(),
            StackTrace = ex.StackTrace
        });
    }
    
    public void LogWarning(string message, params object[] args)
    {
        _logger.LogWarning(message, args);
    }
    
    public void LogInfo(string message, params object[] args)
    {
        _logger.LogInformation(message, args);
    }
}
```

### 6.2 Structured Logging

```csharp
_logger.LogError(
    "Build failed for project {ProjectId} with error {ErrorCode}: {ErrorMessage}",
    projectId,
    errorCode,
    errorMessage);

// Produces:
// [ERROR] Build failed for project abc-123 with error CS0103: The name 'foo' does not exist
```

---

## 7. Error Reporting & Analytics

### 7.1 Error Aggregation

```csharp
public class ErrorAnalyticsService
{
    public async Task<ErrorStatistics> GetErrorStatisticsAsync(TimeSpan period)
    {
        var since = DateTime.UtcNow - period;
        
        var errors = await _errorRepository.GetErrorsSinceAsync(since);
        
        return new ErrorStatistics
        {
            TotalErrors = errors.Count,
            ErrorsByType = errors.GroupBy(e => e.ErrorType)
                .ToDictionary(g => g.Key, g => g.Count()),
            MostCommonError = errors.GroupBy(e => e.ErrorCode)
                .OrderByDescending(g => g.Count())
                .FirstOrDefault()?.Key,
            AverageRecoveryTime = errors
                .Where(e => e.RecoveredAt.HasValue)
                .Average(e => (e.RecoveredAt.Value - e.OccurredAt).TotalSeconds)
        };
    }
}
```

### 7.2 Error Pattern Detection

```csharp
public class ErrorPatternDetector
{
    public async Task DetectPatternsAsync()
    {
        var recentErrors = await _errorRepository.GetRecentErrorsAsync(100);
        
        // Group by error code
        var patterns = recentErrors
            .GroupBy(e => e.ErrorCode)
            .Where(g => g.Count() >= 3)  // Pattern = 3+ occurrences
            .Select(g => new ErrorPattern
            {
                ErrorCode = g.Key,
                OccurrenceCount = g.Count(),
                AffectedProjects = g.Select(e => e.ProjectId).Distinct().Count(),
                FirstSeen = g.Min(e => e.Timestamp),
                LastSeen = g.Max(e => e.Timestamp),
                CommonContext = FindCommonContext(g.ToList())
            });
        
        // Store patterns for AI learning
        foreach (var pattern in patterns)
        {
            await _errorPatternRepository.UpsertAsync(pattern);
        }
    }
}
```

---

## 8. Circuit Breaker Pattern

### 8.1 Implementation

```csharp
public class CircuitBreaker
{
    private int _failureCount;
    private DateTime _lastFailureTime;
    private CircuitState _state = CircuitState.Closed;
    
    private readonly int _failureThreshold = 5;
    private readonly TimeSpan _timeout = TimeSpan.FromMinutes(1);
    
    public async Task<T> ExecuteAsync<T>(Func<Task<T>> operation)
    {
        if (_state == CircuitState.Open)
        {
            if (DateTime.UtcNow - _lastFailureTime > _timeout)
            {
                _state = CircuitState.HalfOpen;
            }
            else
            {
                throw new CircuitBreakerOpenException("Circuit breaker is open");
            }
        }
        
        try
        {
            var result = await operation();
            
            if (_state == CircuitState.HalfOpen)
            {
                _state = CircuitState.Closed;
                _failureCount = 0;
            }
            
            return result;
        }
        catch (Exception ex)
        {
            _failureCount++;
            _lastFailureTime = DateTime.UtcNow;
            
            if (_failureCount >= _failureThreshold)
            {
                _state = CircuitState.Open;
            }
            
            throw;
        }
    }
}

public enum CircuitState
{
    Closed,     // Normal operation
    Open,       // Failing, reject all requests
    HalfOpen    // Testing if service recovered
}
```

---

## 9. Global Exception Handler

### 9.1 Application-Level Handler

```csharp
public class GlobalExceptionHandler
{
    public void Initialize()
    {
        // Catch unhandled exceptions
        AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
        TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;
        Application.Current.UnhandledException += OnApplicationUnhandledException;
    }
    
    private void OnUnhandledException(object sender, UnhandledExceptionEventArgs e)
    {
        var ex = e.ExceptionObject as Exception;
        _logger.LogCritical(ex, "Unhandled exception in AppDomain");
        
        // Show crash dialog
        ShowCrashDialog(ex);
        
        // Save crash dump
        SaveCrashDump(ex);
    }
    
    private void OnApplicationUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        _logger.LogError(e.Exception, "Unhandled UI exception");
        
        // Mark as handled to prevent crash
        e.Handled = true;
        
        // Show error dialog
        ShowErrorDialog(e.Exception);
    }
    
    private async void ShowCrashDialog(Exception ex)
    {
        var dialog = new ContentDialog
        {
            Title = "Application Error",
            Content = "The application encountered an unexpected error and needs to close.\n\n" +
                     "Error details have been saved to the log file.",
            CloseButtonText = "Close Application"
        };
        
        await dialog.ShowAsync();
        Application.Current.Exit();
    }
}
```

---

## 10. Error Prevention

### 10.1 Input Validation

```csharp
public class InputValidator
{
    public ValidationResult ValidatePrompt(string prompt)
    {
        if (string.IsNullOrWhiteSpace(prompt))
            return ValidationResult.Error("Prompt cannot be empty");
        
        if (prompt.Length < 10)
            return ValidationResult.Warning("Prompt is very short. Consider adding more details.");
        
        if (prompt.Length > 10000)
            return ValidationResult.Error("Prompt is too long. Maximum 10,000 characters.");
        
        return ValidationResult.Success();
    }
    
    public ValidationResult ValidateProjectName(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
            return ValidationResult.Error("Project name cannot be empty");
        
        var invalidChars = Path.GetInvalidFileNameChars();
        if (name.Any(c => invalidChars.Contains(c)))
            return ValidationResult.Error("Project name contains invalid characters");
        
        return ValidationResult.Success();
    }
}
```

### 10.2 Precondition Checks

```csharp
public class PreconditionChecker
{
    public async Task<PreconditionResult> CheckBuildPreconditionsAsync(string projectPath)
    {
        var issues = new List<string>();
        
        // Check SDK
        var sdkValidation = await _sdkManager.ValidateSdkAsync();
        if (!sdkValidation.IsValid)
            issues.Add(sdkValidation.ErrorMessage);
        
        // Check disk space
        var driveInfo = new DriveInfo(Path.GetPathRoot(projectPath));
        if (driveInfo.AvailableFreeSpace < 1_000_000_000) // 1 GB
            issues.Add("Low disk space. At least 1 GB free space recommended.");
        
        // Check file locks
        var lockedFiles = await FindLockedFilesAsync(projectPath);
        if (lockedFiles.Any())
            issues.Add($"Files are locked: {string.Join(", ", lockedFiles)}");
        
        return issues.Any()
            ? PreconditionResult.Failed(issues)
            : PreconditionResult.Success();
    }
}
```

---

## References

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [BUILD_SYSTEM_SPECIFICATION.md](BUILD_SYSTEM_SPECIFICATION.md) - Build error handling
- [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) - State machine error recovery
- [UI_SPECIFICATION.md](UI_SPECIFICATION.md) - Error UI components
- [DATABASE_SPECIFICATION.md](DATABASE_SPECIFICATION.md) - Error logging persistence
