# watchOS Complication Hand-off — Widget Lineup Expansion

Read `proposal.md` for rationale + mockups. This is the watch build spec. Owner: `swiftui-watchos-specialist`.

## Scope (watch complications)
W8 Free Run Start, W9 Start Template (configurable), W10 Weekly Ring (+corner), W11 Streak Corner, W12 Today/Next (+inline), W13 Recovery Corner, W14 Last Workout (+circular).

## Tier 1 build

### W8 — Free Run Start
- Extend the existing `QuickStartComplication` families from `[.accessoryCircular, .accessoryRectangular, .accessoryInline]` to also include `.accessoryCorner`.
- Interaction already correct: `widgetURL` `shuttlx://start-workout` → `ShuttlXWatchApp.swift` already calls `workoutManager.startWorkout()`. No new deep-link needed.
- `.accessoryCorner`: curved "FREE RUN" text label + `figure.run` glyph, `widgetAccentable()`.
- States: idle / (optional) active-workout relabel if a shared active flag is readable / placeholder.

## Tier 2

### W9 — Start Template (configurable)
- `AppIntentConfiguration`, families `[.accessoryRectangular, .accessoryCircular]`.
- Reuse the shared `WorkoutTemplateEntity` (must compile in the watch widget ext) querying the watch's `workout_templates.json`.
- New deep link: `shuttlx://start-template/{uuid}`. Add a `case "start-template":` in `ShuttlXWatchApp.swift onOpenURL` → resolve template (from `WatchSyncCoordinator`/`SharedDataManager.workoutTemplates`) → `workoutManager.startIntervalWorkout(template:)`.
- Rectangular: name + `summaryText` + run glyph. Circular: sport glyph + interval count. Unconfigured → "Pick a workout"; deleted-template → Free Run fallback.

### W10 — Weekly Ring
- Add `.accessoryCorner` to existing `WeeklyProgressComplication`. Use `Gauge(.accessoryCorner)` with count as current-value label.

### W11 — Streak Corner
- New `StreakComplication`, families `[.accessoryCorner, .accessoryCircular]`.
- **Port `currentStreak()` into `WatchWidgetDataProvider`** (it currently only has last/today/week; copy the algorithm from iOS `WidgetDataProvider.currentStreak()`).
- Flame glyph + curved count. `shuttlx://home`.

### W12 — Today / Next
- Add `.accessoryInline` to existing `TodayWorkoutComplication`. Inline one-liner: trained-today → "✓ Free Run 28m"; else → "3/5 this week".

### W14 — Last Workout
- Add `.accessoryCircular` to existing `LastWorkoutComplication`: duration in a thin ring, glyph centered.

## Tier 3

### W13 — Recovery Corner
- `[.accessoryCircular, .accessoryCorner]`. **Blocked on the readiness metric** (same dependency as iOS W7). Calm 3-state color, `widgetAccentable`, no alarm styling.

## Register in bundle
Add W9, W11, and the recovery complication to `ShuttlXWatchWidgets/ShuttlXWatchWidgets.swift`. W8/W10/W12/W14 are family/view extensions of existing entries.

## Implementation hand-off
- **Files to create:** `ShuttlXWatchWidgets/StartTemplateComplication.swift` (W9), `ShuttlXWatchWidgets/StreakComplication.swift` (W11), `ShuttlXWatchWidgets/RecoveryComplication.swift` (W13), shared `WorkoutTemplateEntity` (compile the iOS-authored one into this target, or a watch copy under `ShuttlXWatchWidgets/`).
- **Files to modify:** `ShuttlXWatchWidgets/QuickStartComplication.swift` (add `.accessoryCorner` — W8), `ShuttlXWatchWidgets/WeeklyProgressComplication.swift` (add corner — W10), `ShuttlXWatchWidgets/TodayWorkoutComplication.swift` (add inline — W12), `ShuttlXWatchWidgets/LastWorkoutComplication.swift` (add circular — W14), `ShuttlXWatchWidgets/WatchWidgetDataProvider.swift` (add `currentStreak()`), `ShuttlXWatchWidgets/ShuttlXWatchWidgets.swift` (register), `ShuttlX Watch App/ShuttlXWatchApp.swift` (`onOpenURL` add `start-template` case).
- **Reuse existing:** `WatchWidgetDataProvider` (last/today/week + cache), existing `QuickStartComplication` deep link `shuttlx://start-workout` (already starts Free Run — W8 needs no new plumbing), `workoutManager.startWorkout()` / `startIntervalWorkout(template:)`, `SharedDataManager.workoutTemplates`.
- **Theme variants verified:** only **Clean** + **Mixtape** live. Watch faces tint complications system-side, so identity is `widgetAccentable()` + accent only — no per-theme Canvas at complication scale (respects the "chrome never competes with data" + battery anti-goals). Corner gauges read as the Clean ring naturally.
- **Watch performance check:** all complications are static `Shape`/`Gauge`/`Text` — **no idle animation, no `Canvas` timers, no `TimelineView`**. Timeline policies: `.never` for start widgets, `.after(+30m/+1h/+3h)` for data widgets (matches existing). No height-budget concern (complications are fixed slots). `WatchWidgetDataProvider` 5s cache prevents repeated JSON decode across a timeline build.
- **Open questions for dev:**
  1. Confirm `WorkoutTemplateEntity` can be shared across both widget extensions without dragging in app-only types — if not, a small watch-local copy is fine.
  2. W13 recovery blocked on the readiness data model (same as iOS W7) — route to `senior-architect` / `healthkit-domain-expert`.
  3. `shuttlx://start-template/{id}` — if the referenced template isn't yet synced to the watch, should it fall back to Free Run or show "Sync your workouts"? Recommend Free Run fallback + a one-time toast.
