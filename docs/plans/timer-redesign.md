# Plan — Timer Redesign + Watch/iOS Unification

**Status:** Phase 0 in progress (2026-06-06)
**Lead:** project-manager
**Driving feedback:** "design of timers terrible and looks more AI generic — nothing special between each themes except color of fonts" + "BPM isn't showing up in walk/run on watch"

## Context

After a year of iterative fixes, two structural issues remain:

1. **Watch walk/run HR is invisible** — root cause is layout overflow in `TrainingView.fullWorkoutDisplayTab` free-run branch (5 large rows totaling ~210pt on a ~180pt watch screen), pushing HR off-screen. Not a HealthKit bug.
2. **7 of 8 themes look identical** — only colors and fonts change. Theme-specific decorations (`VUGaugeHeader`, `RadioDialHeader`, `TerminalStatusLine`) already exist in `ThemeModifiers.swift` but the timer never invokes them. FM Tuner is the only theme with structural chrome.

A third initiative is folded into this plan:

3. **Watch + iOS unification** — models and theme files are duplicated between targets per `.claude/rules/models.md`. Scoped as Phase 5 below — sized as a separate sprint.

## Phases

### Phase 0 — P0 BPM fix (2026-06-06)
- **Owner:** lead session (no agent needed — single 12-line edit)
- **File scope:** `ShuttlX Watch App/Views/TrainingView.swift:275-287`
- **Change:** convert free-run DIST/PACE/CAD from full-size `metricRow` to `compactMetric` two-up rows
- **Exit criteria:** watch build passes; HR row visible on 41mm simulator
- **Status:** DONE — committed in this push

### Phase 1 — Watch-sized design specs (~1 day)
- **Owner:** `product-designer` (continue session id from prior research turn)
- **Input:** 6 iPhone-sized mockups already saved in `design/proposals/timer-theme-redesigns/`
- **Output:** sibling `watch.md` per theme — adapted for 41mm/45mm constraints (max 5 visible elements, glanceability, no horizontal Canvas hero, 16-24pt minimum text)
- **Exit criteria:** 6 `watch.md` files merged into the same directory
- **Status:** TODO

### Phase 2 — Theme-aware hero primitive (~½ day)
- **Owner:** `senior-ios-developer` solo (architectural primitive — no parallelism)
- **File scope:** `iPhoneWorkoutTimerView.heroSection`, `TrainingView.fullWorkoutDisplayTab`
- **Change:** introduce a `themedHero { ... }` modifier or switch (model on existing FM Tuner `if themeManager.current.id == "fmtuner"` branch). One reusable wrapper, one switch table.
- **Exit criteria:** Clean + FM Tuner still render correctly; Synthwave/Mixtape/Arcade/Classic Radio/VU Meter/Neovim render placeholder hero with theme id label so we can verify the wiring before filling in real heroes
- **Status:** TODO

### Phase 3 — Per-theme implementation (parallel team, ~3 days)
**Playbook T5.** Two waves, three themes per wave. Per wave: `senior-ios-developer` (iOS) + `swiftui-watchos-specialist` (watch) work in parallel on different themes — each theme owns its own `Theme/<Name>Hero.swift` file so no two agents touch the same file in a wave.

Wave 1:
- Synthwave (Outrun speedometer + scrolling grid)
- Mixtape (twin cassette reels + LCD tape counter)
- Arcade (7-segment HI-SCORE + INSERT COIN paused)

Wave 2:
- Classic Radio (horizontal tuning dial with sweeping needle)
- VU Meter (analog needle gauges driven by HR)
- Neovim (modal `:command` status line + line-number gutter)

Each wave ends with `/push` for incremental TestFlight builds.

**Status:** TODO

### Phase 4 — QA + docs (~½ day)
- `qa-engineer` walks all 6 redesigned timers on both simulators
- `docs-keeper` updates CLAUDE.md theme table, `.claude/rules/design-system.md`, `memory/`
- **Status:** TODO

### Phase 5 — Watch + iOS unification (separate sprint after Phase 4)
**Goal:** stop duplicating models + theme files between targets.

- **Approach:** activate the existing `ShuttlXShared` SPM declaration in `Package.swift` (currently declared but `Shared/` directory missing per `tech-debt.md`). Move models + theme structs + theme color/font/effect bridges into the package, delete duplicates.
- **Scope:**
  - Models: 8 shared files (ActivitySegment, BuiltInPlans, RoutePoint, TrainingPlan, TrainingSession, WorkoutSport, WorkoutTemplate, ExerciseDevice) — move to `Shared/Sources/ShuttlXShared/Models/`
  - Theme structs: `AppTheme`, `ThemeColors`, `ThemeFonts`, `ThemeEffects`, `ThemeManager` — move to `Shared/Sources/ShuttlXShared/Theme/`
  - Theme files (Clean, Synthwave, Mixtape, Arcade, ClassicRadio, VUMeter, Neovim, FMTuner) — move to shared package
  - Per-platform view modifiers stay per-target (because `MeshGradient` is iOS-only, `WKInterfaceDevice` is watchOS-only)
- **Team:** `swift-architect` (designs package boundaries) -> `senior-ios-developer` solo (executes move, iOS imports) -> `swiftui-watchos-specialist` solo (watch imports). Sequential, NOT parallel — every file gets touched.
- **Risk:** medium. The build system needs `ShuttlXShared` linked into 4 targets (iOS app, watch app, Live Activity, widgets). Mitigation: do model unification first (lowest risk), then theme.
- **Effort:** ~2-3 days
- **Status:** SCOPED, not started. Approval required before kick-off.

## Verification

After each phase:
```bash
bash tests/build_and_test_both_platforms.sh --clean --build
```

Before pushing each wave: build both schemes individually and run `/payment-check` for iOS.

## What Does NOT change

- Workout state machines, HealthKit sessions, sync, timers — untouched
- The `WatchWorkoutManager` / `iPhoneWorkoutController` public surface — untouched
- Existing user data on device — untouched (JSON formats unchanged)
- Phases 0-4 do NOT touch the SPM structure. Phase 5 is opt-in.
