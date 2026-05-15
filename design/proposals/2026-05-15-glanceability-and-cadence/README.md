# Sprint-2: Interval Countdown Glanceability + Cadence Surfacing

**Date**: 2026-05-15
**Owner**: product-designer
**Scope**: watchOS `TrainingView` (interval mode), iOS `SessionDetailView`
**Estimated dev**: 2–4 hours total across both platforms

---

## Why this sprint

Two findings from the most recent on-device audit ride together because they touch the same screens:

1. **P0 glanceability** — On the watch interval-training screen the *countdown to the next interval transition* is the single most decision-relevant number for a cardiac-rehab patient on a treadmill: it answers "do I keep running or am I about to walk?". Today it lives inside a 56pt progress ring (`intervalTimerLine` in `ShuttlX Watch App/Views/TrainingView.swift:274`) while DIST, HR, and PACE are each rendered at `valueSize = h * 0.19` — roughly 30–42pt depending on watch size, **larger** than the countdown digits. The hierarchy is inverted.
2. **Missing feature — Cadence** — `WatchWorkoutManager.currentCadence` is collected from `CMPedometer` (line 844) and immediately discarded. It is not broadcast to iPhone, not persisted to `TrainingSession`, not shown anywhere. Every competitor in this category surfaces cadence; absence is a perceived-quality gap.

Both ship together because they both modify the watch interval display surface and the `MetricCard` grid on iOS — same designer review, same regression surface.

## Competitor research — cadence display patterns

**Runna** (run coaching, iOS-native, very popular with rehab cohort): shows cadence inline in their workout summary as `CADENCE 168 spm` in a metric tile alongside Avg Pace and Avg HR. During the workout the live cadence appears as a small label below the pace tile, never the hero metric. Threshold-style coloring (sub-160 dimmed grey, 165–185 white, >190 amber) is used as a soft cue, not an alarm.

**Garmin Connect** and the Garmin Forerunner / Venu watch screens: cadence is a first-class data field selectable on a customizable metric tile. The default Run activity profile includes it on screen 2. In post-run summaries it sits in the same row as average pace and average HR. Garmin uses `spm` (steps per minute), not `rpm`, even for run+walk intervals, and treats it as unitless until cycling is detected.

**Apple Workout** (built-in): does not surface cadence live on the watch face during a Run workout. It *is* recorded to HealthKit (`HKQuantityTypeIdentifier.stepCount` derivative) and shown in Fitness on iPhone post-workout as a small chart. Apple's reluctance to show it live tells us it is **not** a hero metric — it earns its place as a peer of Steps and Pace, not as a replacement for HR.

**Implication for ShuttlX**: keep cadence as a tertiary inline row on the watch (same visual weight as DIST/PACE), and as one tile of the iOS `SessionDetailView` metric grid alongside Steps and Pace. Don't color-code thresholds in this sprint — the cardiac-rehab population walks much of the time, and a "your cadence is low" tint during a walk recovery would be a false alarm. Hide the row entirely when cadence is 0 so walk recoveries collapse cleanly.

## Design principles applied

- **Reuse, don't invent.** `ShuttlXColor.forStepType(_:)` and `ShuttlXColor.forHRZone(_:)` already encode the per-step and per-zone color logic for all 7 themes; the new layout consumes them as-is. No new color tokens are added.
- **Theme-safe.** Step tint uses the theme-aware step color at 8% opacity as a screen wash — Neovim and Classic Radio (which have non-black grounds) absorb the tint without becoming muddy; Synthwave and Arcade (already saturated) bloom slightly. Verified mentally against all 7 theme color sets; no per-theme overrides required.
- **Cardiac-rehab default.** No flashy animations on the countdown — the existing `.contentTransition(.numericText())` is retained, and the progress ring is replaced with a sweeping arc beneath the digits (less visual noise than a 360° ring at the new hero size).
- **No state added without states designed.** Specs include `idle` (no current step / engine nil → falls back to TIME), `running`, `walking`, `warmup`, `paused`, `last 3 seconds` (haptic boundary, color unchanged), and `cadence == 0` (row hidden).

## Files

- `watch.md` — handoff for `swiftui-watchos-specialist`
- `ios.md` — handoff for `senior-ios-developer`

## Out of scope

- Cadence target zones / coaching cues (Phase 2)
- Cadence on iOS Live Activity / widgets (Phase 2)
- Per-step cadence breakdown in `IntervalResultsView` (Phase 2 — requires per-interval averaging in `IntervalEngine`)
- Free-run mode layout (untouched; only interval mode reflows)
