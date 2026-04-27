# SwiftUI + watchOS Correctness Audit

Date: 2026-04-25
Scope: Read-only audit of SwiftUI view correctness, watchOS workout patterns, WatchConnectivity, timer behavior, theme reactivity, Live Activity / Widget extensions.

Total findings: 8 (1 P1, 5 P2, 2 P3)

---

## Finding 1 — Theme changes do not invalidate views that use the `ShuttlXColor` / `ShuttlXFont` static bridge

- Severity: P1
- File: `ShuttlX/Theme/ShuttlXTheme.swift:5-94` (and the watchOS mirror), `ShuttlX/Theme/ThemeManager.swift:4-40`, `ShuttlX Watch App/Theme/ThemeManager.swift:4-40`
- Why it matters: `ShuttlXColor` is an `enum` whose properties are `static var` getters that read `ThemeManager.shared.colors.X`. SwiftUI's `@Observable` registers reads only when the property is touched while a tracked view body is rendering against an instance the view actually observes (via `@Environment(ThemeManager.self)`, `@State`, `@Bindable`, or `Observation.withObservationTracking`). A `static var` reading `ThemeManager.shared` from inside a view body does not register the read against that view, so on `selectTheme(...)` the body of any view that only reads colors/fonts via the static bridge does not re-invalidate. The repo grep shows only two views (`ShuttlX/Views/SettingsView.swift:9` and `ShuttlX/Views/DeviceListView.swift:4`) inject `@Environment(ThemeManager.self)`; zero watchOS views do. The watch app injects `.environment(ThemeManager.shared)` at root (`ShuttlX Watch App/ShuttlXWatchApp.swift:28`) but no descendant reads from the environment, so the env injection is effectively dead. Today the theme appears to switch only because (a) the user is usually on Settings when toggling, which does observe, and (b) iOS happens to push a fresh root render through `@State private var themeManager = ThemeManager.shared` in `ShuttlXApp.swift:8` propagating downward via SwiftUI's identity-keyed re-render. On watchOS the theme switch arrives via `SharedDataManager.handleIncomingPayload` (`ShuttlX Watch App/Services/SharedDataManager.swift:578-581`) calling `ThemeManager.shared.selectTheme(themeID)` — no view in the watch graph observes that singleton, so visible theme changes on watch are not guaranteed; they likely only update on the next view recreation (e.g., entering/leaving a screen).
- Fix direction: Either (a) drop the static bridge and make every view observe `@Environment(ThemeManager.self)` (verbose but correct), or (b) keep `ShuttlXColor.*` but force every screen to read at least one tracked property — e.g., add a tiny `themeManager.current.id` read at the top of each view body or via a view modifier `.observingTheme()` that reads a property and adds a hidden `.id(theme.id)`. The cleanest is (b) plus making the static accessors read from a published-id-tagged token so screens that just call `.themedScreenBackground()` (which already reads `ThemeManager.shared.current.id` inside its `@ViewBuilder`) get implicit registration when the view is rendered with the singleton observed at parent.
- Confidence: high

## Finding 2 — Watch broadcasts live metrics on every 1 s tick, but tick continues during paused workout, sending stale data

- Severity: P2
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:326-343` (`pauseWorkout`) and `:488-505` (`startDisplayTimer`)
- Why it matters: `pauseWorkout()` calls `stopDisplayTimer()` so the timer is cancelled — good. But the corresponding `workoutSession?.pause()` is async; the HK session state-change callback (`workoutSession(_:didChangeTo:from:date:)` line 1099) only saves the backup, it does not stop sensors. More importantly, if any race causes the timer to fire between `isPaused = true` (line 328) and `stopDisplayTimer()` (line 331), `updateElapsedTime()` (line 512) computes `elapsedTime = Date().timeIntervalSince(startTime) - accumulatedPauseTime` while the new pause has not yet been added to `accumulatedPauseTime` (that only happens on `resumeWorkout()` at line 351). For one tick, elapsedTime would jump. The greater concern is `broadcastLiveMetricsIfNeeded()` at line 538 — it sends `"isPaused": isPaused` but does not gate the entire send on pause; pause-state metrics will still be delivered to iOS. The Live Activity logic on iOS (`ShuttlX/Services/SharedDataManager.swift:227-235`) ignores `isPaused` for `updateActivity` payload but the elapsed time keeps growing on iOS while the user perceives the workout as paused.
- Fix direction: Compute `elapsedTime` as `Date().timeIntervalSince(startTime) - accumulatedPauseTime - (isPaused ? Date().timeIntervalSince(pauseStartDate ?? Date()) : 0)` so the displayed timer freezes immediately at pause moment, even before the timer is torn down. Also early-return `broadcastLiveMetricsIfNeeded` on `isPaused` after the first paused payload, so iOS sees a single transition and not a stream of increasing elapsedTime values during pause.
- Confidence: high

## Finding 3 — `intervalEngine` is an `ObservableObject` but the SwiftUI view only re-renders incidentally via `WatchWorkoutManager`

- Severity: P2
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:49`, `ShuttlX Watch App/Views/TrainingView.swift:225-288`
- Why it matters: `intervalEngine` is declared `var intervalEngine: IntervalEngine?` — not `@Published`. `IntervalEngine` itself is `ObservableObject` with `@Published` properties, but `TrainingView` reads `workoutManager.intervalEngine` (`TrainingView.swift:225, 236`) without `@ObservedObject` or `@StateObject`. The view does re-render every second because the *outer* `WatchWorkoutManager.elapsedTime` is `@Published` and changes each tick; during that re-render the view re-reads the engine's state. This works today by accident. If anyone changes the broadcast cadence, increases the timer leeway, or re-architects elapsedTime updates, the interval ring/countdown will silently freeze. Also, the haptic at line 60 `WKInterfaceDevice.current().play(.notification)` for the 5-second countdown depends on `tick()` being called — fine — but the SwiftUI ring's `.animation(.linear(duration: 1), value: stepProgress)` (line 257) animates against a value re-derived every render, which can cause the ring to skip back when the engine advances steps and `currentStepTimeRemaining` resets to a new high value.
- Fix direction: Either bind the engine explicitly with `@ObservedObject private var engine = workoutManager.intervalEngine` (requires lifetime juggling), or convert `IntervalEngine` to `@Observable` and read it as a tracked instance via `if let engine = workoutManager.intervalEngine { ... }` in the view. The latter is cleaner; pair it with an `.id(engine.currentStepIndex)` reset of the progress ring (already present at `TrainingView.swift:282`) so the linear animation does not overshoot when a step rolls.
- Confidence: high

## Finding 4 — Always-On Display path keeps issuing 1 Hz state updates and SwiftUI invalidations behind the AOD frame

- Severity: P2
- File: `ShuttlX Watch App/Views/TrainingView.swift:99-132` (`aodMinimalView`), `ShuttlX Watch App/Services/WatchWorkoutManager.swift:488-534` (display timer + tick)
- Why it matters: When `isLuminanceReduced` is true the view switches to a minimal layout but the underlying `displayTimer` keeps firing once per second and writing to `@Published elapsedTime`, `heartRate`, etc. watchOS only repaints AOD ~1× per minute, so 59 of every 60 invalidations are wasted CPU and battery. Apple guidance for Always-On is to drive the AOD view from `TimelineView(.everyMinute)` or coalesce updates to the AOD cadence. The repo's CLAUDE.md / watchos.md rule "Test with long workouts (30+ minutes)" makes this a real-world cost.
- Fix direction: Detect `isLuminanceReduced` and either (a) reduce the broadcast/tick effective cadence (e.g., extend leeway and drop intra-minute UI writes, only updating per minute) or (b) wrap the AOD view in `TimelineView(.everyMinute) { _ in ... }` and pull `elapsedTime` from `Date()` arithmetic against `workoutStartTime` rather than a `@Published` value. Keep the 1 Hz tick for live metrics broadcast and HK builder, but coalesce SwiftUI-visible writes during AOD.
- Confidence: medium

## Finding 5 — `cleanupStaleActivities()` is called on every iOS launch, killing in-flight Live Activity for an already-running workout on the watch

- Severity: P2
- File: `ShuttlX/Services/SharedDataManager.swift:62`, `ShuttlX/Services/LiveActivityManager.swift:129-135`
- Why it matters: `SharedDataManager.shared` init unconditionally ends every `Activity<WorkoutActivityAttributes>` it can see. If the iPhone app is cold-launched while the user has an active Watch workout (with an existing Live Activity from a previous foreground session), the Activity is ended with `dismissalPolicy: .immediate` and then re-created on the next live-metrics message at `SharedDataManager.swift:222-225`. Result: the Lock Screen / Dynamic Island flickers off and back on every launch. This also resets the `attributes.workoutStartDate` on the new Activity (LiveActivityManager.swift:33), which is supposed to be invariant for the run.
- Fix direction: Replace `cleanupStaleActivities()` with a smarter reconcile: if there is already an `Activity` whose `attributes.workoutStartDate` matches a currently active workout (i.e., the watch is broadcasting `isWorkoutActiveOnWatch`), keep it and adopt it as `currentActivity`; otherwise end it. Or condition cleanup on "no live metrics seen in N seconds". The current code pre-emptively kills useful state.
- Confidence: high

## Finding 6 — WCSession `transferUserInfo` sends a fresh `userInfo` payload at workout start that wakes iOS but is not de-duplicated against `liveMetrics` `sendMessage`

- Severity: P3
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:301-309`, `ShuttlX/Services/SharedDataManager.swift:687-693`
- Why it matters: At workout start the watch fires `transferUserInfo` with `action: "workoutStarted"`, and 1-3 seconds later starts pushing `liveMetrics` `sendMessage`. Both paths transition `isWorkoutActiveOnWatch = true` and call `LiveActivityManager.shared.startActivity(...)`. If both arrive close together (sendMessage races with the queued transferUserInfo, which can arrive *after* the foreground sendMessage), iOS may briefly show the Activity twice or end+restart it. `startActivity` does guard against duplicate creation when `currentActivity != nil && !startFailed` (`LiveActivityManager.swift:28-30`), so the duplicate is suppressed there, but `attributes.workoutStartDate` set at line 33 will be wrong if the late `userInfo` causes a second start (because the existing Activity was nil for whatever reason). The reverse risk: if the live-metrics path runs first and successfully starts an Activity, the queued `workoutStarted` userInfo will arrive seconds later and pass the same `activityType` — a no-op only because of the guard.
- Fix direction: Pick one signal. Recommended: drop the `workoutStarted` userInfo transfer entirely and rely on the first `liveMetrics` message to start the Live Activity. Or, conversely, have iOS treat `workoutStarted` as the only Activity-start trigger and have `handleLiveMetrics` only update.
- Confidence: medium

## Finding 7 — `setupBackgroundTasks` schedules a `Timer.scheduledTimer` on watch with no `RunLoop.current` guarantee

- Severity: P3
- File: `ShuttlX Watch App/Services/SharedDataManager.swift:51-59`
- Why it matters: `Timer.scheduledTimer` uses the current run loop in `.default` mode. The watch app's main run loop suspends when the watch is wrist-down and the app is not in a workout session. The 15 s retry timer therefore stalls when the user is not actively interacting with the watch. The iOS counterpart wraps the same call in `DispatchQueue.main.asyncAfter(deadline: .now() + 2.0)` (`ShuttlX/Services/SharedDataManager.swift:71-81`) — same pattern, also tied to main run loop, but iOS apps do not face the same wrist-down constraint. The retry path is also not strictly needed during a workout because `WatchWorkoutManager.broadcastLiveMetricsIfNeeded` already handles delivery — but pending sessions queued at workout end depend on this timer to drain.
- Fix direction: Use `DispatchSourceTimer` on the watch (matching the pattern already used for the display timer at `WatchWorkoutManager.swift:494`) so retries fire on a background queue independent of the main run loop. Alternatively, register a `WKApplicationRefreshBackgroundTask` for periodic sync rather than relying on a foreground timer.
- Confidence: medium

## Finding 8 — `current` stored property on `ThemeManager` is good for `@Observable`, but `selectedThemeID` and `current` can drift if init's `UserDefaults` lookup partially fails

- Severity: P3
- File: `ShuttlX/Theme/ThemeManager.swift:28-34` and watchOS mirror
- Why it matters: `init` reads `selectedThemeID = saved` and `current = AppTheme.theme(for: saved)` only inside the `if let defaults` branch. If `UserDefaults(suiteName: appGroupID)` returns nil (App Group entitlement misconfigured, simulator with no shared container) the manager defaults to `selectedThemeID = "clean"` and `current = .clean`. Subsequent `selectTheme(...)` calls work. But the order in which iOS launches with `.environment(themeManager)` and the watch's `handleIncomingPayload` can run `selectTheme` before any view observes — combined with Finding 1 this leads to an apparent "stuck on default theme until I scroll" symptom. Functionally minor, but worth tightening.
- Fix direction: Add an explicit fallback path that logs when the App Group is unreachable, and consider centralizing the read in a static `loadInitialTheme()` so both code paths (App Group present vs. absent) produce the same logging and state. Also assert that `selectedThemeID` and `current.id` always agree (they currently do, but a future contributor changing one without the other would silently desync).
- Confidence: low

---

## Items checked and considered acceptable

- `WatchWorkoutManager.startDisplayTimer` (`WatchWorkoutManager.swift:488-505`) correctly uses `DispatchSourceTimer` on a background queue with a 50 ms leeway — drift-proof and main-run-loop independent. Good.
- `HKAnchoredObjectQuery` for HR and calories deliberately stays running through pause/resume to avoid the well-known anchor-replay duplication bug (`WatchWorkoutManager.swift:333-339`, `:367-370`). Comment is accurate; behavior is correct.
- `HKWorkoutSession` lifecycle: start at `WatchWorkoutManager.swift:467`, pause at `:340`, end at `:385`, finalize via `endCollection` + `finishWorkout` at `:1045-1046`. Crash-recovery path (`:938-953`) writes a backup on pause / state change. Solid.
- `WCSession` activation is requested in `init` on both platforms; `sessionDidDeactivate` re-activates on iOS (`SharedDataManager.swift:505-511` watch / `:661-665` iOS) — required pattern.
- Size-aware routing in `sendSessionToiOS` (`ShuttlX Watch App/Services/SharedDataManager.swift:101-128`) correctly gates `sendMessage` at <50 KB, `transferUserInfo` at <200 KB, `transferFile` above. Matches Apple's 65 KB sendMessage limit.
- `SmallWidget` and `MediumWidget` providers ship a 30-minute timeline policy (`ShuttlXWidgets/SmallWidget.swift:21-22`) — within Apple's recommended budget.
- `ContentView` on watch wraps the active/inactive split in `NavigationStack` with `.transition(...)` and `.animation(...)` keyed off `workoutManager.isWorkoutActive` (`ContentView.swift:9-24`) — view identity is stable and the animation is keyed correctly.
- `NSFileCoordinator` is used on both reads and writes of `sessions.json` on iOS and watchOS to prevent App Group races (`ShuttlX Watch App/Services/SharedDataManager.swift:259-296`, iOS `:268-285`). Correct.
- `recoverCrashedWorkout` deduplicates against existing `sessions.json` IDs before re-sending (`WatchWorkoutManager.swift:956-972`) — avoids the duplicate-session-on-crash class of bug.

## Out-of-scope notes (mentioned for awareness, not findings)

- `ShuttlXApp.swift` imports `RevenueCat` and `TelemetryDeck`. CLAUDE.md and the rules state "zero external dependencies — Apple frameworks only." This is an architectural / docs drift, not a SwiftUI correctness issue.
