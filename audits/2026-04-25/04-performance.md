# Performance Audit — ShuttlX iOS + watchOS

Date: 2026-04-25
Scope: launch, memory, battery, render efficiency, JSON overhead, HealthKit/WCSession frequency, watchOS constraints.

## Summary

Nine issues found across five focus areas. No P0 issues. Two P1 issues both live in the hot workout path on Watch. The remaining seven range from P2 to P3.

---

## Finding 1 — P1: TrainingView re-renders on every 1 Hz heart-rate tick

**File:** `ShuttlX Watch App/Views/TrainingView.swift:136-194`

**What happens.** `TrainingView` is a single `@EnvironmentObject WatchWorkoutManager`. `WatchWorkoutManager` is `@MainActor ObservableObject` with a large set of `@Published` properties (elapsedTime, heartRate, calories, totalDistance, totalSteps, currentPace, currentActivity, isPaused …). Every 1 Hz `DispatchSourceTimer` tick calls `updateElapsedTime()` which mutates at least `elapsedTime` and `currentSegmentTime`, causing SwiftUI to re-evaluate `TrainingView.body`. `body` calls five computed properties (`heartRateText`, `isHighIntensityWarning`, `distanceText`, `paceText`, `accessiblePace`), resolves `ShuttlXColor.forHRZone(workoutManager.heartRate)` and `ShuttlXColor.forStepType(...)`, and triggers `.contentTransition(.numericText())` on two `Text` nodes every second. On Series 6 / SE, each `numericText` transition costs a cross-dissolve pass on the GPU.

In addition, `broadcastLiveMetricsIfNeeded()` runs inside the same tick (line 533) and checks `lastLiveUpdateTime` — but this is still evaluated on the main actor every second. After 60 minutes that is 3,600 main-actor wakeups with a full SwiftUI diff per wakeup.

**Why it matters.** On Series 6 the GPU has no dedicated power rail separate from the CPU; every extra compositing pass drains the battery. Apple recommends splitting `ObservableObject` state by update frequency or using `@Observable` (`Observation` framework) to track only the properties a given view actually reads. With the current design the entire `TrainingView` — including the controls tab it cannot currently see — invalidates every second.

**Fix direction.** Split `WatchWorkoutManager` state into two observable objects: a high-frequency `LiveMetrics` (`@Observable`, updated 1 Hz) holding only `elapsedTime`, `heartRate`, `calories`, `totalDistance`, `currentPace`; and a low-frequency `WorkoutState` (`@Observable`) holding `isWorkoutActive`, `isPaused`, `workoutMode`, etc. Views that only display control buttons will no longer be invalidated by HR samples. Alternatively, refactor `fullWorkoutDisplayTab` into a child `WorkoutMetricsView` that injects only the fast-changing properties, bounding invalidation to that subtree.

**Instruments trace.** SwiftUI Profiler template → filter on `TrainingView` → "Body Evaluations" column. Look for 1 Hz constant evaluations of the outer view while the controls tab is not visible.

**Confidence:** high.

---

## Finding 2 — P1: `saveWorkoutDataToLocalStorage()` called twice on every pause

**File:** `ShuttlX Watch App/Services/WatchWorkoutManager.swift:326-343` (explicit `saveWorkoutDataToLocalStorage()` in `pauseWorkout()`) and `:1099-1107` (delegate re-calls it on `.paused` state).

**What happens.** `pauseWorkout()` at line 341 calls `saveWorkoutDataToLocalStorage()`. `HKWorkoutSessionDelegate.workoutSession(_:didChangeTo:...)` at line 1104-1106 *also* calls `saveWorkoutDataToLocalStorage()` when `toState == .paused`. The HealthKit delegate fires asynchronously after `session.pause()` is called, meaning every single pause triggers two full JSON encodes and two atomic `Data.write()` to the App Group container: one from `pauseWorkout()` and one from the delegate. Each write is `[.atomic, .completeFileProtection]` which requires a rename and a key-derivation fence.

A `TrainingSession` with 2,000 route points serialises to roughly 400–600 KB of JSON. Two back-to-back writes of that during an active workout is measurable latency on the main actor.

**Fix direction.** Remove the `saveWorkoutDataToLocalStorage()` call from `workoutSession(_:didChangeTo:...)` — the delegate confirmation is redundant because `pauseWorkout()` already called it synchronously before `session.pause()`. Alternatively, reverse: remove it from `pauseWorkout()` and keep only the delegate, accepting the small async gap.

**Instruments trace.** System Trace → File Activity lane → filter on process `ShuttlX WatchKit Extension` → look for `pwrite`/`rename` pairs that appear twice within ~100ms of each other during pause.

**Confidence:** high.

---

## Finding 3 — P2: AnalyticsEngine scans `sessions` array 8+ times per `recomputeAnalytics()`, with redundant sub-passes

**File:** `ShuttlX/Views/AnalyticsView.swift:52-65`, `ShuttlX/Services/AnalyticsEngine.swift:55-93`

**What happens.** `recomputeAnalytics()` calls: `weeklyTrend` (6 filter passes over all sessions), `personalRecords` (1 full pass), `recoveryStatus` (calls `form()` which calls `fitnessScore()` which calls `weeklyTrainingLoads()` (6 filter passes) plus `fatigue()` which calls `weeklyTrainingLoad()` (1 more filter pass)), `estimatedVO2Max` (1 pass), `estimatePreviousVO2Max` (1 filter + 1 pass), `paceZones` (1 pass), `elevationSummary` (1 pass over all route arrays), `latestElevationRoute` (sort + scan).

`form()` (line 93) calls `fitnessScore(sessions)` then `fatigue(sessions)`. `fitnessScore` calls `weeklyTrainingLoads(sessions, weeks: 6)` which does 6 date-windowed `.filter` passes (line 343). `fatigue` calls `weeklyTrainingLoad` which does another `.filter` (line 60). That is 7 filter passes for `form()` alone — and `recoveryStatus` (line 197) also calls `form()` independently, so those 7 passes happen twice: once for `formScore` and once for `recovery`.

Additionally, `weeklyTrend` (line 165) creates a `DateFormatter` per-call (line 16 of `WeeklySummary.weekLabel`) — a computed property called during `Chart { ForEach(weeklyTrend) ... }` on every SwiftUI body evaluation where the chart is visible. `DateFormatter` initialisation is expensive (~0.5 ms per instance on older A-series).

**Why it matters.** With 500 sessions (the DataManager cap at line 57 of `DataManager.swift`) each filter pass iterates 500 structs. With `TrainingSession` carrying optional arrays (`segments`, `route`, `kmSplits`), each element touch is non-trivial. On an iPhone 16 this is fast; on first load after a long session list rebuild, or when `sessions.count` changes (the task trigger), the main thread stalls for several tens of milliseconds.

**Fix direction.** (1) Merge `form()` into a single function that returns `(fitness, fatigue, form)` to avoid the double-scan. (2) Cache `weeklyTrainingLoads` result and reuse it in both `fitnessScore` and `fatigue` within a single `recomputeAnalytics()` call. (3) Move `DateFormatter` into a `static let` on `WeeklySummary`. (4) Wrap `recomputeAnalytics()` in a detached `Task` and `await MainActor.run` only to assign results, preventing the current synchronous stall on the main thread.

**Instruments trace.** Time Profiler → filter on `recomputeAnalytics` → look for flat-top calls to `Array.filter` and `Date.addingTimeInterval`. CPU Profiler "bottom up" on the main thread during AnalyticsView appearance.

**Confidence:** high.

---

## Finding 4 — P2: `liveRoutePoints` on iOS has no size cap; unbounded growth during 60-minute session

**File:** `ShuttlX/Services/SharedDataManager.swift:203-215`

**What happens.** Every 3-second `sendMessage` from Watch includes the last GPS point (WatchWorkoutManager line 562-565). `handleLiveMetrics` appends to `liveRoutePoints` with only a coordinate-delta check (lines 207-213) — no count ceiling. At 10 m distance filter and walking pace (~1.4 m/s), a new unique point arrives roughly every 7 seconds; at running pace (~4 m/s) every ~2.5 seconds. Over 60 minutes that is 860–1440 appended `RoutePoint` structs. Each `RoutePoint` holds 6 `Double` values plus a `Date` (~80 bytes). At 1440 points the array occupies ~115 KB in memory. That is acceptable in isolation, but `liveRoutePoints` is `@Published` on a `@MainActor` class — every append invalidates any view observing it (the live map view, if rendered).

The Watch-side correctly caps at 2,000 points with downsampling (WatchWorkoutManager line 85, 1143-1155). The iOS side has no equivalent.

**Fix direction.** Add a cap of 1,000 points with the same stride-halving downsampling used on Watch. Insert after the duplicate-suppression check at line 213.

**Instruments trace.** Allocations instrument → filter on `RoutePoint` → track growth over 60-minute workout. Memory Debugger snapshot at 10, 30, 60 minutes.

**Confidence:** high.

---

## Finding 5 — P2: Canvas-based screen backgrounds re-draw on theme-related `@Observable` mutation during workout

**File:** `ShuttlX Watch App/Theme/ThemeModifiers.swift:222-235` (`themedScreenBackground()`), `ShuttlX Watch App/Views/TrainingView.swift:51`

**What happens.** `TrainingView.workoutTabView` applies `.themedScreenBackground()` (line 51). `themedScreenBackground()` reads `ThemeManager.shared.current.id` — a stored property on an `@Observable` class. However, `themedScreenBackground()` is a `View` extension function, not a `View` struct, so it cannot hold observation context. The `@Observable` tracking is established in the containing view's `body`. Any mutation to `ThemeManager.shared` (even an unrelated property on the same object) will invalidate the containing `TrainingView` body, causing the Canvas background to be scheduled for redraw.

For Arcade and Classic Radio themes, the background is a `Canvas` that draws 200+ individual line paths (`stride(from: 0, to: size.height, by: 2)` on a 480px screen = 240 iterations). On Series 6 (GPU: S6 chip) a Canvas redraw is GPU-side but still requires command encoder setup. If `ThemeManager` gains any mutable property that gets written during a workout (e.g., a future theme-effect animation), all Canvas backgrounds would re-draw every frame.

Additionally, `synthwaveHorizonBackground()` on watchOS (ThemeModifiers line 254-310) runs a Canvas with two nested loops: 8 horizontal lines + 17 vertical lines = 25 strokes, per layout pass. This is static geometry and safe to cache — but is not currently cached.

**Fix direction.** Wrap each heavy Canvas background in a separate `struct BackgroundView: View` with its own stored properties. SwiftUI will only re-evaluate the background body when its inputs change (currently: never, since these backgrounds have no inputs). Alternatively, pre-render the static portions to an `ImageRenderer` at theme-select time and use the resulting image as background.

**Instruments trace.** SwiftUI Profiler → "View body" column during theme switch → observe re-evaluation count on `TrainingView` and the Canvas render time.

**Confidence:** medium (requires confirming that theme state is mutated during workouts).

---

## Finding 6 — P2: `updateConnectivityHealth()` called on every incoming WCSession message — 20+ times per minute during workout

**File:** `ShuttlX/Services/SharedDataManager.swift:705-736` (`didReceiveMessage`), `:638-665` (reachability/deactivate/didFinish), `:821` (didReceive file)

**What happens.** Every `didReceiveMessage` ends with `self.updateConnectivityHealth()` (line 734). During an active workout the Watch sends `liveMetrics` every 3 seconds → `didReceiveMessage` fires → `updateConnectivityHealth()` runs. That function reads 4 WCSession properties (`activationState`, `isReachable`, `isPaired`, `isWatchAppInstalled`), computes a score, and conditionally writes `connectivityHealth` (a `@Published` property). At 1 update per 3 seconds that is 20 calls per minute, 1,200 per hour. Each call creates a new `Date()` and evaluates `lastSyncTime`.

**Fix direction.** Rate-limit `updateConnectivityHealth()` — only run it at most once every 30 seconds outside of explicit connection-state change callbacks. Move the call out of `didReceiveMessage` for the `liveMetrics` action specifically (the watch is clearly connected if we're receiving live metrics).

**Instruments trace.** Time Profiler → filter on `updateConnectivityHealth` in main thread → check call count over 5-minute window.

**Confidence:** high.

---

## Finding 7 — P2: iOS App init is synchronous, blocking first frame: RevenueCat + TelemetryDeck initialised in `App.init()`

**File:** `ShuttlX/ShuttlXApp.swift:20-25`

**What happens.** `ShuttlXApp.init()` calls `subscriptionManager.configure()` (RevenueCat SDK setup) and `TelemetryDeck.initialize(config:)` synchronously on the main thread before any view is rendered. RevenueCat's `configure` call sets up a `URLSession`, registers receipt observers, and reads `UserDefaults` (typically 5-20 ms on cold launch). TelemetryDeck initialisation parses config and prepares a dispatch queue (1-5 ms). These are not individually large but they extend time-to-first-frame by 6-25 ms, compounding with the `@StateObject` initialisation of `DataManager`, `SharedDataManager` (which calls `loadSessionsFromSharedStorage()` — a synchronous file read — from `init()`), `TemplateManager`, `PlanManager`, `AuthenticationManager`, and `CloudKitSyncManager`.

`SharedDataManager.init()` at line 54-63 of the iOS `SharedDataManager.swift` calls `loadSessionsFromSharedStorage()` synchronously — a file read under `NSFileCoordinator`. On a device with hundreds of sessions and a warm file system cache this takes 2-15 ms. On first launch after a reboot it can take longer.

Note: project doc says "Zero external dependencies — Apple frameworks only", so the presence of RevenueCat / TelemetryDeck imports may itself be a doc/code mismatch worth flagging to the human. Verify with `grep -n "import RevenueCat\|import TelemetryDeck" ShuttlX/ShuttlXApp.swift`.

**Fix direction.** Move SDK initialisations and file loads to a `Task { await ... }` in `WindowGroup.onAppear` or the first view's `onAppear`. Show a skeleton screen while loading. RevenueCat (if retained) can be configured after the first frame without user-visible impact.

**Instruments trace.** App Launch template → "Time to First Frame" → drill into the App init and @StateObject allocations on the main thread.

**Confidence:** high.

---

## Finding 8 — P3: `motionActivityManager.startActivityUpdates(to: .main)` — all CMMotionActivity callbacks on main queue

**File:** `ShuttlX Watch App/Services/WatchWorkoutManager.swift:582`

**What happens.** `startActivityUpdates(to: .main)` delivers all CMMotionActivity updates on the main queue. CoreMotion documentation recommends using a dedicated serial queue. On watchOS, with the main queue already handling the 1 Hz timer tick, HealthKit callbacks, and SwiftUI layout, motion activity callbacks add contention. Each callback creates a `Task { @MainActor ... }` closure (line 583-587), which doubles the main-actor dispatch overhead per callback.

Since motion activity events are already debounced to 5 seconds (line 96), the practical impact is low — but the callback *delivery* queue choice affects whether the main runloop is interrupted during UI rendering.

**Fix direction.** Pass a dedicated `OperationQueue` to `startActivityUpdates`. The inner `Task { @MainActor ... }` already correctly hops back to the main actor, so the change is safe.

**Instruments trace.** System Trace → Threads lane → watch for CoreMotion callbacks preempting main thread during UI frame rendering.

**Confidence:** medium.

---

## Finding 9 — P3: `scanlineOverlay` on iOS builds a `VStack` of ~150 `Rectangle` views per card

**File:** `ShuttlX/Theme/ThemeModifiers.swift:188-203`

**What happens.** `scanlineOverlay()` uses `GeometryReader` to compute `lineCount = Int(geo.size.height / 3)`. For a 450 pt card that is 150 `Rectangle` views inside a `ForEach`. SwiftUI materialises each as a separate leaf node in the render tree. For a screen with 5 cards in Arcade/Mixtape theme, that is ~750 `Rectangle` nodes just for scanline decoration.

**Fix direction.** Replace the `VStack + ForEach` with a single `Canvas { context, size in ... }` that draws the lines directly. Canvas renders into a single layer at draw time with no SwiftUI node overhead. The watch version of this modifier already uses `Canvas` for CRT lines in `arcadeCRTBackground()` (ThemeModifiers watch line 336-348).

**Instruments trace.** SwiftUI Profiler → View hierarchy count → compare node count between Clean and Arcade themes on the Analytics screen.

**Confidence:** high.

---

## Issues NOT found (areas examined and adequately handled)

- `DispatchSourceTimer` usage (correct, not `Timer`) — WatchWorkoutManager line 494.
- HR sample accumulation is O(1) running sum, not O(n) array — WatchWorkoutManager line 69-72.
- Route points have a 2,000-point cap with downsampling on Watch — line 85, 1143.
- HKAnchoredObjectQuery not restarted on pause/resume (correct, avoids double-count) — line 335-341.
- `themedCard()` accesses `ThemeManager.shared` directly (not via `@Environment`) which avoids creating spurious observation subscriptions in modifier closures.
- JSON persistence for `sessions.json` uses `NSFileCoordinator` correctly in both iOS and watchOS `SharedDataManager`.
- `AnalyticsView` uses `.task(id: dataManager.sessions.count)` to avoid recomputing on every render — sensible, though the trigger granularity is coarse (see Finding 3).
