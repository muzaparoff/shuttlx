# Mixtape Authentic — Research & Rationale

**Date:** 2026-06-13
**Author:** product-designer
**Scope:** Reference redesign of the Mixtape theme (iOS + watchOS as ONE product) + a reusable
"authentic hardware" component framework that will be the template for redesigning all 8 themes.

This is the **flagship** proposal. The Mixtape work proves a pattern; the framework section
(`§4`) is the part that survives into Synthwave, Arcade, VU Meter, etc.

---

## 1. Why the current Mixtape theme fails

I read the live implementation before designing:

- `ShuttlX/Theme/Themes/MixtapeTheme.swift` — palette + `.lcd` CardStyle, mostly recolors to blue.
- `ShuttlX/Theme/AppTheme.swift` → `mixtapeBackground()` — a dark blue fill + faint texture lines
  + a blue sheen. **It is a tint, not a cassette.** The "background" is generic plastic-blue, never
  the cassette shell itself.
- `ShuttlX/Theme/ThemeModifiers.swift` → `CassetteHeaderView` / `ReelCounterView` — small monospaced
  strips bolted to the top/bottom of cards ("A · IEC TYPE II", "◀◀ REW 0000:00 FF ▶▶"). These are
  the *only* genuinely cassette-y touches and they live in card chrome, not the screen.
- `MixtapeTimerHero.swift` (iOS) — actually quite good already: spinning twin reels, an LCD counter,
  a label sticker, a VU HR strip, a pace needle, and a transport row. **But:** it only exists on the
  active workout timer; the transport buttons are flat `RoundedRectangle` fills with **no pressed
  state** (no `configuration.isPressed`, no travel, no shadow inversion); the reels float on a plain
  blue field rather than inside a cassette window cut into a shell; and the metaphor evaporates the
  moment you leave the timer (template picker, history, settings are just "blue Clean").

**The user's three complaints, mapped to root causes:**

| Complaint | Root cause in code |
|---|---|
| "Doesn't look like a real cassette" | `mixtapeBackground()` is a tint; no shell geometry anywhere |
| "Buttons don't behave like Walkman keys" | `transportButton` / the PLAY button use static fills, no `isPressed` depth, no travel, no haptic |
| "The background isn't the cassette itself" | There is no full-bleed cassette scene; content sits on a generic dark field, not on a J-card label area |

The fix is **two reusable framework pieces** (a themed `ButtonStyle` family + a full-bleed
"themed scene" protocol) and then a **concrete Mixtape composition** that uses them so the WHOLE
screen reads as a cassette in a Walkman.

---

## 2. Real cassette anatomy (research → SwiftUI primitives)

Sources studied (cited at bottom). Translating each physical part into a drawable primitive:

```
        ┌──────────────────────────────────────────────┐
   (s)  │ ○  write-protect tabs   Type-II notch   ○ (s) │  ← top edge: 2 corner screws + tab wells
        │  ┌────────────────────────────────────────┐  │
        │  │   J-CARD LABEL AREA  (cream/white)      │  │  ← where ALL workout content sits
        │  │   "slanted handwritten title"           │  │
        │  └────────────────────────────────────────┘  │
        │      ╭───────╮   [counter]   ╭───────╮        │  ← two HUB WINDOWS (circular cut-outs)
        │      │ ◎reel │               │ reel◎ │        │     showing reels + tape wound on them
        │      ╰───────╯               ╰───────╯        │
        │  ┌────────────────────────────────────────┐  │
        │  │      ▢▢ tape window (head contact)  ▢▢  │  │  ← clear window, felt pad behind, tape ribbon
        │  └────────────────────────────────────────┘  │
   (s)  │ ○        brand strip / Type-II / 90 min    ○ │  ← bottom edge: 2 corner screws + brand strip
        └──────────────────────────────────────────────┘
```

Part-by-part:

| Physical part | Appearance | SwiftUI primitive | Approx hex |
|---|---|---|---|
| **Shell body** | matte plastic, slightly translucent smoke or solid color | `RoundedRectangle(16)` filled with a top-lit vertical `LinearGradient` | `#26303F`→`#161E29` (smoke-blue) |
| **4–5 corner screws** | small recessed Phillips/slot, brushed metal | small `Circle` + cross `Path`, radial gradient for recess | `#8A93A0` rim, `#3A4250` recess |
| **Hub windows (×2)** | circular cut-outs revealing reels | `Circle` "window" with inner shadow, content (reel Canvas) clipped to it | window bezel `#0E1420` |
| **Reel hubs** | 6-tooth clutch gear, dark, spins | reuse `drawReel()` Canvas from `MixtapeTimerHero` (6 spokes + hub + spindle) | tape ring `#33240F`, spoke `#4A6A9A` |
| **Tape wound on reels** | brown oxide ring, thickness changes (supply shrinks, take-up grows) | already implemented: `outerRadius` interpolates by `fraction` | oxide `#33240F`, leader/clear `#1A3060` |
| **Tape window (head)** | rectangular clear slot, felt pad behind | `RoundedRectangle(4)` with `Color.black.opacity(0.6)` + a felt pad `Capsule` | felt `#B8453A` (period red-brown felt) |
| **J-card label** | cream paper, ruled line for title, "A"/"B" side box | `RoundedRectangle(6)` cream fill `#EDE7D3`, a thin baseline rule, "SIDE A" box | paper `#EDE7D3`, ink `#1C2330` |
| **Slanted handwritten title** | felt-tip marker, italic, slightly rough | `ShuttlXFont` italic + small rotation (`-3°`); content = workout name | ink `#1C2330` |
| **Type-II / brand strip** | tiny uppercase technical print | monospaced 6–7pt, `tracking` | `#8CADCC` |
| **Write-protect tab wells** | two square recesses, top edge | two `RoundedRectangle(1.5)` insets | shadow `#0B1018` |

**Walkman transport keys (Sony WM / TPS-L2 lineage):** chunky, near-square plastic keys, slightly
proud of a recessed channel, with an **embossed glyph** (▶ ‖ ■ ◀◀ ▶▶). When pressed they **travel
down ~2pt into the channel**, the top highlight collapses, and the bottom shadow inverts — the
tactile "clunk." Real decks latch PLAY down while playing; that latch is exactly our **paused/active
state cue** (PLAY key sits depressed while the tape runs; pressing PAUSE pops PLAY up).

Color: the 1979 TPS-L2 was "a dark-blue brick with chunky silver buttons." We adopt
**silver-on-blue** keys: brushed silver keycaps `#C7CCD4`→`#9AA1AC`, embossed dark glyphs `#2A3038`,
seated in a dark channel `#0E1420`.

---

## 3. Material & mood board (in words + ASCII)

- **Surface:** injection-molded smoke-blue ABS plastic, top-lit, faint horizontal mold lines
  (already in `mixtapeBackground` — keep, reduce opacity).
- **Metal:** brushed aluminium screws + transport keys; cool, slightly desaturated.
- **Paper:** the J-card is the only warm element — cream stock, felt-tip ink. This warm/cool
  contrast is the whole charm: cold machine, warm human handwriting.
- **Light:** single soft key light top-left. Screws catch a highlight top-left, shadow bottom-right.
- **Motion:** reels spin (24fps Canvas), tape oxide ring redistributes supply→take-up, transport
  keys clunk. Everything else is still.

```
  cold machine ███ smoke-blue ABS ███   warm human ░░ cream J-card ░░
  brushed silver keys ▮▮▮              felt-tip marker title  ✎
  green LCD counter [88:88]            red felt pad ▰
```

---

## 4. The reusable "authentic hardware" framework (generalizes to all 8 themes)

This is the durable deliverable. Two additions to `Theme/`, plus a convention. Full Swift shapes
are specified in `ios.md §6`; here is the architecture and why it slots into what exists.

### 4.1 `ThemedTransportButtonStyle` — a per-theme `ButtonStyle` family

A `ButtonStyle` that reads the active theme and renders a hardware control with **real pressed
state** via `configuration.isPressed`. The theme supplies *geometry + materials* through a small
value type so each theme draws its own switch/key/knob without forking the press logic.

```swift
// New file: Theme/Components/ThemedTransportButton.swift  (mirrored iOS + watch)

/// Geometry + materials a theme provides for its hardware control.
struct TransportButtonSpec: Equatable {
    var shape: TransportShape          // .walkmanKey | .arcadeButton | .toggleRocker | .lcdSoftkey ...
    var cornerRadius: CGFloat
    var travel: CGFloat                // how far the cap sinks when pressed (pt)
    var capTop: Color                  // keycap gradient top
    var capBottom: Color               // keycap gradient bottom
    var channel: Color                 // recessed channel / well color
    var glyph: Color                   // embossed symbol color
    var highlight: Color               // top edge specular
    var pressedHaptic: SensoryFeedback // .impact(weight: .heavy) for Walkman "clunk"
    var depressLatches: Bool           // PLAY-style latch (stays down while role active)
}

enum TransportRole { case play, pause, stop, rewind, fastForward, skip }

struct ThemedTransportButtonStyle: ButtonStyle {
    let role: TransportRole
    var isLatched: Bool = false        // externally driven (e.g. PLAY latched while running)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View { /* see ios.md §6.1 */ }
}
```

Press behavior (shared, never re-implemented per theme):
- `configuration.isPressed || isLatched` → cap offset down by `spec.travel`, top highlight
  fades to 0, channel shadow deepens, glyph nudges down with the cap.
- `.sensoryFeedback(spec.pressedHaptic, trigger: configuration.isPressed)`.
- Reduce Motion: travel clamped to 0, only a color/shadow swap (still legible state change).
- The theme picks the spec via `ThemeManager.shared.current.id` inside the style (or via a new
  `transportSpec` token on `ThemeEffects` — see Open Questions).

**Why this generalizes:** every future theme just defines its own `TransportButtonSpec` (Arcade →
round arcade button with a hard 4pt travel + click; VU Meter → toggle rocker; Neovim → flat
`[ PLAY ]` keycap with a 1pt terminal "press"). The pressed-state physics, haptics, accessibility,
and latch logic are written **once**.

### 4.2 `ThemedSceneBackground` — a full-bleed scene, not a tint

Today `.themedScreenBackground()` switches on `current.id` and applies a flat fill/overlay per
theme. We **keep that entry point** but upgrade each theme to render a *complete composition*. We
formalize the contract as a protocol so the switch body just delegates:

```swift
// New file: Theme/Components/ThemedSceneBackground.swift

protocol ThemedScene: View {
    /// Safe region where foreground content must live (the J-card label area for Mixtape,
    /// the LCD panel for FM Tuner, etc). Screens read this to inset their content.
    var contentSafeInsets: EdgeInsets { get }
}

struct MixtapeCassetteScene: View, ThemedScene {
    var progress: Double        // 0…1 drives tape distribution + take-up reel growth
    var isRunning: Bool         // reels spin only when true
    var reduceDetail: Bool      // Reduce Motion / low power → static, fewer screws/teeth
    var contentSafeInsets: EdgeInsets { .init(top: 96, leading: 28, bottom: 150, trailing: 28) }
    var body: some View { /* shell + screws + hub windows + tape window + label well */ }
}
```

`.themedScreenBackground()` for `"mixtape"` becomes:
```swift
self.background(MixtapeCassetteScene(progress: ..., isRunning: ..., reduceDetail: ...)
    .ignoresSafeArea())
```

For **non-active** screens (template list, history) `progress = 0`, `isRunning = false` → a static
cassette resting in the deck. The cassette is always present; only the reels' liveness changes.

### 4.3 Relationship to the existing per-theme hero pattern

The codebase already has `Theme/Themes/*TimerHero.swift` rendering the active-workout body per
theme. The new framework **subsumes and cleans up** that pattern:

- **Scene** = the full-bleed hardware *behind* everything (shell). Owns the look of every screen.
- **Hero** = the live instrument *on* the label area during a workout (reels + counter + VU). The
  existing `MixtapeTimerHero` becomes a thinner view that draws ON TOP of `MixtapeCassetteScene`
  and reuses the same `drawReel()` Canvas (now clipped inside the scene's hub windows).
- **TransportButtonStyle** = the controls, replacing the ad-hoc `transportButton`/PLAY button in the
  hero with `Button(...).buttonStyle(ThemedTransportButtonStyle(role: .play, isLatched: !isPaused))`.

No controller logic moves. Heroes/scenes remain read-only over workout state, exactly as the
design-system rule requires.

### 4.4 Migration order for the other 7 themes (after Mixtape ships)

1. Mixtape (this proposal) — proves Scene + TransportButtonStyle.
2. Arcade (round buttons + CRT cabinet scene) — best second test of the button family.
3. VU Meter, Classic Radio (rocker/knob controls, wood/metal panel scenes).
4. Synthwave, FM Tuner, Neovim (already have strong scenes; mostly adopt TransportButtonStyle).
5. Clean stays minimal — opts into a no-op `TransportButtonSpec` (flat, 0 travel) so it still routes
   through one code path.

---

## 5. Accessibility & safety stance (cardiac-rehab first)

- Skeuomorphism must **never** reduce HR/time legibility. The green LCD counter and the BPM readout
  keep `ShuttlXFont`/`ShuttlXColor` and full contrast; the cassette chrome sits *behind* them.
- Transport keys: ≥44pt touch target enforced even though the visual keycap can look chunkier; every
  key gets `.accessibilityLabel` + `.accessibilityHint` (already partially done in the hero).
- The PLAY-latched cue is a *secondary* signal — the primary paused indicator stays the explicit
  "PAUSED" text + amber color, so a low-vision user isn't relying on a 2pt key depression.
- **Reduce Motion / Low Power:** `reduceDetail = true` → reels static, screws/teeth simplified, no
  key travel (color swap only), tape oxide redistribution frozen. Spec'd per platform.

---

## 6. Sources

- [Cassette Tape Parts Diagram: Internal Anatomy Explained — Ultra Ferric](https://ultraferric.com/blogs/news/cassette-tape-parts-diagram-internal-anatomy-explained)
- [Understanding the mechanical parts of a cassette — Tapeheads.net](https://www.tapeheads.net/threads/understanding-the-mechanical-parts-of-a-cassette.101501/)
- [Anatomy of a TDK MA-XG Cassette — Tapeheads.net](https://www.tapeheads.net/threads/anatomy-of-a-tdk-ma-xg-cassette.61090/)
- [Audio tape cassette felt pad / leaf spring (USPTO 5420738)](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/5420738)
- [Walkman Central — WM-6 (transport layout, tape window)](https://walkmancentral.com/products/wm-6)
- [15 iconic Sony Walkman designs — Pocket-lint (TPS-L2 chunky silver buttons, dark-blue brick)](https://www.pocket-lint.com/gadgets/news/sony/150863-15-iconic-sony-walkman-designs-from-yesteryear-looking-back-at-classic-devices/)
- [The Walkman: A Visual History 1979–2004 — Obsolete Sony](https://obsoletesony.substack.com/p/history-of-the-walkman-1979-2004)
- [The Emotional Design of the Mixtape — Charles J. Moss, re:form](https://medium.com/re-form/the-emotional-design-of-the-mixtape-1d7b88e94f85)
- [J-Card | Purpose, Design, and Cultural Relevance — Audiodrome](https://audiodrome.net/glossary/j-card/)
- [J-card — Wikipedia](https://en.wikipedia.org/wiki/J-card)
