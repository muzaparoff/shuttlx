---
description: Swift concurrency review checklist for ShuttlX — actor isolation, queue conventions, delegate hopping, known-good patterns to preserve
user_invocable: true
---

# /swift-concurrency-review

Apply when writing or reviewing any code in `Services/`, `Managers/`, or anything touching actors, queues, or `Task`. Also run before any push to main.

---

## CRITICAL: The @MainActor I/O Traps (July 2026 — caused real user freezes)

These are the exact patterns that produced the watchOS freeze-on-stop and 3s launch lag bugs. Check every new method against them.

### Trap 1 — `Task { }` in a SwiftUI view body inherits @MainActor

```swift
// WRONG — Task {} in onAppear inherits @MainActor from the view
// Data(contentsOf:) runs on the main thread
.onAppear {
    Task {
        let data = try Data(contentsOf: url)         // ← BLOCKS MAIN THREAD
        let decoded = try JSONDecoder().decode(...)  // ← BLOCKS MAIN THREAD
    }
}

// CORRECT — Task.detached escapes @MainActor
.onAppear {
    Task.detached(priority: .utility) {
        let data = try Data(contentsOf: url)          // background
        let decoded = try JSONDecoder().decode(...)   // background
        await MainActor.run { self.state = decoded }  // hop back for UI
    }
}
```

**Rule:** Any `Task { }` created in a SwiftUI view's `.onAppear`, `.task`, or body runs on `@MainActor`. If it does file I/O or JSON decode, use `Task.detached(priority: .utility)` and hop back for state assignments.

### Trap 2 — JSON encode/decode in @MainActor methods at workout stop

JSON encoding a 1-hour GPS session (`TrainingSession` with 2000 `RoutePoint` values) takes 150–500ms on an Apple Watch. If this runs on `@MainActor`, the UI hard-freezes for that entire window.

```swift
// WRONG — @MainActor method, JSONEncoder blocks main thread
func sendSessionToiOS(_ session: TrainingSession) {   // @MainActor class
    let data = try JSONEncoder().encode(session)       // ← FREEZE
    let base64 = data.base64EncodedString()
    WCSession.default.transferUserInfo(...)
}

// CORRECT — encode on background, hop back for WCSession dispatch
func sendSessionToiOS(_ session: TrainingSession) {
    Task.detached(priority: .utility) { [weak self] in
        let data = try JSONEncoder().encode(session)   // background
        await MainActor.run { [weak self] in
            WCSession.default.transferUserInfo(...)    // @MainActor for WC calls
        }
    }
}
```

**Rule:** Never call `JSONEncoder().encode()` or `JSONDecoder().decode()` synchronously inside an `@MainActor` method when the payload could be >10KB. Always wrap in `Task.detached`.

### Trap 3 — Startup I/O blocking the first render

Disk reads in `init()` or `onAppear` run before the first frame. Any file read competing with the view's first layout delays the timer appearing on screen.

```swift
// WRONG — Task { @MainActor } in init still blocks first render
init() {
    Task { @MainActor [weak self] in
        self?.loadPendingSessionsFromDisk()   // ← file I/O blocks main thread
        self?.loadTemplatesFromDisk()
    }
}

// CORRECT — async method with background I/O, results assigned on main after await
init() {
    Task { @MainActor [weak self] in
        await self?.loadPendingSessionsAndTemplates()  // suspends main during I/O
    }
}

private func loadPendingSessionsAndTemplates() async {
    let results = await Task.detached(priority: .utility) {
        // all file I/O here, returns value types
        return (pending, templates)
    }.value
    // Back on @MainActor — assign to @Published
    self.pendingSessions = results.0
    self.workoutTemplates = results.1
}
```

**Rule:** Startup I/O must be in `async` methods that internally `await Task.detached { ... }.value`. The `await` suspends `@MainActor` and lets the first frame render while I/O runs on a background thread.

### Trap 4 — NSFileCoordinator blocking on @MainActor

`NSFileCoordinator.coordinate(readingItemAt:)` is a synchronous blocking call that waits for any concurrent write coordination on the same file. If the background write takes 500ms (e.g., re-encoding sessions.json with 100+ sessions), the main thread blocks for that entire duration.

```swift
// WRONG — coordinate() is blocking, must not run on @MainActor
func loadAllLocalSessions() -> [TrainingSession] {   // @MainActor
    coordinator.coordinate(readingItemAt: url, ...) { ... }   // ← BLOCKS
}

// CORRECT — run coordinator on Task.detached
func loadAllLocalSessions() async -> [TrainingSession] {
    return await Task.detached(priority: .utility) {
        var result: [TrainingSession] = []
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, ...) { readURL in
            result = try JSONDecoder().decode(...)
        }
        return result
    }.value
}
```

**Rule:** `NSFileCoordinator.coordinate(readingItemAt:)` and `coordinate(writingItemAt:)` must always run on a background `Task.detached` or `DispatchQueue`.

### Trap 5 — IPC calls inside coordinator blocks

`WidgetCenter.shared.reloadAllTimelines()` triggers cross-process IPC. Calling it inside an `NSFileCoordinator` block extends the coordination duration and can block other processes waiting to coordinate on the same file.

```swift
// WRONG — IPC call holds the file coordination lock
coordinator.coordinate(writingItemAt: url, ...) { writeURL in
    try data.write(to: writeURL, ...)
    WidgetCenter.shared.reloadAllTimelines()   // ← IPC inside coordinator
}

// CORRECT — call after the coordinator block returns
coordinator.coordinate(writingItemAt: url, ...) { writeURL in
    try data.write(to: writeURL, ...)
}
// outside the block:
WidgetCenter.shared.reloadAllTimelines()
```

**Rule:** Never call `WidgetCenter`, `URLSession`, or other IPC APIs inside `NSFileCoordinator` blocks.

---

## Standard checklist (apply to every change)

### Actor isolation

- [ ] `@MainActor` on `ObservableObject` / `@Observable` UI-facing classes — never `@unchecked Sendable` as an escape hatch.
- [ ] Timer creation and access on the same actor.
- [ ] Delegate callbacks (WCSession, HealthKit) arrive on arbitrary queues — hop to `@MainActor` via `Task`, but read callback-scoped values (e.g. `WCSessionFile.fileURL`) synchronously BEFORE the hop.
- [ ] Any `Task { }` in a SwiftUI view inherits `@MainActor` — check for Trap 1 above.

### File I/O

- [ ] Every `Data(contentsOf:)` or `data.write(to:)` is either in `Task.detached`, on `sessionStoreQueue`, or behind `NSFileCoordinator` running off-main.
- [ ] JSON encode/decode of workout session data is off `@MainActor` (see Trap 2).
- [ ] Startup I/O uses the `async` + `Task.detached { }.value` pattern (see Trap 3).
- [ ] `NSFileCoordinator` always runs on a background thread (see Trap 4).
- [ ] No IPC calls (`WidgetCenter`, network) inside coordinator blocks (see Trap 5).

### Queue conventions in this repo

- [ ] Session store writes go through `sessionStoreQueue` (serial, utility QoS) — the `appendSessionToStore` `nonisolated static` pattern is canonical.
- [ ] One serial queue per resource — adding a second queue for the same file reintroduces races.

### Known-good patterns to preserve (from July 2026 audit)

- Single-flight guard `isBurstScheduled` (WatchSyncCoordinator) prevents retry-burst stacking.
- Id-based dedup in `handleReceivedSession` before persistence.
- `sendSessionToiOS` encodes off main, hops back to main for WCSession dispatch.
- `loadAllLocalSessions()` is `async` — all callers use `await`.
- `loadPendingSessionsAndTemplates()` combines both file loads into one background pass.
- `WidgetCenter.reloadAllTimelines()` called after `NSFileCoordinator` block, not inside.

### General

- [ ] `guard let self = self else { return }` in all escaping closures.
- [ ] No fire-and-forget `Task {}` whose failure would lose user data.
- [ ] Async work triggered per-tick (1s metrics, 15s retries) must be idempotent — verify a slow iteration cannot overlap the next (reentrancy guard pattern in `WatchWorkoutManager.updateElapsedTime`).
- [ ] `savePendingSessionsToDisk()` captures `pendingSessions` as a value on `@MainActor` before dispatching the write.

---

## Pre-ship test for watchOS performance

Before merging any watchOS change:

1. **Launch lag test**: Start a free-run from the Home Screen complication — timer must appear in <1s.
2. **Freeze-on-stop test**: After 5 minutes of free run, swipe to controls tab and tap Stop — confirm no freeze, summary appears in <2s.
3. **Reconnect test**: Run with phone out of Bluetooth range, reconnect — UI must remain responsive during the sync burst.
4. **Pause persistence test**: Pause a workout, wait 30s, verify LiveWorkoutCard on iPhone still shows paused state (not cleared by timeout).
