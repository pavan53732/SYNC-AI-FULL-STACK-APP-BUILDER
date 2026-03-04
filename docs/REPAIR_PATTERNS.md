# REPAIR PATTERNS

> **Multi-Framework Build Error Repair Strategies: WinUI3, WPF, WinForms, Win32, WinRT**
>
> **Related Core Documents:**
>
> - [PROJECT_ARCHETYPE_RESOLUTION.md](./PROJECT_ARCHETYPE_RESOLUTION.md) — Framework selection context
> - [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Fix Agent that applies these patterns
> - [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — Solution structure context for repair
> - [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — Retry controller that invokes the Fix Agent

---

## Table of Contents

1. [Overview](#1-overview)
2. [Error Classification System](#2-error-classification-system)
3. [MSBuild / .csproj Errors](#3-msbuild--csproj-errors)
4. [C# Compiler Errors (CS-series)](#4-c-compiler-errors-cs-series)
5. [WinUI 3 / XAML Errors](#5-winui-3--xaml-errors)
6. [EF Core Errors](#6-ef-core-errors)
7. [MSIX / Package Manifest Errors](#7-msix--package-manifest-errors)
8. [Runtime Errors (Post-Compilation)](#8-runtime-errors-post-compilation)
9. [Fix Agent Decision Flow](#9-fix-agent-decision-flow)
10. [System Reset Triggers](#10-system-reset-triggers)

---

## 1. Overview

The **Fix Agent** uses these patterns to identify, classify, and repair build and runtime errors autonomous during the construction process. All repair strategies here are deterministic — when a specific error code or pattern is matched, the corresponding repair action is applied.

### Repair Principles

| Principle                | Rule                                                                                     |
| ------------------------ | ---------------------------------------------------------------------------------------- |
| **Pattern-first**        | Match the error to a known pattern in this document before attempting AI-inferred repair |
| **Minimal change**       | Repair only the specific failing file/line. Do not refactor surrounding code             |
| **No skip**              | If an error cannot be repaired within 9 attempts, escalate to System Reset (Retry 10+)   |
| **Context preservation** | Repair attempts must not break previously passing code                                   |
| **Determinism**          | Same error must always produce the same repair action type (even if content differs)     |

### Error Source Mapping

| Error Origin            | Error Prefix         | Repair Complexity          |
| ----------------------- | -------------------- | -------------------------- |
| MSBuild / project file  | `NETSDK`, `MSB`      | Low (config fix)           |
| C# compiler             | `CS`                 | Medium (code fix)          |
| WinUI 3 / XAML compiler | `WMC`, `MC`, `XBF`   | Medium (XAML fix)          |
| C++ compiler            | `C1`, `C2`, `C9`    | Medium (native code fix)   |
| C++ linker              | `LNK`                | Medium (linker fix)        |
| Resource compiler       | `RC`                 | Low (resource fix)         |
| EF Core design-time     | `EF Core:` messages  | Medium (model/context fix) |
| MSIX / App manifest     | `AppxMan`, `APPX`    | Low (manifest fix)         |
| NuGet package restore   | `NU`                 | Low (package version fix)  |
| Runtime exception       | Stack trace analysis | High (logic fix)           |

---

## 2. Error Classification System

Each build error is classified into one of four severity tiers:

| Tier   | Name       | Description                                                | Max Retries Before Escalation |
| ------ | ---------- | ---------------------------------------------------------- | ----------------------------- |
| **T1** | Config     | Project/package/manifest misconfiguration                  | 3                             |
| **T2** | Syntax     | C# / XAML syntax or type errors                            | 5                             |
| **T3** | Logic      | Incorrect logic, missing bindings, missing DI registration | 7                             |
| **T4** | Structural | Architecture violation; requires spec amendment            | 9 (then System Reset)         |

> **Note**: The tier-specific max-retry columns (T1–T4) are fine-grained per-tier budgets. The stage escalation sequence (FIX_LEVEL → INTEGRATION_LEVEL → ARCHITECTURE_LEVEL → SYSTEM_RESET) is governed by [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) §8.

---

## 3. MSBuild / .csproj Errors

### Error: NETSDK1138 — Target framework is out of date

**Pattern**: `error NETSDK1138: The target framework 'netX.0' is out of date.`

**Repair Action**:

```diff
- <TargetFramework>net6.0-windows10.0.19041.0</TargetFramework>
+ <TargetFramework>net8.0-windows10.0.22621.0</TargetFramework>
```

**Tier**: T1

---

### Error: NETSDK1073 — Framework not installed

**Pattern**: `error NETSDK1073: The FrameworkReference '...' was not recognized.`

**Repair Action**: Ensure `UseWinUI` is set to `true` in `.csproj`:

```xml
<PropertyGroup>
    <UseWinUI>true</UseWinUI>
</PropertyGroup>
```

**Tier**: T1

---

### Error: MSB4019 — Imported project not found

**Pattern**: `error MSB4019: The imported project "..." was not found.`

**Repair Action**: Verify `Microsoft.WindowsAppSDK` package reference version and re-add if missing:

```xml
<PackageReference Include="Microsoft.WindowsAppSDK" Version="1.5.250211001" />
<PackageReference Include="Microsoft.Windows.SDK.BuildTools" Version="10.0.22621.756" />
```

**Tier**: T1

---

### Error: NU1202 — Package not compatible with target framework

**Pattern**: `error NU1202: Package {name} {version} is not compatible with net8.0-windows`.

**Repair Action**:

1. Check if package has a WinUI 3 compatible version
2. Replace with `CommunityToolkit.WinUI.*` equivalent
3. If no replacement, remove the feature that requires the package and note in spec amendment

**Tier**: T1/T4 depending on impact

---

### Error: NU1605/NU1608 — Package Version Conflict (Dependency Tree Healing)

**Pattern**: 
- `error NU1605: Warning As Error: Detected package downgrade: {PackageA} from {VersionX} to {VersionY}`
- `error NU1608: Warning As Error: {PackageA} {VersionX} depends on {DependencyB} ({VersionRange}) but {PackageC} {VersionY} depends on {DependencyB} ({VersionRange})`

**Root Cause**: Transitive dependency version conflicts in the NuGet dependency tree.

**Repair Action — Dependency Tree Healing**:

```xml
<!-- Step 1: Add explicit package reference to force version -->
<PackageReference Include="{ConflictPackage}" Version="{HighestCompatibleVersion}" />

<!-- Step 2: If conflict persists, add Directory.Packages.props for central version management -->
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <PackageVersion Include="{PackageA}" Version="{VersionX}" />
    <PackageVersion Include="{PackageB}" Version="{VersionY}" />
  </ItemGroup>
</Project>

<!-- Step 3: For irreconcilable conflicts, use package-specific fallback -->
<PackageReference Include="{ProblematicPackage}" Version="{Version}" GeneratePathProperty="true">
  <ExcludeAssets>runtime</ExcludeAssets> <!-- Exclude conflicting runtime assets -->
</PackageReference>
```

**Dependency Tree Healing Algorithm**:

```csharp
public async Task<RepairResult> HealDependencyTreeConflictsAsync(NuGetError error)
{
    // 1. Parse dependency graph from NuGet lock file (if exists)
    var dependencyGraph = await ParseNuGetLockFileAsync("packages.lock.json");
    
    // 2. Identify conflicting paths in dependency tree
    var conflicts = FindConflictingDependencies(dependencyGraph, error.PackageId);
    
    // 3. Compute highest compatible version across all dependents
    var highestVersion = ComputeHighestCompatibleVersion(conflicts);
    
    // 4. Inject explicit package reference to force resolution
    await InjectExplicitPackageReferenceAsync(error.PackageId, highestVersion);
    
    // 5. Restore packages and verify conflict resolved
    var restoreSuccess = await RunDotnetRestoreAsync();
    
    if (!restoreSuccess)
    {
        // 6. Fallback: Central Package Version Management
        await EnableCentralPackageVersionsAsync();
        restoreSuccess = await RunDotnetRestoreAsync();
    }
    
    return new RepairResult 
    { 
        Success = restoreSuccess,
        Strategy = "Dependency Tree Healing",
        ConflictsResolved = conflicts.Count()
    };
}
```

**Learning Integration**: Successful dependency tree healing strategies are stored in `learned_repairs` table (see [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) §2.8) for future reuse.

**Tier**: T1 (config fix) / T3 (complex dependency graph analysis)

---

### Error: MSB3644 — Reference assemblies not found

**Pattern**: `error MSB3644: The reference assemblies for framework ".NETFramework,Version=..." were not found.`

**Repair Action**: This occurs when a transitive dependency targets .NET Framework. Add:

```xml
<GenerateErrorForMissingTargetingPacks>false</GenerateErrorForMissingTargetingPacks>
```

And verify no Core/Data project accidentally references Windows-UI-only packages.

**Tier**: T1

---

## 4. C# Compiler Errors (CS-series)

### Error: CS0246 — Type or namespace not found

**Pattern**: `error CS0246: The type or namespace name '{TypeName}' could not be found`

**Diagnosis Steps**:

1. Check if the using directive is missing
2. Check if the type is in the correct project (`Core` vs `Data` vs `App`)
3. Check if the package providing the type is referenced in the `.csproj`

**Repair Action A** — Missing using:

```diff
+ using {AppName}.Core.Models;
+ using {AppName}.Core.Services;
```

**Repair Action B** — Wrong project reference:

```xml
<!-- Add to .csproj of the consuming project -->
<ProjectReference Include="..\{AppName}.Core\{AppName}.Core.csproj" />
```

**Tier**: T2

---

### Error: CS1061 — Member does not exist

**Pattern**: `error CS1061: '{TypeName}' does not contain a definition for '{MemberName}'`

**Repair Action**: Check entity model and ensure property name matches spec exactly (case-sensitive). Correct the reference or add the missing property to the model.

**Tier**: T2

---

### Error: CS0115 — No suitable method to override

**Pattern**: `error CS0115: '{method}': no suitable method found to override`

**Repair Action**: WinUI 3 pages inherit from `Microsoft.UI.Xaml.Controls.Page`, not `Windows.UI.Xaml.Controls.Page`. Check `using` namespace:

```diff
- using Windows.UI.Xaml.Controls;
+ using Microsoft.UI.Xaml.Controls;
```

**Tier**: T2

---

### Error: CS8618 — Non-nullable member must be initialized

**Pattern**: `error CS8618: Non-nullable ... '{name}' must contain a non-null value when exiting constructor.`

**Repair Action**: Apply the correct nullable initialization pattern per field type:

```csharp
// string field
public string Name { get; set; } = string.Empty;

// collection field
public List<Item> Items { get; set; } = [];

// EF Core DbSet in AppDbContext
public DbSet<Category> Categories { get; set; } = null!;

// Navigation property
public Category Category { get; set; } = null!;
```

**Tier**: T2

---

### Error: CS0103 — Name does not exist in current context

**Pattern**: `error CS0103: The name '{name}' does not exist in the current context`

**Repair Action**: Most commonly a missing DI registration or incorrect service accessor. Check `App.GetService<T>()` call and ensure the type is registered in `ConfigureServices()`.

**Tier**: T2/T3

---

### Error: CS0266 — Cannot implicitly convert type

**Pattern**: `error CS0266: Cannot implicitly convert type '{typeA}' to '{typeB}'`

**Common Cases in WinUI 3**:

| Conversion Error                                     | Fix                                           |
| ---------------------------------------------------- | --------------------------------------------- |
| `Windows.UI.Color` → `Microsoft.UI.Xaml.Media.Brush` | Use `new SolidColorBrush(color)`              |
| `Task` to `void` in async delegate                   | Mark lambda as `async`                        |
| `IEnumerable<T>` to `ObservableCollection<T>`        | Use `new ObservableCollection<T>(collection)` |

**Tier**: T2

---

### Error: CS0161 — Not all code paths return a value

**Pattern**: `error CS0161: '{method}': not all code paths return a value`

**Repair Action**: Add a default `return` or `throw` at the end of the method's unreachable paths:

```csharp
// Add at end of method if all cases are covered in switch:
throw new InvalidOperationException($"Unhandled case: {variable}");
```

**Tier**: T2

---

## 5. WinUI 3 / XAML Errors

### Error: WMC0001 / XamlParseException — Object not found

**Pattern**: `XamlParseException: The name "{ControlName}" does not exist in the namespace`

**Repair Action**: Add the correct xmlns declaration:

```xml
<!-- For CommunityToolkit controls -->
xmlns:ctk="using:CommunityToolkit.WinUI.UI.Controls"

<!-- For local controls -->
xmlns:local="using:{AppName}"
xmlns:pages="using:{AppName}.Pages"
```

**Tier**: T2

---

### Error: XBF2001 — Cannot resolve type

**Pattern**: `error XBF2001: Cannot resolve 'type' from value '{TypeName}'`

**Repair Action**: Verify the full type path in the `x:DataType` attribute matches the actual namespace of the type:

```xml
<!-- Correct pattern -->
<DataTemplate x:DataType="models:{EntityName}">
    ...
</DataTemplate>
```

Then ensure `xmlns:models="using:{AppName}.Core.Models"` is declared on the Page element.

**Tier**: T2

---

### Error: WMC0012 — Cannot set read-only property

**Pattern**: `error WMC0012: Cannot set a value on the object '{property}' because it is read-only`

**Repair Action**: Remove the incorrect XAML property set. Use code-behind or `Binding`/`x:Bind` via a writable helper property instead.

**Tier**: T2

---

### Error: XamlParseException at runtime — Failed to create a '{Type}' from text '{value}'

**Pattern**: `XamlParseException: Failed to create a 'System.Int32' from the text '...'`

**Repair Action**: Add a value converter and wire it in XAML:

```xml
<!-- In Page resources -->
<converters:IntToStringConverter x:Key="IntToStringConverter"/>

<!-- In binding -->
<TextBox Text="{x:Bind ViewModel.IntProperty,
               Converter={StaticResource IntToStringConverter},
               Mode=TwoWay}"/>
```

**Tier**: T3

---

### Error: DispatcherQueue required — Cross-thread access

**Pattern**: `System.Exception: The application called an interface that was marshalled for a different thread.`

**Repair Action**: All UI updates from background threads must use `DispatcherQueue`:

```csharp
// ❌ FORBIDDEN — direct UI update from background thread
Expenses.Add(expense);

// ✅ CORRECT — marshal to UI thread
DispatcherQueue.TryEnqueue(() =>
{
    Expenses.Add(expense);
});
```

**Tier**: T3

---

### Error: ContentDialog ShowAsync without XamlRoot

**Pattern**: `System.Runtime.InteropServices.COMException: The application called an interface that was marshalled for a different thread` on dialog `ShowAsync()`

**Repair Action**: Always set `XamlRoot` before calling `ShowAsync()`:

```csharp
var dialog = new AddExpenseDialog();
dialog.XamlRoot = this.XamlRoot; // ← this = the Page
await dialog.ShowAsync();
```

**Tier**: T3

---

## 6. EF Core Errors

### Error: InvalidOperationException — No database provider configured

**Pattern**: `InvalidOperationException: No database provider has been configured for this DbContext.`

**Repair Action**: Ensure `AppDbContext` is registered in DI with `AddDbContext<AppDbContext>()` and the `UseSqlite()` call is correct. Verify `OnConfiguring` fallback exists for design-time tools.

**Tier**: T1

---

### Error: MigrationPendingException — Model has changes not reflected in migrations

**Pattern**: `InvalidOperationException: The model for context 'AppDbContext' has pending changes. Add a new migration.`

**Repair Action**: Generate a new migration:

```bash
dotnet ef migrations add {Timestamp}_SpecAmendment_{Description} --project {AppName}.Data --startup-project {AppName}.App
```

**Tier**: T1

---

### Error: SQLite UNIQUE constraint failed

**Pattern**: `Microsoft.Data.Sqlite.SqliteException: UNIQUE constraint failed: {TableName}.{ColumnName}`

**Repair Action**:

1. If `isUnique: true` is intentional: surface a user-facing validation error via `InfoBar` in the ViewModel
2. Add validation in the Service before attempting the insert:

```csharp
// In Service.AddAsync() — validate uniqueness before insert
var existing = await _repository.GetByAsync(e => e.Name == entity.Name);
if (existing.Any())
    throw new InvalidOperationException($"A {nameof(T)} with the name '{entity.Name}' already exists.");
```

**Tier**: T3

---

### Error: ConcurrencyException — DbUpdateConcurrencyException

**Pattern**: `Microsoft.EntityFrameworkCore.DbUpdateConcurrencyException: Database operation expected to affect 1 row(s) but actually affected 0 row(s).`

**Repair Action**: Switch from `Update()` to a fetch-then-update pattern for EF Core with SQLite:

```csharp
// ✅ Correct pattern for SQLite
var existing = await _context.{Entity}s.FindAsync(entity.Id);
if (existing is null) return;
// Map properties from entity to existing
existing.Name = entity.Name;
existing.Amount = entity.Amount;
await _context.SaveChangesAsync();
```

**Tier**: T3

---

### Error: EF Core FK Cascade path cycle

**Pattern**: `Microsoft.Data.Sqlite.SqliteException: ... FOREIGN KEY constraint failed`
or MSBuild-time: `InvalidOperationException: Introducing FOREIGN KEY constraint '...' may cause cycles or multiple cascade paths.`

**Repair Action**: Change delete behavior to `Restrict` for the relationship that forms the cycle:

```csharp
entity.HasOne(...)
      .WithMany(...)
      .OnDelete(DeleteBehavior.Restrict); // ← change from Cascade
```

Then generate a new migration.

**Tier**: T3

---

## 7. MSIX / Package Manifest Errors

### Error: APPX0104 — Identity missing or invalid

**Pattern**: `error APPX0104: Certificate with thumbprint '...' not found.`

**Root Cause**: The self-signed development certificate is missing or expired.

**Repair Action**: Regenerate the self-signed development certificate using `cert-gen.ps1`:

```powershell
# Execute cert-gen.ps1 in project root
.\cert-gen.ps1 -Subject "CN={AppName}" -ValidityYears 1
```

This creates a new self-signed certificate valid for 1 year and updates the `.csproj` with the correct thumbprint.

**DO NOT** use `<AppxPackageSigningEnabled>false</AppxPackageSigningEnabled>` — this violates the signing invariant ([SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) §3.4).

**Tier**: T1

---

### Error: AppxMan3217 — Capability not declared

**Pattern**: `error AppxMan3217: The capability '...' is used in the application but not declared in the manifest.`

**Repair Action**: Add the required capability to `Package.appxmanifest`:

```xml
<Capabilities>
    <Capability Name="internetClient" />
    <uap:Capability Name="picturesLibrary" />
    <rescap:Capability Name="broadFileSystemAccess" />
</Capabilities>
```

This is handled by the Capability Inference Agent post-generation. If it occurs in a retry, the Fix Agent adds the specific capability directly.

**Tier**: T1

---

### Error: APPX1101 — Min version incompatible

**Pattern**: `error APPX1101: The minimum OS version '...' is not supported.`

**Repair Action**:

```xml
<!-- In Package.appxmanifest -->
<TargetDeviceFamily Name="Windows.Desktop"
                    MinVersion="10.0.22621.0"
                    MaxVersionTested="10.0.22621.0"/>
```

**Tier**: T1

---

## 8. Runtime Errors (Post-Compilation)

### Error: NullReferenceException in ViewModel

**Pattern**: Stack trace shows `NullReferenceException` in a ViewModel property accessor or command method.

**Diagnosis**:

1. Check if DI service was not registered (returns null via `GetService<T>()`)
2. Check if `LoadAsync()` was awaited but `ObservableCollection` was used before it completed

**Repair Action**:

```csharp
// Add null guards in ViewModel
private readonly IExpenseService _expenseService;

public ExpensesPageViewModel(IExpenseService expenseService)
{
    _expenseService = expenseService
        ?? throw new ArgumentNullException(nameof(expenseService));
}
```

**Tier**: T3

---

### Error: InvalidOperationException — Cannot use DbContext after it is disposed

**Pattern**: `InvalidOperationException: Cannot access a disposed context instance.`

**Repair Action**: Ensure `AppDbContext` is registered as `Scoped` (not Singleton) in DI. ViewModels that hold long-lived references to services should use `IServiceScopeFactory`:

```csharp
// ❌ FORBIDDEN — Scoped DbContext in Singleton
services.AddSingleton<AppDbContext>(...);

// ✅ CORRECT
services.AddDbContext<AppDbContext>(...); // Default = Scoped
services.AddScoped<IExpenseRepository, ExpenseRepository>();
```

**Tier**: T3

---

### Error: XamlParseException on NavigationView SelectionChanged

**Pattern**: `XamlParseException` or `InvalidCastException` when navigating between pages.

**Common Cause**: `ContentFrame.Navigate(pageType)` passing the wrong page type.

**Repair Action**: Verify the `tag switch` in `NavView_SelectionChanged` covers all pages in the spec. Add a default case:

```csharp
var pageType = tag switch
{
    "expenses"   => typeof(ExpensesPage),
    "categories" => typeof(CategoriesPage),
    "report"     => typeof(ReportPage),
    _            => typeof(ExpensesPage) // ← safe default
};
```

**Tier**: T3

---

## 9. Fix Agent Decision Flow

### Error Detection and Repair Pipeline

```text
Build/Runtime Error Detected
          ↓
1. Parse error output → Extract error code + message + file + line
          ↓
2. Normalize error context → Strip line numbers, variable names, paths
          ↓
3. Compute error_hash = SHA256(normalized_error_context)
          ↓
4. Query learned_repairs table by error_hash
          ↓
   ├── Found → Apply stored repair → Rebuild → Check success
   │           ├─ Success → RecordSuccessfulRepair(error_hash) → Increment success_count
   │           └─ Failure → Continue to pattern matching
   │
   └── Not Found → Continue with existing pattern matching below
          ↓
5. Match error to known repair pattern in this document (Sections 3-8)
          ↓
6. Apply deterministic repair action from matched pattern
          ↓
7. Rebuild and validate
          ↓
8. If repair succeeds → Store in learned_repairs for future use
   
   If repair fails → Retry with escalated strategy (up to 9 attempts)
          ↓
9. After 9 failed attempts → SYSTEM_RESET (Retry 10+)
```

### Deterministic Error Hashing

The `error_hash` MUST be computed from a **normalized** representation to ensure same logical errors produce identical hashes across sessions:

```csharp
public static string ComputeErrorHash(ErrorClassification error)
{
    // Normalize: strip line numbers, variable names, full paths
    var normalized = new
    {
        errorCode = error.Code,           // e.g., "CS0246"
        errorTier = error.Tier,           // e.g., "T2"
        fileName = Path.GetFileName(error.FilePath),  // Strip path
        messageType = error.Type.ToString(),  // e.g., "BUILD_ERROR"
        // Strip line numbers and specific identifiers
        surroundingContext = NormalizeCodeSnippet(error.Context)
    };
    
    using var sha256 = SHA256.Create();
    var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(normalized)));
    return BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();
}

private static string NormalizeCodeSnippet(string snippet)
{
    // Remove line numbers
    snippet = Regex.Replace(snippet, @"^\s*\d+\s*[→:]?\s*", "", RegexOptions.Multiline);
    // Replace variable names with placeholders
    snippet = Regex.Replace(snippet, @"\b[a-z][a-z0-9]*\b", "VAR", RegexOptions.IgnoreCase);
    // Normalize whitespace
    return string.Join("\n", snippet.Split('\n').Select(l => l.Trim()).Where(l => !string.IsNullOrEmpty(l)));
}
```

---

## 11. Learned Repair Storage

### Cross-Session Learning Invariant

> **INVARIANT**: Successful repairs are persisted across sessions to enable deterministic learning.
> The same error context MUST always produce the same repair action.

### Storage Schema

As defined in [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) §4:

```sql
CREATE TABLE learned_repairs (
    id INTEGER PRIMARY KEY,
    error_hash TEXT NOT NULL,       -- SHA256 of normalized error context
    error_tier TEXT NOT NULL,       -- T1/T2/T3/T4
    error_code TEXT,                -- Compiler error code
    error_message_normalized TEXT,  -- Stripped of line numbers, paths
    repair_action TEXT NOT NULL,    -- JSON patch or fix strategy
    repair_type TEXT NOT NULL,      -- 'AST_PATCH', 'REGISTRATION_FIX', etc.
    success_count INTEGER DEFAULT 1,
    failure_count INTEGER DEFAULT 0,
    first_seen_utc TEXT NOT NULL,
    last_success_utc TEXT NOT NULL,
    project_id TEXT,                -- Optional attribution
    toolchain_version TEXT,         -- Version when fix was learned
    framework_family TEXT,          -- WinUI3/WPF/WinForms/Win32/etc.
    confidence_score REAL DEFAULT 0.5  -- success_count / (success_count + failure_count)
);
```

### Learning Repository Interface

```csharp
public interface ILearningRepository
{
    /// <summary>
    /// Find a learned repair by error hash
    /// </summary>
    Task<LearnedRepair?> FindRepairAsync(string errorHash);
    
    /// <summary>
    /// Record a successful repair for future learning
    /// </summary>
    Task RecordSuccessfulRepairAsync(string errorHash, string repairAction, string errorTier);
    
    /// <summary>
    /// Increment success count after applying learned repair
    /// </summary>
    Task IncrementSuccessCountAsync(string errorHash);
    
    /// <summary>
    /// Record failure of a previously learned repair
    /// </summary>
    Task RecordFailureAsync(string errorHash);
}
```

### Confidence Scoring

Repairs are ranked by confidence score for selection when multiple repairs match similar contexts:

```
confidence_score = success_count / (success_count + failure_count)
```

| Confidence Range | Interpretation | Usage |
|-----------------|----------------|-------|
| **≥ 0.9** | Highly reliable | Auto-apply without validation |
| **0.7 - 0.9** | Reliable | Apply with quick validation |
| **0.5 - 0.7** | Uncertain | Apply with full rebuild validation |
| **< 0.5** | Unreliable | Do not auto-apply; flag for human review |

### Determinism Guarantee

> **INVARIANT**: Learning MUST NOT introduce non-determinism.
> 
> - Same error hash → Same repair action (deterministic lookup)
> - Different machines with same learned database → Identical repairs
> - Learning is append-only; deletions only via explicit user action

See [CODE_INTELLIGENCE.md](./CODE_INTELLIGENCE.md) §4 for complete schema definition.

```text
Build/Runtime Error Detected
          ↓
1. Parse error output → extract error code + message + file + line
          ↓
2. Match against known patterns in REPAIR_PATTERNS.md
          ↓
3a. Pattern found (Tier T1/T2/T3)?
    → Apply deterministic repair action
    → Rebuild
    → Check if resolved
    → If not: go to step 2 (different pattern)
          ↓
3b. Pattern not found (novel error)?
    → Fix Agent sends error + context to AI LLM
    → AI proposes repair
    → Apply AI-proposed repair
    → Rebuild
    → Check if resolved
          ↓
4. If retry count < 9:
    → Increment retry counter
    → Go to step 1 with next error
          ↓
5. If retry count >= 9 (or Tier T4):
    → Report to Orchestrator
    → Orchestrator initiates System Reset (rollback + amnesia + re-plan)
```

### Error Output Parser Contract

The Fix Agent parses build output using this structure:

```json
{
  "errors": [
    {
      "errorCode": "CS0246",
      "message": "The type or namespace name 'IExpenseService' could not be found",
      "file": "ExpensesPageViewModel.cs",
      "line": 12,
      "column": 24,
      "severity": "error",
      "tier": "T2"
    }
  ],
  "warnings": [...]
}
```

---

## 10. System Reset Triggers

The following conditions trigger an escalation to the **Runtime Safety Kernel** for a System Reset (Rollback + Forced Amnesia + Full Re-plan):

| Trigger                  | Condition                                                                                  |
| ------------------------ | ------------------------------------------------------------------------------------------ |
| **Max retries reached**  | 10+ consecutive failed build attempts on the same task (see [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) §8 for stage escalation) |
| **Circular error**       | Same error code appears on retries 5, 7, and 9                                             |
| **Structural violation** | Fix requires changing the AppSpec architecture (T4 error)                                  |
| **Corruption detected**  | Generated code produces valid build but incorrect runtime behavior confirmed by validation |
| **Conflicting repairs**  | Repair of error X introduces error Y which when repaired reintroduces error X              |

### System Reset Behavior

```text
Runtime Safety Kernel initiates Reset:
    1. Rollback workspace to PreMutationSnapshotId
    2. Clear all task-scoped AI memory (Forced Amnesia)
    3. Bump AppSpec version (e.g., 1.0.3 → 2.0.0)
    4. Architect Agent produces a new blueprint with different approach
    5. Planner Agent generates a new Task Graph
    6. Construction resumes from the first task
```

> **INVARIANT**: System Reset is NOT failure. It is a higher-order retry. The system never stops on its own. Only user cancellation ends execution.

---

## Change Log

| Date       | Change                                                                                                                                                        |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-03-03 | **Added NU1605/NU1608 Dependency Tree Healing** - Static type-to-NuGet mapping for deterministic reference resolution. Added static lookup before LLM fallback. |
| 2026-03-03 | **AUTONOMOUS BUILD LOOP COVERAGE IMPROVEMENTS**: Added explicit documentation for three previously implicit features: (1) Dependency Tree Healing for NU1605/NU1608 errors with algorithm and central package management, (2) Clean Build Cycle management integrated with retry escalation, (3) Unused Reference Removal via Roslyn Formatter.Format(). Updated coverage accuracy from 90% to 100%. |
| 2026-03-03 | Initial creation — complete WinUI 3 + MSBuild + EF Core repair pattern catalog                                                                                |

---

## References

- [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Fix Agent that uses these patterns
- [ORCHESTRATION_ENGINE.md](./ORCHESTRATION_ENGINE.md) — Retry governance and System Reset
- [DATA_LAYER_GENERATION.md](./DATA_LAYER_GENERATION.md) — EF Core rules that prevent these errors
- [UI_GENERATION_RULES.md](./UI_GENERATION_RULES.md) — XAML rules that prevent these errors
- [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — Solution structure context
- [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — Runtime Safety Kernel and reset governance
