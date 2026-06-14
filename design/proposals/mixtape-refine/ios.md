# Mixtape Refine — iOS hand-off spec

Primary doc. Owner: `senior-ios-developer`.
Scope files: `MixtapeTheme.swift`, `MixtapeTimerHero.swift`,
`ThemedSceneBackground.swift` (MixtapeCassetteScene), `ThemedTransportButton.swift`.

Build after each phase: `bash tests/build_and_test_both_platforms.sh --clean --build`.
**P1 (safety + trademark) must ship together** — the rest is incremental polish.

---

## 0. The redesigned iOS Free Run deck — full-screen ASCII mockup

Free Run is the hero screen. Layout below is the target (ACTIVE state). Annotations
give exact tokens / sizes. Everything sits ON the cassette shell scene; the hero
draws live content on top.

```
 ┌──────────────────────────────────────────────┐  ← shell #26303F→#161E29 vertical
 │ ◉                                          ◉ │  ← corner screws (scene, 12pt)
 │  ╔════════════════════════════════════════╗  │
 │  ║[SIDE A] ●REC  MORNING RUN      4.12 KM ║  │  ← J-card laid-paper texture
 │  ║         8pt   italic (no rotation)  lcdGreenDim 11pt║   #EDE7D3 + corner creases
 │  ║───────────────────────────────────────║  │  ← baseline rule labelInk 0.25
 │  ║      ┌──────────────┐                  ║  │
 │  ║      │ 88:88  12 34 │  STATION/STEP    ║  │  ← LCD counter: ghost "8888" 0.04,
 │  ║      │ ELAPSED      │  pill (n/a freerun)║    center divider 1pt, 28pt lcdGreen
 │  ╚══════└──────────────┘══════════════════╝  │
 │                                                │
 │     ╭────╮      glass glare ╲      ╭────╮      │  ← hub WINDOWS (clear polycarb,
 │    │ ▓▓▓▓ │   ┌─leader─┐    │ ░░░░ │      │      green-tinted) — live reels
 │    │ ████ │   │▓░░░░░░░│    │ ░██░ │      │      SUPPLY scale 1.0→0.65 (shrinks)
 │     ╰────╯      tape bar      ╰────╯      │      TAKE-UP 0.65→1.0 (grows)
 │   supply ω↑ (fat→thin)        take-up ω↓ (thin→fat)
 │                                                │
 │  ┌──────────────────────────────────────────┐ │  ← matte-black HEAD panel (felt
 │  ║▌ HR  ▮▮▮▮▮▮▯▯▯▯           [142] bpm      ║ │    edge); DIFFERENT material than
 │  ║▌      10-seg VU (z-color) 28pt lcdGreen  ║ │    the green-glass window above
 │  ║▌ SPD  ·····|····>·····    [5'48] /km     ║ │  ← pace NUMERIC dominant 18-20pt,
 │  ╚══════════════════════════════════════════╝ │    needle = thin secondary flourish
 │                                                │
 │   ◀◀        ┌────────────────┐        ■        │  ← transport keys
 │  CANCEL     │   ▶  PLAY       │      STOP       │    PLAY proud+lighter (latches)
 │  (gray)     │  (proud cap)    │   (accentBlue) │    STOP = blue cap, white glyph
 │ ◉            └────────────────┘             ◉ │  ← bottom screws (scene)
 │  IEC TYPE II · HIGH BIAS         C-90 · 90 MIN │  ← brand strip (generic, no TM)
 └──────────────────────────────────────────────┘
```

PAUSED state delta: amber tint on counter + name + reels frozen + a **solid amber
PAUSED chip** (#F2A61A fill, #1C2330 ink) top-right of the J-card. COMPLETE state:
reels parked at progress 1.0, "SIDE A COMPLETE" in **lcdGreen** (not blue),
"▶▶ FLIP TO SIDE B?" hint.

---

## P1 — Safety + trademark (SHIP TOGETHER, blocking)

### P1-1 (also a craft win) — Differential reel fill + variable RPM
**File:** `MixtapeTimerHero.swift` reels (L329–382) and the static thumbnails in
`ThemedSceneBackground.swift` (`staticReelThumbnail` L304–390 already has the
shrink/grow math — mirror it onto the live reels).

Introduce a single scalar:
```
tapeProgress: Double   // 0 at workout start → 1 at "end of side"
  freeRun:  min(1.0, controller.elapsedTime / 3600.0)   // reuse tapeProgressBar nominal (L488)
  interval: Double(currentStepIndex) / Double(totalStepsCount)  // whole-workout, NOT per-step
```
Drive the live `reelView` (L340):
- **Supply reel (left):** `scale = 1.0 - 0.35 * tapeProgress`  → 1.0 down to 0.65
- **Take-up reel (right):** `scale = 0.65 + 0.35 * tapeProgress` → 0.65 up to 1.0
- Apply via `.scaleEffect(scale)` on `reelImage` (inside the clip, so the visible
  oxide pack appears to grow/shrink against the fixed hub window).
- **RPM coupling:** in `reelAngle` (L360), multiply each reel's angular velocity by
  `1.0 / scale` so the thinner reel spins faster (ω ∝ 1/radius). Keep the existing
  `baseSpeed 45 + paceBonus` as the base; final ωₗ = base / supplyScale,
  ωᵣ = base / takeUpScale. Cap final ω at 140°/s to avoid strobing.
- Keep the existing supply=CCW (−1), take-up=CW (+1) directions.
- Reduce Motion / Low Power (`reduceDetail` L73): static reels at their
  current-progress scale (no spin), as today.

This is the single biggest authenticity win — prioritize it for Free Run.

### P1-2 — Shared layout constants (reels sit exactly over scene bezels)
**Problem:** scene bezels at `x: w*0.30 / 0.70, y: h*0.58`
(`ThemedSceneBackground.swift` L128–142) vs hero live reels at `x: w*0.28 / 0.72`
inside a separate `GeometryReader` with `.padding(.horizontal, 28)`
(`MixtapeTimerHero.swift` L298–319) — misaligned, worst on Pro Max widths.

**Fix:** add one source of truth (new tiny struct in `ThemedSceneBackground.swift`,
both files import it):
```
enum MixtapeLayoutConstants {
    static let hubCenterXFraction: (CGFloat, CGFloat) = (0.30, 0.70)
    static let hubCenterYFraction: CGFloat = 0.58   // of full-screen scene height
    static let hubDiameter: CGFloat = 96
}
```
- Scene uses these for both `hubWindowBezelView` and `staticReelThumbnail` positions.
- Hero `reelHubWindowsRow` must compute positions in the **same coordinate space**
  as the scene (full-screen, not the inset VStack). Recommended: lift the live reels
  out of the VStack flow into a `ZStack` overlay on the hero root keyed to screen
  geometry, OR pass the scene's GeometryReader size down. Either way the two `x`
  fractions and `y` fraction MUST be identical to the scene. Verify on iPhone 16
  Pro Max + SE.

### P1-B — Zone color remap (CARDIAC SAFETY — Z1 ≠ Z2)
**File:** `MixtapeTheme.swift` L28–32. Today Z1 and Z2 are the identical #39FF14 —
a rehab patient told "stay in Zone 2" cannot distinguish Z1 from Z2. Z3 blue vs Z4
purple-blue is only ~1.19:1. Remap to a **traffic-light** ramp so "don't exceed"
(Z4) is unmistakably distinct:

```
hrZone1: lcdGreenDim   #1C8009 (0.11, 0.50, 0.04)   // base, calm
hrZone2: lcdGreen      #39FF14 (0.22, 1.00, 0.08)   // target — bright green, clearly > Z1
hrZone3: amber         #F2A61A (0.95, 0.65, 0.10)   // working
hrZone4: orange-red    #FF6A1A (1.00, 0.42, 0.10)   // ceiling — distinct from amber AND red
hrZone5: ledRed        #FF3333 (1.00, 0.20, 0.20)   // max
```
The 10-seg VU bar in `hrVUStrip` (L548–560) currently hard-codes green/amber/red by
index — leave that preattentive bar as-is, but the **numeric BPM color** at L568
uses `ShuttlXColor.forHRZone(bpm)` which now reads the corrected tokens. No call-site
change needed; only the token values change.

### P1-C — PAUSED chip: solid amber, dark ink (was ~1.5:1, near-invisible)
**File:** `MixtapeTimerHero.swift` L207–219. Replace the `amberPause.opacity(0.15)`
fill with a **solid** chip:
- background fill: `amberPause` (#F2A61A) solid
- text foreground: `labelInk` (#1C2330) — dark ink on amber ≈ 6:1
- keep `RoundedRectangle(cornerRadius: 3)`, drop the 0.5 stroke (solid fill carries it)
- bump font 8pt → **9pt** heavy for legibility.

### P1-D — Free-Run HR prominence (primary cardiac metric)
**File:** `MixtapeTimerHero.swift` `hrVUStrip` L536–581. The 16pt BPM numeric (L566)
is too small for the #1 cardiac metric, especially in Free Run. Spec:
- BPM numeric **28pt** bold mono, color `ShuttlXColor.forHRZone(bpm)` (post P1-B),
  with the existing `.contentTransition(.numericText())`.
- "bpm" label stays 9pt textSecondary, baseline-aligned.
- Widen the trailing readout block from `width: 54` to **72** to fit 28pt + "bpm".
- Add a small zone badge `[Z3]` (9pt, zone color, 1pt stroke) immediately right of
  the number — reuse the watch's Z-badge pattern. The 10-seg VU bar stays as the
  preattentive indicator; the **number + badge are the readout**.
- Keep the felt-pad edge accent.

### P1-E — Pace numeric dominant, needle secondary
**File:** `MixtapeTimerHero.swift` `paceSpeedStrip` L583–640. The 3pt needle is the
dominant pace cue today and is unreadable mid-run. Spec:
- Pace numeric **20pt** bold mono lcdGreen (up from 15pt at L627), width block → 76.
- Demote the needle: keep it but thin to **2pt**, reduce shadow radius 3→2, and
  shrink the needle track height so it reads as a secondary flourish under/behind
  the number, not the main element. The number is the readout; the needle is decor.

### Trademark scrub (visible UI + a11y + struct names) — BLOCKING
**`ThemedSceneBackground.swift` brandStrip L416–428:**
```
"BASF"          → "IEC TYPE II"
"TYPE II · 90"  → "HIGH BIAS · 90"
"C-90"          → "C-90 · 90 MIN"
```
**`MixtapeTimerHero.swift` accessibility hints** — remove "Walkman" from L662, L680,
L708, L725. Generic replacements:
- L662 (cancel): `"Ends without saving. Rewind key."`
- L680 (skip): `"Skips to the next interval step. Fast-forward key."`
- L708 (play): `"Play key. Latches down while tape is running."`
- L725 (stop): `"Saves and ends the workout. Stop key."`
- Doc comment L17 "Walkman transport keys" → "cassette transport keys".

`ThemedTransportButton.swift` doc comments L66, L68 mention "Walkman" → "transport"
(comments only; no code change).

> Watch-side trademark (TrainingView L645/647/680, `WalkmanRecoveryKeyStyle`
> RecoveryWorkoutView L208/260/267) is in `watch.md` — owned by the watch specialist.

---

## P2 — Authenticity (incremental)

### P2-1 — Hub windows lit correctly (currently inverted)
**File:** `ThemedSceneBackground.swift` `hubWindowBezelView` L281–301. Real inset is
LIT at top, shadowed at bottom; current gradient is inverted. Replace:
- inner shadow gradient: **top black 0.6 → bottom black 0.15** (cut-out reads concave)
- add a **2pt ABS rim ring**: `LinearGradient(white 0.45 topLeading → white 0.18
  bottomTrailing)` stroked just outside the bezel
- faint topLeading translucency dot/arc: white 0.08
Apply to both bezel positions.

### P2-2 — J-card laid-paper texture + corner creases
**Files:** `ThemedSceneBackground.swift` `jCardLabel` L221–242 AND
`MixtapeTimerHero.swift` `jCardLabelSection` paper fill L138–156.
- Overlay a Canvas: horizontal lines every **4pt** at `labelInk.opacity(0.025)`.
  Reuse the lined-Canvas approach from `ClassicRadioTimerFrame`
  (`ThemeAssets.swift` ~L517 brushed-metal lines) — copy the pattern, recolor to ink.
- Add **2 diagonal corner crease marks** (top-left + bottom-right), a 1pt
  `labelInk.opacity(0.12)` short diagonal stroke ~10pt long, to sell aged paper.
- Both overlays `.allowsHitTesting(false)`, clipped to the 6pt-radius rect.

### P2-3 — Window vs head-panel material differentiation
The hub windows and the HR/pace panel currently use near-identical dark fills.
- **Hub windows** = clear polycarbonate: tint the live-reel clip background a faint
  green `Color(0.05,0.10,0.06).opacity(0.5)` and add the glass glare (see Signature
  Touch #2 below). `MixtapeTimerHero.swift` reel clip L307/L313.
- **HR/pace panel** (`vuAndPaceStrips` background L518–532) = matte-black
  head-contact panel: keep `#0A1219`-ish flat fill but DROP any sheen; this panel
  should read flat/matte to contrast the glossy green window. Keep the felt edge.

### P2-4 — Transport keycaps: dome specular + proud PLAY + recessed channel
**File:** `ThemedTransportButton.swift` `makeBody` L80–128.
- **Top-edge dome specular:** replace the flat 2pt highlight (L105–110) with a 4pt
  `white.opacity(0.25)` band narrowing to 60% width via a diamond/triangle mask so
  the cap reads domed, not flat. Collapses on press (keep `highlightOpacity` logic).
- **PLAY proud + lighter:** when `role == .play`, lighten `capTop/capBottom` ~8% and
  add +1pt rest elevation (shadow radius 5 instead of 4) so PLAY visually leads.
- **Recess the channel:** add an inner **top shadow** inside the channel
  (`black.opacity(0.5)`, 2pt) so the keycap sits in a real well.

### P3 (grouped here for sequencing) authenticity nods

### P2-B — Distance / Steps contrast (borderline/fail on cream)
**File:** `MixtapeTimerHero.swift` L223–232. KM at lcdGreenDim on cream ≈ 4.12:1,
STEPS at `labelInk.opacity(0.5)` ≈ 3.0:1 (fail). Fix:
- KM: use **labelInk** (#1C2330, ~13:1) bold, keep 9pt → 10pt.
- STEPS: use `labelInk.opacity(0.75)` (≈ 8:1), 9pt.
- (lcdGreen-on-cream never passes; reserve lcdGreen for the dark LCD well only.)

### P2-G — Drop name rotation (overlap risk), keep italic
**File:** `MixtapeTimerHero.swift` L190 & L198. Remove `.rotationEffect(-3°)` on the
workout name (long names rotate into the PAUSED chip). Keep `.italic()` for the
skewed look. Same for "SIDE A COMPLETE" L190.

---

## P3 — Polish

### P3-1 — Leader-tape progress bar + "nearly done" tint
**File:** `MixtapeTimerHero.swift` `tapeProgressBar` L481–508.
- At progress 0, draw a **6pt pale white.0.35 leader** at the track's left edge.
- When progress > ~0.85, tint the **remaining** track `ledRed.opacity(0.5)` (UX
  affordance: tape almost out / step almost done).

### P3-4 — Authentic LCD counter touches (KEEP 4-digit no-colon)
**File:** `MixtapeTimerHero.swift` `lcdCounter` L386–421. Per prior user decision the
counter stays 4 digits, no colon (tape-counter look). Add:
- a faint **center divider** 1pt `lcdGreenDim.opacity(0.20)` between the two digit
  pairs (this is the physical module gap, NOT a colon)
- a **ghost "8888"** behind the active digits at `lcdGreen.opacity(0.04)` (dead-pixel
  LCD look). Render as a back layer in the ZStack at L388, same font/size/tracking.

### P3-B — REC dot bigger / full opacity
**File:** `MixtapeTimerHero.swift` L173–182. Bump the dot 6pt → **8pt**, full-opacity
`ledRed` when running (keep dim 0.3 when paused/complete), keep the pulse halo.

### P3-C — "SIDE A COMPLETE" in lcdGreen (was blue, low pop)
**File:** `MixtapeTimerHero.swift` L186–188. Change foreground `accentBlue` → `lcdGreen`.

### P3-F — STOP vs CANCEL keycap differentiation (prevent destructive misfire)
**File:** `MixtapeTimerHero.swift` transport keys L644–726. STOP (save) and CANCEL
(discard) keycaps look identical today. Give **STOP** a distinct cap:
- pass a per-role cap override so STOP renders an **accentBlue cap with a white
  glyph** (add an optional `capOverride`/`glyphOverride` to `TransportButtonSpec`
  in `ThemedTransportButton.swift`, OR a `role`-aware branch in `spec(for:)`).
- CANCEL stays the neutral gray cap. The existing confirmation alerts (L109–130)
  stay — this is belt-and-suspenders against accidental destructive taps.

### H3 — Dynamic Island safe-area
**File:** `MixtapeTimerHero.swift` L88 & L108. `padding(.top, 56)` +
`.ignoresSafeArea(edges: .top)` is calibrated for iPhone 15; on 16 Pro Max the J-card
can collide with the Dynamic Island. Use:
```
.padding(.top, max(56, safeAreaInsets.top + 12))   // read via GeometryReader safeAreaInsets
```

---

## Signature touches (the "unique" asks)

### #1 Differential reel fill — see P1-1 (the headline). Free Run shows tape winding
left→right over the workout; interval shows whole-workout progress.

### #2 Moving tape sheen + glass glare (decorative, behind metrics, motion-gated)
- **Glass glare:** one fixed diagonal specular streak across each hub window —
  `LinearGradient(white 0.10 → clear)` at ~35° drawn inside the reel clip, ABOVE
  the reel, `.allowsHitTesting(false)`. Static (does not move). Sells "real glass."
- **Tape sheen:** a slow horizontal `white.opacity(0.06)` band that travels across
  the matte head-panel once per ~6s while `isRunning` via `TimelineView` (reuse the
  24fps timeline already in `reelView`). Paused: parked. Disabled under
  `reduceDetail`. This is the "moving tape behind the window" cue.

Both are low-opacity, behind all numbers, and never animate during Reduce Motion /
Low Power — they cost nothing in legibility and a lot in "finished object" feel.

---

## State coverage (all required, designed)

- **IDLE / READY:** reels static at progress 0 (supply fat, take-up thin), PLAY up,
  counter "0000 READY", REC dim. (Scene resting state already covers most.)
- **ACTIVE:** reels spin (differential), PLAY latched down, REC full-opacity pulse,
  sheen + glare on, counter green.
- **PAUSED:** reels frozen, PLAY pops up, amber tint on counter+name, **solid amber
  PAUSED chip**, sheen parked.
- **COMPLETE:** reels parked at progress 1.0 (supply thin, take-up fat),
  "SIDE A COMPLETE" lcdGreen, "▶▶ FLIP TO SIDE B?" hint, REC off.
- **No-data HR:** "—" bpm, no zone badge, VU bar empty (existing behavior at L565).

---

## Implementation hand-off
- **Files to create:** none (one new `MixtapeLayoutConstants` enum lives inside the
  existing `ThemedSceneBackground.swift`).
- **Files to modify:**
  - `ShuttlX/Theme/Themes/MixtapeTheme.swift` (P1-B zone tokens L28–32)
  - `ShuttlX/Theme/Themes/MixtapeTimerHero.swift` (P1-1, P1-C, P1-D, P1-E, P2-2,
    P2-3, P2-B, P2-G, P3-1, P3-4, P3-B, P3-C, P3-F, H3, trademark hints, sheen/glare)
  - `ShuttlX/Theme/Components/ThemedSceneBackground.swift` (P1-2 constants, P2-1,
    P2-2, trademark brand strip L416–428)
  - `ShuttlX/Theme/Components/ThemedTransportButton.swift` (P2-4 dome/recess, P3-F
    STOP cap override, comment trademark scrub)
- **Reuse existing:** `ShuttlXColor.forHRZone()` (token values change, not call
  sites); `ClassicRadioTimerFrame` lined-Canvas pattern (`ThemeAssets.swift` ~L517);
  `MixtapeReel` image asset; `staticReelThumbnail` shrink/grow math
  (`ThemedSceneBackground.swift` L304–390) as the reference for live differential fill;
  existing 24fps `TimelineView` in `reelView` for the sheen.
- **Theme variants verified:** all changes are inside `id == "mixtape"` paths or
  Mixtape-only theme tokens / Mixtape-only components — no impact on the other 7
  themes. `ShuttlXColor.forHRZone` token change is Mixtape-scoped (lives in
  `MixtapeTheme.swift`). Verify Clean still passes (it owns the separate token set).
- **Open questions for dev:**
  1. P1-2: cleanest way to share one coordinate space — lift live reels into a
     screen-keyed ZStack overlay, or thread the scene's GeometryReader size into the
     hero? Watch specialist will want the same answer for consistency.
  2. P1-1 interval `tapeProgress`: confirm whole-workout fill (stepIndex/total) reads
     better than per-step for intervals, or should interval reels reset per step? I
     recommend whole-workout (one continuous wind = one tape) — confirm.
  3. P3-F: extend `TransportButtonSpec` with optional cap/glyph overrides vs a
     role branch in `spec(for:)` — your call on the cleaner API.
  4. Confirm 140°/s ω cap (P1-1) and ~6s sheen period (Sig #2) feel right on device —
     these are starting values, tune live.
</content>
