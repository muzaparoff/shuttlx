# Arcade Authentic — watchOS Adaptation Spec

Hand-off for `swiftui-watchos-specialist`. Companion to `ios.md`. The headline decision, mirroring the
Mixtape (single reel badge) and VU Meter (single right strip) precedents:

> **The watch does NOT get the upright cabinet.** A 41/45 mm screen cannot hold a marquee + bezel +
> control panel + coin door without crushing the five core metrics. The watch keeps the proven
> `ArcadeTimerOverlay` (pixel-border bezel + faint scanlines) and adds at most ONE small live cabinet
> cue — a bezel back-light tint driven by HR — and only if it survives the legibility review.

Apple-frameworks-only, asset-light, no idle animations (battery) — per `.claude/rules/watchos.md`.

---

## 1. What survives, what is cut

| iOS cabinet element | Watch (41/45 mm) | Why |
|---|---|---|
| Pixel-border bezel + corner rivets | **KEEP** | Already shipped in `ArcadeTimerOverlay`, `.allowsHitTesting(false)`, cheap. It IS the surviving cabinet cue. |
| Faint scanline backdrop | **KEEP** | Already in `ArcadeTimerOverlay` at 6% opacity — sells "CRT inside a cabinet" without touching legibility. |
| Marquee housing + glow | **CUT** (downgrade to optional bezel HR tint, §4) | No vertical room above the metrics; a glowing marquee would steal the band the workout-name row + HR row need. |
| 7-segment hero digits | **CUT** | Base `TrainingView` already renders the monospaced timer in step color. Double-drawing 7-seg would fight the interval color wash and cost battery (documented in the existing `ArcadeTimerOverlay` header). |
| 1UP / HI score slots | **CUT** | Base view already shows HR (with zone badge) and time. |
| STAGE power-bar + interval dots | **CUT** | Base step pill already conveys step N/total. |
| 5 pixel score boxes | **CUT** | Base view already lays out HR + DIST/PACE (+ TIME in interval); cadence appears numerically there. Re-boxing them costs space + battery for zero new info. |
| Joystick-LED ring | **CUT** | No room; progress is implicit in the step pill. |
| Coin-door `CREDIT` + INSERT COIN | **CUT** | Paused state is handled by the base paused overlay (pause pulse on the workout name). |
| Arcade transport buttons (`ThemedTransportButtonStyle`) | **CUT for v1** | Watch controls are the established circular green=pause / red=stop buttons (`.claude/rules/watchos.md`). Adopting the arcade button material on watch is a separate, optional task — not part of this scene work. |

**Net change to watch code: effectively none required for v1.** The existing
`ShuttlX Watch App/Theme/Themes/Decorations/ArcadeTimerHero.swift` (`ArcadeTimerOverlay`) already
implements the correct degraded form. This proposal **endorses keeping it as-is**, with one **optional**
HR-tint enhancement (§4) the user may approve.

---

## 2. Layout (unchanged — for reference)

```
┌─────────────────────────┐  ← pixel-border bezel + corner rivets (ArcadeTimerOverlay)
│▒INTERVAL RUN▒▒▒▒▒▒▒▒▒▒▒▒│  ← base TrainingView workout-name row (pauses-pulse when paused)
│░░░░░ scanlines ░░░░░░░░░│  ← faint 6% scanline backdrop (overlay)
│      01:48              │  ← base monospaced countdown hero (step color)
│      WORK 3/8           │  ← base step pill
│  142 BPM   [Z3]         │  ← base HR row (zone badge) — primary cardiac read
│  DIST 2.15   PACE 5:42  │  ← base tertiary two-up (interval) / full rows (free-run)
└─────────────────────────┘
   ↑ bezel + scanlines = overlay (non-interactive)   ↑ everything else = base TrainingView
```

The metrics VStack already gets a **6 pt top/bottom inset** when `themeManager.current.id == "arcade"`
(`TrainingView.watchTimerTopPadding`/`watchTimerBottomPadding`, lines 427 & 439) so the HR row and
tertiary metrics clear the pixel border. **Preserve that inset** — it is the legibility guarantee.

---

## 3. Legibility of the base timer / HR rows (the #1 rule)

- `ArcadeTimerOverlay` is `.allowsHitTesting(false)` end-to-end — it cannot cover or steal taps from
  the timer, HR row, step pill, or crown/swipe targets.
- The bezel is a 1 pt stroke hugging the screen edge; the scanlines are 6% opacity at 4 px pitch —
  neither competes with the 40 pt mono timer or the BPM digits.
- Do **not** widen the bezel, raise the scanline opacity, or remove the 6 pt inset; any of those would
  push the HR/timer toward the chrome and risk clipping on 41 mm.
- HR remains the largest second-tier number in step-zone color; cadence (SPM) remains numeric in the
  base tertiary area. No cabinet element occludes any of the five core metrics.

---

## 4. Optional polish (P2 — only if the user approves)

To give the watch ONE honest live cabinet cue without adding clutter or battery cost:

- **HR-tinted bezel back-light.** Tint the existing pixel-border stroke color by
  `ShuttlXColor.forHRZone(workoutManager.heartRate)` instead of the fixed phosphor green, and scale its
  opacity gently with `bpm/200`. This makes the "cabinet glows harder as the heart works" idea survive
  to the watch as a *frame tint*, at near-zero cost (one color computation, no new layer).
  - It is a **secondary** cue only — the base HR row + zone badge stays the primary read.
  - **No animation / no throb on watch** (battery + no idle animation rule). A static per-frame tint
    that updates on `workoutManager.heartRate` change via the overlay's existing redraw is fine; do
    not add a `TimelineView` pulse.
  - Reduce Motion / Low Power: fall back to the fixed phosphor-green bezel.

Do **not** add a marquee, 7-seg digits, score boxes, an LED ring, a coin door, raster side-art, or the
arcade transport-button material on watch. Keeps the target Apple-frameworks-only and asset-light.

---

## Implementation hand-off
- **Files to create:** none.
- **Files to modify:** none required for v1. (If the user approves the P2 HR-tinted bezel, it is a
  self-contained change inside `ArcadeTimerOverlay.pixelBorder` — replace the fixed `phosphor` stroke
  color with `ShuttlXColor.forHRZone(workoutManager.heartRate)` and scale opacity by `bpm/200`,
  guarded for `bpm == 0` and Reduce Motion.)
- **Reuse existing:** `ArcadeTimerOverlay` in
  `ShuttlX Watch App/Theme/Themes/Decorations/ArcadeTimerHero.swift` (kept verbatim for v1), the
  `arcade` dispatch + 6 pt top/bottom inset in `ShuttlX Watch App/Views/TrainingView.swift`
  (lines 350–352, 427, 439), `ShuttlXColor.forHRZone`.
- **Theme variants verified:** Arcade only; overlay is gated by `themeManager.current.id == "arcade"`.
  No other watch theme affected. The base `TrainingView` standard stacked-metrics layout is unchanged.
- **Open questions for dev:**
  1. Confirm you agree the full cabinet is correctly cut at 41 mm (design strongly recommends keeping
     the existing bezel + scanline overlay — a marquee/score-box layout would crush the five core
     metrics).
  2. Do you want the P2 HR-tinted bezel for v1, or ship the existing fixed-green overlay unchanged and
     defer the tint? (Design recommendation: ship unchanged; the iOS cabinet is where the depth work
     pays off, and the watch's job is legibility.)
