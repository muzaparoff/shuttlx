# Synthwave Timer — Outrun Speedometer

## 1. Hero concept

The timer becomes the **digital dash readout of a 1984 sports car blasting down a neon highway**. The largest element is the elapsed time, but it sits *inside* a chevroned trapezoidal frame painted in cyan/magenta neon — the kind of readout you'd see between the steering-wheel spokes in an arcade racer. Behind it the **perspective grid scrolls toward the horizon** at a speed proportional to current pace: faster pace = grid lines move faster. A neon sun sits behind the timer as a backlight halo.

```
       ___________________________
      /  ▼      03:24.7      ▼   \
     /═══════════════════════════ \
    /   ▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱    \
   /_____________________________ \
         ║         ║          ║
       142 BPM   5:42/km    1.84 km
       Z3 ▲▲     PACE       DIST
```

## 2. Secondary metrics layout

- **HR** — left "gauge" — needle is a vertical neon bar that grows; zone color drives the neon hue (Z3 magenta, Z5 white-hot).
- **Pace** — center, also styled as a digital readout, but with **chevron arrows** that animate left-to-right when faster than target.
- **Distance** — right, with a tiny "odometer" tick animation on each 100 m.
- **Step/interval pill** sits on the top edge of the trapezoid like a destination sign ("WORK · 02:12").

## 3. Background composition

Existing `synthwaveHorizonBackground` already paints the grid + sun. We just **animate the grid's scroll offset** off `controller.currentPace` and add a magenta haze gradient at the horizon line that pulses on each HR beat.

## 4. SwiftUI primitives

- `Canvas` — trapezoidal frame with chevron tick marks; grid scroll animation driven by `TimelineView(.animation)` so the horizon moves with the workout.
- `TimelineView(.animation(minimumInterval: 1/30))` — drives sun glow pulse + grid scroll.
- `ZStack` — neon halo (Blur+Color) behind the time text to fake the "glow through fog" CRT bloom.
- `.blur(radius: 8).blendMode(.plusLighter)` clone of the time `Text` to do the neon bloom without any image asset.

## 5. Reuse note

Drive everything from existing `controller.elapsedTime`, `intervalEngine.currentStepTimeRemaining`, `heartRateMonitor.current`, `controller.currentPace`, `controller.totalDistance`. No workout logic changes — this is a pure presentation layer that swaps in when `themeManager.current.id == "synthwave"`.
