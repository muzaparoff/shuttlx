---
globs:
  - "ShuttlX Watch App/**"
---

# watchOS Rules

## General

- Scheme name: `ShuttlX Watch App`
- watchOS target path: `ShuttlX Watch App/`
- Build: `xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlX Watch App" -destination 'generic/platform=watchOS Simulator' build` (do NOT pass `-sdk` — it forces the iOS companion target onto the watch SDK and breaks its SPM deps)
- Background mode: `workout-processing` for active workouts

## Timer Display

- Use 40pt monospaced font for timer on watch (smaller than iOS 52pt)
- Use `DispatchSourceTimer` (not `Timer`) — drift-proof, works when screen off
- Must work during wrist-down (screen off) state
- Test with long workouts (30+ minutes)
- **Watch screens follow the timeline mockup** (2026-10, owner decision: "follow the mockup"; it replaced the 4-row free-run metric stack). Source of truth: the timeline mockup's 10 watch screens. Sizes are mockup px scaled by screen height: `WatchScale.pt(px)` = `px / 238 × screenHeight` (`Components/WatchScreenParts.swift`), so 40mm and 46mm keep the mockup proportions.
- **Free run = 3 pages** (`TrainingView.swift` TabView, `TrainingView+Running.swift`): 0 `runningPage` → 1 `freeRunMetricsPage` (swipe left) → 2 `controlsTab`. Interval and gym recovery keep their own main page (`fullWorkoutDisplayTab`, `RecoveryWorkoutView`) + controls; `fullWorkoutDisplayTab` is interval-only now.
  - **Running page**: `● RUN|WALK|CYCLE` tag in the activity colour (`FREE RUN` grey before the first classification) → `ElapsedTimerText` at pt(48) semibold → ONE zone word EASY/STEADY/HARD (pt(30) heavy; EASY pale green, STEADY green, HARD orange) + thin zone bar (hr / reference) → spacer → red `N BPM` pt(30) at the bottom → hint "Swipe left: distance, pace, calories." (hidden while a banner or the toast shows). Zone reference = synced `heartSafety.upperLimit`, else `HeartRateZoneCalculator.estimatedMaxHR`, same 70 / 90 % split as `HeartSafetySettings.zoneWord`; effort-only mode → no word, no bar. Paused = amber clock + 0.8 s pulse.
  - **Heart-limit mode** replaces the running page while a limit is synced AND HR ≥ 90 % of it: `HEART LIMIT N`, pt(62) orange HR, pt(9) green→orange bar at hr/limit, amber "Ease off — HR high" pill. No timer on this page (mockup).
  - **Metrics page**: distance / pace / calories as label-less `unitNumber` rows, each solved with `fittedMetricSize` (cap 0.17h).
  - **"Ease off — HR high" is amber, not red** (instruction, not alarm) on every layout. With a synced limit it fires above the limit; without one it fires at HARD (≥ 90 % of `HeartRateZoneCalculator.estimatedMaxHR`, via `HeartSafetySettings.zoneWord`), so it never shows next to STEADY (`isHighHR`, `TrainingView+Metrics.swift`). The shared calculator's 70 % `isHighIntensityWarning` is no longer used by the watch.
- **Overlays on `TrainingView`** (overlays, never sheets — no system close button): `SafetyPromptView` (3h50m) > `UnusualHeartRateView` (`unusualHeartRate`, from a `.suddenJump` alert; `.failure` haptic; stays until OK / Pause) > `AutoPausedView` (`isPaused && autoPauseReason != nil`; "No heart rate for N s." uses `heartSafety.noMotionSeconds`). All share `WatchPromptCard` + `WatchPillButtonStyle` (`SafetyPromptView.swift`): green primary, dark-red/red-text End & Save, ≥44pt tall, opaque black base.
- **Auto-switch toast + Undo**: `commitActivityTransition` publishes `activitySwitch` for `undoWindow` (4 s) on a real run↔walk / foot↔cycle switch (not the first classification, not stationary). It renders in its own row under the tag (timer/word shrink to pt(44)/pt(28) to pay for it). `undoActivitySwitch()` drops the just-opened segment, reopens the previous one (restores its start, step and distance baselines), `classifier.override(to:)`, and skips `checkSpeedActivity` / `checkPendingActivityTransition` for `undoSuppression` (60 s). Pause clears the toast; resume clears the suppression. The toast only shows on the running page, not in heart-limit mode.
- **Interval page** (`fullWorkoutDisplayTab`, `TrainingView+Metrics.swift`): `VStack(spacing: 0)`, all sizes `WatchScale.pt` + solved. Program name pt(11) capped to 60 % width (clear of the system clock) → countdown hero (≤ pt(44), solved against the row minus the phase column; the phase column stacks one word per line — COOL / DOWN / 3/8) → step bar → NEXT preview (hidden while a banner shows, to pay for it on 40mm) → HR pt(26) + BPM + zone arc → banners → DIST/PACE and TIME/CAL two-up rows (one solved size per row via `twoUpValueSize`, `fixedSize`, no scale factor) → bottom inset `max(10, h*0.055)`.
- **Controls page**: two pt(70) circles (min 56): green PAUSE/RESUME, red END (still goes through the Finish alert), hint "Swipe right: back to workout".
- **Summary** (`WorkoutSummaryView`): `WORKOUT COMPLETE`, pt(38) time, `ActivityRibbon` from `WorkoutSummary.segments` (finalized segments), km + red bpm, "Saved to Health ✓" only when `healthKitSaved` (set after `finishWorkout()` returns a workout), else amber "Not saved to Health" when `healthKitSaveError != nil` (the old TrainingView alert is gone: it was set after the summary had replaced TrainingView, so it never showed; the error is reset at workout start), green Done; calories / pace / steps / sets / HRR / weight hint sit below the fold. Done → `EffortView` (when `heartSafety.showEffortOnWatch`): Digital Crown 0–10, Borg CR10 words, 11-segment bar, Skip / Save → `updateSessionEffort` (writes the watch copy AND sends `["action": "updateSessionEffort", "sessionId", "effortRPE"]` to the phone: sendMessage when reachable, else / on error transferUserInfo — iOS dedups resent sessions by id, so the session itself never carries a late effort; never Health metadata or telemetry).
- **Home**: `SHUTTLX` caption, pt(104) green Start circle (free run), "Free Run · finds Run / Walk itself", one `Programs ›` row → `ProgramsListView` (templates + DEBUG ant). Gym Recovery is off Home; it is still started from the iPhone (`"gymRecovery"` in WatchSyncCoordinator).
- **Lessons that still bind**:
  - **Sizes are SOLVED, never scaled.** SwiftUI silently scale-to-fits an over-full stack (measured 2026-08-06: the old hero rendered at 0.49× its computed size). Value `Text`s use `.fixedSize()` and no `minimumScaleFactor`; `ElapsedTimerText` caps its own size by glyph count (5 for m:ss, 7 for h:mm:ss) and must never get a scale factor. If something doesn't fit, it visibly doesn't — fix the size, don't add a scale factor.
  - A `Spacer(minLength: 0)` inside a spaced VStack still costs spacing on both sides — new pages use `VStack(spacing: 0)` + explicit `padding(.top, pt(...))`.
  - Keep the last line clear of the TabView page dots: `max(10, h * 0.055)` bottom inset (dot band y193–195.5 of 197 on 40mm, y240–245.5 of 248 on 46mm).
  - HR and the safety banner never leave the screen; any new running-page element must fit the 40mm budget with the banner showing — check with the snapshot harness.
  - No idle animations; any `TimelineView(.animation)` must pass `paused:`; AOD (`isLuminanceReduced`) shows `aodMinimalView` (time + BPM) only.
- Snapshot-verified 2026-10-20 on SE 3 40mm + Series 12 46mm (watchOS 27 sim): every screen above, plus 1h+ clock, banner, paused, AOD, interval.
- DEBUG snapshot harness env (`ShuttlXWatchApp.swift`, launched via `SIMCTL_CHILD_*`): `SHUTTLX_SNAPSHOT=<themeID>`, `SHUTTLX_SNAPSHOT_ELAPSED=<sec>` (free-run seed; omit for the interval seed), `SHUTTLX_SNAPSHOT_HR`, `SHUTTLX_SNAPSHOT_PACE` (`none` → "—"), `SHUTTLX_SNAPSHOT_AOD=1`, `SHUTTLX_SNAPSHOT_PAUSED=1`, `SHUTTLX_SNAPSHOT_ACTIVITY=running|walking|cycling`, `SHUTTLX_SNAPSHOT_LIMIT=<bpm>` (fake synced heart limit), `SHUTTLX_SNAPSHOT_OVERLAY=toast|unusual|autopaused`, `SHUTTLX_SNAPSHOT_TAB=<page>`, `SHUTTLX_SNAPSHOT_SCREEN=home|summary|effort`, `SHUTTLX_SNAPSHOT_HEALTHFAIL=1` (summary shows "Not saved to Health").

## Pace (Rolling vs Cumulative)

- Pace is computed from a **sliding 30-second window**, not cumulative average from workout start
- Guards: must be ≥20s into workout AND ≥0.05km total distance AND window ≥5s AND ≥5m moved, else shows "—"
- CMPedometer distance has ~30s warmup lag; first sample arrives skewed (e.g. 30s / 0.05km = 10'00). Sliding window avoids the warmup artifact entirely
- Root cause doc: `docs/incidents/2026-06-06-pace-10min.md`

## Controls

- Circular buttons: green for pause, red for stop
- Keep controls large and tappable (min 44pt touch target)

## Workout Lifecycle

- HealthKit workout session must survive app backgrounding
- Save workout data on pause AND on stop (crash recovery)
- If app is killed mid-workout, data must be recoverable from local storage
- **Crash/kill recovery RESUMES the workout** (2026-10): `WatchAppDelegate.handleActiveWorkoutRecovery()` (`@WKApplicationDelegateAdaptor` in `ShuttlXWatchApp.swift`) and the root `onAppear` both call the idempotent `beginLaunchRecovery()`. `recoverOrphanedHKSession()` gets the live session via `recoverActiveWorkoutSession` (5s timeout); a `.running`/`.paused` session goes to `resumeRecoveredSession(_:)` — delegates, builder, a fresh `HKLiveWorkoutDataSource` and route builder are reattached, and timer/sensors/15s checkpoint continue under the crash backup's session id. Active time comes from `builder.elapsedTime(at:)`; the backup restores segments/steps/splits/route/mode (the checkpoint now carries `templateID`, `programName`, `sportType`, `sessionMode`, `recoveryReport`). HR and energy/distance are NOT seeded from the backup: the HR query replays from the start (anchor nil) and builder statistics are cumulative. Any other state, or a failed auth, falls back to finalizing (`endCollection` + `finishWorkout`); if no session is recovered, the backup is sent.
- `saveRecoveredSession` **always** hands the backup to `sendSessionToiOS` — "already in sessions.json" means stored on the watch, not delivered. iOS dedups by id, so resending is safe.
- **Distance + energy come from the live builder** (`didCollectDataOf` → `applyBuilderDistance` / `applyBuilderEnergy`): `distanceWalkingRunning` / `distanceCycling` / `distanceSwimming` and `activeEnergyBurned` `statistics(for:).sumQuantity()`. There is no anchored energy query any more (it was unfiltered and summed other sources). Per-phase energy: each builder increment becomes one ledger span. Pedometer = steps/cadence + distance/pace fallback until the builder reports a non-zero distance; on that switch the pace window is cleared so the two sources never mix.
- **Pedometer restarts from resume time** with a captured step/distance offset — paused steps are never counted.
- **Indoor sessions** (`sessionLocationType == .indoor`: gym recovery, elliptical, cross-training) never start CoreLocation; the guard lives in `startLocationUpdates()` and `requestLocationAndStartUpdates()`.
- **Long-workout safety prompt**: at 3h50m ACTIVE time, `SafetyPromptView` (an overlay on `TrainingView`, not a `fullScreenCover`, so no system close button can dismiss it) shows "Still training?" with Continue / End & Save, plays `.notification` and checkpoints right away. Continue re-arms it 60 min later; no answer within 5 active minutes → `finishAndSave(autoEnded: true)` (sets `TrainingSession.autoEnded = true`, a defaulted optional in both copies). Pure logic: `Shared/SafetyPromptSchedule.swift` (tested in `tests/ShuttlXTests/SafetyPromptScheduleTests.swift`). Ticks don't run while paused, so pause freezes both the threshold and the timeout.

## Heart Alerts, Auto-Pause, Activity Switch

- **Alerts** (`HeartAlertEvaluator`, run from the workout tick): above limit, below low limit, signal lost, no motion. The sudden-jump alert is removed. A haptic always fires; a watch notification posts only when the app is not frontmost; every alert goes to the phone as `heartAlert`.
- **No-motion auto-pause**: 60 s without an HR sample and without motion pauses the workout with reason `noMotion` (`autoPauseReason`). It is a heuristic: there is no public wrist-detection API. *Unverified: behaviour with the watch off the wrist (device test pending).*
- **Zone word**: with a synced heart limit, the one-word zone (EASY / STEADY / HARD, cut-offs at 70% and 90% of the limit) takes the arc's slot beside the BPM value. Without a limit the arc stays.
- **Activity auto-switch**: `checkSpeedActivity()` classifies on-foot vs cycling from GPS speed and cadence (`SpeedActivityClassifier`, with hysteresis). *Unverified: thresholds are not yet tuned on real sessions.*
- **Effort**: the post-workout RPE is written to `effortRPE` through `WatchSyncCoordinator.updateSessionEffort`, which also sends the `updateSessionEffort` message to the phone (`sendSessionEffort`).

## Watch Complications / Widgets

- Widget files are in `ShuttlXWatchWidgets/`
- Types: LastWorkout, QuickStart, WeeklyProgress, TodayWorkout
- Data provided via `WatchWidgetDataProvider`

## Theme System

- Clean is the only theme (July 2026 reduction deleted 5, October 2026 deleted Mixtape)
- Theme files mirrored in `ShuttlX Watch App/Theme/` with watch-specific font sizes
- Theme selection synced from iPhone via WCSession `applicationContext`
- `ThemeManager.shared` injected at app root in `ShuttlXWatchApp.swift`
- Use `ShuttlXColor.*` / `ShuttlXFont.*` (bridges to active theme) or `@Environment(ThemeManager.self)`

## Sync

- Watch-side sync is in `WatchSyncCoordinator.swift` (~1,200 lines)
- Phone-side sync is in iOS `PhoneSyncCoordinator.swift` (~1,130 lines)
- Both must handle offline gracefully — queue and retry
- Theme sync: `handleIncomingPayload` handles `"syncTheme"` action from iPhone
