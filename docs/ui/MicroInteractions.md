# Micro-Interactions

> **UI Layer: Animations, Motion Design, and Transitions**
>
> **Parent Document:** [UI_IMPLEMENTATION.md](../UI_IMPLEMENTATION.md)

---

## Generate Button Behavior

| State        | Visual                                                        |
| ------------ | ------------------------------------------------------------- |
| **Idle**     | 160×48px, accent color, enabled                               |
| **Hover**    | +4% brightness, elevation shadow, translate Y: -2px           |
| **Click**    | Shrink to 96% scale (80ms)                                    |
| **Building** | Disabled, text "Building…", indeterminate progress bar inside |

---

## Status Indicator Pulse

**Building State Pulse** (1.5s cycle): Scale 1.0 → 1.15 → 1.0 with cubic easing.

**Success Flash** (300ms): Quick green flash, fade back to idle gray (200ms).

---

## Page Transitions

**Smooth Fade + Slide** (120ms fade out, 160ms slide in):
1. Fade out current page (120ms)
2. Swap pages
3. Slide in new page from right (160ms) with cubic ease out

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Extracted from UI_IMPLEMENTATION.md |