# Mixtape Walkman Refresh — iOS hand-off

**Read `spec.md` first** for palette rationale, ASCII mockups, and the signature-shape decision. This file is the executable checklist.

---

## Phase 1 — Quick wins (no new files, no new Canvas)

### 1.1 `ShuttlX/Theme/Themes/MixtapeTheme.swift` — palette swap

```swift
// ── Body & chrome
background      Color(red: 0.141, green: 0.153, blue: 0.169)  // #24272B bodyBase
surface         Color(red: 0.180, green: 0.196, blue: 0.216)  // #2E3237 body panel
surfaceBorder   Color(red: 0.784, green: 0.804, blue: 0.827).opacity(0.35) // #C8CDD3 chrome
cardBackground  Color(red: 0.180, green: 0.196, blue: 0.216)  // #2E3237

// ── Text
textPrimary     Color(red: 0.937, green: 0.906, blue: 0.824)  // #EFE7D2 labelCream  (12.2:1)
textSecondary   Color(red: 0.557, green: 0.584, blue: 0.616)  // #8E959D chromeDim   (4.95:1)

// ── Data
running/steps/
cycling/elliptical   Color(red: 1.0, green: 0.769, blue: 0.302)  // #FFC44D lcdLit
walking/hiking/
calories/pace        Color(red: 0.784, green: 0.804, blue: 0.827) // #C8CDD3 chrome
heartRate            Color(red: 1.0, green: 0.231, blue: 0.188)   // #FF3B30 ledRed
stationary           Color(red: 0.557, green: 0.584, blue: 0.616) // #8E959D

// ── CTA
ctaPrimary      Color(red: 0.243, green: 0.812, blue: 0.427)  // #3ECF6D ctaPlay
ctaDestructive  Color(red: 1.0,   green: 0.231, blue: 0.188)  // #FF3B30 ledRed
ctaPause        Color(red: 1.0,   green: 0.639, blue: 0.094)  // #FFA318 ledAmber
ctaWarning      Color(red: 1.0,   green: 0.639, blue: 0.094)  // #FFA318 ledAmber
iconOnCTA       Color(red: 0.082, green: 0.090, blue: 0.102)  // #15171A bodyDeep

// ── HR zones (yellow-free ramp — see spec §1.4)
hrZone1  Color(red: 0.498, green: 0.796, blue: 0.643)  // #7FCBA4
hrZone2  Color(red: 0.216, green: 0.769, blue: 0.388)  // #37C463
hrZone3  Color(red: 1.0,   green: 0.541, blue: 0.239)  // #FF8A3D
hrZone4  Color(red: 1.0,   green: 0.353, blue: 0.169)  // #FF5A2B
hrZone5  Color(red: 1.0,   green: 0.176, blue: 0.125)  // #FF2D20

// ── Steps
stepWork      #FFC44D lcdLit
stepRest      #C8CDD3 chrome
stepWarmup    #FFA318 ledAmber
stepCooldown  #3ECF6D ctaPlay

// ── chartStyle
gridColor / axisLabelColor  → #8E959D
accentColor                 → #FFC44D
```

Fonts — two edits only:
```swift
cardTitle:  .system(.headline, design: .monospaced).weight(.semibold)  // was .bold
microLabel: .system(size: 9, design: .monospaced).weight(.heavy)       // was regular
```

### 1.2 `ShuttlX/Theme/ThemeModifiers.swift`

- **Delete** `CassetteHeaderView` and `ReelCounterView` (both struct definitions and the call sites in the `.lcd` branch of `themedCard`). The `ReelCounterView` prints a hard-coded `0000:00` — fake data on every card.
- Rebuild the `.lcd` branch per spec §3.1:

```
fill:        RoundedRectangle(r:10), LinearGradient(#3A3E43 → #24272B, .top → .bottom)
outerStroke: 1pt #15171A
topHighlight:1pt #EDF1F4 @0.14, inset 8 L/R, top edge only
moldLines:   Canvas, 0.5pt horizontal @ white 0.02, pitch 4pt, clipped to shape
brackets:    2 chrome L-marks (topLeading + bottomTrailing), 10pt arms, 1pt, #C8CDD3 @0.35, inset 6
headerWell:  MixtapeWindow(cornerRadius:4, chamfer:4), h=22, fill #EFE7D2, inset 10 L/R, 8 from top
headerStripe:2.5pt #B0392E, flush leading edge of the well, full height
headerText:  .system(size:11, weight:.semibold, design:.monospaced).tracking(0.6),
             .textCase(.uppercase), #23201A, 8pt from stripe
bodyPadding: 16
```
Header well is **optional** — only when `headerLabel != nil`. Cards without a header are just the shell.

Card states (loading / empty / error / pressed) — spec §3.1 table.

### 1.3 `ShuttlX/Theme/Components/ThemedTransportButton.swift`

In `spec(for: "mixtape")`:
```swift
capTop:    Color(red: 0.867, green: 0.886, blue: 0.906)  // #DDE2E7
capBottom: Color(red: 0.659, green: 0.686, blue: 0.722)  // #A8AFB8
channel:   Color(red: 0.082, green: 0.090, blue: 0.102)  // #15171A
glyph:     Color(red: 0.102, green: 0.114, blue: 0.129)  // #1A1D21
```
`.stop` overrides: `capTopOverride = ledRed.opacity(0.85)`, `capBottomOverride = ledRed.opacity(0.65)`, `glyphOverride = labelCream`. (Blue `#4A8ACA` is off-palette now.)
`.play`: keep `proudBoost = 1`, add a 4pt `ctaPlay` legend dot above the glyph in the label.

### 1.4 `ShuttlX/Theme/Themes/MixtapeTimerHero.swift` — typography + colour pass

- Replace the hard-wired local palette constants with the §1 values (`lcdGreen` → `lcdLit #FFC44D`, `borderBlue`/`accentBlue` → `chrome`, `labelPaper` → `labelCream`, `amberPause` → `ledAmber #FFA318`).
- Hero timer: add `.tracking(-1.0)`; reduce glow to `.shadow(color: lcdLit.opacity(0.45), radius: 10)`.
- **Remove `.italic()`** from the workout-name `Text` and from `SIDE A COMPLETE`.
- All 6–9pt legends: add `.tracking(1.4)` and `.textCase(.uppercase)`.
- `sheenOffset` / `animateSheenIfNeeded`: change `.repeatForever` to a single 1.2s pass on resume (see open question 1).
- REC dot: drop the permanent scaled halo overlay, keep a static 1pt ring.

---

## Phase 2 — New components

### 2.1 `ShuttlX/Theme/Components/MixtapeWindow.swift` *(new — build first)*

```swift
struct MixtapeWindow: Shape {
    var cornerRadius: CGFloat = 6   // top corners
    var chamfer: CGFloat = 10       // bottom corners, 45°
    func path(in rect: CGRect) -> Path
}

struct MixtapeWindowFrame<Content: View>: View {
    var cornerRadius: CGFloat = 8
    var chamfer: CGFloat = 14
    var tinted: Bool = true        // smoked amber interior
    @ViewBuilder var content: () -> Content
}
```

Auto-clamp: when `rect.height < 28`, use `chamfer = 4`, `cornerRadius = 3`.

`MixtapeWindowFrame` layers, bottom → top:
1. `MixtapeWindow().fill(lcdSubstrate #14180F)`
2. if `tinted`: `LinearGradient(#3A2A10 @0.55 → #150E05 @0.75, .top → .bottom)`, `.blendMode(.plusLighter)`, opacity 0.5, clipped to the shape
3. inner shadow: 8pt top band `black @0.45 → .clear`, clipped
4. `content()`
5. static diagonal glare `LinearGradient(white @0.06 → .clear)` @ 35°, `.allowsHitTesting(false)`
6. `MixtapeWindow().stroke(chrome, lineWidth: 1.5)` + 0.5pt `chromeHi @0.5` on the top edge

### 2.2 `ShuttlX/Theme/Components/MixtapeTapeCounter.swift` *(new)*

```swift
struct MixtapeTapeCounter: View {
    let value: Int          // 0…999
    var legend: String = "×0.01 KM"
}
```
- Call site: `MixtapeTapeCounter(value: min(999, Int(controller.totalDistance * 100)))`
- Digit: 18×26, `bodyDeep` fill, 1pt inner top shadow, `labelCream` 18pt `.monospaced .bold`
- 1pt `chrome @0.4` dividers; whole group in a 1.5pt `chrome` bezel, r=3
- Roll: `.id(digit)` + `.transition(.offset(y:26).combined(with:.opacity))`, 0.22s `.easeOut`. Reduce Motion → `.opacity` only. **No idle animation**
- Legend: 6pt `.monospaced .heavy .tracking(1.5)`, `chrome @0.6`
- `.accessibilityLabel("Tape counter, \(value)")`, or hide it and let the DIST metric carry the value

### 2.3 `ShuttlX/Theme/Components/MixtapeLEDLamp.swift` *(new)*

```swift
struct MixtapeLEDLamp: View {
    let color: Color?       // nil = unlit
    var diameter: CGFloat = 7
    var bloomTrigger: Int = 0   // increment to fire a one-shot bloom
}
```
- Lit: fill `color`, 1.5pt `bodyDeep` bezel ring, 3pt `white @0.5` specular offset `(-1.5,-1.5)`
- Unlit: no fill, 1pt `chrome @0.15` ring
- Bloom: `.onChange(of: bloomTrigger)` → 0.4s scale 1.0→1.35→1.0 on a `white @0.35` overlay ring. Reduce Motion → skip
- **No continuous pulse.** Timer call site drives `bloomTrigger` from the HR *zone* value, not BPM

### 2.4 `MixtapeTimerHero.swift` — structural

- Wrap `bigLCDPanel` + `decorativeReelsRow` in a single `MixtapeWindowFrame` (the tape door). Delete the current `RoundedRectangle(cornerRadius: 10)` LCD panel background — the frame supplies it.
- Place `MixtapeTapeCounter` to the trailing side of the reel row, vertically centred.
- Add `MixtapeLEDLamp` + `MEGA BASS` legend to the leading edge of the `vuAndPaceStrips` row; colour by zone (Z1–2 `ctaPlay`, Z3–4 `ledAmber`, Z5 `ledRed`, no HR = unlit).
- Keep: J-card strip, VU/pace strips, transport controls, all alerts, all accessibility labels.

### 2.5 `ShuttlX/Theme/Components/ThemedSceneBackground.swift` — `MixtapeCassetteScene` → `MixtapeDeckScene`

Per spec §3.3. Keep `screwView` (use 2, bottom corners only). **Delete** `jCardLabel`, `hubWindowBezelView`, `staticReelThumbnail`, `writeProtectWell`, and `MixtapeLayoutConstants` (no consumers left once the hero owns its own window). Add grip-ridge `Canvas`, chrome shell seam at `y = h*0.62`, foam jack surround, new brand strip.

Rename the modifier body in `ThemeModifiers.swift` accordingly; `mixtapeBackground()` / `timerScreenBackground(themeID:)` keep their names and signatures.

---

## Implementation hand-off

- **Files to create:**
  - `ShuttlX/Theme/Components/MixtapeWindow.swift`
  - `ShuttlX/Theme/Components/MixtapeTapeCounter.swift`
  - `ShuttlX/Theme/Components/MixtapeLEDLamp.swift`
- **Files to modify:**
  - `ShuttlX/Theme/Themes/MixtapeTheme.swift` (palette + 2 font tokens)
  - `ShuttlX/Theme/ThemeModifiers.swift` (`.lcd` card rebuild; delete `CassetteHeaderView`, `ReelCounterView`)
  - `ShuttlX/Theme/Themes/MixtapeTimerHero.swift` (colours, tracking, window frame, counter, lamp, italic removal, sheen)
  - `ShuttlX/Theme/Components/ThemedSceneBackground.swift` (deck scene rewrite)
  - `ShuttlX/Theme/Components/ThemedTransportButton.swift` (4 cap colours + STOP/PLAY overrides)
  - Asset catalog: `MixtapeReel` recolor navy → gunmetal (1x/2x/3x) — Public-Domain source, update the provenance memory note
  - **`ShuttlX.xcodeproj/project.pbxproj`** — the 3 new files need explicit registration (`ShuttlX/` is not a synchronized folder)
- **Reuse existing:** `ShuttlXColor.forHRZone()`, `ShuttlXColor.forStepType()`, `ThemedTransportButtonStyle` press physics (do not duplicate), `MixtapeParkedReel` end-state logic for the celebration screen, `FormattingUtils.*`, existing `screwView`, existing accessibility labels on the hero (all preserved verbatim).
- **Theme variants verified:** the app ships **2** themes. **Clean** is untouched — it remains the calm cardiac-patient accessibility baseline. **Mixtape** is the only theme affected; every change is inside `Mixtape*` files or a `case .lcd` / `case "mixtape"` branch. `MixtapeWindow` is Mixtape-only and must not leak into shared components. (CLAUDE.md still documents 7–8 themes; that's stale — flagged for `docs-keeper`.)
- **Watch performance check:** N/A for iOS, but ⚠️ **B5 mold-line `Canvas` per card** — one `Canvas` per card in a scrolling list is the one perf risk in this spec. Profile a 20-card dashboard scroll before shipping; if it costs frames, substitute a 3-stop `LinearGradient` and drop the texture.
- **Open questions for dev:**
  1. `animateSheenIfNeeded` uses `.repeatForever` — an idle animation the design-system anti-goals prohibit. OK to change to a single pass on resume?
  2. Tape counter maps to distance (`×0.01 KM`). Product prefers distance, purists prefer tape revolutions/time — confirm before building the drums.
  3. HR zone ramp change flows through `ShuttlXColor.forHRZone()` to the recovery/cardiac surfaces. Wants a sign-off from `ux-ui-designer` before merge.
  4. `sportYellow #FFD400` has no assigned owner yet — assign it to the km-split flash or drop it from the palette.
  5. Deleting `MixtapeLayoutConstants` assumes no other consumer — grep before removing.
