---
description: watchOS battery, memory, and lifecycle constraints checklist for ShuttlX — TimelineView pausing, AOD, redraw budgets, workout survival
user_invocable: true
---

# /watchos-constraints

Apply when writing or reviewing any code in `ShuttlX Watch App/`, especially theme heroes, Canvas overlays, and workout lifecycle code.

## Battery & rendering budget

- [ ] Every `TimelineView(.animation(minimumInterval:))` MUST pass `paused:` tied to workout pause state. Reference implementation: `ClassicRadioTimerHero.swift` (`minimumInterval: 1.0/12.0, paused: workoutManager.isPaused`). A hero redrawing a static frame at 24 Hz while paused is a defect.
- [ ] Redraw rate budget on watch: ≤12 Hz for decorative animation, 1 Hz for data-driven updates. 24 Hz needs written justification.
- [ ] AOD / wrist-down: `isLuminanceReduced` must tear down heroes and swap to the minimal AOD view (pattern: `aodMinimalView`, TrainingView.swift). No decorative animation may run in AOD.
- [ ] No idle animations outside an active workout screen (design-system anti-goal).
- [ ] All overlay chrome uses `.allowsHitTesting(false)`.

## Memory budget

- [ ] Watch extension budget is ~32 MB under workout. Decoding a multi-MB `sessions.json` during post-workout save (when HealthKit teardown + WCSession churn already peak) is the known kill window — keep per-operation allocations small, avoid whole-history decode/re-encode in hot paths.
- [ ] GPS sessions carry per-second `RoutePoint` arrays (230–275 KB per hour-long run) — never hold more than one full-route session in memory at a time during sync.

## Workout lifecycle survival

- [ ] HealthKit session must survive backgrounding (`workout-processing` background mode).
- [ ] Save workout data on pause AND stop; 15 s checkpoint backups must share the SAME session id as the final save so recovery dedup works.
- [ ] If the app is killed mid-workout, data must be recoverable from local storage on next launch; recovered sessions must not duplicate normally-saved ones (id-stable dedup).
- [ ] `clearBackup()` after a successful final save must be ordered so a kill between save and clear cannot resurrect a duplicate.

## Timer rules

- [ ] `DispatchSourceTimer`, never `Timer` — drift-proof, works with screen off.
- [ ] 40 pt monospaced timer font on watch (iOS uses 52 pt).
- [ ] Test with 30+ minute workouts including wrist-down periods.

## UI constraints

- [ ] 41 mm screen budget ~180 pt vertical for metric stacks — use `compactMetric` two-up rows for free-run layouts (see 2026-06-06 BPM visibility fix).
- [ ] Circular controls: green = pause, red = stop, min 44 pt touch targets.
- [ ] `MeshGradient` is iOS-only — watch uses `LinearGradient` fallback.
