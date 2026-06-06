# VU Meter Timer — Analog Audio Meter

## 1. Hero concept

The hero is a **large analog VU meter** — cream/ivory face, hand-painted scale arc, black needle, amber backlight. But this VU meter measures **heart rate**, not audio: scale runs from 60 → 200 BPM with the standard VU "0 dB" tick replaced by the user's target zone midpoint. The needle swings in real time. Above the arc, the **elapsed time** is printed in a small recessed "minute counter" rectangle below the scale, like the cumulative counter on a reel-to-reel. Interval step countdown gets a second smaller needle that ticks down the current step.

```
   ┌───────────────────────────────┐
   │      ╱─────────────╲          │
   │    60   80  100  120  140 200 │  ← scale arc
   │   ╲      ZONE     PEAK ▶ ╱    │
   │    ╲────────●──────────╱      │  ← needle pivot
   │           PEAK 168            │
   │         ┌────────────┐        │
   │         │  ELAPSED   │        │
   │         │   03:24    │        │  ← recessed counter
   │         └────────────┘        │
   │  ◀STEP 02:12    DIST 1.84KM▶  │  ← side strips
   └───────────────────────────────┘
```

## 2. Secondary metrics layout

- **Peak indicator** — small red LED dot above the scale that latches at the session's peak HR (resets only on workout end). This is the "peak hold" feature of a real VU meter.
- **Elapsed time** — recessed rectangle below the pivot, monospaced.
- **Step remaining** — left side strip (small secondary needle gauge or just numeric).
- **Distance** — right side strip.
- **Pace** — printed as a small "rec level" caption under the arc (`-3 dB · 5:42/km`).

## 3. Background composition

Existing `vuMeterBackground` (amber glow + panel lines) stays. The meter face is a `.themedCard()` with `.meter` CardStyle. Add **subtle screw-head dots in the four corners** of the meter face (just `Circle().fill(.gray).frame(width: 6)`) for verisimilitude.

## 4. SwiftUI primitives

- `Canvas` — draws the scale arc (60–200), tick marks, numeric labels along the curve, and both needles.
- `TimelineView(.animation(minimumInterval: 1/30))` — smooth needle interpolation between HR updates (real VU needles have ~300 ms ballistics; mimic with a `.spring(response: 0.3, dampingFraction: 0.6)` animation on the needle angle).
- `ZStack` — meter face card, recessed counter rectangle (use inset `RoundedRectangle` with inner shadow gradient), peak LED.
- `@State private var peakHR: Int` — local state for peak-hold; resets when `controller.elapsedTime` resets to 0.

## 5. Reuse note

Needle angle = `lerp(60, 200, heartRateMonitor.current)`. Step countdown needle = `intervalEngine.currentStepTimeRemaining / currentStep.duration`. Elapsed counter = `FormattingUtils.formatTimer(controller.elapsedTime)`. No workout-logic changes — pure presentation swap.
