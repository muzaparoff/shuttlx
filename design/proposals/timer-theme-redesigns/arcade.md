# Arcade Timer — 1983 Cabinet Score Readout

## 1. Hero concept

The timer is the **TOP-SCORE READOUT of an arcade cabinet attract screen**. The largest element is the elapsed time rendered as **chunky 7-segment-style "score digits"** (drawn in Canvas — no font asset needed), prefixed with leading zeros (`00:03:24`) like a Galaga high-score. Above it blinks a **★ HI-SCORE ★** banner that switches to **★ PERSONAL BEST ★** if the user crosses a PR threshold. On idle/paused: the screen taunts with a blinking **"INSERT COIN"** label below the score.

```
   ╔══════════════════════════════╗
   ║  1UP                    HI   ║
   ║  142                  09:42  ║
   ║                              ║
   ║      ★ HI-SCORE ★            ║
   ║                              ║
   ║    █▀▀ █▀█ ▄▀▀ ▀█▀ █▄█       ║
   ║    █▄▄ █▄█ ▄██  █  █ █  ← 7-seg time
   ║                              ║
   ║  ▶ WORK  ░░░░▓▓▓▓▓▓▓▓░░░░    ║  ← progress as power bar
   ║                              ║
   ║  STAGE 3-8   ●●●●●○○○○       ║  ← interval dots
   ╚══════════════════════════════╝
```

## 2. Secondary metrics layout

- **HR** — top-left "1UP" slot, styled as a score with the zone label as a tiny suffix (e.g., `1UP  142  Z3`).
- **Personal best / target time** — top-right "HI" slot.
- **Pace / distance** — bottom status bar: `STAGE 3-8 · 5:42/KM · 1.84KM`.
- **Step progress** — a row of pixel dots at the bottom (one per interval step), filled = completed, blinking = current.

## 3. Background composition

Existing `arcadeCRTBackground` (scanlines + vignette) stays. Add a **2-pixel pixel-art border** drawn with `Canvas` (thick outer black, inner phosphor green). On HR-zone change, briefly flash the border (3 frames @ 60Hz) — same trick CPS-1 used to indicate "danger".

## 4. SwiftUI primitives

- `Canvas` — draws the 7-segment digits manually (7 horizontal/vertical rects per digit, lit/dim based on the digit value). Same Canvas draws the pixel border.
- `TimelineView(.animation)` — drives the "INSERT COIN" blink (0.5 Hz) and HI-SCORE banner shimmer.
- `ZStack` overlays — scanline tint over digits to fake CRT bloom; the existing `.scanlineOverlay()` modifier already does this.
- `.contentTransition(.numericText(countsDown: true))` on the interval-remaining digits so they tick like a countdown.

## 5. Reuse note

Same data sources — `controller.elapsedTime`, `intervalEngine.totalStepsCount` / `currentStepIndex`, `heartRateMonitor.current`. The PR detection can reuse the existing PR logic in `AnalyticsView` (compute "best 5K time" client-side from `DataManager.sessions`). No workout logic touched.
