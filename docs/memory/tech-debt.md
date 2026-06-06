# Technical Debt & Known Issues

## Code Quality
- [ ] Package.swift declares `ShuttlXShared` but `Shared/` dir doesn't exist — remove or implement
- [ ] Models duplicated between targets — consider SPM shared package
- [ ] Debug views (SyncDebugView, DebugView) should be `#if DEBUG` gated
- [ ] `print()` statements should use `os.log` / `Logger`
- [ ] CloudKit sync: no push-triggered sync, no conflict resolution UI (just newest-wins)

## Safety
- [ ] Some `try?` silent failures in JSON encode/decode — should use `do/catch` with logging
- [ ] Session deduplication by UUID only — consider timestamp-based dedup

## Partial Implementations
- [ ] Multi-Sport: 8 sport types in model, but only run/walk have dedicated sensor stacks (CMPedometer + CMMotionActivity). Cycling/swimming/hiking record HR+calories only.
- [x] ~~Cadence: CMPedometer captures step count, but steps-per-minute not computed or displayed~~ — FIXED 2026-05-23. Both `WatchWorkoutManager.startPedometerUpdates` and `iPhoneWorkoutController.startPedometer` now fall back to a step-delta derivation over a ≥3s window when `CMPedometer.currentCadence` is nil (frequent during the first 30-60s of a workout + always nil in the simulator). Apple's instantaneous cadence still takes precedence when available. Display gates relaxed to render "—" when zero instead of hiding the CAD card entirely (avoids layout pop-in).
- [x] ~~Pace: Cumulative average locked at 10'00 due to CMPedometer warmup lag~~ — FIXED 2026-06-06. Both targets now compute pace from sliding 30s window with guards (≥20s into workout, ≥0.05km moved, ≥5s + ≥5m in window). Avoids warmup spike artifact entirely. See `docs/incidents/2026-06-06-pace-10min.md`.
- [ ] Training Plans: plan days reference template names by string, not UUID — no direct Watch launch from plan
- [ ] Custom Fonts: 7-segment (Arcade) & pixel (some themes) use system monospaced as fallback — OFL fonts not bundled
- [ ] BPM visibility in free-run walk/run: FIXED 2026-06-06 by converting DIST/PACE/CAD to compactMetric two-up rows (frees ~30pt on 41mm screen). Watch layout budget is ~180pt; full-size rows overflow. Layout lesson: track metric row heights when designing watch UIs.

## Fixed Issues (for reference)
- [x] Watch-iPhone sync: isReachable guard removed, retries added (Build 19)
- [x] Watch UI: timer enlarged to 52pt, circular controls (Build 20)
- [x] Custom interval workouts: full implementation (Build 21)
- [x] PrivacyInfo.xcprivacy added for both targets
- [x] Version mismatch fixed (iOS + watchOS aligned)
- [x] NSAllowsArbitraryLoads removed from watchOS
- [x] Force unwraps replaced with safe patterns
- [x] @unchecked Sendable replaced with @MainActor
- [x] HealthKit background delivery entitlement added to watchOS
- [x] Deprecated Alert API replaced
- [x] Theme switching: stored `current` property + `selectTheme()` method (Build 29)
- [x] Per-theme timer heroes: 6 themes now render unique hero visualizations (Synthwave speedometer, Mixtape reels, Arcade 7-segment, Classic Radio tuning needle, VU Meter gauges, Neovim command line) on both iOS and watchOS (Build 34)
