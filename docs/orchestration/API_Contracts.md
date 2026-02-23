# API Contracts

> **Orchestration Layer: Service Interfaces, Timeout Configuration, and AI Service Governance**
>
> **Parent Document:** [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md)
>
> **Related:** [StateMachine.md](./StateMachine.md) — Builder states and transitions

---

## Table of Contents

1. [Orchestrator Service Contract](#1-orchestrator-service-contract)
2. [ConstructionTransaction](#2-constructiontransaction)
3. [Timeout Granularity Configuration](#3-timeout-granularity-configuration)
4. [Trace ID Propagation](#4-trace-id-propagation)
5. [AI Service Failure Governance](#5-ai-service-failure-governance)
6. [AI E2E Test Suite Specification](#6-ai-e2e-test-suite-specification)
7. [ai-service.exe Package Integrity](#7-ai-serviceexe-package-integrity)

---

## 1. Orchestrator Service Contract

### IOrchestrator Interface

```csharp
public interface IOrchestrator
{
    Task<BuilderState> DispatchAsync(BuilderEvent @event);
    Task<TaskResult> ExecuteTaskAsync(TaskDefinition task);
    BuilderContext GetCurrentContext();
    void RequestCancellation();  // Only way to stop execution
}
```

---

## 2. ConstructionTransaction

> **INVARIANT**: Every ConstructionTransaction MUST record the AI provider and model used. This ensures reproducibility of AI-generated artifacts.

> **INVARIANT**: Any change to AI configuration (via Settings > AI Settings) MUST emit a `ConfigurationChangedEvent`. The Orchestrator then transitions to `SYSTEM_RESET` state, clears any active tasks, and forces a complete revalidation before continuing construction. Hot model swapping during active construction is FORBIDDEN.

### ConstructionTransaction Record

```csharp
public record ConstructionTransaction
{
    public string Id { get; init; }
    public string Description { get; init; }
    public DateTime StartedAt { get; init; }
    public DateTime? CompletedAt { get; init; }
    
    // Snapshot reference for rollback
    public string PreMutationSnapshotId { get; init; }
    
    // === PROVIDER/MODEL TRACKING (CRITICAL FOR REPRODUCIBILITY) ===
    public string AIProviderBaseUrl { get; init; }    // e.g., "https://openrouter.ai/api/v1"
    public string AIModelName { get; init; }          // e.g., "openai/gpt-4o"
    public string AIServiceVersion { get; init; }     // ai-service.exe build version
    
    // Trace ID for correlating logs
    public string TraceId { get; init; }
    
    // AI operations performed in this transaction
    public List<AIOperationRecord> AIOperations { get; init; } = new();
    
    // Result
    public bool Success { get; init; }
    public string? ErrorMessage { get; init; }
}

public record AIOperationRecord
{
    public string OperationId { get; init; }
    public string OperationType { get; init; }  // "LLM", "IMAGE_GEN", "VLM", "SEARCH"
    public string ModelUsed { get; init; }       // Which model slot handled this operation
    public DateTime Timestamp { get; init; }
    public TimeSpan Duration { get; init; }
    public bool Success { get; init; }
    public int TokenCount { get; init; }        // For LLM operations
    public string? IntentHash { get; init; }    // Hash of input prompt for caching
    public string? ResultHash { get; init; }    // Hash of output for verification
}
```

### Provider Info Injection

```csharp
public class ConstructionTransactionFactory
{
    private readonly AIServiceClient _aiClient;
    
    public async Task<ConstructionTransaction> CreateTransactionAsync(string taskId, string description)
    {
        // Get health/config info from AI service
        var health = await _aiClient.GetHealthAsync();
        
        return new ConstructionTransaction
        {
            Id = taskId,
            Description = description,
            StartedAt = DateTime.UtcNow,
            PreMutationSnapshotId = GetCurrentSnapshotId(),
            
            // Provider/Model Tracking (CRITICAL)
            AIProviderBaseUrl = "configured-via-settings",
            AIModelName = "configured-via-settings",
            AIServiceVersion = health.Version ?? "unknown",
            
            // Generate trace ID for log correlation
            TraceId = GenerateTraceId()
        };
    }
    
    private string GenerateTraceId()
    {
        // Format: trace_{guid}
        return $"trace_{Guid.NewGuid():N}";
    }
}
```

---

## 3. Timeout Granularity Configuration

> **INVARIANT**: Timeouts MUST be configured per-operation-type, not globally. Different AI operations have vastly different latency profiles.

### Timeout Configuration

```csharp
public class AIOperationTimeouts
{
    /// <summary>
    /// Timeout configuration by operation type.
    /// These are ENFORCED by the Orchestrator, not by the AI service.
    /// </summary>
    public static readonly Dictionary<string, TimeSpan> OperationTimeouts = new()
    {
        // LLM Operations (varies by complexity)
        ["LLM_CHAT_SIMPLE"] = TimeSpan.FromSeconds(30),      // Simple queries
        ["LLM_CHAT_COMPLEX"] = TimeSpan.FromSeconds(120),    // Code generation
        ["LLM_CHAT_ARCHITECTURE"] = TimeSpan.FromSeconds(180), // Architecture design
        
        // Image Generation
        ["IMAGE_GEN_STANDARD"] = TimeSpan.FromSeconds(30),   // 1024x1024
        ["IMAGE_GEN_LARGE"] = TimeSpan.FromSeconds(60),      // Larger sizes
        
        
        // Vision
        ["VLM_ANALYSIS"] = TimeSpan.FromSeconds(45),          // Image analysis
        
        // Search
        ["WEB_SEARCH"] = TimeSpan.FromSeconds(20),            // Web search
        
        // Build Operations
        ["BUILD_DEBUG"] = TimeSpan.FromSeconds(120),          // Debug build
        ["BUILD_RELEASE"] = TimeSpan.FromSeconds(300),        // Release build with optimization
        
        // Packaging
        ["MSIX_PACKAGE"] = TimeSpan.FromSeconds(60),
        ["SIGNING"] = TimeSpan.FromSeconds(30)
    };
    
    /// <summary>
    /// Get timeout for a specific operation type.
    /// Falls back to default if not configured.
    /// </summary>
    public static TimeSpan GetTimeout(string operationType)
    {
        return OperationTimeouts.TryGetValue(operationType, out var timeout) 
            ? timeout 
            : TimeSpan.FromSeconds(120); // Default fallback
    }
}
```

### Timeout Enforcement

```csharp
public class TimeoutAwareAIClient
{
    private readonly AIServiceClient _client;
    
    public async Task<T> ExecuteWithTimeoutAsync<T>(
        string operationType,
        Func<CancellationToken, Task<T>> operation)
    {
        var timeout = AIOperationTimeouts.GetTimeout(operationType);
        
        using var cts = new CancellationTokenSource(timeout);
        
        try
        {
            return await operation(cts.Token);
        }
        catch (OperationCanceledException) when (!cts.Token.IsCancellationRequested)
        {
            // This was a timeout, not external cancellation
            throw new AIOperationTimeoutException(operationType, timeout);
        }
    }
}
```

---

## 4. Trace ID Propagation

> **INVARIANT**: Every request from Orchestrator → AI Service → Transaction Log MUST include a Trace ID for log correlation and debugging.

### Trace Context

```csharp
public class TraceContext
{
    public string TraceId { get; init; }
    public string ProjectId { get; init; }
    public string TaskId { get; init; }
    public string ParentSpanId { get; init; }
    public List<string> SpanChain { get; init; } = new();
    
    /// <summary>
    /// Creates a child span for nested operations.
    /// </summary>
    public TraceContext CreateChildSpan(string spanName)
    {
        return new TraceContext
        {
            TraceId = TraceId,
            ProjectId = ProjectId,
            TaskId = TaskId,
            ParentSpanId = Guid.NewGuid().ToString("N")[..8],
            SpanChain = new List<string>(SpanChain) { spanName }
        };
    }
}
```

### HTTP Header Propagation

```csharp
public class TracingHttpClient : DelegatingHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        // Get trace context from current scope
        var traceContext = TraceContext.Current;
        
        if (traceContext != null)
        {
            // Add trace headers to ALL AI service requests
            request.Headers.Add("X-Trace-Id", traceContext.TraceId);
            request.Headers.Add("X-Project-Id", traceContext.ProjectId);
            request.Headers.Add("X-Task-Id", traceContext.TaskId);
            request.Headers.Add("X-Parent-Span-Id", traceContext.ParentSpanId);
        }
        
        return await base.SendAsync(request, cancellationToken);
    }
}
```

### AI Service Request with Trace ID

```typescript
// ai-mini-service/index.ts - Request logging with trace ID

interface RequestContext {
    traceId: string;
    projectId: string;
    taskId: string;
    parentSpanId?: string;
}

function logRequest(context: RequestContext, operation: string, data: unknown) {
    console.log(JSON.stringify({
        timestamp: new Date().toISOString(),
        traceId: context.traceId,
        projectId: context.projectId,
        taskId: context.taskId,
        operation,
        data
    }));
}

// Example: Chat endpoint with trace logging
export async function handleChat(request: Request): Promise<Response> {
    const traceId = request.headers.get("X-Trace-Id") || "unknown";
    const projectId = request.headers.get("X-Project-Id") || "unknown";
    const taskId = request.headers.get("X-Task-Id") || "unknown";
    
    logRequest({ traceId, projectId, taskId }, "chat_request", { /* ... */ });
    
    // ... process request ...
    
    logRequest({ traceId, projectId, taskId }, "chat_response", { /* ... */ });
}
```

---

## 5. AI Service Failure Governance

> **INVARIANT**: When the AI Service is unavailable, the system MUST transition to a defined fallback state and follow explicit recovery procedures.

### Failure Detection

```csharp
public class AIServiceHealthMonitor
{
    private readonly AIServiceClient _client;
    private readonly ILogger<AIServiceHealthMonitor> _logger;
    
    public AIServiceHealthStatus LastKnownStatus { get; private set; } = AIServiceHealthStatus.UNKNOWN;
    public DateTime? LastSuccessfulHealthCheck { get; private set; }
    
    public async Task<AIServiceHealthStatus> CheckHealthAsync()
    {
        try
        {
            var health = await _client.GetHealthAsync();
            LastKnownStatus = health.Status;
            LastSuccessfulHealthCheck = DateTime.UtcNow;
            return health.Status;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AI Service health check failed");
            LastKnownStatus = AIServiceHealthStatus.UNAVAILABLE;
            return AIServiceHealthStatus.UNAVAILABLE;
        }
    }
}

public enum AIServiceHealthStatus
{
    UNKNOWN,
    HEALTHY,
    DEGRADED,      // Partial functionality
    UNAVAILABLE    // Not responding
}
```

### Fallback Strategy

```csharp
public class AIServiceFallbackStrategy
{
    /// <summary>
    /// Determines the appropriate fallback when AI service fails.
    /// </summary>
    public FallbackAction DetermineFallback(AIServiceHealthStatus status, BuilderContext context)
    {
        return status switch
        {
            AIServiceHealthStatus.HEALTHY => FallbackAction.Continue(),
            
            AIServiceHealthStatus.DEGRADED => FallbackAction.TransitionTo(
                BuilderState.AI_SERVICE_DEGRADED,
                "AI Service operating in degraded mode. Some features may be unavailable."
            ),
            
            AIServiceHealthStatus.UNAVAILABLE => FallbackAction.TransitionTo(
                BuilderState.AI_SERVICE_UNAVAILABLE,
                "AI Service is not responding. Attempting automatic recovery..."
            ),
            
            _ => FallbackAction.TransitionTo(
                BuilderState.AI_SERVICE_UNAVAILABLE,
                "AI Service status unknown. Running health check..."
            )
        };
    }
}

public record FallbackAction
{
    public bool ShouldTransition { get; init; }
    public BuilderState? TargetState { get; init; }
    public string Message { get; init; }
    
    public static FallbackAction Continue() => new() { ShouldTransition = false };
    
    public static FallbackAction TransitionTo(BuilderState state, string message) => new()
    {
        ShouldTransition = true,
        TargetState = state,
        Message = message
    };
}
```

### Degraded State Definition and Escalation

| State                  | Trigger                                                                                     | Behavior                                                                                              | Recovery                                                                                     |
|------------------------|---------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------|
| `AI_SERVICE_DEGRADED`  | - 3 consecutive health check failures<br>- 3 consecutive request timeouts<br>- 10+ 429 rate‑limit responses | - AI operations continue with exponential backoff<br>- Blueprint generation is **blocked**<br>- UI shows yellow status dot | Auto‑recovery after 1 successful health check; fallback to `AI_SERVICE_UNAVAILABLE` if 10 consecutive failures |
| `AI_SERVICE_UNAVAILABLE` | - Health check timeout (5s)<br>- Process not running<br>- Any request returns 5xx error       | - All AI‑dependent operations are blocked<br>- Orchestrator stays in this state until recovery succeeds | Automatic restart of mini‑service, then retry health check; after 3 failed restarts, wait 60s and retry indefinitely |

**Transition Rules:**
- `AI_SERVICE_DEGRADED` → `AI_GENERATING` after a successful health check.
- `AI_SERVICE_UNAVAILABLE` → `CONFIGURED` after mini‑service restart and successful `/health` call.
- User can always cancel to leave these states and return to `IDLE`.

---

## 6. AI E2E Test Suite Specification

> **INVARIANT**: All AI service integrations MUST have end-to-end tests that verify the complete request/response cycle.

### Test Categories

```csharp
public class AIServiceE2ETests
{
    // === LLM Tests ===
    [Fact]
    public async Task LLM_ChatSimple_ReturnsValidResponse()
    {
        var response = await _client.ChatAsync(
            systemPrompt: "You are a helpful assistant.",
            userPrompt: "Say 'hello'"
        );
        
        Assert.NotNull(response);
        Assert.NotEmpty(response);
    }
    
    [Fact]
    public async Task LLM_ChatCodeGeneration_GeneratesValidCode()
    {
        var response = await _client.ChatAsync(
            systemPrompt: "You are a C# code generator.",
            userPrompt: "Generate a simple ViewModel class"
        );
        
        Assert.NotNull(response);
        Assert.Contains("class", response);
        Assert.Contains("ViewModel", response);
    }
    
    // === Image Generation Tests ===
    [Fact]
    public async Task Image_GenerateStandard_ReturnsValidImage()
    {
        var imageBase64 = await _client.GenerateImageAsync(
            prompt: "A simple app icon",
            size: "1024x1024"
        );
        
        Assert.NotNull(imageBase64);
        Assert.True(imageBase64.Length > 0);
        // Verify it's valid base64 by decoding
        var imageBytes = Convert.FromBase64String(imageBase64);
        Assert.True(imageBytes.Length > 0);
    }
    
    
    // === Vision Tests ===
    [Fact]
    public async Task Vision_AnalyzeImage_ReturnsValidDescription()
    {
        var imageData = await _client.GenerateImageAsync(
            prompt: "A red square",
            size: "1024x1024"
        );
        
        var analysis = await _client.AnalyzeImageAsync(
            prompt: "Describe this image",
            imageData: imageData
        );
        
        Assert.NotNull(analysis);
        Assert.Contains("red", analysis.ToLower());
    }
    
    // === Search Tests ===
    [Fact]
    public async Task Search_Query_ReturnsRelevantResults()
    {
        var results = await _client.SearchAsync(
            query: "WinUI 3 documentation",
            numResults: 5
        );
        
        Assert.NotNull(results);
        Assert.NotEmpty(results);
    }
    
    // === Error Handling Tests ===
    [Fact]
    public async Task ServiceUnavailable_ReturnsAppropriateError()
    {
        // Stop the AI service
        await _serviceManager.StopServiceAsync();
        
        await Assert.ThrowsAsync<AIServiceUnavailableException>(
            () => _client.ChatAsync("test", "test")
        );
        
        // Restart for other tests
        await _serviceManager.StartServiceAsync();
    }
    
    [Fact]
    public async Task Timeout_ExceedsLimit_ThrowsTimeoutException()
    {
        await Assert.ThrowsAsync<AIOperationTimeoutException>(
            () => _timeoutClient.ExecuteWithTimeoutAsync(
                "LLM_CHAT_SIMPLE",
                async (ct) => {
                    await Task.Delay(TimeSpan.FromSeconds(60), ct);
                    return "result";
                }
            )
        );
    }
    
    // === Trace ID Tests ===
    [Fact]
    public async Task Request_WithTraceId_PropagatesToLogs()
    {
        var traceId = $"test_{Guid.NewGuid():N}";
        
        await _client.ChatAsync(
            systemPrompt: "test",
            userPrompt: "test",
            traceId: traceId
        );
        
        // Verify trace ID appears in logs
        var logEntry = await _logReader.FindByTraceIdAsync(traceId);
        Assert.NotNull(logEntry);
        Assert.Equal(traceId, logEntry.TraceId);
    }
}
```

---

## 7. ai-service.exe Package Integrity

> **INVARIANT**: The ai-service.exe MUST verify its own integrity on startup and reject execution if tampered.

### Startup Integrity Check

```typescript
// ai-mini-service/integrity.ts

import { createHash } from "crypto";
import { readFileSync, existsSync } from "fs";

interface IntegrityCheckResult {
    valid: boolean;
    expectedHash: string;
    actualHash: string;
    timestamp: string;
}

export async function verifyIntegrity(): Promise<IntegrityCheckResult> {
    // The expected hash is embedded at build time
    const EXPECTED_HASH = process.env.AI_SERVICE_HASH || "";
    
    // Calculate actual hash of running executable
    const executablePath = process.execPath;
    const executableData = readFileSync(executablePath);
    const actualHash = createHash("sha256").update(executableData).digest("hex");
    
    const valid = EXPECTED_HASH === "" || actualHash === EXPECTED_HASH;
    
    if (!valid) {
        console.error("⚠️ INTEGRITY CHECK FAILED");
        console.error(`Expected: ${EXPECTED_HASH}`);
        console.error(`Actual:   ${actualHash}`);
        console.error("The ai-service.exe may have been tampered with!");
    }
    
    return {
        valid,
        expectedHash: EXPECTED_HASH,
        actualHash,
        timestamp: new Date().toISOString()
    };
}
```

### C# Client Verification

```csharp
public class AIServiceIntegrityValidator
{
    private readonly string _servicePath;
    private readonly string _expectedHash;
    
    public AIServiceIntegrityValidator(string servicePath, string expectedHash)
    {
        _servicePath = servicePath;
        _expectedHash = expectedHash;
    }
    
    public async Task<IntegrityResult> VerifyBeforeStartAsync()
    {
        var exePath = Path.Combine(_servicePath, "ai-service.exe");
        
        if (!File.Exists(exePath))
        {
            return IntegrityResult.Failed("ai-service.exe not found");
        }
        
        // Calculate SHA256 hash
        using var sha256 = System.Security.Cryptography.SHA256.Create();
        using var stream = File.OpenRead(exePath);
        var hashBytes = await sha256.ComputeHashAsync(stream);
        var actualHash = Convert.ToHexString(hashBytes).ToLower();
        
        if (actualHash != _expectedHash.ToLower())
        {
            return IntegrityResult.Failed(
                $"Hash mismatch. Expected: {_expectedHash}, Actual: {actualHash}");
        }
        
        // Verify signature (Windows Authenticode)
        var signatureValid = VerifyAuthenticodeSignature(exePath);
        if (!signatureValid)
        {
            return IntegrityResult.Failed("Authenticode signature verification failed");
        }
        
        return IntegrityResult.Success();
    }
    
    private bool VerifyAuthenticodeSignature(string filePath)
    {
        // Use Windows CryptoAPI to verify Authenticode signature
        // Implementation depends on Windows API interop
        // Return true if signature is valid or if running in development mode
        #if DEBUG
        return true; // Skip signature check in debug builds
        #else
        return WinTrust.VerifyEmbeddedSignature(filePath);
        #endif
    }
}

public record IntegrityResult
{
    public bool IsValid { get; init; }
    public string? ErrorMessage { get; init; }
    
    public static IntegrityResult Success() => new() { IsValid = true };
    public static IntegrityResult Failed(string error) => new() { IsValid = false, ErrorMessage = error };
}
```

### Integration with Service Startup

```csharp
public class AIMiniServiceManager
{
    public async Task<bool> StartServiceAsync()
    {
        // 1. Verify integrity BEFORE starting
        var integrity = await _integrityValidator.VerifyBeforeStartAsync();
        
        if (!integrity.IsValid)
        {
            _logger.LogError("AI Service integrity check failed: {Error}", integrity.ErrorMessage);
            // Show user-friendly error
            await ShowIntegrityErrorDialog(integrity.ErrorMessage);
            return false;
        }
        
        // 2. Proceed with normal startup
        // ... existing startup code ...
    }
}
```

---

## References

- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Parent document
- [StateMachine.md](./StateMachine.md) — Builder states and transitions
- [AI_SERVICE_LAYER.md](../AI_SERVICE_LAYER.md) — AI capabilities via user-configured providers
- [AI_MINI_SERVICE_IMPLEMENTATION.md](../AI_MINI_SERVICE_IMPLEMENTATION.md) — Complete TypeScript implementation

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from ORCHESTRATION_ENGINE.md as part of documentation reorganization |