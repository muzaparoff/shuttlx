# Synthwave Timer — Watch Variant

## 1. Watch-adapted hero metaphor

Same Outrun dash readout — but the **trapezoidal frame is dropped** and the timer floats over a **vertically compressed horizon strip** that occupies the top ~35% of the screen. The grid still scrolls in perspective, the neon sun still glows behind the time, but the dash chrome is gone. The time is the dash; the grid behind it carries the brand. Think "speedometer numerals projected onto windshield" rather than "full dash cluster".

## 2. What's cut from the iPhone version

- Trapezoidal chevron frame around the time — dropped (it ate horizontal width)
- Chevron tick marks and the destination-sign step pill on top — dropped
- The three vertical needle gauges (HR/Pace/Dist row) — collapsed to a single inline metric row
- Magenta haze "fog" at horizon — kept but at 60% intensity (watch backlight blooms enough already)

## 3. Five elements on screen (priority order)

1. Elapsed time (hero, 44pt mono, neon-cyan with magenta bloom clone)
2. Heart rate + zone badge (22pt, top-left)
3. Step pill — `WORK 02:12` (18pt, top-right, magenta tinted)
4. Horizon grid + sun halo (Canvas backdrop, lower 50%)
5. Distance OR pace (single 18pt line, bottom-center, toggles every 4s)

## 4. ASCII layout (30 col)

```
  142 Z3            WORK 02:12
  ────────────────────────────
       0 3 : 2 4 . 7
       ▒▒▒ neon bloom ▒▒▒
   ╲       sun halo       ╱
    ╲ ─── ─── ─── ─── ── ╱
     ╲══════ grid ══════╱
        1.84 KM
```

## 5. SwiftUI primitives

- `Canvas` (lower half only, 50% height, `ignoresSafeArea` off): scrolling perspective grid + sun glow, driven by `TimelineView(.animation(minimumInterval: 1/24))`. Scroll speed = `controller.currentPace` clamped.
- Hero time: single `Text` with `ShuttlXFont.timerDisplay` + a `.blur(radius: 6).blendMode(.plusLighter)` duplicate in a `ZStack` for the neon bloom.
- Top row: `HStack` with two `Text` views (HR left, step pill right) — no Canvas, just colored backgrounds via `.themedCard()` at half padding.
- Bottom metric: single `Text` that swaps source via `TimelineView(.periodic(every: 4))`.
- No pinned footer chrome — leaves room for the TabView page-indicator dots.
