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
| DetectedActivity (running/walking/cycling/stationary/unknown) | `Shared/DetectedActivity.swift` | color lives in per-target `DetectedActivity+Theme.swift` |
| RoutePoint | `Shared/RoutePoint.swift` | |
| TrainingPlan (+PlanDay/PlanWeek/PlanProgress/CompletedPlanDay) | `Shared/TrainingPlan.swift` | |
| BuiltInPlans | `Shared/BuiltInPlans.swift` | |
| ExerciseDevice (+DeviceCategory) | `Shared/ExerciseDevice.swift` | |
| WorkoutSport | `Shared/WorkoutSport.swift` | themeColor lives in per-target `WorkoutSport+Theme.swift`; HK vars gated `#if canImport(HealthKit) && !os(macOS)` |
| SessionMode | `Shared/SessionMode.swift` | |
| HeartRateZoneCalculator | `Shared/HeartRateZoneCalculator.swift` | |
| HeartSafetySettings | `Shared/HeartSafetySettings.swift` | HEALTH DATA: `onBetaBlocker` is device-only. `watchPayload(age:)` strips it and resolves the upper limit. `zoneWord`: EASY < 70% / STEADY < 90% / HARD |
| HeartAlertEvaluator (+ `HeartAlert`) | `Shared/HeartAlertEvaluator.swift` | Kinds: aboveLimit, belowLow, signalLost, noMotion (60 s without HR and without motion), suddenJump (+40 bpm in 10 s; default OFF in `HeartSafetySettings`, see `watchos.md`) |
| PausedSample | `Shared/PausedSample.swift` | Whether an HR sample belongs to a pause, judged by its own date (delivery can lag). Used by the watch |
| PhoneDiscardRule (+ `Decision`) | `Shared/PhoneDiscardRule.swift` | Watch-side rule for a phone `discardWorkout`: applies only to the workout with the same `phoneSessionId`; 120 s age limit; held while starting |
| WCPayloadValidation | `Shared/WCPayloadValidation.swift` | Sanity checks for WatchConnectivity payloads (sessions, effort, alerts, live metrics) and the 8 MB session cap |
| DistanceFusion | `Shared/DistanceFusion.swift` | iPhone workout distance: GPS when usable, else pedometer; never summed |
| MedicineVault | `Shared/MedicineVault.swift` | Medication notes (name, daily dose) in the Keychain (`SecretBackend`, phone only). Never in JSON or sync |
| SegmentEdits | `Shared/SegmentEdits.swift` | "Fix a part" corrections for `segment_overrides.json`: v2 envelope (types + per-session partitions), v1 flat map still decodes. Pure `apply`, split, merge, `caloriesRemoved`, `minPart`. Applied once in `DataManager.effectiveSessions` |
| PendingSessionEffort | `Shared/PendingSessionEffort.swift` | Effort answers that arrived before their session; bounded to `cap` = 20 (oldest dropped); persisted under `pendingSessionEffort` |
| HealthImportRules | `Shared/HealthImportRules.swift` | Dedup and grace-period rules for the iOS Health import; session ids from the external workout UUID |
| WatchLinkRules | `Shared/WatchLinkRules.swift` | Phone/watch start handshake reply parsing (`phoneSessionId`) and the stale `workoutStopped` rule |
| SafetyPromptSchedule | `Shared/SafetyPromptSchedule.swift` | Pure schedule for the 3h50m active-time prompt (re-arm, 5 min timeout) |
| CalorieEstimationEngine | `Shared/CalorieEstimationEngine.swift` | MET math. iOS adds the `TrainingSession` overloads in `ShuttlX/Services/CalorieEstimationEngine.swift` |
| ThemeID | `Shared/ThemeID.swift` | `valid` = `["clean"]`; unknown saved or synced ids fall back to clean |
| SpeedActivityClassifier (+ `Hysteresis`) | `Shared/ActivityClassifier.swift` | GPS speed + cadence → running / walking / cycling. 30 s min window; 60 s hold into or out of cycling, 30 s otherwise. Named apart from the watch-only `ActivityClassifier` |
| FormattingUtils | `Shared/FormattingUtils.swift` | |

Also in the package: `IntervalEngine` (canonical, consumed by iOS only for now),
`RecoverySegmenter`, `HapticPlayer`.

## Still duplicated per target (update BOTH copies; Phase 4 will unify)

| Model | Why blocked |
|-------|------------|
| TrainingSession | references `IntervalType`/`CompletedInterval` which collide with the package engine's types |
| WorkoutTemplate | defines the app-side `IntervalType` — collides with `ShuttlXShared.IntervalType` |

`TrainingSession` also carries `effortRPE: Int?` (watch post-workout effort, both copies). It usually stays on the watch copy; iOS dedups by id. Also optional in both copies: `autoEnded` (safety-prompt timeout) and `pausedPeakHeartRate` (peak HR read while paused, kept out of the active peak).
`TrainingSession.pausedPeakHeartRate: Double?` (both copies): the highest HR read while paused; `maxHeartRate` and `averageHeartRate` count active time only.

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
