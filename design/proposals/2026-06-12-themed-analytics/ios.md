# iOS Hand-off — Themed Analytics Charts (Sprint 2)

**Target file count:** 1 new style file, 1 new renderer file, 1 modified `AppTheme.swift`, 8 modified theme files, 1 modified `AnalyticsView.swift`, 2-3 lightly-touched chart files.
**Target Swift LOC:** ~500.
**Implementer:** `senior-ios-developer`.

---

## 1. `ThemeChartStyle` — the new style struct

Lives at `ShuttlX/Theme/ThemeChartStyle.swift`. Equatable so `AppTheme` stays Equatable.

```swift
import SwiftUI

struct ThemeChartStyle: Equatable {

    // ── Grid ─────────────────────────────────────────────────────────────
    enum GridStyle: String, Equatable {
        case dashed       // Clean — current default
        case solid        // Classic Radio
        case dotted       // Mixtape
        case scanline     // Arcade (horizontal lines, denser)
        case perspective  // Synthwave (converging lines under the chart)
        case gutter       // Neovim (vertical line numbers at left, no horizontal grid)
        case segments     // FM Tuner (faint LCD segment hash marks)
        case none         // VU Meter (the meter face IS the chart)
    }
    let gridStyle: GridStyle
    let gridColor: Color           // theme.colors.surfaceBorder works for most
    let gridOpacity: Double        // typical 0.15 - 0.40

    // ── Bars ─────────────────────────────────────────────────────────────
    enum BarShape: String, Equatable {
        case roundedSwiftCharts   // Clean — keep stock BarMark with cornerRadius
        case neonStroke           // Synthwave — Canvas; fill + 2px glowing stroke
        case pixelBlocks          // Arcade — Canvas; stacked 6×6 chunky pixels
        case lcdSegments          // FM Tuner — Canvas; stacked 4px horizontal segments with gaps
        case tapeStrip            // Mixtape — Canvas; bar w/ horizontal tape-edge stripes
        case dbMeter              // VU Meter — Canvas; horizontal segmented amber bars + red zone
        case blockChars           // Neovim — Canvas; bars built from ▁▂▃▄▅▆▇█ rows
        case needle               // Classic Radio — Canvas; line + needle indicator at value
    }
    let barShape: BarShape

    enum BarFill: String, Equatable {
        case solid
        case gradientVertical     // current default — 0.8 → 0.4
        case glow                 // solid + outer blur (Synthwave/Arcade peak)
        case stepped              // VU Meter segments
    }
    let barFill: BarFill

    // ── Lines / area ─────────────────────────────────────────────────────
    enum LineStyle: String, Equatable {
        case smoothArea      // Clean — current LineMark + AreaMark catmullRom
        case glowSmooth      // Synthwave — same shape + glow halo
        case stepped         // Neovim, FM Tuner — interpolationMethod(.stepCenter)
        case needleTip       // Classic Radio — line + needle pointer at latest value
    }
    let lineStyle: LineStyle

    /// Whether the line chart gets a soft glow halo behind the stroke.
    /// Implemented as a second LineMark with .blur and increased lineWidth.
    let lineGlow: Bool

    // ── Point markers (line chart) ───────────────────────────────────────
    enum PointMarker: String, Equatable {
        case circle           // Clean default
        case diamond          // Synthwave
        case square           // Arcade
        case none             // FM Tuner, Neovim
        case brassDot         // Classic Radio
    }
    let pointMarker: PointMarker

    // ── Axis labels ──────────────────────────────────────────────────────
    enum AxisLabelStyle: String, Equatable {
        case system           // Clean — current microLabel
        case monospaced       // Synthwave, FM Tuner, Arcade
        case sevenSegment     // Arcade — labels styled like LCD digits (use existing monospaced + tracking)
        case lineNumber       // Neovim — right-aligned grey numbers in gutter
        case lcdSubtitle      // FM Tuner — cyan all-caps with bullet separators
    }
    let axisLabelStyle: AxisLabelStyle
    let axisLabelColor: Color
    let axisLabelTracking: CGFloat   // 0 for Clean, 1-2 for monospaced themes

    // ── Accent / highlight ───────────────────────────────────────────────
    /// Highlight applied to the maximum bar / latest data point. The renderer
    /// uses this to draw a "peak" marker, a brighter top, or a red-zone segment.
    let accentColor: Color
    let highlightPeak: Bool          // draws marker on max value bar/point

    // ── Signature accent flag ────────────────────────────────────────────
    /// When true, the renderer calls the theme's signature accent decorator
    /// (a single optional hook per theme — see section 4). When false, the
    /// chart uses pure parameters only. Used to keep the spec tight while
    /// still letting 1-2 themes earn their distinctive flourish.
    let signatureAccent: Bool
}
```

**Composition into `AppTheme`:**

```swift
// AppTheme.swift — add one stored field:
let chartStyle: ThemeChartStyle
```

This is the **only** edit needed in `AppTheme.swift` (plus updating the
memberwise call site each theme uses).

---

## 2. Per-theme value table

Read across rows for the full configuration of each theme.

| Theme        | gridStyle    | barShape          | barFill          | lineStyle    | lineGlow | pointMarker | axisLabelStyle | accentColor                       | highlightPeak | signatureAccent |
|--------------|--------------|-------------------|------------------|--------------|----------|-------------|----------------|------------------------------------|---------------|-----------------|
| Clean        | `dashed`     | `roundedSwiftCharts` | `gradientVertical` | `smoothArea` | false    | `circle`    | `system`       | `colors.running`                   | false         | false           |
| Synthwave    | `perspective`| `neonStroke`      | `glow`           | `glowSmooth` | true     | `diamond`   | `monospaced`   | `colors.steps` (cyan)              | true          | true            |
| Mixtape      | `dotted`     | `tapeStrip`       | `solid`          | `smoothArea` | false    | `circle`    | `monospaced`   | `colors.running`                   | false         | true            |
| Arcade       | `scanline`   | `pixelBlocks`     | `glow`           | `stepped`    | true     | `square`    | `sevenSegment` | `colors.heartRate` (player-red)    | true          | true            |
| ClassicRadio | `solid`      | `needle`          | `solid`          | `needleTip`  | false    | `brassDot`  | `system`       | `colors.pace` (brass)              | true          | true            |
| VU Meter     | `none`       | `dbMeter`         | `stepped`        | `stepped`    | false    | `none`      | `monospaced`   | `colors.heartRate` (red zone)      | true          | true            |
| Neovim       | `gutter`     | `blockChars`      | `solid`          | `stepped`    | false    | `none`      | `lineNumber`   | `colors.running` (Gruvbox green)   | false         | true            |
| FM Tuner     | `segments`   | `lcdSegments`     | `stepped`        | `stepped`    | false    | `none`      | `lcdSubtitle`  | `colors.ctaPrimary` (cyan)         | true          | false           |

**Notes on column choices:**

- `accentColor` is intentionally a token, not a literal — when the user picks an alternate base color in a future theme variant, the chart highlight follows.
- `gridColor` / `gridOpacity` are not in the table to keep it readable; defaults:
  - Clean: `colors.surfaceBorder, 0.30`
  - Synthwave: `colors.steps, 0.25`
  - Mixtape: `colors.textSecondary, 0.20`
  - Arcade: `colors.running, 0.18`
  - Classic Radio: `colors.surfaceBorder, 0.40`
  - VU Meter: unused (none)
  - Neovim: `Color(hex 0x504945), 0.50` (Gruvbox bg2)
  - FM Tuner: `colors.ctaPrimary, 0.15`
- `axisLabelColor` defaults to `colors.textSecondary` for all themes; Neovim overrides to `Color(hex 0x665C54)` (Gruvbox bg3) to match a real gutter.
- `axisLabelTracking`: 0 for Clean & Classic Radio; 1.0 for Mixtape, Neovim; 1.5 for Synthwave, FM Tuner; 2.0 for Arcade.

---

## 3. Per-chart routing

The Analytics tab currently renders 4 charts inline + 1 horizontal HR-zone-style
bar (pace zones). Routing strategy: **keep Swift Charts wherever Clean still
looks right; route to the parameterized Canvas renderer when the theme demands
a non-Swift-Charts geometry.**

| Chart in `AnalyticsView.swift`         | Lines     | Swift Charts kept for                 | Canvas renderer used for                            |
|----------------------------------------|-----------|---------------------------------------|-----------------------------------------------------|
| Fitness Trend (line + area, weekly)    | ~152-209  | Clean, Mixtape, Classic Radio         | Synthwave (glow), Arcade, VU Meter, Neovim, FM Tuner|
| Weekly Volume (vertical bar, 6 weeks)  | ~213-272  | Clean                                 | All 7 other themes                                  |
| Pace Zones (horizontal % bars)         | ~402-447  | Clean, Mixtape, Classic Radio         | Synthwave, Arcade, VU Meter, Neovim, FM Tuner       |
| `WeeklyDistanceChart.swift` (7-day)    | full file | Clean                                 | All 7 other themes                                  |
| `HRZoneChart.swift` (horizontal %)     | full file | Clean, Mixtape                        | Synthwave, Arcade, Classic Radio, VU Meter, Neovim, FM Tuner |
| `WeekStripView.swift` (day chips)      | full file | Clean (current pill+dot)              | Mixtape (spool decoration), others keep Clean look  |
| `PaceTrendChart.swift`                 | unknown   | Read & follow Fitness-Trend routing   | (Apply same rule based on lineStyle)                |

**The dispatch:** each chart is wrapped by a single new view, `ThemedBarChart`
or `ThemedLineChart`, which inspects `themeManager.current.chartStyle.barShape`
(or `.lineStyle`). If `roundedSwiftCharts` / `smoothArea`, it renders the
existing Swift Charts code (parameterized for color from `chartStyle.accentColor`).
Otherwise, it renders the Canvas path.

This means **the existing Swift Charts code in `AnalyticsView.swift` is not
deleted** — it's wrapped by a conditional that swaps in the Canvas renderer.
Less risk, smaller diff, no regression for Clean users (the default).

---

## 4. Per-theme signature accent (single hook per theme)

For 6 themes, one Canvas-based flourish is layered on top of the parameterized
renderer. Effort is sized small (S = <30 lines) or medium (M = 30-80 lines).

| Theme         | Accent                                                                                              | Where                                       | Effort |
|---------------|-----------------------------------------------------------------------------------------------------|---------------------------------------------|--------|
| Synthwave     | Perspective grid backdrop (3-point vanishing) drawn behind the chart frame, fading toward horizon   | Behind `Chart {}` in fitness trend + weekly | M      |
| Mixtape       | `WeekStripView` day cells render as tiny tape spools (2 concentric circles + 6 hole dots) when count > 0 | `WeekStripView.swift`                       | M      |
| Arcade        | Bar tops drawn as 2 stacked 7-segment-style "blocks" — top block is the bar's "highlight tier"; bottom dim     | `ThemedBarChart` when `barShape == .pixelBlocks`           | S      |
| Classic Radio | Pace trend line ends in a brass "needle" pointer that visually sweeps from the last data point to the current value at the right edge | Fitness trend & PaceTrendChart              | M      |
| VU Meter      | `HRZoneChart` and Pace Zones render as horizontal dB-meter strips: 14 segments per bar, segments past ~0dB position glow red (zone 4-5) | `HRZoneChart.swift` + pace zones            | M      |
| Neovim        | Axis labels render as Gruvbox grey right-aligned line numbers ` 1`, ` 2`, ` 3` … in a gutter strip; bars drawn with block characters `▁▂▃▄▅▆▇█` as `Text` columns | `ThemedBarChart` when `barShape == .blockChars` | M      |
| Clean         | (none — calm baseline is the accent)                                                                | —                                           | —      |
| FM Tuner      | (uses existing chrome — signal-dot density above max bar handled inside renderer, not as a separate hook) | `ThemedBarChart` when `barShape == .lcdSegments` | included |

The accent decorators live as `@ViewBuilder` extensions on the relevant chart
views, gated by `themeManager.current.id == "..."`. Same pattern Sprint 1 used
for timer hero dispatch — see `iPhoneWorkoutTimerView.themedTimerBody`.

---

## 5. ASCII mockups

### Weekly Volume bar chart — current (Clean baseline)

```
┌─────────────────────────────────────────┐
│ Weekly Volume                           │  ← ShuttlXFont.cardTitle
│                                         │
│ 120m ┤  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │  ← AxisGridLine dashed 4pt
│      │                       ┌──┐       │
│  90m ┤ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │██│ ─ ─ ─ │
│      │             ┌──┐      │██│       │
│  60m ┤ ─ ─ ┌──┐ ─ ─│██│ ┌──┐ │██│ ─ ─ ─ │
│      │     │██│    │██│ │██│ │██│       │
│  30m ┤ ─ ─ │██│ ─ ─│██│ │██│ │██│ ┌──┐ ─│  ← bars: 0.8→0.4 vertical gradient, cornerRadius 4
│      │     │██│    │██│ │██│ │██│ │██│  │
│       ─────┴──┴────┴──┴─┴──┴─┴──┴─┴──┴──│
│        W22  W23  W24  W25  W26  W27     │
└─────────────────────────────────────────┘
```

### Weekly Volume — Arcade variant (pixelBlocks + scanline grid + sevenSegment labels)

```
┌─────────────────────────────────────────┐
│ ★ WEEKLY VOLUME ★                       │  ← phosphor green, tracking 2
│                                         │
│ ╶─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ╴│  ← scanline grid (denser horizontal)
│ ╶─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ╴│
│ 120 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
│ ╶─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ █ ─ ─ ─ ─ ╴│  ← ▓ = bright peak block (highlight tier)
│                              ▓▓         │
│  90 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─██─ ─ ─ ─ ─│
│                  ██          ██         │
│  60 ─ ─ ─ ──── ─ ██─ ── ─ ──██──── ─ ─ ─│  ← bars built from 6×6 pixel blocks (no smooth fill)
│           ██     ██    ██    ██         │
│  30 ─ ─ ──██── ─ ██─ ──██────██──── ─ ─█│
│           ██     ██    ██    ██     ██  │
│       ──────────────────────────────────│
│        W22  W23  W24  W25  W26  W27     │  ← 7-segment label tracking, phosphor dim
└─────────────────────────────────────────┘
                                  ★ HI ★    ← peak marker (signatureAccent)
```

Per-bar block construction: bar height H, block size 6pt, gap 1pt. Top
block of the tallest bar uses `accentColor` at full opacity (player-red).
All other blocks of every bar use `colors.running` (phosphor green) at
0.85 opacity.

### Weekly Volume — Synthwave variant (neonStroke + perspective grid)

```
┌─────────────────────────────────────────┐
│ WEEKLY VOLUME                           │  ← monospaced bold, tracking 1.5
│                                         │
│       ┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┐         │
│      /  ╲╲                  ╱╱ ╲        │  ← perspective grid (signatureAccent)
│     /    ╲╲                ╱╱   ╲       │     drawn behind bars, fades to horizon
│    / 120  ╲╲    ┌╌╌╌╌╮    ╱╱     ╲      │
│   /        ╲╲   ┊  ◇┊   ╱╱       ╲     │  ← ◇ = diamond point marker on peak top
│  /          ╲╲  ┊████┊  ╱╱         ╲    │
│ /  90    ┌╌╌╌╲╲ ┊████┊╱╱╌╌╌╮        ╲   │  ← bars: cyan fill 0.30 + 2px cyan stroke + outer blur
│/         ┊◇  ╲╲ ┊████┊╱╱   ┊         ╲  │     (glow on top edge = bar fill)
│          ┊█████┊┊████┊┊████┊            │
│  60      ┊█████┊┊████┊┊████┊            │
│   ╲      ┊█████┊┊████┊┊████┊       ╱    │
│    ╲ 30  ┊█████┊┊████┊┊████┊┌╌╌╌╮ ╱     │
│     ╲    ┊█████┊┊████┊┊████┊┊◇█┊╱       │
│      ─────────────────────────────      │
│        W22  W23  W24  W25  W26  W27     │  ← cyan monospaced, tracking 1.5
└─────────────────────────────────────────┘
```

### Weekly Volume — VU Meter variant (dbMeter horizontal segments)

VU Meter inverts orientation: bars are horizontal segmented dB strips, like
audio channels stacked. Most theme-distinctive of the eight.

```
┌─────────────────────────────────────────┐
│ ▼ WEEKLY VOLUME              [ -7 dB ]  │  ← amber on cream face, [peakHold] tag
│                                         │
│       -20    -10  -7 -3  0  +3          │  ← dB scale (read across all bars)
│        │      │   │  │   │   │          │
│ W22 ▕▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░▕   ▕  ▕      │  ← amber segments, dim past last value
│ W23 ▕▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░▕▒░▕░▕        │  ← past 0dB enters red zone (highlight)
│ W24 ▕▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░▕   ▕  ▕      │
│ W25 ▕▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░▕▒▒▕▒▕  ←PEAK │  ← peak marker (signatureAccent)
│ W26 ▕▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░▕   ▕  ▕      │     red zone segments glow
│ W27 ▕▒▒▒▒▒░░░░░░░░░░░░░░░░▕   ▕  ▕      │
│        │      │   │  │   │   │          │
│      brass screws at corners            │  ← reuse VUMeterTimerHero screws (small set)
└─────────────────────────────────────────┘
```

### Weekly Volume — Neovim variant (blockChars + gutter line numbers)

```
┌─────────────────────────────────────────┐
│ -- ANALYTICS --                         │  ← Gruvbox green status mode
│ analytics/weekly_volume.json            │
│                                         │
│    1 │                          ▇       │  ← line numbers in gutter (lineNumber labels)
│    2 │                          ▇       │
│    3 │              ▆           ▇       │  ← bars as block-character columns
│    4 │              ▆     ▆     ▇     ▃ │     using ▁▂▃▄▅▆▇█
│    5 │   ▄          ▆     ▆     ▇     ▃ │
│    6 │   ▄          ▆     ▆     ▇     ▃ │
│    7 │   ▄    ▃     ▆     ▆     ▇     ▃ │  ← color: colors.running (Gruvbox green #B8BB26)
│    8 │   ▄    ▃     ▆     ▆     ▇     ▃ │
│      │ W22  W23   W24   W25   W26   W27 │  ← Gruvbox bg3 grey, monospaced
│                                         │
│ :w weekly.json                  [W27,3] │  ← optional command line at bottom (reuse status pattern)
└─────────────────────────────────────────┘
```

### Fitness Trend line chart — Synthwave variant (glowSmooth)

```
┌─────────────────────────────────────────┐
│ TRAINING LOAD                           │
│                                         │
│ 120 ┊                              ╱◇   │  ← ◇ = diamond marker (pointMarker)
│     ┊                          ╱──╱     │     line: cyan stroke 2pt + outer blur 8pt
│     ┊                       ╱──         │     area below: cyan 0.20 → 0.04 vertical
│  90 ┊            ◇──╲    ╱──            │     (glowSmooth = same shape as Clean + glow)
│     ┊         ╱──    ╲╲──               │
│     ┊      ╱──         ╲                │
│  60 ┊  ◇──             ◇──╲             │
│     ┊╱──                                │
│  30 ┊                                   │
│     └─────────────────────────────────  │
│       W22  W23  W24  W25  W26  W27      │
└─────────────────────────────────────────┘
```

---

## 6. Empty / loading states (one parametric approach)

Today's empty state (`AnalyticsView.swift` lines 69-88) shows
`Image(systemName: "chart.line.uptrend.xyaxis")` and a "No Data Yet" message.
**Keep that view** — empty Analytics applies to the whole tab, so it never
reaches per-chart styling.

For **per-chart empty / loading** (e.g. fitness trend has data but pace zones
do not), use a single parameterized empty pattern keyed off `barShape`:

| Theme         | Per-chart empty rendering                                                |
|---------------|--------------------------------------------------------------------------|
| Clean         | Grey skeleton bars + "Not enough data" centered in the chart frame       |
| Synthwave     | Cyan outlined skeleton bars (no fill) + "NO SIGNAL" in monospaced cyan   |
| Mixtape       | "▶ SIDE B UNREC ▶" pseudo-tape label                                     |
| Arcade        | "PRESS START ► RECORD 1 RUN" in phosphor green, blinking via TimelineView|
| Classic Radio | Brass-bordered empty card, "TUNE IN — record a workout"                  |
| VU Meter      | Meter face with needle pinned to -20 dB, "NO SIGNAL"                     |
| Neovim        | `-- INSERT --` status line + "// no data" comment in gutter              |
| FM Tuner      | "─ NO STATION ─" between cyan segment chevrons                           |

Loading (analytics recompute task is still running): all themes show a single
shimmer animation on the chart frame at 1 Hz — keep this as one `.shimmer()`
helper modifier rather than per-theme custom loaders. Cardiac patients
should never see chart elements "twitch" — the 1 Hz shimmer is well below
flicker-fusion concern and respects `reduceMotion`.

---

## 7. Accessibility

The 1-card-1-summary pattern already in `AnalyticsView.swift` carries over.
Specifically:

1. **Every chart card** keeps `.accessibilityElement(children: .combine)` and
   gets a `.accessibilityLabel` containing the **numeric summary** of the data,
   never a description of the visual style. Example for Arcade weekly volume:
   `"Weekly training volume: 6 weeks. W22 45 minutes, W23 62 minutes, ..."`
   The label is generated from the same data the renderer receives, not from
   chart visuals.
2. **Canvas-rendered bars are `.accessibilityHidden(true)`** — they are
   decoration; the card-level summary is the truth.
3. **Dynamic Type** — axis labels use `ShuttlXFont.microLabel` today
   (`.system(size: 9, design: .monospaced)` in Synthwave). This is below the
   Dynamic Type floor at the largest sizes. Required change:
   - Wrap each axis label `Text` with `.minimumScaleFactor(0.8)` (Canvas-drawn
     labels skip this — they're already sized to draw geometry).
   - For Neovim line-number gutter and Arcade 7-segment labels, do **not**
     scale Dynamic Type up — they are graphic glyphs. Mark with
     `.accessibilityHidden(true)` and let the card-level summary speak.
4. **Clean stays calm** — the cardiac-rehab baseline. No glow, no blink, no
   animated bars on Clean. Verified by `barShape == .roundedSwiftCharts &&
   lineStyle == .smoothArea && lineGlow == false`.
5. **`reduceMotion` respected** — Arcade "PRESS START" blink and any
   shimmer / glow pulse already check `@Environment(\.accessibilityReduceMotion)`
   (pattern from `ArcadeTimerHero.swift` and `VUMeterTimerHero.swift`).
6. **Contrast** — `axisLabelColor` defaults match each theme's existing
   `textSecondary`, which the design-system rules require to clear 4.5:1
   against `background`. Implementer must verify Neovim gutter grey
   (`#665C54`) on `#1D2021` — comes to ~4.6:1, passes by a hair.

---

## Implementation hand-off

- **Files to create:**
  - `ShuttlX/Theme/ThemeChartStyle.swift` — the struct (section 1)
  - `ShuttlX/Views/Charts/ThemedBarChart.swift` — the parameterized Canvas bar renderer + Swift Charts wrapper
  - `ShuttlX/Views/Charts/ThemedLineChart.swift` — the parameterized Canvas line renderer + Swift Charts wrapper
  - `ShuttlX/Views/Charts/Accents/SynthwavePerspectiveGrid.swift` — perspective grid backdrop (signature accent)
  - `ShuttlX/Views/Charts/Accents/VUMeterDBStrip.swift` — horizontal dB segment strip (signature accent for HRZoneChart & pace zones)
  - `ShuttlX/Views/Charts/Accents/ClassicRadioNeedlePointer.swift` — brass needle for trend chart (signature accent)
  - `ShuttlX/Views/Charts/Accents/MixtapeSpoolDot.swift` — tape-spool day chip for WeekStripView (signature accent)
- **Files to modify:**
  - `ShuttlX/Theme/AppTheme.swift` — add `let chartStyle: ThemeChartStyle`
  - `ShuttlX/Theme/Themes/CleanTheme.swift` — add `chartStyle: ThemeChartStyle(...)` per table row 1
  - `ShuttlX/Theme/Themes/SynthwaveTheme.swift` — row 2
  - `ShuttlX/Theme/Themes/MixtapeTheme.swift` — row 3
  - `ShuttlX/Theme/Themes/ArcadeTheme.swift` — row 4
  - `ShuttlX/Theme/Themes/ClassicRadioTheme.swift` — row 5
  - `ShuttlX/Theme/Themes/VUMeterTheme.swift` — row 6
  - `ShuttlX/Theme/Themes/NeovimTheme.swift` — row 7
  - `ShuttlX/Theme/Themes/FMTunerTheme.swift` — row 8
  - `ShuttlX/Views/AnalyticsView.swift` — replace inline `Chart {}` blocks for fitness trend & weekly volume with `ThemedLineChart(...)` / `ThemedBarChart(...)`; replace pace-zone bars with `VUMeterDBStrip` when `barShape == .dbMeter`, else current GeometryReader path
  - `ShuttlX/Views/Charts/WeeklyDistanceChart.swift` — wrap `Chart {}` in `ThemedBarChart`
  - `ShuttlX/Views/Charts/HRZoneChart.swift` — same pattern + `VUMeterDBStrip` accent branch
  - `ShuttlX/Views/Charts/PaceTrendChart.swift` — wrap in `ThemedLineChart`
  - `ShuttlX/Views/Charts/WeekStripView.swift` — Mixtape `MixtapeSpoolDot` accent branch (gated on theme id)
- **Reuse existing:**
  - `ShuttlXColor.*` / `ShuttlXFont.*` bridge enums (do **not** hardcode colors)
  - `.themedCard(...)` modifier — no changes to card chrome
  - `.themedScreenBackground()` — no changes
  - Canvas rendering pattern from `ArcadeTimerHero.swift` (pixel boxes, 7-segment helpers)
  - Brass screw decoration from `VUMeterTimerHero.swift` (lines 561-600)
  - `TimelineView` pattern for any blink / shimmer (matches Sprint 1 conventions)
  - `FormattingUtils` for any numeric formatting
- **Theme variants verified:**
  - All 8 themes have a row in the table (section 2)
  - Clean explicitly keeps Swift Charts — no regression, no animations, cardiac baseline preserved
  - Per-theme adjustments documented as `signatureAccent: true` on 6 themes; Clean and FM Tuner sit on pure parameters (FM Tuner's LCD segments are dramatic enough on their own; Clean's calmness is the feature)
  - VU Meter chart geometry is the most divergent (inverted horizontal bars) — verify that `WeeklyDistanceChart` looks usable when `barShape == .dbMeter`. May need a min-height override of 200pt instead of 160pt; flagged for visual QA
  - Synthwave perspective grid uses `Canvas` (same approach as the existing `synthwaveHorizonBackground` modifier) — verify performance on iPhone 12 baseline (target: 60fps scrolling through Analytics)
- **Open questions for dev:**
  1. `PaceTrendChart.swift` was not read during spec authoring — verify its
     current line-chart shape matches the Fitness Trend pattern; if it uses
     a different mark type, route it through `ThemedLineChart` the same way.
  2. The accent decorators are `@ViewBuilder` extensions gated by
     `themeManager.current.id`. Do you prefer a `ThemeChartStyle.signatureAccentID:
     String?` field instead, so the gating is driven by the style struct
     not the theme id string? Either works — the id-string approach matches
     Sprint 1's `themedTimerBody` pattern in `iPhoneWorkoutTimerView`, so the
     default recommendation is to keep using string gating for consistency.
  3. Pace Zones currently uses a `GeometryReader` + `RoundedRectangle` (not
     Swift Charts). The spec routes 5 themes to the new `VUMeterDBStrip` /
     similar Canvas paths — confirm that's worth it vs. just restyling the
     `RoundedRectangle` per-theme. Recommendation: keep `RoundedRectangle`
     for Clean/Mixtape/Classic Radio/FM Tuner; use Canvas for Arcade (pixel
     blocks across the full width), Synthwave (neon stroke), VU Meter (dB
     segments), Neovim (block characters spelled `█████░░░ 60%`).
  4. Should the per-chart "loading" shimmer be a true `.shimmer()` modifier,
     or a single `Rectangle().fill(.linearGradient).mask()` inline? No
     existing shimmer infra in the codebase — quickest win is inline. Flag
     for dev preference.
