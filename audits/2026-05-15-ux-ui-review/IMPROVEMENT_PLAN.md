# ShuttlX Improvement Plan — 2026-05-15

Synthesized from 4 parallel audits:
- [`product-designer.md`](./product-designer.md) — UX/UI beauty + glanceability
- [`design-reviewer.md`](./design-reviewer.md) — design-system + HIG compliance (87 violations)
- [`app-auditor.md`](./app-auditor.md) — crash risks + logic bugs (4 P0, 6 P1, 8 P2)
- [`senior-architect.md`](./senior-architect.md) — architecture, code cleanliness, tech debt

---

## TL;DR

**Headline state**: the app is shippable but carries 4 latent P0 crash/data-loss bugs and ~87 design-system violations. The architecture has one major god-object (`WatchWorkoutManager` at 1,358 LOC) and proven drift between "duplicated" iOS/watchOS files. Zero tests.

**Highest-ROI sequence** (rough order of attack):
1. **Today (P0 patch)**: 4 crash fixes (1-3 hours total) — must ship before next TestFlight build
2. **This week (cleanup)**: watch `RecoveryWorkoutView` + `TrainingView` design-system pass — fixes ~35 of 87 violations in 2 files
3. **Next week (UX)**: top-5 UX changes from product-designer
4. **This month (architecture)**: shared SPM target (`Shared/`) for models + theme primitives → kill the drift
5. **Within 2 months (refactor)**: split `WatchWorkoutManager` into 4 facade services + bootstrap XCTest target

---

## Top 10 Highest-Impact Fixes (cross-audit)

| # | Fix | Severity | Effort | Owner | File reference |
|---|---|---|---|---|---|
| 1 | Clear `active_workout_backup.json` in `stopWorkout()` — fixes the false-recovery-of-discarded-workouts bug | P0 | S | swiftui-watchos-specialist | `ShuttlX Watch App/Services/WatchWorkoutManager.swift:486` |
| 2 | Remove force-unwrap on `completedIntervals!` in TelemetryDeck call | P0 | S | senior-ios-developer | `ShuttlX/Services/DataManager.swift:82` |
| 3 | Reset `isStarting` in deallocated-self path (defer-reset pattern) | P0 | S | swiftui-watchos-specialist | `ShuttlX Watch App/Services/WatchWorkoutManager.swift:247` |
| 4 | Replace `lastFullResendTime!` force-unwrap with `.map`/`??` pattern | P0 | S | swiftui-watchos-specialist | `ShuttlX Watch App/Services/SharedDataManager.swift:366` |
| 5 | Promote watch interval countdown to hero size + step-color tint (glanceability) | P0 (UX) | M | swiftui-watchos-specialist | `ShuttlX Watch App/Views/TrainingView.swift:262-326` |
| 6 | Replace 7 hardcoded colors in `RecoveryWorkoutView` with `ShuttlXColor.*` tokens | P0 (design) | S | swiftui-watchos-specialist | `RecoveryWorkoutView.swift:39,43,169,243,248,252` |
| 7 | Replace 28 raw `.font(.system(size:))` calls in watch `TrainingView` + `RecoveryWorkoutView` with `ShuttlXFont.*` | P0 (design) | M | swiftui-watchos-specialist | watch view files |
| 8 | Add `.themedScreenBackground()` to `DevicePickerView` + `HealthPermissionsInfoView` | P0 (design) | S | senior-ios-developer | `DevicePickerView.swift:66`, `SettingsView.swift:597` |
| 9 | Fix retry storm in `scheduleFinishRetryBurst` with `isBurstScheduled` flag | P1 | S | swiftui-watchos-specialist | `ShuttlX Watch App/Services/SharedDataManager.swift:150-157` |
| 10 | Surface `currentCadence` (already collected) in broadcast + history + watch TrainingView | P1 (feature) | M | swiftui-watchos-specialist + senior-ios-developer | `WatchWorkoutManager.swift:843`, `TrainingView.swift`, `TrainingSession.swift` |

Effort scale: **S** (≤2h), **M** (½–1 day), **L** (multi-day).

---

## By Severity

### P0 — Must fix before next ship (4 crash/data-loss + 9 design ship-blockers + 1 UX glanceability)

**Crash / data risk (app-auditor)**
- `completedIntervals!` force-unwrap → DataManager.swift:82
- Discarded workout falsely recovered → WatchWorkoutManager.swift:486
- `isStarting` spinner can lock → WatchWorkoutManager.swift:247
- `lastFullResendTime!` force-unwrap → SharedDataManager.swift:366

**Design ship-blockers (design-reviewer)**
- 7 hardcoded colors in `RecoveryWorkoutView` (DS-01..DS-07)
- 28 raw `.font(.system(size:))` in watch views (W-01)
- Missing `.themedScreenBackground()` on `DevicePickerView` (H-01)
- Missing `.themedScreenBackground()` on `HealthPermissionsInfoView` (H-02)
- Hardcoded `.white` map marker background (H-03)

**UX glanceability ship-blocker (product-designer)**
- Watch interval countdown fails the "readable mid-treadmill at an angle" test — currently smaller than DIST/HR/PACE; needs to be the largest element with step-type color filling the periphery

### P1 — Should fix soon

**Logic / behavior (app-auditor)**
- `replyHandler` deferred-Task pattern can cause WC delivery timeouts (P1-1)
- `SyncMonitor` mis-isolates actor (P1-2)
- Retry storm in burst scheduler (P1-3)
- CloudKit completion off-main (P1-4)
- DataManager redundant first-load merge (P1-5)
- `AnalyticsEngine.fitnessScore` index can overflow (P1-6)

**Design (design-reviewer)**
- ~52 semantic font tokens bypass `ShuttlXFont.*` across iOS views (DS-08)
- `.caption2` everywhere with no `ShuttlXFont` equivalent (DS-09) — add `chartCaption` token
- 4 cards bypass `.themedCard()` — `LiveWorkoutCard`, recovery card in AnalyticsView, PRCard, watch `MetricCard` (DS-10..13)
- Deprecated `.foregroundColor(.accentColor)` in 2 places (H-04)
- 6 missing accessibility labels/hints (A-01..A-05)
- Watch `RecoveryWorkoutView.restView` doesn't scroll on 40mm (W-02)
- No haptic on interval work↔rest transitions (W-04)

**UX (product-designer — full list in `product-designer.md`)** — per-screen improvements for Dashboard, Analytics, Workout flows, etc.

### P2 — Polish / nice-to-have

- 11 polish items in design-reviewer (DS-15..20, H-07..H-09, A-06..A-07, TP-01)
- 8 P2 items in app-auditor (version hardcoding in Info.plist, HK background-delivery entitlement, temp-file cleanup, etc.)

---

## Missing Features (already designed/discussed, never finished)

| Feature | State today | Effort |
|---|---|---|
| **Cadence (SPM) display** | Sensor data collected via `CMPedometer.currentCadence` and immediately discarded — never broadcast, never saved, never displayed | 2-3h |
| **RevenueCat `.enforced` entitlement check** | `.informational` only; TODO marks for future | 0 until RC ships it |
| **CloudKit sync progress UI** | Initial-migration spinner has no progress indication for 200+ session uploads | 3-4h |
| **iOS UI tests** | None exist | half-day to bootstrap |
| **watchOS UI tests** | None exist | half-day |

---

## Architectural Concerns (senior-architect)

### 1. `WatchWorkoutManager` is a 1,358-LOC god-object on the most critical code path
One `@MainActor` class owns: HK session lifecycle, two anchored HR/calorie queries, location, motion, pedometer, the display timer, activity debouncing, KM splits, interval engine driver, recovery segmenter driver, crash backup, route builder finalization, dual-channel WC broadcast. ~25 `@Published` props. 25-line `stopWorkout()` that resets state by hand — future changes will miss a reset.

**Proposed refactor** (medium effort): same facade externally; internally split into 4 focused services:
- `WorkoutSessionLifecycle` (HK session start/pause/resume/stop, backup, recovery)
- `HealthKitMetricsBridge` (HR/calorie anchored queries, sample processing)
- `SensorAggregator` (location, motion, pedometer, KM splits)
- `LiveMetricsBroadcaster` (dual-channel WC, includes burst scheduler from SharedDataManager)

`IntervalEngine` and `RecoverySegmenter` are already separated correctly.

### 2. iOS↔watchOS file duplication has already drifted

Verified via `diff`:
- `TrainingSession.swift` — doc-comment drift
- `ThemeAssets.swift` — 81-line diff. Watch variant uses raw `Color.yellow/.cyan/.pink` where iOS uses theme tokens — a theme regression survives only on watch
- `ThemeModifiers.swift` — 177-line diff

The "update both copies" rule is not holding. Root cause: nothing prevents it.

**Proposed fix** (low effort, high ROI): the repo root `Package.swift` already declares an empty `Shared/` SPM target. Fill it with:
- All 8 shared models (`TrainingSession`, `WorkoutTemplate`, `BuiltInPlans`, `ActivitySegment`, `RoutePoint`, `TrainingPlan`, `WorkoutSport`, `ExerciseDevice`)
- Theme primitives (`AppTheme`, `ThemeColors`, `ThemeFonts`, `ThemeEffects` structs — but NOT `ThemeManager` since SwiftUI `@Observable` is target-specific)
- Pure logic (`RecoverySegmenter`, `IntervalEngine`, calorie helpers)

Delete the watch copies. Drift becomes impossible by construction.

### 3. Zero tests despite a test-friendly architecture

`RecoverySegmenter` is a pure value type, `IntervalEngine` is `@MainActor` but trivially driveable, `AnalyticsEngine` is explicitly pure, `TrainingSession` Codable roundtrips are easy fixtures. The `Package.swift` even references a `Tests/` path that doesn't exist. The `tests/` directory contains 4 dead scratch scripts.

**Proposed scaffold** (half-day):
- Create `ShuttlXTests/` target in Xcode (use Swift Testing macros where available)
- 10 starter tests: `RecoverySegmenterTests`, `IntervalEngineTests`, `TrainingSessionRoundtripTests`, `CalorieEstimationEngineTests`
- Wire into CI so any regression fails the merge

This is a prerequisite for safely doing concerns #1 and #2.

---

## Suggested Execution Plan

### Sprint 1 (this week) — P0 fixes + watch design pass

Single team (parallel where file-scoped):

**Team prompt**:
> Spawn a 3-teammate team to ship Sprint 1: `swiftui-watchos-specialist` (owns all 4 watch fixes #1, #3, #4, #6, #7 + adds haptics on transitions), `senior-ios-developer` (owns iOS fix #2 + theme bg fixes #8), `qa-engineer` (verifies all 4 P0 reproductions can no longer trip).

Deliverable: TestFlight build that closes the 4 P0 crash paths and removes the visible theme breaks on the gym recovery and watch training screens.

### Sprint 2 (next week) — UX glanceability + missing features

> Phase 1: `product-designer` writes `design/proposals/2026-05-22-watch-glanceability/` with mockups for the interval countdown hero (#5) and the cadence display rollout (#10).
> Phase 2: 2-teammate team — `swiftui-watchos-specialist` (watch implementation) + `senior-ios-developer` (cadence in `TrainingSession` model + iOS history display).

### Sprint 3 (week after) — design-system completion

> 1-teammate sweep by `senior-ios-developer`: replace all 52+ semantic Apple font tokens with `ShuttlXFont.*`; add `ShuttlXFont.chartCaption`; migrate the 4 manual-card sites to `.themedCard()`; add the 6 missing a11y labels/hints. Single PR.

### Sprint 4 (architecture month) — shared package + test bootstrap

> Two PRs by `senior-architect` (implementation):
> 1. Move shared models + theme primitives to the `Shared/` SPM target; delete watch copies; resolve any drift forward to iOS canonical.
> 2. Create the `ShuttlXTests/` target with 10 starter tests.

### Sprint 5 (refactor) — split `WatchWorkoutManager`

> 1-teammate refactor by `swiftui-watchos-specialist` on a feature branch with comprehensive tests in place from Sprint 4. Split into 4 facade services. No behavior changes, only structural.

---

## Numbers at a Glance

| Audit | Findings | P0 | P1 | P2 |
|---|---|---|---|---|
| design-reviewer | 87 | 11 | ~30 | ~46 |
| app-auditor | 18 + 3 dead | 4 | 6 | 8 |
| product-designer | ~25 per-screen | (counted in design) | (counted in design) | (counted in design) |
| senior-architect | 3 major + 1 TODO inventory | 1 | 2 | rest |

**~120 distinct improvement items.** ~15 are ship-blocking (P0). ~38 are worth fixing soon (P1). ~67 are polish.

---

## File Index

All audit docs are in `/Users/sergeymuzyukin/github/shuttlx/audits/2026-05-15-ux-ui-review/`:

- `product-designer.md` — top 10 UX improvements + per-screen findings + mockup sketches
- `design-reviewer.md` — full design-system violation list with file:line
- `app-auditor.md` — crash/logic bugs with reproduce steps + suggested owners
- `senior-architect.md` — architecture concerns + refactor proposals + TODO inventory
- `IMPROVEMENT_PLAN.md` — this synthesis
