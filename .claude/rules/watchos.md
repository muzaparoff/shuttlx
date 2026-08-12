---
globs:
  - "ShuttlX Watch App/**"
---

# watchOS Rules

## General

- Scheme name: `ShuttlX Watch App`
- watchOS target path: `ShuttlX Watch App/`
- Build: `xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlX Watch App" -destination 'generic/platform=watchOS Simulator' build` (do NOT pass `-sdk` — it forces the iOS companion target onto the watch SDK and breaks its SPM deps)
- Background mode: `workout-processing` for active workouts

## Timer Display

- Use 40pt monospaced font for timer on watch (smaller than iOS 52pt)
- Use `DispatchSourceTimer` (not `Timer`) — drift-proof, works when screen off
- Must work during wrist-down (screen off) state
- Test with long workouts (30+ minutes)
- **Free-run layout is a label-less, left-aligned metric column** (`TrainingView+Metrics.fullWorkoutDisplayTab`, free-run branch), modelled on Apple Workout's Outdoor Run metrics page. Row order: **TIME hero → HR → PACE → [DIST | CAL] compact two-up**. Every row is `unitNumber(value, unit, …)` — a big monospaced number with the unit as a SMALL suffix on the same baseline (`138`+`BPM`, `6'47"`+`/KM`, `12.84`+`KM`, `812`+`CAL`) — and every number, including the hero clock, shares one leading edge. The `[LABEL][spacer][value]` `metricRow` is deleted; do not reintroduce it here. The leading label column cost `labelWidth` (0.20h ≈ 39pt on 40mm) of every row to say what a ~24pt suffix says.
- **The workout-name header is INTERVAL-ONLY** (2026-08-06): interval mode keeps it because it names the running program ("5K INTERVAL"); free run dropped it because "FREE RUN" is a constant string that carries no mid-workout information while costing a full label row (~24pt on 40mm, ~30pt on 46mm). Two things the header used to carry are preserved in the free-run branch at zero vertical cost: (1) the **paused signal** — the hero clock itself now tints `ctaWarning` amber and takes the 0.8s `pausePulse` (the pulse driver `.onAppear` moved from the header row to the metrics `VStack`); (2) the **VoiceOver announcement of the workout type** — the hero's accessibility label is now `"<workoutName>[, paused], elapsed time …"`. Never re-add a static text row to the free-run stack.
- **Sizes are SOLVED, never scaled — this is the load-bearing rule.** SwiftUI does not report an over-full metrics stack; it silently scale-to-fits every row, so the source can say "0.26h" while the screen shows half that. Measured 2026-08-06 on the pre-redesign layout: hero **25.7pt rendered against a 49.7pt computed size** on 40mm (0.49×), 33.0 vs 64.5 on 46mm, 17.7 vs 35.5 at 1h27m; HR and PACE both at 0.67×. Three rules keep it honest: (1) `fittedMetricSize(glyphs:unit:unitSize:accessoryWidth:available:cap:)` solves each point size against the real row width up front; (2) value `Text`s use `.fixedSize()` on **both** axes with **no** `minimumScaleFactor` — `vertical: false` lets the VStack's height proposal shrink the text (and its width) instead of overflowing; (3) `ElapsedTimerText` likewise dropped `minimumScaleFactor` on both branches. If a row now doesn't fit, it visibly doesn't fit — fix the coefficient, don't re-add a scale factor.
- **Free run runs at `VStack(spacing: 0)`; interval keeps `rowSpacing`.** A `Spacer(minLength: 0)` is not free inside a spaced VStack — the stack still inserts spacing on *both* sides of it, so the four `flexGap`s were charging 8 × `rowSpacing` ≈ 39pt of forced whitespace on a 197pt screen (a quarter of the usable height). That was the single biggest reason the stack blew its budget and triggered the global scale-to-fit. Line boxes carry their own ~0.2em leading, so spacing 0 still reads as separated rows; the banner supplies `.padding(.vertical, 2)` of its own.
- **Two-tier type scale, keyed on `freeRunBannerShown`** (`isHighIntensityWarning || noHeartRateDetected`): every number renders `× 1.13` while no banner is showing and steps back down when one appears, so the banner's ~21pt (25pt on 46mm) is either a banner or bigger digits, never dead space. The banner always wins — it is cardiac-safety UI and must be fully visible. The reflow is animated by `.animation(…, value: bannerShown)` on the stack (font sizes themselves don't interpolate; the row insert/remove reflow carries it).
- **Measured free-run size table** (rendered pt, verified from snapshots — coefficients are `× screenHeight`):

  | Row | 40mm banner | 40mm no banner | 46mm banner | 46mm no banner |
  |---|---|---|---|---|
  | TIME hero (0.20h × tier) | 39.4 | 44.5 | 49.6 | 56.0 |
  | HR (cap 0.16h × tier) | 31.5 | 35.6 | 39.7 | 44.9 |
  | PACE (cap 0.15h × tier) | 29.6 | 33.4 | 37.2 | 42.0 |
  | DIST / CAL (cap 0.085h × tier) | 16.7 | 18.2 | 21.1 | 23.8 |

  For reference the old layout *rendered* 25.7 / 21.9 / 22.6 / 18.5 on 40mm. The compact row is **width**-bound, not height-bound: "12.84" is 5 glyphs in a half-width slot, and DIST and CAL deliberately share the smaller of the two solved sizes (mismatched sizes on one line read as a bug).
- **The hero is width-capped at `h:mm:ss` and that headroom is not spendable.** `ElapsedTimerText` caps itself at `availableWidth / (glyphCount * 0.62)`: on 40mm that is 49.7pt for `mm:ss` but only **35.5pt** for the 7-glyph `h:mm:ss` (46.1pt on 46mm). So past the hour mark the clock is a touch smaller than the HR digits. That is expected — the clock still spans the full row width and reads as the dominant element. Do not shrink HR/PACE to preserve a nominal hierarchy at 1h+; they are the live coaching metrics.
- **Vertical budget rule still binding in spirit** (2026-06-06 BPM visibility fix): HR and the "Ease off — HR high" banner must never leave the screen. The structure that satisfies it is 3 full rows + 1 compact two-up; usable height is ~166pt on 40mm and ~209pt on 46mm (screen − top safe area − page-dot inset), and a text line occupies ~1.2 × its point size, so **the sum of the four row point sizes must stay under `usable / 1.2`, minus ~21pt (25pt on 46mm) when the banner shows**. Any new metric goes into the compact row, never as a 4th full row.
- Free-run leftover height is distributed by collapsible `flexGap` spacers (`Spacer(minLength: 0)`), plus a `max(10, h * 0.055)` bottom inset that keeps the compact row clear of the TabView page dots (measured dot band: y193–195.5 of 197 on 40mm, y240–245.5 of 248 on 46mm; the old `0.085h` reserved more than that needed). Interval mode keeps its fixed `rowSpacing` rhythm — it has no slack.
- Free-run TIME hero has **no "TIME" text label** and no unit suffix — it is the only clock on screen. VoiceOver still announces it (see the header bullet above); the other rows keep full-unit labels ("Heart rate 138 beats per minute, Zone 2", "Average pace 6 minutes 47 seconds per kilometer", "Distance 12.84 kilometers", "812 calories").
- The **HR zone arc stays on both screen sizes**, parked after the `BPM` suffix. Solved against the row it costs `max(30, h * 0.145)`, which still leaves the digits ~91pt on 40mm — more than the 0.16h cap asks for — so it is free.
- Snapshot-verified 2026-08-06 on SE 3 40mm + Series 11 46mm (watchOS 26.5), free run at 22m and 1h27m × banner/no-banner/nil-pace/paused, plus AOD: no truncation, all rows plus banner on screen, compact row clear of the TabView page dots, no row scale-to-fit.
- DEBUG snapshot harness env (`ShuttlXWatchApp.swift`, launched via `SIMCTL_CHILD_*`): `SHUTTLX_SNAPSHOT=<themeID>`, `SHUTTLX_SNAPSHOT_ELAPSED=<sec>` (free-run seed; omit for the interval seed), `SHUTTLX_SNAPSHOT_HR`, `SHUTTLX_SNAPSHOT_PACE` (`none` → "—"), `SHUTTLX_SNAPSHOT_AOD=1`, `SHUTTLX_SNAPSHOT_PAUSED=1` (→ `WatchWorkoutManager.applyPausedPreviewState()`, the only way to capture the paused presentation since `timerReferenceDate` is `private(set)`).

## Pace (Rolling vs Cumulative)

- Pace is computed from a **sliding 30-second window**, not cumulative average from workout start
- Guards: must be ≥20s into workout AND ≥0.05km total distance AND window ≥5s AND ≥5m moved, else shows "—"
- CMPedometer distance has ~30s warmup lag; first sample arrives skewed (e.g. 30s / 0.05km = 10'00). Sliding window avoids the warmup artifact entirely
- Root cause doc: `docs/incidents/2026-06-06-pace-10min.md`

## Controls

- Circular buttons: green for pause, red for stop
- Keep controls large and tappable (min 44pt touch target)

## Workout Lifecycle

- HealthKit workout session must survive app backgrounding
- Save workout data on pause AND on stop (crash recovery)
- If app is killed mid-workout, data must be recoverable from local storage

## Watch Complications / Widgets

- Widget files are in `ShuttlXWatchWidgets/`
- Types: LastWorkout, QuickStart, WeeklyProgress, TodayWorkout
- Data provided via `WatchWidgetDataProvider`

## Theme System

- Both themes (Clean, Mixtape) are supported on watchOS (July 2026 reduction — the other 5 themes were deleted app-wide)
- Theme files mirrored in `ShuttlX Watch App/Theme/` with watch-specific font sizes
- Theme selection synced from iPhone via WCSession `applicationContext`
- `ThemeManager.shared` injected at app root in `ShuttlXWatchApp.swift`
- Use `ShuttlXColor.*` / `ShuttlXFont.*` (bridges to active theme) or `@Environment(ThemeManager.self)`
- Mixtape on watch: full-screen Walkman LCD deck — `MixtapeWatchDeck` in `ShuttlX Watch App/Theme/Themes/Decorations/MixtapeTimerHero.swift`, rendered from `TrainingView+Metrics.swift`; reel rotation keys off `elapsedTime` (halts on pause), decorations are `.allowsHitTesting(false)`

## Sync

- Watch-side sync is in `WatchSyncCoordinator.swift` (~1,200 lines)
- Phone-side sync is in iOS `PhoneSyncCoordinator.swift` (~1,130 lines)
- Both must handle offline gracefully — queue and retry
- Theme sync: `handleIncomingPayload` handles `"syncTheme"` action from iPhone
