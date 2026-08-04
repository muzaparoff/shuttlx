# 2026-08-04 — Free-run timer stale first 5–7 min + first-cold-launch auto-stop

**Status: fixes implemented, builds green on both platforms. Root cause is a code-traced diagnosis — on-device confirmation still pending (see Verification).**

## Symptoms

1. During a free run, the in-app watch timer updated only once every couple of minutes — but only for the first 5–7 minutes of the session, then behaved.
2. On the first cold launch, the workout "stopped by itself" within ~1 minute; after a clean restart it worked. (Meanwhile the Smart Stack showed live time — that is the iOS Live Activity mirrored by the system, update-driven, unaffected by the watch app's main actor.)

## Diagnosis (unverified hypothesis, high confidence from code structure)

### A. 5–7 min stale timer — cold-launch sync storm + fragile tick path

- Every cold launch re-sent all last-24h sessions (`WatchSyncCoordinator` activation), while the phone simultaneously auto-pulled `requestAllSessions` — handled on the watch **main actor**, JSON-encoding every stored session (incl. GPS routes) there.
- A 15s retry timer re-queued duplicate `transferFile`/`transferUserInfo` items unconditionally (no in-flight check), re-decoding the full store and firing `WidgetCenter.reloadAllTimelines()` per retry even on dedup no-ops.
- The live-metrics broadcast (`sendMessage` + `updateApplicationContext` — synchronous XPC to wcd) ran **inside the display-timer tick** on the main actor; a saturated wcd outbox stalled the tick directly.
- The display timer ran at `.utility` QoS (regression in 4f8d049 S-6) with a tick-dropping reentrancy guard — converting intermittent pressure into multi-minute clock stalls. `elapsedTime` is wall-clock-derived, so it "jumped" on recovery.
- Side defect: the pace window pruned on `elapsedTime`, so a frozen clock grew `paceWindowSamples` unbounded (positive feedback).
- All ends of the chain resolve together when the WC queue drains (~minutes over BT) → the 5–7 min window.

### B. First-cold-launch auto-stop — orphan-recovery race (top candidate)

- `recoverOrphanedHKSession()` ran fire-and-forget at launch; a fast workout start (complication deep-link) raced it. The RC-2 guard then *ignored* the orphaned HK session, leaving it lodged alongside the new session — the system ends one of them → `didChangeTo .stopped` → auto save+stop ~1 min in. Self-sustaining: each death leaves the next orphan.
- Secondary candidates: jetsam kill at the launch memory peak (storm + workout sensors); 8s HealthKit auth timeout defaulting to `authorized: true` (first-ever launch only; known defect from the 2026-07 stability plan, never applied).

## Fixes applied (2026-08-04, uncommitted)

Watch (`ShuttlX Watch App/`):
- `WatchSyncCoordinator`: in-flight transfer guard (`inFlightSessionIDs`, reconciled from WCSession outstanding transfers at activation); removed the unconditional 24h resend at activation; `requestAllSessions`/`reconcileSessions` encoding moved off the main actor; widget timeline reload only on actual store insert.
- `LiveMetricsBroadcaster`: WC calls moved to a serial background queue (out of the tick path); applicationContext failure log → `.warning`; new `>250ms` slow-call warning (confirmation instrumentation).
- `WatchWorkoutManager`: tick QoS `.utility` → `.userInitiated`; new `@Published timerReferenceDate` (wall-clock basis, pause-aware); pace window keyed on wall clock.
- `TrainingView+Metrics` / `MixtapeTimerHero`: free-run + AOD + Mixtape hero clocks now render via `Text(timerInterval:)` (system-ticking, AOD-safe, immune to main-actor stalls); static text while paused. Format note: no leading zero (`5:23`), Mixtape >1h renders `1:08:45`.
- First-launch: workout start now awaits `launchRecoveryTask` (orphan recovery serialized ahead of any new session, 5s recovery timeout); HealthKit auth timeout 8s→30s and defaults to **not** authorized with a user-visible error banner.

iOS (`ShuttlX/`, `ShuttlXLiveActivity/`):
- `PhoneSyncCoordinator`: auto-pull debounced to once per 5 min and skipped while `isWorkoutActiveOnWatch`; manual Sync Now unaffected.
- Live Activity: `ContentState.timerReferenceDate` added; lock screen + Dynamic Island timers now use `Text(timerInterval:)` (true 1s ticking instead of 3s update jumps), static while paused.

## Addendum — 1h+ display truncations (user screenshot, 2026-08-04 run on old build)

At 1h27 the TIME row showed `1:27…`. Root cause **runtime-confirmed in simulator**: `Text(timerInterval:)` content is advanced by the render server, so `minimumScaleFactor` is ignored and the text truncates instead of scaling (the old static-string path could also truncate at its 0.6 floor). Fix: solve the fitting point size up front from glyph count (5/7/8 for mm:ss / h:mm:ss / 10h+) and available width — `ElapsedTimerText` + Mixtape hero (ghost now `8:88:88` at 1h+). Same fitted-size treatment applied to the 40mm HR digits (`1…` defect); HR alert banner copy tightened to "Ease off — HR high" (full sentence kept in a11y label) after a 2-line wrap displaced the bottom row on 40mm; interval compact DIST drops the `km` unit (precedent: paceText drops `/KM`), VoiceOver unchanged. All verified via simulator screenshots at 1h27m on 40mm + 46mm, free-run + interval, Clean + Mixtape; sub-1h rendering unchanged. DEBUG snapshot harness added (`SHUTTLX_SNAPSHOT_ELAPSED`/`SHUTTLX_SNAPSHOT_AOD` env vars) for reproducing timed states.

## Verification (pending)

On-device cold-launch free run, Console filtered to `shuttlx` (capture recipe was delivered 2026-08-04):
- No `"Tick gap …"` warnings clustering in minutes 0–7; `"Retrying N pending sessions"` stops quickly.
- `"Live metrics applicationContext slow: <n>ms"` present pre-fix conditions would confirm the wcd backpressure mechanism.
- `"Launch recovery complete"` precedes session start on a complication-tap start; workout survives past minute 1.
- Known residual: if wcd drops a transfer without `didFinish` while the app stays alive, the in-flight claim holds until next launch (reconciler corrects it). Add a staleness timeout if seen in the field.
