# STRUCTURED SPEC FORMAT

> **Sync AI Internal Blueprint Format: Canonical JSON Schema for AI-Generated Application Specifications**
>
> **Related Core Documents:**
>
> - [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — AI Construction Engine that consumes this spec
> - [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — Output solution structure produced from this spec
> - [DATA_LAYER_GENERATION.md](./DATA_LAYER_GENERATION.md) — Data layer rules derived from this spec
> - [UI_GENERATION_RULES.md](./UI_GENERATION_RULES.md) — XAML generation rules derived from this spec

---

## Table of Contents

1. [Overview](#1-overview)
2. [Top-Level Spec Schema](#2-top-level-spec-schema)
3. [App Identity](#3-app-identity)
4. [Domain Model](#4-domain-model)
5. [Features](#5-features)
6. [Navigation Graph](#6-navigation-graph)
7. [Permissions](#7-permissions)
8. [Constraints](#8-constraints)
9. [Spec Lifecycle](#9-spec-lifecycle)
10. [Validation Rules](#10-validation-rules)
11. [Full Spec Example](#11-full-spec-example)

---

## 1. Overview

The **Structured Spec** is the canonical internal representation of a user's natural language description after AI parsing and intent extraction. It is the **single source of truth** that all downstream agents (Architect, Planner, Schema, Frontend, Backend, Integration, Fix) consume to generate a complete WinUI 3 application.

### Flow

```text
User Natural Language Input
        ↓
Architect Agent (Spec Extraction)
        ↓
  AppSpec (JSON)       ← THIS DOCUMENT DEFINES THIS
        ↓
Planner Agent (Task Graph)
        ↓
Schema / Frontend / Backend Agents
        ↓
Generated WinUI 3 Application
```

### Design Principles

| Principle         | Rule                                                                                           |
| ----------------- | ---------------------------------------------------------------------------------------------- |
| **Complete**      | All downstream agents must be able to operate from the spec alone without re-querying the user |
| **Versioned**     | Each spec has a version field; mutations during retry cycles produce new versions              |
| **Deterministic** | Same spec must always produce the same solution structure                                      |
| **Validated**     | Spec must pass validation before being dispatched to the Planner                               |
| **Bounded**       | Spec enforces Phase 1 platform constraints (WinUI 3, SQLite, MVVM, MSIX)                       |

---

## 2. Top-Level Spec Schema

```json
{
  "$schema": "https://sync-ai/schemas/app-spec/v1",
  "specVersion": "string (semver, e.g. 1.0.0)",
  "specId": "string (UUID v4)",
  "createdAt": "string (ISO 8601)",
  "appIdentity": { ... },
  "domainModel": { ... },
  "features": [ ... ],
  "navigationGraph": { ... },
  "permissions": [ ... ],
  "constraints": { ... }
}
```

### Field Descriptions

| Field             | Type     | Required | Description                                                    |
| ----------------- | -------- | -------- | -------------------------------------------------------------- |
| `$schema`         | string   | yes      | Fixed schema URI for this spec version                         |
| `specVersion`     | string   | yes      | Semantic version of the spec itself                            |
| `specId`          | UUID     | yes      | Unique ID for this spec instance; used in snapshot referencing |
| `createdAt`       | ISO 8601 | yes      | Timestamp at which the spec was extracted                      |
| `appIdentity`     | object   | yes      | App name, description, branding, icon intent                   |
| `domainModel`     | object   | yes      | All entities, their fields, and relationships                  |
| `features`        | array    | yes      | User-requested features decomposed into capability units       |
| `navigationGraph` | object   | yes      | Pages and page transitions                                     |
| `permissions`     | array    | yes      | Required Windows capabilities inferred from features           |
| `constraints`     | object   | yes      | Locked Phase 1 platform constraints                            |

---

## 3. App Identity

```json
"appIdentity": {
  "name": "string",
  "displayName": "string",
  "description": "string",
  "version": "string (semver, default 1.0.0)",
  "publisher": "string (default CN=SyncAI)",
  "iconIntent": "string (natural language for image gen, e.g. 'modern blue shield icon for a password manager')",
  "splashIntent": "string (natural language for splash screen image gen)",
  "primaryColor": "string (hex color, AI-inferred from iconIntent)",
  "theme": "enum: Light | Dark | SystemDefault"
}
```

### Rules

- `name` must be a valid C# namespace identifier (PascalCase, no spaces).
- `displayName` is what the user sees in the app title bar and MSIX manifest.
- `iconIntent` is passed verbatim to the Frontend Agent's image generation capability.
- `primaryColor` is AI-inferred from app purpose and `iconIntent` using branding heuristics.
- `theme` defaults to `SystemDefault` unless the user explicitly specifies otherwise.

---

## 4. Domain Model

```json
"domainModel": {
  "entities": [
    {
      "name": "string (PascalCase, singular)",
      "description": "string",
      "fields": [
        {
          "name": "string (camelCase)",
          "type": "enum: string | int | long | double | bool | DateTime | Guid | byte[]",
          "isRequired": "bool",
          "isUnique": "bool",
          "isPrimaryKey": "bool",
          "isForeignKey": "bool",
          "referencesEntity": "string (entity name, if isForeignKey)",
          "defaultValue": "any (optional)"
        }
      ],
      "relationships": [
        {
          "type": "enum: OneToOne | OneToMany | ManyToMany",
          "targetEntity": "string",
          "navigationProperty": "string (C# property name)"
        }
      ]
    }
  ]
}
```

### Rules

- Every entity must have exactly one field with `isPrimaryKey: true`.
- Primary keys are always `type: Guid` and named `Id` unless the user specifies otherwise.
- `ManyToMany` relationships always generate a join table entity automatically.
- Entity names map directly to EF Core `DbSet<EntityName>` properties.
- `DateTime` fields use UTC internally; display formatting is handled in the ViewModel.

### Reserved Entity Names (Forbidden)

The following names are reserved by the platform and may not be used as entity names:

| Forbidden Name | Reason                                       |
| -------------- | -------------------------------------------- |
| `User`         | Reserved for future Windows auth integration |
| `App`          | Conflicts with `App.xaml.cs` namespace       |
| `Page`         | Conflicts with WinUI 3 base class            |
| `ViewModel`    | Conflicts with MVVM base class naming        |
| `Service`      | Suffix-only — use `{Name}Service` form       |

---

## 5. Features

```json
"features": [
  {
    "id": "string (kebab-case, e.g. create-expense)",
    "title": "string (human readable)",
    "description": "string",
    "category": "enum: CRUD | Report | Dashboard | Import | Export | Notification | Settings | Auth | Search | FileAccess",
    "entities": ["string (entity names this feature touches)"],
    "uiComponent": "string (name of the Page or Dialog this feature maps to)",
    "requiresPermissions": ["string (Windows capability names)"],
    "isOptional": "bool (false = core feature, true = stretch goal)"
  }
]
```

### Feature Categories and Their Implications

| Category       | Generated Components                                              |
| -------------- | ----------------------------------------------------------------- |
| `CRUD`         | List Page + Detail Page/Dialog + ViewModel + Service + Repository |
| `Report`       | Report Page + Chart Controls + Read-only ViewModel                |
| `Dashboard`    | Dashboard Page with summary cards + aggregation queries           |
| `Import`       | Import Dialog + FileOpenPicker + CSV/JSON parser service          |
| `Export`       | Export command + FileSavePicker + serialization service           |
| `Notification` | Toast notification service + background task if scheduled         |
| `Settings`     | Settings Page + AppSettings model + LocalSettings persistence     |
| `Auth`         | Login Page + WindowsHello or PIN service                          |
| `Search`       | Search box in existing list + full-text EF Core query             |
| `FileAccess`   | FilePicker integration + `broadFileSystemAccess` capability       |

### Phase 1 Feature Constraints

> **CRITICAL**: In Phase 1, the following features are **NOT supported** and must be rejected or simplified at spec extraction time:

| Unsupported Category     | Fallback                              |
| ------------------------ | ------------------------------------- |
| Network / REST API calls | Convert to local data only            |
| Real-time sync           | Convert to manual refresh             |
| Web browser embedding    | Omit                                  |
| Third-party OAuth        | Omit; use local credentials if needed |
| Camera capture           | Use file picker fallback              |
| Map rendering            | Omit; store address as plain text     |

---

## 6. Navigation Graph

```json
"navigationGraph": {
  "shellType": "enum: NavigationView | TabView | SinglePage",
  "mainPage": "string (page name)",
  "pages": [
    {
      "name": "string (PascalCase + 'Page' suffix, e.g. ExpensesPage)",
      "route": "string (kebab-case, e.g. expenses)",
      "title": "string (displayed in nav)",
      "icon": "string (Segoe Fluent Icons glyph name, e.g. Calculator)",
      "isInNavMenu": "bool",
      "parentPage": "string (optional, for drill-down pages)",
      "featureIds": ["string (feature IDs rendered on this page)"],
      "dialogs": [
        {
          "name": "string (PascalCase + 'Dialog' suffix)",
          "trigger": "enum: ButtonClick | RowDoubleTap | ContextMenu",
          "purpose": "string"
        }
      ]
    }
  ],
  "transitions": [
    {
      "from": "string (page name)",
      "to": "string (page name)",
      "trigger": "string (e.g. NavigationView item click, button click)"
    }
  ]
}
```

### Shell Type Selection Rules

| Condition             | Shell Type       |
| --------------------- | ---------------- |
| 3+ top-level sections | `NavigationView` |
| 2–3 peer sections     | `TabView`        |
| Single workflow       | `SinglePage`     |

### Navigation Invariants

- Every page in `pages` must be reachable from `mainPage` via `transitions`.
- The `mainPage` must have `isInNavMenu: true`.
- Drill-down pages (e.g. detail pages) have `isInNavMenu: false` and a non-null `parentPage`.

---

## 7. Permissions

```json
"permissions": [
  {
    "capability": "string (Windows appxmanifest capability name, e.g. picturesLibrary)",
    "reason": "string (why this is needed)",
    "inferredFrom": "string (feature id or entity field that triggered this)"
  }
]
```

### Capability Inference Map

| Feature / Field Type     | Required Capability                |
| ------------------------ | ---------------------------------- |
| `FileAccess` feature     | `broadFileSystemAccess`            |
| `byte[]` image field     | `picturesLibrary`                  |
| `Notification` feature   | _(none required — local toast)_    |
| Network fetch            | `internetClient`                   |
| `Auth` via Windows Hello | _(none — uses WinRT API directly)_ |
| Microphone               | `microphone`                       |
| Camera                   | `webcam`                           |

> **CRITICAL**: Capability inference runs via **static Roslyn analysis** AFTER code generation (not at spec time). This permissions array is the AI's pre-generation estimate. The Capability Inference Agent validates and adjusts the final `Package.appxmanifest` post-generation.

---

## 8. Constraints

```json
"constraints": {
  "targetFramework": "net8.0-windows10.0.22621.0",
  "uiFramework": "WinUI3",
  "minWindowsVersion": "10.0.22621.0",
  "databaseEngine": "SQLite",
  "orm": "EntityFrameworkCore",
  "efCoreVersion": "8.x",
  "architecturalPattern": "MVVM",
  "diContainer": "Microsoft.Extensions.DependencyInjection",
  "packagingFormat": "MSIX",
  "selfContained": true,
  "allowNetworkAccess": false,
  "allowWebContent": false,
  "allowExternalProcesses": false
}
```

> **INVARIANT**: The `constraints` object is **always identical** across all Phase 1 specs. It is defined here for explicitness and documentation purposes. Agents must treat it as read-only. Any spec that deviates from these constraints must be rejected by the Runtime Safety Kernel.

---

## 9. Spec Lifecycle

```text
[User Input]
     ↓
Architect Agent → Draft Spec (v1.0.0)
     ↓
Spec Validator → PASS / FAIL
     ↓ (PASS)
Planner Agent → Task Graph
     ↓
... code generation ...
     ↓ (Build Error Detected, Retry 3+)
Fix Agent → Spec Amendment Request
     ↓
Architect Agent → Revised Spec (v1.0.1)
     ↓
Planner Agent → Amended Task Graph
```

### Versioning Rules

- Initial spec: `1.0.0`
- Spec corrections during build retries: increment patch version (`1.0.1`, `1.0.2`)
- Major structural redesigns (System Reset): increment major version (`2.0.0`)
- Spec amendments are append-only; old version is preserved in the snapshot system

---

## 10. Validation Rules

The Spec Validator enforces the following before dispatching to the Planner Agent:

### Structural Rules

| Rule                                                      | Validator Check             |
| --------------------------------------------------------- | --------------------------- |
| `appIdentity.name` is a valid C# identifier               | Regex `^[A-Z][A-Za-z0-9]*$` |
| At least one entity in `domainModel.entities`             | `entities.length >= 1`      |
| At least one feature in `features`                        | `features.length >= 1`      |
| At least one page in `navigationGraph.pages`              | `pages.length >= 1`         |
| Every feature's `entities` references a valid entity name | Cross-reference check       |
| Every page's `featureIds` references a valid feature id   | Cross-reference check       |
| Every entity has exactly one `isPrimaryKey: true` field   | Per-entity check            |
| No entity uses a reserved name                            | Blocklist check             |

### Constraint Enforcement

| Rule                                          | Enforced By           |
| --------------------------------------------- | --------------------- |
| `constraints.databaseEngine` must be `SQLite` | Spec Validator        |
| `constraints.uiFramework` must be `WinUI3`    | Spec Validator        |
| No feature category in Phase 1 forbidden list | Spec Validator        |
| `allowNetworkAccess` must remain `false`      | Runtime Safety Kernel |

### Failure Behavior

If the Spec Validator fails:

1. Validation errors are logged to the AI Construction Engine
2. The Architect Agent receives the error list and revises the spec
3. Spec version is bumped
4. Validation is re-run on the new version
5. This cycle repeats until the spec is valid (no user intervention)

---

## 11. Full Spec Example

Below is a complete, valid `AppSpec` for a **Personal Expense Tracker** application.

```json
{
  "$schema": "https://sync-ai/schemas/app-spec/v1",
  "specVersion": "1.0.0",
  "specId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "createdAt": "2026-03-03T05:30:00Z",
  "appIdentity": {
    "name": "ExpenseTracker",
    "displayName": "Expense Tracker",
    "description": "A personal expense tracking app with category budgets and monthly reports.",
    "version": "1.0.0",
    "publisher": "CN=SyncAI",
    "iconIntent": "modern flat icon of a wallet with coins, teal and white color scheme",
    "splashIntent": "minimalist teal background with white wallet icon centered",
    "primaryColor": "#009688",
    "theme": "SystemDefault"
  },
  "domainModel": {
    "entities": [
      {
        "name": "Category",
        "description": "Expense category with an optional monthly budget",
        "fields": [
          {
            "name": "id",
            "type": "Guid",
            "isPrimaryKey": true,
            "isRequired": true,
            "isUnique": true,
            "isForeignKey": false
          },
          {
            "name": "name",
            "type": "string",
            "isRequired": true,
            "isUnique": true,
            "isForeignKey": false
          },
          {
            "name": "budgetAmount",
            "type": "double",
            "isRequired": false,
            "isForeignKey": false,
            "defaultValue": 0.0
          },
          { "name": "colorHex", "type": "string", "isRequired": false, "isForeignKey": false }
        ],
        "relationships": [
          { "type": "OneToMany", "targetEntity": "Expense", "navigationProperty": "Expenses" }
        ]
      },
      {
        "name": "Expense",
        "description": "An individual expense entry",
        "fields": [
          {
            "name": "id",
            "type": "Guid",
            "isPrimaryKey": true,
            "isRequired": true,
            "isUnique": true,
            "isForeignKey": false
          },
          { "name": "title", "type": "string", "isRequired": true, "isForeignKey": false },
          { "name": "amount", "type": "double", "isRequired": true, "isForeignKey": false },
          { "name": "date", "type": "DateTime", "isRequired": true, "isForeignKey": false },
          { "name": "notes", "type": "string", "isRequired": false, "isForeignKey": false },
          {
            "name": "categoryId",
            "type": "Guid",
            "isRequired": true,
            "isForeignKey": true,
            "referencesEntity": "Category"
          }
        ],
        "relationships": []
      }
    ]
  },
  "features": [
    {
      "id": "manage-categories",
      "title": "Manage Categories",
      "description": "Create, edit, and delete expense categories with optional monthly budgets.",
      "category": "CRUD",
      "entities": ["Category"],
      "uiComponent": "CategoriesPage",
      "requiresPermissions": [],
      "isOptional": false
    },
    {
      "id": "manage-expenses",
      "title": "Manage Expenses",
      "description": "Log, edit, and delete individual expense entries with category assignment.",
      "category": "CRUD",
      "entities": ["Expense", "Category"],
      "uiComponent": "ExpensesPage",
      "requiresPermissions": [],
      "isOptional": false
    },
    {
      "id": "monthly-report",
      "title": "Monthly Report",
      "description": "View spending by category versus budget for the current month.",
      "category": "Report",
      "entities": ["Expense", "Category"],
      "uiComponent": "ReportPage",
      "requiresPermissions": [],
      "isOptional": false
    },
    {
      "id": "export-expenses",
      "title": "Export to CSV",
      "description": "Export all expenses to a CSV file selected by the user.",
      "category": "Export",
      "entities": ["Expense"],
      "uiComponent": "ExpensesPage",
      "requiresPermissions": [],
      "isOptional": true
    }
  ],
  "navigationGraph": {
    "shellType": "NavigationView",
    "mainPage": "ExpensesPage",
    "pages": [
      {
        "name": "ExpensesPage",
        "route": "expenses",
        "title": "Expenses",
        "icon": "Money",
        "isInNavMenu": true,
        "parentPage": null,
        "featureIds": ["manage-expenses", "export-expenses"],
        "dialogs": [
          { "name": "AddExpenseDialog", "trigger": "ButtonClick", "purpose": "Add a new expense" },
          {
            "name": "EditExpenseDialog",
            "trigger": "RowDoubleTap",
            "purpose": "Edit an existing expense"
          }
        ]
      },
      {
        "name": "CategoriesPage",
        "route": "categories",
        "title": "Categories",
        "icon": "Tag",
        "isInNavMenu": true,
        "parentPage": null,
        "featureIds": ["manage-categories"],
        "dialogs": [
          { "name": "AddCategoryDialog", "trigger": "ButtonClick", "purpose": "Add a new category" }
        ]
      },
      {
        "name": "ReportPage",
        "route": "report",
        "title": "Monthly Report",
        "icon": "BarChart",
        "isInNavMenu": true,
        "parentPage": null,
        "featureIds": ["monthly-report"],
        "dialogs": []
      }
    ],
    "transitions": [
      { "from": "ExpensesPage", "to": "CategoriesPage", "trigger": "NavigationView item click" },
      { "from": "ExpensesPage", "to": "ReportPage", "trigger": "NavigationView item click" },
      { "from": "CategoriesPage", "to": "ExpensesPage", "trigger": "NavigationView item click" },
      { "from": "ReportPage", "to": "ExpensesPage", "trigger": "NavigationView item click" }
    ]
  },
  "permissions": [],
  "constraints": {
    "targetFramework": "net8.0-windows10.0.22621.0",
    "uiFramework": "WinUI3",
    "minWindowsVersion": "10.0.22621.0",
    "databaseEngine": "SQLite",
    "orm": "EntityFrameworkCore",
    "efCoreVersion": "8.x",
    "architecturalPattern": "MVVM",
    "diContainer": "Microsoft.Extensions.DependencyInjection",
    "packagingFormat": "MSIX",
    "selfContained": true,
    "allowNetworkAccess": false,
    "allowWebContent": false,
    "allowExternalProcesses": false
  }
}
```

---

## Change Log

| Date       | Change                                             |
| ---------- | -------------------------------------------------- |
| 2026-03-03 | Initial creation — full JSON schema for AppSpec v1 |

---

## References

- [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Architect Agent that produces this spec
- [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — Solution structure derived from this spec
- [DATA_LAYER_GENERATION.md](./DATA_LAYER_GENERATION.md) — EF Core + SQLite generation rules
- [UI_GENERATION_RULES.md](./UI_GENERATION_RULES.md) — WinUI 3 XAML generation rules
- [BRANDING_INFERENCE_HEURISTICS.md](./BRANDING_INFERENCE_HEURISTICS.md) — Icon + color derivation from `iconIntent`
