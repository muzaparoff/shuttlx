# Stability + Design Plan — July 2026

Synthesis of a 5-agent review (swiftui-watchos-specialist, senior-architect, healthkit-domain-expert, design-reviewer, product-designer). Two tracks: (A) watch timer freeze / data loss, (B) design system.

## Track A — Timer freeze + unsavable sessions (watch)

### Root-cause verdict (3 independent investigations, convergent)

The freeze is not one bug — it is four confirmed defects that compound. All three agents independently confirmed the same core findings in code.

**A1. Interval countdown is tick-counted, not wall-clock — CONFIRMED (primary perceived freeze in interval mode)**
- `IntervalEngine.tick()` does `currentStepTimeRemaining -= 1` per *tick*, not per wall-second (`ShuttlX Watch App/Services/IntervalEngine.swift:46-69`), driven solely by the display `DispatchSourceTimer` (`WatchWorkoutManager.swift:659-692`).
- Dropped/suspended ticks are lost forever: countdown lags real time, and because completion gates on `engine.isComplete`, a stalled tick stream means the step never ends and auto-save never fires. Elapsed (wall-clock) self-heals; interval progression does not.
- Fix: `currentStepTimeRemaining = stepEndDate − now`. Timer becomes a pure render pulse.

**A2. App is deaf to HKWorkoutSession state changes — CONFIRMED (explains "can't stop / dead session")**
- `didChangeTo` is an empty switch (`WatchWorkoutManager.swift:1511-1520`); `didFailWithError` only writes a backup and continues (`:1522-1527`).
- If watchOS ends/stops the session (pressure, HK error), the app keeps showing a running timer on a dead session; `session.end()`/`finishWorkout()` then act on an already-ended session and can throw into `healthKitSaveError`.
- Fix: real `didChangeTo` handling (reflect `.paused`/`.running`; on `.stopped`/`.ended` finalize + checkpoint + surface state); `didFailWithError` must tear down cleanly.

**A3. Crash backup only written on pause; no `recoverActiveWorkoutSession()` — CONFIRMED (guarantees data loss)**
- `saveWorkoutDataToLocalStorage()` called only in `pauseWorkout()` (`:476`) and `didFailWithError` (`:1525`). A never-paused 30-min run has **zero** backup; `recoverCrashedWorkout()` returns nil.
- `HKHealthStore.recoverActiveWorkoutSession()` is never called → a killed frozen app orphans the live HK session; no HKWorkout is ever written to Health.
- Fix: periodic checkpoint every 15–30 s from the tick path (on background actor); call `recoverActiveWorkoutSession()` at launch and reattach/finalize.

**A4. Single-@MainActor saturation + synchronous O(history) persistence — CONFIRMED structure, PLAUSIBLE as trigger (explains why stop/save/UI die together)**
- `WatchWorkoutManager` is `@MainActor` (`:18`). Six sources (display timer, HR, calories, pedometer, motion, location) each hop via unstructured `Task { @MainActor }` with no coalescing (`:662`, `:1081`, `:1187`, `:949`, `:835`, `:1576`). Backlog grows under throttling; Stop tap queues behind it.
- `saveSessionToAppGroup` decodes/re-encodes the **entire** `sessions.json` synchronously on the main actor (`SharedDataManager.swift:293-339`); session encode incl. up to 2000 route points also on main actor (`WatchWorkoutManager.swift:1329-1358`). Save is itself a main-actor stall that grows with history.
- Fix: persistence off the main actor; coalesce sensor callbacks into one throttled 1 Hz snapshot; reentrancy-guard the tick.

**Secondary (confirmed, lower priority):** no `WKExtendedRuntimeSession` backstop (Info.plist has only `workout-processing`); 8-s auth timeout defaults `healthKitAuthorized = true` (`:222-225`); `updateApplicationContext` every 3 s adds baseline main-actor load.
**Ruled out:** WCSession retry stacking (single-flighted); unbounded data arrays (route points capped at 2000, O(1) accumulators); the stop code itself (non-blocking, correct order) — blocker is the frozen UI, not the save logic.

### Fix plan

**Phase 1 — data safety + timer correctness (do first, small diffs, watch target only)**
1. Wall-clock interval countdown (A1) — IntervalEngine + tick call site.
2. Periodic checkpoint every ~15–30 s + `recoverActiveWorkoutSession()` at launch (A3).
3. Implement `didChangeTo` / `didFailWithError` (A2).
4. Instrumentation: tick-heartbeat log, session-state transition log, MetricKit crash diagnostics — proves root cause on device and verifies fixes.

**Phase 2 — actor hygiene (removes the stall mechanism)**
5. Move `saveSessionToAppGroup` / `loadAllLocalSessions` / session encode off the main actor.
6. Coalesce six per-callback `@Published` writes into one throttled 1 Hz snapshot; tick reentrancy guard.
7. `WorkoutState` enum (idle/starting/running/paused/finishing/saving) replacing scattered flags — stop always drives finishing→saving regardless of render-pulse health.
8. Optional: `WKExtendedRuntimeSession` backstop; fix auth-timeout default to false.

**Phase 3 — "one app" consolidation (removes drift, ~1,000+ LOC)**
9. `ShuttlXShared` package **already exists** in `Package.swift` with a clean platform-agnostic `IntervalEngine` in `Shared/` — neither target consumes it. Wire it: models first (8 duplicated models; iOS/watch `TrainingSession.swift` have **already drifted**), engine second, themes last (24 duplicated files; highest risk — `#if os(watchOS)` font sizing, MeshGradient fallback).

## Track B — Design (both platforms)

### Quick wins (reuse existing components, no new design)
1. **iOS post-workout celebration screen** — `ThemedCompletionBadge` (all 7 themes) exists in `ShuttlX/Theme/ThemeAssets.swift:717-729` but is used only on watch. iOS finish flow just dismisses. Port the watch's summary treatment (incl. Mixtape "SIDE A COMPLETE").
2. **Fix Mixtape background leak (P0)** — `mixtapeBackground()` (`ThemeModifiers.swift:350-361`) draws the full cassette scene (J-card, hubs, screws, brand strip) behind every functional screen. Swap to calm tinted-navy ambient variant; full shell only on timer/completion. Copy FM Tuner's pattern (`ThemeModifiers.swift:465-469`). No other theme has this bug.
3. **Delete dead code** — VU Meter leftovers (`ThemeEffects.swift:29` `.meter`, `ThemeModifiers.swift:104-111,706-776`, unreachable `ThemePreset.warmAnalog` path) and the duplicate Mixtape static-reel system in `ThemedSceneBackground.swift:141-152` once hubs leave the ambient background.
4. **Font token fixes** — raw semantic fonts on themed surfaces: `iPhoneWorkoutTimerView.swift:539`, `PlanProgressCard.swift:30`, `IntervalResultsView.swift:68,80`; normalize `ThemedBarChart.swift` raw `.font(.system(size:))`.
5. **Spread the ThemedBarChart recipe** (per-theme Canvas + bespoke empty state — the app's best-executed pattern) to DashboardView hero and IntervalResultsView.

### Strategic (user decision required)
- **Cut 7 → 5 themes**: keep Clean, Synthwave, Mixtape, Neovim, Arcade; cut Classic Radio + FM Tuner (three variations of "vintage audio device with readout"; every theme is 2× files). Stretch: 4 (drop Arcade later). Full rationale: `design/proposals/app-design-strategy/strategy.md`.
- **"iPhone is the device, Watch is the readout"** contract: per theme, byte-identical signature shape, palette hex, timer typography, status vocabulary; everything else diverges natively.
- **Signature Gauge** flagship: one parametric Canvas per theme reused as timer hero / analytics chart / progress ring / empty state / summary medal on both devices; replaces stock Swift Charts on themed surfaces.
- **Reconcile Mixtape metaphor**: iOS has 84 pt physical spinning reels; watch deliberately cut reels for pure LCD. Decide one shared grammar.

### Open decisions (product calls)
1. Theme cut list — approve 7→5? (FM Tuner is recently built = sunk cost; Mixtape has emotional investment.)
2. 5 vs 4 themes long-term.
3. Mixtape direction: reels (iOS-style) or LCD-only (watch-style) as the shared grammar — also decides whether the Walkman photo-asset hunt (Concept A) is still needed.

## Recommended execution order
1. Track A Phase 1 (data safety — highest user harm today)
2. Track B quick wins 1–2 (completion screen + Mixtape leak — visible polish, cheap)
3. Track A Phase 2
4. Track B strategic (after theme-cut decision)
5. Track A Phase 3 (shared package)
