# Swift Architecture Audit — ShuttlX

Date: 2026-04-25
Scope: ~13,200 LOC, 117 Swift files (iOS + watchOS + extensions)
Mode: Read-only audit. No source code was modified.

## Executive Summary

The codebase is structurally healthy for a solo-dev SwiftUI project at this size: clean folder split (Models / Services / Views / Theme / Utilities), proper `@MainActor` discipline on all `ObservableObject` services, reasonable use of `nonisolated` for `WCSessionDelegate` callbacks, and no force-unwraps or implicitly-unwrapped optionals in production paths beyond a single instance. Models are currently identical between iOS and watchOS targets (verified by `diff -q` across all nine shared models).

The principal architectural debt is concentrated in three areas:

1. Two god-objects: `WatchWorkoutManager` (1184 LOC) and the iOS `SharedDataManager` (824 LOC) absorb too many responsibilities and own the project's most fragile concurrency.
2. A confused dual data path between `SharedDataManager` and `DataManager` on iOS — a Combine sink AND a direct delegate callback both forward sessions, with a transient `pendingForDataManager` buffer to paper over a temporal-coupling bug at app start.
3. Pervasive use of `Manager.shared` singletons cross-referenced from inside one another (`TemplateManager` -> `SharedDataManager.shared`, `SubscriptionManager` -> `SharedDataManager.shared`, `DataManager` -> `CloudKitSyncManager.shared` + `AuthenticationManager.shared`, `SharedDataManager` -> `LiveActivityManager.shared`), making the service graph effectively un-mockable and turning every test into an integration test.

10 findings below, ranked roughly by severity. Two are P0, four are P1, three are P2, one is P3.

---

## Findings

### F1 — `WatchWorkoutManager` is a 1184-LOC god object

- Severity: **P1**
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:1-1184`
- Confidence: high

`WatchWorkoutManager` simultaneously owns: HealthKit authorization (lines 116-210), `HKWorkoutSession` and `HKLiveWorkoutBuilder` lifecycle (444-484, 1040-1075), `DispatchSourceTimer`-based display tick (488-534), CoreMotion activity classification with a bespoke 5-second debounce state machine (574-651), CoreLocation tracking and route downsampling (659-684, 1122-1184), CMPedometer step/distance + km-split detection with haptics (686-741), two `HKAnchoredObjectQuery` instances with their replay-bug workarounds (745-891), `WCSession` broadcast for live metrics (538-572, 302-309, 428-432), interval engine ticking (522-530), workout backup persistence (895-986), HealthKit save finalization (988-1093), and `HKWorkoutSessionDelegate` + `CLLocationManagerDelegate` conformances (1098-1184).

Each of these is independently testable in principle; together they make the file impossible to unit-test (every test would need a HealthKit-authorized device) and changes to one concern (e.g. the km-split downsampling rule) frequently force you to re-read the entire file to confirm you have not regressed an unrelated subsystem like the pause/resume HR-query workaround.

Suggested fix direction: extract three collaborators behind protocols owned by `WatchWorkoutManager`:
- `WorkoutSensorCoordinator` (CoreMotion + CMPedometer + CLLocation + km splits + haptics)
- `WorkoutHealthKitClient` (auth, queries, builder lifecycle, save finalization)
- `WorkoutBroadcaster` (the 3-second `liveMetrics` send + start/stop transferUserInfo)

`WatchWorkoutManager` keeps the published state, the timer, and the orchestration. This is a multi-day refactor but is the single biggest structural win available.

---

### F2 — `SharedDataManager` has a dual data path into `DataManager` (Combine sink + direct call)

- Severity: **P1**
- Files:
  - `ShuttlX/Services/SharedDataManager.swift:178-184`
  - `ShuttlX/Services/DataManager.swift:42-49`
- Confidence: high

When a session arrives from the Watch, `SharedDataManager.handleReceivedSession` (line 168) appends to `@Published syncedSessions` (line 170). The append fires the `$syncedSessions.sink` subscription set up in `DataManager.setupBindings` (line 43-48), which calls `dataManager.handleReceivedSessions(receivedSessions)`. Then `SharedDataManager` *also* directly calls `dataManager.handleReceivedSessions([session])` (line 180).

Both paths run on `MainActor` so there is no race, and `DataManager.handleReceivedSessions` deduplicates via `processedSessionIds` (DataManager.swift:54-55), so the bug is benign — but the two-pathway design is the root cause of:

1. The `pendingForDataManager` buffer (SharedDataManager.swift:48, 159-163, 181-184) which exists only because the Combine sink delivers sessions while `dataManager` is still nil during cold launch.
2. Reasoning ambiguity: a future contributor cannot tell whether `SharedDataManager.syncedSessions` is the source of truth or whether `DataManager.sessions` is.

Suggested fix direction: pick one channel. Either (a) remove the `setDataManager` direct callback and rely solely on the Combine subscription (DataManager already deduplicates), or (b) remove the `@Published` projection and the `setupBindings` sink and use only the imperative callback. Option (b) is preferred — `syncedSessions` is currently never observed by any view (verified by grep on `syncedSessions`); only `liveElapsedTime`, `connectivityHealth`, etc. are observed. Removing it would let `SharedDataManager` shrink and fix the temporal-coupling bug at the same time.

---

### F3 — Singleton web makes every service un-mockable

- Severity: **P1**
- Files (singletons): `ShuttlX/Theme/ThemeManager.swift:6`, `ShuttlX/Services/SharedDataManager.swift:9`, `ShuttlX/Services/SubscriptionManager.swift:8`, `ShuttlX/Services/CloudKitSyncManager.swift:7`, `ShuttlX/Services/DeviceManager.swift:6`, `ShuttlX/Services/LiveActivityManager.swift:7`, `ShuttlX/Services/AuthenticationManager.swift:7`, `ShuttlX Watch App/Services/SharedDataManager.swift:8`, `ShuttlX Watch App/Theme/ThemeManager.swift:6`, `ShuttlX/Views/SyncDebugView.swift:68`
- Cross-coupling examples: `TemplateManager.swift:41` (`SharedDataManager.shared.sendTemplatesToWatch`), `SubscriptionManager.swift:126` (`SharedDataManager.shared.sendSubscriptionStatusToWatch`), `DataManager.swift:38` (`SharedDataManager.shared.setDataManager(self)`), `DataManager.swift:194` (`CloudKitSyncManager.shared.performFullSync`), `DataManager.swift:189` (`AuthenticationManager.shared.isSignedIn`), `SharedDataManager.swift:62` (`LiveActivityManager.shared.cleanupStaleActivities`)
- Confidence: high

Why it matters: not a single service has its outbound dependencies injected. Every collaborator is reached via `Manager.shared.*` from inside the body of another service. Consequences:

- The codebase contains zero unit tests today (verified — no `Tests` target). Even if you added one, you could not instantiate `DataManager()` without simultaneously activating `SharedDataManager.shared` (which calls `WCSession.default.activate()` in its `init`, `SharedDataManager.swift:57-58`), starting `LiveActivityManager.shared.cleanupStaleActivities` (line 62), and scheduling a 15s `Timer.scheduledTimer` (line 74).
- `TemplateManager.swift:41` reaches into `SharedDataManager.shared` to push templates to the watch — a leaky abstraction. `TemplateManager`'s job is templates; sync is orthogonal.
- `SubscriptionManager.swift:126` similarly violates separation: a subscription change calls into a sync manager.

Suggested fix direction: introduce thin protocols (`WatchSyncing`, `CloudSyncing`, `LiveActivityHosting`) and inject them into the constructor of each consumer. Keep the singleton instances as the production wiring in `ShuttlXApp.init`, but let `DataManager(init: cloudSync: any CloudSyncing = CloudKitSyncManager.shared, ...)` etc. accept overrides. This is a one-day refactor that unlocks all future testing.

---

### F4 — `ThemeManager` is `@Observable` but not `@MainActor`, mutated from `nonisolated` WC callbacks

- Severity: **P1**
- Files:
  - `ShuttlX/Theme/ThemeManager.swift:4-40`
  - `ShuttlX Watch App/Theme/ThemeManager.swift:4-40`
  - Mutation site: `ShuttlX Watch App/Services/SharedDataManager.swift:579` (`ThemeManager.shared.selectTheme(themeID)` inside a `Task { @MainActor in ... }`, but the call chain originates in `nonisolated func session(_:didReceiveApplicationContext:)`, line 491)
- Confidence: high

`ThemeManager` is declared `@Observable final class` but has neither `@MainActor` nor any other isolation. It is read from many synchronous `View.body` contexts (`ShuttlX/Theme/ShuttlXTheme.swift:6`, `99`, `ThemeAssets.swift:11`, `846`, `1065`, `ThemeModifiers.swift:13`, `147`, `164`, etc.) and *also* mutated from a `Task @MainActor` continuation that is itself reached from a `nonisolated` `WCSessionDelegate` callback. The current `@Published`-equivalent observation tracking only fires correctly because `MainActor.run` happens to wrap the mutation today.

Under Swift 6 strict concurrency (the project is on Swift 5 today, `project.pbxproj:1077` etc., but Apple is forcing migration), this class will fail to build because:
- Reading `ThemeManager.shared.colors` from a non-isolated context (e.g. a widget extension's timeline provider, or a `nonisolated` delegate) would be a data race.
- The `init()` writes `selectedThemeID` (a stored `@Observable` property) from `nonisolated` context.

Suggested fix direction: add `@MainActor` to both `ThemeManager` classes and ensure every mutation site is already inside an isolated context (the WC callback at `ShuttlX Watch App/Services/SharedDataManager.swift:579` already is, since it is inside a `Task { @MainActor in ... }`). Read-only access from `View.body` is safe because SwiftUI bodies are `@MainActor`. The widget extension targets do not import this class so they are unaffected.

---

### F5 — Three timer-driven retry loops + Combine sink + dual data path = unbounded coupling around session sync

- Severity: **P2**
- Files:
  - `ShuttlX/Services/SharedDataManager.swift:74` (15s `Timer.scheduledTimer` `performBackgroundSync`)
  - `ShuttlX Watch App/Services/SharedDataManager.swift:52` (15s retry loop)
  - `ShuttlX/Services/SharedDataManager.swift:239` (10s live-metrics timeout)
  - `ShuttlX/Views/SyncDebugView.swift:110` (2s view polling)
  - Plus the Combine sink at `ShuttlX/Services/DataManager.swift:43-48`
- Confidence: high

Five independent reactive loops touch session state. Each one was added to fix a specific symptom (sync-on-foreground-stuck, watch-rebooted-mid-workout, debug-view-not-refreshing, etc.) but no contributor can confidently reason about the global behaviour. The `lastFullResendTime` throttle at `ShuttlX Watch App/Services/SharedDataManager.swift:336` is itself a workaround for the redundancy.

Suggested fix direction: collapse into a single `SyncCoordinator` with one `AsyncStream` of sync events (foreground, reachability-change, periodic-tick, explicit-pull) and one consumer. Document the resulting state diagram in `.claude/rules/services.md`.

---

### F6 — `WatchWorkoutManager.workoutBuilder` lifetime: `Task` captures it after it has been niled

- Severity: **P2**
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:1029-1075` (specifically 1033-1036, 1042-1052)
- Confidence: medium

`saveWorkoutData()` reads `workoutBuilder` into the local `builderToFinish` (line 1033), then immediately nils `workoutBuilder` (line 1035), then launches an async `Task` that uses `builderToFinish` (line 1042). This pattern is correct, but the same function is *also* reachable from `updateElapsedTime` (line 526), which fires every 1 second from a `DispatchSourceTimer` on a background queue, hopping back to `MainActor`. If two `tick` cycles overlap (e.g. main thread stalled by a slow `liveMetrics` `sendMessage`), `saveWorkoutData` could in principle be called twice — once with `builderToFinish != nil`, once with nil. The first invocation calls `stopWorkout()` which itself nils things, but the second hop's `Task` could race the first.

The HealthKit error path "Workout builder unavailable — workout may not appear in Health app" (line 1067) is the user-visible symptom that has shown up in production telemetry per the existing `SHUTTLX_AUDIT.md` notes.

Suggested fix direction: gate `saveWorkoutData()` on a `private var isSaving = false` flag; or move the entire interval-completion auto-save into `IntervalEngine.tick`'s caller via a continuation rather than firing it from inside the timer tick. Long-term: extract the HealthKit save into the `WorkoutHealthKitClient` proposed in F1 with serial actor isolation.

---

### F7 — `WidgetDataProvider` uses unsynchronized `static var` cache

- Severity: **P2**
- File: `ShuttlX/Services/WidgetDataProvider.swift:10-11`, used at `:13-47`
- Confidence: high

```swift
private static var cachedSessions: [TrainingSession]?
private static var cacheTimestamp: Date?
```

These are mutated inside `loadSessions()` (lines 45-46), which is called from widget timeline providers. WidgetKit can call timeline-builder methods from arbitrary background threads, and multiple widget kinds (`SmallWidget`, `MediumWidget`) can request a timeline concurrently. The `enum WidgetDataProvider` has no isolation, no lock, and no actor.

Symptom: undefined behaviour in production — likely just suboptimal cache thrashing today, but exposes you to TSan warnings the moment you turn on Swift 6 strict concurrency.

Suggested fix direction: convert to `actor WidgetDataProvider` or, simpler, drop the cache entirely (the file read is fast and timeline rebuilds are infrequent). If you keep the cache, make the type a global actor or wrap state in `OSAllocatedUnfairLock`.

---

### F8 — Watch `SharedDataManager` allows public `init()`, defeating the singleton

- Severity: **P2**
- File: `ShuttlX Watch App/Services/SharedDataManager.swift:28`
- Confidence: high

```swift
override init() {       // not private
    super.init()
    if WCSession.isSupported() { ... session.activate() ... }
    setupBackgroundTasks()
}
```

The iOS counterpart is `private override init()` at `ShuttlX/Services/SharedDataManager.swift:54` — correct. The watch one is unprotected, and indeed `ContentView.swift:33-37` (the `#Preview`) constructs a second instance: `let dataManager = SharedDataManager.shared` then `WatchWorkoutManager()` (which is fine), but if anyone copy-pastes the preview as a starting point they will get two singletons each calling `WCSession.default.activate()` and clashing on the delegate slot.

Suggested fix direction: change `override init()` to `private override init()` to match iOS. The preview at `ShuttlX Watch App/ContentView.swift:32-40` already uses `.shared`, so no other call-site breaks.

---

### F9 — `SharedDataManager.handleLiveMetrics` recreates a `Timer.scheduledTimer` every 1-3 seconds during a workout

- Severity: **P2**
- File: `ShuttlX/Services/SharedDataManager.swift:238-243`
- Confidence: high

```swift
liveMetricsTimeoutTimer?.invalidate()
liveMetricsTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { ... }
```

This is invoked every time the watch sends a `liveMetrics` message — every 3 seconds for the duration of a workout (potentially 60+ minutes). Each invocation invalidates the previous one-shot timer and creates a new one. `Timer.scheduledTimer` allocates a `CFRunLoopTimer` and attaches it to the main run loop; doing this hundreds of times per workout is wasteful. The `[weak self]` capture is correctly placed (line 239) so retain cycles are not the issue — it is GC churn and unnecessary main-thread work.

Suggested fix direction: keep a single `Date` `lastLiveMetricUpdate` and check it lazily inside the existing 15s `backgroundSyncTimer` tick. Or use a `DispatchSourceTimer` with `.schedule(deadline:)` reset rather than re-creating the timer.

---

### F10 — One unguarded force-unwrap remains; one over-cautious `!` could be `let`-bound

- Severity: **P3**
- Files:
  - `ShuttlX Watch App/Services/SharedDataManager.swift:336` — `now.timeIntervalSince(self.lastFullResendTime!)` (guarded by a `nil` check on line 336 itself, so safe today, but a future edit to that condition could break it)
  - `ShuttlX/Services/DataManager.swift:82` — `String(session.completedIntervals != nil && !(session.completedIntervals!.isEmpty))`
- Confidence: high

These are the only force-unwraps in the entire `Services/` tree across both targets. Both are defensible but ugly:

```swift
// Watch SharedDataManager.swift:336
if self.lastFullResendTime == nil || now.timeIntervalSince(self.lastFullResendTime!) > 60 {
```
Refactor to: `if self.lastFullResendTime.map({ now.timeIntervalSince($0) > 60 }) ?? true`.

```swift
// DataManager.swift:82
"isInterval": String(session.completedIntervals != nil && !(session.completedIntervals!.isEmpty))
```
Refactor to: `String(session.completedIntervals?.isEmpty == false)`.

No P0 force-unwrap risk in this codebase. This is a discipline note, not a bug.

---

## What I did NOT find (notable absences)

- No retain cycles in Combine pipelines or escaping closures: every `[weak self]` I inspected (e.g. `WatchWorkoutManager.swift:497-499`, `SharedDataManager.swift:74-79`, `113-128`) is correctly placed.
- No models diverging between iOS and watchOS — `diff -q` confirms all 9 shared models are byte-identical today (TrainingSession, WorkoutTemplate, TrainingPlan, ActivitySegment, RoutePoint, WorkoutSport, ExerciseDevice, HeartRateZoneCalculator, BuiltInPlans). The duplication is a maintenance hazard but is not currently fired.
- No `[0]` or `.first!` array indexing — verified by `grep`.
- No `try!` or `as!` in production code.
- No misused `Task.detached` -> `MainActor.run` chains beyond the legitimate ones in `WatchWorkoutManager`'s HealthKit completion handlers.
- `nonisolated` `WCSessionDelegate` methods consistently hop to `MainActor` via `Task { @MainActor in ... }` before mutating state — this is correct.

## Cross-cutting themes

The three biggest issues (F1, F2, F3) compound: because `WatchWorkoutManager` is a god object (F1), it owns its own `WCSession.default.transferUserInfo` calls (`WatchWorkoutManager.swift:302-309`, `428-432`, `567`) bypassing `SharedDataManager`. That, plus the dual data path on iOS (F2), plus the singleton web (F3), means there is *no single layer that owns "what we send between watch and phone"*. Three different files send `WCSession` messages (the two `SharedDataManager`s and `WatchWorkoutManager`), and the iOS side has two places that consume sessions (`SharedDataManager` direct + Combine sink). The recovery feature being designed in `audits/2026-04-25/PROMPT.md` will have to plug into this seam — I would prioritize F2 and a partial F3 (introduce `WatchSyncing` protocol consumed by `TemplateManager` and `SubscriptionManager`) before adding the recovery feature, because those changes will reduce the surface area the new feature has to integrate with.

---

## Files referenced

- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX Watch App/Services/WatchWorkoutManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX Watch App/Services/SharedDataManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX Watch App/Services/IntervalEngine.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX Watch App/Theme/ThemeManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX Watch App/ShuttlXWatchApp.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX Watch App/ContentView.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/Services/SharedDataManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/Services/DataManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/Services/CloudKitSyncManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/Services/AuthenticationManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/Services/LiveActivityManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/Services/SubscriptionManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/Services/TemplateManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/Services/WidgetDataProvider.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/Theme/ThemeManager.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/ShuttlXApp.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX/ContentView.swift`
- `/Users/sergeymuzyukin/github/shuttlx/ShuttlX.xcodeproj/project.pbxproj` (Swift version)
