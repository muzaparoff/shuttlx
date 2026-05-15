# Senior Architect Review — 2026-05-15

Scope: ~14,600 LOC across 117 Swift files. Full read of `WatchWorkoutManager.swift` (1,358 LOC), both `SharedDataManager.swift` copies, `DataManager`, `CloudKitSyncManager`, `IntervalEngine`, `RecoverySegmenter`, `TemplateManager`, `LiveActivityManager`, app entry points, plus diffs of every duplicated model and theme file.

---

## Executive summary

ShuttlX is a solo-developer, dual-target SwiftUI app whose architecture is honestly more disciplined than its size implies. The split is clean: pure-function `AnalyticsEngine`, value-type `RecoverySegmenter`, a small `IntervalEngine`, and a clear data-flow story (iPhone authors templates → App Group → Watch executes → session syncs back via WC + CloudKit + App Group reconcile loop). `@MainActor` is applied consistently on every ObservableObject, `nonisolated` delegate methods hop to `@MainActor` via `Task`, JSON writes are atomic + file-coordinated, and the WC sync path is genuinely thoughtful — dual-channel `sendMessage` + `applicationContext`, file-transfer escalation by payload size, retry burst on finish, corrupt-file backup before re-write. The crash-recovery flow (active workout backup → recoverCrashedWorkout → dedupe-by-UUID save) is one of the better solo-dev implementations I've reviewed.

What is at risk is **cohesion in the two largest classes** and **silent drift between iOS and watchOS copies of "duplicated" files**. `WatchWorkoutManager` is 1,358 LOC and owns six unrelated responsibilities (HK session, HK queries, motion/pedometer, GPS, interval engine driver, recovery state machine driver, persistence, WC broadcast, summary computation, KM-split detection). The iOS `SharedDataManager` is 864 LOC and is the *only* WCSessionDelegate, a Combine publisher, an LiveActivity coordinator, a corrupt-file restorer, *and* the runner of a 15-second background poll timer. Both classes are still readable, but they are one feature away from becoming sealed: any change requires re-reading hundreds of lines to be sure you haven't broken something else. Separately, the `Models/` files that CLAUDE.md says are byte-identical between targets are **not** byte-identical (small comment drift; one variant uses raw Colors where the other uses theme tokens). The Package.swift declares a `Shared/` SPM target and `Tests/` directory that **do not exist** — the project has zero tests today.

Three structural moves would meaningfully raise the ceiling for this codebase without overengineering it: (1) split `WatchWorkoutManager` into 4 single-responsibility actors/services kept behind the same `@Observable` facade so call sites don't change, (2) carve duplicated models + theme files into a real local SwiftPM package so drift is impossible by construction, (3) introduce a tiny `ShuttlXTests` XCTest target and start with `RecoverySegmenter` (pure value type, trivial to test). Nothing else in this audit is urgent.

---

## P0 — Architecture blockers

### P0-1: `WatchWorkoutManager` is a 1,358-line god-object on the highest-criticality code path
**File:** `ShuttlX Watch App/Services/WatchWorkoutManager.swift`

This single `@MainActor` class owns: HK workout session lifecycle, HK live builder, two `HKAnchoredObjectQuery` lifecycles (HR + calories) with their own anchor state, `CLLocationManager` delegate, `CMPedometer` + `CMMotionActivity` lifecycles, `DispatchSourceTimer` display tick, activity-debounce state machine (pendingActivity + 5s confirmation), KM split detection + pace, route point downsampling, interval engine tick + completion check, recovery segmenter tick + event processing, HRR capture aggregation, JSON backup for crash recovery, route builder finalization, and dual-channel live-metrics broadcast over WCSession. There are ~25 `@Published` properties and ~30 private mutating fields. Pause/resume specifically toggles 6 subsystems by hand (lines 361–408), and `stopWorkout()` resets ~25 fields manually (lines 410–487). Future contributors *will* miss resetting one. Recommended split:
- `WorkoutSessionCoordinator` (facade, ~150 LOC) — owns the `@Observable`/published surface that views bind to today, delegates everything else.
- `HealthKitWorkoutBridge` — authorization, HKWorkoutSession + builder, HR/calorie anchored queries, route builder finalization.
- `WorkoutSensorAggregator` — motion + pedometer + location, emits a `SensorSnapshot` per tick.
- `WorkoutMetricsBroadcaster` — WC dual-channel send + throttling.
- `WorkoutCrashRecovery` — backup/recover/clear (~80 LOC, already nearly standalone).

Keep the facade `@MainActor` and let the children be plain classes/actors. Effort **L** (3–5 days). Do not migrate views — only the internals move.

### P0-2: Models/Theme "duplication" has already drifted; the drift will only get worse
**Files:** `ShuttlX/Models/TrainingSession.swift` vs `ShuttlX Watch App/Models/TrainingSession.swift`, all 7 theme files (`ShuttlXTheme.swift`, `ThemeAssets.swift`, `ThemeManager.swift`, `ThemeModifiers.swift`).

Drift observed today (verified by `diff`):
- `TrainingSession.swift`: doc comments on `HRRCapture` fields and `hrr1`/`hrr2` accessors present on iOS, **missing on watch**.
- `BuiltInPlans.swift`: an explanatory comment block and the inline `// rest` annotation diverge.
- `ThemeAssets.swift`: differs in 81 lines — most notably the iOS variant references `CleanTimerFrame`/`CleanCompletionBadge` for the `neovim` theme; the watch variant uses raw `Color.yellow/.cyan/.pink` where iOS uses `ShuttlXColor.*` tokens (i.e. a theme regression survives only on watch).
- `ThemeModifiers.swift`: differs in 177 lines — `ThemedControlButtonStyle` is watchOS-only (correct) but the watch variant has a fundamentally different shape switching system (`Circle()` vs the iOS theme-aware `RoundedRectangle`).
- `ThemeManager.swift`: only differs by `subsystem` string (legitimate per-target).

The drift is invisible because both targets compile in isolation. The rule "update both copies" is already not holding. Proposed: create a SwiftPM package `Shared/` (the `Package.swift` at the repo root already declares this — it's just an empty stub) containing the 8 model files (no `WorkoutSport.hkActivityType`-style HK reaches in models — those are already neutral) and the theme primitives (`ThemeColors`, `ThemeFonts`, `ThemeEffects`, `AppTheme`, `ThemeManager`). Keep target-specific stuff (`ThemeAssets`, `ThemeModifiers` which use SwiftUI shapes per-platform) out of the package. Effort **M** (1–2 days for models alone, +1 day if themes go in). Risk **low** — these files have no UIKit/WatchKit dependencies.

### P0-3: Zero tests, but the architecture is unusually test-friendly
**Files:** none (Package.swift refs `Tests/` which doesn't exist; no `*Tests.swift` files anywhere).

The single biggest improvement-for-effort win. `RecoverySegmenter` is a pure value type — every state transition can be unit-tested by feeding `(hr, activity, maxHR, now)` tuples and asserting on emitted events. `IntervalEngine` is similarly pure. `AnalyticsEngine` is described as "pure functions" and already is. KM-split detection in `WatchWorkoutManager.updatePaceAndSplits` is a 30-line function that's never been verified for boundary conditions (what happens at distance = 0.999999? at km = 0? on a >100km ultra?). Effort to bootstrap: **S** (half a day to add an XCTest target + 10 unit tests on `RecoverySegmenter`). See "Test target setup recommendation" below.

---

## P1 — Tech debt worth addressing

### P1-1: Singleton mesh — `SharedDataManager.shared` referenced from 11 distinct view/service files
**Files:** see grep results in audit prep — `SettingsView`, `DashboardView`, `DebugView`, `SyncDebugView`, `DataManager`, `TemplateManager`, `SubscriptionManager`, `LiveWorkoutCard`, `ContentView` (watch), watch `DebugView`, etc.

The app advertises an `@EnvironmentObject` injection (`ShuttlXApp.swift:38`), but ~half the call sites reach for `.shared` directly anyway. This breaks SwiftUI previews silently (any view that touches `.shared` during preview construction will hit the real singleton). Recommended: pick one. Either commit fully to `EnvironmentObject` (and add `#Preview` helpers that inject stubs) or commit to singletons (and drop the `@EnvironmentObject` machinery). Pragmatically the EnvironmentObject path is the right one because `DataManager` already depends on it for `setDataManager`. Effort **S** (mechanical refactor, 2–3 hours).

### P1-2: `SharedDataManager` (iOS) carries 4 unrelated responsibilities
**File:** `ShuttlX/Services/SharedDataManager.swift` (864 LOC)

It is: (1) the WCSessionDelegate, (2) the source of truth for live workout state surfaced to UI (`liveElapsedTime`, `liveHeartRate`, etc.), (3) the `LiveActivityManager` driver, (4) a session-storage layer (load/save/purge `sessions.json` *in addition to* `DataManager` doing the same), and (5) a background poll-and-reconcile loop. The result is that two classes (`SharedDataManager` and `DataManager`) both own the same `sessions.json` file, both have `loadSessionsFromAppGroup`, both write atomically, and they reconcile each other via Combine (`DataManager.setupBindings`) plus a 15-second timer (`performBackgroundSync`). This is genuinely confusing — which one is the source of truth? Today the answer is "both, kind of, with reconcile". Recommend: extract `LiveWorkoutMirror` (the live-metrics publisher) into its own `@MainActor` `@Observable`, keep `SharedDataManager` as the WC delegate + sync queue only, and make `DataManager` the single source of truth for stored sessions. Effort **M** (1 day).

### P1-3: Two parallel storage layers, both reading and writing `sessions.json`
**Files:** `ShuttlX/Services/SharedDataManager.swift:271-336`, `ShuttlX/Services/DataManager.swift:166-244`, `ShuttlX Watch App/Services/SharedDataManager.swift:281-327`.

Each has its own `saveSessionsToAppGroup`/`loadSessionsFromAppGroup` with near-identical NSFileCoordinator logic. They protect against concurrent writes *within* a process, but not between iOS and watch (which is fine because App Group writes from a single watch and a single iPhone don't typically race). The duplication is the issue, not the correctness. Extract `SessionStore` (struct, ~80 LOC) that owns the JSON file and the coordinator. Both managers use it. Effort **S** (3 hours).

### P1-4: Concurrency pattern: 30+ `Task { @MainActor in }` blocks inside `nonisolated` delegate methods
**Files:** `ShuttlX/Services/SharedDataManager.swift`, `ShuttlX Watch App/Services/SharedDataManager.swift`, `ShuttlX Watch App/Services/WatchWorkoutManager.swift`.

Functionally correct, but the boilerplate is heavy and the indirection makes the call graph hard to follow (e.g. `processHeartRateSamples` is `nonisolated`, hops back to `@MainActor` to mutate state — fine — but the same pattern appears 30+ times). With Swift 6 strict concurrency this will become noisier still. Recommend collecting the WC delegate methods into a small adapter type (`WCDelegateAdapter`) that lives off-main and `await`s into the main-actor manager via a clean async interface. Effort **M** (1 day). Not urgent — current code works.

### P1-5: Build script `tests/build_and_test_both_platforms.sh` is 400+ lines of shell with known SPM cross-contamination on `--clean`
**File:** `tests/build_and_test_both_platforms.sh`

The current implementation writes a temp script per build, parses `XCODEBUILD_EXIT_CODE` from stderr, and runs iOS + watchOS sequentially. The "SPM cross-contamination on --clean" issue is a real Xcode/SPM quirk: when you `xcodebuild clean` for one target and then build the other, SPM packages can rebuild from scratch because Xcode shares the DerivedData/SourcePackages folder. The cleanest fix is **don't `clean` both targets in the same invocation** — clean iOS, build iOS, then build watch (no clean). Or use `xcodebuild -scheme ShuttlX -destination 'platform=...' build` with `-derivedDataPath` set to two distinct paths. Effort **S** (rewrite to 50 lines, 2 hours). Not blocking but the script is hard to maintain at its current size.

### P1-6: `TrainingSession` is accumulating fields without versioning
**File:** `ShuttlX/Models/TrainingSession.swift` (and watch copy)

23 stored properties, ~half optional. New fields (`sessionMode`, `recoveryReport`, `deviceID`, `estimatedCalories`, `planID`, `planDayIndex`, `modifiedDate`) have been added incrementally. Decoding works today because every new field is optional, but there is no `version` field. When a future migration is needed (e.g. moving `route` out of the JSON blob — see scalability concern below) there's no graceful path. Recommend adding `var schemaVersion: Int = 3` now (defaulting to 3 means old JSON without it decodes as the current version), and writing a 5-line `migrateIfNeeded(_:)` that reads the version on load. Effort **S** (2 hours). Best added when you next touch the model.

### P1-7: `ThemeAssets.swift` (1,259 LOC iOS / 1,224 LOC watch) is the single largest file
**Files:** `ShuttlX/Theme/ThemeAssets.swift`, `ShuttlX Watch App/Theme/ThemeAssets.swift`

A massive switch-on-themeID dispatch over per-theme `TimerFrame`/`CompletionBadge`/`CardBackground` views. Each theme should own its visual assets in its own file (you already have `Themes/CleanTheme.swift` etc.) Move the per-theme view structs out of `ThemeAssets` and into `Themes/<Name>Theme.swift`, leave `ThemeAssets` as a thin dispatcher (~150 LOC). Effort **M** (1 day). This is also where the drift between iOS and watch lives — splitting it up makes drift visible at the per-theme file level instead of buried in a 1,200-line file.

---

## P2 — Nice-to-haves

### P2-1: `setupBackgroundTasks` runs a `Timer.scheduledTimer` every 15s on both iOS and watch
`SharedDataManager` (both targets). On watch, this competes for power during a workout. Recommend gating the watch-side poll behind `!workoutManager.isWorkoutActive` so it doesn't fire during a workout.

### P2-2: `SettingsView` is 652 LOC
Mostly forms, but it owns 10+ `@State` flags. Split into `AccountSection`, `HealthSection`, `ThemeSection`, `SubscriptionSection` subviews. Effort **S**.

### P2-3: `RoutePoint` is a struct with no schema for downsampling
`WatchWorkoutManager.maxRoutePoints = 2000` caps array growth, but the downsampling algorithm at lines 1317–1329 is ad-hoc (keep every 2nd from the first half, all of the second half). Document the invariant, or move to a small `RouteCompressor` that uses Douglas-Peucker. Cosmetic — current behavior is fine.

### P2-4: No structured logger categories convention
`Logger(subsystem:category:)` is used everywhere, but categories are ad-hoc strings ("ThemeManager", "WatchWorkoutManager", "SharedDataManager"). Define a `LogCategory` enum so categories are typo-proof. Effort **S** (1 hour).

### P2-5: `ContentView` (iOS) deep-links via `@State Binding` for session IDs
The deep-link flow uses `@Binding var deepLinkSessionID: UUID?` on `ContentView` and a `@State` on `ShuttlXApp`. Works, but the binding-of-optional-UUID pattern is awkward. Replace with `NotificationCenter` post or an `@Observable DeepLinkRouter`. Cosmetic.

### P2-6: `tests/` directory contains 4 Swift files but no test target
`tests/debug_ui_freeze.swift` and three `sync_fix*.swift` files are stand-alone scripts, not XCTests. They should be deleted or moved to `scripts/` to remove the implication that tests exist. Effort **trivial**.

---

## Refactor proposals (ranked by ROI)

### 1. `WatchWorkoutManager` split — Effort L, Risk M, Highest ROI
**Current:** 1,358-LOC `@MainActor` class managing 6 concerns, ~25 `@Published`, ~30 private mutating fields, manual reset of all state in `stopWorkout()`.

**Proposed:** Keep `WatchWorkoutManager` as a 200-LOC facade that views bind to. Behind it:
```
WatchWorkoutManager (facade, @MainActor, @Observable)
├─ HealthKitWorkoutBridge      — auth, session, builder, HR/cal queries
├─ WorkoutSensorAggregator     — motion + pedometer + location
├─ WorkoutMetricsBroadcaster   — WC dual-channel send + throttle
├─ WorkoutCrashRecovery        — backup/recover/clear
├─ IntervalEngine              — already standalone
└─ RecoverySegmenter           — already standalone (value type)
```
**Risk:** medium. Workout code is critical. Mitigate by moving one subsystem at a time, behind feature flag if needed. Build-and-test on physical Apple Watch (not simulator) at each step.

### 2. Local SwiftPM `Shared/` package for models + theme primitives — Effort M, Risk Low, High ROI
**Current:** 16 model+theme files mirrored across targets with verified drift. Package.swift already declares the package; just empty.

**Proposed:** Move `Models/` (8 files) + `Theme/{ThemeColors,ThemeFonts,ThemeEffects,AppTheme,ThemeManager}.swift` + `Utilities/FormattingUtils.swift` into `Shared/Sources/ShuttlXShared/`. Both Xcode targets `import ShuttlXShared`. Themes that use SwiftUI shapes (`ThemeAssets`, `ThemeModifiers`) stay duplicated because of platform-specific Shape availability. Delete the watch copies.

**Risk:** low. Models are POCO Codables with no platform APIs. The `HKWorkoutActivityType` extension on `WorkoutSport` may need an `#if canImport(HealthKit)` guard, but HealthKit is on both targets so even that may not be needed.

### 3. Introduce `ShuttlXTests` XCTest target with `RecoverySegmenterTests` seed — Effort S, Risk None, High ROI
**Current:** No tests, just stub scripts in `tests/`.

**Proposed:** Add an XCTest target in Xcode, add `RecoverySegmenterTests.swift` with ~10 tests covering: gymStrength idle→work transition, work→rest transition, HRR-1 capture at 60s ±tolerance, rest timeout, cardiacRehab dual-condition (stationary + HR rise), cardiacRehab fallback after 45s, walk-stop debounce. These tests run in <1s and would have caught the recent dual-condition work in `RecoverySegmenter` regressions before they shipped. Once the harness exists, add `IntervalEngineTests` and `AnalyticsEngineTests` opportunistically.

### 4. Extract `SessionStore` shared by iOS `SharedDataManager` + `DataManager` + watch `SharedDataManager` — Effort S, Risk Low, Medium ROI
**Current:** 3 implementations of the same `loadSessionsFromAppGroup`/`saveSessionsToAppGroup` with NSFileCoordinator + corrupt-file backup.

**Proposed:** Move into the new `Shared` package. Single source of truth for App Group JSON I/O.

### 5. Split `ThemeAssets.swift` into per-theme files — Effort M, Risk Low, Medium ROI
**Current:** 1,259-LOC dispatcher with `switch themeID` repeated for every theme-specific component. Drift between iOS and watch copies (81 lines).

**Proposed:** Per-theme files own their visuals. `ThemeAssets` becomes a thin protocol-driven dispatcher.

---

## TODO / FIXME inventory

| file:line | tag | text | suggested action |
|---|---|---|---|
| `ShuttlX/Services/SubscriptionManager.swift:47` | TODO | switch to `.enforced` once RevenueCat SDK ships it | Re-check on each RevenueCat update; track as a GitHub issue, not a code TODO |

**Astonishingly, that is the only TODO/FIXME/HACK in the entire codebase.** That is rare for a 14k LOC solo project and reflects well on hygiene. (Inline `// Note:` and `// MARK:` annotations are not counted.) Recommendation: keep it that way — the absence of `// TODO` comments forces fixes to land in a tracker rather than rotting in code.

---

## Test target setup recommendation

### Minimum scaffold (½ day)

1. **Xcode → File → New → Target → Unit Testing Bundle**
   - Product Name: `ShuttlXTests`
   - Target to be tested: `ShuttlX`
   - Add a second target `ShuttlXWatchTests` against `ShuttlX Watch App` *only if* you want to test watch-specific logic; for now skip — RecoverySegmenter is platform-neutral and can be tested from iOS.

2. **Folder layout**
   ```
   ShuttlXTests/
     Segmenter/RecoverySegmenterTests.swift   ← start here
     IntervalEngine/IntervalEngineTests.swift
     Analytics/AnalyticsEngineTests.swift
     Models/TrainingSessionCodableTests.swift
     Support/Fixtures.swift                    ← session factories
   ```

3. **Seed test (write this first)** — `RecoverySegmenterTests`:
   - `test_gymStrength_idle_to_work_after_minWorkDuration_with_elevated_HR_and_motion`
   - `test_gymStrength_work_to_rest_after_motion_stops_for_restEntryDelay`
   - `test_rest_emits_HRR1_at_60s_within_tolerance`
   - `test_rest_emits_HRR2_at_120s_within_tolerance`
   - `test_rest_timeout_returns_to_idle_at_restTimeoutDuration`
   - `test_cardiacRehab_dual_condition_stationary_AND_hr_rise`
   - `test_cardiacRehab_fallback_after_45s_regardless_of_HR`
   - `test_cardiacRehab_walk_stop_debounce_walkStopConfirmDuration`

4. **CI**: add a `test` job to `.github/workflows/test.yml` (already exists) running `xcodebuild test -scheme ShuttlX -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`. Don't gate `main` on tests yet — let the harness mature for a week first.

5. **Delete the misleading scripts in `tests/`** (`debug_ui_freeze.swift`, `sync_fix_implementation.swift`, `sync_fix_verification.swift`, `test_phase19_final_integration.swift`) — they look like tests but are dead scripts. Move the active shell scripts to `scripts/`.

### Why this is achievable today
- `RecoverySegmenter` is a pure `struct` with `mutating func tick(hr:activity:maxHR:now:) -> [SegmenterEvent]`. Zero mocking required. Inject `now` to control time.
- `IntervalEngine` is `@MainActor` but its state is observable and `tick(heartRate:distance:)` is trivially callable.
- `AnalyticsEngine` is `enum` with `static func`s — pure.
- `TrainingSession` Codable round-trip can be verified with fixtures, catching schema-evolution regressions early.

---

## Scalability concerns (brief, since these were P2 in the prompt)

- **1,000 sessions, no GPS:** ~5–10 MB JSON, ~50ms decode. Fine.
- **100 1-hour GPS workouts:** 100 × 2000 capped route points × ~80 bytes = ~16 MB. JSON encode/decode on every save becomes 200–400ms — felt as UI hitches. **Mitigation:** store `route` in a sidecar `routes/<session-id>.json` file, lazy-load on detail view. Effort M.
- **WCSession 200KB payload limit:** already correctly handled with size-based routing (file transfer > 200KB, userInfo > 50KB, sendMessage otherwise). Good.
- **CloudKit:** already paginated at 200 records, incremental pull via `modifiedDate` predicate (H7), `.ifServerRecordUnchanged` conflict resolution (H8). This is the most mature subsystem in the app.

---

## Priority roadmap

1. **[quick — ½ day]** Add `ShuttlXTests` target + `RecoverySegmenterTests` seed (P0-3 / Refactor #3). High signal, zero risk.
2. **[quick — 2 hours]** Add `schemaVersion: Int = 3` to `TrainingSession` (P1-6). Prevents future migration pain.
3. **[medium — 1–2 days]** Move models + theme primitives into the empty `Shared/` SPM package that `Package.swift` already declares (P0-2 / Refactor #2). Eliminates the drift you already have.
4. **[medium — 1 day]** Extract `SessionStore` and remove duplicate JSON I/O across `SharedDataManager`/`DataManager` (P1-3 / Refactor #4).
5. **[medium — 1 day]** Decouple `SharedDataManager` (iOS) into `WCSyncCoordinator` + `LiveWorkoutMirror` (P1-2).
6. **[large — 3–5 days]** Split `WatchWorkoutManager` behind the same facade (P0-1 / Refactor #1). Do this *after* you have at least `RecoverySegmenterTests` + `IntervalEngineTests` passing, so regressions surface immediately.
7. **[medium — 1 day]** Split `ThemeAssets.swift` per-theme (P1-7 / Refactor #5).

Stop there. Nothing in P2 is worth doing until items 1–7 are complete.
