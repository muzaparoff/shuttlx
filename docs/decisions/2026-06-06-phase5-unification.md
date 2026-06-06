---
date: 2026-06-06
decision: DEFER
owner: swift-architect agent
status: closed
---

# Decision — Phase 5 Watch/iOS Unification

## Outcome

**Defer all five areas** of the proposed Phase 5 unification. No code changes shipped under this phase. Phase 5 task `T5.0` moves from `BLOCKED` to `CLOSED — DEFERRED`.

## TL;DR

The `ShuttlXShared` SPM package is **not a stub** — it's already wired into both Xcode targets and shipping 4 production files (`IntervalEngine`, `HapticPlayer`, `RecoverySegmenter`, `DetectedActivity`). The prior architect deliberately kept SwiftUI-importing types out of it (explicit comment at `Shared/DetectedActivity.swift:6`). Of the five areas proposed for unification, only the pure theme data structs are bit-identical, but they import SwiftUI — moving them reverses the prior architect's decision, a strategic call requiring explicit user sign-off.

## Per-area decision matrix

| # | Area | Decision | Justification |
|---|------|----------|---------------|
| 1 | **Models** (8 files) | DEFER | Comment-only drift today; safe-ish in isolation. But 52 consumer files would need `import ShuttlXShared` + every type/property/init becomes `public`. High churn, no shipping payoff this sprint. |
| 2 | **Theme bridges** (`ShuttlXColor`, `ShuttlXFont`) | DEFER | Read `ThemeManager.shared` at runtime — and `ThemeManager` has real iOS-only state (FM Tuner chrome at `ThemeManager.swift:20-27`). Sharing the bridge means sharing the manager, which is **not** bit-identical. |
| 3 | **Theme structs** (`AppTheme`, `ThemeColors`, `ThemeFonts`, `ThemeEffects`, `ThemeManager`) | DEFER | First four are bit-identical but import SwiftUI — pulls SwiftUI into the SPM target (reverses prior architect's decision). `ThemeManager` is divergent — flag, do not silently unify. |
| 4 | **Per-theme files** (Clean, Synthwave, …) | DEFER | `ShuttlXTheme.swift` drifts by 147 lines, `ThemeAssets.swift` by 81, `ThemeModifiers.swift` by 220 — these are NOT identical. iOS uses `MeshGradient` (iOS-18-only); watch has its own `Themes/Decorations/` subdir. Forced unification would mean a swarm of `#if os(iOS)` blocks in shared code — worse than two clean copies. |
| 5 | **Theme decorations / heroes** (`FMTunerHeader`, `SynthwaveTimerHero`, …) | DEFER (permanent) | iOS has 7 `*TimerHero.swift` files. Watch has none — watch uses an overlay pattern instead. **Sharing is anti-pattern here**, confirmed. |

## Evidence

- `Package.swift:14-26` — `ShuttlXShared` already declared with `path: "Shared"`, no nested module structure.
- `Shared/DetectedActivity.swift:1-10` — explicit prior-architect comment: *"we keep this shim free of SwiftUI to make the Shared/ SPM target compile … the SwiftUI extensions can move to a separate file in the app target"*. Direct evidence that moving SwiftUI-importing types into `ShuttlXShared` was already considered and rejected.
- `ShuttlX/Theme/ThemeManager.swift:20-27` vs watch copy — iOS exposes FM Tuner chrome state (`vuMeterValue`, `signalStrength`, `footerStatusLines`, `chromeVisible`); watch does not. **Real semantic divergence**, not just comment drift.
- `ShuttlX/Models/BuiltInPlans.swift` vs watch copy — 7 diff lines, comment-only. Safe.
- `ShuttlX/Models/TrainingSession.swift:15-23` vs watch copy — 12 diff lines, comment-only (HRR documentation). Safe.
- `ShuttlX/Theme/Themes/ShuttlXTheme.swift` vs watch copy — 147 diff lines. **Not** safe to unify without splitting.
- `ShuttlX/Theme/ThemeModifiers.swift` vs watch copy — 220 diff lines. **Not** safe.
- 52 source files reference one or more of the duplicated model types. Each would need `import ShuttlXShared` and every type member would need `public`.

## Conditions to revisit

Unify Models when **all** of these hold:
1. No uncommitted changes in `Services/` on either target
2. No active sprint touching `TrainingSession` / `WorkoutTemplate` shape
3. A dedicated 1-day branch with a single owner (no parallel agent team)
4. Step-by-step pilot: start with `RoutePoint` (20 LOC, 11 consumers) → verify CI green → then `ActivitySegment` → `WorkoutSport` → leaf models → finally `TrainingSession`. Each step in its own commit.

Unify Theme pure-data structs (`AppTheme`, `ThemeColors`, `ThemeEffects`, `ThemeFonts`) **only** if and when SwiftUI is acceptable inside `ShuttlXShared`. That requires reversing the prior architect's decision in `Shared/DetectedActivity.swift:6` — needs explicit user sign-off.

**Never** unify per-theme `*TimerHero.swift` files or watch-side `Decorations/` views — iOS and watchOS use different layout paradigms (full-body vs overlay) by design.

## What this decision is not

This is NOT a vote against `ShuttlXShared`. The package already exists and is being used correctly for platform-agnostic logic (`IntervalEngine`, `RecoverySegmenter`, etc.). Adding more code to it is the right move WHEN the prerequisites above are met. This decision is just: not this sprint.
