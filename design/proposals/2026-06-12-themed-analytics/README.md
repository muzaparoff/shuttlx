# Sprint 2 — Themed Analytics Charts

**Date:** 2026-06-12
**Status:** Spec ready for implementation
**Scope:** iOS only — Analytics tab does not exist on watchOS, so there is no `watch.md` in this proposal.
**Predecessor:** Sprint 1 (Timer Hero redesigns) closed out 2026-04 → 2026-05.

---

## The problem

A design audit scored ShuttlX as follows:

| Area              | Score | Note                                                        |
|-------------------|-------|-------------------------------------------------------------|
| Timer screens     | 9/10  | Per-theme heroes; signature shapes; unmistakable identity   |
| Everything else   | 4/10  | Generic — biggest tell is **stock Swift Charts**            |

The Analytics tab (`ShuttlX/Views/AnalyticsView.swift` + `ShuttlX/Views/Charts/*.swift`)
renders **identical chart geometry across all 8 themes**:

- Same `AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))`
- Same `BarMark(...).cornerRadius(4)` with a 0.8 → 0.4 LinearGradient
- Same `LineMark + AreaMark + .symbol(.circle)` for the load trend
- Same `RoundedRectangle(cornerRadius: 4)` horizontal bars for pace zones
- Same `Text` axis labels — no theme typography

Result: Synthwave Analytics looks like Clean Analytics with cyan accents.
Arcade Analytics has zero pixel-art identity. Neovim Analytics has zero
terminal identity. The visual language stops at the card chrome.

## What "good" looks like

Every theme has an established **Signature Shape DNA** from Sprint 1's timer heroes.
The charts must inherit that vocabulary:

| Theme         | DNA (from timer hero)                                   | Chart translation                                     |
|---------------|---------------------------------------------------------|-------------------------------------------------------|
| Clean         | Glass card, soft mesh, system fonts                     | Stock Swift Charts, calm gradients, rounded bars      |
| Synthwave     | Perspective grid, neon glow, cyan/magenta phosphor      | Glowing line, neon stroke bars, perspective backdrop  |
| Mixtape       | Tape spools, blue body, magnetic tape texture           | Bars as tape-edge strips, week strip days as spools   |
| Arcade        | 7-segment digits, pixel borders, INSERT COIN blink      | Pixel-block bars (▇▆▅), 7-segment axis labels         |
| Classic Radio | Sweeping needle, warm brown grain, brass accents        | Pace trend as needle-style indicator, brown panel     |
| VU Meter      | Analog needle arc, dB scale ticks, peak-hold LED        | HR zones as horizontal dB-meter strips, amber face    |
| Neovim        | Gruvbox palette, gutter, modal `:command` status        | Block-character bars `▁▃▅▇`, gutter line numbers      |
| FM Tuner      | Navy LCD, cyan monospaced, signal segments              | LCD segment-stack bars, signal-dot density            |

## Constraint: solo dev, one focused session

I am not building 5 charts × 8 themes of bespoke code. That's 40 renderers
and a maintenance nightmare. The spec uses a **parameterized** approach:

1. **One** new style struct, `ThemeChartStyle`, sits alongside `ThemeColors` /
   `ThemeFonts` / `ThemeEffects` inside `AppTheme`. ~10 fields.
2. Each existing theme adds a single `ThemeChartStyle(...)` value.
3. Where Swift Charts can express the style (foregroundStyle, AxisMarks,
   StrokeStyle), it stays. Where it cannot (pixel blocks, LCD segments, neon
   glow halo, block-character bars), **one** shared Canvas-based renderer
   reads the style and draws the bars.
4. **One** optional "signature accent" hook per theme — the highest-impact
   detail — keeps the spec from devolving into pure parameters.

The result is one new style struct + one parameterized Canvas renderer + 8
table-row config entries + at most 6 small accent decorators. Total target:
**~400-600 lines of new Swift**, implementable in one focused session.

## Hand-off

- iOS spec: see `ios.md` in this folder.
- No watch spec — analytics is iPhone only (`AnalyticsView.swift` lives in
  `ShuttlX/Views/`, no equivalent under `ShuttlX Watch App/Views/`).
- Implementer: `senior-ios-developer`.

## Mood references (inspiration, not literal)

- **Strava** weekly volume bars — clean, but stops at "clean"
- **NuStep T5XR console** — physical analog meters with red zones (drives VU Meter chart aesthetic)
- **vim-airline** statuslines + block characters in TUI charts (drives Neovim chart aesthetic)
- **Tandy TRS-80 / Galaga score readout** — chunky pixel bars (drives Arcade chart aesthetic)
- **Roland TR-808 LED step grids** — LCD column blocks (drives FM Tuner chart aesthetic)
- **Yamaha hi-fi spectrum analyzers** — vertical bar segments with peak-hold

## Why this scoring threshold

The audit said "everything else 4/10". The success criterion for this
sprint is: a designer looking at a screenshot of the Analytics tab **without
seeing the rest of the app** can name the theme within 3 seconds. Today:
impossible. Target: 7 of 8 themes pass that test.
