---
globs:
  - "**/Models/**"
  - "Shared/**"
---

# Model Rules

## Where models live (post-consolidation, July 2026)

Most models are single-sourced in the **ShuttlXShared** package (`Shared/`) and
imported by all targets via `import ShuttlXShared`. Only two models remain
duplicated per target until the Phase 4 engine unification
(see `docs/plans/2026-07-codebase-refactor-plan.md`).

## Package models (single source of truth — edit `Shared/`, add `public` to new API)

| Model | Path | Notes |
|-------|------|-------|
| ActivitySegment | `Shared/ActivitySegment.swift` | |
| DetectedActivity | `Shared/DetectedActivity.swift` | color lives in per-target `DetectedActivity+Theme.swift` |
| RoutePoint | `Shared/RoutePoint.swift` | |
| TrainingPlan (+PlanDay/PlanWeek/PlanProgress/CompletedPlanDay) | `Shared/TrainingPlan.swift` | |
| BuiltInPlans | `Shared/BuiltInPlans.swift` | |
| ExerciseDevice (+DeviceCategory) | `Shared/ExerciseDevice.swift` | |
| WorkoutSport | `Shared/WorkoutSport.swift` | themeColor lives in per-target `WorkoutSport+Theme.swift`; HK vars gated `#if canImport(HealthKit) && !os(macOS)` |
| SessionMode | `Shared/SessionMode.swift` | |
| HeartRateZoneCalculator | `Shared/HeartRateZoneCalculator.swift` | |
| FormattingUtils | `Shared/FormattingUtils.swift` | |

Also in the package: `IntervalEngine` (canonical, consumed by iOS only for now),
`RecoverySegmenter`, `HapticPlayer`.

## Still duplicated per target (update BOTH copies; Phase 4 will unify)

| Model | Why blocked |
|-------|------------|
| TrainingSession | references `IntervalType`/`CompletedInterval` which collide with the package engine's types |
| WorkoutTemplate | defines the app-side `IntervalType` — collides with `ShuttlXShared.IntervalType` |

## Per-target theme extensions (intentionally different per platform)

- `Models/WorkoutSport+Theme.swift` — `themeColor` via that target's ShuttlXColor
- `Models/DetectedActivity+Theme.swift` — `color`/`themeColor`

## iOS-Only Models

- `ChartData.swift` — chart helpers (iOS analytics only)
- `WorkoutActivityAttributes.swift` — Live Activity attributes

## Conventions

- All models must be `Codable` and `Identifiable`; package models also `Sendable` where possible
- Package model API must be `public`, including an explicit `public init` (public structs lose the implicit memberwise init)
- Use `UUID` for identity
- Enums must have `String` raw values for stable JSON encoding
- New properties must have default values (backward-compatible decoding)
- Use `CodingKeys` when property names differ from JSON keys
- Xcode project note: files under `ShuttlX/` need explicit pbxproj registration; files under `ShuttlX Watch App/` are picked up automatically (synchronized folder); files under `Shared/` are SPM (no pbxproj entries)
