---
name: Cadence (RPM/SPM) derivation
description: Why cadence never showed in workout timers, what CMPedometer's quirk is, and how the step-delta fallback works
type: project
originSessionId: 03b9c796-5a97-4621-b137-52ae78784ca2
---
# Cadence (RPM/SPM) Derivation

## Symptom (pre-fix)

Users reported "RPM" / cadence not showing in the workout timer on either iOS or watchOS — the CAD card simply wasn't visible during workouts.

## Root cause

Both `WatchWorkoutManager.startPedometerUpdates()` and `iPhoneWorkoutController.startPedometer(from:)` relied **solely on `CMPedometerData.currentCadence`** (Apple's instantaneous steps-per-second reading, multiplied by 60 for SPM).

That value is `nil`:
- Always in the iOS Simulator (no real motion data)
- For the first ~30-60s of a workout (CMPedometer needs a sample window to compute it)
- Frequently on real devices when step rate is inconsistent / very slow

When `currentCadence` was nil, the code skipped the assignment, leaving `currentCadence == 0`. The views (`iPhoneWorkoutTimerView.swift`, `TrainingView.swift`) used `if currentCadence > 0` as the display gate — so the CAD card was hidden entirely.

**Why:** the fix is non-obvious because Apple's docs describe `currentCadence` as "the cadence in steps per second," implying it's always available — but in practice it's a derived rolling estimate that requires a warmup window and consistent motion.

**How to apply:** Whenever cadence (or any other rolling-window CoreMotion / HealthKit value) appears to "not work," check whether the API returns nil for the warmup window and write a step-delta fallback. The same pattern likely applies to pace stability, ground contact time, and stride length.

## Fix (shipped 2026-05-23)

Both platforms now apply the same fallback pattern:

1. **Primary path** — if `data.currentCadence != nil`, use Apple's value (preferred)
2. **Fallback path** — if nil, derive cadence from step-count delta over a ≥3-second window:
   ```
   spm = (currentSteps - lastSteps) * 60 / elapsedSinceLastUpdate
   ```
3. Persist `lastCadenceStepCount` + `lastCadenceTimestamp` between samples
4. Reset both state vars at workout start AND workout end (otherwise the next workout's first delta carries over the previous workout's total)

### Files touched

- `ShuttlX Watch App/Services/WatchWorkoutManager.swift` — added `lastCadenceStepCount` / `lastCadenceTimestamp`, fallback in `startPedometerUpdates`, resets in both interval and free-run start helpers
- `ShuttlX/Services/iPhoneWorkoutController.swift` — same two-state-var + fallback pattern, resets in `beginCommonStart` and `tearDown`
- `ShuttlX/Views/Workout/iPhoneWorkoutTimerView.swift` — relaxed `if currentCadence > 0` gate to always show CAD card, rendering `"—"` when zero (avoids layout pop-in)
- `ShuttlX Watch App/Views/TrainingView.swift` — same display gate relaxation in both interval tertiary row and free-run row

### What did NOT change

- Apple's `currentCadence` still takes precedence when available (most accurate during steady-state running)
- Average / max cadence accumulators only sample when `spm > 0 && !isPaused` — unchanged
- HealthKit workout save data structure — unchanged

## Behavior after fix

| Scenario | Behavior |
|---|---|
| First 3s of workout | CAD shows `—` (still building first window) |
| 3-60s, Apple's value nil | CAD shows fallback derivation (jitters slightly more than Apple's value, but live) |
| 60s+, Apple's value available | CAD switches to Apple's instantaneous value (smoother) |
| Stationary user (treadmill rest) | CAD shows `0` (step delta = 0) — correctly reflects reality |
| iOS Simulator | CAD shows fallback derivation if simulator is providing step data; otherwise `—` |

## Related quirks (for future work)

- `CMPedometerData.currentPace` has the same nil-during-warmup behavior — currently we derive pace from `elapsedTime / totalDistance` so we don't hit this, but worth noting if we ever switch to instantaneous pace
- `HKQuantityTypeIdentifier.runningStrideLength` is iOS 16+ and could be a future enhancement, but requires `HKAnchoredObjectQuery` infrastructure we don't have today
- The `cadenceSampleSum` accumulator only collects samples where `spm > 0` — so the post-workout average is "average while moving" (not "average over total time"), which matches how athletes interpret cadence
