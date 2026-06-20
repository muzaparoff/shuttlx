# Arcade Authentic — iOS Hero + Scene Spec

Hand-off for `senior-ios-developer`. Implements the upright-cabinet concept from `README.md`. Mirrors
the Mixtape scene/overlay split (`MixtapeCassetteScene` + `MixtapeTimerHero`) and the VU Meter
rewrite — **read those two heroes and `ThemedTransportButton.swift` first**; this spec assumes that
pattern and reuses its primitives.

The existing `ArcadeTimerHero.swift` already contains every Canvas primitive we need
(`drawSevenSegmentString`, `drawPixelBox`, `drawGlobalScanlines`, the score-slot / score-box / step-pill
helpers). **This is mostly a re-composition + rebind-to-live-data job, not a from-scratch build.**

---

## 1. Layout diagram (6.3" iPhone, portrait, ACTIVE / interval mode)

```
┌──────────────────────────────────────────────────────────────┐  ← ArcadeCabinetScene (full-bleed)
│▒▒▒▒▒▒▒▒  MARQUEE HOUSING (back-lit)  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│  ← marquee well (scene, ~52pt)
│   I N T E R V A L   R U N            ·   PLAYER 1             │  ← HERO: glow pulses w/ HR (forHRZone)
├──────────────────────────────────────────────────────────────┤
│ ███ pixel bezel + corner rivets (scene) ████████████████████ │  ← CRT bezel cut-out (recessed)
│ █ ░░░░░░░░░░░ CRT GLASS — scanlines + corner barrel ░░░░░░░ █ │
│ █  1UP                                     HI-SCORE        █ │
│ █  142  [Z3]                               03280          █ │  ← 1UP=HR (zone color) · HI=step count
│ █                                                          █ │
│ █              ███  0 1 : 4 8  ███   (7-seg)               █ │  ← HERO digit window (signature shape)
│ █                 WORK REMAINING                          █ │
│ █     STAGE 3-8   ▓▓▓░░░░░░  (power-bar = step progress)   █ │  ← interval only
│ █                                                          █ │
│ █  ┌HR──┐ ┌DIST─┐ ┌PACE─┐ ┌SPM──┐                         █ │  ← 5 CORE METRICS, pixel-boxed
│ █  │142 │ │2.15 │ │5:42 │ │168  │                         █ │     (HR zone-tinted; SPM replaces STEP)
│ █  └────┘ └─────┘ └─────┘ └─────┘                         █ │
│ ███████████████████████████████████████████████████████████ │
├──────────────────────────────────────────────────────────────┤
│  CONTROL PANEL HOUSING                                       │  ← panel well (scene, ~84pt)
│   ◉◉◉  joystick-LED ring     [ ‖ ]  [ ▶▶ ]  [ ■ ]  [ ✕ ]    │  ← LED ring = progress · arcade buttons
├──────────────────────────────────────────────────────────────┤
│  ▢  COIN DOOR   ·   CREDIT 02   ·   ▢                        │  ← coin door footer (CREDIT = steps done)
└──────────────────────────────────────────────────────────────┘
```

**Free-run mode:** marquee shows workout name; 7-seg hero = `ELAPSED`; STAGE power-bar + interval dots
hidden; LED ring driven by elapsed-vs-goal (or static idle if no goal); `CREDIT` = lap count or `01`.
**Gym-recovery mode:** 7-seg hero = station/rest elapsed (existing `heroTimeString` logic); STAGE bar
hidden; `CREDIT` = `recoverySetNumber`; the recovery Start/End-station buttons render in the control
panel above the global transport row (reuse the existing controls-bar gym-recovery branch contract).
**Paused:** marquee glow drops to dim, `★ INSERT COIN ★` blinks under the marquee title, transport
START key pops up (latch released), 7-seg digits hold last value.

---

## 2. Component breakdown

### NEW — `ArcadeCabinetScene : View, ThemedScene`

Append **below `VUReceiverScene`** in `ShuttlX/Theme/Components/ThemedSceneBackground.swift` (keep all
scene definitions colocated — house rule). Static cabinet only — **no live data, no marquee glow, no
7-seg digits, no LEDs** (identical read-only contract to `MixtapeCassetteScene`).

Sub-views (all `.allowsHitTesting(false)`):
1. **Cabinet body** — full-bleed `Rectangle` fill (`cabinetBlack` if user picks dark finish per
   README open-Q 4; else current navy `#0F0F2D`) + a subtle radial vignette darkening the outer 8%
   margin only (never the CRT area).
2. **Marquee housing** — top strip, height `ArcadeCabinetLayoutConstants.marqueeHeight`. A
   `RoundedRectangle(cornerRadius: 4)` filled darker than the body with a thin top/bottom pixel rule
   (reuse the `drawPixelBox` 2-px border technique). **Unlit** — the back-light glow is the hero's job.
3. **CRT bezel** — the recessed screen frame. Reuse `drawPixelBox` for the chunky pixel border + add
   four corner **rivets** (2×2 pt squares, same pattern already in the watch `ArcadeTimerOverlay`).
   The bezel is drawn *proud* (light top-left edge, dark bottom-right) so the CRT reads as recessed
   behind it.
4. **CRT glass** — inside the bezel: the existing scanline grid (`drawGlobalScanlines`) **plus** a
   corner-barrel darkening (`RadialGradient`, transparent center → `black.opacity(0.35)` corners) so
   the glass reads as curved tube glass. Gated by `showCRTContent` (default true; timer screen passes
   `false` so the hero owns the live CRT content without a duplicate).
5. **Control-panel housing** — lower strip, height `ArcadeCabinetLayoutConstants.panelHeight`. A
   slightly raised `RoundedRectangle` with an empty **joystick well** (recessed dark circle, left) and
   four **button wells** (recessed dark circles, right) — the hero's LED ring + transport buttons land
   in these. Use the recessed-well lighting technique from `MixtapeCassetteScene.hubWindowBezelView`
   (top-dark inner shadow).
6. **Coin-door footer** — thin bottom strip: two small recessed coin-slot rects flanking a centered
   `CREDIT` plate (the plate is static chrome; the hero overprints the live number). Optional brass
   recolor reuse of `MixtapeCassetteScene.screwView` for two faceplate screws.

```swift
enum ArcadeCabinetLayoutConstants {
    /// Marquee housing height (pt) at the top of the cabinet.
    static let marqueeHeight: CGFloat = 52
    /// Control-panel housing height (pt) above the coin door.
    static let panelHeight: CGFloat = 84
    /// Coin-door footer height (pt).
    static let coinDoorHeight: CGFloat = 28
    /// CRT glass rect as fractions of scene size (the live hero content area).
    /// Derived from marquee + panel + coin-door so the hero never overlaps housings.
    static let crtTopFraction: CGFloat = 0.10      // just below marquee
    static let crtBottomFraction: CGFloat = 0.72   // just above control panel
    static let crtInsetX: CGFloat = 16             // bezel thickness inset
    /// Joystick-LED ring center in the control panel (fractions of scene size).
    static let joystickCenter: (x: CGFloat, y: CGFloat) = (0.18, 0.80)
    static let joystickRingDiameter: CGFloat = 56
}
```

`contentSafeInsets` for the scene: `EdgeInsets(top: 60, leading: 20, bottom: 120, trailing: 20)`
(content lives inside the CRT glass).

### REWRITE — `ArcadeTimerHero`

Restructure `body` to the Mixtape `GeometryReader { screen in ZStack { ... } }` shape so live elements
anchor to `ArcadeCabinetLayoutConstants` in screen space.

> **User decision (README §10.3):** keep raw step count. The HI-SCORE slot (`hiCorner`) shows
> `controller.totalSteps` (arcade "score = steps"), NOT elapsed time — the 7-seg hero is the single
> time display, so HI is free to carry the step "score." The 4th metric box is SPM (cadence).

**KEEP unchanged from current hero** (do not rewrite these — they are correct):
- Full palette block (lines 37–45) — `phosphorGreen`, `cabinetBlack`, `playerRed`, `coinYellow`,
  `cyanScore`, etc.
- The entire `Canvas` 7-segment renderer: `drawSevenSegmentString`, `hSegPath`, `vSegPath`,
  `segmentMasks`.
- `drawPixelBox`, `drawGlobalScanlines`.
- `heroTimeString`, `heroSubLabel`, `heroDisplayColor`, `heroA11yLabel` (mode-branched hero logic).
- `scoreBox(...)`, `upCorner` / `hiCorner` (1UP / HI slots), `stepPillInfo`, all the
  `appType`/`sharedStepColor`/`displayName`/`hrZoneLabel` helpers.
- Both `.alert`s (finish/cancel confirmations) and the `@State` flags.

**REPLACE / REBIND:**
- `cabinetBlack.ignoresSafeArea()` + global scanlines in `body` → **deleted from the hero**; the
  cabinet body, scanlines, and CRT barrel now come from `ArcadeCabinetScene` via
  `timerScreenBackground`. The hero draws only the live CRT content + control panel content.
- `scoreMetricStrip` — **swap the 4th box from raw `STEP` to `SPM`**: change
  `scoreBox(label: "STEP", value: "\(controller.totalSteps)", ...)` →
  `scoreBox(label: "SPM", value: cadenceScoreValue, color: coinYellow)` (see `cadenceScoreValue`
  below). The other three boxes (HR / DIST / PACE) are unchanged.
- `bannerRow` `INSERT COIN` / `HI-SCORE` blink — keep the **paused** `INSERT COIN` blink branch
  (it is honestly bound to `controller.isPaused`). The non-paused branch becomes the **marquee title**
  rendered in the marquee housing, not a center banner.
- `dotCircle` active-dot blink — **rebind from wall-clock to step progress.** Replace the
  `TimelineView`-driven brightness with brightness = `stepProgress` (see below): the active dot glows
  brighter as the current step nears completion. Reduce Motion → solid.
- `arcadeControlsBar` — keep the action wiring (pause/resume, skip, finish, cancel, gym Start/End), but
  render each as a **round arcade button** via `ThemedTransportButtonStyle` (Arcade spec, §6) instead
  of the ad-hoc `arcadeButton`/pixel-box fills.

**NEW in hero** (the live cabinet elements):
- `marqueeGlowLayer(screenSize:)` — a full-width layer positioned over the scene's marquee housing via
  `.position`/`.frame` using `ArcadeCabinetLayoutConstants.marqueeHeight`. A `RadialGradient` glow
  behind the marquee title text. **HR-driven:**

```swift
/// Marquee back-light intensity from heart rate. Glow radius/opacity scale with
/// bpm/200, tinted by the HR zone. A short throb envelope retriggers on each BPM
/// change (onChange) so the marquee "lights up harder" as the heart works.
/// Reduce Motion: static glow at the current zone color, no throb.
private var marqueeGlowColor: Color {
    let bpm = controller.heartRateMonitor.current
    return bpm > 0 ? ShuttlXColor.forHRZone(bpm) : phosphorGreen
}
private var marqueeGlowFraction: Double {
    let bpm = controller.heartRateMonitor.current
    guard bpm > 0 else { return 0.15 }            // dim "attract" glow before HR
    return max(0.2, min(1.0, Double(bpm) / 200.0))
}
```

  Animate the throb on `.onChange(of: controller.heartRateMonitor.current)` with
  `.easeOut(duration: 0.18)` (one quick bloom per beat-ish update). When `controller.isPaused`, drop
  the glow to `0.12` opacity (marquee "powered down").

- `joystickLEDRing(screenSize:)` — positioned at `ArcadeCabinetLayoutConstants.joystickCenter` inside
  the scene's joystick well. A ring of N pixel LEDs (e.g. 12) lit clockwise by **workout progress:**

```swift
/// Overall workout-progress fraction driving the joystick LED ring (README open-Q 2:
/// proposes OVERALL progress, distinct from the STAGE step bar).
private var workoutProgressFraction: Double {
    switch controller.mode {
    case .interval:
        guard let e = controller.intervalEngine, e.totalStepsCount > 0 else { return 0 }
        return Double(e.currentStepIndex) / Double(e.totalStepsCount)
    case .gymRecovery:
        return 0   // no fixed total; ring stays at attract-idle (see open-Q)
    case .freeRun:
        return 0   // no goal; ring idle unless a goal is later wired
    }
}
```

  Light `Int(workoutProgressFraction * ledCount)` LEDs in `phosphorGreen`, the rest dim
  (`phosphorDim`). Reduce Motion → static fill (no sweep animation).

- `stepProgress` computed (drives the active interval dot brightness + the STAGE power-bar fill):

```swift
private var stepProgress: Double {
    guard let e = controller.intervalEngine, let step = e.currentStep, step.duration > 0,
          let remaining = e.currentStepTimeRemaining else { return 0 }
    return max(0, min(1, 1.0 - remaining / step.duration))
}
```

- `cadenceScoreValue` (drives the new SPM box):

```swift
/// SPM box value. `—` only during the brief first-window before cadence is live;
/// `0` when genuinely stationary (per docs/memory/cadence-derivation.md, the
/// step-delta fallback makes cadence dependable ~3s in).
private var cadenceScoreValue: String {
    let spm = controller.currentCadence
    return spm > 0 ? "\(spm)" : "—"
}
```

- `stagePowerBar` — replace the existing capsule-style progress (if any) with a **pixel-segmented bar**
  inside the CRT: ~10 cells, `Int(stepProgress * 10)` filled `phosphorGreen`, rest `phosphorDim`,
  drawn with `drawPixelBox`-style segments. `.animation(.linear(duration: 1), value: stepProgress)`.

### Deterministic placement (the load-bearing pattern)

Anchor the CRT content band exactly as Mixtape anchors `vuAndPaceStrips` / VU anchors its readout band
— never guess sibling heights:

```swift
GeometryReader { screen in
    ZStack {
        // Marquee glow + title, positioned over the scene marquee housing
        marqueeGlowLayer(screenSize: screen.size)
            .frame(height: ArcadeCabinetLayoutConstants.marqueeHeight)
            .frame(maxHeight: .infinity, alignment: .top)

        // CRT content column, inset to land inside the bezel
        VStack(spacing: 6) {
            Color.clear
                .frame(height: screen.size.height
                       * ArcadeCabinetLayoutConstants.crtTopFraction)
            scoreSlotsRow          // 1UP / HI
            digitHeroBox           // 7-seg window
            if controller.mode == .interval { stagePowerBar; intervalDotsRow }
            scoreMetricStrip       // HR / DIST / PACE / SPM
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ArcadeCabinetLayoutConstants.crtInsetX)

        // Control panel: LED ring + transport buttons over the scene panel wells
        joystickLEDRing(screenSize: screen.size)
        arcadeControlsBar
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, ArcadeCabinetLayoutConstants.coinDoorHeight + 8)

        coinDoorCredit             // CREDIT NN over the scene coin-door plate
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
```

---

## 3. Exact placement of the 5 core metrics + legibility rationale

The hard constraint: a sweaty 55-year-old mid-treadmill reads **HR + zone, time, pace, distance,
cadence** in under a second. Placement and rationale:

| Metric | Where | Size / style | Legibility rationale |
|---|---|---|---|
| **Heart rate + zone** | TWO places: 1UP slot (top-left of CRT) **and** HR score box | 1UP `18pt` heavy mono + `Z#` badge; box `14pt` | HR is the cardiac-critical number — redundant top-left placement (where the eye lands first, left-to-right) + box ensures it is never lost behind chrome. Zone color via `ShuttlXColor.forHRZone`. |
| **Time (elapsed / countdown)** | HI slot (elapsed) + the **7-seg hero window** (mode time) | hero 7-seg ~`88pt` window; HI `18pt` | The hero is the single largest element; never occluded — the CRT barrel darkening is clamped to the outer margin and never touches the digit window. |
| **Pace** | PACE score box | `14pt` heavy mono, `cyanScore` | One of four equal pixel boxes in a single row beneath the hero — a stable, scannable grid. `--:--` guarded. |
| **Distance** | DIST score box | `14pt` heavy mono, `phosphorGreen` | Same row; `FormattingUtils.formatDistance`. |
| **Cadence (SPM)** | SPM score box (NEW — replaces raw STEP) | `14pt` heavy mono, `coinYellow` | Mandated 5th core metric. `—` first-window / `0` stationary. |

**Anti-crowding / anti-occlusion rules (enforced):**
- The four score boxes stay a single equal-width row; no 5th box crammed in (HR is the redundant
  top-left slot, not a 5th box).
- CRT corner-barrel darkening clamps to the outer 8% — it must **never** dim the digit window, the
  1UP/HI slots, or the score boxes. (Verify on device against the deepest corner.)
- Marquee glow lives *above* the CRT in its own housing; it cannot bleed onto the digit window.
- `minimumScaleFactor(0.7)` on every numeric (already present).
- Control-panel LED ring + buttons sit in their own housing *below* the CRT — chrome and data never
  share a band.

---

## 4. Controls treatment (arcade transport buttons)

Replace the ad-hoc `arcadeButton` pixel-box fills with the shared `ThemedTransportButtonStyle`:

```swift
Button { controller.skipStep() } label: {
    Image(systemName: "forward.end.fill").frame(width: 56, height: 56)
}
.buttonStyle(ThemedTransportButtonStyle(role: .skip))
.accessibilityLabel("Skip step")

Button { controller.isPaused ? controller.resume() : controller.pause() } label: {
    Image(systemName: controller.isPaused ? "play.fill" : "pause.fill").frame(width: 64, height: 64)
}
.buttonStyle(ThemedTransportButtonStyle(role: .pause, isLatched: !controller.isPaused))
.accessibilityLabel(controller.isPaused ? "Resume workout" : "Pause workout")
```

- Map roles: cancel → `.stop`-styled distinct cap; skip → `.skip`; pause/resume → `.pause`/`.play`
  with `isLatched: !controller.isPaused` so the START key **stays depressed while the game runs**
  (the arcade equivalent of Mixtape's PLAY latch and a free secondary paused cue).
- Gym-recovery Start/End-station buttons render in the panel above the global row (same contract as the
  existing controls bar gym branch — reuse it; do not re-implement station logic).

---

## 5. Arcade `TransportButtonSpec` (add to `ThemedTransportButton.swift`)

Add an `arcade` case to `ThemedTransportButtonStyle.spec(for:role:)` — a **round, hard-clicking arcade
button** (concave well → convex cap, deeper travel, sharp haptic):

```swift
case "arcade":
    var base = TransportButtonSpec(
        cornerRadius: 28,                         // round cap (28 on a 56pt frame ≈ circle)
        travel: 4,                                // hard arcade-button throw
        capTop:    Color(red: 0.95, green: 0.20, blue: 0.20),  // player-red cap top
        capBottom: Color(red: 0.62, green: 0.06, blue: 0.06),  // cap bottom
        channel:   Color(red: 0.04, green: 0.04, blue: 0.04),  // black recessed well
        glyph:     Color(red: 0.06, green: 0.06, blue: 0.18),  // dark glyph on bright cap
        highlight: .white,
        depressLatches: true,                     // PLAY/START latches while running
        haptic: .impact(weight: .rigid)           // sharp "click" vs Mixtape's heavy "clunk"
    )
    switch role {
    case .pause, .play: base.proudBoost = 1       // START/PAUSE leads visually
    case .stop:                                    // FINISH = green confirm cap, distinct from CANCEL
        base.capTopOverride    = Color(red: 0.20, green: 1.0, blue: 0.08)
        base.capBottomOverride = Color(red: 0.06, green: 0.55, blue: 0.04)
        base.glyphOverride     = Color(red: 0.06, green: 0.06, blue: 0.18)
    default: break
    }
    return base
```

Color choices use the Arcade palette (player-red, phosphor-green) so buttons read as cabinet hardware,
not generic CTAs. The press physics/haptic/44 pt-min/Reduce-Motion handling are inherited from the
shared style — **do not re-implement.**

---

## 6. State variants

| State | Marquee glow | 7-seg hero | STAGE bar / dots | LED ring | Score boxes | INSERT COIN |
|---|---|---|---|---|---|---|
| **idle / not-started** | dim attract (0.15) | `00:00` / `READY` sub | hidden / dim | static idle (off) | `—` until live | hidden |
| **loading (no HR yet)** | dim attract | runs (time is local) | per-mode | per-mode | HR `—`, others live | hidden |
| **active** | HR-driven throb | running, step color | filling | progress-filled | all live | hidden |
| **stationary (active, 0 SPM)** | HR-driven | running | filling | per progress | SPM `0` | hidden |
| **paused** | powered-down (0.12) | holds last value | frozen | frozen | frozen | **blinking** |
| **error (HR lost)** | drops to `phosphorGreen` dim | unaffected | unaffected | unaffected | HR box `—` | hidden |
| **complete (interval)** | last HR glow | `COMPLETE` (not "GAME OVER") | full | full | last values | hidden |

Reduce Motion / Low Power across all states: marquee glow static, LED ring static-filled, active dot
solid (no blink), INSERT COIN solid, button travel = 0.

---

## 7. Wiring changes in `ShuttlX/Theme/ThemeModifiers.swift`

- **`arcadeBackground()` / `arcadeCRTBackground()`** → replace the flat fill + scanlines + vignette
  ZStack with `ArcadeCabinetScene(showCRTContent: true).allowsHitTesting(false).ignoresSafeArea()`
  (same shape as `mixtapeBackground()`).
- **`timerScreenBackground(themeID:)`** → add an `arcade` branch drawing
  `ArcadeCabinetScene(showCRTContent: false)` so the hero owns the live CRT content (mirror of the
  `mixtape` branch passing `showJCard: false`).

---

## Implementation hand-off
- **Files to create:** `ArcadeCabinetScene` struct + `ArcadeCabinetLayoutConstants` enum, both
  appended to `ShuttlX/Theme/Components/ThemedSceneBackground.swift` (same file as
  `MixtapeCassetteScene` / `VUReceiverScene` — colocate, do not make a new file).
- **Files to modify:**
  - `ShuttlX/Theme/Themes/ArcadeTimerHero.swift` (re-compose to scene-anchored overlay; rebind every
    animation to live data; swap `STEP` box → `SPM`; route controls through `ThemedTransportButtonStyle`.
    KEEP palette, 7-seg + pixel-box Canvas, score-slot/box/pill helpers, alerts).
  - `ShuttlX/Theme/ThemeModifiers.swift` (`arcadeBackground()`/`arcadeCRTBackground()` → scene; add
    `arcade` branch to `timerScreenBackground(themeID:)`).
  - `ShuttlX/Theme/Components/ThemedTransportButton.swift` (add `arcade` case to `spec(for:role:)`).
- **Reuse existing:** the entire `ArcadeTimerHero` Canvas primitive set
  (`drawSevenSegmentString`/`hSegPath`/`vSegPath`/`segmentMasks`/`drawPixelBox`/`drawGlobalScanlines`),
  `MixtapeCassetteScene.hubWindowBezelView` (recessed-well lighting for joystick/button wells),
  `MixtapeCassetteScene.screwView` (coin-door faceplate screws), `ThemedTransportButtonStyle`,
  `ShuttlXColor.forHRZone` / `forStepType`, `FormattingUtils.*`, the `Color.clear`-spacer +
  `*LayoutConstants` deterministic-placement pattern from `MixtapeTimerHero` / `VUMeterTimerHero`.
- **Theme variants verified:** Arcade only. The scene/hero/spec are only constructed when
  `themeManager.current.id == "arcade"`; the 7 other themes are untouched (their
  `timerScreenBackground` cases are unchanged; the `ThemedTransportButton` default case still serves
  every non-mixtape/non-arcade theme). Clean stays the cardiac-accessibility baseline — unaffected.
- **Open questions for dev:**
  1. README open-Q 1 (full cabinet vs marquee-only) and open-Q 4 (dark vs navy finish) change
     `ArcadeCabinetScene` geometry/palette — confirm the user's choice before building the scene.
  2. Confirm `controller.currentCadence` publishes on the same tick as the other live metrics so the
     SPM box updates smoothly (verify against `iPhoneWorkoutController`; VU proposal flagged the same).
  3. README open-Q 2: LED ring = overall workout progress (proposed). For free-run/gym-recovery there
     is no fixed total — confirm the ring should sit at attract-idle in those modes (current spec), or
     whether you want it to mirror the STAGE step bar instead.
