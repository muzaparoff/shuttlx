# Design Reviewer Audit — 2026-05-15

## Summary

**Total violations: 87**

| Category | Count |
|---|---|
| Hardcoded colors in view/component files | 7 (all in watch `RecoveryWorkoutView` + map overlay whites) |
| Hardcoded fonts `.font(.system(size:))` in view files | 28 (watch `TrainingView` + `RecoveryWorkoutView`) |
| Semantic font tokens bypassed (`caption`, `headline`, `subheadline`, `title`) in iOS view files | 52+ instances across 20 files |
| Missing `.themedCard()` on container views | 5 |
| Missing `.themedScreenBackground()` | 2 (DevicePickerView, HealthPermissionsInfoView) |
| Missing `.monospacedDigit()` on numeric displays | 6 |
| Missing accessibility labels/hints | 8 |
| HIG violations | 7 |
| Theme parity gaps | 2 |
| watchOS-specific issues | 4 |

---

## P0 — Must fix before ship

### DS-01 — Hardcoded `.foregroundColor(.orange)` in watch rest view
`ShuttlX Watch App/Views/RecoveryWorkoutView.swift:169` → `.foregroundColor(ShuttlXColor.ctaWarning)`

### DS-02 — Hardcoded `Color.green` / `Color.gray` for milestone badge backgrounds
`ShuttlX Watch App/Views/RecoveryWorkoutView.swift:248,252` → `ShuttlXColor.positive.opacity(0.25)` / `ShuttlXColor.surface` / `ShuttlXColor.surfaceBorder`

### DS-03 — Hardcoded `.foregroundColor(.white.opacity(0.7))` in Always-On Display
`ShuttlX Watch App/Views/TrainingView.swift:127` → `.foregroundColor(ShuttlXColor.textPrimary.opacity(0.7))`

### DS-04 — Hardcoded `.foregroundColor(.red.opacity(0.7))` in AOD heart rate display
`ShuttlX Watch App/Views/TrainingView.swift:132` → `.foregroundColor(ShuttlXColor.heartRate.opacity(0.7))`

### DS-05 — Hardcoded white/gray in milestone badge text
`ShuttlX Watch App/Views/RecoveryWorkoutView.swift:243` → `ShuttlXColor.textPrimary` / `ShuttlXColor.textSecondary`

### DS-06 — `Color.gray` ring track in idle recovery view
`ShuttlX Watch App/Views/RecoveryWorkoutView.swift:39` → `ShuttlXColor.surfaceBorder`

### DS-07 — `Color.green` station detection progress ring
`ShuttlX Watch App/Views/RecoveryWorkoutView.swift:43` → `ShuttlXColor.positive.opacity(0.75)`

### H-01 — Missing `.themedScreenBackground()` on `DevicePickerView`
`ShuttlX/Views/DevicePickerView.swift:66` — List background bleeds through on Synthwave/Arcade. Add `.scrollContentBackground(.hidden)` + `.themedScreenBackground()`.

### H-02 — Missing `.themedScreenBackground()` on `HealthPermissionsInfoView`
`ShuttlX/Views/SettingsView.swift:597` — NavigationStack + ScrollView with no themed bg.

### H-03 — `.background(.white, in: Circle())` hardcodes white for map marker
`ShuttlX/Views/RouteMapView.swift:53` → `ShuttlXColor.background`

### W-01 — Watch `TrainingView` + `RecoveryWorkoutView` bypass `ShuttlXFont.*`
- `ShuttlX Watch App/Views/TrainingView.swift` — 13 raw `.font(.system(size:))` at lines 125, 130, 136, 158, 180, 186, 194, 241, 246, 412
- `ShuttlX Watch App/Views/RecoveryWorkoutView.swift` — 17 instances at lines 49, 58, 63, 67, 92, 96, 102, 106, 117, 120, 129, 132, 141, 144, 168, 172, 186, 191, 236, 239

Switching themes never changes the actual watch UI fonts. Replace with `ShuttlXFont.watchTimerDisplay`, `ShuttlXFont.watchMetricDisplay`, `ShuttlXFont.watchStepLabel` tokens; introduce `watchMetricPrimary`/`watchMetricSecondary` if dynamic sizing is needed.

---

## P1 — Should fix soon

### DS-08 — Semantic font tokens bypass `ShuttlXFont.*` across iOS views (~52 sites)

| File | Lines | Apple style used | Replacement |
|---|---|---|---|
| `TemplateListView.swift` | 58, 62, 92, 97, 172, 177 | `.headline`, `.subheadline` | `ShuttlXFont.cardTitle`, `cardSubtitle` |
| `PlanDetailView.swift` | 38, 43, 48, 60, 88, 91, 113, 119, 124, 130 | `.title`, `.subheadline`, `.caption`, `.headline` | `metricLarge`, `cardSubtitle`, `cardCaption`, `cardTitle` |
| `PlanListView.swift` | 72, 76, 81 | `.headline`, `.subheadline`, `.caption` | `cardTitle`, `cardSubtitle`, `cardCaption` |
| `ProgramsTabView.swift` | 27, 29, 49, 51, 80, 90, 97 | `.headline`, `.caption` | `cardTitle`, `cardCaption` |
| `OnboardingView.swift` | 37, 73, 127 | `.largeTitle.bold()` | `metricLarge` |
| `SignInView.swift` | 21, 24, 53, 84, 86 | `.largeTitle.bold()`, `.body`, `.caption` | `metricLarge`, `cardSubtitle`, `cardCaption` |
| `IntervalResultsView.swift` | 9, 56, 124 | `.headline`, `.subheadline`, `.caption2` | `cardTitle`, `cardSubtitle`, `cardCaption` |
| `SettingsView.swift` | 41, 43, 82, 106, 294, 311, 317, 320, 326, 347, 365, 584, 601, 607, 618 | `.body`, `.caption`, `.callout`, `.largeTitle.bold()`, `.headline` | `cardSubtitle`, `cardCaption`, `metricLarge`, `cardTitle` |
| `TrainingHistoryView.swift` | 88, 202 | `.headline`, `.caption` | `cardTitle`, `cardCaption` |
| `SessionDetailView.swift` | 49, 55, 64, 208 | `.subheadline`, `.caption` | `cardSubtitle`, `cardCaption` |
| `ProgramListView.swift` | 20, 33, 44 | `.body`, `.caption`, `.title2` | `cardSubtitle`, `cardCaption` |
| `DeviceListView.swift` | 173, 179 | `.caption` | `cardCaption` |

### DS-09 — `.caption2` used everywhere (no `ShuttlXFont` equivalent)

`AnalyticsView.swift:191,200,243,252,262,265,312,426,527,538`, `IntervalResultsView.swift:58,72,124`, `Charts/WeeklyDistanceChart.swift:31,40`, `Charts/PaceTrendChart.swift:43,53`, `Charts/HRZoneChart.swift:28,36`, `ElevationProfileView.swift:108,113`, `TemplateListView.swift:69,74,104,182,191`. Add `ShuttlXFont.chartCaption` token to `ThemeFonts`.

### DS-10 — `LiveWorkoutCard` bypasses `.themedCard()`
`ShuttlX/Views/Dashboard/LiveWorkoutCard.swift:86-93` — uses manual `RoundedRectangle` hardcoded to `ShuttlXColor.running.opacity(0.08)`. Replace with `.padding(16).themedCard(accent: .running, headerLabel: "LIVE WORKOUT")`.

### DS-11 — `AnalyticsView` recovery card uses manual `RoundedRectangle`
`ShuttlX/Views/AnalyticsView.swift:116-120` → `.themedCard(accent: ShuttlXColor.forRecovery(recovery), headerLabel: "RECOVERY")`

### DS-12 — `PRCard` uses manual `.background`
`ShuttlX/Views/AnalyticsView.swift:544` → `.themedCard(accent: color)`

### DS-13 — `WatchMetricCard` has no `.themedCard()`
`ShuttlX Watch App/Components/MetricCard.swift` — bare surface. Add `.themedCard()` to the VStack.

### DS-14 — `DevicePickerView` missing `.scrollContentBackground(.hidden)`
`ShuttlX/Views/DevicePickerView.swift:67`

### H-04 — `WatchPromptView` uses deprecated `.foregroundColor(.accentColor)`
`ShuttlX/Views/ProgramListView.swift:11, 21` → `.foregroundStyle(.tint)`, `.foregroundStyle(.secondary)`

### H-05 — `PlanDetailView` sport icon uses `.font(.title)` not `ShuttlXFont.heroIcon`
`ShuttlX/Views/PlanDetailView.swift:38`

### A-01 — `ElevationProfileView.elevationStat` missing a11y
`ShuttlX/Views/ElevationProfileView.swift:105-116` — add `.accessibilityElement(children: .combine)` + `.accessibilityLabel("\(title): \(value)")`

### A-02 — `LiveRouteView` zero accessibility markup
`ShuttlX/Views/LiveRouteView.swift` — add `.accessibilityLabel("Live route map")` to `Map`, `.accessibilityLabel("Acquiring GPS signal")` to waiting state.

### A-03 — `IntervalResultsView.summaryItem` missing combine
`ShuttlX/Views/IntervalResultsView.swift:118-128`

### A-04 — `ActivitySegmentsView` toggle missing hint
`ShuttlX/Views/SessionDetailView.swift:204-213`

### A-05 — `WeekStripView` days missing hint
`ShuttlX/Views/Charts/WeekStripView.swift:57-58`

### W-02 — Watch `RecoveryWorkoutView.restView` no scroll / no crown
`ShuttlX Watch App/Views/RecoveryWorkoutView.swift` — content may clip on 40mm. Wrap in `ScrollView`.

### W-03 — Watch `WorkoutSummaryView.summaryRow` missing `.accessibilityLabel`
`ShuttlX Watch App/Views/TrainingView.swift:563-578`

### W-04 — No haptic on interval step transitions
Pause/stop/start/success haptics fire; **interval work↔rest transitions do NOT**. CLAUDE.md spec says they should. Add `WKInterfaceDevice.current().play(.click)` for rest→work and `.directionUp` for work→rest in `WatchWorkoutManager` where `IntervalEngine.tick()` reports a step change.

---

## P2 — Polish

- **DS-15/16** — Hardcoded magenta/cyan literals in `ThemeModifiers.swift` (both targets). Extract to theme tokens.
- **DS-17** — `HRZoneChart` `#Preview` uses hardcoded `.green`, `.yellow`, `.orange`. Use `ShuttlXColor.hrZone2..4`.
- **DS-18** — Map marker borders use `.stroke(.white, …)`. Use `ShuttlXColor.background`.
- **DS-19** — `AnalyticsView` VO2max trend icon uses `.title3.weight(.semibold)`. Use `ShuttlXFont.prValue`.
- **DS-20** — `MetricCard` icon uses raw `.body`/`.title2`. Add `ShuttlXFont.metricIcon`.
- **H-07** — `SettingsView` theme swatch row decorative circles should be `.accessibilityHidden(true)`.
- **H-08** — `SignInView` uses `VStack(spacing: 32)` outside the 8/12/16/24 scale.
- **H-09** — `ProgramListView (WatchPromptView)` uses `HStack(spacing: 32)`.
- **A-06** — `ElevationProfileView` Swift Charts block has no `.accessibilityLabel`.
- **A-07** — `SessionDetailView.MetricCard` HR redundant VoiceOver reading.
- **TP-01** — Add `// MARK: Decorative — not Dynamic Type` to `ThemeAssets.swift` decorative views.

---

## Theme Parity Matrix

| Screen | Clean | Synthwave | Mixtape | Arcade | Classic Radio | VU Meter | Neovim |
|---|---|---|---|---|---|---|---|
| DashboardView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| AnalyticsView | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ |
| TrainingHistoryView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| SessionDetailView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| TemplateListView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| SettingsView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| PlanListView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| PlanDetailView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| DeviceListView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| DevicePickerView | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| OnboardingView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| SignInView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| HealthPermissionsInfoView | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| ProgramsTabView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Watch: TrainingView | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ |
| Watch: RecoveryWorkoutView | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ |
| Watch: WorkoutSummaryView | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

✓ = uses themed bg + card correctly. ⚠ = renders but has hardcoded color/font that ignores theme. ✗ = bg/cards don't adopt theme.

---

## Top 3 fixes (highest impact, lowest effort)

1. **W-01 / DS-08 combined — watch views entirely bypass `ShuttlXFont.*`** — `TrainingView.swift` + `RecoveryWorkoutView.swift` account for 28 of the 87 violations. Switching to `ShuttlXFont.*` tokens makes all 7 themes visually distinct during active workouts, the most-viewed screen in the app.
2. **DS-01..DS-07 — hardcoded `Color.green`, `Color.gray`, `.orange`, `.white`, `.red` in `RecoveryWorkoutView`** — all 7 fixes in one file, pure token substitutions. Gym recovery is a flagship feature and color breaks are visible in every non-Clean theme.
3. **H-01 + H-02 — `DevicePickerView` and `HealthPermissionsInfoView` missing `.themedScreenBackground()`** — single-line fixes; eliminate the jarring theme discontinuity when navigating in from a themed Settings.
