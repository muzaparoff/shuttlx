# Open development items: fix plan for review (October 2026)

Status: proposal. Nothing here is implemented. Written against HEAD e54f4f5 (v1.10.1, build 244). Each item names the code it touches, three ways to fix it with a pick, effort, and the check that proves it works. The rule for this plan is the smallest change that fixes the problem (ponytail): no new abstractions, no new dependencies, one fix at the place all callers go through.

Device-only checks stay in `docs/device-test-checklist-v1.10.1.md`. Nothing below is verified on hardware unless it says so.

## Phase 1: small fixes (one agent, one build, about half a day)

### 1.1 Live Activity "End & Save" saves with one tap
- **Evidence:** `EndWorkoutIntent.perform()` in `ShuttlX/Models/WorkoutControlIntents.swift:26` sends `"stop"` to `WorkoutControlBridge` at once. A Live Activity intent has no confirmation step, so a stray tap on the lock screen ends and saves the workout.
- **Options:**
  1. Keep Pause/Resume on the Live Activity and make End open the app on the live card, where the existing "End & Save" confirmation lives (`openAppWhenRun = true`, no stop sent). Effort S.
  2. Keep one tap and add a 5-second "Undo" in the app after it ends. Effort M, and the watch has already stopped by then.
  3. Leave as is and document it. Effort none.
- **Pick:** option 1. It costs one extra tap and cannot lose a workout by accident.
- **Files:** `ShuttlX/Models/WorkoutControlIntents.swift`, `ShuttlXLiveActivity/LockScreenView.swift` (button label "Finish…"), the Dynamic Island expanded view.
- **Check:** unit test that the bridge receives no `"stop"` from the intent; e2e step is not possible (Live Activity), so it stays on the device list.

### 1.2 Fix a part guess: no-cadence segments between 3.5 and 6.5 m/s
- **Evidence:** `SessionDetailView.swift:378` calls `SpeedActivityClassifier.classify` with `cadence` nil when a segment has no steps. With nil cadence the classifier returns cycling only at 6.5 m/s or more, so a 5 m/s segment is guessed as running. Segments with steps are unaffected.
- **Options:**
  1. When cadence is nil and speed is between 3.5 and 6.5 m/s, return the guess with low confidence so the sheet shows "not sure" and preselects nothing. Effort S.
  2. Lower the unknown-cadence cycling speed to 5 m/s. Effort S, but it brings back the watch false-cycling risk this threshold was raised to avoid.
  3. Leave as is.
- **Pick:** option 1. The watch keeps its safe threshold and the sheet stops claiming something it cannot know.
- **Files:** `Shared/ActivityClassifier.swift` (a `.low` confidence branch), `SessionDetailView.swift` (render "not sure").
- **Check:** `ActivityClassifierTests`: speed 5.0, cadence nil gives low confidence.

### 1.3 Jump alert wording
- **Evidence:** `Shared/HeartAlertEvaluator.swift:24` reads "Heart rate jumped quickly" on the phone, while the watch card says "Check your heart rate".
- **Pick (no options needed, wording only):** change the phone text to "Check your heart rate" and the body to "Up N bpm quickly". Effort S. The alert is off by default.

### 1.4 Stray blue circle under Trends › More › Distance
- **Evidence:** none. The agent found only the scrubber thumb in `ScrubTimelineHeroCard.swift`.
- **Plan:** needs a screenshot from the owner. Until then nothing changes.

### 1.5 Largest-text screenshots
- Take AX5 screenshots of History, Fix a part and the map header with `xcrun simctl ui booted content_size accessibility-extra-extra-extra-large`, and fix only what clips. Effort S.

## Phase 2: crash-resumed workout loses the phone session id

- **Evidence:** `WatchWorkoutManager.phoneSessionID` is set at start (`:386`, `:574`, `:598`) and cleared at stop (`:823`). `WorkoutPersistence` does not store it, so after a watch crash the resumed workout has no id and the watch ignores a phone Discard (by design: no id, no discard).
- **Options:**
  1. Write `phoneSessionID` into the existing crash backup and restore it in `resumeRecoveredSession`. Effort S, additive optional field.
  2. Let the phone resend its id when the watch reconnects. Effort M, more messages.
  3. Accept the limit.
- **Pick:** option 1.
- **Files:** `ShuttlX Watch App/Services/WorkoutPersistence.swift`, `WatchWorkoutManager.swift` (checkpoint and resume).
- **Check:** unit test of the backup round trip keeping the id; the device list already has checkpoint recovery.

## Phase 3: routes out of `sessions.json` (the one real project)

- **Evidence:** `route: [RoutePoint]?` is a stored property of both `TrainingSession` copies (`ShuttlX/Models/TrainingSession.swift:65`). About 26 places read `.route` across `SessionDetailView`, `HistoryMapView`, `TodayTimeline`, `PhoneSyncCoordinator`, `HealthKitImporter`, `AnalyticsEngine`, `ShuttlXApp`, and the watch. Every save rewrites all routes in `sessions.json`.
- **Blocker:** the model is duplicated per target and edits must stay in step.
- **Options:**
  1. Do it after the Phase 4 `TrainingSession` unification: one model, `route` becomes lazy, `routes/<uuid>.json` written only by `DataManager`. Safest, but waits on the unification. Effort L.
  2. Do it now with a side file and a computed accessor on both copies. Migration order: write the route file, then the stripped `sessions.json`, then delete the old data. Effort L, higher risk of losing routes if one reader is missed.
  3. Cap and thin routes at save time (the 6000-point cap already exists) and leave the file layout alone. Effort S.
- **Pick:** option 3 now, option 1 later. The file is large only for long GPS sessions; thinning already limits it. Do a measurement first: size of `sessions.json` after 50 sessions of 60 minutes each. Only if it exceeds about 5 MB is option 1 worth scheduling.
- **Check:** a size test on a generated history.

## Phase 4: planned features (discuss before building)

These need the owner's go-ahead on scope. Listed with the smallest first version.

| Item | Smallest first version | Effort | Depends on |
|---|---|---|---|
| Trends past periods | Previous/next arrows on the hero, same chart code | M | none |
| Reset to detected | A "Reset" button in Fix a part that deletes that session's entry in `segment_overrides.json` | S | none |
| AirPods heart rate | Needs a device test first to learn how the heart rate reaches the app | unknown | owner's device |
| Sign-in screen | Not planned; iCloud sync already works without it | none | owner decision |
| Tier 2 and 3 widgets | One at a time, starting with Next Planned | M each | design |
| `TrainingSession` / `WorkoutTemplate` unification | Move to Shared and delete the per-target copies | L | enables Phase 3 option 1 |
| `WatchWorkoutManager` decomposition | Extract the pause/alert code first (about 2,725 lines now) | L | none |

## Decisions needed from the owner

1. Live Activity End: option 1 (open the app) or keep one tap?
2. Fix a part guess: show "not sure" for ambiguous no-cadence segments?
3. Blue circle: a screenshot of where it is.
4. Phase 3: agree to measure first and thin only?
5. Heart-limit estimate sign-off (85 percent of 220 minus age, times 0.81 on a beta-blocker).
6. Sudden-jump alert: keep (off by default) or remove the code and the toggle?

## Order and process

Phase 1 and 2 together, one watch agent and one iOS agent, each building only its scheme, then one lead build, `swift test`, and the e2e suites (`smoke,workout10,discard`) before any push. Phase 3 measurement is a read-only step. Phase 4 starts only per item after discussion. Each push needs the owner's approval.
