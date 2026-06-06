# Classic Radio Timer — Watch Variant

## 1. Watch-adapted hero metaphor

Same 1960s wood-cabinet radio — but the **horizontal tuning dial becomes a thin strip across the top third**, and the **amber backlit numeric readout becomes the hero** in the middle. On iPhone the dial was the focal point; on watch the dial degrades to a "you are here" progress strip and the warm amber valve-glow numeric is what the user actually reads at a glance. The three bakelite knobs are dropped — too small to be legible at watch scale.

## 2. What's cut from the iPhone version

- Three bakelite knobs (TONE/VOLUME/BAND) — dropped; would be <30pt and unreadable
- "Brand plate" header (`⊙ SHUTTLX · BAND: INTERVAL`) — dropped
- Station-name labels under the dial (`WORK · REST · WORK`) — dropped; the step pill carries this
- The dial shrinks from hero to a thin progress strip with only a needle + two end ticks

## 3. Five elements on screen (priority order)

1. Amber backlit elapsed time (44pt monospaced, warm amber, hero center)
2. Tuning-dial progress strip with red needle (Canvas, full-width, ~14pt tall, top)
3. Step pill — `WORK 02:12` (18pt, just above the time, amber)
4. Heart rate + zone (18pt, bottom-left, amber)
5. Distance (18pt, bottom-right, amber)

## 4. ASCII layout (30 col)

```
  00────────▼─────────30
            ↑ needle
  ─────────────────────────
       WORK · 02:12
       ╭─────────────╮
       │   03 : 24   │  ← amber glow
       ╰─────────────╯
  142 Z3          1.84 KM
```

## 5. SwiftUI primitives

- `Canvas` (top, ~14pt tall, full-width): tuning dial — two end ticks (`00`, `30`), thin centerline, red needle whose X-position = `elapsed / plannedDuration`.
- Hero time: `Text` with `ShuttlXFont.timerDisplay`, color = `ShuttlXColor.warning` (amber), wrapped in a `ZStack` with a `Circle().fill(amber.opacity(0.12)).blur(20)` behind it for the valve-glow halo. Halo opacity pulses on each HR beat via `TimelineView(.animation(minimumInterval: 1/8))`.
- Step pill: existing `.themedCard()` with `.lcd`-like styling.
- Bottom row: plain `HStack` of two `Text` views.
- Existing `classicRadioBackground` (wood grain + vignette) stays as the screen background.
- No pinned chrome — page indicator dots clear.
