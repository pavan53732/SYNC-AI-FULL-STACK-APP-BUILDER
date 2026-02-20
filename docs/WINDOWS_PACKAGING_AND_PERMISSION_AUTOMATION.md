# WINDOWS PACKAGING AND PERMISSION AUTOMATION

> **Layer 2.5: The Packaging & Manifest Subsystem**
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Defines the relationship between AI Construction Engine (Primary Brain) and Runtime Safety Kernel (Enforcement Layer).
>
> _Governs the transition from "Compile" to "Distribute". Automates Identity, Capabilities, and Signing. The Packaging Pipeline is owned by the Runtime Safety Kernel._

---

## 1. Core Responsibilities

### AI-Primary Ownership of Packaging

> **The AI Construction Engine proposes capabilities, the Runtime Safety Kernel enforces packaging rules.**

| Packaging Stage | Owner | Description |
|-----------------|-------|-------------|
| Capability inference | AI Construction Engine | Code analysis determines needs |
| Manifest generation | Runtime Safety Kernel | Enforces correct structure |
| Certificate management | Runtime Safety Kernel | Hard enforcement of signing |
| MSIX creation | Runtime Safety Kernel | Deterministic packaging |
| Error recovery | AI Construction Engine | Agent decides how to adapt |

This subsystem bridges the gap between raw binaries and deployable Windows apps. It ensures that every app built by Sync AI is:

1.  **Identity-Correct**: Has a valid `Package.appxmanifest`.
2.  **Permission-Aware**: Only requests necessary capabilities (Least Privilege).
3.  **Signed**: Has a valid trusted signature for installation.
4.  **Distributable**: Is packaged as a clean `.msixbundle`.

### Architectural Position

Top: **Layer 2 (Execution Kernel)**  
**Layer 2.5 (Packaging & Manifest)**  
Bottom: **Layer 1 (Filesystem)**

---

## 2. Manifest Engine

The Manifest Engine programmatically generates and updates `Package.appxmanifest`.

### 2.1 Schema Generation

It generates the XML structure enforcing:

- **Identity**: Unique Name, Publisher, Version.
- **Properties**: DisplayName, PublisherDisplayName, Logo.
- **Applications**: Executable entry point, VisualElements.
- **Capabilities**: Sandbox permissions.

### 2.2 Invariants

1.  **Deterministic Version Increment**: Version increments **only on mutation events** (code patch, capability change, or schema break). Preview-only builds do NOT increment version.
2.  **Identity Consistency**: Publisher ID must match the signing certificate.
3.  **Visual Alignment**: Assets (Logos) defined in manifest must exist on disk.

---

## 3. Capability Inference Engine (CIE)

The CIE analyzes code to determine required OS permissions, preventing runtime crashes due to missing capabilities.

### 3.1 Inference Logic

    **Critical Ordering**:
    1.  **Debug/Preview**: Reactive (Inference runs on failure).
    2.  **Release/Packaging**: Proactive (Inference runs **BEFORE** `BUILD_RELEASE`).

    **Rule**: For Release packaging, inference MUST execute before build to ensure the manifest is final.

    It triggers after Roslyn indexing:

1.  **Scan**: Check `api_usage` table in Code Intelligence.
2.  **Map**: Match Windows API calls to Capabilities.
3.  **Inject**: Add `<Capability Name="..." />` to Manifest.

### 3.2 Mapping Table (Examples)

| Windows API Namespace         | Required Capability     | Reason                    |
| ----------------------------- | ----------------------- | ------------------------- |
| `Windows.Storage`             | `broadFileSystemAccess` | File I/O outside app data |
| `Windows.Devices.Geolocation` | `location`              | GPS / LatLong access      |
| `Windows.Media.Capture`       | `webcam`                | Camera access             |
| `Windows.Networking`          | `internetClient`        | Http/Socket requests      |
| `Windows.Devices.Bluetooth`   | `bluetooth`             | BT connectivity           |

### 3.3 Safety Guard

- **Over-Permissioning Check**: Warn if a capability is requested manually but no API usage is detected.
- **Missing-Permission Check**: Error if API usage is detected but capability is missing (auto-fixable).

---

## 4. MSIX Automation Pipeline

### 4.1 Packaging Flow

1.  **Prepare**: Gather build output (binaries, assets, manifest).
2.  **MakePri**: Generate `resources.pri` (Package Resource Index).
3.  **MakeAppx**: Bundle into `.msix`.
4.  **Sign**: Apply certificate.

### 4.2 Certificate Policy (Mandatory)

    1.  **Strict Enforcement**: A project cannot complete the packaging phase without a valid signing certificate.
    2.  **Auto-Generation**: If no certificate exists, the system auto-generates one.
    3.  **Identity Match**: If a certificate exists, it must match the Publisher in the manifest.
    4.  **Validation**: The certificate is validated before packaging begins.
    5.  **Expiration Monitoring**: Certificates are monitored for approaching expiration (30-day warning threshold). UI shows warning badge when certificate is within 30 days of expiration.

    ### 4.2.1 Certificate Health Monitoring

    The system continuously monitors certificate health:

    | Check | Frequency | Warning Threshold | Action |
    | :--- | :--- | :--- | :--- |
    | **Expiration Date** | On app launch + daily | 30 days before expiry | UI warning badge + toast notification |
    | **Certificate Chain** | Before packaging | N/A | Fail packaging if chain invalid |
    | **Private Key Access** | Before signing | N/A | Fail signing if key inaccessible |

    **Health Status UI Integration**:
    - **Green**: Certificate valid for > 30 days
    - **Yellow**: Certificate expires within 30 days (warning badge in Settings)
    - **Red**: Certificate expired or invalid (blocking error, regeneration required)

    ### 4.3 Certificate Lifecycle Rules

    *   **Scope**: Certificates are scoped per project. Global reuse is forbidden.
    *   **Storage**: Private keys are stored encrypted; public keys are in the project repo.
    *   **Cleanup**: On project deletion, the certificate is removed from the Windows Certificate Store **ONLY IF** no other installed apps reference its thumbprint (Reference Counting). Certificates are tagged with `SyncAI_Project_{GUID}` to ensure scoped removal.

    ### 4.4 Version Increment Rules (Deterministic)

    To prevent double-increment collisions, the following rules apply:

    | Trigger Event | Action | Version Component | Example |
    | :--- | :--- | :--- | :--- |
    | **Code Patch** | Increment Patch | `x.y.Z+1` | `1.0.0` → `1.0.1` |
    | **Capability Change** | Increment Minor | `x.Y+1.0` | `1.0.1` → `1.1.0` |
    | **Schema Breaking** | Increment Major | `X+1.0.0` | `1.1.0` → `2.0.0` |

    > **Rule**: If a build involves both a Code Patch and a Capability Change, the **highest order** increment wins (Minor).

---

## 5. Error Classification

| Error Code | Classification      | Description                                      | Auto-Fix                     |
| :--------- | :------------------ | :----------------------------------------------- | :--------------------------- |
| `PKG001`   | Manifest Invalid    | XML structure corrupt or missing required fields | Regenerate Default           |
| `PKG002`   | Capability Mismatch | Code uses API without Manifest declaration       | Inject Capability            |
| `PKG003`   | Asset Missing       | Initial logo/icon files missing from Assets/     | Generate Placeholders        |
| `PKG004`   | Sign Failed         | Certificate expired or password wrong            | Prompt User / Regen Dev Cert |
| `PKG005`   | Identity Mismatch   | Manifest Publisher != Cert Publisher             | Update Manifest              |

---

## 6. Elevation Policy

### 6.1 Operations Requiring Elevation

The following operations require administrator privileges:

| Operation | Reason | User Experience |
| :--- | :--- | :--- |
| **Certificate Installation** | Installs cert to LocalMachine\TrustedPeople | One-time prompt per project |
| **MSIX Installation** | System-wide app installation | UAC prompt when user clicks "Install Now" |
| **BroadFileSystemAccess** | Grants app-wide file system access | User must enable in Windows Settings |

### 6.2 Operations NOT Requiring Elevation

The following operations run without elevation:

| Operation | Reason |
| :--- | :--- |
| **Build & Compilation** | User-space operation, no system changes |
| **Preview Launch** | Shadow copy runs in user context |
| **MSIX Creation** | File creation only, no installation |
| **Certificate Generation** | Creates PFX file in user directory |
| **Project Deletion** | Removes files from user workspace |

### 6.3 Elevation UX Guidelines

1. **Never auto-prompt**: Only request elevation when user explicitly triggers an action
2. **Clear context**: Show why elevation is needed before UAC prompt
3. **Graceful degradation**: If elevation denied, explain what functionality is unavailable
4. **Remember choices**: Don't re-prompt for same operation within same session

### 6.4 Certificate Installation Flow

```
User clicks "Install App" or "Trust Certificate"
    ↓
Check if certificate already trusted
    ↓ (No)
Show confirmation: "This app needs a trusted certificate to run. Install certificate?"
    ↓ (User confirms)
UAC Prompt (for LocalMachine store installation)
    ↓ (Approved)
Install certificate to TrustedPeople store
    ↓
Proceed with MSIX installation or app launch
```

### 6.5 Packaging Failure Classification

| Error | Recovery Strategy | Behavior |
| :--- | :--- | :--- |
| **MAKEAPPX_DISK** | Prompt user + wait + retry | Pause with user guidance - disk space/I/O issue, retry after user action |
| **SIGNING_ERROR** | Prompt user + wait + retry | Pause with user guidance - certificate or key issue, retry after user action |
| **CAPABILITY_MISSING** | Auto-inject + retry | Inject capability + rebuild manifest (continuous retry) |
| **MANIFEST_INVALID** | Auto-regenerate + retry | Regenerate from template (continuous retry) |

**Continuous Retry Principle**: All errors trigger continuous retry until success or user cancellation. User-action-required errors (disk, certificate) pause the retry loop and show guidance. Once the user resolves the issue, retry continues automatically. The system NEVER gives up on its own - only user cancellation stops the process.

---

## 7. Integration Contract

### Input (from Orchestrator)

```json
{
  "TaskId": "PKG_JOB_123",
  "ProjectRoot": "C:\\Users\\User\\.syncai\\workspaces\\MyApp",
  "BuildArtifacts": "bin\\Release\\net8.0-windows10.0.19041.0",
  "CertificatePath": "packaging\\certificate.pfx"
}
```

### Output (to Filesystem)

- `MyApp_1.0.0.0_x64.msix`
- `MyApp_1.0.0.0_x64.cer` (Public key)

---

## 8. Windows Sandbox Failure Path (CRITICAL)

> **INVARIANT**: Windows Sandbox is an OPTIONAL execution environment. The system MUST handle sandbox unavailability gracefully without blocking app execution.

### 8.1 Sandbox Availability Detection

Before attempting sandboxed execution, the system checks:

```csharp
public class WindowsSandboxDetector
{
    public async Task<SandboxAvailability> CheckAvailabilityAsync()
    {
        // 1. Check if Windows Sandbox feature is enabled
        var featureEnabled = await IsWindowsSandboxFeatureEnabledAsync();

        // 2. Check if hardware virtualization is available
        var virtualizationAvailable = await IsVirtualizationAvailableAsync();

        // 3. Check if sandbox executable exists
        var executableExists = File.Exists(
            Path.Combine(Environment.SystemDirectory, "WindowsSandbox.exe"));

        return new SandboxAvailability
        {
            IsAvailable = featureEnabled && virtualizationAvailable && executableExists,
            FeatureEnabled = featureEnabled,
            VirtualizationAvailable = virtualizationAvailable,
            ExecutableExists = executableExists,
            UnavailableReason = DetermineReason(featureEnabled, virtualizationAvailable, executableExists)
        };
    }
}
```

### 8.2 Sandbox Execution Decision Matrix

| Sandbox Available | App Has Capabilities | Execution Mode | Rationale |
|-------------------|---------------------|----------------|-----------|
| ✅ Yes | ✅ Yes | **Sandboxed** | Full isolation for capability-requiring apps |
| ✅ Yes | ❌ No | **Direct** | No sandbox needed for simple apps |
| ❌ No | ✅ Yes | **Direct with Warning** | User warned about capability usage without isolation |
| ❌ No | ❌ No | **Direct** | Normal execution, no sandbox needed |

### 8.3 Sandbox Failure Recovery Flow

```
SANDBOX EXECUTION REQUEST
         │
         ▼
┌────────────────────────────────┐
│ Check Sandbox Availability     │
└────────────────────────────────┘
         │
         ├── AVAILABLE ──────────────────────────────┐
         │                                           │
         │                                           ▼
         │                        ┌────────────────────────────────┐
         │                        │ Execute in Windows Sandbox     │
         │                        └────────────────────────────────┘
         │                                           │
         │                                           ├── SUCCESS ──→ Return Result
         │                                           │
         │                                           └── FAILURE ──→ Log Error
         │                                                            │
         │                                                            ▼
         │                                          ┌────────────────────────────────┐
         │                                          │ FALLBACK: Direct Execution     │
         │                                          │ Emit SandboxFallbackEvent      │
         │                                          └────────────────────────────────┘
         │                                                            │
         │                                                            ▼
         │                                                          Return Result
         │
         └── UNAVAILABLE ────────────────────────────┐
                                                     │
                                                     ▼
                              ┌────────────────────────────────┐
                              │ Check: App Has Capabilities?   │
                              └────────────────────────────────┘
                                     │
                                     ├── HAS CAPABILITIES ────┐
                                     │                        │
                                     │                        ▼
                                     │     ┌────────────────────────────────────┐
                                     │     │ Emit: SandboxUnavailableEvent      │
                                     │     │ Show: Warning toast to user        │
                                     │     │ Log: Capability usage without      │
                                     │     │      sandbox isolation             │
                                     │     └────────────────────────────────────┘
                                     │                        │
                                     │                        ▼
                                     │              Execute Directly
                                     │
                                     └── NO CAPABILITIES ────┐
                                                              │
                                                              ▼
                                              Execute Directly (No Warning Needed)
```

### 8.4 Fallback Implementation

```csharp
public class SandboxExecutionService
{
    public async Task<ExecutionResult> ExecuteAppAsync(
        string appPath,
        SandboxPolicy policy)
    {
        var availability = await _sandboxDetector.CheckAvailabilityAsync();

        if (!availability.IsAvailable)
        {
            // Log sandbox unavailability
            _logger.LogWarning("Windows Sandbox unavailable: {Reason}", availability.UnavailableReason);

            // Check if app has capabilities requiring isolation
            var capabilities = await _capabilityEngine.GetAppCapabilitiesAsync(appPath);

            if (capabilities.Any())
            {
                // Emit event for audit trail
                await _eventBus.PublishAsync(new SandboxUnavailableEvent
                {
                    AppPath = appPath,
                    RequiredCapabilities = capabilities,
                    Reason = availability.UnavailableReason,
                    FallbackMode = ExecutionFallbackMode.Direct
                });

                // Show user warning (non-blocking toast)
                await _toastService.ShowWarningAsync(
                    "App Preview Running Without Sandbox Isolation",
                    $"This app requires {string.Join(", ", capabilities)} but Windows Sandbox is unavailable. " +
                    "Running directly for preview purposes.");
            }

            // Execute directly as fallback
            return await ExecuteDirectAsync(appPath, policy);
        }

        // Attempt sandboxed execution
        try
        {
            return await ExecuteInSandboxAsync(appPath, policy);
        }
        catch (SandboxExecutionException ex)
        {
            _logger.LogError(ex, "Sandbox execution failed, falling back to direct execution");

            // Emit fallback event
            await _eventBus.PublishAsync(new SandboxFallbackEvent
            {
                AppPath = appPath,
                Exception = ex.Message,
                FallbackMode = ExecutionFallbackMode.Direct
            });

            // Fallback to direct execution
            return await ExecuteDirectAsync(appPath, policy);
        }
    }
}
```

### 8.5 Events for Audit Trail

```csharp
public record SandboxUnavailableEvent : BuilderEvent
{
    public string AppPath { get; init; }
    public List<string> RequiredCapabilities { get; init; }
    public string Reason { get; init; }
    public ExecutionFallbackMode FallbackMode { get; init; }
}

public record SandboxFallbackEvent : BuilderEvent
{
    public string AppPath { get; init; }
    public string Exception { get; init; }
    public ExecutionFallbackMode FallbackMode { get; init; }
}

public enum ExecutionFallbackMode
{
    None,           // No fallback needed
    Direct,         // Fell back to direct execution
    Cancelled       // Execution cancelled due to safety concerns
}
```

### 8.6 User Communication

| Scenario | User Message | Severity |
|----------|--------------|----------|
| Sandbox unavailable, app has capabilities | "App Preview Running Without Sandbox Isolation" | Warning (Toast) |
| Sandbox execution failed, fallback succeeded | "Preview running in standard mode" | Info (Toast) |
| Both sandbox and direct failed | "Preview failed to start" | Error (Dialog) |

### 8.7 Why This Matters

> **Rationale**: Windows Sandbox is not available on all Windows editions (requires Pro/Enterprise) and may be disabled by policy. The system must gracefully degrade to direct execution rather than failing completely. This ensures the preview functionality works for all users, with appropriate warnings when isolation is unavailable.

---

## 9. Reference
