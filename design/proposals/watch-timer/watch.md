# Proposal 2 — watchOS Timer "Focus Rail" (watch hand-off)

Mockup: [`watch-mockup.html`](watch-mockup.html) · Surface: `ShuttlX Watch App/Views/TrainingView+Metrics.swift` → `fullWorkoutDisplayTab`

---

## 1. Scope

**Mixtape's watch face is out of scope.** `MixtapeWatchDeck` is already a designed surface and
this proposal does not touch it. The work is the `else` branch —
`if themeManager.current.id != "mixtape"` — i.e. the **Clean** face, which is still the
original stacked label/value layout.

Secondary: `aodMinimalView` gets the same skeleton so AOD and active look like one design.

## 2. Three concrete problems in the current branch

1. **Three progress indicators at once.** In interval mode `fullWorkoutDisplayTab` renders
   `OverallProgressStrip` (3pt, `.overlay(alignment: .top)`), *plus* `intervalCountdownHero`'s
   own 3pt capsule, *plus* `IntervalStepWash`. Three encodings of "how far along" on a
   176×215pt screen.
2. **The label column costs ~20% of the width.** `labelWidth = h * 0.20` ≈ 43pt on 41mm,
   permanently reserved for "DIST"/"PACE"/"HR"/"TIME". This is why the code carries
   `minimumScaleFactor(0.4)` with a comment about `"2.15 km"` clipping — the fix treats the
   symptom.
3. **Element count exceeds the budget.** Interval mode can show: progress strip, workout
   name, countdown, step capsule, phase+count, NEXT preview, HR+arc, DIST, PACE, TIME, CAL,
   plus up to two banners. That is 13 against a stated max of ~5.

## 3. The design — 5 slots, fixed

```
┌────────────────────────────┐
│ ▓▓▓▒░░░░░░░░               │ 1  step rail   6pt   ← theme signature slot
│ RUN                    3/8 │ 2  phase      18pt
│ 1:48                       │ 3  HERO       66pt
│ next › WALK 1:00           │    (reserved optional row, 14pt)
│ 142 BPM             ▁▃▅    │ 4  HR + zone  46pt
│                            │    Spacer()
│ DIST      PACE             │ 5  footer     34pt
│ 0.42      5:38             │
└────────────────────────────┘
```

### 3.1 Step rail (the key move)

Replaces `OverallProgressStrip` **and** the hero capsule. One tick per interval step:

| Tick state | Fill |
|---|---|
| completed | `forStepType(step.type)` @ 55% |
| current | `forStepType(step.type)` full + 7pt glow |
| upcoming | `.white.opacity(0.13)` |

- Height 6pt, full-bleed, gap 2.5pt, `.allowsHitTesting(false)`
- Free-run: single continuous tick (no steps to segment)
- **> 12 steps:** ticks fall below the 3pt legibility floor. Group into 12 buckets and fill
  proportionally. Decide with dev — see open questions.
- Redraw: changes at step boundaries only (~8/workout) vs the current per-second
  `.animation(.linear(duration: 1))` bar (~1,800/workout).

### 3.2 Delete the label column

`metricRow` / `compactMetric` lose `labelWidth`. Labels become 10pt/700 captions stacked
**above** values in a `VStack(alignment: .leading, spacing: 0)`. Values gain ~25% width and
`minimumScaleFactor` can go back to 0.6.

### 3.3 Hero sizing is conditional

```
hero = (bannerVisible) ? h * 0.26 : h * 0.31
```

Both `noHeartRateBanner` and `highIntensityWarningView` count as banners. **Never render a
banner and the NEXT chip simultaneously** — banner wins. This keeps 41mm inside budget (see
the arithmetic block in the mockup).

### 3.4 HR zone: arc → ticks

Replace `HRZoneArc` (a `Canvas` drawing 5 arc strokes at 34×17pt) with 5 ascending
`RoundedRectangle` ticks, 6pt wide, heights 7/11/15/19/23pt. Same `hrZone1…5` colours, same
fill-up-to-current-zone logic. Cheaper and more legible at that size.

### 3.5 Remove the workout name row

It is chosen seconds before the workout starts and consumes a full row plus a
`repeatForever` pause-pulse animation. Pause state is carried by the phase word going amber
and the rail's glow stopping.

## 4. Files

### Modify
- **`ShuttlX Watch App/Views/TrainingView+Metrics.swift`**
  - `fullWorkoutDisplayTab`: restructure the non-Mixtape branch into the 5 slots; delete the
    name `HStack`; remove the TIME/CAL two-up (TIME moves nowhere — in interval mode the
    footer stays DIST/PACE; elapsed is available on the controls tab)
  - `intervalCountdownHero`: drop the internal capsule and the `NEXT` row's own layout (NEXT
    becomes the shared optional row)
  - `metricRow` / `compactMetric`: drop `labelWidth`, stack label above value
  - `HRZoneArc`: replace body with tick bars (keep the type name + a11y label)
  - `aodMinimalView`: adopt rail + phase + hero + HR, ≤ 66% opacity
  - Delete `watchTimerTopPadding` / `watchTimerBottomPadding` — both already
    `return 0` unconditionally (dead code)
- **`ShuttlX Watch App/Views/TrainingView.swift`** — remove `pausePulse` state + its
  `.onAppear` if the name row goes

### Create
- **`ShuttlX Watch App/Theme/Themes/Decorations/StepRail.swift`** —
  `StepRail(engine: IntervalEngine)` as an `@ObservedObject` view, mirroring how
  `OverallProgressStrip` and `IntervalStepWash` already isolate engine observation so the
  parent body does not re-evaluate on every manager tick. **Keep that pattern** — it was a
  deliberate perf fix.

### Delete
- `OverallProgressStrip` (superseded). Check for other call sites first.

### Reuse
`ShuttlXColor.forStepType/forHRZone`, `FormattingUtils.formatTimer/formatDistance/formatPace`,
`IntervalStepWash` (keep — it is a background wash, not a progress indicator),
`HeartRateZoneCalculator`, existing banner copy verbatim.

## 5. States

| State | Rail | Phase | Hero | HR | Footer |
|---|---|---|---|---|---|
| Running | current tick glows | step colour | step colour | zone tint | live |
| Paused | glow off | `PAUSED` amber | amber | live | live |
| No HR | normal | normal | normal | `——` + banner | pace `—` |
| HR high | normal | normal | normal | red + all 5 ticks + banner | live |
| Starting | tick 1 only | `WARM UP` | step colour | `——` | `0.00` / `—` |
| Free run | 1 continuous | `ELAPSED` grey | white | live | live |
| AOD | dimmed, no glow | dimmed | 66% white | dimmed | hidden |

## 6. Accessibility / cardiac safety

- **Zone 5 has three non-colour encodings**: all five ticks filled, the numeral, and the
  worded banner. Verify with Differentiate Without Colour.
- Pause is conveyed by the word `PAUSED` and by motion stopping — not by hue alone.
- Keep every existing `accessibilityLabel` string; only visuals change. The rail needs
  `"Step 3 of 8"` and should **not** be `accessibilityHidden` (it replaces the strip that
  carried "Workout progress N percent").
- HR tick bars: `accessibilityHidden(true)`; the numeral keeps
  `"142 beats per minute, Zone 3"` and `.updatesFrequently`.
- Larger watch text sizes: hero uses `minimumScaleFactor(0.5)`; footer 0.6.
- No new haptics. The zone-change haptic is Mixtape-only today; do **not** port it to Clean
  without a product decision (open question).

## 7. Motion budget

| Kept | Trigger | Frequency |
|---|---|---|
| Rail tick fill | step boundary | ~8 / workout |
| `.contentTransition(.numericText())` | value change | free |
| Banner fade | threshold cross | rare |
| Step-change hero transition (existing) | step boundary | ~8 / workout |

| Removed | Was |
|---|---|
| `OverallProgressStrip` linear 1s animation | ~1,800 / workout |
| Hero capsule linear 1s animation | ~1,800 / workout |
| `pausePulse` `repeatForever` | continuous while paused |

No idle animation. No `TimelineView`, no `Canvas`, no gradients in the new code.

---

## Implementation hand-off

- **Files to create:** `ShuttlX Watch App/Theme/Themes/Decorations/StepRail.swift`
- **Files to modify:** `ShuttlX Watch App/Views/TrainingView+Metrics.swift` (`fullWorkoutDisplayTab`, `intervalCountdownHero`, `metricRow`, `compactMetric`, `HRZoneArc`, `aodMinimalView`; delete the two dead padding helpers); `ShuttlX Watch App/Views/TrainingView.swift` (drop `pausePulse`)
- **Files to delete:** `OverallProgressStrip` (in `TrainingView+Metrics.swift`) — verify no other call sites
- **Reuse existing:** `ShuttlXColor.forStepType/forHRZone`; `FormattingUtils.*`; `IntervalStepWash`; `HeartRateZoneCalculator`; the `@ObservedObject`-isolation pattern used by `IntervalStepWash`/`OverallProgressStrip`; all current banner copy and a11y strings
- **Theme variants verified:** 2 themes exist. **Mixtape untouched** (`MixtapeWatchDeck` stays as-is); **Clean** fully specified. Slot 1 (step rail) is the per-theme extension point if a theme is revived. Watch files are in a synchronized folder — no pbxproj edits needed.
- **Watch performance check:** No idle animation. Static `RoundedRectangle` shapes only — no `Canvas`, no `TimelineView`, no gradients. Net animation count **drops** by ~3,600 interpolated updates per 30-min workout (two per-second linear bars removed). 41mm budget verified at 214pt of 215pt in the worst case (banner visible, hero reduced to `h*0.26`, next-chip suppressed) — arithmetic in the mockup.
- **Open questions for dev:**
  1. **> 12 interval steps** — group ticks into 12 proportional buckets, or scroll/compress? Need the real max step count from `WorkoutTemplate`.
  2. Dropping TIME/CAL from the interval footer — is elapsed time reachable enough on the controls tab, or must it stay on the metrics face?
  3. `OverallProgressStrip` — any other call sites (widgets, summary)?
  4. Should Clean adopt Mixtape's zone-change haptic (`handleZoneHaptic`, `.directionUp`, BPM ≥ 105)? It is arguably a *safety* feature and theme-independent, but it changes behaviour for existing Clean users.
  5. `IntervalStepWash` stays — confirm it does not visually fight the step rail once both are on screen.
