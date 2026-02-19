# WINDOWS PACKAGING AND PERMISSION AUTOMATION

> **Layer 2.5: The Packaging & Manifest Subsystem**
>
> _Governs the transition from "Compile" to "Distribute". Automates Identity, Capabilities, and Signing._

---

## 1. Core Responsibilities

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

    **Critical Ordering**: Capability inference is executed **immediately after a successful build and before packaging begins**.

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

| Error | Auto-Fixable | Behavior |
| :--- | :--- | :--- |
| **MAKEAPPX_DISK** | No | Pause with user guidance - disk space/I/O issue requires user action |
| **SIGNING_ERROR** | No | Pause with user guidance - certificate or key issue requires user action |
| **CAPABILITY_MISSING** | Yes | Inject capability + rebuild manifest (continuous retry) |
| **MANIFEST_INVALID** | Yes | Regenerate from template (continuous retry) |

**Continuous Retry Principle**: All errors trigger continuous retry. User-action-required errors (disk, certificate) pause the retry loop and show guidance. Once the user resolves the issue, retry continues automatically. There are no FATAL states that permanently stop the process.

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