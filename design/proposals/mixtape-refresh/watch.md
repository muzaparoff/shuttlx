# Mixtape Walkman Refresh — watchOS hand-off

**Read `spec.md` §1, §4 first.** This file is the executable checklist for `ShuttlX Watch App/**`.

Guiding constraints for every change below: **~180pt height budget on 41mm, max 5 visible elements, no idle animation, static `Shape`/`Canvas` only, OLED-friendly.**

---

## Target layout (41mm, `screenH ≈ 176`)

```
 ╭────────────────────────────────────╮ ← bezel: MixtapeWindow stroke only,
 │ ▐SIDE A▌ ▸ RUN                 ◉   │   1pt chrome@0.45, inset 2pt
 │                                    │   row 1 · 20pt
 │  88:88                             │ ← ghost layer @0.06
 │  1:48                              │   row 2 · 62pt  lcdLit #FFC44D
 │                                    │
 │  ● ● ● ○ ○      142 BPM            │   row 3 · 28pt  5 zone LEDs
 │                                    │
 │  DIST 2.47      PACE 5'24          │   row 4 · 22pt  two-up
 ╰────────────────────────────────────╯
```

| Element | pt |
|---|---|
| row 1 now-playing | 20 |
| row 2 hero | 62 |
| row 3 HR | 28 |
| row 4 metrics | 22 |
| 3 × spacing (`screenH*0.008`) | 4 |
| top/bottom padding | 14 |
| **total** | **150** ✅ (30pt slack for the no-HR banner + Dynamic Type) |

---

## 1. `ShuttlX Watch App/Theme/Themes/MixtapeTheme.swift`

Apply the **identical** palette as iOS — see `ios.md` §1.1 for the full literal list. Theme files are mirrored; any divergence is a bug. Watch font sizes stay as they are.

Key values for quick reference:
```
bodyBase #24272B · bodyDeep #15171A · chrome #C8CDD3 · chromeDim #8E959D
labelCream #EFE7D2 · labelInk #23201A · labelRule #B0392E
lcdSubstrate #14180F · lcdLit #FFC44D · lcdDim #6E5A22 · lcdGhost = lcdLit@0.06
ctaPlay #3ECF6D · ledAmber #FFA318 · ledRed #FF3B30
hrZone1…5: #7FCBA4 #37C463 #FF8A3D #FF5A2B #FF2D20   (yellow-free — spec §1.4)
```

---

## 2. `ShuttlX Watch App/Theme/Components/MixtapeWindow.swift` *(new)*

Mirror of the iOS `MixtapeWindow: Shape` (same geometry, same clamp rule). The watch needs **only the `Shape`**, not `MixtapeWindowFrame` — the watch bezel is a stroke, never a fill.

```swift
struct MixtapeWindow: Shape {
    var cornerRadius: CGFloat = 6
    var chamfer: CGFloat = 10   // 45° bottom corners
    func path(in rect: CGRect) -> Path
}
```
Clamp: `rect.height < 28` → `chamfer = 4`, `cornerRadius = 3`.

---

## 3. `ShuttlX Watch App/Theme/Themes/Decorations/MixtapeTimerHero.swift`

### 3.1 `MixtapeWatchDeck` — bezel

Replace `.background(lcdWell.ignoresSafeArea())` with:
```
background: Color(#14180F).ignoresSafeArea()        // lcdSubstrate, near-black — OLED + AOD friendly
overlay:    MixtapeWindow(cornerRadius: 10, chamfer: 8)
              .stroke(chrome.opacity(0.45), lineWidth: 1)
              .padding(2)
              .allowsHitTesting(false)
            + 8pt top inner-shadow band (black @0.5 → .clear) clipped to the same shape
```
Cost: one stroked `Shape` + one clipped gradient. No `Canvas`, no fill, no per-frame work. Hidden entirely in AOD.

⚠️ **Check first:** `.themedScreenBackground()` also paints `mixtapeBackground()` underneath this view. One of the two is dead paint — resolve before adding the bezel (open question 1).

### 3.2 Row 1 — now-playing strip (~20pt)

- `SIDE A` capsule: fill **`labelCream`** (was `lcdAmber` — cream is the paper label and stops it competing with the amber hero), text `labelInk`, `tagSize` `.heavy .monospaced`, padding 5×2
- `▸` / `pause.fill`: `ctaPlay` running, `ledAmber` paused
- Phase text: `subLabel` `.heavy .monospaced`, **add `.tracking(0.8)`**, step colour. Keep the Mixtape-only `RUN`/`WALK`/`WARM UP`/`COOL DOWN`/`ELAPSED` wording — do **not** touch shared `IntervalType.displayName`
- **Trailing: static spool glyph, 14pt** — `Canvas`, **3 spokes** (not 6; six aliases to grey mush under 20pt), 1.5pt strokes `chrome @0.5`, 3pt filled hub, outer 1pt ring. **Never rotates.** `.accessibilityHidden(true)`
  - Risk: the 2026-06-20 redesign cut reels at 14–18pt as "bicycle wheels". The bezel now supplies the tape-door context they lacked. **If it still reads as a wheel on device, delete it** — bezel + cream capsule carry the identity alone. Don't debate it, just look.

### 3.3 Row 2 — hero timer (~62pt)

Geometry unchanged (`heroSize = screenH * 0.20`, leading-aligned, `minimumScaleFactor(0.5)`). Changes:
- Colour `lcdLit #FFC44D`; paused → `ledAmber`; complete → `ctaPlay`
- **Add the ghost `88:88` layer** behind, `lcdGhost` (`lcdLit @0.06`), same font/size, `.accessibilityHidden(true)`. iOS already has this; the watch omits it. It's the single best LCD tell and costs 6 lines
- Add `.tracking(-0.5)`
- Glow: `.shadow(color: lcdLit.opacity(0.45), radius: heroSize * 0.05)` (currently uses `lcdAmber` at 0.55 — align the token and lower it)

### 3.4 Row 3 — **replace `MixtapeVUMeter` with a 5-lamp zone ladder** (~28pt)

Delete the private `MixtapeVUMeter` struct. Add:

```swift
private struct MixtapeZoneLadder: View {
    let zone: Int        // 0 = no data, 1…5
    let paused: Bool
    var dot: CGFloat = 8
}
```
- 5 dots, `dot` = 8pt, 6pt apart, leading-aligned
- Lit (`i < zone`): fill = that zone's ramp colour. Unlit: 1pt `chrome @0.22` ring, no fill
- Paused: lit dots freeze at last zone, all recolour `ledAmber @0.6`
- Transition: `.animation(.easeOut(duration: 0.3), value: zone)` — event-driven off HR ticks only, nil under Reduce Motion
- `.accessibilityHidden(true)` (the row's combined label carries the zone)

Row composition: ladder (leading) · `Spacer` · BPM number (`hrSize`, zone colour, `.monospacedDigit()`) · `BPM` (`labelSize`, `chromeDim`).

**Why:** 12 segments at 41mm are ~10pt each and read as a smear; the count means nothing nameable. 5 dots = the zone number, readable without hue (colour-blind + direct sunlight), and 3–5 discrete lamps is what the hardware actually had.

Keep the existing `handleZoneHaptic` upward-crossing `.directionUp` logic verbatim. `vuLevel(bpm:)` becomes unused — delete it, drive the ladder from `hrCalc.zone(for:)` directly.

### 3.5 Row 4 — metrics, two-up (~22pt)

Collapse the two `metricLine` calls into **one** `HStack` two-up (frees ~20pt for the bezel; matches the `compactMetric` guidance in `.claude/rules/watchos.md`):
```
HStack(spacing: 8) {
    compact("DIST", FormattingUtils.formatDistance(...))   // no " km" suffix
    compact("PACE", pace ?? "—")                           // no "/km" suffix
}
```
- Labels `chromeDim` at `labelSize` (`screenH*0.052`)
- Values `lcdLit` at `metricSize` (`screenH*0.10`), `.monospacedDigit()`, `minimumScaleFactor(0.4)`
- Units live in the labels — precedent already set by `TrainingView+Metrics.paceText`
- Accessibility strings keep the full units (`"Distance 2.47 kilometres"`) — unchanged

---

## 4. States

| State | Treatment |
|---|---|
| **Running** | As drawn |
| **Paused** | Hero + phase → `ledAmber`; `▸` → `pause.fill`; ladder freezes, all lit dots → `ledAmber @0.6`. Bezel unchanged (the machine is still on) |
| **Loading / starting** | Hero `--:--` in `lcdDim` with the ghost layer at full 0.06; phase reads `CUEING`; all 5 dots unlit |
| **No HR** | BPM `—` in `chromeDim`; all 5 dots unlit rings; existing `noHeartRateDetected` banner restyled: `ledAmber` text, 1pt `ledAmber` border using `MixtapeWindow(cornerRadius:4, chamfer:4)` |
| **Empty** (pre-start / no template) | Bezel + centred `— NO TAPE —`, 12pt `.monospaced .heavy .tracking(1.4)`, `chrome @0.4`, start CTA below |
| **Error** | `ERR` in `ledRed` at the hero position, one-line cause in `chromeDim`, retry button |
| **AOD (reduced luminance)** | Bezel **hidden**; hero `lcdLit @0.4`; BPM zone colour @0.4; dots outline-only; background pure `#000000`; **no cream capsule** (large bright area = burn-in + battery). Update `aodMinimalView` in `TrainingView+Metrics.swift` for the Mixtape branch |
| **Complete** | `SIDE B` cream capsule; `SIDE A COMPLETE` in `ctaPlay`; total duration as the hero; `MixtapeParkedReel` static pair centred at 40pt. No confetti, no animation |

---

## 5. Files that stay untouched

- `MixtapeReelBadge` — the spinning inline badge. **Not used by `MixtapeWatchDeck`.** Leave it for other surfaces; if a grep shows zero call sites, flag it for deletion rather than reworking it.
- `TrainingView+Metrics.swift` — only the `aodMinimalView` Mixtape branch changes. The non-Mixtape stacked layout, `HRZoneArc`, `OverallProgressStrip`, `IntervalStepWash`, and all padding helpers are out of scope.
- All existing accessibility labels, `updatesFrequently` traits, and the zone haptic — preserve verbatim.

---

## Implementation hand-off

- **Files to create:**
  - `ShuttlX Watch App/Theme/Components/MixtapeWindow.swift` (Shape only — no frame view on watch)
- **Files to modify:**
  - `ShuttlX Watch App/Theme/Themes/MixtapeTheme.swift` (palette — must match iOS literally)
  - `ShuttlX Watch App/Theme/Themes/Decorations/MixtapeTimerHero.swift` (bezel, ghost layer, cream capsule, zone ladder replacing `MixtapeVUMeter`, two-up metrics, static spool glyph)
  - `ShuttlX Watch App/Views/TrainingView+Metrics.swift` (Mixtape branch of `aodMinimalView` only)
  - `ShuttlX Watch App/Theme/ThemeModifiers.swift` (only if `mixtapeBackground()` is confirmed dead under the deck — see open question 1)
  - No pbxproj work: `ShuttlX Watch App/` is a synchronized folder
- **Reuse existing:** `ShuttlXColor.forHRZone()` / `.forStepType()`, `HeartRateZoneCalculator.fromSharedDefaults()`, `handleZoneHaptic` + `.directionUp`, `FormattingUtils.formatDistance/formatPace/formatTimer/formatTimeAccessible`, `trimLeadingZero`, `MixtapeParkedReel`, `compactMetric` sizing conventions from `TrainingView+Metrics.swift`.
- **Theme variants verified:** the app ships **2** themes. **Clean** is untouched (calm cardiac baseline). Every change here is inside a `MixtapeTheme` / `Mixtape*` file or the existing `if themeManager.current.id == "mixtape"` branch in `fullWorkoutDisplayTab`. `MixtapeWindow` is Mixtape-only and must not leak into shared watch components.
- **Watch performance check:**
  - **No idle animation added.** Every animation is event-driven: hero digits (`.contentTransition(.numericText())`, ~1 Hz), zone ladder (0.3s ease, fires only on zone change), pause colour swap. The static spool glyph never rotates. No `TimelineView`, no `.repeatForever`.
  - **Static drawing only:** bezel = 1 stroked `Shape` + 1 clipped gradient; spool = 1 `Canvas`, drawn once, no state input. The 12-segment VU (12 `RoundedRectangle`s re-coloured on every HR tick) is **removed** and replaced by 5 dots → fewer views, fewer invalidations.
  - **Height budget:** 150pt of 180pt on 41mm (table above). Verify on 41mm at `.accessibility1` — the two-up metric row is the first thing to break; its `minimumScaleFactor(0.4)` floor is the safety valve.
  - **OLED/AOD:** background is `#14180F` (near-black), bezel and cream capsule are suppressed in AOD, background drops to pure `#000000`.
- **Open questions for dev:**
  1. `MixtapeWatchDeck` sets `.background(lcdWell.ignoresSafeArea())` while `.themedScreenBackground()` also paints `mixtapeBackground()` beneath it. One is dead paint — which wins? Resolve before layering the bezel.
  2. Does `MixtapeReelBadge` still have any call site? If not, propose deletion rather than recolouring it.
  3. The 14pt static spool glyph (§3.2) is the one element I'd cut first if it reads as a bicycle wheel on a real 41mm. Build it, look at it once on device, and delete it if it doesn't land — no need to escalate.
  4. HR zone ramp change flows through `ShuttlXColor.forHRZone()` to the recovery/cardiac watch surfaces too. Wants a `ux-ui-designer` sign-off before merge.
  5. `MixtapeVUMeter` and `vuLevel(bpm:)` become dead code — confirm no other consumer before deleting.
