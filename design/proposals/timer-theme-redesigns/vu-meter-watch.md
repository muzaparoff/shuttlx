# VU Meter Timer — Watch Variant

## 1. Watch-adapted hero metaphor

Same analog VU meter measuring heart rate — but the meter is a **tall, narrow vertical arc pinned to the right edge** instead of a wide horizontal arc. The needle swings vertically (up = higher BPM) so the meter occupies the right ~30% of the screen and leaves the left two-thirds for the elapsed-time readout and step pill. Think "tape-deck VU strip rotated 90°, sitting beside the counter" — which is exactly how real cassette decks laid them out.

## 2. What's cut from the iPhone version

- Horizontal scale arc spanning the full width — replaced by a vertical arc on the right
- Secondary "step countdown" needle — dropped; the step pill carries the step time numerically
- Side strips for step/distance — collapsed into a single bottom row
- Peak HR LED — kept but shrunk to a 6pt dot at the top of the arc
- "rec level" pace caption — dropped; pace shares the bottom row

## 3. Five elements on screen (priority order)

1. Elapsed time recessed counter (44pt mono, ivory-on-dark, left two-thirds)
2. Vertical VU arc + needle + peak LED (Canvas, right ~30%, full height)
3. Step pill — `WORK 02:12` (16pt, above the counter)
4. HR numeric — `142 Z3` (18pt, under the arc baseline, right-aligned)
5. Pace OR distance (single 16pt line, bottom-left, swaps every 4s)

## 4. ASCII layout (30 col)

```
  WORK 02:12               ●  peak
  ╭──────────────╮       ╲
  │              │     200╲
  │  03 : 24     │      ╲  ↑
  │  ELAPSED     │       ╲ ●
  ╰──────────────╯      60╱
                          142
  5:42 /KM                 Z3
```

## 5. SwiftUI primitives

- `Canvas` (right column, full height, ~30% width): draws the vertical arc (60→200 BPM), tick marks, needle, peak-hold LED. Needle rotation = `lerp(60, 200, heartRateMonitor.current)`.
- Needle ballistics: `.animation(.spring(response: 0.3, dampingFraction: 0.6), value: hr)` to mimic the 300ms VU swing.
- Hero counter: `Text` in `ShuttlXFont.timerDisplay`, `.monospacedDigit()`, wrapped in a recessed `RoundedRectangle` with an inner-shadow gradient overlay (two stacked `RoundedRectangle.stroke` with offset).
- Step pill: existing `.themedCard()`.
- `@State private var peakHR: Int` — local peak-hold; resets when `controller.elapsedTime == 0`.
- Existing `vuMeterBackground` (amber glow + panel lines) stays as backdrop.
- No pinned footer.
