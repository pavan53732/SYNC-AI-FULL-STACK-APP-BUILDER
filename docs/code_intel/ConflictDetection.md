# Conflict Detection

> **Code Intelligence Layer: Patch Failure Scenarios and Escalation Policy**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [PatchEngine.md](./PatchEngine.md) — Patch operations

---

## Table of Contents

1. [Patch Failure Scenarios](#1-patch-failure-scenarios)
2. [PatchResult & Error Types](#2-patchresult--error-types)
3. [Guard Failure Escalation Policy](#3-guard-failure-escalation-policy)

---

## 1. Patch Failure Scenarios

A patch fails if:

- **Target node not found** — Class, method, or property doesn't exist
- **Signature mismatch** — Method signature has changed
- **File hash changed** — File was modified since patch was created
- **Syntax invalid** — Generated code has syntax errors
- **Duplicate member** — Adding a member that already exists

---

## 2. PatchResult & Error Types

```csharp
public class PatchResult
{
    public bool Success { get; set; }
    public PatchErrorType? Error { get; set; }
    public string ErrorMessage { get; set; }
    public string NewFileHash { get; set; }
}

public enum PatchErrorType
{
    ValidationFailed,
    FileHashMismatch,
    TargetNotFound,
    SignatureMismatch,
    SyntaxError,
    DuplicateMember,
    UnexpectedException
}
```

---

## 3. Guard Failure Escalation Policy

The system uses an Infinite Silent Retry model. If a mutation repeatedly fails the safety guard:

1. **Attempt 1-3 (Soft Rejection)** — Return tailored error (e.g., "Symbol Foo not found") to the Agent.
2. **Attempt 4-9 (Hard Rejection)** — Return "Breaking Change Detected" with impact path. Agent attempts architectural pivot.
3. **Attempt 10+ (Barrier Failure / System Reset)** — **SYSTEM RESET**. The kernel triggers an automatic rollback to the pre-mutation snapshot, clears the AI context (forced amnesia), and forces the Architect agent to generate an entirely different file strategy. The user only ever sees "Optimizing build..."

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document
- [PatchEngine.md](./PatchEngine.md) — Patch operations
- [ORCHESTRATION_ENGINE.md](../ORCHESTRATION_ENGINE.md) — Retry controller

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md as part of documentation reorganization |