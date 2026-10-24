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

- `sessions.json` and `routes/`: only `DataManager` writes them (route files first, then sessions.json; `RouteExternalize.save`). Never read `session.inlineRoute` of a stored session on the iPhone: use `DataManager.route(for:)` or `routeSummary`.
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
- Payload checks (`Shared/WCPayloadValidation.swift`, tested): session data over 8 MB is refused before decoding; `isSaneSession` rejects implausible values (non-finite, out-of-range duration, distance, HR, segment or route counts); effort must be a UUID id and 0...10; alert values outside 0...300 are dropped while the alert itself still shows; live metrics with a bad elapsed time are ignored, other bad numbers become 0

## HealthKit

- `requestAuthorization()` must handle denial gracefully (no force unwraps on types)
- Background delivery requires `com.apple.developer.healthkit.background-delivery` entitlement
- Workout sessions: save on pause/stop, implement crash recovery
- iOS Health reads are read-only: `HealthKitImporter` requests `toShare: []`; `SessionHeartRateLoader` runs a statistics query over one session's range and stores nothing. `DataManager` is the iOS path that requests share types

## Units, VO2max (Wave 2)

- Distance unit: App Group `distanceUnit` ("km"|"mi"|absent); watch gets "km"|"mi"|"auto" under context key `distanceUnit` plus `splitAlerts` (Bool, missing = on). Display only; stored distances, `kmSplits` and pace data stay per km. Use `FormattingUtils.*(unit: .current)`; never hard-code "km" or "/km" in iOS views.
- VO2max: `VO2MaxLoader` (HKSampleQuery, latest 2 samples) is read-only; never stored, written to Health or sent to telemetry. Its type is requested in the single sheet via `DataManager.requestReadTypes` (importer gating stays on `HealthKitImporter.readTypes` so adding a read type never pauses the import).

## Deep Links

Deep links route widgets/controls/external URLs into the app to start workouts or navigate. **Widget processes cannot run WatchConnectivity** — iOS widgets must deep-link to the host app, which then calls `PhoneSyncCoordinator.startWatchWorkout()`.

- **iOS schemes**: `shuttlx://start-template/{uuid}`, `shuttlx://start-freerun`, `shuttlx://dashboard`, `shuttlx://session/{id}`, `shuttlx://plan` (selects Today and sets `showPrograms`; Programs is a row on Today), `shuttlx://last-workout` (sets `DeepLinkRouter.openLastWorkout`; ContentView resolves it to the newest session and keeps it pending until sessions load).
- **watchOS schemes**: `shuttlx://start-workout` (free run, direct call to `workoutManager.startWorkout()`), `shuttlx://start-template/{uuid}` (resolve template → `startIntervalWorkout(template:)`), `shuttlx://home` (navigate to home), `shuttlx://last-workout`.
- **DeepLinkRouter** (iOS): `ShuttlXApp.onOpenURL` parses and writes into the `DeepLinkRouter` environment object's pending properties. Consumers MUST read the pending value both on mount (`.task`/`.onAppear`) AND via `.onChange` — onChange alone never fires for a value set before the view mounted (cold-launch widget taps), which was a real shipped bug. If the target data isn't loaded yet, keep the pending value and retry when the data source changes (consume-on-load); clear it only after successful consumption.
- **Starting from a URL needs a confirmation (Oct 2026):** `shuttlx://start-freerun` and `shuttlx://start-template/{id}` only set `pendingStart`; an alert ("Start ...? This starts the workout on your Apple Watch.") must be confirmed before `startWatchWorkoutWithRetry` runs. Any app or web page can open a `shuttlx://` URL, so no URL may start a workout silently. Watch-side links (`shuttlx://start-workout` from complications) are unchanged.
- **New link registration**: use hyphenated hosts (e.g., `start-template`, not `startTemplate` or `start/template`).

## Heart limits, notifications, Health timing, phone workouts (Oct 2026)

- **Heart-limit numbers live in `Shared/HeartLimits.swift`** (one place). Estimate = round(0.85 x (220 - age) [x 0.81 on a beta-blocker "yes" / "not sure"]); needs a valid age (10-110). Typed ranges: limit 60-220, low limit 30...(upper-10), age 10-110, max HR 100-230. Fields commit on submit/blur only (`CommitIntField`); out-of-range numbers are clamped with a visible hint, non-numbers revert. `syncHeartSafety` is sent on commit/toggle only. Table pinned in `HeartLimitsTests.testEstimateTable`.
- `HeartSafetySettings.settingsVersion`: 1 = sudden-jump default OFF; older saved data is migrated once on decode. `load()` drops out-of-range limits.
- **Accepted risk (owner decision):** the watch receives the resolved limit and no medication answer, but a limit that is exactly 0.81x lower than the age formula lets a determined reader infer a beta-blocker answer. Not changed.
- `userMaxHeartRate` (HeartRateZoneCalculator.saveMaxHR) holds ONLY a value the user typed (Heart & alerts -> Max heart rate -> Manual). The Health-derived age goes to `userAge` (`userAgeFromHealth` flag), never into the override. A one-time migration clears the old frozen value on phone and watch (`maxHRResetPendingToWatch`).
- **Notifications:** permission is requested in onboarding (Done on the limit page) and when an alert switch is turned on, never in `handleHeartAlert`. `heartAlert` with ts older than 60 s or more than 5 s in the future is dropped.
- **Health sheet timing:** `HealthKitImporter` never requests access. It runs only when onboarding is finished (`isFirstLaunch == false`) and `statusForAuthorizationRequest(read: readTypes) == .unnecessary`. ONE request (`DataManager.requestHealthKitPermissions`) covers sharing + importer read types + date of birth; called from onboarding and Settings -> Health (button shown once while `healthReadAccessNeeded`; after denial Settings explains and opens iPhone Settings).
- **iPhone workout + watch:** starting on the iPhone also starts the watch (`watchLinked`). pause/resume/stop reach the watch. The watch session is authoritative: the phone's session is saved as a *placeholder* (`DataManager.markPhonePlaceholder`) and replaced by the watch session of the same workout (`SessionMerge`, overlap >= 50%); if a watch/Health session of that workout is already stored the phone's is not saved. A Health-imported copy with the same id is also replaced by the watch session (effort carried). Discard on the phone sends `["action":"discardWorkout"]` (sendMessage + transferUserInfo) and the watch drops its recording too. A 30 s gap in live metrics only clears the live card; the phone workout ends only on an explicit `workoutStopped` or the user. Workouts under 5 s are not saved.
- **Start handshake (phone workout + watch):** the phone's start message carries `phoneSessionId`; the watch answers `workoutStarted` (+ its `sessionId`) or `workoutStartIgnored` (already recording). `watchLinked` is set only after `workoutStarted` for that id; "ignored" shows a short notice on the timer, and no answer within 5 s means not linked for now, but a late `workoutStarted` for the same id (the watch answers only after HealthKit authorization) still links, and the second copy of an answer (sendMessage + transferUserInfo) is dropped (`StartHandshake`). The watch also answers `workoutStartIgnored` when its start fails. `discardWorkout` is never sent unlinked: the watch ignores one without the acknowledged id (`WatchLinkRules`, Shared, tested). While linked, pause / resume / stop / `discardWorkout` carry `phoneSessionId`. A `workoutStopped` is ignored when its `sessionId` differs from the current watch session, or (no id) when it was sent before the current workout started. `remoteStop` only ends a linked phone workout.
- **Live Activity buttons:** Pause/Resume go through the bridge; "Finish…" sends NO stop (`openAppWhenRun`, bridge command `show` raises the phone timer), the in-app End & Save confirmation does the stop. the intent first adopts the activity the system kept (`LiveActivityManager.adoptExisting`, cold launch), then routes to `iPhoneWorkoutController.handleLiveActivityControl` when a phone workout is active, else to the watch. `cleanupStaleActivities` never ends the activity this process holds.
- **Heart low limit:** clamped against the RESOLVED upper limit (own or estimated) in `watchPayload`, and moved on the phone (with a note) by `reconcileLowLimit` when the age changes.
- **Medication notes:** the name and daily dose live in the Keychain (`Shared/MedicineVault.swift`, service `com.shuttlx.medication`, `AfterFirstUnlockThisDeviceOnly`), behind the `SecretBackend` protocol so tests use an in-memory backend. `HeartSafetySettings.save()` strips them from the App Group JSON. Legacy JSON notes are removed only after the Keychain write is read back OK (`MedicineVault.store`); `wipeLocalUserData(.everything)` calls `MedicineVault.clear()`. Never synced, never sent to telemetry or Health.
- **Phone workout distance:** `Shared/DistanceFusion.swift` (value type, `update`) adds the GPS increment while a usable fix is under 10 s old, else the pedometer increment. Monotonic, never the sum, updated on every update of either source.
- **Paused heart-rate samples:** `Shared/PausedSample.swift` judges a sample by its own date, not by delivery time (used by the watch, see `watchos.md`).
- **Rejected watch sessions** (implausible values) are copied to `rejected_sessions/<id>.json` (newest 20), logged, and answered with an error reply, not "saved". The wipe removes the folder.
- **Widgets** apply "Fix a part" through `SegmentEdits.effective` (the same rule as `DataManager.effectiveSessions`), reading `segment_overrides.json` read-only.
- iPhone workout checkpoint: `PhoneWorkoutCheckpoint` (`iphone_workout_checkpoint.json`) every 15 s, on pause and on background; next launch offers Save / Discard. `UIBackgroundModes: location`; `allowsBackgroundLocationUpdates` is on only while an outdoor workout is running and not paused.

- **iPhone workout controls (Oct 2026):** labelled Pause/Resume and End & Save bars (End & Save still confirms); Discard is a small red "Discard workout" button in the header that opens a `confirmationDialog` ("Discard workout?", destructive "Discard", cancel "Keep going"; no Menu, which dropped taps in e2e). Route thinning uses `RoutePoint.thinEvenlyIfOver` (phone workout 6000 to 4500, live watch route 2000 to 1500). Phone distance is `DistanceFusion.update` called from `iPhoneWorkoutController.refreshDistance`. Recovery-rest arrow uses `HeartSafetySettings.zoneWord` (EASY) with the resolved limit; hidden when no limit/age.
