# Arcade Timer — Watch Variant

## 1. Watch-adapted hero metaphor

Same 1983 arcade-cabinet score readout — the **elapsed time is still the HI-SCORE**, drawn as chunky 7-segment digits in Canvas. But the cabinet bezel shrinks to a **2-pixel phosphor-green border** hugging the screen edge, the `1UP/HI` header collapses to a single line, and the "INSERT COIN" taunt is reserved for the paused state only (handled by the existing paused overlay, not by this view's idle state). The watch reads as a cabinet attract screen viewed through a porthole.

## 2. What's cut from the iPhone version

- Separate `1UP` / `HI` corner score slots — merged into one top line
- `★ HI-SCORE ★` blinking banner — dropped (no vertical room)
- `STAGE 3-8 ●●●●●○○○○` interval-dot row — dropped (handled by the step pill)
- Bottom `WORK ░░▓▓░░` power-bar progress — dropped
- "INSERT COIN" idle taunt — moved out (paused-state overlay handles it)

## 3. Five elements on screen (priority order)

1. 7-segment elapsed time (Canvas, ~44pt tall, centered, phosphor green)
2. Top status line — `1UP 142 Z3        HI 09:42` (14pt, mono)
3. Step pill — `STAGE 3-8 WORK` (16pt, just under the time)
4. Pace OR distance (single 16pt line, bottom-center, swaps every 4s)
5. 2-pixel phosphor-green pixel border (Canvas, screen edge)

## 4. ASCII layout (30 col)

```
 ╔════════════════════════════╗
 ║ 1UP 142 Z3      HI 09:42   ║
 ║                            ║
 ║   █▀ █▀ █▀ █▀  █▀ █  █▀    ║
 ║   █▄ █▄ ▄█ ▄█  █▄ ▄  █▄    ║
 ║      03 : 24               ║
 ║                            ║
 ║      STAGE 3-8 WORK        ║
 ║         1.84 KM            ║
 ╚════════════════════════════╝
```

## 5. SwiftUI primitives

- `Canvas` (one, full-screen): draws the pixel border + the 7-segment digits (each digit = 7 axis-aligned `Path` rects, lit/dim by digit value). Sized so digits are ≥40pt tall on 41mm.
- `TimelineView(.animation(minimumInterval: 0.5))` — drives HI-SCORE shimmer only; the segment digits don't need 60Hz (they update on the 1Hz controller tick).
- `.contentTransition(.numericText(countsDown: true))` on the step-pill remaining time.
- Top status line + bottom metric: plain `Text` views with mono font.
- Existing `.scanlineOverlay()` modifier wraps the whole `ZStack` for CRT bloom.
- No pinned footer; the border is drawn inside Canvas so it can't push past safe area.
