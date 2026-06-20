# Arcade Authentic — Concept & Rationale

**Date:** 2026-06-15
**Author:** product-designer
**Status:** Proposal — user decisions LOCKED (see §10); static mockup rendered at
`mockups/arcade-cabinet-v1.png` and approved-pending-review. No Swift touched yet.
**Parallels:** the Mixtape cassette-shell upgrade (`MixtapeCassetteScene` + `MixtapeTimerHero` +
`ThemedTransportButtonStyle`) and the VU Meter receiver upgrade (`design/proposals/2026-06-15-vumeter-authentic/`).
This proposal reuses the **same Scene/overlay split and the same `TransportButtonSpec` family** those
two established — it does not invent a new framework.

---

## 1. Why today's Arcade theme is a flat reskin

I read the live implementation before designing:

- `ShuttlX/Theme/Themes/ArcadeTheme.swift` — palette + `.pixel` CardStyle + `hasCRTEffect: true`.
  Pure recolor/effect flags. No cabinet geometry exists anywhere.
- `ShuttlX/Theme/Themes/ArcadeTimerHero.swift` — already does a lot right: a `Canvas` 7-segment digit
  renderer, a pixel-border box, `1UP`/`HI` corner score slots, `★ HI-SCORE ★` / `★ INSERT COIN ★`
  blink, `STAGE N-M ●●●○○` interval dots, four score-readout metric boxes, and a controls bar. **But:**
  it is a *flat poster of an arcade screen*, not a physical cabinet. There is no bezel depth, no
  marquee, no coin door, no joystick/button cluster, and — critically — **none of the chrome maps to
  live workout data**: the `INSERT COIN` blink is a fixed 0.5 Hz timer, the score slots are just
  relabeled metrics, and the metaphor evaporates the instant you leave the timer (template picker,
  history, settings are "navy Clean").
- `ShuttlX Watch App/Theme/Themes/Decorations/ArcadeTimerHero.swift` (`ArcadeTimerOverlay`) — a
  decorative pixel-border bezel + faint scanlines. Correct restraint for the watch, but it is *only*
  a frame; it carries no live signal.

**Root-cause table (mirrors the Mixtape README):**

| Symptom | Root cause in code |
|---|---|
| "Doesn't look like a real cabinet" | No scene geometry — `arcadeCRTBackground()` is CRT scanlines + vignette on a flat fill; there is no marquee, bezel, coin door, or control panel anywhere |
| "It's just a screen, not hardware" | The hero composes *inside* one rectangle; nothing frames it as a CRT recessed behind glass inside a wooden/metal cabinet |
| "The flashing stuff is fake" | The `INSERT COIN` blink and active-dot blink run off wall-clock `TimelineView`, decoupled from the workout. Chrome must pulse with HR / fill with progress, not tick on a fixed clock |

The fix: render a **full-bleed cabinet scene** behind every Arcade screen (so the theme reads as
hardware even on the home screen), and **rewire every animated element of the hero to a live workout
value**. We adopt the existing Scene/overlay split verbatim.

---

## 2. Signature Shape DNA for Arcade

Per `.claude/rules/design-system.md`, each theme owns ONE signature shape reused across surfaces. The
design-system table lists Arcade's as **"7-segment digit block / pixel border."** This proposal keeps
that and elevates it into a hardware reading:

> **Arcade signature shape = the lit 7-segment digit window framed by a chunky pixel bezel, recessed
> behind CRT glass.** The same parametric `Canvas` that draws the 7-segment digits (already in
> `ArcadeTimerHero.drawSevenSegmentString`) becomes the reusable motif: it is the timer hero, the
> score readout, the marquee letters, and — on watch — the single surviving cabinet cue (the pixel
> bezel + corner rivets, already shipped in `ArcadeTimerOverlay`).

No new illustration set. One `Canvas` digit renderer + one `Canvas` pixel-box renderer (both already
exist) carry the whole identity.

---

## 3. The concept — "Upright Cabinet" scene

Upgrade from "flat arcade screen" to a **full upright arcade cabinet viewed head-on**, with the
workout living inside the CRT. Anatomy, top to bottom:

```
        ┌══════════════════════════════════════════════┐
   MARQUEE  ║   I N T E R V A L   R U N   ·  PLAYER 1   ║   ← back-lit header, glow pulses with HR
        ┠──────────────────────────────────────────────┨
        ║  ┌────────────────────────────────────────┐  ║   ← BEZEL (chunky pixel border + rivets)
        ║  │░░░ CRT GLASS (scanlines + corner curve) │  ║
        ║  │   1UP[HR]              HI-SCORE[STEPS]   │  ║   ← 1UP = live HR · HI = step count (score)
        ║  │                                          │  ║
        ║  │        ███ 7-SEG COUNTDOWN ███           │  ║   ← the hero digit window (signature shape)
        ║  │            WORK REMAINING                │  ║
        ║  │       STAGE 3-8  ▓▓▓░░░░░ (progress)     │  ║   ← power-bar fills with step/workout progress
        ║  │   HR   DIST   PACE   SPM  (score boxes)  │  ║   ← 5 core metrics, pixel-boxed
        ║  └────────────────────────────────────────┘  ║
        ┠──────────────────────────────────────────────┨
   PANEL  ║  ◉ joystick-LED ring     [A] [B] [START]   ║   ← control panel = transport buttons
        ┠──────────────────────────────────────────────┨
   COIN   ║  ▢ COIN DOOR  ·  CREDIT 01  ·  ▢            ║   ← coin door footer; CREDIT = lap/step count
        └══════════════════════════════════════════════┘
```

- **MARQUEE** (top): a back-lit header strip. Generic title text (workout name, `PLAYER 1`). Its
  glow **pulses with heart rate** — the marquee "lights up harder" as the heart works harder. This is
  the Arcade equivalent of Mixtape's spinning reels: the always-present, data-driven hero cue.
- **BEZEL + CRT GLASS**: the chunky pixel border (reuse `drawPixelBox`) becomes a *recessed* bezel
  with corner rivets, framing a CRT with the existing scanline overlay plus a faint barrel/corner
  darkening so the glass reads as curved. The 7-segment timer sits behind the glass.
- **CONTROL PANEL** (lower): the joystick + buttons cluster. The transport controls
  (pause/skip/finish/cancel) are rendered as **round arcade buttons** via the existing
  `ThemedTransportButtonStyle` framework (Arcade gets a new `TransportButtonSpec` — hard 4 pt travel,
  concave-to-convex cap, sharp click haptic). A **joystick-LED ring fills with overall workout
  progress.**
- **COIN DOOR** (footer): a thin strip with a `CREDIT NN` counter = completed-step (interval) /
  completed-station (recovery) / lap count, and the `INSERT COIN` taunt **only** when paused.

The whole cabinet renders behind every screen via the scene; only the live elements (marquee glow,
LED ring, 7-seg digits, score boxes) animate, and only during a workout.

---

## 4. Live-data → chrome mapping table (the #1 requirement)

**Every dynamic element cites its `iPhoneWorkoutController` / `WatchWorkoutManager` source. Nothing is
a dead skin or a wall-clock animation.**

| Cabinet element | Drives on | Data source (iOS `controller` / watch `workoutManager`) | Ballistics |
|---|---|---|---|
| **Marquee back-light glow** | Heart rate | `controller.heartRateMonitor.current` (watch: `workoutManager.heartRate`) | Glow radius + opacity scale with `bpm/200`; a 1-beat "throb" envelope retriggers each time BPM changes via `onChange`. Tinted `ShuttlXColor.forHRZone(bpm)`. Reduce Motion → static glow at current zone color. |
| **Marquee title text** | Workout name + mode | `controller.workoutName`, `controller.mode` | Static text; `PLAYER 1` is generic decoration. |
| **1UP score slot** | Heart rate + zone | `heartRateMonitor.current` → `ShuttlXColor.forHRZone` | Numeric text, `contentTransition(.numericText())` (already done). Zone label `Z3`. |
| **HI-SCORE slot** | Total step count (the "score") | `controller.totalSteps` | Numeric ticking text. The arcade score = steps taken — keeps raw step count visible (user decision §10.3) without crowding the metric row. |
| **7-segment hero window** | Mode-dependent time | free-run: `elapsedTime`; interval: `intervalEngine.currentStepTimeRemaining`; recovery: station/rest elapsed (logic already in `heroTimeString`) | 7-seg digits, lit color = step color. Segment "ignite" transition on digit change. |
| **STAGE power-bar** | Step progress (interval) / workout progress | interval: `1 - currentStepTimeRemaining/currentStep.duration`; free-run: hidden or workout-elapsed fraction | A pixel-segmented bar `▓▓▓░░░` filling left→right. `.linear(duration: 1)` like the existing capsule progress. |
| **Active interval dot** | Current step index | `intervalEngine.currentStepIndex` / `totalStepsCount` | Completed = solid, current = **glow whose intensity tracks step progress** (replaces today's wall-clock blink), future = dim outline. |
| **HR score box** | Heart rate | `heartRateMonitor.current`, zone color | Numeric. |
| **DIST score box** | Distance | `controller.totalDistance` → `FormattingUtils.formatDistance` | Numeric. |
| **PACE score box** | Pace | `controller.currentPace` → `FormattingUtils.formatPace` | Numeric (`--:--` guarded). |
| **SPM score box** *(NEW vs today)* | Cadence | `controller.currentCadence` (watch: `workoutManager` cadence) | Numeric. Takes the 4th metric-box slot so all five **core** metrics are present. Raw step count is NOT dropped — it moves to the HI-SCORE slot (above). |
| **Joystick-LED ring** | Overall workout progress | interval: `currentStepIndex/totalStepsCount`; free-run: elapsed-vs-goal or just animated idle-off | Ring of pixel LEDs lighting clockwise as progress fills. Reduce Motion → static fill. |
| **COIN DOOR `CREDIT NN`** | Completed steps / stations / laps | interval: `currentStepIndex`; recovery: `recoverySetNumber`; free-run: lap count if available else `01` | Static numeric, increments on step/station change. |
| **`INSERT COIN` blink** | Paused state | `controller.isPaused` | Blink retained **only** while paused (it is genuinely a "game is waiting" cue). Replaces today's always-eligible blink. Reduce Motion → solid, no blink. |
| **Arcade transport buttons** | Press + latch | `configuration.isPressed`; `isLatched: !controller.isPaused` for the START/PLAY-style key | 4 pt hard travel, click haptic, via `ThemedTransportButtonStyle` (Arcade spec). |

The NET changes vs today's hero: (1) **the metric boxes become the 5 core metrics** — HR / DIST /
PACE / **SPM** — so cadence is present; (2) **raw step count moves into the HI-SCORE slot** (the arcade
"score = steps" metaphor) so it stays visible per the user's decision; (3) **every animation is rebound
to a workout value** instead of the wall clock.

---

## 5. Architecture decision — Scene vs Overlay (reuse Mixtape/VU exactly)

Adopt the **same two-layer split** Mixtape and VU Meter use. No new framework.

```
┌─ LAYER 1: RESTING SCENE ──────────────────────────────────────┐
│  ArcadeCabinetScene : View, ThemedScene                       │
│  (append BELOW MixtapeCassetteScene / VUReceiverScene in      │
│   ShuttlX/Theme/Components/ThemedSceneBackground.swift —       │
│   keep all scene definitions colocated, per house rule)       │
│                                                               │
│  Draws ONLY the static cabinet hardware:                      │
│   • cabinet body (side panels + dark vignette)                │
│   • marquee housing (UNLIT — glow is the hero's job)          │
│   • CRT bezel cut-out (pixel border + rivets, recessed)       │
│   • CRT glass (scanlines + corner barrel darkening)           │
│   • control-panel housing + empty joystick well + button wells│
│   • coin-door footer strip (static chrome only)               │
│  NO live data, NO marquee glow, NO 7-seg digits, NO LEDs.     │
│                                                               │
│  Shared constants: ArcadeCabinetLayoutConstants               │
│   (CRT-glass rect fractions, marquee height, panel height)    │
└───────────────────────────────────────────────────────────────┘
                          ▲ overlaid by
┌─ LAYER 2: LIVE OVERLAY ───────────────────────────────────────┐
│  ArcadeTimerHero (REWRITE of existing file)                   │
│  Draws ON TOP, positioned in screen space via                 │
│  ArcadeCabinetLayoutConstants so the digit window, score      │
│  slots, power-bar, and LED ring land exactly inside the       │
│  scene's CRT-glass / panel cut-outs regardless of width:      │
│   • marquee glow layer (HR-driven)                            │
│   • 1UP / HI score slots, 7-seg hero, STAGE power-bar         │
│   • 5 score boxes (HR/DIST/PACE/SPM)                          │
│   • joystick-LED ring (progress-driven)                       │
│   • arcade transport buttons (ThemedTransportButtonStyle)     │
└───────────────────────────────────────────────────────────────┘
```

**Why split it** (same reasons as Mixtape/VU): the cabinet renders globally so the theme reads as
hardware on every screen, and the hero anchors its live elements with the proven
`Color.clear`-spacer + `ArcadeCabinetLayoutConstants` math instead of guessed sibling heights.

**Wiring handshake** (mirror `timerScreenBackground(themeID:)`): add an `arcade` branch that draws
`ArcadeCabinetScene(showCRTContent: false)` so the hero owns the live CRT content without a duplicate,
exactly as Mixtape passes `showJCard: false` and VU passes `showCounter: false`.

---

## 6. Asset sourcing recommendation

**Recommendation: parametric `Canvas` / SwiftUI shapes, NOT raster. Do not embed imagery.**

Justification (same logic the Mixtape/VU proposals settled on):

1. **A cabinet is geometry, not photography.** Bezel, rivets, scanlines, 7-seg digits, pixel LEDs,
   round buttons — all are already Canvas/shape primitives in the codebase
   (`drawPixelBox`, `drawSevenSegmentString`, `drawGlobalScanlines`). The marquee glow is a
   `RadialGradient`/`.blur`. Nothing here benefits from a raster.
2. **watchOS must stay Apple-frameworks-only and asset-light** (`.claude/rules/watchos.md`). Canvas
   costs zero bytes and renders identically on both targets; a raster cabinet would bloat the bundle
   and need a second small asset.
3. **Mixtape's one justified raster** (the reel imageset) was an organic, hard-to-vector object. The
   Arcade cabinet has no equivalent — it is all hard edges and CRT phosphor, which Canvas nails.

**If** the user later wants a real cabinet side-art texture (wood-grain or worn-laminate side panels),
the sourcing rule stands: **CC0 / Public-Domain only, license verified before embed**, recorded in a
memory file like `project_mixtape_reel_asset.md`. Candidate CC0 sources: Poly Haven / ambientCG
(wood-grain or laminate, crop to a thin vertical side strip). **Default call: ship the Canvas version;
treat side-art raster as an optional P2 polish pass only.** Any side-art must never carry a logo,
brand, or character — generic finish only (trademark constraint).

---

## 7. Trademark safety stance (non-negotiable)

- **No brand, character, logo, or game title** anywhere — not in visible text, not in struct/file/var
  names, not in marquee art. The cabinet is a generic upright arcade machine.
- Allowed generic vocabulary (already used and safe): `INSERT COIN`, `PLAYER 1`, `HI-SCORE`,
  `1UP`, `CREDIT`, `STAGE`, `READY`, `GAME OVER`-style framing is **avoided** (too on-the-nose; we use
  `COMPLETE`). Marquee model text is invented and generic, e.g. `MODEL ARC-83` (verify it reads as no
  real cabinet). No `START`/`SELECT`/`A`/`B` button *labels* that imply a specific controller layout —
  use neutral glyphs (▶ ‖ ■ ▶▶) like the rest of the app.
- Reviewer check before implementation: grep the final code for any token resembling a real brand.

---

## 8. Accessibility & cardiac-safety stance (cardiac-rehab first)

- Skeuomorphism must **never** reduce HR/time/pace/SPM legibility. The 7-seg hero, the 1UP HR slot,
  and the five score boxes keep their current sizes, `monospacedDigit()`, and zone coloring; the
  cabinet chrome sits *behind/around* them. The CRT corner-barrel darkening is clamped so it never
  dims the digit window or score boxes (darkening lives in the outer 8% margin only).
- **The marquee glow is a *secondary* HR cue, never the primary one.** The 1UP numeric BPM + zone
  badge remains the explicit reading; a low-vision user never relies on glow intensity.
- Transport buttons: ≥44 pt hit target enforced by `ThemedTransportButtonStyle` even if the visual cap
  is round and chunky. Every button keeps `.accessibilityLabel` + `.accessibilityHint` (already done).
- **Reduce Motion / Low Power:** marquee glow becomes static, LED ring static-filled, active-dot stops
  blinking, `INSERT COIN` shows solid (no blink), button travel clamps to 0 (color/shadow swap only).
- Watch gets the deliberately degraded form (see `watch.md`): cabinet bezel + faint scanlines only.

---

## 9. Files (summary — full hand-off in `ios.md` / `watch.md`)

- **New:** `ArcadeCabinetScene` + `ArcadeCabinetLayoutConstants`, appended to
  `ShuttlX/Theme/Components/ThemedSceneBackground.swift`.
- **Rewrite:** `ShuttlX/Theme/Themes/ArcadeTimerHero.swift` (keep palette, 7-seg + pixel-box Canvas,
  score-slot/score-box helpers, alerts; replace flat composition with scene-anchored overlay; rebind
  every animation to live data; swap raw `STEP` box → `SPM`).
- **Modify:** `ShuttlX/Theme/ThemeModifiers.swift` — upgrade `arcadeBackground()`/`arcadeCRTBackground()`
  to draw the scene; add `arcade` branch to `timerScreenBackground(themeID:)`.
- **Modify:** `ShuttlX/Theme/Components/ThemedTransportButton.swift` — add an `arcade` case to
  `spec(for:role:)` (round arcade-button material, 4 pt travel, click haptic).
- **Watch:** minimal — keep `ArcadeTimerOverlay` essentially as-is; see `watch.md`.

---

## 10. User decisions — LOCKED (2026-06-15)

1. **Cabinet framing → FULL UPRIGHT CABINET.** Marquee + CRT bezel + control panel + coin door all
   render. (Mockup reflects this.)
2. **Joystick-LED ring → OVERALL WORKOUT PROGRESS.** Steps completed / total (interval); attract-idle
   in free-run/recovery where there is no fixed total. Distinct from the STAGE bar (current-step).
3. **Step count → KEEP, as the HI-SCORE.** User chose to keep raw step count rather than swap it for
   SPM. Reconciliation: cadence (SPM) is a mandated core metric, so it takes the 4th metric box; raw
   step count moves to the **HI-SCORE slot** (arcade "score = steps"). Both are visible; nothing is
   crowded. (This refines the original spec, which had HI = elapsed and SPM replacing STEP.)
4. **Cabinet finish → DARK CHARCOAL.** `ArcadeCabinetScene` uses a charcoal body (`~#1c1c20`→`#0c0c0e`
   gradient), not the legacy navy `#0F0F2D`.

These are reflected in `mockups/arcade-cabinet-v1.png`. Implementation can proceed once the user
approves the mockup aesthetic.
