# App Auditor — Logic & Crash Risks — 2026-05-15

## Summary

| Severity | Count |
|---|---|
| P0 (crashes / data loss / blocks ship) | 4 |
| P1 (broken logic / wrong data) | 6 |
| P2 (edge cases / defense) | 8 |
| Dead code candidates | 3 |

---

## P0 — Crashes / Data Loss / Ship Blockers

### [P0-1] Force-unwrap on `completedIntervals!` in TelemetryDeck analytics

`ShuttlX/Services/DataManager.swift:82`

```swift
"isInterval": String(session.completedIntervals != nil && !(session.completedIntervals!.isEmpty))
```

The `!` is applied at expression level. The pattern is currently safe due to short-circuit evaluation but is flagged by static analysis and will break under any future refactor or concurrent mutation path.

**Fix**: `"isInterval": String(session.completedIntervals?.isEmpty == false)`
**Owner**: `senior-ios-developer`

### [P0-2] Discarding a paused workout leaves backup on disk → next launch falsely recovers it

`ShuttlX Watch App/Views/TrainingView.swift:76-78`
`ShuttlX Watch App/Services/WatchWorkoutManager.swift:486`

`pauseWorkout()` writes `active_workout_backup.json`. Discard calls `stopWorkout()` which **explicitly does not clear the backup** (`// Backup is cleared by saveWorkoutData() after confirmed save — not here`). Next cold launch's `recoverCrashedWorkout()` finds the file and offers to save the discarded session as a "crashed" recovery — duplicate ghost session.

**Reproduce**: Start workout → pause → Finish → Discard → force-kill app → relaunch.
**Fix**: Add `clearWorkoutBackup()` unconditionally inside `stopWorkout()`.
**Owner**: `swiftui-watchos-specialist`

### [P0-3] `isStarting` spinner can lock permanently

`ShuttlX Watch App/Services/WatchWorkoutManager.swift:247-251`

```swift
Task { [weak self] in
    guard let self = self else { return }   // ← isStarting NOT reset
    await self.startWorkoutAfterAuth()
    self.isStarting = false
}
```

If `WatchWorkoutManager` is deallocated mid-auth, the guard fires without resetting `isStarting = false`. Start button is permanently spinning.

**Fix**: `defer { isStarting = false }` at the top of the Task, or reset in the guard's else branch.
**Owner**: `swiftui-watchos-specialist`

### [P0-4] Force-unwrap on `lastFullResendTime!` Optional inside concurrent Task callbacks

`ShuttlX Watch App/Services/SharedDataManager.swift:366`

```swift
if self.lastFullResendTime == nil || now.timeIntervalSince(self.lastFullResendTime!) > 60 {
```

`@MainActor` class with multiple WC delegate callbacks creating `Task { @MainActor in }` blocks. Concurrent interleaving + force-unwrap = latent crash.

**Fix**: `if self.lastFullResendTime.map({ now.timeIntervalSince($0) > 60 }) ?? true {`
**Owner**: `swiftui-watchos-specialist`

---

## P1 — Broken Logic / Wrong Behavior

### [P1-1] `replyHandler` called inside `Task { @MainActor in }` — WC delivery timeouts under load

`ShuttlX Watch App/Services/SharedDataManager.swift:395-457`

WC framework expects `replyHandler` to be called within a short window (~5s). If the main actor is busy (heavy JSON decode of many sessions), the Task is deferred and the reply arrives late. Sender gets `WCErrorCodeDeliveryFailed`.

**Fix**: Call `replyHandler` synchronously with a preliminary OK, then do heavy lifting in a background Task. For `ping`, call reply immediately before entering Task.
**Owner**: `swiftui-watchos-specialist`

### [P1-2] `SyncMonitor.addLog()` wraps writes in `DispatchQueue.main.async` inside a `@MainActor` class

`ShuttlX/Views/SyncDebugView.swift:159-164`

Redundant + violates actor isolation. Timer callback at line 110 mutates `@Published` properties — may run off-actor depending on RunLoop mode.

**Fix**: Remove the `DispatchQueue.main.async` wrapper. Convert timer callback to `Task { @MainActor [weak self] in ... }`.
**Owner**: `senior-ios-developer`

### [P1-3] Retry storm: `scheduleFinishRetryBurst()` inside `sendSessionToiOS` → quadratic closure accumulation

`ShuttlX Watch App/Services/SharedDataManager.swift:61-71` and `150-157`

`sendSessionToiOS` schedules a burst (+1s/+3s/+8s). Burst calls `retryPendingSessions()` which calls `sendSessionToiOS` for each pending session, which schedules another burst per session. N pending sessions → 3N retained closures per cycle, growing quadratically. On watchOS memory pressure, the WatchKit extension can be killed mid-workout.

**Fix**: Add `isBurstScheduled: Bool` flag; only schedule a burst if one isn't already pending.
**Owner**: `swiftui-watchos-specialist`

### [P1-4] `CloudKitSyncManager.performFullSync` `completion?()` not guaranteed on main

`ShuttlX/Services/CloudKitSyncManager.swift:58-88`

Inner `Task {}` inherits actor implicitly in Swift 5.9+, but after multiple `await` points the resumption executor is not guaranteed to be main actor. Callers update UI in the completion block.

**Fix**: `Task { @MainActor in ... }` explicitly, or `await MainActor.run { completion?() }`.
**Owner**: `senior-ios-developer`

### [P1-5] `DataManager.loadSessionsFromAppGroup()` does redundant work on first load

`ShuttlX/Services/DataManager.swift:225-242`

On empty `sessions`, the merge loop appends + inserts to `processedSessionIds`, then the `if existingIds.isEmpty` branch replaces `sessions = loaded` and re-builds `processedSessionIds`. The loop runs O(n) for nothing. For 500-session histories this is a noticeable startup pause.

**Fix**: Exit early when `existingIds.isEmpty`.
**Owner**: `senior-ios-developer`

### [P1-6] `AnalyticsEngine.fitnessScore` weight-index logic opaque + can overflow

`ShuttlX/Services/AnalyticsEngine.swift:76-83`

`weights` has 6 entries (oldest→most-recent). For `count < 6` weeks of data the offset `weightIndex = (6 - count) + i` is intentional. But if `weeklyTrainingLoads` is ever called with `weeks > 6`, the index overflows silently and the `else 0.1` fallback fires.

**Fix**: `precondition(count <= weights.count)` or clamp. Add inline comment.
**Owner**: `senior-ios-developer`

---

## P2 — Edge Cases / Defense

### [P2-1] `CFBundleShortVersionString` hardcoded `1.1.0` in both Info.plists
iOS: `ShuttlX/Info.plist:19`, watchOS: `ShuttlX Watch App/Info.plist:22`. CI is at 1.1.8. Settings-screen version display reads from this key and shows the wrong version. Live Activity extension correctly uses `$(MARKETING_VERSION)`.
**Fix**: Change both to `$(MARKETING_VERSION)`. **Owner**: `release-shepherd`

### [P2-2] `stopWorkout()` `workoutStopped` sendMessage has `errorHandler: nil`
`ShuttlX Watch App/Services/WatchWorkoutManager.swift:465`. Only `sendMessage` in the codebase without an error handler. iPhone Live Workout card stays visible up to 10s after stop if BT drops at that instant.
**Fix**: Add minimal error handler logging the WCError.
**Owner**: `swiftui-watchos-specialist`

### [P2-3] CloudKit temp files not cleaned on `pushSessions` failure
`ShuttlX/Services/CloudKitSyncManager.swift:118-119`. `cleanupTempFiles` only called on success. Failed syncs accumulate `{uuid}.json` and `{uuid}-retry.json` in temp dir.
**Fix**: `defer { cleanupTempFiles(for: sessions.map { $0.id }) }` at start of `pushSessions`.
**Owner**: `senior-ios-developer`

### [P2-4] Display timer creates a `Task` per second — accumulates if `updateElapsedTime` > 1s
`ShuttlX Watch App/Services/WatchWorkoutManager.swift:547-558`. `DispatchSourceTimer` fires 1Hz, each tick creates `Task { @MainActor [weak self] in ... }`. If updates exceed 1s (long workouts with route + HRR), Tasks accumulate.
**Fix**: `DispatchSource.makeTimerSource(queue: .main)` and call directly without Task.
**Owner**: `swiftui-watchos-specialist`

### [P2-5] Missing `com.apple.developer.healthkit.background-delivery` entitlement
No current feature requires it; declaring it now costs nothing and avoids a release delay later.
**Fix**: Add to both entitlement files.
**Owner**: `senior-ios-developer`

### [P2-6] `WorkoutTemplate.init` doesn't expose `deviceID`/`deviceName`
`ShuttlX/Models/WorkoutTemplate.swift:52-70` (+ watch copy). Fallback templates lose device association.
**Fix**: Add `deviceID: UUID? = nil, deviceName: String? = nil` params to designated init in both copies.
**Owner**: `senior-ios-developer`

### [P2-7] Verify `DebugView`/`SyncDebugView` NavigationLinks are `#if DEBUG`-wrapped in callers
`ShuttlX/Views/DebugView.swift:3`, `ShuttlX/Views/SyncDebugView.swift:4` are both DEBUG-wrapped. Confirm `SettingsView` references are too — release build will fail if not.
**Fix**: Grep + wrap if missing.
**Owner**: `senior-ios-developer`

### [P2-8] `print()` in `TemplateEditorView` `#Preview` block
`ShuttlX/Views/TemplateEditorView.swift:302`. Harmless (preview only), but violates the no-print policy.
**Fix**: Replace with `{ _ in }`.
**Owner**: `senior-ios-developer`

---

## Missing Features from CLAUDE.md

### Cadence (SPM) queried but never surfaced
`WatchWorkoutManager.currentCadence` populated from `CMPedometer.currentCadence` (line 843) but: not in broadcast payload, not saved to `TrainingSession`, not displayed in any view. Sensor data collected and discarded. Competitors (Runna, Garmin, Nike Run Club) all show cadence live + in history.
**Effort**: 2-3 hours. Add to broadcast dict, add `cadence: Int?` to `TrainingSession` (default nil), add a metric row to `TrainingView`.

### RevenueCat entitlement verification is `.informational` not `.enforced`
`ShuttlX/Services/SubscriptionManager.swift:47`. TODO marks `.enforced` as "future release." Acceptable for now — revisit when RevenueCat ships it.

### CloudKit sync has no progress UI during initial migration
`CloudKitSyncManager.migrateLocalData` has no `syncProgress` published state. Users uploading 200+ sessions see a spinner with no progress indicator.
**Effort**: 3-4 hours. Add `syncProgress: Double` published property, update SettingsView.

---

## Dead Code Candidates

### `tests/debug_ui_freeze.swift`, `sync_fix_implementation.swift`, `sync_fix_verification.swift`, `test_phase19_final_integration.swift`
In `tests/` but not part of any XCTest target. Scratch files from development sprints. No `XCTestCase` imports. Not referenced anywhere. Safe to delete or move out.

### `SyncMonitor` class inline in `SyncDebugView.swift:67`
Duplicates connectivity state that `SharedDataManager` already exposes (`connectivityHealth`, `lastSyncTime`, `syncLog`). Can be replaced with `@ObservedObject var sharedData: SharedDataManager`. DEBUG-only so low priority.

### `DebugView` "Clear All Training Sessions" button
One tap from irreversible data loss with no backup verification. Confirm excluded from release build.

---

## Top 5 P0/P1 findings (ship-blocking ranked)

1. **[P0-2]** Discarded workout falsely recovered — single most user-visible bug. Easy fix.
2. **[P0-1]** Force-unwrap on `completedIntervals!` in analytics path — fires every session, time bomb.
3. **[P0-3]** `isStarting` spinner permanently locked — workouts uninstartable until app restart.
4. **[P0-4]** Force-unwrap on `lastFullResendTime!` in concurrent WC paths.
5. **[P1-3]** Retry storm — quadratic closure accumulation; risks watchOS extension kill mid-workout.
