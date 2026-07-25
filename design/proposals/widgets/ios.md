# iOS Widget Hand-off — Widget Lineup Expansion

Read `proposal.md` for rationale + ASCII mockups. This is the iOS build spec. Owner: `senior-ios-developer`.

## Scope (iOS widgets)
W1 Start Training (configurable), W2 Quick Start Control, W3 Weekly Goal Ring, W4 Streak (+families), W5 Next Planned, W6 Weekly Dashboard (large), W7 Recovery Status.

## Tier 1 build (do these first)

### W1 — Start Training (configurable)
- `AppIntentConfiguration` widget, families `[.systemSmall, .systemMedium]`.
- `WorkoutTemplateEntity: AppEntity` + `TemplateEntityQuery: EntityQuery` reading `workout_templates.json` from App Group `group.com.shuttlx.shared` (reuse the `NSFileCoordinator` decode pattern from `WidgetDataProvider.loadSessions()`).
- `@Parameter var template: WorkoutTemplateEntity?` — nil ⇒ Free Run default.
- Tap: `.widgetURL(URL(string: template == nil ? "shuttlx://start/freerun" : "shuttlx://start/template/\(id)"))`.
- Host `ShuttlXApp.swift onOpenURL`: add `case "start":` → parse `freerun` / `template/{uuid}` → `PhoneSyncCoordinator.shared.startWatchWorkout(mode:"freeRun")` or resolve template from `TemplateManager` and `startWatchWorkout(mode:"interval", template:)`. Show a lightweight "starting on watch…" toast; gate on watch reachability (fall back to "Open watch app" like `StartOnWatchCard`).
- Theme: `WidgetTheme.forID(entry.themeID)`; Clean glass ring around glyph, Mixtape cassette-label + spool play glyph. Use the shared `GlassRingProgress`/`CassetteSpoolProgress` canvases (static, no fill for W1).
- States: configured / unconfigured (Free Run) / deleted-template (Free Run fallback) / redacted placeholder.

### W2 — Quick Start Control (iOS 18)
- `ControlWidget` with `ControlWidgetButton` → `StartFreeRunIntent: AppIntent` (`openAppWhenRun = true`, opens `shuttlx://start/freerun`).
- Monochrome system tint; SF Symbol `figure.run`, title "Free Run". No per-theme art.

### W3 — Weekly Goal Ring
- Families `[.systemSmall, .accessoryCircular, .accessoryRectangular]`.
- Data: `WidgetDataProvider.thisWeekSessionCount()` + `weeklyWorkoutGoal` (guard 0 → 5, like `WeeklyProgressComplication`).
- systemSmall: Clean → `GlassRingProgress`; Mixtape → `CassetteSpoolProgress` (custom `Canvas`, NOT `Gauge`). accessoryCircular → system `Gauge(.accessoryCircular)`.
- States: in-progress / goal-reached (subtle check, no confetti) / zero / placeholder.

## Tier 2 / Tier 3
- W4: extend `SmallWidget` to add `.accessoryInline` + `.accessoryCircular`; reskin number into ring / cassette counter.
- W5 Next Planned: new `PlannedWorkoutProvider` — **needs plan progress in App Group** (see open questions). `.systemMedium` + `.accessoryRectangular`, interactive Start region → `shuttlx://start/template/{id}`.
- W6 Weekly Dashboard: `.systemLarge`, composite, multiple tap regions.
- W7 Recovery Status: `.systemSmall` + `.accessoryCircular`, **blocked on readiness metric** — calm 3-state color, no alarm red.

## Register in bundle
Add W1, W2 (as separate `ControlWidget` in the bundle or a `ControlWidgetBundle`), W3, W4, W5, W6, W7 to `ShuttlXWidgets/ShuttlXWidgetsBundle.swift`.

## Implementation hand-off
- **Files to create:** `ShuttlXWidgets/StartTrainingWidget.swift` (W1), `ShuttlXWidgets/QuickStartControl.swift` (W2 + `StartFreeRunIntent`), `ShuttlXWidgets/WeeklyGoalRingWidget.swift` (W3), `ShuttlXWidgets/NextPlannedWidget.swift` (W5), `ShuttlXWidgets/WeeklyDashboardWidget.swift` (W6), `ShuttlXWidgets/RecoveryStatusWidget.swift` (W7), `ShuttlXWidgets/Shared/WorkoutTemplateEntity.swift` (AppEntity + query), `ShuttlXWidgets/Shared/StartIntents.swift`, `ShuttlXWidgets/Shared/ThemeCanvases.swift` (`GlassRingProgress`, `CassetteSpoolProgress`).
- **Files to modify:** `ShuttlXWidgets/SmallWidget.swift` (W4 families), `ShuttlXWidgets/ShuttlXWidgetsBundle.swift` (register), `ShuttlX/ShuttlXApp.swift` (`onOpenURL` add `case "start"`), possibly `ShuttlX/Services/PhoneSyncCoordinator.swift` (expose template lookup by id for deep-link resolution). `ShuttlXWidgets/MediumWidget.swift` (`WidgetTheme`) — optional cleanup of dead theme cases.
- **Reuse existing:** `WidgetDataProvider` (streak/week/today/last), `WidgetTheme.forID`, `PhoneSyncCoordinator.startWatchWorkout(mode:template:)`, `TemplateManager`, `NSFileCoordinator` decode pattern, `MetricBox` from `MediumWidget.swift`.
- **Theme variants verified:** only **Clean** + **Mixtape** are live. Clean = glass ring; Mixtape = cassette spool/label/counter. `WidgetTheme` still contains 5 dead theme cases — harmless, flag for docs-keeper/cleanup. Lock-screen accessories are monochrome (tint only) by platform rule — no per-theme art there.
- **Watch performance check:** N/A (iOS), but the shared `WorkoutTemplateEntity` must compile in both the iOS widget ext and the watch widget ext without importing app-only types.
- **Open questions for dev:**
  1. Widget process cannot run WatchConnectivity — confirm the deep-link-into-host approach is acceptable for W1/W2 (adds one app-foreground flash vs a true in-process start).
  2. W5/W6 need **plan progress persisted to App Group** (next incomplete `PlanDay` + its template id). Where should this be written — extend `PhoneSyncCoordinator` to snapshot plan progress to a `plan_progress.json`?
  3. W7 needs a **readiness/recovery metric** persisted. Does one exist, or is this blocked on future healthkit-domain-expert work? Route the data-model decision to `senior-architect`.
  4. Should reconfiguring W1 when a template is renamed force a timeline reload (`WidgetCenter.shared.reloadTimelines`) from `TemplateManager.save()`?
