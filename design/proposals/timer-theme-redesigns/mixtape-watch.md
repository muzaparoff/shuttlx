# Mixtape Timer — Watch Variant

## 1. Watch-adapted hero metaphor

Same Walkman cassette — but reduced to **ONE reel** as the hero, pinned to the **left edge**, with the **LCD tape counter pulled out of the cassette and enlarged** to dominate the right two-thirds of the screen. The reel still spins continuously and slows as the workout approaches its planned duration; the LCD shows the elapsed time. The metaphor reads as "you can see one reel through the cassette window, and the counter beside it" — exactly the layout of a real Walkman flipped sideways.

## 2. What's cut from the iPhone version

- The cassette body shell — dropped; only the reel and the LCD survive
- The second (take-up) reel — dropped; one reel carries the rotation metaphor alone
- Transport row (◀◀ ▶ ❚❚ ■ ▶▶) — dropped (controls live on the controls page)
- "Tape speed" VU strip — collapsed into the existing HR row
- "Side A" cassette-label sticker — dropped

## 3. Five elements on screen (priority order)

1. LCD tape counter showing elapsed time (44pt green LCD digits, right side)
2. Spinning reel (Canvas circle + 6 spokes, ~70pt diameter, left edge)
3. Heart rate + zone (22pt, top-right above the LCD)
4. Step pill — `TRACK 3/8 WORK` (16pt, top-left above the reel)
5. HR VU strip (10 segments, 8pt tall, bottom under the LCD)

## 4. ASCII layout (30 col)

```
  TRACK 3/8 WORK    142 Z3
  ─────────────────────────
   ╱─╲
  │ ◉ │      0 3 : 2 4
   ╲─╱       LCD green
    ↻
            ▮▮▮▮▮▮▱▱▱▱
            HR VU
```

## 5. SwiftUI primitives

- `Canvas` (left ~30% width, square): single reel — concentric circles + 6 radial spokes. Rotation via `TimelineView(.animation(minimumInterval: 1/24))` + accumulated `@State var spinAngle` so wrist-raise doesn't snap.
- LCD: `Text` with `ShuttlXFont.timerDisplay` in `ShuttlXColor.success` (green) over a `.lcdPanel()` modifier, `.monospacedDigit()`.
- Top row: plain `HStack` of two `Text` views.
- VU strip: `HStack(spacing: 1)` of 10 `Rectangle()` views, color-tuned by HR zone — no Canvas needed.
- No pinned bottom chrome — page indicator dots stay visible.
