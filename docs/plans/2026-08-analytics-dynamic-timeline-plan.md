# Dynamic Analytics Timeline — Implementation Plan (August 2026)

Follow-up to the interactive mockup deck (artifact `019169ba-bd08-4b57-9a10-a36c3baa3cc5`, "Analytics Timeline Concepts") built from a product-designer competitor audit (Strava, WHOOP, Oura, Apple Health, Garmin). User approved 4 of 5 concepts — **Narrative Insight Cards (concept 3) was rejected**, everything else approved.

## Decision (confirmed with user)

**Layout: one scrolling screen, stacked** — not tabs, not a hero+tabs hybrid. New sections are inserted into the existing `AnalyticsView` scroll stack, in this order:

1. Recovery Status *(existing, unchanged)*
2. **Scrub Timeline Hero** *(new)* — draggable timeline scrubber over a hero metric, preset range pills (7D/30D/90D/1Y)
3. **Comparison Split View** *(new)* — period-pair toggle (this vs last week/month), diverging delta bars per metric
4. **Calendar Heatmap Navigator** *(new)* — 14-week tap-to-drill grid, sequential color ramp
5. Run vs Walk Split *(existing, Phase 4 run+walk work — unchanged)*
6. **Weekly Carousel** *(new)* — swipeable per-week cards with a mini training-focus scatter, dot-strip jump picker
7. VO2max Card *(existing, unchanged)*
8. Personal Records *(existing, unchanged)*
9. Pace Zones Chart *(existing, unchanged)*
10. Elevation Section *(existing, unchanged)*

**Consolidation (recommended, flag before implementing):** the current "Fitness Trend Chart" and "Weekly Volume Chart" sections (`AnalyticsView.swift` `// MARK: - Fitness Trend Chart` / `// MARK: - Weekly Volume Chart`) are both single-metric-over-time views that the new Scrub Timeline Hero fully generalizes and makes interactive. **Remove both**, replaced by the hero — otherwise this ships as 4 new sections piled onto an already-long screen, which works against the actual goal ("make it feel less static," not "make it longer"). If review disagrees, keep them and place the hero above them instead — flag, don't silently decide either way at implementation time.

## Design source (from the mockup deck, condensed)

Each concept's full pitch, competitor citation, and Clean/Mixtape treatment notes are in the artifact and reproduced in `docs/plans/` history — key implementation-relevant points:

- **Series colors are fixed and already accessibility-validated**: running = blue (`#2a78d6` light / `#3987e5` dark), walking = orange (`#eb6834` light / `#d95926` dark) — validated via the dataviz skill's `validate_palette.js` (ΔE ~25-27, clears the CVD floor cleanly on both surfaces). **Do NOT use the app's existing green/orange convention for any new chart in this work** — that exact pair was validated and *fails* (ΔE 2.7–3.2, well under the safety floor). This is a separate, pre-existing accessibility finding worth a follow-up ticket on `ShuttlXColor.running`/`.walking` themselves, out of scope for this plan.
- **Comparison bars use a dedicated diverging pair** (blue=decrease, red=increase, neutral gray zero-line) — deliberately distinct from the categorical run/walk colors so "more/less" is never visually confused with "run/walk."
- **Heatmap uses one sequential hue, light→dark** — blue ramp for Clean, amber ramp for Mixtape (sequential encoding, not categorical — no CVD adjacency requirement, only lightness monotonicity).
- Signature Shape DNA: Mixtape's scrubber handle and heatmap cells can pick up the cassette-spool/tape-hole motif already used in `MixtapeSpoolDot.swift`; not required for v1, nice-to-have.
- All four are THEMED surfaces per `.claude/rules/design-system.md` (Analytics is explicitly themed) — `ShuttlXColor`/`ShuttlXFont` bridges only, `.monospacedDigit()` on all numeric displays, full Clean + Mixtape treatment (not Clean-only).

## Implementation split (parallel-safe)

Both agents produce **new, standalone SwiftUI files only** — neither touches `AnalyticsView.swift` or `AnalyticsEngine.swift` directly, to keep the two writers fully disjoint. Each derives its own data from the raw `[TrainingSession]` / `WeeklySummary` / `DailyWorkoutSummary` arrays `AnalyticsEngine` already produces, rather than requiring shared-engine changes. The lead does the final integration pass: wiring both sets of views into `AnalyticsView.swift`'s scroll stack in the confirmed order, plus the Fitness Trend/Weekly Volume removal.

**Track A — trend/comparison (shares data shape: time-bucketed summaries)**
- `ScrubTimelineHeroCard.swift` — drag-to-scrub hero + range pills
- `ComparisonSplitCard.swift` — period-pair toggle + diverging delta bars

**Track B — period navigation (shares data shape: per-day/per-week buckets)**
- `CalendarHeatmapCard.swift` — 14-week tap grid
- `WeeklyCarouselCard.swift` — swipeable per-week cards + mini scatter

## Feasibility notes (from the design review)

- Scrub hero: Swift Charts `LineMark` + `DragGesture` over a transparent overlay snapping to nearest data index; extend/reuse `ThemedLineChart` rather than a new chart engine.
- Comparison bars: pure `Canvas` or stacked `Rectangle`s anchored at a center zero-line — no chart library needed.
- Heatmap: `LazyVGrid` of `RoundedRectangle`s colored via a sequential-ramp function over `DailyWorkoutSummary.totalDistance` — no new chart engine.
- Carousel: `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` (iOS 17+) or `TabView(.page)`; mini scatter is a small custom `Canvas`.

## Verification

Build iOS scheme clean; per repo discipline, visually verify in simulator (both Clean and Mixtape, both light rendering) before calling it done — this is exactly the class of work where a build success doesn't prove the interaction feels right. Screenshot both themes for the four new cards.
