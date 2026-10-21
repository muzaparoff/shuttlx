---
globs:
  - "**/Services/**"
---

# Services Rules

## Thread Safety

- Use `@MainActor` on `ObservableObject` classes — never `@unchecked Sendable`
- Timer creation and access must be on the same actor
- Avoid `Task.detached` → `MainActor.run` chains that risk deadlock
- Weak references: always use `guard let self = self else { return }` pattern

## No Force Unwraps

- Never use `!` or `[0]` for array access
- Pattern: `FileManager.default.urls(for:in:)` → use `.first` with `guard let`
- Pattern: `HKQuantityType(...)` → use `guard let` or `if let`

## JSON Persistence

- `sessions.json`: only `DataManager` writes it. Other code hands sessions to `DataManager.handleReceivedSessions` (PhoneSyncCoordinator also drops them in the `pending_sessions/` inbox first). Never add a second writer
- Decode arrays with `LenientJSON.decodeArray`, back up with `StoreFile.backupCorrupt`, write with `StoreFile.writeOptions` (`Shared/StoreSupport.swift`)
- Local wipes go through `DataManager.wipeLocalUserData`; it sets the `sessionsClearedAt` cutoff and purges the watch

- Never silently fail: use `do/catch` with `os.log` for encode/decode errors
- Always encode/decode inside `do { try } catch { Logger.error(...) }`
- Corrections that must not touch `sessions.json` go in their own file: `SegmentOverrideStore` (`@MainActor`, single writer) keeps `segment_overrides.json`; effective parts = `SegmentEdits.apply(segments, sessionID)` (Shared, pure), applied once in `DataManager.effectiveSessions`; never write effective sessions back

## WatchConnectivity

- `WCSession.default.activate()` must be called at the correct lifecycle point
- Handle `WCSessionActivationState` changes properly
- Sync retries: use exponential backoff, max 5 retries, prevent stacking
- Always check `isReachable` before `sendMessage`, fall back to `transferUserInfo`
- Theme sync: iPhone sends `"syncTheme"` action via `updateApplicationContext` → Watch updates `ThemeManager.shared.selectedThemeID`
- Heart limits: iPhone sends `"syncHeartSafety"` with `HeartSafetySettings.watchPayload(age:)` only (resolved limit + alert flags). The medication answer never leaves the phone
- Effort: watch sends `"updateSessionEffort"` (`sessionId`, `effortRPE`) via sendMessage and transferUserInfo; the phone applies it by id (`DataManager.applyEffort`), or parks it in `PendingSessionEffort` until the session arrives. Never forwarded to Health or telemetry
- Heart alerts: watch sends `"heartAlert"` (`kind`, `value`, `ts`) via `sendMessage`, falling back to `transferUserInfo`. The phone mirrors it as a notification; a `noMotion` alert sets the Live Activity pause reason

## HealthKit

- `requestAuthorization()` must handle denial gracefully (no force unwraps on types)
- Background delivery requires `com.apple.developer.healthkit.background-delivery` entitlement
- Workout sessions: save on pause/stop, implement crash recovery
- iOS Health reads are read-only: `HealthKitImporter` requests `toShare: []`; `SessionHeartRateLoader` runs a statistics query over one session's range and stores nothing. `DataManager` is the iOS path that requests share types

## Deep Links

Deep links route widgets/controls/external URLs into the app to start workouts or navigate. **Widget processes cannot run WatchConnectivity** — iOS widgets must deep-link to the host app, which then calls `PhoneSyncCoordinator.startWatchWorkout()`.

- **iOS schemes**: `shuttlx://start-template/{uuid}`, `shuttlx://start-freerun`, `shuttlx://dashboard`, `shuttlx://session/{id}`, `shuttlx://plan` (selects Today and sets `showPrograms`; Programs is a row on Today), `shuttlx://last-workout` (sets `DeepLinkRouter.openLastWorkout`; ContentView resolves it to the newest session and keeps it pending until sessions load).
- **watchOS schemes**: `shuttlx://start-workout` (free run, direct call to `workoutManager.startWorkout()`), `shuttlx://start-template/{uuid}` (resolve template → `startIntervalWorkout(template:)`), `shuttlx://home` (navigate to home), `shuttlx://last-workout`.
- **DeepLinkRouter** (iOS): `ShuttlXApp.onOpenURL` parses and writes into the `DeepLinkRouter` environment object's pending properties. Consumers MUST read the pending value both on mount (`.task`/`.onAppear`) AND via `.onChange` — onChange alone never fires for a value set before the view mounted (cold-launch widget taps), which was a real shipped bug. If the target data isn't loaded yet, keep the pending value and retry when the data source changes (consume-on-load); clear it only after successful consumption.
- **New link registration**: use hyphenated hosts (e.g., `start-template`, not `startTemplate` or `start/template`).

## Heart limits, notifications, Health timing, phone workouts (Oct 2026)

- **Heart-limit numbers live in `Shared/HeartLimits.swift`** (one place). Estimate = round(0.85 x (220 - age) [x 0.81 on a beta-blocker "yes" / "not sure"]); needs a valid age (10-110). Typed ranges: limit 60-220, low limit 30...(upper-10), age 10-110, max HR 100-230. Fields commit on submit/blur only (`CommitIntField`); out-of-range numbers are clamped with a visible hint, non-numbers revert. `syncHeartSafety` is sent on commit/toggle only. Table pinned in `HeartLimitsTests.testEstimateTable`.
- `HeartSafetySettings.settingsVersion`: 1 = sudden-jump default OFF; older saved data is migrated once on decode. `load()` drops out-of-range limits.
- **Accepted risk (owner decision):** the watch receives the resolved limit and no medication answer, but a limit that is exactly 0.81x lower than the age formula lets a determined reader infer a beta-blocker answer. Not changed.
- `userMaxHeartRate` (HeartRateZoneCalculator.saveMaxHR) holds ONLY a value the user typed (Heart & alerts -> Max heart rate -> Manual). The Health-derived age goes to `userAge` (`userAgeFromHealth` flag), never into the override. A one-time migration clears the old frozen value on phone and watch (`maxHRResetPendingToWatch`).
- **Notifications:** permission is requested in onboarding (Done on the limit page) and when an alert switch is turned on, never in `handleHeartAlert`. `heartAlert` with ts older than 60 s or more than 5 s in the future is dropped.
- **Health sheet timing:** `HealthKitImporter` never requests access. It runs only when onboarding is finished (`isFirstLaunch == false`) and `statusForAuthorizationRequest(read: readTypes) == .unnecessary`. ONE request (`DataManager.requestHealthKitPermissions`) covers sharing + importer read types + date of birth; called from onboarding and Settings -> Health (button shown once while `healthReadAccessNeeded`; after denial Settings explains and opens iPhone Settings).
- **iPhone workout + watch:** starting on the iPhone also starts the watch (`watchLinked`). pause/resume/stop reach the watch. The watch session is authoritative: the phone's session is saved as a *placeholder* (`DataManager.markPhonePlaceholder`) and replaced by the watch session of the same workout (`SessionMerge`, overlap >= 50%); if a watch/Health session of that workout is already stored the phone's is not saved. A Health-imported copy with the same id is also replaced by the watch session (effort carried). Discard on the phone stops the watch, which still keeps its own recording (no remote-discard command). Workouts under 5 s are not saved.
- iPhone workout checkpoint: `PhoneWorkoutCheckpoint` (`iphone_workout_checkpoint.json`) every 15 s, on pause and on background; next launch offers Save / Discard. `UIBackgroundModes: location`; `allowsBackgroundLocationUpdates` is on only while an outdoor workout is running and not paused.
