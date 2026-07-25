# Mixtape Theme — Walkman Hardware Refresh

**Date:** 2026-07-24
**Author:** product-designer
**Status:** Proposal — awaiting approval before implementation
**Scope:** `MixtapeTheme.swift` (×2), `ThemeModifiers.swift` (×2), `MixtapeTimerHero.swift` (×2), `ThemedSceneBackground.swift`, `ThemedTransportButton.swift`, plus 3 new components per target

---

## 0. The core strategic move

The current Mixtape theme renders **the cassette** (the media): a navy-blue ABS shell with 4 corner screws, hub windows, a J-card, and a `#39FF14` neon-green LCD. It's well built, but it is the wrong object.

A cassette is a passive plastic box. A **Walkman is a machine** — it has a body, a door, a window, transport keys with real travel, a counter, indicator lamps, and chrome. Machines are what make a workout screen feel like an *instrument*, and instruments are what a fitness app wants to feel like mid-effort.

> **Thesis: stop drawing the tape, start drawing the player. The tape is what you see *through the window*.**

Three concrete consequences run through this whole spec:

| Now (cassette) | After (Walkman) |
|---|---|
| Navy `#0E1420` body, blue-steel `#4A6A9A` borders | Gunmetal `#24272B` body, brushed chrome `#C8CDD3` seams |
| `#39FF14` neon green LCD (a 2010s "hacker green", not a 1985 part) | Amber `#FFC44D` LCD on olive-black `#14180F` substrate |
| Signature shape = cassette spool | Signature shape = **cassette window** (spool demoted to a detail *inside* it) |

Neon green `#39FF14` is the single loudest "not authentic" tell in the current theme. No consumer LCD in 1985 emitted that colour. Real ones were **reflective olive-grey** (unlit, no backlight) or, on later EL-backlit units, **amber/green-amber**. Amber also solves a real problem: it is the highest-legibility warm colour at low brightness, and it separates cleanly from the green→red HR zone ramp that lives on the same screen.

---

## 1. Palette

Eight named roles. All values are sRGB hex; contrast ratios computed against their intended background.

### 1.1 Body & chrome (the machine)

| Token | Hex | Role | Notes |
|---|---|---|---|
| `bodyTop` | `#3A3E43` | Body gradient top | Matte ABS, top-lit |
| `bodyBase` | `#24272B` | Body gradient bottom / card fill | **Primary surface.** Gunmetal charcoal — replaces `#0E1420` navy |
| `bodyDeep` | `#15171A` | Recess / channel / seam | Button wells, screen bezel interior, card outer stroke |
| `chrome` | `#C8CDD3` | Brushed aluminium accent | 9.4:1 on `bodyBase`. Seams, corner brackets, counter bezel, etched legends |
| `chromeHi` | `#EDF1F4` | Chrome specular | 1pt top-edge highlight only, never a fill |
| `chromeDim` | `#8E959D` | Secondary / label text on body | **4.95:1 on `bodyBase`** — passes AA for body text. This is `textSecondary` |

### 1.2 Window & display (what you look through)

| Token | Hex | Role | Notes |
|---|---|---|---|
| `windowSmokeTop` | `#3A2A10` @ 0.55 | Smoked amber tint, top | Gradient overlay over window interior |
| `windowSmokeBottom` | `#150E05` @ 0.75 | Smoked amber tint, bottom | Darker at the bottom = tinted plastic reads convex |
| `lcdSubstrate` | `#14180F` | LCD glass / display well | Olive-black, not pure black. Pure black reads OLED, not LCD |
| `lcdLit` | `#FFC44D` | Lit segment (hero timer, counter, values) | **11.7:1 on `lcdSubstrate`** |
| `lcdDim` | `#6E5A22` | Half-lit / secondary LCD text | Sub-labels, unit suffixes |
| `lcdGhost` | `lcdLit` @ 0.06 | Dead-segment ghost layer | The `88:88` behind the live timer. **This is the single most important LCD tell** — keep it |

### 1.3 Data & lamps

| Token | Hex | Role | Notes |
|---|---|---|---|
| `labelCream` | `#EFE7D2` | Tape-label paper | 12.2:1 on `bodyBase`. Also `textPrimary` |
| `labelInk` | `#23201A` | Typewriter ink on cream | 11:1 on `labelCream` |
| `labelRule` | `#B0392E` | Tape-label border stripe | The red/maroon border printed on TDK/Maxell labels |
| `ctaPlay` | `#3ECF6D` | PLAY / primary CTA | Physical transport green; also the Dolby-NR lamp |
| `ledAmber` | `#FFA318` | MegaBass lamp | Slightly hotter than `lcdLit` so lamp ≠ display |
| `ledRed` | `#FF3B30` | REC lamp / destructive | |
| `sportYellow` | `#FFD400` | Sport accent (optional) | 10.5:1 on `bodyBase`. **Use for at most one element per screen** — km-split flash, PR badge. Never as a fill |

### 1.4 HR zone ramp — deliberately yellow-free

The hero timer is amber. If the zone ramp also contains amber/yellow, a mid-treadmill glance can confuse "time" with "effort". So the Mixtape zone ramp skips yellow entirely and runs **green → orange → red**:

| Zone | Hex | Contrast on `lcdSubstrate` |
|---|---|---|
| Z1 | `#7FCBA4` pale green | 11.9:1 |
| Z2 | `#37C463` green | 8.1:1 |
| Z3 | `#FF8A3D` orange | 7.9:1 |
| Z4 | `#FF5A2B` deep orange | 5.9:1 |
| Z5 | `#FF2D20` red | 5.1:1 |

**Colour is never the only zone cue.** Zone number is always redundantly encoded by the **count of lit LED dots** (§4.3) — so the screen is fully readable with deuteranopia, protanopia, or in direct sunlight where hue washes out. This matters for the 55+ cardiac cohort, where colour discrimination decline is common.

### 1.5 What this replaces in `MixtapeTheme.swift`

```
background        #0E1420 → #24272B  (bodyBase)
surface           #1A3060 → #2E3237  (body panel, one step up from base)
surfaceBorder     #4A6A9A → #C8CDD3 @0.35  (chrome seam)
textPrimary       #B3D1ED → #EFE7D2  (labelCream)
textSecondary     #8CADCC → #8E959D  (chromeDim)
running/steps     #39FF14 → #FFC44D  (lcdLit)
ctaPrimary        #4A8ACA → #3ECF6D  (ctaPlay)
ctaPause          #F2A61A → #FFA318  (ledAmber)
hrZone1…5         (see §1.4)
```

---

## 2. Signature shape — decision

### Verdict: **the cassette window**, not the spool.

The spool is demoted from *signature shape* to *detail motif that only ever appears inside a window*.

**Why the spool loses:**

1. **It is a circle.** Progress rings, avatars, HR gauges, and map pins are all circles. A circle-with-spokes cannot claim identity in a UI that is already full of circles.
2. **It fails at small sizes.** Already documented in the codebase: the watch deck redesign of 2026-06-20 cut the twin reels because *"at 14–18pt it read as bicycle wheels, not a cassette."* A signature shape that dies below 20pt cannot be a card header, a chart tick, or a list glyph.
3. **It cannot frame anything.** The design-system rule requires reuse as *chart frame, progress indicator, medal, empty state, loading state*. A spool can be a progress indicator and a medal. It cannot be a chart frame or an empty-state container.
4. **It's the wrong object.** It belongs to the media, and this refresh moves the theme to the machine.

**Why the window wins:**

1. **It's the iconic front face.** If you sketch a Walkman from memory, you draw a rectangle with a tinted window in it. It *is* the product silhouette.
2. **It's a frame.** Frames wrap content. One shape becomes: card header well, timer display bezel, analytics chart frame, empty-state container, summary medal, watch screen bezel.
3. **It survives scaling.** Legible at 12pt as a list glyph, correct at 380pt as a full-screen chart frame.
4. **It contains the spool.** Nothing is lost — the reel still spins, it just spins *behind the window*, which is exactly where a real tape lives.

### Geometry — `MixtapeWindow: Shape`

A rounded rectangle with the two **bottom corners chamfered at 45°** — the tape-door silhouette.

```
        ╭──────────────────────────────╮   ← cornerRadius r (top, default 6)
        │                              │
        │                              │
        │                              │
        ╲                              ╱   ← chamfer c (default 10) at 45°
         ╲────────────────────────────╱
```

```swift
struct MixtapeWindow: Shape {
    var cornerRadius: CGFloat = 6   // top two corners
    var chamfer: CGFloat = 10       // bottom two corners, 45° cut
    func path(in rect: CGRect) -> Path { … }
}
```

Sizing rules:
- `chamfer` scales as `min(rect.height * 0.18, 14)`, floored at 4. Below ~28pt tall, clamp `chamfer = 4` and `cornerRadius = 3` so it stays a recognisable silhouette instead of a blob.
- The stroke is always `chrome` at `1.5` (iOS) / `1.0` (watch). Never a soft/blurred border — hardware edges are crisp.

### Reuse table (one parametric shape, zero per-state illustrations)

| Surface | How the window appears |
|---|---|
| Dashboard card | Optional header well: window shape, 22pt tall, cream fill = tape label |
| iOS timer | Full display bezel around LCD + reels, smoked amber interior |
| Analytics chart | Chart plot area is clipped to the window; axis labels etched on the chrome frame |
| Empty state | Empty window with a dim `— NO TAPE —` legend inside. One Canvas, all empty states |
| Loading | Same window; three chrome dots marching L→R inside. No spinner |
| Summary / celebration | Window with `SIDE A COMPLETE` on cream, PR value in `lcdLit` |
| Watch deck | 2pt inset window stroke = the screen bezel |

**Rejected: the counter.** A 3-digit odometer is a *component*, not a shape — it can't frame content or scale below its digit height. It stays a great component (§3.3), just not the signature.

---

## 3. iOS surfaces

### 3.1 `.themedCard()` — the cassette-shell card

Current `.lcd` case has two problems worth fixing while we're here:
- It appends `ReelCounterView` to every card with a `headerLabel`, printing a **hard-coded fake `0000:00`**. Fake data in a fitness app is a credibility leak.
- Flat `#1A3060` fill + 1pt border reads generic-dark-card. Nothing about it says hardware.

**Proposed anatomy** (top → bottom, all measurements exact):

```
┌────────────────────────────────────────────────┐  ← r=10, stroke bodyDeep 1pt
│ ┌─╮                                        ╭─┐ │  ← chrome L-brackets, 10pt arms,
│ │ │  ╭──────────────────────────────────╮  │ │ │    1pt, chrome @0.35
│ │ │  │▌ THIS WEEK                       │  │ │ │  ← window header well, h=22, cream
│ │ │  ╰──────────────────────────────────╯  │ │ │    ▌ = labelRule stripe, 2.5pt
│ └─╯                                        ╰─┘ │
│                                                │
│        (content — 16pt padding all round)      │
│                                                │
│ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │  ← mold lines, white @0.02, every 4pt
└────────────────────────────────────────────────┘
```

| Layer | Spec |
|---|---|
| Fill | `RoundedRectangle(cornerRadius: 10)`, `LinearGradient(bodyTop → bodyBase, .top → .bottom)` |
| Outer stroke | 1pt `bodyDeep` — the mold seam. Dark, not light: real plastic parts have a dark parting line |
| Top highlight | 1pt inset line, `chromeHi @ 0.14`, horizontal, inset 8pt L/R. Only on the **top** edge |
| Mold texture | One `Canvas`, horizontal 0.5pt lines at `white @ 0.02` every 4pt, clipped to the card shape. Draw once, no animation |
| Corner brackets | 2 L-shaped chrome marks (top-leading, bottom-trailing only — 4 corners is noise on a list). 10pt arms, 1pt, `chrome @ 0.35`, inset 6pt |
| Header well (optional) | `MixtapeWindow(cornerRadius: 4, chamfer: 4)`, height 22, fill `labelCream`, inset 10pt L/R, 8pt from top |
| Header stripe | 2.5pt wide `labelRule` bar flush to the well's leading edge, full height |
| Header text | `.system(size: 11, weight: .semibold, design: .monospaced)`, `.tracking(0.6)`, uppercase, `labelInk`, 8pt from stripe |
| Body padding | 16pt (unchanged) |

**Remove:** `CassetteHeaderView` and `ReelCounterView` from the `.lcd` card path. `IEC TYPE II` / `◀◀ REW` / `FF ▶▶` chrome on *every card in the app* violates "chrome never competes with data". That vocabulary belongs on the timer screen only.

**Card states:**

| State | Treatment |
|---|---|
| **Idle** | As above |
| **Pressed** (tappable cards) | Whole card offsets `y: +1`, top highlight opacity → 0, shadow radius 4→1. 80ms ease. Matches the transport-key physics already in `ThemedTransportButtonStyle` |
| **Loading** | Header well shows 3 chrome dots (4pt, 6pt apart) marching L→R, 0.9s loop, `chrome @0.35 → @0.9`. Body shows 2 skeleton bars: `bodyDeep`, height 14, r=3, widths 60% / 40%. **No `ProgressView`** |
| **Empty** | Header well text becomes `— NO TAPE —` at `labelInk @0.45`. Body: `MixtapeWindow` outline, 1pt `chrome @0.25`, 64pt tall, with a static 3-spoke spool glyph centred at 28pt, `chrome @0.18`. One line of guidance in `chromeDim`, plus the CTA |
| **Error** | Left stripe `labelRule → ledRed`, header text prefixed `ERR ·`, body message in `chromeDim`, retry as a small transport-style key labelled `RETRY` |

### 3.2 iOS workout timer — the tape door

Keep the existing 5-band vertical composition (it works and it's tuned). Change the *material*.

```
┌──────────────────────────────────────────────────────┐
│ ╭──────────────────────────────────────────────────╮ │ ← cream J-card, h=44
│ │▌ SIDE A  ●REC  INTERVAL 8×400              2.47km│ │   ▌ labelRule 3pt
│ ╰──────────────────────────────────────────────────╯ │
│                                                      │
│  ╭────────────────────────────────────────────────╮  │ ← MixtapeWindow, the TAPE DOOR
│  │▒▒▒▒▒▒▒▒ smoked amber, inner shadow ▒▒▒▒▒▒▒▒▒▒▒▒│  │   chrome 1.5pt stroke
│  │                                                │  │
│  │              88:88   ← lcdGhost @0.06          │  │
│  │              01:48   ← lcdLit, 56pt mono bold  │  │
│  │                                                │  │
│  │   STEP 3/8      ▪ RUN                          │  │ ← lcdDim 9pt / step colour
│  │                                                │  │
│  │      ◉               ┌───┬───┬───┐             │  │ ← spool 84pt (spins)
│  │     ╱ ╲              │ 2 │ 4 │ 7 │  ×0.01 KM   │  │ ← ODOMETER, cream digits
│  │      ◉               └───┴───┴───┘             │  │   on bodyDeep drums,
│  │                                                │  │   chrome bezel
│  ╲────────────────────────────────────────────────╱  │ ← 45° chamfer
│                                                      │
│  ● MEGA BASS    HR ▮▮▮▮▮▮▯▯▯▯    142 bpm   [Z3]     │ ← lamp + VU + zone colour
│  SPD  ├────────────▲─────────┤    5'24 /km          │
│                                                      │
│  ┌────┐  ┌────┐  ┌──────────────────┐  ┌────┐       │ ← chrome keycaps,
│  │ ◀◀ │  │ ▶▶ │  │  ▶  PLAY         │  │ ■  │       │   3pt travel, PLAY latches
│  │CNCL│  │SKIP│  └──────────────────┘  │STOP│       │
│  └────┘  └────┘                        └────┘       │
└──────────────────────────────────────────────────────┘
```

**3.2.1 Tape-door window frame** *(new — `MixtapeWindowFrame`)*
- Shape: `MixtapeWindow(cornerRadius: 8, chamfer: 14)`
- Interior fill: `lcdSubstrate`
- Smoked-amber tint: `LinearGradient(windowSmokeTop → windowSmokeBottom, .top → .bottom)` over the substrate, `.blendMode(.plusLighter)` at 0.5 opacity
- Inner shadow: top 8pt band, `black @0.45 → .clear`, clipped to the shape. This is what makes it read as *recessed glass* rather than a painted panel
- Stroke: 1.5pt `chrome`, plus a 0.5pt `chromeHi @0.5` line on the top edge only
- Glass glare: one static diagonal `LinearGradient(white @0.06 → .clear)` at 35°, `.allowsHitTesting(false)`. **Static** — no travelling sheen (the current 6s repeating sheen on the VU panel is an idle animation; see §7 open questions)

**3.2.2 Hero timer**
- 56pt `.monospaced` `.bold`, `.monospacedDigit()`, `.tracking(-1.0)` (LCD segments sit tight)
- Colour: `lcdLit`; when paused → `ledAmber`; when complete → `ctaPlay`
- Ghost layer `88:88` in `lcdGhost` behind — keep exactly as built, it's the best detail in the current file
- Glow: `.shadow(color: lcdLit.opacity(0.45), radius: 10)` — an EL backlight bleeds; a real segment does not glow hard. Reduce from the current 0.55/8

**3.2.3 Mechanical tape counter** *(new — `MixtapeTapeCounter`)*

Three digit drums in a recessed chrome bezel. This replaces the fake `0000:00`.

- **Value:** `min(999, Int(totalDistance * 100))` — hundredths of a kilometre. `247` = 2.47 km. Etched `×0.01 KM` legend beneath in 6pt `chrome @0.6`, `.tracking(1.5)`. Decorative *and* true.
- Each digit: 18×26pt, fill `bodyDeep`, 1pt inner top shadow, digit in `labelCream` 18pt `.monospaced` `.bold`
- Separated by 1pt `chrome @0.4` dividers; whole group wrapped in a 1.5pt `chrome` bezel, r=3
- **Roll animation:** only on value change. `.transition(.offset(y: 26).combined(with: .opacity))`, 0.22s `.easeOut`, using `.id(digit)`. No idle motion. Reduce Motion → cross-fade only
- Placement: right of the spool, vertically centred in the window

**3.2.4 SIDE A label strip**
- Keep the current cream J-card, restyle: `labelCream` fill, 3pt `labelRule` stripe flush left, drop the `.italic()` (a synthetic oblique on a monospaced face looks like a rendering bug, not a typewriter)
- `SIDE A` box → `SIDE B` on completion (already correct)
- REC dot: `ledRed`, 7pt. **Remove the pulsing halo** — see §7

**3.2.5 MegaBass lamp** *(new — `MixtapeLEDLamp`)*
- 7pt circle + 1.5pt `bodyDeep` bezel ring + a 3pt `white @0.5` specular dot offset `(-1.5, -1.5)`
- Colour by HR zone: Z1–2 → `ctaPlay`; Z3–4 → `ledAmber`; Z5 → `ledRed`; no HR → unlit (`chrome @0.15` ring, no fill)
- Legend `MEGA BASS`, 6pt `.monospaced` `.heavy`, `.tracking(1.4)`, `chrome @0.55`, trailing the lamp
- **Motion:** the brief asks for a pulse. I'm recommending against a continuous pulse and instead: a **one-shot 0.4s bloom** (scale 1.0→1.35→1.0 on a `white @0.35` overlay ring) *only at the instant of a zone change*. Rationale: a continuously pulsing red lamp beside a heart-rate number is an anxiety cue for a post-cardiac-event user, and continuous animation violates the theme's own anti-goals. Reduce Motion → opacity step only, no bloom

**3.2.6 Transport keys** — modify `ThemedTransportButtonStyle.spec(for: "mixtape")`:
```
capTop     #C7CCD4 → #DDE2E7   (chrome, brighter)
capBottom  #9AA1AC → #A8AFB8
channel    #0E1420 → #15171A   (bodyDeep)
glyph      #2A3038 → #1A1D21
```
Plus: PLAY gets a 4pt `ctaPlay` legend dot above its glyph; STOP's override changes from `accentBlue` to `ledRed @0.85` cap with `labelCream` glyph (blue is now off-palette).

**Timer states:**

| State | Treatment |
|---|---|
| **Running** | As drawn. PLAY key latched down, spool spinning, counter live |
| **Paused** | Timer + phase → `ledAmber`. PLAY key unlatches (pops up), spool halts (no decay spin), `PAUSED` chip on the cream strip in `labelInk` on `ledAmber`, REC dot dims to 0.3. Window tint unchanged — the machine is still on |
| **Loading / starting** | Window shows `--:--` in `lcdDim` with the ghost layer at full 0.06. Counter reads `000`. Cream strip shows `CUEING…`. All transport keys disabled except CANCEL |
| **No HR** | BPM shows `—` in `chromeDim`, VU bar all unlit, MegaBass lamp unlit ring. One line under the VU: `NO SIGNAL — CHECK WRIST` in 8pt `ledAmber` |
| **Error** (workout failed to start) | Window interior desaturates (tint opacity 0.5→0.2), `ERR` in `ledRed` where the timer was, message on the cream strip, single `RETRY` transport key |
| **Complete / celebration** | Cream strip → `SIDE B` + `SIDE A COMPLETE` in `ctaPlay`. Timer shows total duration in `ctaPlay`. Spool parks (supply thin, take-up fat — reuse `MixtapeParkedReel` logic). Counter freezes on final distance. Below: `▶▶ FLIP TO SIDE B?` in `chrome @0.7` as the "start another" affordance. **No confetti** — a machine doesn't throw confetti; the reward is the tape being fully wound |

### 3.3 Background scene — `MixtapeCassetteScene` → `MixtapeDeckScene`

The current scene draws a *cassette*: 4 corner screws, write-protect wells, hub bezels, `IEC TYPE II` brand strip. That is now the wrong object for a full-screen background.

Rebuild as the **player body**:
- Vertical gradient `bodyTop → bodyBase`, r=16
- **Grip texture:** two bands of horizontal rubber-feel ridges (1pt lines, 3pt pitch, `black @0.10` + `white @0.03` alternating) along the left and right 18pt edges. One `Canvas`
- **Chrome seam:** one full-width 1pt `chrome @0.4` horizontal line at `y = h * 0.62`, with a `black @0.3` line 1pt below it — the two-part shell join
- **2 screws only** (bottom-left, bottom-right, 10pt) — reuse the existing `screwView`; four corner screws is cassette anatomy, not player anatomy
- **Foam jack surround:** 14pt circle at top-trailing, `bodyDeep` fill, 2pt `chrome @0.3` ring, tiny `PHONES` legend at 6pt `chrome @0.45`
- Bottom legend strip: `AUTO REVERSE · MEGA BASS · DOLBY B NR` in 7pt `chrome @0.4`, `.tracking(1.5)` — replaces `IEC TYPE II · HIGH BIAS · C-90`
- **Drop** the J-card, hub bezels, and static reel thumbnails from the background entirely. Those live inside the timer's window now

---

## 4. watchOS — `MixtapeWatchDeck`

Hard constraints: ~180pt height budget on 41mm, max 5 visible elements, **no idle animation**, static `Shape`/`Canvas` only, OLED-friendly.

```
 ╭────────────────────────────────────╮ ← bezel: MixtapeWindow stroke,
 │ ▐SIDE A▌ ▸ RUN                 ◉   │   1pt chrome@0.45, inset 2
 │                                    │ ← 1: cream capsule + phase + static spool 14pt
 │  88:88                             │ ← ghost
 │  1:48                              │ ← 2: HERO, lcdLit, screenH*0.20
 │                                    │
 │  ● ● ● ○ ○      142 BPM            │ ← 3: 5 LED dots (zone) + zone-tinted BPM
 │                                    │
 │  DIST 2.47      PACE 5'24          │ ← 4: two-up, lcdLit values, chromeDim labels
 ╰────────────────────────────────────╯
```

### 4.1 Bezel *(replaces the flat `lcdWell` full-bleed)*
- Background stays `lcdSubstrate` `#14180F` full-bleed, `.ignoresSafeArea()` — near-black keeps OLED pixels off and AOD cheap
- Over it: `MixtapeWindow(cornerRadius: 10, chamfer: 8)` **stroked only**, 1pt `chrome @0.45`, inset 2pt from the screen edge, plus an 8pt top inner-shadow band (`black @0.5 → .clear`) clipped to the shape
- Total cost: one stroked `Shape` + one clipped gradient. No `Canvas`, no fill, no per-frame work
- Result: the whole watch face reads as *looking through the tape door* — the strongest possible identity per point of vertical budget

### 4.2 Row 1 — now-playing strip *(≈20pt)*
- `SIDE A` capsule: `labelCream` fill (was `lcdAmber` — cream is the paper label, and it stops competing with the amber timer), `labelInk` text, 9pt `.heavy` `.monospaced`, 5×2 padding
- `▸` glyph in `ctaPlay` (running) / `ledAmber` (paused), `pause.fill` when paused
- Phase in **typewriter caps**: `RUN` / `WALK` / `WARM UP` / `COOL DOWN` / `ELAPSED` — 10pt `.heavy` `.monospaced`, `.tracking(0.8)`, step colour
- **Trailing: static spool glyph, 14pt.** Canvas-drawn, **3 spokes not 6** (6 spokes alias into grey mush below 20pt), 1.5pt strokes, `chrome @0.5`, plus a 3pt filled hub. Never rotates on the watch
  - *Risk noted:* the 2026-06-20 redesign cut reels at 14–18pt for exactly this reason. The difference now is that it sits **inside a visible window bezel**, which supplies the "this is a tape door" context the bare reels lacked. If it still reads as a wheel on device, delete it — the bezel + cream capsule carry the identity alone

### 4.3 Row 3 — HR: **5 LED dots replace the 12-segment VU** *(≈28pt)*

The current 12-segment bar is the weakest element on the watch. At 41mm each segment is ~10pt wide; twelve of them read as a textured smear, and the segment count carries no meaning the user can name.

Replace with a **5-lamp zone ladder** — which is *also* more authentic (Walkman battery/level indicators were 3–5 discrete lamps, not 12):

- 5 dots, 8pt diameter, 6pt apart, leading-aligned
- Lit dots = current zone number. Lit fill = that zone's ramp colour (§1.4). Unlit = 1pt `chrome @0.22` ring, no fill
- BPM number: `screenH * 0.16`, `.bold` `.monospaced`, zone colour, `.monospacedDigit()`
- `BPM` unit: `screenH * 0.052`, `chromeDim`
- **Zone is now readable three ways:** dot count, dot colour, number colour. Colour-blind and sunlight safe
- Transition: 0.3s `.easeOut` on the lit count, event-driven off HR ticks only. Keep the existing upward-crossing `.directionUp` haptic

### 4.4 Rows 2 & 4
- **Hero:** unchanged geometry (`screenH * 0.20`, leading-aligned, `minimumScaleFactor(0.5)`), recoloured to `lcdLit`, ghost `88:88` layer added behind at `lcdGhost` (currently watch-only omission — the iOS hero has it, the watch doesn't). `.tracking(-0.5)`
- **Metrics:** move `DIST` and `PACE` from two separate full-width lines to **one two-up row** — reclaims ~20pt for the bezel and matches the `compactMetric` guidance in `.claude/rules/watchos.md`. Labels `chromeDim` at `screenH*0.052`, values `lcdLit` at `screenH*0.10`, `.monospacedDigit()`, `minimumScaleFactor(0.4)`. Drop the `km` / `/km` suffixes — the labels carry the units (this precedent already exists in `paceText`)

**Height budget, 41mm (`screenH ≈ 176`):**

| Element | Height |
|---|---|
| Row 1 now-playing | 20 |
| Row 2 hero | 62 |
| Row 3 HR | 28 |
| Row 4 metrics | 22 |
| 3 × spacing @ `screenH*0.008` | 4 |
| top/bottom padding | 14 |
| **Total** | **150** ✅ (budget 180) |

30pt of slack absorbs the `noHeartRateDetected` banner and Dynamic Type growth.

**Watch states:**

| State | Treatment |
|---|---|
| **Running** | As drawn |
| **Paused** | Hero + phase → `ledAmber`, `▸` → `pause.fill`, LED dots freeze at last zone and all recolour to `ledAmber @0.6`. Bezel unchanged |
| **Loading / starting** | Hero `--:--` in `lcdDim` with ghost at full opacity, phase reads `CUEING`, dots all unlit |
| **No HR** | BPM `—` in `chromeDim`, all 5 dots unlit rings. Existing `noHeartRateDetected` banner styled: `ledAmber` text, 1pt `ledAmber` window-shaped border |
| **Empty** (no template / pre-start) | Bezel + centred `— NO TAPE —` in `chrome @0.4`, 12pt, plus the start CTA below |
| **Error** | `ERR` in `ledRed` at hero position, one-line cause in `chromeDim`, retry button |
| **AOD (reduced luminance)** | Bezel hidden entirely; hero at `lcdLit @0.4`; BPM at zone colour @0.4; dots as outlines only; background pure `#000000`. No cream capsule (bright large area = burn-in + battery) |
| **Complete** | `SIDE B` cream capsule, `SIDE A COMPLETE` in `ctaPlay`, total duration as hero, `MixtapeParkedReel` static pair centred at 40pt |

---

## 5. Typography

No custom fonts. Everything is system, differentiated by **design, weight, and tracking**.

| Role | Font | Tracking | Case | Where |
|---|---|---|---|---|
| **LCD numeric** | `.system(size:, weight: .bold, design: .monospaced)` + `.monospacedDigit()` | `-1.0` @56pt, `-0.5` @28–40pt, `0` below | — | Hero timer, BPM, DIST/PACE values, counter digits |
| **LCD sub-label** | `.system(size: 9, weight: .heavy, design: .monospaced)` | `+1.0` | UPPER | `STEP 3/8`, `ELAPSED`, `REMAINING` |
| **Etched chrome legend** | `.system(size: 6–8, weight: .heavy, design: .monospaced)` | `+1.4` | UPPER | `MEGA BASS`, `×0.01 KM`, `PHONES`, bottom brand strip |
| **Typewriter label** | `.system(size: 11–13, weight: .semibold, design: .monospaced)` | `+0.6` | UPPER | Workout name on the cream J-card, card header |
| **Molded button legend** | `.system(size: 7–9, weight: .heavy, design: .rounded)` | `+0.3` | UPPER | `PLAY`, `STOP`, `SKIP`, `CANCEL` |
| **Body / secondary** | `.system(size: 11–13, design: .monospaced)` | `0` | Sentence | Card body copy, guidance lines |

**Rules:**
1. **`.rounded` is for legends only.** Molded plastic key legends have soft terminals; data never does. One-way rule — no data in `.rounded`, ever.
2. **Tracking is the whole trick.** `+1.4` monospaced small caps is what makes text read as *silkscreened onto a machine* rather than *typed into a text field*. It's a one-line change with more identity payoff than any drawing.
3. **Negative tracking on big numerics.** Real 7-segment/LCD digits are packed tight. `.monospaced` at 56pt is airy by default; `-1.0` closes it.
4. **Kill `.italic()`.** Synthetic oblique on a monospaced face renders as skewed bitmaps. The current iOS hero uses it on the workout name and `SIDE A COMPLETE`. Remove both.
5. **Dynamic Type:** chrome legends and the brand strip are *hardware etching* — fixed size, exempt (they're decorative and `accessibilityHidden`). Every **data** element scales; the watch already derives from `screenH`, iOS uses `minimumScaleFactor` floors of 0.55 (hero) / 0.6 (metrics). Test at `.accessibility1`; the two-up watch row is the first thing to break.

Theme-token mapping in `MixtapeTheme.swift` — mostly unchanged (already all `.monospaced`), two edits:
```
cardTitle:   .system(.headline, design: .monospaced).weight(.bold)   → .weight(.semibold)  // typewriter, not bold
microLabel:  .system(size: 9, design: .monospaced)                   → .weight(.heavy)     // etched legend
```

---

## 6. Quick wins vs bigger lifts

### Quick wins — small diffs, disproportionate impact

| # | Change | Files | Impact |
|---|---|---|---|
| Q1 | **Recolor the palette**: navy → gunmetal, green → amber, blue-steel → chrome (§1.5) | `MixtapeTheme.swift` ×2 | ★★★★★ — single biggest authenticity gain in the whole spec |
| Q2 | **Delete `ReelCounterView` + `CassetteHeaderView`** from the `.lcd` card path | `ThemeModifiers.swift` ×2 | ★★★★ — removes fake `0000:00` data and per-card chrome noise |
| Q3 | **Tracking pass**: `+1.4` on all chrome legends, `-1.0` on the 56pt hero | Both hero files | ★★★★ — pure typography, zero new drawing |
| Q4 | **Remove `.italic()`** from the J-card strip | `MixtapeTimerHero.swift` (iOS) | ★★★ — fixes a visible rendering artifact |
| Q5 | **Chrome keycaps**: 4 colour constants in the transport spec | `ThemedTransportButton.swift` | ★★★ — keys go from grey plastic to brushed metal |
| Q6 | **Watch: 12-segment VU → 5 LED dots** | `MixtapeTimerHero.swift` (watch) | ★★★★ — legibility + colour-blind safety + authenticity in one swap |
| Q7 | **Watch: two-up DIST/PACE**, drop unit suffixes | `MixtapeTimerHero.swift` (watch) | ★★★ — frees ~20pt for the bezel |
| Q8 | **Cream label strip + `labelRule` stripe** as the card header | `ThemeModifiers.swift` ×2 | ★★★★ — the tape-label tell, ~20 lines |
| Q9 | **Ghost `88:88` layer on the watch hero** (iOS already has it) | `MixtapeTimerHero.swift` (watch) | ★★★ — the LCD tell, 6 lines |

Q1–Q9 together deliver most of the visual shift with **no new files and no new Canvas drawing**. Recommended as phase 1.

### Bigger lifts — new drawing, needs its own review pass

| # | Change | New files | Notes |
|---|---|---|---|
| B1 | **`MixtapeWindow` Shape + `MixtapeWindowFrame`** | `Theme/Components/MixtapeWindow.swift` ×2 | The signature shape. Everything else depends on it — do this first |
| B2 | **`MixtapeTapeCounter`** odometer | `Theme/Components/MixtapeTapeCounter.swift` (iOS) | 3 digit drums + roll transition |
| B3 | **`MixtapeLEDLamp`** (MegaBass) | `Theme/Components/MixtapeLEDLamp.swift` (iOS) | Reusable for REC/Dolby lamps later |
| B4 | **`MixtapeCassetteScene` → `MixtapeDeckScene`** | rewrite `ThemedSceneBackground.swift` | Cassette anatomy → player anatomy. Largest single diff |
| B5 | **Mold-line Canvas texture** in cards | `ThemeModifiers.swift` | ⚠️ Measure: one `Canvas` per card × a scrolling list. Profile before shipping; drop to a 2-stop gradient if it costs frames |
| B6 | **Window-framed analytics charts** | `ThemeChartStyle` consumers | Deferred — separate proposal, but B1 is the prerequisite |
| B7 | **`MixtapeReel` asset recolor** navy → gunmetal | asset catalog (1x/2x/3x) | Source is Public Domain (Paul Sherman); recolor is fine, **update the provenance memory note** |

**Suggested sequencing:** Q1–Q9 → B1 → B2/B3 → B4 → (B5 gated on profiling) → B6 separately.

---

## 7. Open questions & existing-code notes

Per file-ownership rules I don't touch Swift. Flagging for `senior-ios-developer` / `swiftui-watchos-specialist` to decide:

1. **Idle animations already shipping.** `MixtapeTimerHero.swift` (iOS) runs a `.repeatForever` 6-second sheen band on the VU panel (`animateSheenIfNeeded`), and the REC dot draws a permanent halo ring. Both are idle animations, which the design-system anti-goals prohibit. Recommend: sheen fires **once** on resume then stops; REC halo becomes a static ring. Dev call.
2. **`ReelCounterView` prints hard-coded `0000:00`** on every card with a `headerLabel`. Fake data. §3.1 removes it; if the component is kept anywhere it must be wired to real values.
3. **Watch background conflict.** `MixtapeWatchDeck` sets `.background(lcdWell.ignoresSafeArea())` while `.themedScreenBackground()` also draws `mixtapeBackground()` underneath. One is dead paint. Confirm which wins before adding the bezel.
4. **HR zone ramp is a theme-token change** (`hrZone1…5` in `MixtapeTheme.swift` ×2). It flows through `ShuttlXColor.forHRZone()` to *every* Mixtape surface including the recovery/cardiac screens. Requires a deliberate re-check by `ux-ui-designer` / `healthkit-domain-expert` — I've kept the green→red direction and only removed the yellow band, but cardiac-rehab surfaces deserve the explicit sign-off.
5. **Tape counter semantics.** I mapped it to distance (`×0.01 KM`). Alternative: elapsed minutes, or true tape-position (interval index). Product call — distance is the most useful glanceable number, but a real counter tracked tape revolutions, so purists may prefer time.
6. **Sport yellow** `#FFD400` is specced but unassigned. Candidate homes: km-split flash (currently `ShuttlXColor.running`), PR badges, the "new best" celebration. Needs one owner or it should be dropped from the palette.
7. **CLAUDE.md drift.** Docs describe 7–8 themes; the code ships 2 (Clean + Mixtape). This spec assumes 2. `docs-keeper` should reconcile.
8. **The watch spool glyph (§4.2)** is the one element I'd cut first if it doesn't survive an on-device look at 41mm. Ship it behind a quick visual check, not a debate.

---

## 8. Hand-off

Platform-specific hand-off blocks with exact file lists live in:
- **`design/proposals/mixtape-refresh/ios.md`** → `senior-ios-developer`
- **`design/proposals/mixtape-refresh/watch.md`** → `swiftui-watchos-specialist`
