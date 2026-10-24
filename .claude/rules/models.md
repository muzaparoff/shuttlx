---
globs:
  - "**/Models/**"
  - "Shared/**"
---

# Model Rules

## Where models live (October 2026)

Every model is single-sourced in the **ShuttlXShared** package (`Shared/`) and
imported by all targets via `import ShuttlXShared` (no `@_exported import`).
`TrainingSession` and `WorkoutTemplate` were the last per-target copies; they moved
in Wave 4 Part A (`docs/plans/2026-10-model-unification-and-route-files.md`).
The watch still runs its own `Services/IntervalEngine.swift` and `RecoverySegmenter.swift`
(rest of Phase 4, not done).

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
| DistanceFusion | `Shared/DistanceFusion.swift` | iPhone workout distance, incremental value type (`update`): adds the GPS increment while a usable fix is < 10 s old, else the pedometer increment; monotonic, never summed |
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
| TrainingSession (+HRRCapture/RecoveryReport/CompletedInterval/LegacyCompletedInterval/KmSplitData) | `Shared/TrainingSession.swift` | Explicit `CodingKeys` (a new stored property must be added there, `testEveryStoredPropertyHasAJSONKey` checks it). `inlineRoute` is encoded as `"route"` (renamed in part B1). On the iPhone, sessions in `DataManager` never carry it: routes live in `routes/<id>.json`; read them with `DataManager.route(for:)`. Optional `routeSummary` (`Shared/RouteSummary.swift`, nil is not encoded). Optional `effortRPE` (watch effort; iOS dedups by id), `autoEnded` (safety-prompt timeout), `pausedPeakHeartRate` (highest HR read while paused; `maxHeartRate` and `averageHeartRate` count active time only), `importedFromHealth` |
| WorkoutTemplate (+IntervalStep) | `Shared/WorkoutTemplate.swift` | Steps use the package `IntervalType` (`displayName` lives on it; the app enum is gone) |
| RouteStore | `Shared/RouteStore.swift` | One `[RoutePoint]` file per session id in a directory; missing or corrupt reads as nil; `orphans(keeping:writtenBefore:)`. Plus `RouteExternalize` (`strip`, `save`: one-time backup, route files, then sessions.json; a failed route write stays inline). Tested in `RouteExternalizeTests`, `SessionsFileSizeTests` |
| SessionHeadline | `Shared/SessionHeadline.swift` | Decodable slim view of a session for widgets (no route); decode with `LenientJSON.decodeArray`, apply Fix a part with `SegmentEdits.effective` |

**Wire format is pinned**: `ModelWireCompatibilityTests` decodes `tests/ShuttlXTests/Fixtures/session_v1.json`
and `template_v1.json` (written by the pre-move models) and requires a byte-equal JSON object on re-encode.
Renaming a stored property changes the JSON key: add an explicit `CodingKeys` entry instead.

Also in the package: `IntervalEngine` (canonical, consumed by iOS only for now),
`RecoverySegmenter`, `HapticPlayer`.

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
