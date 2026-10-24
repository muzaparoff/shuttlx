# Wave 5: code health (C2-C8), October 2026

Status: plan only, written 2026-10-24. Nothing is implemented. Board: `docs/tasks/2026-10-audit-waves.md` (Wave 5).
Source audit: session scratchpad `audit2/code.md` (C1-C18; C1 shipped in Wave 0).

Every finding was re-checked against the working tree as it stood on 2026-10-24: HEAD `e0749c8` (Part A of Wave 4 committed), plus the uncommitted Part B work (B0 `RouteStore` / `RouteSummary`, B1 rename `route` to `inlineRoute`) and the uncommitted Discard change in `iPhoneWorkoutTimerView.swift`. Line numbers are from that tree and will drift.

**Evidence labels.** *Measured* means I ran something and the output is quoted. *Code reading* means the finding is an unverified hypothesis under the CLAUDE.md root-cause rule; the "Measure" line says how to confirm it.

## 0. What I measured for this plan

1. **Warnings in the normal build today** (scratch logs `b1-ShuttlX.log` / `b1-ShuttlX_Watch_App.log`, Swift 5 mode, minimal checking). There are 3 concurrency warnings, all in `DataManager.swift`: `:452`, `:468` and `:521`, each "capture of 'inbox' with non-Sendable type `SessionInbox<TrainingSession>` in a '@Sendable' closure". The rest are `weak`-capture warnings (`DataManager.swift:453,522`, `PhoneSyncCoordinator.swift:1071`, `WatchSyncCoordinator.swift:593,702,1398`, `ShuttlXApp.swift:236,239`), `SyncDebugView.swift:187` (main-actor call from a Timer closure), `TodayTimeline.swift:266` (main-actor static `wide`), deprecations in `FormattingUtils.swift:15`, and self-imports in `Shared/ExerciseDevice.swift:2` and `Shared/TrainingPlan.swift:2`.
2. **`SWIFT_STRICT_CONCURRENCY=complete`, Swift 5 mode, both schemes** (own `-derivedDataPath`, logs `scratchpad/w5-strict-ios.log` and `w5-strict-watch.log`). It gives 65 unique warnings: Shared 14, iOS app 19, watch app 26, iOS widgets 4, watch widgets 2. The iOS app count is a **lower bound**: compilation stopped on one error. `iPhoneHapticPlayer.swift:14`, a `nonisolated init()` on a `@MainActor` class that holds UIKit generators, fails with "return from initializer without initializing all stored properties". The watch app's 26 are mostly the `[String: Any]` WC payloads crossing into `Task { @MainActor in }` (`WatchSyncCoordinator.swift:723,744,828,832,878,924,961,1127`).
3. **Shared package in Swift 6 language mode** (`swift build -Xswiftc -swift-version -Xswiftc 6`, log `scratchpad/w5-spm6.log`). It fails with 6 errors in 2 files: `BuiltInPlans.swift:10,14,50,82,116` and `ExerciseDevice.swift:87` (static lets of non-`Sendable` `TrainingPlan` / `ExerciseDevice`). Making those two types `Sendable` may reveal a second round of errors. This is the first pass only.
4. **Decode cost** (from the Wave 4 plan's harness, macOS release build): a session at the watch route cap of 2000 points is about 383 KB and decodes in about 2.9 ms (582 ms for 200 sessions). The iPhone time has not been measured.

## 1. Part B overlap (read this first)

Part B is reserved for the Wave 4 agent. It covers B1 (in the working tree now), then B2-B4, then B6.

| Part B step | Files |
|---|---|
| B1 rename (uncommitted) | `Shared/TrainingSession.swift`; watch `WatchSyncCoordinator`, `WatchWorkoutManager`, `WorkoutPersistence`; iOS `AnalyticsEngine`, `HealthKitImporter`, `PhoneSyncCoordinator`, `iPhoneWorkoutController`, `ShuttlXApp`, `TodayTimeline`, `HistoryMapView`, `SessionDetailView`; tests |
| B2 readers | `SessionDetailView`, `TodayTimeline`, `HistoryMapView`, `AnalyticsEngine`, `ShuttlXApp` (demo), `DataManager` |
| B3 externalize | `DataManager`, `Shared/RouteStore.swift` (+ snapshot helper), `PhoneSyncCoordinator` (relay stripping), tests |
| B4 CloudKit | `CloudKitSyncManager` |
| B6 cleanup | `DataManager` |
| Not Part B, but uncommitted | `ShuttlX/Views/Workout/iPhoneWorkoutTimerView.swift` (Discard) |

Once B1 is committed, **Part B never touches a watch file again**. So the watch work (C2, C8, the watch half of C4 and C7) can run in parallel with B2-B4. The iOS work that touches `DataManager`, `PhoneSyncCoordinator` or `ShuttlXApp` (C3, the phone half of C6/C7, the C4 test target) waits until B4 is committed. Before editing `Shared/StoreSupport.swift`, confirm with the Part B agent that their B3 helper lives in `RouteStore.swift` and not there.

## 2. Items

### C2: watch UI re-renders on every manager publish

**Still true.** Measured by grep, unverified at runtime.
- `WatchWorkoutManager` is an `ObservableObject` with 40 `@Published` properties (`WatchWorkoutManager.swift:23-308`). It is held as `@StateObject` in `ShuttlXWatchApp.swift:26` and injected with `.environmentObject`.
- `TrainingView` is one struct (`TrainingView.swift:7-8`). Its pages are computed properties in extensions: `runningPage` and `freeRunMetricsPage` (`+Running.swift:14,196`), `fullWorkoutDisplayTab` (`+Metrics.swift:40`) and `controlsTab` (`+Controls.swift:8`). Together they read `workoutManager.` 91 times. Extensions are not invalidation boundaries, so each HR, energy, distance, pace or pedometer publish runs the body of every page and of the overlay chain.
- **Gym recovery** still publishes on every tick: `restElapsedTime` and `stationElapsedTime` (`WatchWorkoutManager.swift:1061-1069`), plus `recoveryState` and `recoverySetNumber` (`:1071-1072`). These setters fire even when the value has not changed, so the clock isolation (`WorkoutClock`, `:14-20`) does not cover this mode. The tick also reads UserDefaults every second (`HeartRateZoneCalculator.fromSharedDefaults()`, `:1056`).
- **Already fine:** the free-run and interval 1 Hz clock (`WorkoutClock`), and the interval views that observe the engine directly. The watch has no Combine sinks or `$workoutManager` bindings (grep), so moving to `@Observable` is mechanical.
- **Related (code reading):** `TrainingView+Metrics.swift:161,312` and `TrainingView.swift:119` read `WatchSyncCoordinator.shared.distanceUnit` / `.heartSafety` without observing them. A unit or limit synced mid-workout shows on the next HR publish, which comes within seconds, so this is harmless today. It would go stale if publishes became rarer.

**Measure.** A DEBUG-only body counter (an `OSSignposter` event plus `Self._printChanges()` behind a `SHUTTLX_PRINT_CHANGES=1` env flag) in `TrainingView.body` and in each page. Run a 2-minute free run and a gym recovery run on the watch simulator, which produces simulated HR and distance. Count body runs per minute. The simulator is fine for counts. Cost per pass needs the Instruments SwiftUI template on a watch.

**Options.**
1. Split the pages into their own `View` structs that take plain values. This works with `ObservableObject`, but `TrainingView` still observes everything and has to plumb every value down. Effort S-M.
2. Move `WatchWorkoutManager` (and `WatchSyncCoordinator`) to `@Observable`. That means `@State` in the App, `@Environment(WatchWorkoutManager.self)` in about 14 views, and `@ObservationIgnored` on internal hot state such as route arrays and pace windows. On its own this fixes the App and `ContentView` passes, but **not** `TrainingView`: its single body reads HR, distance and pace, so it would still re-render on all of them. Effort M.
3. **Option 2, then split the pages** into structs that each read the manager from the environment. With Observation, each page tracks only the properties it reads, so the split needs no value plumbing. Effort M plus S-M.

**Pick: 3, with the gym fix done first.** This differs from the audit's pick (split first). With `ObservableObject` a split needs every value passed by hand. With `@Observable` it comes free. The package floor (C14) does not block this: the watch `IntervalEngine` is app-local until C4, and the Shared engine can stay `ObservableObject`, observed with `@ObservedObject` as today.

**Gym fix (S).** Publish `restStartTime` / `workStartTime` only when they change, and compute the elapsed seconds inside the existing 1 Hz `WorkoutClockReader` in `RecoveryWorkoutView.swift:83,86,120`. Assign `recoveryState` / `recoverySetNumber` only when they differ. Read the max-HR calculator once at workout start.

**Files:** `WatchWorkoutManager.swift`, `ShuttlXWatchApp.swift`, watch `ContentView.swift`, `TrainingView*.swift`, `RecoveryWorkoutView.swift`, `StartTrainingView`, `WorkoutSummaryView`, `ProgramSelectionView`, `WatchSyncCoordinator.swift` (if migrated too). Part B overlap: only B1. Start after B1 is committed.

**Behavior risk.** Medium, and it is UI-only. Under Observation a view updates only when a property it read changes. A body that silently depends on an unrelated publish to refresh (reads of `Date()`, UserDefaults or another singleton) will go stale. Go through the 91 reads looking for that pattern. The snapshot harness (every `SHUTTLX_SNAPSHOT_*` screen on 40 mm and 46 mm) must match before and after.

**Tests.** None in SPM; this is view code. Gate on: the snapshot set, body counts before and after (they must go down), and one free run plus one interval run on the watch simulator.

### C3: iOS root re-renders at high frequency

**Still true, with one correction and one new finding.** Code reading.
- `ShuttlXApp.swift:33-40` holds 8 `ObservableObject`s as `@StateObject`. The App body reads `workoutController` and `sharedDataManager` (`:84-107`) and binds `$workoutController.isPresentingTimer` (`appRoot`, `:185-205`), so every publish on those objects re-runs the App body.
- `iPhoneWorkoutController.elapsedTime` is written every second (`:639`). **New:** the controller also forwards every `IntervalEngine.objectWillChange` into its own (`:212-214`), so the engine's 1 Hz countdown fans out through the root as well.
- `PhoneSyncCoordinator.log()` appends to `@Published syncLog` (`:1042-1048`; 78 `log(` call sites in the file). Only `SyncDebugView` and the dead `DebugView` read it. `DashboardView.swift:9` and `ProgramsTabView.swift:8` observe the whole coordinator, so every log line re-runs Today.
- **Correction to the audit:** a single live-metrics message writes about 12 `@Published` values synchronously, but SwiftUI coalesces them into one pass, roughly one pass per message (the watch broadcasts every 3 s, `WatchWorkoutManager.swift:1075`). The real hot spots are the 1 Hz controller writes and the `log()` storm.

**Measure.** The same DEBUG body counter in `ContentView`, `DashboardView` and `ProgramsTabView`. Run three cases on the simulator: idle Today with a paired watch sim, a phone free run, and a phone interval run. Cost needs Instruments on the iPhone.

**Options.**
1. Move `iPhoneWorkoutController`, `PhoneSyncCoordinator` and `DataManager` to `@Observable`. `DataManager` relies on Combine `$sessions` / `$syncedSessions` / `$edits` pipelines (`DataManager.swift:64,112`), and there are 51 property-wrapper sites. Effort M-L.
2. **Targeted split, the watch pattern.** Add a `PhoneWorkoutClock` (holds `elapsedTime`, observed only by the timer view and the Live Activity update). The timer view observes the engine directly, and the forwarding sink goes away. Make `syncLog` non-published; `SyncDebugView` already refreshes on its own 2 s timer (`SyncDebugView.swift:186`). Move the `fullScreenCover` out of the App body into a small wrapper view that observes only the controller. Effort S-M.
3. Stop the App observing at all: hold the owned objects as `@State` (a reference held in `@State` is not observed) and pass them with `.environmentObject`. This removes the App pass, but `Dashboard` still fans out. Effort S. It is part of 2 anyway.

**Pick: 2 (it includes 3).** Option 1 waits for a later wave, together with C14.

**Files:** `ShuttlXApp.swift`, `iPhoneWorkoutController.swift`, `iPhoneWorkoutTimerView.swift`, `PhoneSyncCoordinator.swift`, `SyncDebugView.swift`, `DashboardView.swift`, `ProgramsTabView.swift`, `LiveActivityManager` call site. Part B overlap: `ShuttlXApp` (B2), `PhoneSyncCoordinator` (B3), and the uncommitted Discard change in the timer view. **Wait for B4 and the Discard commit.** Do it after C4, because both edit the controller.

**Behavior risk.** Low to medium. The timer view could freeze if it stops observing the right object; the engine-forwarding comment at `:200` exists because that happened once. e2e `workout10` and `discard` cover the timer.

**Tests.** e2e smoke, workout10 and discard. Body counts must go down.

### C4: the interval engine that runs on the watch is not the one tested, and there is no app test target

**Re-verified.** Part A made the `IntervalType` name collision moot: one enum, `Shared/IntervalEngine.swift:173`, and both models now live in `Shared/`. The audit remark that the parity test should guard the duplicated models is also moot. What remains:
- The watch runs its own engine (`ShuttlX Watch App/Services/IntervalEngine.swift`). Its `tick(heartRate:distance:workoutElapsed:)` (`:55`) is wall-clock based (late ticks self-heal) and clicks 3-2-1 (`StepCountdownCue`). The Shared engine's `tick(heartRate:distance:)` (`Shared/IntervalEngine.swift:67`) counts ticks (`stepElapsed += 1`) and taps once at 5 s. **The tested engine is the weaker one, and it is the one the iPhone runs.** On the iPhone a late or dropped tick loses a second; the timer is a `DispatchSource` on a global queue hopping to the main actor (`iPhoneWorkoutController.swift:593-603`). This is an unverified hypothesis: no drift has been seen. Measure by logging the engine's elapsed time against the wall clock during a 20-minute iPhone interval run with the screen locked.
- iOS `skipStep()` fast-forwards by calling `tick` N times (`iPhoneWorkoutController.swift:525-533`). A wall-clock engine needs a real `skipStep(at:)` instead.
- The watch also keeps its own `RecoverySegmenter`. `WatchParityTests` pins it to the Shared copy (comments, `public` and `Sendable` only), so it can be deleted safely.
- There is no app or unit test bundle: pbxproj has 2 applications and 3 app extensions. Note that `test.yml` passes `run_tests: false` to appstore-kit. Check whether `swift test` really runs in CI, as CLAUDE.md says.

**Engine unification (Phase 4), options.**
1. **Port the watch's wall-clock semantics into `Shared/IntervalEngine`**: `tick(..., workoutElapsed:)`, multi-step catch-up, `StepCountdownCue` through a new `HapticKind`, and `skipStep(at:)`. Add a `WatchHapticPlayer` (work `.start`, rest `.directionDown`, warm-up/cool-down `.click`, complete `.success`, countdown `.click`), switch the watch call sites, and delete the watch engine and `RecoverySegmenter`. Both platforms then share the better behavior. Effort M.
2. Move the watch engine into Shared as is and delete the old Shared one. The same result in the end, but the iOS adapter (descriptors, `IntervalResult`) has to be rewritten in the same step. Effort M.
3. Keep both engines and add a dual-engine parity test. This catches drift but keeps two copies. Effort S.

**Pick: 1.** Keep `IntervalStepDescriptor` / `IntervalResult` for now: the watch builds descriptors from `template.allSteps` and converts results at its stop site, as iOS does today. That keeps `iPhoneWorkoutTimerView` untouched. Collapsing those types into `IntervalStep` / `CompletedInterval` is a later S cleanup.

**Dual-engine gate before the watch engine is deleted.** Copy the current watch engine into the test target as `LegacyWatchIntervalEngine` (it compiles on macOS; the WatchKit code is behind `#if os(watchOS)`). Feed both engines the same scenarios: normal 1 s ticks, a dropped tick, a 90 s suspension that spans two steps, a pause, and the last step. Assert the same step sequence, the same `CompletedInterval` values and the same click beats. Delete the copy one release later.

**App test target, options.**
1. **A hosted iOS XCTest target (`ShuttlXAppTests`)** for the code SPM cannot reach: `DataManager` ingest, dedup, merge and the inbox, and later the phone router. This needs small seams: `DataManager(container:autoload:)` without init side effects (`DataManager.swift:57-66` loads the file, checks HealthKit and wires the coordinator), and no `WCSession.activate()` when running under tests. Effort M.
2. SPM only: keep moving decisions into pure Shared types, the `PhoneDiscardRule` / `SafetyPromptSchedule` pattern. This is cheap and proven, but `DataManager` stays untested. Effort S per rule.
3. A hosted watch test target. `WatchWorkoutManager` needs an `HKHealthStore` and a session, so the value is low. Effort M-L.

**Pick: 1, scoped to `DataManager` plus the router, and started only after Part B lands** (it edits `DataManager` and pbxproj). Keep using 2 for everything else.

**Files:** `Shared/IntervalEngine.swift`, `Shared/HapticPlayer.swift`, `iPhoneHapticPlayer.swift`, `iPhoneWorkoutController.swift` (tick and skip call sites; B1 only), watch `WatchWorkoutManager.swift` (6 engine sites), a new watch `WatchHapticPlayer.swift`, deletion of the watch `IntervalEngine.swift` and `RecoverySegmenter.swift`, `tests/ShuttlXTests/IntervalEngineTests.swift` plus the legacy fixture, and deletion of `WatchParityTests.swift`. For the test target: pbxproj, `DataManager.swift`, the scheme. The engine work can start after B1; the test target waits for B4.

**Behavior risk.** High for the engine: step timing, results and haptics on both platforms, and it needs a device run. Low for the test target.

**Tests.** The dual-engine parity suite, and existing `IntervalEngineTests` updated to the wall-clock API, plus new cases for skip, catch-up and the click beats. In the test target: ingest dedup by id, placeholder replacement, the cleared-at cutoff, inbox drain and acknowledgement.

### C5: no compiler data-race checking

**Still true:** `SWIFT_VERSION = 5.0` ×10 in pbxproj, no `SWIFT_STRICT_CONCURRENCY`, Package tools 5.9. Section 0 has the measured counts. Most warnings are cheap. These ones matter:
- `DataManager.swift:452,468,521`: `SessionInbox` holds only a `let directory: URL` (`Shared/StoreSupport.swift:156`). Adding `extension SessionInbox: Sendable {}` clears all three **without touching `DataManager`**.
- `iPhoneHapticPlayer.swift:8,14`: drop `@unchecked Sendable` (a `@MainActor` class is already `Sendable`) and make `init` main-actor. It is built on the main actor (`iPhoneWorkoutController.swift:118`).
- `ShuttlX/Services/WidgetDataProvider.swift:11-12` and `ShuttlXWatchWidgets/WatchWidgetDataProvider.swift:11-12`: mutable static caches. Timeline providers can be called concurrently, so this is a real (low-impact) race. Put a lock around them or drop the cache.
- False positives with a one-line fix: `WorkoutPersistence.swift:30-48` (use `let stripped`), and `WatchWorkoutManager.swift:2431,2437` (the `resumeOnce` closure is guarded by a lock; mark it `@Sendable`).
- The WC `[String: Any]` `sending` warnings are fixed at the edge in C7.

**Options.**
1. **Swift 6 language mode for the Shared package only** (tools 6.0, `swiftLanguageMode(.v6)`), plus `SWIFT_STRICT_CONCURRENCY=complete` in Swift 5 mode for each app target, one at a time. Effort S plus S-M.
2. Complete checking everywhere at once. One big commit that mixes many causes. Effort M.
3. Swift 6 mode plus default MainActor isolation for the app targets. This is a behavior change in the WC and HK delegates; not now. Effort M-L.

**Pick: 1.** Order: Shared fixes, then widgets, then watch (after C7-watch), then iOS (after C7-phone and C3). Swift 6 mode for Shared waits until Part B's Shared files are final, because new Swift 6 errors would land in `RouteStore` / `RouteSummary` / `TrainingSession`.

**Files:** `Package.swift`, `Shared/BuiltInPlans.swift`, `TrainingPlan.swift`, `ExerciseDevice.swift`, `StoreSupport.swift`, `iPhoneHapticPlayer.swift`, both widget data providers, `WorkoutPersistence.swift`, `WatchWorkoutManager.swift`, pbxproj (per-target setting).

**Behavior risk.** Low. Annotations only, apart from the widget lock.

**Tests.** `swift test` under Swift 6 mode. Warning count per target, recorded in the commit message and required not to rise.

### C6: session decode on the iPhone main actor

**Still true, and smaller than the audit said.** All four receive paths decode inside `Task { @MainActor in }` (`PhoneSyncCoordinator.swift:1127,1184,1250,1326`), and so does the base64 decode (`sessionBytes`, `:259`, called inside the task). The inbox re-encode also runs on the main actor (`ingestCounting` → `inbox.add`, `:242-245`). But the watch caps routes at 2000 points (`WatchWorkoutManager.swift:250`), so a real payload is about 400 KB. At the measured ~3 ms per decode on the Mac (iPhone not measured), that is far below a hang. The audit's "8 MB" is the validation cap, not a real size.

**Options.**
1. **Decode at the delegate edge, before the hop.** WC calls its delegate serially on a background queue, so order is kept. Effort S.
2. A `nonisolated` decode helper awaited from the main actor. Same effect, and it changes ordering subtly. Effort S.
3. An `actor SessionIngest` that decodes, validates and writes the inbox. Effort M.

**Pick: 1, folded into C7** (the router decodes `saveSession` at the edge). Moving the inbox write off main changes the crash-safety order (the inbox entry must exist before the watch is told "saved"), so do it only if a Hangs trace shows it.

**Measure.** Instruments Hangs on the iPhone while the watch sends a 60-minute GPS session.

**Files:** `PhoneSyncCoordinator.swift`. **Waits for B3.**

**Behavior risk.** Low. **Tests:** covered by the C7 tests.

### C7: WatchConnectivity dispatch written several times, and the copies have drifted

**Still true.** The phone has four switch blocks (`PhoneSyncCoordinator.swift:1119-1288`) plus the file path (`:1302`). The channel matrix, from code:

| Action (phone receives) | message | message+reply | userInfo | context | file |
|---|---|---|---|---|---|
| saveSession | yes | yes | yes | - | yes |
| workoutStarted | handshake only | handshake only | handshake **+ watch-start Live Activity** | - | - |
| workoutStartIgnored, heartAlert, workoutStopped | yes | yes | yes | - | - |
| updateSessionEffort | yes | **no** | yes | - | - |
| lastSessionID | **no** | **no** | yes | yes | - |
| liveMetrics | yes | yes | no (correct: a queued snapshot is stale) | yes | - |

These gaps are latent today. The watch sends watch-originated `workoutStarted` only by userInfo (`LiveMetricsBroadcaster.swift:131`), and effort with `replyHandler: nil` (`WatchSyncCoordinator.swift:262`). The watch side has the same shape: `didReceiveMessage` and the reply variant repeat the same switch (`WatchSyncCoordinator.swift:742-868`), and only the userInfo path applies the 120 s / 30 s stale windows (`dispatchWorkoutControl`, `:983-1010`).

**Options.**
1. **One `route(_ payload:, channel:) -> reply` function per side**, called by every delegate, with one explicit per-channel rule (only "liveMetrics never from userInfo" and the stale windows). Wrap the payload in a `Sendable` box at the edge: plist values are immutable, so a documented `@unchecked Sendable` on a one-field struct is justified. Decode `saveSession` there too (C6). Add a pure `Shared/WCAction.swift` (action names as a `String` enum used by senders and receivers, raw values pinned by a test) and `WCRoutePolicy.accepts(action, channel)`. Effort M.
2. Fully typed `enum WCMessage: Codable` with a payload struct per case, shared by both sides. Exhaustive and testable, but every sender changes and version skew needs care. Effort L.
3. An `AsyncStream` inbox with one consumer. This guarantees order, but delegate tasks with explicit `@MainActor` already start in order (SE-0431), so it is machinery for nothing. Effort M.

**Pick: 1.** Option 2 can grow out of it later. `HKWorkoutSession` mirroring for live data is a separate project, not in Wave 5 (decision 7).

**Behavior change.** Intended. `workoutStarted` by any channel now does what userInfo does today, and `lastSessionID` / effort work on every channel. Stale windows apply wherever `sentAt` is present; a live message is fresh, so for sendMessage nothing changes.

**Files:** `PhoneSyncCoordinator.swift` (waits for B3), `WatchSyncCoordinator.swift` (after B1, after C8 by the same agent), `LiveMetricsBroadcaster.swift` and the other senders (action enum only), the new `Shared/WCAction.swift`.

**Tests.** SPM: `WCActionTests` (raw values pinned, since they are wire format) and `WCRoutePolicyTests` (the matrix above, with the intended changes). Hosted target (C4): feed `workoutStarted` with `sessionId` X through the message path and assert `currentWatchSessionId == X`. That fails today, which confirms the audit's hypothesis. e2e discard and workout10 cover the handshake.

### C8: the watch's unsynced-session queue can lose or reorder workouts

**Still true, and worse than the audit said.** Code reading.
- (a) The load uses `try?` (`WatchSyncCoordinator.swift:549-552`). A corrupt `pending_sync_sessions.json` reads as `[]`, and the next save with an empty queue deletes the file (`:523-524`).
- (b) Each save is its own `Task.detached` (`:521`). These tasks are unordered, so an older snapshot can land last.
- (c) **New:** the load starts asynchronously in `init` (`:75-77`). A session queued before it finishes is saved alone, which overwrites the file the load is about to read. Then `pendingSessions = pending` (`:564`) replaces the in-memory list instead of merging. A workout that finishes, or a send that fails, right after launch can wipe older unsynced workouts. Reproduce by queueing a session in DEBUG before the load completes.
- The writes also use `.completeFileProtection` (`:527`, C18).

**Options.**
1. Keep one file. Run every save and load on `sessionStoreQueue`, use `do/catch`, back up and keep an unreadable file, and merge on load. Effort S.
2. **One file per session in a `pending_sync/` folder, using the Shared `SessionInbox`** (`StoreSupport.swift:156`; it already writes with `StoreFile.writeOptions` and sets unreadable entries aside as `.bad`). With no whole-array rewrite, (a), (b) and (c) all go away. It needs a `put(_:)` that overwrites, because `add` is a no-op on an existing id and the effort update edits a pending session (`:600-604`). Run the adds and removes on `sessionStoreQueue`, so an add and a remove for the same id stay in order. One-time migration: read the old file leniently, `put` each session, and delete the old file only after every put succeeds. Purge removes by id. Effort S-M.
3. Treat WC `outstandingUserInfoTransfers` / `outstandingFileTransfers` as the queue and drop the file. The OS persists them, but we lose control of retry and purge. Effort M.

**Pick: 2.**

**Files:** `WatchSyncCoordinator.swift`, `Shared/StoreSupport.swift` (`put`, `Sendable`; check with the Part B agent first). Part B overlap: B1 only. Start after B1.

**Behavior risk.** Medium. This is the path that saves unsynced workouts. The migration is the risky moment.

**Tests.** SPM `StoreSupportTests`: `put` overwrites; `add` then `remove` in order; a corrupt entry is set aside and the others survive; migration of a v1 array file, including a half-corrupt one (per record, `LenientJSON`). Watch simulator: write garbage to the old file, relaunch, check that the file still exists or was set aside, and that a new session is still queued.

## 3. Order of steps

Each step is one commit and must pass: `bash tests/build_and_test_both_platforms.sh --clean --build`, `swift test`, e2e `smoke,workout10,discard`, and for watch steps the snapshot set on 40 mm and 46 mm. "‖ B" means the step can run while Part B B2-B4 is in flight (no shared files). "after B" means it waits for B4 to be committed.

**Precondition:** Part B's B1 and the Discard change are committed.

**TestFlight build 1: low-risk health**
1. **C5a** (S, ‖ B): Shared `Sendable` (`TrainingPlan`, `ExerciseDevice`, `SessionInbox`), `iPhoneHapticPlayer`, the widget cache lock, `WorkoutPersistence` / `resumeOnce`. Check: the 3 `DataManager` warnings are gone from the normal build.
2. **C8** (S-M, ‖ B; watch agent): pending queue as an inbox, with migration.
3. **C2a + C2b** (S, ‖ B; watch agent): body counters (DEBUG) with before numbers, then the gym publish fix with after numbers.

**TestFlight build 2: watch behavior (one device session covers both)**
4. **C4a** (M, ‖ B; watch agent, with the iOS controller lines touched only for tick and skip): wall-clock Shared engine, `WatchHapticPlayer`, legacy parity suite, then the switch. Delete the watch engine and `RecoverySegmenter` in a separate follow-up commit.
5. **C2c** (M, ‖ B; watch agent): `@Observable` manager and coordinator, then the page structs. Gate: body counts down, snapshots unchanged.
6. Device run on the owner's watch and iPhone: a free run, an interval run (check step timing against a stopwatch, the 3-2-1 clicks, the result card), and a gym recovery run.

**TestFlight build 3: sync (after B)**
7. **C7-watch** (M, can start ‖ B; watch agent): router, the payload box, `WCAction` / `WCRoutePolicy` in Shared.
8. **C7-phone + C6** (M, after B): router, decode at the edge.
9. **C5c-watch + widgets** (S): complete checking on the watch app and both widget targets.

**TestFlight build 4: iOS (after B)**
10. **C3** (S-M): phone clock, engine observation, `syncLog`, the App-level cover wrapper.
11. **C4b** (M): hosted `ShuttlXAppTests` with the `DataManager` seams; first tests: ingest and the router matrix.
12. **C5b + C5c-iOS** (S-M): Swift 6 mode for the Shared package, complete checking for the iOS app.
13. Docs: CLAUDE.md, `.claude/rules/watchos.md` / `services.md` / `models.md`, the skills (`observable-theme-patterns` parity text, `swift-concurrency-review` known-good list), `docs/memory/`.

The watch agent owns steps 2-5 and 7 in sequence. The iOS agent owns 8, 10 and 11. Never run two writers on `WatchSyncCoordinator.swift` or `iPhoneWorkoutController.swift` at the same time. C4a touches the controller's tick and skip lines, so it must be committed before C3 starts.

## 4. Bugs found along the way (not fixed; each folds into an item above)

| Bug | Evidence | Where it is fixed |
|---|---|---|
| A session queued right after watch launch can overwrite older unsynced sessions | `WatchSyncCoordinator.swift:75-77, 516-534, 564` (code reading) | C8 option 2. Other fixes: C8 option 1, or a "loaded" gate that defers saves until the load finishes (S) |
| The iPhone interval countdown counts ticks and can lose time on late ticks | `Shared/IntervalEngine.swift:70-71` (code reading) | C4a |
| `iPhoneHapticPlayer` creates UIKit generators in a `nonisolated init` | measured: an error under complete checking | C5a |
| Widget static caches are mutated without a lock | measured warning, `WidgetDataProvider.swift:11-12` | C5a |
| CI may not run `swift test` (`run_tests: false` in `test.yml`), although CLAUDE.md says it does | `.github/workflows/test.yml` | Decision 3 |

## 5. Decisions the owner must make

1. **C2:** move the watch manager to `@Observable` and then split the pages (my pick), or split the pages only and keep `ObservableObject`?
2. **C4 haptics on the iPhone:** once both platforms share one engine, should the iPhone get the watch's 3-2-1 taps before each step change, or keep its single tap at 5 s? Pick: 3-2-1 on both (one rule). The iPhone also gets the wall-clock countdown; I recommend yes.
3. **C4 test target and CI:** add the hosted iOS test target after Part B (pick)? Should CI run it and `swift test` (flip `run_tests` in `test.yml`, which costs CI simulator time)?
4. **C5:** Swift 6 mode for Shared only and complete checking for the apps (pick)? Turn on appstore-kit's `warnings_gate` once a target reaches zero warnings?
5. **C6:** accept folding it into C7 with no separate work, since real payloads are about 400 KB?
6. **C8:** per-session pending files with a one-time migration (pick), or the single-file fix?
7. **C7:** keep `HKWorkoutSession` mirroring (Apple's multidevice workout model, which could remove much of the live-metrics and handshake code) as a separate future project, outside Wave 5?
8. **Release shape:** four TestFlight builds as in section 3, or merge builds 1 and 2 to save a device session (harder to bisect)?
