# Dynamic Run+Walk Sessions — Phased Plan (August 2026)

Follow-up to the 2026-08-17 feasibility research (codebase audit + Apple API research, two-agent investigation). Full sourced writeup: artifact `93d1ab85-092e-4032-96b1-426f9aee175e` ("Run+Walk Feasibility"). This doc turns that research into an implementation plan.

**Status: all 4 phases implemented 2026-08-17, both platforms build clean, 49/49 SPM tests pass.** See "Implementation notes" at the end of this doc for what shipped vs. what was deliberately scaled back.

## Goal, reframed

Original ask: a run+walk session that dynamically recognizes walk vs. run phases and attributes calories per phase using personal health data — and have Apple Fitness reflect that.

**Confirmed hard platform limit (do not pursue):** Apple Fitness cannot display a single workout as walk+run phases. HealthKit forbids mixing activity types within one workout outside `.swimBikeRun` (walking isn't even a valid leg there), and Fitness does not render third-party `HKWorkoutEvent(.segment)` markers — confirmed via Apple's own "Dividing a HealthKit workout into activities" doc and multiple unanswered developer-forum reports since 2022. No competitor (Runkeeper, Galloway Run-Walk-Run, WorkOutDoors, Runna) has ever achieved it either. **Drop "Fitness shows the phases" as a success criterion.**

**Confirmed achievable (this plan):** live detection, per-phase personal calorie attribution, and a phase-aware story — all inside ShuttlX, all with public APIs. Since Fitness's blindness here is permanent and universal, this becomes a durable product differentiator rather than a workaround.

## Current-state audit (codebase evidence)

Roughly half-built. What exists and works:
- Live `CMMotionActivity` classification with 5s debounce (`WatchWorkoutManager.swift:897-934`), segments stored on `TrainingSession` (`Shared/ActivitySegment.swift`), synced watch→phone intact, and shown in `SessionDetailView`'s timeline + route-map coloring.

What's missing or broken:
- **CE1 — Single weak detection signal.** Only `CMMotionActivity.running/.walking/.stationary` booleans are read; `confidence` is ignored, and cadence (`WatchWorkoutManager.swift:1011-1044`) + pace (`:1049-1078`) + HR are already computed for display but never feed classification.
- **CE2 — Segment hygiene bugs.** First segment always seeded `.unknown` (`:353`); resume-from-pause reopens a segment carrying the stale pre-pause activity (`:523`); no minimum-length filter, so a single 5s classifier blip persists as a segment; `ActivitySegment.steps`/`.distance` fields exist but are never populated on any code path.
- **CE3 — Calorie engine is dead code.** `CalorieEstimationEngine` (MET × weight × HR-adjustment, `ShuttlX/Services/CalorieEstimationEngine.swift`) has zero call sites repo-wide. `TrainingSession.estimatedCalories` is declared but never written or read.
- **CE4 — No personal anthropometrics.** `bodyMass`/`biologicalSex`/`height` are never requested from HealthKit (`HealthKitAuthService.swift:88-105`); the dead engine would silently default to 70kg if it were called.
- **CE5 — Calories are Apple's, under a running model throughout.** The watch just sums Apple's own `activeEnergyBurned` samples (`:1221-1283`) for a session configured `.running` end-to-end — walk phases included. No per-segment energy anywhere.
- **CE6 — HealthKit learns nothing about phases.** No `HKWorkoutActivity` sub-activities, no `.segment`/`.marker` events, no phase metadata beyond `templateName`/`intervalCount`.
- **CE7 — Interval plan and detected phases are never reconciled.** `IntervalEngine` knows the exact RUN/WALK step boundaries from the template; `segments` is built solely from motion detection, independently, so they can disagree.
- **CE8 — No aggregate surfacing.** `AnalyticsView.swift` never reads `segments`; run-vs-walk totals appear only on the single session-detail screen, never in trends/weekly views.

## Phase 1 — Harden detection (watch target)

Fix the signal and the hygiene bugs before building anything on top of them.

1. Fuse cadence + pace + `CMMotionActivity.confidence` into classification instead of the raw boolean alone (community cadence threshold ~130–140 spm as the run/walk discriminator); gate transitions on confidence ≥ `.medium`.
2. For interval-mode sessions, reconcile detected phases against the known `IntervalEngine` RUN/WALK step schedule (CE7) — the plan is ground truth when available; motion detection is authoritative only for free runs.
3. Fix hygiene bugs (CE2): seed the first segment from the first confident classification instead of `.unknown`; carry the correct (not stale) activity across pause/resume; add a minimum segment length filter (e.g. merge segments < 10s into their neighbor); populate `steps`/`distance` per segment from `CMPedometer` deltas.
4. Instrumentation: log classification confidence + cadence at each transition, to verify Phase 1 on-device before Phase 2 builds on it.

## Phase 2 — Per-phase personal calories

5. Request `bodyMass`, `biologicalSex`, and existing `dateOfBirth` read scopes (CE4); read them once per session start with sane fallbacks (not a silent 70kg default — surface "add your weight in Health for accurate calories" if missing).
6. Wire `CalorieEstimationEngine` in (CE3): call it per closed segment (duration + segment-average HR + real anthropometrics) as ShuttlX's own estimate.
7. Compute the platform-native per-phase number in parallel: sum Apple's `activeEnergyBurned` samples over each segment's timestamp range (CE5) — free, since energy samples already arrive personally-calibrated from HR + motion.
8. On-device validation (open empirical question from the research): log identical walk intervals under `.walking` vs `.running` configuration to measure the actual running-model bias on calories; use this to decide whether ShuttlX's MET estimate or Apple's segment-summed estimate is presented as primary, or both side-by-side.

## Phase 3 — HealthKit interoperability (optional, low priority)

9. Add same-type `HKWorkoutActivity` intervals via `beginNewActivity` (valid since they share `.running`) for per-interval `statistics(for:)` — enables other HealthKit-reading apps to see interval structure even though Fitness itself won't render it.
10. Add `HKWorkoutEvent(.segment)` markers at phase transitions and phase metadata (walk/run split, per-phase calories) for interop / future export, accepting Fitness won't display them.
11. Keep `.running` as the Fitness-facing `HKWorkoutActivityType` — confirmed as the least-bad choice; `.mixedCardio` is more honest but loses Fitness's route/pace/splits treatment.

## Phase 4 — Surface it in-app

12. Run/walk aggregates in `AnalyticsView` (CE8): weekly walk-vs-run time and calorie split, trend over time.
13. Session-detail phase story: per-phase calories (ShuttlX estimate vs. Apple's), not just per-phase duration as today.
14. Consider this the pitch surface for why ShuttlX's tracking is more honest than Apple Fitness — the differentiator the research identified.

## Sequencing notes

- Each phase is independently shippable; Phase 1 gates Phase 2's accuracy but nothing blocks on Apple.
- No phase requires new external dependencies or entitlements beyond additional HealthKit read scopes (`bodyMass`, `biologicalSex`) already coverable by the existing `com.shuttlx.ShuttlX` HealthKit capability.
- Route to `swiftui-watchos-specialist` for Phases 1 and 2 (watch-primary), `senior-ios-developer` for Phase 4 (iOS analytics), either for Phase 3 given it's low-priority interop plumbing.
- Per CLAUDE.md discipline: Phase 1's confidence/cadence fusion and Phase 2's calorie-bias measurement are runtime-verifiable claims — treat pre-implementation reasoning as hypothesis, confirm via the instrumentation this plan adds before declaring "fixed."

## Implementation notes (2026-08-17)

**Phase 1** — new `ActivityClassifier.swift` + `SegmentHygiene.swift` (watch). Confidence gate (drops `.low`), cadence corroboration (130/140 spm band), interval mode trusts the plan exclusively (motion only logged for disagreement), sub-10s segments absorbed backwards into their predecessor then coalesced. Verified by compiling the two pure files standalone and tracing concrete event sequences (shown in the implementing agent's report), not just build success — matches the repo's root-cause-verification rule since classifier behavior can't be screenshot-tested.

**Phase 2** — `CalorieEstimationEngine` moved from dead iOS-only code into `Shared/` (the watch needs it in-session); new `SegmentMetricsLedger` reconstructs per-segment HR/energy from timestamped samples the old running-accumulator pattern discarded. Every closed segment now carries both `estimatedCalories` (ShuttlX MET estimate, real body mass/age/HR) and `activeEnergyCalories` (Apple's own sum for that time window) — Apple's is primary for display, ShuttlX's is the honesty check. `SEG KCAL` log lines exist specifically to let a real device run measure the walk-under-running bias the original research flagged as unmeasured. No weight on file → `nil`, never a silent 70kg default; watch summary shows a one-line Health-app prompt instead.

**Phase 3** — deliberately did NOT use `HKWorkoutSession.beginNewActivity` for live sub-activities: watchOS SDK headers document it re-arms sensor algorithms on every call (would perturb the HR/energy stream Phase 2 depends on) and its only failure signal is the session delegate, which this codebase treats as fatal. Used `HKLiveWorkoutBuilder.addWorkoutActivity`/`.addWorkoutEvents(.segment)` with fully-closed intervals instead, written once at finalization from the already-hygiene-passed segment timeline — same interop value (per-phase `statistics(for:)` for other HealthKit readers), none of the live-session risk. Phase metadata (walk/run seconds + both calorie totals, JSON-encoded, `com.shuttlx.`-namespaced) attached alongside the existing mandatory metadata call, isolated so a rejected key can't cost the user their workout. `.running` stays the Fitness-facing type, unchanged, confirmed in the report.

**Phase 4** — `AnalyticsView` gained a run/walk split card (duration + calories, 6-week trend) built from Phase 2's `TrainingSession` rollups, not raw segments. `SessionDetailView`'s existing duration-only aggregate now also shows calories (Apple's primary, ShuttlX's as a secondary caption only when it diverges ≥5 kcal from Apple's, to avoid cluttering the common case). Caught and fixed a real defect during its own screenshot verification: raw `.foregroundStyle(.secondary)` was nearly invisible against Mixtape's LCD palette — switched to the `ShuttlXColor` bridge. All new UI is nil-safe against pre-Phase-2 sessions and empty-segment (`iPhoneWorkoutController`-originated) sessions.

**Known gaps, accepted:** manual weight entered in iOS Settings doesn't sync to the watch (separate feature); `beginNewActivity`'s true on-device behavior and whether Fitness renders anything unexpected for the added activities are unverified (device-only, degrade gracefully either way); the walk-vs-running calorie bias itself is still an open number pending a real paired recording.
