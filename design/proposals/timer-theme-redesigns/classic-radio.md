# Classic Radio Timer — 1960s Wood-Cabinet Tube Radio

## 1. Hero concept

The largest element is a **horizontal tuning dial** spanning the screen — cream-colored celluloid scale, hand-printed amber tick marks, and a vertical **red pointer needle** that sweeps left-to-right as the workout progresses. The tick numbers are **time stamps** instead of MHz: `00 · 05 · 10 · 15 · 20 · 25 · 30` (minutes). The elapsed time is also printed as a small backlit numeric readout in the dial's frame, lit by a warm valve glow. Interval mode: each step gets its own "station name" printed on the dial (`WORK · REST · WORK · REST · ...`) and the needle parks on the current one.

```
   ┌──────────────────────────────────┐
   │   ⊙ SHUTTLX · BAND: INTERVAL    │  ← brand plate
   │  ╔══════════════════════════════╗ │
   │  ║ 00  05  10▼ 15  20  25  30  ║ │  ← tuning dial w/ needle
   │  ║ ─────WORK─────REST───WORK── ║ │
   │  ╚══════════════════════════════╝ │
   │       ╭──────╮         03:24      │  ← amber readout
   │       │ ◉◉◉◉ │    ← valve glow    │
   │       ╰──────╯                    │
   │  TONE         VOLUME         BAND │  ← knobs (metrics)
   │  142 BPM      5:42/KM        1.84 │
   └──────────────────────────────────┘
```

## 2. Secondary metrics layout

Three **bakelite knobs** at the bottom, each labeled like a real radio knob:
- **TONE** = Heart Rate (knob rotates by zone; Z1 = 7 o'clock, Z5 = 5 o'clock; amber pilot light brightens with intensity).
- **VOLUME** = Pace (knob rotation maps to pace vs target — louder = faster).
- **BAND** = Distance (the knob is segmented like a band-selector switch; clicks one notch per km).

## 3. Background composition

Existing `classicRadioBackground` (warm brown grain + vignette) stays. Add a **subtle valve-glow radial gradient** behind the readout that pulses on each HR beat — the glow is amber `Color(red: 1.0, green: 0.7, blue: 0.3)` at 12% opacity max, so it never crushes contrast. The grain texture already conveys "wood cabinet".

## 4. SwiftUI primitives

- `Canvas` — the tuning dial: tick marks, station labels, and the red needle. Needle X-position = `elapsedTime / plannedDuration`.
- `Canvas` — each knob (circle + pointer line + ring of tick marks); rotation maps to its metric.
- `TimelineView(.animation(minimumInterval: 1/8))` — pulses the valve glow on each detected HR beat (debounced by `heartRateMonitor`).
- `ZStack` — brand plate (top), dial, readout strip, knob row.

## 5. Reuse note

Drive the needle off `controller.elapsedTime / controller.plannedDuration` (already computable from `intervalEngine.totalDuration` in interval mode, or the planned freeRun duration). Knobs read `heartRateMonitor.current`, `controller.currentPace`, `controller.totalDistance` directly. The "station labels" on the dial come straight from `intervalEngine.steps[i].type`.
