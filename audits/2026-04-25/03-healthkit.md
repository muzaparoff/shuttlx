# HealthKit Audit — ShuttlX

Date: 2026-04-25
Scope: Clinical-grade correctness review of HealthKit usage, with attention to the upcoming Recovery Training (cardiac-rehab style) feature.
Audit-only. No source code modified.

## Regression Check (Prior P0s)

| Prior P0 | Status | Evidence |
|---|---|---|
| Workouts not saving to HealthKit | FIXED | `WatchWorkoutManager.swift:1042-1059` — `endCollection` then `finishWorkout`; route attached via `finalizeRouteBuilder` at `WatchWorkoutManager.swift:1082-1093`. `TrainingView.swift:53-67` calls `saveWorkoutData()` BEFORE `stopWorkout()`. |
| Auth gate missing on workout start | FIXED | `WatchWorkoutManager.swift:242-254` — `startWorkoutAfterAuth` awaits `requestHealthAuthorizationAsync()` and aborts if denied. UI surfaces denial via `authorizationDenied` and alert at `TrainingView.swift:85-94`. |
| Hardcoded HR zones | FIXED | `HeartRateZoneCalculator.swift:41-69` uses Tanaka formula (208 - 0.7×age) with manual override and HealthKit DOB lookup at `WatchWorkoutManager.swift:189-210`. No hardcoded zone numbers found. |

All three prior P0s are correctly fixed and not silently regressed. New findings below.

---

## Findings

### F1 — Calorie double-source: HK builder writes, app also writes via TrainingSession (potential clinical confusion)

- Severity: P1
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:824-884`, `872-883`, `1009`
- Why it matters: `HKLiveWorkoutBuilder` with `HKLiveWorkoutDataSource` automatically aggregates `activeEnergyBurned` and writes the resulting `HKWorkout` with summary statistics via `finishWorkout()` at line 1046. Independently, the app runs an `HKAnchoredObjectQuery` for `activeEnergyBurned` since `workoutStartTime` (line 829-840) and stores the sum in `totalCaloriesAccumulated`, then ships that number to the iPhone in `TrainingSession.caloriesBurned` (line 1009). Because the live builder also pumps values into HealthKit during the session, the anchored query on the same store may observe those samples and *also* sum them — meaning the app's own kcal display can include builder-emitted samples. Then on iOS, `CalorieEstimationEngine` (`ShuttlX/Services/CalorieEstimationEngine.swift:32-45`) re-estimates calories MET-based for analytics. A clinician viewing ShuttlX vs. Apple Health can see *three* different kcal numbers for the same session.
- Suggested fix direction: Use `HKLiveWorkoutBuilder.statistics(for:)` (Apple's recommended path) instead of a parallel anchored query to avoid double-counting; document which number is shown where. Decide which of (a) HK builder's energy, (b) MET re-estimate is the canonical clinician-facing value, and stop showing the other on summary screens.
- Confidence: high

### F2 — No HKWorkoutEvent markers for intervals, laps, or motion-paused

- Severity: P1
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift` (entire file — no occurrences); `ShuttlX Watch App/Services/IntervalEngine.swift:103-128` (step transitions emit haptics only)
- Why it matters: For interval/cardiac-rehab use, each warmup → work → rest → cooldown step boundary is exactly the moment a clinician needs to query in retrospective analysis. `HKLiveWorkoutBuilder.addWorkoutEvents([HKWorkoutEvent])` lets you record `.segment`, `.lap`, `.pause`, `.resume`, and `.motionPaused` events that survive into the `HKWorkout` object visible to other apps and to research exports. ShuttlX records zero events. The interval boundaries exist only inside the in-app `intervalResults` array (Watch local) and inside the JSON `TrainingSession` shipped to the phone. Apple Health, Fitness, and any third-party clinician app cannot reconstruct the rehab structure of the workout.
- Also missing: `pauseWorkout()`/`resumeWorkout()` (lines 326-373) call `workoutSession?.pause()`/`resume()` which DO emit pause/resume events automatically via the system, so those are fine — but explicit `.segment`/`.lap` events for interval steps and km splits are absent.
- Suggested fix direction: In `IntervalEngine.advanceToNextStep` (Watch can call back into `WatchWorkoutManager`), call `workoutBuilder?.addWorkoutEvents([HKWorkoutEvent.event(type: .segment, dateInterval: ..., metadata: ["IntervalType": ..., "TargetHRZone": ...])])`. Same for km splits in `updatePaceAndSplits` (line 709-737) — emit `.lap` events.
- Confidence: high

### F3 — No metadata written to saved HKWorkout (interval count, cooldown, template name lost)

- Severity: P1
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:1042-1049`
- Why it matters: `builder.finishWorkout()` is called with no preceding `builder.addMetadata(...)`. The saved `HKWorkout` therefore has no `HKMetadataKeyIndoorWorkout`, no `HKMetadataKeyWorkoutBrandName` for the template, no custom keys for interval count, no cool-down duration, no `HKMetadataKeyAverageMETs`. A clinician opening Apple Health or exporting via `HKWorkoutQuery` sees an unstructured generic workout. ShuttlX's own DB still has the template ID via `TrainingSession.templateID`, but that information is not in HealthKit — so a Health export to a doctor is missing the entire rehab program structure.
- Suggested fix direction: Before `finishWorkout()`, call `try await builder.addMetadata([HKMetadataKeyIndoorWorkout: NSNumber(...), "ShuttlXTemplateName": templateName, "ShuttlXIntervalCount": NSNumber(value: intervalResults.count), "ShuttlXProgramID": templateID.uuidString])`. For sport types like `.elliptical`/`.crossTraining` already mapped to indoor at `WorkoutSport.swift:62-64`, set `HKMetadataKeyIndoorWorkout` true.
- Confidence: high

### F4 — No HKWorkoutEffort (RPE) capture; no UI for it; missing for cardiac rehab

- Severity: P1 for the planned Recovery Training feature; P2 today
- File: There is no occurrence of `HKWorkoutEffort`, `RPE`, `perceivedExertion`, or `effort` in any Swift source under `ShuttlX/` or `ShuttlX Watch App/`. `TrainingSession.swift` has no RPE field.
- Why it matters: Cardiac rehab and ACSM/AHA guidelines treat RPE (Borg 6-20 or modified 0-10) as a primary intensity marker — frequently the only safe one when beta-blockers blunt heart rate. watchOS 11 introduced `HKWorkoutEffortRelationship`/`HKQuantityTypeIdentifier.workoutEffortScore` precisely for this. Without RPE capture, the app cannot meaningfully serve the cardiac-rehab use case the roadmap describes. A clinician comparing two patient sessions cannot tell which felt harder.
- Suggested fix direction: Add a post-workout RPE prompt (1-10 modified Borg) in `WorkoutSummaryView`, write it as `HKQuantitySample(type: .workoutEffortScore, ...)` and relate it to the saved `HKWorkout` via `HKWorkoutEffortRelationship`. Persist into `TrainingSession.rpe`. Required read+write types: `.workoutEffortScore`.
- Confidence: high

### F5 — HR sample dedup on relaunch is anchor-based but anchor is not persisted across app launches

- Severity: P2
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:67-68` (`heartRateAnchor`/`caloriesAnchor` are instance vars only); `WatchWorkoutManager.swift:280` (reset to nil on every workout start); `WatchWorkoutManager.swift:420-421` (cleared on stop)
- Why it matters: The `recoverCrashedWorkout()` path (line 938) reads JSON-backed `TrainingSession` from disk after a crash. But the in-memory HR/calorie anchors are gone. If the user crashed mid-workout and the watch app restarts mid-session (rare, but cardiac patients are exactly the population where extended sessions make this likelier), there is no path to resume the anchored queries from where they left off — the recovery currently just restores the saved JSON snapshot, not the live HK collection. The HK side ends up missing all samples between crash and restart. For a recovered session this is acceptable; the bigger risk is that the *backed-up JSON values* and *what HK eventually saved via builder* will not agree, because in a hard crash `builder.finishWorkout()` is never called and the in-flight session is dropped (HKWorkoutSession state machine).
- Suggested fix direction: On crash recovery, do not attempt to "resume" the HK side — accept that HKWorkout for a crashed run will not exist and clearly mark the recovered session as `source: .localOnly` so a clinician knows the data did not pass through HealthKit. Persisting `heartRateAnchor` to disk would not help because the abandoned `HKWorkoutSession` state cannot be reattached anyway.
- Confidence: medium

### F6 — HR/calorie samples from ANY source contaminate workout averages (no source filter)

- Severity: P1
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:755-790` (HR query), `833-869` (calories query)
- Why it matters: `HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)` filters by *time only*. If the user wears a paired Bluetooth chest strap that writes to HealthKit, OR has another fitness app running that writes HR samples concurrently, OR the iPhone is connected to a third-party HR monitor — every one of those samples gets summed into the running average and counted toward `heartRateSampleCount`. For a cardiac patient this is dangerous: the clinician sees an average that mixes wrist-PPG (less accurate at high HR) with a chest-strap ECG (more accurate). Worse, both sources can be summed double if both are active.
- The same applies to `activeEnergyBurned` (line 829-840): if a smart treadmill or bike publishes kcal during the same window, those get added in.
- Suggested fix direction: Use `HKQuery.predicateForObjects(from: HKDevice.local())` ANDed with the time predicate, OR filter to samples whose source is the current workout's `HKLiveWorkoutBuilder`. The cleanest fix is to remove the parallel anchored queries entirely and read live values from `workoutBuilder.statistics(for: heartRateType)` — those are sourced exactly to the active session.
- Confidence: high

### F7 — Distance and step source disagrees with HKLiveWorkoutBuilder

- Severity: P2
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:688-707` (CMPedometer drives `totalDistance`)
- Why it matters: The app uses `CMPedometer` for distance/steps (line 696-704), which returns Core Motion's pedometer estimate. Meanwhile `HKLiveWorkoutDataSource` (line 466) is collecting `distanceWalkingRunning` from HealthKit's fused source (GPS + accel) into the builder. The `HKWorkout` saved at the end carries HK's distance; the in-app `TrainingSession.distance` carries CMPedometer's distance. These two will not agree. For a cycling/elliptical/swimming workout (see `WorkoutSport.swift:69-74`, only running/walking auto-start the pedometer), `totalDistance` stays at zero in the local session yet HK builder may still record distance from connected gym equipment.
- Suggested fix direction: Read `workoutBuilder.statistics(for: distanceWalkingRunning)?.sumQuantity()` for the in-app distance and drop the parallel CMPedometer path for distance (keep it for steps if needed, since HK builder doesn't aggregate `stepCount`). This also gives correct distance for the non-running sports.
- Confidence: high

### F8 — `distanceWalkingRunning` is the only distance type read/written; cycling/swimming distances are silently zero in TrainingSession

- Severity: P1
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:174-177` and the absence of `distanceCycling`, `distanceSwimming`
- Why it matters: For the cycling/swimming sports already in `WorkoutSport.swift:7-15`, ShuttlX reads/writes only `distanceWalkingRunning`. `HKLiveWorkoutDataSource` will collect the correct distance type behind the scenes (cycling -> distanceCycling, swimming -> distanceSwimming) and write the resulting `HKWorkout` with that distance. But the auth set the user is presented with does not include those types — so when ShuttlX reads them back later for analytics, no samples appear. The local `TrainingSession.distance` for cycling/swimming will be zero (CMPedometer doesn't apply, no HK read for those types). A clinician comparing rehab progress in cycling will see 0 km in ShuttlX while Apple Health shows the correct value.
- Suggested fix direction: Add `HKQuantityTypeIdentifier.distanceCycling`, `.distanceSwimming` to read+write set in `buildHealthKitTypes()`. Read the appropriate distance type per sport via `workoutBuilder.statistics(for:)`.
- Confidence: high

### F9 — Background delivery is NOT enabled; `workout-processing` background mode is the only thing carrying long sessions

- Severity: P2 (informational)
- File: `ShuttlX Watch App/Info.plist:35-38` (`workout-processing`); no `enableBackgroundDelivery` in any Swift file; `com.apple.developer.healthkit.background-delivery` is NOT in either entitlements file (`ShuttlX Watch App/ShuttlX Watch App.entitlements`, `ShuttlX/ShuttlX.entitlements`).
- Why it matters: The watch app correctly relies on `workout-processing` to keep the HK session alive during a workout — that is the right approach for active workouts. However, for the planned Recovery Training feature (HRR — heart rate recovery — needs to capture 1-, 2-, and 3-minute post-exercise HR values *after* the user has stopped active exertion), the lack of HK background delivery means once `stopWorkout()` ends the session and queries are torn down (line 381-382), the app cannot reliably observe post-workout HR samples. HRR is the strongest single predictor of cardiac mortality risk in rehab — losing that window is a clinical correctness gap for the planned feature.
- Suggested fix direction: When implementing Recovery Training, add `com.apple.developer.healthkit.background-delivery` entitlement and call `healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate)`. Keep an HKObserverQuery alive during a "recovery window" (3-5 minutes post-stop) and capture HR-1/HR-2/HR-3 samples even with the app suspended.
- Confidence: high

### F10 — `HKHealthStore.authorizationStatus` is checked only for `workoutType` on iOS — read-only types' status is unknowable

- Severity: P3
- File: `ShuttlX/Services/DataManager.swift:106-111`
- Why it matters: HealthKit deliberately does not expose authorization status for *read* types (privacy). The iOS app sets `healthKitAuthorized` based on the *write* status of `HKWorkoutType`. If the user grants share but denies read of HR, `healthKitAuthorized` is `true` and the app proceeds as if everything is fine — but read queries will silently return empty results. For a cardiac-rehab clinician dashboard on iOS, this means the app may show "no HR data" instead of "HealthKit access incomplete."
- Suggested fix direction: When reading HR fails to return *any* samples for a recently saved workout, treat that as a soft-deny signal and prompt the user to re-check Health permissions in iOS Settings.
- Confidence: medium

### F11 — Calorie MET adjustment uses the wrong max-HR formula vs. the rest of the app

- Severity: P3
- File: `ShuttlX/Services/CalorieEstimationEngine.swift:89` uses `220.0 - Double(age)` (Fox formula); `ShuttlX/Models/HeartRateZoneCalculator.swift:46` uses `208 - 0.7 × age` (Tanaka formula).
- Why it matters: Two different max-HR formulas in the same codebase produce two different "% of max" interpretations. The HR-zone display will say "Zone 3" while the calorie engine internally treats the same HR as a different fraction of max. For a 60-year-old: Tanaka = 166, Fox = 160 — that is a 4% delta in `hrReserveRatio` and produces measurably different MET adjustments for the same workout.
- Suggested fix direction: Use `HeartRateZoneCalculator.estimatedMaxHR` everywhere, including inside `hrAdjustedMET`. Or document explicitly which formula is used where and why.
- Confidence: high

### F12 — `HKWorkoutSession.startMirroringToCompanionDevice` not used; live iPhone view re-implemented over WCSession

- Severity: P3
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:538-572` (manual `WCSession.sendMessage` every 3s); no `startMirroringToCompanionDevice` anywhere.
- Why it matters: watchOS 11 added `HKWorkoutSession.startMirroringToCompanionDevice()` precisely so you don't have to roll your own live HR/distance pipe over WatchConnectivity. The current implementation works but is throttled to 3 seconds (line 540) — a clinician's iPhone view of a rehab session sees HR with a 3-second-stale reading. Mirroring delivers per-sample updates with system-managed latency. Not a correctness bug per se, but it is also more battery-efficient.
- Suggested fix direction: For the iOS-side rehab dashboard, adopt session mirroring; keep WC for non-HK metadata (interval engine state, RPE prompt).
- Confidence: medium

### F13 — `pauseWorkout` re-saves backup but doesn't trigger HK sample re-fetch on resume; HR/calorie queries persist across pause but pause-time exclusion is based only on `isPaused` flag

- Severity: P3
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:334-338` (queries deliberately kept running through pause), `799-805` (HR sum-skip when paused)
- Why it matters: The decision to keep the anchored query running across pause is correct (avoids the well-known HKAnchoredObjectQuery initial-replay bug — see comment at 334-337). However, the pause-exclusion logic at line 802 (`if !self.isPaused { sum += ... }`) drops samples observed *during* the paused period from the HR average — but `HKLiveWorkoutBuilder` with `HKLiveWorkoutDataSource` will still aggregate those samples into the saved `HKWorkout.statistics(for: heartRate)` because `workoutSession.pause()` does pause its own collection. So the in-app average HR can differ from `HKWorkout`'s reported average HR for the exact same time range. Minor, but for a clinician auditing rehab compliance, two "average HR" numbers for the same workout is a confidence-eroding artifact.
- Suggested fix direction: As in F1/F6, prefer `workoutBuilder.statistics(for: heartRateType)` as the single source of truth for in-app display.
- Confidence: medium

---

## Summary

Three prior P0s are correctly fixed. The architecture is largely sound for a consumer interval-training app, but several gaps make it unsuitable for clinical-grade cardiac rehabilitation review *as-is*:

1. **Multiple parallel data sources** for the same metrics (HK builder + anchored query + CMPedometer + MET re-estimate) producing disagreeing numbers (F1, F6, F7, F11, F13).
2. **Lost rehab structure in HealthKit**: no events for interval boundaries, no metadata on saved workouts, no RPE (F2, F3, F4).
3. **Missing read scopes for non-running sports** mean cycling/swimming distance is zero in app even when correctly saved by HK (F8).
4. **No HR background delivery** so HRR — the marquee cardiac-rehab signal — cannot be reliably captured post-workout (F9).

Highest-impact fixes in order: F4 (RPE for rehab), F2 + F3 (interval segments + metadata in HK), F6 (source filtering on HR), F1 + F8 (single-source-of-truth via builder.statistics).
