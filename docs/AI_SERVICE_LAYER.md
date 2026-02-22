# AI SERVICE LAYER

> **Layer 6.6: The AI Capability Bridge**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> _Governs the communication between the Windows Desktop App and user-configured OpenAI-compatible AI providers via a local HTTP mini-service._

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture Position](#2-architecture-position)
3. [Communication Protocol](#3-communication-protocol)
4. [Available AI Capabilities](#4-available-ai-capabilities)
5. [Integration Pattern](#5-integration-pattern)
6. [Error Handling](#6-error-handling)
7. [Performance Considerations](#7-performance-considerations)
8. [Security Model](#8-security-model)
9. [API Contract](#9-api-contract)
10. [Cross-References](#10-cross-references)
11. [Process Lifecycle Management (AUTO-START)](#11-process-lifecycle-management-auto-start)

---

## 1. Overview

### Purpose

The AI Service Layer bridges the gap between the **Windows Desktop Application** (C# / .NET 8 / WinUI 3) and user-configured **OpenAI-compatible AI providers** via the `openai` npm SDK (Node.js / TypeScript).

### Key Principle

> **User-Configured AI Providers**
>
> Users configure their own AI providers (OpenRouter, OpenAI, or any OpenAI-compatible endpoint) in the app's **Settings > AI Settings** page. The system supports three independent model slots: **Primary** (code/chat), **Vision** (UI analysis), and **Image Generation** (icons/splash).

### Why This Layer Exists

| Component | Technology | Role |
|-----------|------------|------|
| **Sync AI Desktop** | C# / .NET 8 / WinUI 3 | Main application, UI, Orchestrator, Build System |
| **AI Mini Service** | Bun / Node.js + `openai` SDK | AI capabilities (LLM, Vision, Image Gen, Search) |

The `openai` npm SDK is a **Node.js/TypeScript library**, which cannot be used directly in a C#/.NET application. Therefore, we need a **local HTTP service** that wraps the SDK and exposes AI capabilities via REST API.

---

## 2. Architecture Position

### Layer Stack (Updated)

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 7: User Interface (WinUI 3 / XAML)                   │
│  ─ Prompt input, real-time preview, version timeline         │
│  ─ Settings > AI Settings (user-configured providers)       │
├─────────────────────────────────────────────────────────────┤
│  Layer 6.5: AI Construction Engine (PRIMARY INTELLIGENCE)   │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Blueprint Designer    → Adaptive architecture design    ││
│  │ Multi-Agent System    → Specialized code generation     ││
│  │ Planning Engine       → Task graph construction         ││
│  │ Retry Controller      → Error recovery strategy (1-9)   ││
│  │ AI Service Client     → HTTP client to Layer 6.6        ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  Layer 6.6: AI Service Layer                                │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Local HTTP Service    → localhost:3001                  ││
│  │ openai SDK            → OpenAI-compatible providers     ││
│  │ 3-Slot Config:                                          ││
│  │   🧠 Primary  (code/chat)   → user-configured          ││
│  │   👁️ Vision   (UI analysis) → user-configured          ││
│  │   🎨 Image Gen (icons)      → user-configured          ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  Layer 6: Runtime Safety Kernel (ENFORCEMENT LAYER)         │
│  ─ Validates all mutations, enforces deterministic execution │
├─────────────────────────────────────────────────────────────┤
│  Layer 5: Code Intelligence (Roslyn)                         │
│  ─ AST parsing, symbol indexing, impact analysis             │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: Patch Engine                                       │
│  ─ Transactional code mutations, conflict detection          │
├─────────────────────────────────────────────────────────────┤
│  Layer 2.5: Packaging & Manifest Engine                      │
│  ─ Manifest generator, Capability inference, MSIX bundler    │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Execution Kernel                                   │
│  ─ In-process MSBuild, NuGet restore, app execution          │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: Filesystem Sandbox + SQLite Graph DB               │
│  ─ Isolated projects, snapshots, symbol/dependency storage   │
└─────────────────────────────────────────────────────────────┘
```

### Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│           SYNC AI DESKTOP (C# / .NET 8)                      │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ AI Construction Engine                              │   │
│   │ ├─ Architect Agent                                  │   │
│   │ ├─ Frontend Agent                                   │   │
│   │ ├─ Backend Agent                                    │   │
│   │ ├─ Fix Agent                                        │   │
│   │ └─ AI Service Client (HTTP)                         │   │
│   └─────────────────────────────────────────────────────┘   │
│                           │                                  │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ Settings > AI Settings (User-Configured)            │   │
│   │ ├─ 🧠 Primary:  model / baseURL / apiKey            │   │
│   │ ├─ 👁️ Vision:   model / baseURL / apiKey            │   │
│   │ └─ 🎨 Image Gen: model / baseURL / apiKey           │   │
│   └─────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           │ HTTP POST (localhost:3001)      │
│                           ▼                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ http://localhost:3001/api/...
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           AI MINI SERVICE (Bun / Node.js)                    │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ openai SDK (User-Configured Providers)              │   │
│   │ ├─ 🧠 primaryClient  → LLM Chat Completions        │   │
│   │ ├─ 👁️ visionClient   → Vision Language Model       │   │
│   │ ├─ 🎨 imageClient    → Image Generation            │   │
│   │ └─ 🔍 searchClient   → Web Search (via Primary)    │   │
│   └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Communication Protocol

### HTTP Endpoints

| Endpoint | Method | Purpose | Model Slot Used |
|----------|--------|---------|----------------|
| `/api/chat` | POST | LLM chat completions | 🧠 Primary |
| `/api/chat/stream` | POST | Streaming LLM responses | 🧠 Primary |
| `/api/generate-image` | POST | Image generation | 🎨 Image Gen |
| `/api/vision` | POST | Image analysis (VLM) | 👁️ Vision |
| `/api/search` | POST | Web search | 🧠 Primary |
| `/api/config` | POST | Push AI provider config from desktop app | — |
| `/health` | GET | Service health check | — |

### Request/Response Format

All requests use JSON format:

```typescript
// Request Header
Content-Type: application/json

// Response Header
Content-Type: application/json
```

---

## 4. Available AI Capabilities

### 4.1 LLM (Large Language Model)

**Endpoint:** `POST /api/chat`

**Request:**
```json
{
  "messages": [
    { "role": "assistant", "content": "You are a helpful code generator..." },
    { "role": "user", "content": "Generate a MVVM view model for a todo list" }
  ],
  "thinking": { "type": "disabled" }
}
```

**Response:**
```json
{
  "success": true,
  "content": "Here's the generated ViewModel...",
  "usage": { "totalTokens": 1500 }
}
```

**Use Cases:**
- Intent parsing
- Architecture design
- Code generation
- Error analysis
- Fix suggestions

---

### 4.2 Image Generation

**Endpoint:** `POST /api/generate-image`

**Request:**
```json
{
  "prompt": "A modern app icon with blue gradient",
  "size": "1024x1024"
}
```

**Response:**
```
Binary image data (PNG)
```

**Supported Sizes:**
- `1024x1024` (Square)
- `768x1344` (Portrait)
- `1344x768` (Landscape)
- `1440x720` (Wide)

**Use Cases:**
- App icon generation
- UI placeholder images
- Visual assets

---

---

### 4.5 VLM (Vision Language Model)

**Endpoint:** `POST /api/vision`

**Request:**
```json
{
  "prompt": "Analyze this UI screenshot and describe the layout",
  "imageUrl": "data:image/png;base64,iVBORw0KGgo..."
}
```

**Response:**
```json
{
  "success": true,
  "content": "This screenshot shows a master-detail layout..."
}
```

**Use Cases:**
- UI screenshot analysis
- Design feedback
- Visual debugging
- OCR

---

### 4.6 Web Search

**Endpoint:** `POST /api/search`

**Request:**
```json
{
  "query": "WinUI 3 best practices 2024",
  "num": 10
}
```

**Response:**
```json
{
  "success": true,
  "results": [
    {
      "url": "https://...",
      "name": "WinUI 3 Best Practices",
      "snippet": "...",
      "host_name": "learn.microsoft.com"
    }
  ]
}
```

**Use Cases:**
- Documentation lookup
- Best practices research
- Error solution search

---

## 5. Integration Pattern

### C# Client Implementation

```csharp
public class AIServiceClient
{
    private readonly HttpClient _httpClient;
    private const string BaseUrl = "http://localhost:3001";
    
    public AIServiceClient()
    {
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri(BaseUrl),
            Timeout = TimeSpan.FromSeconds(120)
        };
    }
    
    // ── Configuration ──────────────────────────────────────
    
    /// <summary>
    /// Sends AI provider settings to the service. Called on app startup
    /// and whenever the user changes Settings > AI Settings.
    /// </summary>
    public async Task<bool> ConfigureAsync(AIProviderSettings settings)
    {
        var request = new
        {
            primary = settings.Primary != null ? new
            {
                modelName = settings.Primary.ModelName,
                baseUrl = settings.Primary.BaseUrl,
                apiKey = settings.Primary.ApiKey
            } : null,
            vision = settings.Vision != null ? new
            {
                modelName = settings.Vision.ModelName,
                baseUrl = settings.Vision.BaseUrl,
                apiKey = settings.Vision.ApiKey
            } : null,
            imageGen = settings.ImageGen != null ? new
            {
                modelName = settings.ImageGen.ModelName,
                baseUrl = settings.ImageGen.BaseUrl,
                apiKey = settings.ImageGen.ApiKey
            } : null
        };
        
        var response = await _httpClient.PostAsJsonAsync("/api/config", request);
        response.EnsureSuccessStatusCode();
        
        var result = await response.Content.ReadFromJsonAsync<ConfigResponse>();
        return result.Configured.Primary && result.Configured.Vision;
    }
    
    // ── Chat (Primary Model) ──────────────────────────────
    
    public async Task<string> ChatAsync(string systemPrompt, string userPrompt)
    {
        var request = new
        {
            messages = new[]
            {
                new { role = "system", content = systemPrompt },
                new { role = "user", content = userPrompt }
            }
        };
        
        var response = await _httpClient.PostAsJsonAsync("/api/chat", request);
        response.EnsureSuccessStatusCode();
        
        var result = await response.Content.ReadFromJsonAsync<ChatResponse>();
        return result.Content;
    }
    
    // ── Image Generation (Image Gen Model) ────────────────
    
    public async Task<byte[]> GenerateImageAsync(string prompt, string size = "1024x1024")
    {
        var request = new { prompt, size };
        var response = await _httpClient.PostAsJsonAsync("/api/generate-image", request);
        response.EnsureSuccessStatusCode();
        
        var result = await response.Content.ReadFromJsonAsync<ImageResponse>();
        return Convert.FromBase64String(result.ImageBase64);
    }
    
    // ── Vision Analysis (Vision Model) ────────────────────
    
    public async Task<string> AnalyzeImageAsync(string prompt, byte[] imageData)
    {
        var request = new
        {
            prompt,
            imageUrl = $"data:image/png;base64,{Convert.ToBase64String(imageData)}"
        };
        var response = await _httpClient.PostAsJsonAsync("/api/vision", request);
        response.EnsureSuccessStatusCode();
        
        var result = await response.Content.ReadFromJsonAsync<VisionResponse>();
        return result.Content;
    }
    
    // ── Web Search (Primary Model) ────────────────────────
    
    public async Task<string> SearchAsync(string query)
    {
        var request = new { query };
        var response = await _httpClient.PostAsJsonAsync("/api/search", request);
        response.EnsureSuccessStatusCode();
        
        var result = await response.Content.ReadFromJsonAsync<SearchResponse>();
        return result.Content;
    }
    
    // ── Health Check ──────────────────────────────────────
    
    public async Task<HealthResponse> GetHealthAsync()
    {
        var response = await _httpClient.GetAsync("/health");
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<HealthResponse>();
    }
    
    public async Task<bool> IsHealthyAsync()
    {
        try
        {
            var health = await GetHealthAsync();
            return health.Success;
        }
        catch
        {
            return false;
        }
    }
}

// ── DTOs ──────────────────────────────────────────────────

public record AIProviderSettings
{
    public AIProviderSlot? Primary { get; init; }
    public AIProviderSlot? Vision { get; init; }
    public AIProviderSlot? ImageGen { get; init; }
}

public record AIProviderSlot
{
    public string ModelName { get; init; }
    public string BaseUrl { get; init; }
    public string ApiKey { get; init; }
}

public record ConfigResponse
{
    public bool Success { get; init; }
    public ConfiguredSlots Configured { get; init; }
}

public record ConfiguredSlots
{
    public bool Primary { get; init; }
    public bool Vision { get; init; }
    public bool ImageGen { get; init; }
}

public record HealthResponse
{
    public bool Success { get; init; }
    public string Status { get; init; }
    public string Version { get; init; }
    public ConfiguredSlots Configured { get; init; }
}

public record ImageResponse
{
    public bool Success { get; init; }
    public string ImageBase64 { get; init; }
}
```

---

## 6. Error Handling

### Error Response Format

```json
{
  "success": false,
  "error": {
    "code": "SERVICE_UNAVAILABLE",
    "message": "AI service is not responding",
    "retryable": true
  }
}
```

### Error Codes

| Code | Description | Recovery |
|------|-------------|----------|
| `SERVICE_UNAVAILABLE` | Mini service not running | Start the service |
| `INVALID_REQUEST` | Malformed request | Fix request format |
| `RATE_LIMITED` | Too many requests | Implement backoff |
| `INTERNAL_ERROR` | SDK error | Retry with backoff |

### Retry Strategy

```csharp
public async Task<T> WithRetryAsync<T>(Func<Task<T>> operation, int maxRetries = 3)
{
    for (int i = 0; i < maxRetries; i++)
    {
        try
        {
            return await operation();
        }
        catch (HttpRequestException ex) when (i < maxRetries - 1)
        {
            await Task.Delay(TimeSpan.FromSeconds(Math.Pow(2, i)));
        }
    }
    throw new AIServiceException("Max retries exceeded");
}
```

---

## 7. Performance Considerations

### Latency Targets

| Operation | Target Latency |
|-----------|---------------|
| Health check | < 10ms |
| Chat (simple) | < 2s |
| Chat (complex) | < 10s |
| Image generation | < 15s |
| Vision analysis | < 5s |
| Web search | < 3s |

### Optimization Strategies

1. **Reuse HTTP Client** - Single `HttpClient` instance
2. **Connection Pooling** - Keep-alive connections
3. **Request Batching** - Combine multiple operations
4. **Caching** - Cache frequent responses
5. **Streaming** - Use streaming for long responses

---

## 8. Security Model

### Network Security

| Aspect | Implementation |
|--------|---------------|
| **Binding** | localhost only (127.0.0.1) |
| **Port** | 3001 (configurable) |
| **Protocol** | HTTP (local only, no external access) |
| **Authentication** | Not required (local service) |

### Data Security

| Aspect | Implementation |
|--------|---------------|
| **API Keys** | User-configured per model slot; stored encrypted locally |
| **User Data** | Stays local |
| **Network Calls** | Only to user-configured AI provider endpoints |
| **Logging** | No sensitive data logged (API keys never logged) |

### Service Isolation

```
┌─────────────────────────────────────────────────────────────┐
│ Windows Desktop App (User context)                           │
│         │                                                    │
│         │ HTTP (localhost:3001)                              │
│         ▼                                                    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ AI Mini Service (Same user context)                     │ │
│ │                                                         │ │
│ │ ┌─────────────────────────────────────────────────────┐│ │
│ │ │ openai SDK                                         ││ │
│ │ │ (Receives config from desktop app via /api/config) ││ │
│ │ └─────────────────────────────────────────────────────┘│ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. API Contract

### Complete API Specification

See [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md) for:
- Complete TypeScript implementation
- Bun project setup
- All endpoint implementations
- Error handling code
- Startup scripts

### Service Lifecycle

```
1. Sync AI Desktop starts
2. Check if AI Mini Service is running (GET /health)
3. If not running, start the service:
   - Locate mini-service executable
   - Start as child process
   - Wait for health check to pass
4. Service is now available
5. On shutdown: terminate child process
```

---

## 12. Deterministic Configuration Lifecycle (MANDATORY)

### AIConfigState

The system defines a global AI configuration state:

NOT_CONFIGURED
CONFIGURED
VALIDATED
INVALID
SERVICE_UNAVAILABLE

Blueprint design is BLOCKED unless state == VALIDATED.

---

### Boot Sequence (Required Order)

1. Start mini-service.
2. Load encrypted config.
3. Decrypt in memory.
4. POST /api/config.
5. Perform test LLM call (minimal).
6. Validate all model slots.
7. Set AIConfigState = VALIDATED.

If any slot fails:
• State = INVALID
• Construction is blocked.

---

### Config Change Handling

When user updates AI settings:

1. Cancel active tasks.
2. Transition to SYSTEM_RESET.
3. Restart mini-service.
4. Revalidate configuration.
5. Resume execution.

Hot model swapping during active construction is FORBIDDEN.

> **KEY PRINCIPLE:** The AI Mini Service must be **completely hidden** from the user. It starts automatically when the main app launches and runs in the background with no visible windows.

### 11.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SYNC AI DESKTOP (WinUI 3 App)                         │
│                                                                          │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │ Process Manager (Layer 0 - Below all other layers)            │    │
│   │                                                                 │    │
│   │  ┌─────────────────┐   ┌─────────────────┐   ┌──────────────┐ │    │
│   │  │ AI Mini Service │   │ Health Monitor  │   │ Auto-Restart │ │    │
│   │  │ (Hidden Child)  │   │ (Background)    │   │ (Watchdog)   │ │    │
│   │  └─────────────────┘   └─────────────────┘   └──────────────┘ │    │
│   │                                                                 │    │
│   └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTP localhost:3001
                                    ▼
                    ┌───────────────────────────────┐
                    │   AI MINI SERVICE (Bun)       │
                    │   - NO visible window         │
                    │   - NO console window         │
                    │   - Runs in background        │
                    │   - Hidden from taskbar       │
                    └───────────────────────────────┘
```

### 11.2 WinUI 3 Process Manager Implementation

```csharp
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace SyncAI.Services
{
    /// <summary>
    /// Manages the lifecycle of the AI Mini Service.
    /// Automatically starts, monitors, and restarts the service.
    /// COMPLETELY HIDDEN from the user - no console windows, no taskbar presence.
    /// </summary>
    public class AIMiniServiceManager : IDisposable
    {
        private Process? _serviceProcess;
        private readonly string _servicePath;
        private readonly int _port;
        private readonly HttpClient _healthClient;
        private CancellationTokenSource? _monitorCts;
        private bool _isShuttingDown = false;

        // Windows API for hiding console windows
        [DllImport("kernel32.dll")]
        private static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        private const int SW_HIDE = 0;

        public AIMiniServiceManager(string servicePath, int port = 3001)
        {
            _servicePath = servicePath;
            _port = port;
            _healthClient = new HttpClient
            {
                BaseAddress = new Uri($"http://localhost:{port}"),
                Timeout = TimeSpan.FromSeconds(5)
            };
        }

        /// <summary>
        /// Starts the AI Mini Service automatically on app launch.
        /// The service runs COMPLETELY HIDDEN in the background.
        /// </summary>
        public async Task<bool> StartServiceAsync()
        {
            // Check if already running
            if (await IsServiceHealthyAsync())
            {
                Debug.WriteLine("AI Mini Service already running");
                return true;
            }

            try
            {
                // Start the compiled service executable (HIDDEN background process)
                var startInfo = new ProcessStartInfo
                {
                    // Path to compiled ai-service.exe (embedded in app)
                    FileName = Path.Combine(_servicePath, "ai-service.exe"),
                    Arguments = $"--port={_port}",
                    
                    // CRITICAL: Hide all windows
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    
                    // Redirect output for logging (no console window needed)
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                };

                _serviceProcess = new Process { StartInfo = startInfo };
                
                // Capture output for debugging (logs, not console)
                _serviceProcess.OutputDataReceived += (s, e) => 
                {
                    if (!string.IsNullOrEmpty(e.Data))
                        Debug.WriteLine($"[AI Service] {e.Data}");
                };
                
                _serviceProcess.ErrorDataReceived += (s, e) => 
                {
                    if (!string.IsNullOrEmpty(e.Data))
                        Debug.WriteLine($"[AI Service ERROR] {e.Data}");
                };

                _serviceProcess.Start();
                _serviceProcess.BeginOutputReadLine();
                _serviceProcess.BeginErrorReadLine();

                // Wait for service to be healthy
                var healthy = await WaitForHealthyAsync(TimeSpan.FromSeconds(30));
                
                if (healthy)
                {
                    // Start background health monitor
                    StartHealthMonitor();
                    Debug.WriteLine($"AI Mini Service started on port {_port}");
                }

                return healthy;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to start AI Mini Service: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Background health monitor - auto-restarts service if it crashes
        /// </summary>
        private void StartHealthMonitor()
        {
            _monitorCts = new CancellationTokenSource();
            var token = _monitorCts.Token;

            _ = Task.Run(async () =>
            {
                while (!token.IsCancellationRequested)
                {
                    try
                    {
                        await Task.Delay(TimeSpan.FromSeconds(10), token);
                        
                        if (!await IsServiceHealthyAsync())
                        {
                            Debug.WriteLine("AI Mini Service unhealthy - attempting restart");
                            await RestartServiceAsync();
                        }
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                }
            }, token);
        }

        /// <summary>
        /// Checks if the service is running and healthy
        /// </summary>
        public async Task<bool> IsServiceHealthyAsync()
        {
            try
            {
                var response = await _healthClient.GetAsync("/health");
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Waits for the service to become healthy
        /// </summary>
        private async Task<bool> WaitForHealthyAsync(TimeSpan timeout)
        {
            var endTime = DateTime.UtcNow + timeout;
            
            while (DateTime.UtcNow < endTime)
            {
                if (await IsServiceHealthyAsync())
                    return true;
                    
                await Task.Delay(500);
            }
            
            return false;
        }

        /// <summary>
        /// Restarts the service if it crashes
        /// </summary>
        private async Task RestartServiceAsync()
        {
            if (_isShuttingDown) return;
            
            StopService();
            await Task.Delay(1000);
            await StartServiceAsync();
        }

        /// <summary>
        /// Stops the service gracefully
        /// </summary>
        public void StopService()
        {
            try
            {
                _monitorCts?.Cancel();
                
                if (_serviceProcess != null && !_serviceProcess.HasExited)
                {
                    // Try graceful shutdown first
                    _serviceProcess.CloseMainWindow();
                    
                    // Wait up to 5 seconds for graceful shutdown
                    if (!_serviceProcess.WaitForExit(5000))
                    {
                        // Force kill if needed
                        _serviceProcess.Kill();
                    }
                    
                    _serviceProcess.Dispose();
                    _serviceProcess = null;
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error stopping service: {ex.Message}");
            }
        }

        /// <summary>
        /// Cleanup on app shutdown
        /// </summary>
        public void Dispose()
        {
            _isShuttingDown = true;
            StopService();
            _healthClient.Dispose();
            _monitorCts?.Dispose();
        }
    }
}
```

### 11.3 Integration with App Startup

```csharp
// App.xaml.cs
public partial class App : Application
{
    private AIMiniServiceManager? _aiServiceManager;

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        // Start AI Mini Service IMMEDIATELY on app launch
        // This happens BEFORE any UI is shown
        // The compiled ai-service.exe is embedded in Assets folder
        _aiServiceManager = new AIMiniServiceManager(
            servicePath: Path.Combine(AppContext.BaseDirectory, "Assets"),
            port: 3001
        );

        // Start in background - completely hidden from user
        var serviceStarted = await _aiServiceManager.StartServiceAsync();
        
        if (!serviceStarted)
        {
            // Show error dialog if service fails to start
            await ShowServiceErrorDialog();
            return;
        }

        // Now load the main window
        var window = new MainWindow();
        window.Activate();
    }

    protected override void OnSuspending(object sender, SuspendingEventArgs e)
    {
        // Gracefully stop the service on app exit
        _aiServiceManager?.StopService();
    }
}
```

### 11.4 Single-Executable Deployment (RECOMMENDED)

> **⚠️ IMPORTANT:** The compiled executable approach is the ONLY recommended method for production.
> 
> Do NOT use `bun run dev` scripts in production - it requires Bun runtime on the user's machine and adds unnecessary complexity.

#### Build the Executable

```bash
# In your development environment, compile the service
cd ai-mini-service
bun build ./index.ts --compile --outfile ai-service.exe
```

This creates a **standalone `ai-service.exe`** that:
- ✅ Requires NO Node.js/Bun installation on user's machine
- ✅ Single file - easy to embed in MSIX package
- ✅ Faster startup than interpreted scripts
- ✅ Runs completely hidden in the background
- ✅ Professional production deployment

#### Project Structure

```
SyncAI/
├── SyncAI.Desktop/              (WinUI 3 App)
│   ├── Package.appxmanifest
│   ├── Assets/
│   │   └── ai-service.exe       ← Compiled service embedded here
│   └── ...
│
└── ai-mini-service/             (Dev only - not shipped)
    ├── index.ts
    ├── package.json
    └── ...
```

#### Build Pipeline

```xml
<!-- Include in your .csproj or build script -->
<ItemGroup>
  <Content Include="..\ai-mini-service\ai-service.exe">
    <Link>Assets\ai-service.exe</Link>
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </Content>
</ItemGroup>
```

Or use a pre-build step:

```xml
<Target Name="CompileAIService" BeforeTargets="BeforeBuild">
  <Exec Command="cd ai-mini-service && bun build ./index.ts --compile --outfile ../SyncAI.Desktop/Assets/ai-service.exe" />
</Target>
```

#### Updated Process Manager for Compiled Executable

```csharp
// Simplified - no Bun dependency needed
var startInfo = new ProcessStartInfo
{
    // The exe is embedded in the app package
    FileName = Path.Combine(AppContext.BaseDirectory, "Assets", "ai-service.exe"),
    Arguments = $"--port={_port}",
    
    // CRITICAL: Hide all windows
    CreateNoWindow = true,
    WindowStyle = ProcessWindowStyle.Hidden,
    UseShellExecute = false,
    
    // Optional: Redirect for internal logging
    RedirectStandardOutput = true,
    RedirectStandardError = true
};
```

#### MSIX Packaging

The `ai-service.exe` is just another asset file:

```xml
<!-- Package.appxmanifest -->
<Package>
  <Applications>
    <Application Executable="SyncAI.exe" EntryPoint="SyncAI.App">
      <!-- ai-service.exe is included as content, no manifest changes needed -->
    </Application>
  </Applications>
</Package>
```

### 11.5 Summary: What the User Sees

| Before (Manual) | After (Auto) |
|-----------------|--------------|
| User opens Sync AI | User opens Sync AI |
| User must start service manually | ✅ Service starts automatically |
| Console window visible | ✅ NO windows visible |
| Service appears in taskbar | ✅ Hidden from taskbar |
| User must stop service on exit | ✅ Service stops automatically |
| If service crashes, user must restart | ✅ Auto-restart on crash |

> **RESULT:** The AI Mini Service is now completely transparent to the user. It behaves like any other internal component of the application.

---

## 10. Cross-References

### Related Documentation

| Document | Relationship |
|----------|--------------|
| [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) | Updated layer definitions |
| [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) | AI/Kernel relationship, now includes AI Service |
| [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) | Agents use AI Service for generation |
| [AI_MINI_SERVICE_IMPLEMENTATION.md](./AI_MINI_SERVICE_IMPLEMENTATION.md) | Complete implementation code |
| [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) | Orchestrator coordinates AI Service calls |
| [UI_IMPLEMENTATION.md](./UI_IMPLEMENTATION.md) | UI includes AI Settings page |

### Implementation Dependencies

```
AI_MINI_SERVICE_IMPLEMENTATION.md
    │
    ├── openai (NPM package)
    ├── Bun runtime
    └── TypeScript 5.x

AI_SERVICE_LAYER.md (this document)
    │
    └── Referenced by all agent implementations
```

---

## Document Status

- **Status:** 🔴 CRITICAL FOUNDATION
- **Complexity:** Medium (bridge between C# and Node.js)
- **Risk:** HIGH if skipped (no AI capabilities)
- **Maintainer:** Architecture Team

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-22 | Initial specification for AI Service Layer |
| 2026-02-22 | Integrated with 7-layer architecture as Layer 6.6 |
| 2026-02-22 | Added Section 11: Process Lifecycle Management (Auto-Start) |
| 2026-02-22 | **Changed to compiled executable ONLY** - removed `bun run dev` scripts approach for production |
| 2026-02-23 | **BREAKING: Replaced z-ai-web-dev-sdk with openai SDK** - 3-slot user-configured AI providers |
| 2026-02-23 | **Removed TTS/ASR features** - Simplified to LLM, Vision, Image Gen, Search |
