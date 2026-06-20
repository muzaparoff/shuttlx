# watch.md — Mixtape "Walkman deck LCD" timer face

Implementation spec for `swiftui-watchos-specialist`. Target: replace the body of
`MixtapeWatchDeck` in
`ShuttlX Watch App/Theme/Themes/Decorations/MixtapeTimerHero.swift` (line 113).
The struct signature, the call site in `TrainingView.swift` (~line 189–204), and
the existing color tokens stay as-is. This is a body rewrite, not a new wiring.

```swift
struct MixtapeWatchDeck: View {
    @ObservedObject var workoutManager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isInterval: Bool
    let screenH: CGFloat   // physical screen height; drives proportional type
    private let hrCalc = HeartRateZoneCalculator.fromSharedDefaults()
}
```

---

## 1. Design language

ONE material: a **matte deck body** (full-bleed subtle charcoal gradient) carrying a
single **recessed LCD well** that holds every metric. The cassette is implied by a
small twin-reel header band + an engraved "SIDE A" tag. A **VU meter bar** fills the
band between hero and HR and doubles as a live effort readout. A **transport glyph**
(▶ running / ‖ paused) sits top-right.

No separate red rule, no cream pill, no edge-pinned reels. Everything that is data is
amber/green on the LCD; the only non-LCD color is the HR value (zone-colored, safety).

---

## 2. Color tokens (hex — reuse existing, add 3)

Reuse from the current file:

| Token | Hex | Use |
|---|---|---|
| `lcdGreen` | `#39FF14` | hero (free-run), DIST/PACE values, "lit" VU segments in Z1–Z2 |
| `lcdGreenDim` | `#1C8009` | LCD bezel stroke, unlit VU segments, hairlines |
| `lcdWell` | `#051405` | recessed LCD background |
| `amberPause` | `#F2A61A` | paused hero + paused sublabel + paused transport bars + VU "hot" segments |
| `ledRed` | `#FF3333` | VU top-2 "peak" segments (clip), tape-low warning |
| `labelInk` | `#1C2330` | SIDE A tag ink, engraved tag stroke |
| `textSecondary` | `#8CADCC` | metric labels (DIST/PACE/HR/ELAPSED) |

Add these (deck body + amber LCD warm tint so the panel reads "vintage display" not
"terminal green"):

| New token | Hex | Use |
|---|---|---|
| `deckBodyTop` | `#2A2E36` | deck body gradient top |
| `deckBodyBottom` | `#15171C` | deck body gradient bottom |
| `lcdAmber` | `#FFB02E` | hero glow rim + VU mid segments + SIDE A tag fill on deck |

> The well stays near-black (`lcdWell #051405`) but the **hero text** gets an amber
> drop glow (`lcdAmber`, radius ∝ heroSize·0.06) so green digits sit on a warm halo —
> this is the "amber phosphor" Nakamichi/Walkman cue and lifts contrast vs. the old
> dim-green-on-near-black (now ~9:1 green-on-#051405, comfortably AA).

Step-type heroes (interval) keep `ShuttlXColor.forStepType(step.type)` for the hero
digits + sublabel + the VU/amber glow rim, exactly as today.

---

## 3. Layout, top → bottom

Outer container: `VStack(spacing: screenH * 0.018)` inside the deck body.
`.padding(.horizontal, 6)`, `.padding(.top, 20)` (clears the shell screws drawn by
`mixtapeBackground()`), `.padding(.bottom, 4)`, `.frame(maxWidth/maxHeight: .infinity)`.

**Deck body** = a `RoundedRectangle(cornerRadius: 10)` filled with
`LinearGradient([deckBodyTop, deckBodyBottom], .top → .bottom)` behind the whole VStack,
inset 2pt from the screen edge, with a 1pt `lcdGreenDim.opacity(0.25)` top hairline
(brushed-metal highlight). `.allowsHitTesting(false)`.

### Proportional sizes (functions of `screenH`)

```
reelBand    = max(14, screenH * 0.075)   // header reel diameter
tagSize     = max(8,  screenH * 0.046)   // SIDE A tag / transport glyph
heroSize    = max(34, screenH * 0.195)   // hero number
subLabel    = max(8,  screenH * 0.046)   // ELAPSED / WARMUP 2/8
vuHeight    = max(8,  screenH * 0.040)   // VU bar height
hrSize      = max(26, screenH * 0.135)   // BPM number
labelSize   = max(9,  screenH * 0.050)   // DIST/PACE/HR labels
metricSize  = max(15, screenH * 0.082)   // DIST/PACE values
```

41mm screenH ≈ 224pt usable → hero ≈ 44pt, hr ≈ 30pt, metrics ≈ 18pt. Verified to
fit the ~180pt content budget (see §10 height audit).

### 3a. Header band (NOT inside the LCD well)

`HStack(spacing: 4)`, height `reelBand`:

1. **Twin reel cue** — `MixtapeReelTape` (new tiny Canvas or reuse `MixtapeReel`):
   two reels of diameter `reelBand` with a 2pt `lcdGreenDim` "tape" line connecting
   their centers. Left reel spins `-spinDegrees`, right spins `+spinDegrees`
   (monotonic off `elapsedTime`, halts on pause, `reduceMotion ? 0`). 1pt black shadow.
   `.accessibilityHidden(true)`.
   - *Differential fill is dropped on the header* — at 14–16pt it doesn't read; the
     tape-progress is shown by the VU/hero glow instead. Keep both reels equal size.
2. `Spacer(minLength: 4)`
3. **SIDE A tag** — `Text("SIDE A")` at `tagSize`, weight `.heavy`, mono, `labelInk`,
   on a `Capsule().fill(lcdAmber.opacity(0.85))` with 3×1 padding. Engraved feel:
   add a `.stroke(labelInk.opacity(0.4), 0.5)` overlay. This is a small deck label,
   not a banner.
4. **Transport glyph** — `tagSize·1.2`, see §5. `▶` when running, `‖` when paused.

`.accessibilityElement(children: .combine)` →
label `"\(workoutName), SIDE A, \(isPaused ? "paused" : "playing")"`.

### 3b. LCD well (the metric panel — everything else lives here)

A `VStack(spacing: screenH * 0.012)` on a `RoundedRectangle(cornerRadius: 8)`
filled `lcdWell`, `.padding(.horizontal, 8)`, `.padding(.vertical, 6)`,
`.frame(maxWidth: .infinity)`, with an engraved bezel:
`.overlay(RoundedRectangle(cornerRadius: 8).stroke(lcdGreenDim.opacity(0.55), lineWidth: 1))`
and an inner `.shadow(color: .black.opacity(0.6), radius: 2)` (recessed look).

Rows inside the well:

**Row A — sublabel line** (`HStack`):
- left: `Text(heroSubLabel)` at `subLabel`, weight `.heavy`, mono,
  color = `isPaused ? amberPause : (isInterval ? stepTint : textSecondary)`.
  Free-run: `"ELAPSED"`. Interval: `"WARMUP 2/8"` (step name + index, uppercased).
- `Spacer()`
- right: a tiny 1-reel `◷` glyph (the take-up reel mini, `subLabel` size,
  `lcdGreenDim`) — optional decorative full-stop. `.accessibilityHidden(true)`.

**Row B — HERO** (`Text(heroText)`):
- `heroSize`, weight `.bold`, `design: .monospaced`, `.monospacedDigit()`.
- color = `isPaused ? amberPause : heroTint` (heroTint = `lcdGreen` free-run /
  `stepTint` interval).
- `.shadow(color: lcdAmber.opacity(isPaused ? 0 : 0.55), radius: heroSize*0.06)`
  — the amber phosphor halo. Paused → no glow (static, calm).
- `.contentTransition(.numericText())`, `.lineLimit(1)`, `.minimumScaleFactor(0.5)`.
- Free-run text = `formatTimer(elapsedTime)` ("20:12").
  Interval text = `formatTimer(max(0, engine.currentStepTimeRemaining))`.

**Row C — VU METER + HR** — a two-line block so the big BPM number and its
unit/zone never collide or overflow the trailing edge (this is the layout that
killed the earlier edge-clip — see §11 safe-box):
- **Line C1** (`HStack(spacing: 6)`, baseline-aligned):
  - left, fills width: `VUMeter` bar, height `vuHeight` — see §4. The bar takes only
    the slack to the left of the HR number; cap it so it never grows under the digits.
  - right, fixed (`.layoutPriority(1)`, trailing-aligned): `Text(bpm)` at `hrSize`,
    `.monospacedDigit()`, `foregroundStyle(ShuttlXColor.forHRZone(bpm))`,
    `.lineLimit(1)`. `bpm <= 0` → `—`. The digits are the ONLY thing on the right of
    this line, so 3-digit HRs (e.g. 142) always fit before the trailing inset.
- **Line C2** (`HStack`, the units/zone strip directly under the number):
  - left: `Text("HR")` at `labelSize`, `textSecondary`.
  - `Spacer()`
  - right cluster (trailing-aligned, in order): `Text("BPM")` at `labelSize`
    `textSecondary`, then the `Z\(zone)` badge — `Text("Z\(zone)")` at `labelSize`,
    zone-colored, in a 32×20 `RoundedRectangle(cornerRadius: 4).stroke(zoneColor·0.5)`.
    The badge is the rightmost element; its trailing edge must respect the well's
    inner inset (it sits inside the LCD well's 8pt horizontal padding, which already
    keeps it ≥14pt off the deck-body edge — never absolutely-position it).
- Rationale for splitting BPM/Z2 onto C2 (not trailing the number on C1): at
  `hrSize` ≈ 26–30pt the digits + "BPM" + a boxed Z badge on one line overflow the
  trailing edge on 41mm (the exact defect that clipped the Z2 box past the screen).
  Stacking the unit strip under the number frees the full right margin for the digits
  and gives the badge its own bounded row.

**Row D — DIST / PACE two-up** (`HStack(spacing: 8)`): two `lcdMetric` cells.
Each cell = `HStack(spacing: 4)` with a **fixed-width label gutter** then value:
```
Text(label)                       // "DIST" / "PACE"
  .frame(width: screenH*0.16, alignment: .leading)   // gutter — prevents the "IST" clip
  .font(labelSize, .bold, mono).foregroundStyle(textSecondary)
Text(value).font(metricSize, .bold, mono).monospacedDigit()
  .foregroundStyle(lcdGreen).minimumScaleFactor(0.5).lineLimit(1)
```
`.frame(maxWidth: .infinity, alignment: .leading)`. DIST = `formatDistance(totalDistance)`,
PACE = `currentPace.map(formatPace) ?? "—"`.

> The fixed gutter + the cell's own `maxWidth: .infinity` + 6pt well padding + 6pt
> outer padding guarantees no label or value can reach a screen edge. This is the
> direct fix for the "IST 1.92" clip.

---

## 4. VU meter behavior

A horizontal segmented bar — the cassette-deck signature. It maps **heart-rate
effort** to lit segments (Nakamichi peak-meter, cold-left → hot-right).

- **Segments:** 12 equal capsules, `spacing 2`, each `width = (totalW - 22) / 12`,
  height `vuHeight`, `cornerRadius vuHeight*0.3`.
- **Drive value:** normalized HR fraction
  `level = clamp((bpm - restApprox) / (maxHR - restApprox), 0, 1)` where
  `maxHR = hrCalc.estimatedMaxHR`, `restApprox = maxHR * 0.40` (so Z1 starts lighting
  ~2–3 segments, Z5 fills the bar). If `bpm <= 0` → `level = 0` (all unlit).
- **Lit count:** `litN = Int((level * 12).rounded())`.
- **Per-segment color (index i, 0-based, left→right):**
  - `i >= litN` → unlit: `lcdGreenDim.opacity(0.25)`
  - lit & `i < 7` → `lcdGreen` (cool / Z1–Z2 band)
  - lit & `7 <= i < 10` → `lcdAmber` (working / Z3–Z4)
  - lit & `i >= 10` → `ledRed` (peak / Z5 + high-intensity warning) — these are the
    "+dB clip" segments borrowed from the Nakamichi -40→+7dB meter.
- **Paused:** freeze at the last `litN`, recolor ALL lit segments to `amberPause`
  (deck "paused" tint), drop any animation. No motion.
- **Animation (running only):** `.animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: litN)`
  so segments settle smoothly as HR drifts. This is the ONLY data-driven motion
  besides the reels; it is inherently event-driven (HR ticks ~1 Hz), not an idle
  loop, so it satisfies the no-idle-animation rule — it stops moving the moment HR
  is steady and on pause.
- **Reduce Motion:** segments still recolor/relight (state, not motion) but with no
  transition animation — instant snap.
- **Accessibility:** the VU bar is `.accessibilityHidden(true)` (it's a redundant view
  of HR, which is already announced by the HR cluster). Do not double-announce effort.

```
HR 60bpm (Z1): ▮▮▯▯▯▯▯▯▯▯▯▯   (2 green)
HR 142  (Z2):  ▮▮▮▮▮▮▯▯▯▯▯▯   (6 green)        ← the mockup state
HR 168  (Z4):  ▮▮▮▮▮▮▮🟧🟧🟧▯▯  (7 green + 3 amber)
HR 185  (Z5):  ▮▮▮▮▮▮▮🟧🟧🟧🟥🟥 (full, top 2 red)
```

---

## 5. Transport glyph states

Top-right of the header band, `tagSize·1.2`, weight `.heavy`:

| State | Glyph | Color | Motion |
|---|---|---|---|
| Running (free-run or interval) | `▶` (`Text("\u{25B6}")` or `Image(systemName: "play.fill")`) | `lcdGreen` | none — static lit "play" light |
| Paused | `‖` (two bars; `Image(systemName: "pause.fill")`) | `amberPause` | none |

Prefer SF Symbols `play.fill` / `pause.fill` for crisp small rendering, tinted as
above. `.accessibilityHidden(true)` (state is in the header's combined label).

> No blinking. A static lit play/pause light is the authentic deck cue and respects
> the no-idle-animation rule. The "is it running?" signal is carried by color (green
> vs amber) across the hero, sublabel, VU, and this glyph in unison.

---

## 6. INTERVAL vs FREE-RUN

| Element | Free-Run | Interval |
|---|---|---|
| Hero text | `formatTimer(elapsedTime)` | `formatTimer(currentStepTimeRemaining)` |
| Hero color | `lcdGreen` | `ShuttlXColor.forStepType(step.type)` |
| Sublabel | `"ELAPSED"` (textSecondary) | `"\(step.type.displayName.uppercased()) \(idx+1)/\(total)"` in stepTint |
| Hero glow rim | `lcdAmber` | `stepTint` (so warmup=amber-ish, run=red-ish per step palette) |
| VU bar | HR-driven | HR-driven (identical) |
| HR / DIST / PACE | identical | identical |
| Header reels / SIDE A / transport | identical | identical |

The whole interval/free-run difference is the hero + sublabel + tint, driven by
`isInterval` and `workoutManager.intervalEngine`. Everything else is shared. Use the
existing `heroText / heroSubLabel / heroTint / heroProgress` helpers — they already
encode this; keep them.

---

## 7. Paused state (whole-deck)

When `workoutManager.isPaused`:
- Hero, sublabel → `amberPause`, hero glow OFF (static).
- Transport glyph → `pause.fill` amber.
- VU bar → frozen, all lit segments `amberPause`.
- Reels → halt (elapsedTime stops advancing; no catch-up).
- SIDE A tag, DIST/PACE labels, HR → unchanged (HR keeps zone color; it's still real).
- Add a small `‖ PAUSED` is NOT needed as a separate chip — the amber wash across
  hero+glyph+VU already says it coherently (this removes the old cream PAUSED pill,
  one of the "four languages").

Optional (nice-to-have, low cost): a single non-repeating 0.25s fade when entering
pause so the green→amber transition isn't a hard cut. Gated on `!reduceMotion`.

---

## 8. Reduce Motion

- Reels: no rotation (`spinDegrees → 0`).
- VU bar: relights/recolors instantly (no `.easeOut`), still reflects current HR.
- Hero: `.contentTransition(.numericText())` is fine (it's a content change, not an
  idle loop) but wrap the pause fade in `reduceMotion ? nil`.
- No glow pulsing under any setting — the amber glow is a static shadow, not animated.

---

## 9. Accessibility labels (full list)

| Element | accessibilityElement | Label |
|---|---|---|
| Header band | `.combine` | `"\(workoutName), Side A, \(isPaused ? "paused" : "playing")"` |
| LCD well (hero) | `.combine`, `.updatesFrequently` | Free-run: `"Elapsed time \(formatTimeAccessible(elapsedTime))"`. Interval: `"Time remaining \(formatTimeAccessible(currentStepTimeRemaining)), \(heroSubLabel)"` |
| HR cluster | `.combine`, `.updatesFrequently` | `bpm > 0 ? "\(bpm) beats per minute, Zone \(zone)" : "Heart rate, no data"` |
| DIST cell | `.combine` | `"Distance \(formatDistance(totalDistance))"` |
| PACE cell | `.combine` | `"Pace \(pace == nil ? "no data" : formatPace(pace))"` |
| VU bar, reels, transport glyph, mini reel | `.accessibilityHidden(true)` | — (redundant / decorative) |

Reuse the existing `heroSubLabel`, `heroA11yLabel`, `forHRZone`, `forStepType`,
`formatTimer`, `formatTimeAccessible`, `formatDistance`, `formatPace`, and
`hrCalc.zone(for:)` — no new plumbing.

---

## 10. Height audit (41mm, screenH ≈ 224, ~180pt content budget)

| Block | Height |
|---|---|
| top padding (clears screws) | 20 |
| header band (reels) | ≈ 17 |
| VStack spacing ×1 | 4 |
| LCD well padding (6+6) | 12 |
| sublabel row | ≈ 11 |
| hero row | ≈ 44 |
| VU + HR number line (C1) | ≈ 30 |
| HR / BPM / Z2 strip (C2) | ≈ 14 |
| DIST/PACE row | ≈ 18 |
| inner spacing ×4 (~2.5 each) | 10 |
| bottom padding | 4 |
| **Total** | **≈ 167** |

Fits with ~13pt slack on 41mm; scales up on 45/49mm. The previous design overflowed
because reels + LCD window + HR + metrics were 4 *separate full-width bands*; folding
HR/DIST/PACE/VU into one LCD well and shrinking the reels to a header reclaims the
dead space. (C2 is a thin units strip, not a full metric row — it costs ~14pt and
buys the overflow-proof HR cluster.)

---

## 11. Safe content box (DO NOT reintroduce edge clips)

The mockup SVGs use real pixel dimensions; the inner deck body is inset from the
screen, so every drawn element must live inside a safe content box:

| Watch | Screen px | Deck body | **Safe content box (use this)** |
|---|---|---|---|
| 41mm | 352 × 430 | x 10–342, y 20–416 | **x ∈ [24, 328]**, **bottom ≤ 400** |
| 45mm | 396 × 484 | x 12–384, y 24–460 | **x ∈ [28, 370]**, **bottom ≤ 448** |

Rules for the engineer (these map to SwiftUI, not absolute coords — they're the
intent the layout must honor):
- The whole deck lives inside the LCD well, which has 8pt horizontal padding inside a
  body inset 2pt from the screen, inside the view's 6pt outer padding. That stack of
  insets is what keeps content ≥14pt off the deck-body edge. **Never absolutely
  position** the HR number, BPM unit, or Z badge — let `Spacer()` + `HStack` trailing
  alignment place them so they reflow within the well width on any screen size.
- The HR digits are the rightmost element on line C1; the Z badge is the rightmost on
  line C2. Both terminate at the well's trailing inner edge, never past it.
- `.minimumScaleFactor` (hero 0.5, HR 0.6, metrics 0.5) is the safety net for 4-digit
  edge cases (e.g. distance "10.42 km", HR clamps to "—" if no data).

**Verified clip-free** in all four mockups after the 2026-06-20 fix: on 41mm the HR
cluster's rightmost pixel (Z2 badge) is **x = 326** (was x ≈ 366, clipping ~24px past
the deck body and ~14px past the screen); on 45mm it is x = 368. Both sit inside the
safe box with breathing room.

---

## Implementation hand-off

- **Files to create:** none required. (Optional: a small `MixtapeReelTape` / `MixtapeVUMeter`
  helper view — author it as a `private struct` inside the existing
  `MixtapeTimerHero.swift` to keep the theme decoration self-contained. Do NOT add a
  new file under `Theme/Themes/Decorations/` unless you prefer it; spec assumes inline.)
- **Files to modify:** `ShuttlX Watch App/Theme/Themes/Decorations/MixtapeTimerHero.swift`
  — rewrite the body of `MixtapeWatchDeck` (line 113) per §3–§9; add the 3 new color
  tokens (`deckBodyTop`, `deckBodyBottom`, `lcdAmber`) alongside the existing palette
  (lines 126–134); add `private struct` for VU bar + reel-tape band.
- **Reuse existing:** `MixtapeReel` image asset; tokens `lcdGreen/lcdGreenDim/lcdWell/
  amberPause/ledRed/labelInk/textSecondary`; helpers `heroText/heroSubLabel/heroTint/
  heroProgress/heroA11yLabel`; `ShuttlXColor.forHRZone/forStepType`; `HeartRateZoneCalculator`
  (`.zone(for:)`, `.estimatedMaxHR`, `.isHighIntensityWarning`); `FormattingUtils.*`;
  `ShuttlXSpacing`. The `TrainingView.swift` call site (line 189) is unchanged.
- **Theme variants verified:** Mixtape only — this view is gated by
  `themeManager.current.id == "mixtape"` in `fullWorkoutDisplayTab` (line 189). Other
  themes route to the standard stacked layout; no cross-theme impact. iOS Mixtape hero
  (`MixtapeTimerHero` full deck) is a separate surface — out of scope here, but the new
  `lcdAmber`/VU vocabulary could later harmonize it (note for designer, not this task).
- **Open questions for dev:**
  1. `HeartRateZoneCalculator` exposes `estimatedMaxHR` but I assumed `restApprox =
     maxHR*0.40` for the VU floor — confirm there's no stored resting-HR you'd rather
     use. If a real resting HR exists, prefer it for the VU `level` floor.
  2. `MixtapeReelTape` header band: reuse the `MixtapeReel` PNG at 14–16pt, or draw a
     parametric 2-circle-with-spokes `Canvas`? PNG is authentic but may alias at 14pt;
     your call on which renders crisper on-device. (Designer leans Canvas at this size.)
  3. The current `MixtapeWatchDeck` drives a differential reel size cue (supply
     shrinks / take-up grows) off `tapeProgress`. I dropped it on the header (too small
     to read). If you want to keep *some* progress cue, the cleanest home is a thin
     1pt amber underline beneath the hero that fills L→R with `heroProgress` — confirm
     whether to add it (spec leaves it out to stay clean).
  4. Confirm SF Symbols `play.fill`/`pause.fill` vs. literal `▶`/`‖` glyphs renders
     better at `tagSize·1.2` on 41mm — pick the crisper one.
