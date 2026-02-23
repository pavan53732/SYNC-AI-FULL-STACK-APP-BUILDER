# Graph Integrity Verifier

> **Code Intelligence Layer: Self-Healing Repair and Integrity Checks**
>
> **Parent Document:** [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md)
>
> **Related:** [DatabaseSchema.md](./DatabaseSchema.md) — Graph storage

---

## Table of Contents

1. [Run Triggers](#1-run-triggers)
2. [Integrity Checks](#2-integrity-checks)
3. [Self-Healing Repair Strategy](#3-self-healing-repair-strategy)

---

## 1. Run Triggers

**Run triggers**: Boot, Post-Restore, Post-Crash, Weekly.

---

## 2. Integrity Checks

1. **File ↔ Symbol Consistency** — Recompute file hash, compare with DB. Mismatch → re-index
2. **Edge Validity** — Verify `from_id` and `to_id` exist in `symbols`. Orphan → delete
3. **XAML Binding Validation** — Verify `viewmodel_symbol_id` exists and property matches
4. **Snapshot Chain** — Verify `parent_snapshot_id` links form a valid tree (no cycles, no gaps)

---

## 3. Self-Healing Repair Strategy

If corruption detected:

1. Lock Workspace
2. Create "Safety Snapshot" (backup current state)
3. **TRUNCATE** graph tables
4. Perform **Full Re-index** from disk
5. Validate Integrity
6. Resume operation

---

## References

- [CODE_INTELLIGENCE.md](../CODE_INTELLIGENCE.md) — Parent document
- [DatabaseSchema.md](./DatabaseSchema.md) — Graph storage
- [CrashRecovery.md](../execution/CrashRecovery.md) — Recovery procedures

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from CODE_INTELLIGENCE.md as part of documentation reorganization |