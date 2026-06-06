# Mixtape Timer — Walkman Cassette Deck

## 1. Hero concept

The screen IS a top-down view of a **clear-plastic Sony Walkman with a cassette loaded**. The largest visual is the **two spinning reels** — the left reel (supply) shrinks as time elapses, the right reel (take-up) grows, exactly like real tape. The elapsed time is engraved into the **tape counter window** between the reels — a small green LCD digit display ("0312" style, 4 digits, no separator). Interval mode: the counter shows time remaining in the current step and the reels "pause + reverse" on REST steps.

```
   ╭──────────────────────────────╮
   │  ◉ REC   ▣ SHUTTLX MIXTAPE   │  ← label sticker (workout name)
   │  ┏━━━━━━━━━━━━━━━━━━━━━━━━┓  │
   │  ┃  ╱─╲              ╱─╲  ┃  │  ← spinning reels
   │  ┃ │ ◉ │    0312    │ ◉ │ ┃  │  ← center LCD
   │  ┃  ╲─╱            ╲─╱  ┃  │
   │  ┗━━━━━━━━━━━━━━━━━━━━━━━━┛  │
   │  ◀◀  ▶  ❚❚  ■  ▶▶            │  ← transport row (controls)
   │  HR 142 ▮▮▮▮▮▱▱▱  5:42 PACE  │  ← VU strip
   ╰──────────────────────────────╯
```

## 2. Secondary metrics layout

- **HR** — a horizontal bar-graph "VU strip" below the reels (10 segments, lights up green→amber→red by zone). Same row shows numeric BPM.
- **Pace** — a second VU strip labeled "TAPE SPEED", needle moves left/right of target pace.
- **Distance / steps** — engraved into the cassette label sticker top-left/top-right corners in small monospaced caps ("SIDE A · 1.84 KM").
- **Step pill** — replaces the cassette label band in interval mode: "WORK · TRACK 3/8".

## 3. Background composition

Blue Walkman body shell (existing `mixtapeBackground`) + a translucent rounded-rect "cassette window" centered. The reels rotate at angular velocity = `1 - (elapsed / totalDuration)` so the supply reel visibly slows as the workout nears completion.

## 4. SwiftUI primitives

- `Canvas` — draws each reel (concentric circles + 6 radial spokes); rotation driven by `TimelineView(.animation)`.
- `TimelineView(.animation(minimumInterval: 1/24))` — continuous reel rotation, independent of the 1 Hz tick.
- `ZStack` — cassette body (rounded rect with gradient + texture), window cutout, transport controls overlay.
- `.rotationEffect(.degrees(spinAngle))` on each reel `Canvas`; angle accumulates via `@State` so wrist-down resume doesn't snap.

## 5. Reuse note

All data still comes from `iPhoneWorkoutController` / `WatchWorkoutManager` — `elapsedTime`, `intervalEngine.currentStep`, `heartRateMonitor.current`, `currentPace`, `totalDistance`. The reels are decorative; the LCD digit field reads `FormattingUtils.formatTimer()` exactly as today.
