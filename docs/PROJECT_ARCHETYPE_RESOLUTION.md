# PROJECT ARCHETYPE RESOLUTION

> **Determines framework family from user intent and enforces compatibility matrix**
>
> **Related Core Documents:**
>
> - [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — Layer 6.7 definition
> - [STRUCTURED_SPEC_FORMAT.md](./STRUCTURED_SPEC_FORMAT.md) — targetPlatform schema
> - [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — Output project structures
> - [TOOLCHAIN_MANIFEST.md](./TOOLCHAIN_MANIFEST.md) — Toolchain profiles

---

## 1. Purpose

The **Project Archetype Resolver** is the decision engine that determines which Windows framework to use based on user intent. It is Layer 6.7 in the architecture.

### Why This Exists

Without this layer, the system cannot automatically decide:
- "Build a Windows app" → Which framework?
- "Create a desktop app with a GUI" → WPF or WinUI 3?
- "Make a native C++ application" → Win32 or WinRT?

---

## 2. Decision Graph

```
User Intent Analysis
        ↓
┌─────────────────────────────────────────────────────────┐
│                    ARCHETYPE RESOLVER                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Q1: Does user mention "C++", "native", "Win32"?    │
│       ↓ YES → Win32 / WinRT / Hybrid                  │
│       ↓ NO                                            │
│                                                         │
│  Q2: Does user mention "modern", "Windows 11",       │
│      "Fluent Design", "WinUI"?                        │
│       ↓ YES → WinUI 3                                 │
│       ↓ NO                                            │
│                                                         │
│  Q3: Does user mention "WPF"?                         │
│       ↓ YES → WPF                                      │
│       ↓ NO                                            │
│                                                         │
│  Q4: Does user mention "Forms", "WinForms"?          │
│       ↓ YES → WinForms                                │
│       ↓ NO                                            │
│                                                         │
│  Q5: Is this a command-line tool?                    │
│       ↓ YES → Console (.NET)                          │
│       ↓ NO                                            │
│                                                         │
│  DEFAULT: WinUI 3 (most modern, recommended)        │
│                                                         │
└─────────────────────────────────────────────────────────┘
        ↓
   targetPlatform Selection
```

---

## 3. Framework Compatibility Matrix

### Data Layer

| Framework | SQLite | EF Core | Dapper | In-Memory |
| --------- | ------ | -------- | ------ | ---------- |
| WinUI3 | ✅ | ✅ | ✅ | ✅ |
| WPF | ✅ | ✅ | ✅ | ✅ |
| WinForms | ✅ | ✅ | ✅ | ✅ |
| Console | ✅ | ✅ | ✅ | ✅ |
| Win32 | ⚠️ Manual | ❌ | ⚠️ Manual | ❌ |
| WinRT | ✅ | ⚠️ Limited | ⚠️ Manual | ✅ |
| Hybrid | ✅ | ✅ | ✅ | ✅ |

### UI Patterns

| Framework | MVVM | MVC | Code-Behind | No-UI |
| --------- | ---- | --- | ------------ | ----- |
| WinUI3 | ✅ Default | ❌ | ✅ | ❌ |
| WPF | ✅ Default | ❌ | ✅ | ❌ |
| WinForms | ⚠️ Optional | ❌ | ✅ Default | ❌ |
| Console | N/A | N/A | N/A | ✅ |
| Win32 | ❌ | ❌ | ✅ Default | ❌ |
| WinRT | ✅ | ❌ | ✅ | ❌ |
| Hybrid | ✅ Default | ❌ | ✅ | ❌ |

### Packaging

| Framework | MSIX | MSI | EXE | Portable |
| --------- | ---- | --- | --- | -------- |
| WinUI3 | ✅ Default | ❌ | ⚠️ Self-contained | ⚠️ Zip |
| WPF | ✅ | ✅ | ✅ | ✅ |
| WinForms | ⚠️ Limited | ✅ Default | ✅ | ✅ |
| Console | ❌ | ✅ | ✅ Default | ✅ |
| Win32 | ⚠️ Limited | ✅ | ✅ Default | ✅ |
| WinRT | ✅ Default | ❌ | ❌ | ❌ |
| Hybrid | ✅ | ⚠️ Limited | ✅ | ⚠️ Limited |

---

## 4. Toolchain Profile Selection

| Framework | .NET SDK | MSBuild | MSVC | Windows SDK |
| --------- | --------- | -------- | ---- | ----------- |
| WinUI3 | ✅ | ✅ | ⚠️ Optional | ✅ |
| WPF | ✅ | ✅ | ❌ | ⚠️ Optional |
| WinForms | ✅ | ✅ | ❌ | ❌ |
| Console | ✅ | ✅ | ❌ | ❌ |
| Win32 | ❌ | ❌ | ✅ Default | ✅ |
| WinRT | ❌ | ❌ | ✅ Default | ✅ Default |
| Hybrid | ✅ | ✅ | ✅ | ✅ |

---

## 5. AI Intent Keywords

### Framework Keywords

| Framework | Primary Keywords | Secondary Keywords |
| --------- | ---------------- | ------------------ |
| **WinUI3** | "modern", "Windows 11", "Fluent", "WinUI", "Fluent Design" | "beautiful", "latest Windows" |
| **WPF** | "WPF", "WPF app", "WPF application" | "XAML", ".NET desktop" |
| **WinForms** | "WinForms", "Forms", "Windows Forms" | "classic", "traditional" |
| **Win32** | "Win32", "native", "C++", "pure C++" | "MFC", "ATL", "raw" |
| **WinRT** | "WinRT", "C++/WinRT", "C++ WinRT" | "modern C++", "Windows Runtime" |
| **Console** | "console", "CLI", "command line", "terminal" | "tool", "utility" |
| **Hybrid** | "hybrid", "C++ interop", "native interop" | "native library", "C++ DLL" |

### Packaging Keywords

| Mode | Keywords |
| ---- | -------- |
| **MSIX** | "store", "Microsoft Store", "package", "installer" |
| **MSI** | "MSI", "enterprise", "silent install" |
| **EXE** | "standalone", "portable", "single file" |

---

## 6. Architecture Resolution Rules

### Rule 1: Explicit Wins

If user explicitly names a framework (e.g., "WPF app"), that framework is selected regardless of other signals.

### Rule 2: Modern Default

If no framework is specified, default to the most modern option: **WinUI 3**.

### Rule 3: Capability Matching

If user requests a capability that is only available in one framework, that framework is forced.

Example: "Build a Windows app with camera access using WinRT" → WinUI3 or WinRT

### Rule 4: Conflict Resolution

If user gives conflicting signals (e.g., "modern WPF app"), prefer the modern option (WinUI3) and explain the choice.

---

## 7. Hybrid Detection

### When to Use Hybrid

- User explicitly requests C++ interop
- Performance-critical components need native code
- User wants to use an existing C++ library

### Hybrid Project Structure

```
Solution
├── App.sln
├── App/                    ← .NET 8 WinUI 3 project
│   ├── App.csproj
│   └── (UI and .NET code)
├── NativeLib/              ← C++ DLL project
│   ├── NativeLib.vcxproj
│   └── (C++ code)
└── App.Package.wapproj    ← Windows Application Packaging
```

---

## 8. Error Handling

### Unresolvable Intent

If intent is ambiguous and cannot be resolved:

1. Ask user clarifying question
2. Provide 2-3 framework options with trade-offs
3. Let user choose

### Unsupported Combination

If requested combination is not supported (e.g., "WPF with MSIX"):

1. Suggest closest supported alternative
2. Explain limitation
3. Offer workaround if possible

---

## 9. Integration with Orchestrator

The Project Archetype Resolver outputs the `targetPlatform` object that flows into:

1. **Structured Spec** — Stored in spec JSON
2. **Target App Architecture** — Determines project template
3. **Toolchain Manifest** — Selects toolchain profile
4. **Orchestration Engine** — Determines task types

---

## Change Log

| Date | Change |
| ---- | ------ |
| 2026-03-04 | Initial creation - multi-framework archetype resolution |
