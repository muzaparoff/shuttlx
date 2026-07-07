# Mixtape Theme — Redesign Concepts

**Date:** 2026-06-30
**Author:** product-designer
**Status:** Concepts, awaiting direction
**Owns:** `design/proposals/mixtape-redesign/`

---

## 1. Honest assessment of the current state

The user's question — *"why is the background generated and not some beautiful actual image, then cleaned from logos and adapted as wallpaper?"* — is fair, and the answer is: we over-engineered it. The current `MixtapeCassetteScene` is a 500-line `Canvas` reconstruction of a cassette anatomy (screws, write-protect tabs, J-card paper texture, felt pad, brand strip). It is technically impressive and zero-asset, but it has three real problems that the reference images expose:

1. **It looks generic, not iconic.** A Sony WM-2 Walkman, an Aiwa HS-PX, a Sharp QT-50 — these are specific objects with personality. Our shell is "a cassette in the abstract." It doesn't trigger the nostalgia hit the theme is supposed to deliver. The Rainbow Player iOS app the user shared works because it picked ONE device (a yellow boombox) and committed to it photographically.
2. **The shell leaks behind non-timer content.** `MixtapeCassetteScene` is full-bleed via `themedScreenBackground()`. On the dashboard, settings, analytics, and template editors, the J-card strip and hub bezels show through behind navigation cards. This is a layering bug, not a design choice — it looks like the wallpaper forgot to get out of the way. The timer screen suppresses the J-card and hubs via `showJCard: false, showHubs: false`, which proves we already know the shell doesn't belong on every screen.
3. **Two reels in two places.** The scene draws static reel thumbnails AND the hero draws live animated reels on top. We added `MixtapeLayoutConstants` to keep them aligned. That's a smell — we're choreographing two systems to look like one. On watch the user already cut this for the same reason (reels at 14–18pt read as bicycle wheels).

What's working: the **palette is locked in** (smoke-blue shell, cream J-card, LCD green, felt-pad red, accent blue) and is genuinely Mixtape. The **transport buttons + VU bar + zone-tinted HR** on iOS is one of the prettiest timer surfaces in the app. The **watch deck redesign** (full-screen LCD, no reels, amber SIDE A tag, zone via colour + haptic) is the correct direction and should be preserved or extended.

The three concepts below differ on **one axis**: how authentic do we get with imagery, and where does that authenticity live?

---

## Concept A — "Real Walkman Wallpaper" (photo-based, committed)

**Tagline:** *One iconic device, photographed, cleaned, used everywhere it belongs.*

### Core visual approach

Pick ONE specific 1980s portable cassette player from CC0/PD sources (Wikimedia Commons has multiple: the original WM-2, a generic "personal cassette player" silhouette, the Aiwa CS-J1). Photograph or composite a top-down, perfectly square-on shot. Remove all brand marks in image editing. Adjust hue toward the existing Mixtape navy palette so it sits in the theme. Embed as `MixtapeWalkmanBody@2x.png` / `@3x.png` in the asset catalog (~400KB total).

This image becomes the **timer screen background** and **dashboard hero card background only**. Non-timer screens get a calm tinted-navy variant (NOT the player photo).

Use the photo for the **window cutout** where the live LCD/VU/reels go — the photo provides the chrome (yellow shell, BATT lamp, OPR switch, brushed-aluminum trim, real shadow, real wear) and our SwiftUI overlay provides the live data through a "screen hole" in the photo. This is exactly what the Rainbow Player app does.

### iOS timer screen mockup

```
┌─────────────────────────────────┐
│ ┌─Walkman photo bleeds to edge─┐│
│ │ ╔═══════════════════════════╗ ││ ← photo: yellow/navy hybrid
│ │ ║ ░ SIDE A  ● 5K RUN  PAUSED║ ││   cassette body, real shadows
│ │ ║ ───── J-card paper ──── 2K║ ││   real screws, real switches
│ │ ║                           ║ ││
│ │ ║      ╔═══════════════╗    ║ ││ ← LIVE LCD CUTOUT
│ │ ║      ║               ║    ║ ││   our SwiftUI draws inside
│ │ ║      ║   29:41       ║    ║ ││   the photo's window
│ │ ║      ║   ELAPSED Z3  ║    ║ ││   green LCD, monospaced
│ │ ║      ╚═══════════════╝    ║ ││
│ │ ║                           ║ ││
│ │ ║   ▮▮▮▮▮▮▮▯▯▯  142 BPM Z3  ║ ││ ← VU + HR overlay on photo
│ │ ║   ━━━━━━●━━   5'42"/km   ║ ││
│ │ ║                           ║ ││
│ │ ║   ╭─photo reel hubs──╮    ║ ││ ← photo provides the hubs
│ │ ║   │  ◉  spin  ◉ spin │    ║ ││   our overlay spins MixtapeReel
│ │ ║   ╰──────────────────╯    ║ ││   inside the cutout
│ │ ║                           ║ ││
│ │ ║  [REW] [PLAY] [FF] [STOP] ║ ││ ← real switch photo + tap overlay
│ │ ╚═══════════════════════════╝ ││
│ └───────────────────────────────┘│
└─────────────────────────────────┘
```

### iOS non-timer screens

Non-timer screens get a **calm tinted-navy `.themedScreenBackground()`**: solid `#161E29` shell color + a 6% horizontal scan-line texture, no J-card, no reels, no hub bezels. Sources to remove from `themedScreenBackground` switch: the full `MixtapeCassetteScene`. Add `MixtapeCalmBackground` (a `LinearGradient` + a `Canvas` texture, ~30 LOC).

The dashboard's primary CTA card (Start Workout) gets a small mini-photo of the Walkman as its card background — a "thumb of the device" — so the theme identity is still felt off-timer without taking over.

```
┌──────────────────────────┐
│ Dashboard          ⚙     │ ← calm navy + scanlines, no shell
│                          │
│ ┌──────────────────────┐ │
│ │  TODAY               │ │ ← standard themedCard, lcd style
│ │  5K Walk-Run        ▶│ │
│ └──────────────────────┘ │
│                          │
│ ┌─[mini walkman photo]─┐ │ ← only this card carries the photo
│ │ START WORKOUT      ▶ │ │
│ └──────────────────────┘ │
│                          │
│ Recent                   │
│ • Mon  5.2km  28:14      │ ← list rows, no shell behind
│ • Sun  3.1km  16:02      │
└──────────────────────────┘
```

### watchOS timer mockup

Keep the existing `MixtapeWatchDeck` exactly as-is (full-screen green LCD, amber SIDE A tag, VU bar, zone-tinted BPM, directional haptic). The watch does NOT get the photo treatment — at 41–45mm a photographic shell would compete with the timer and burn battery on the OLED. Coherence with iOS comes from **shared palette + shared LCD typography + shared "SIDE A" tag**, not shared imagery.

```
┌──────────────────────┐
│ [SIDE A] ▶ ELAPSED   │ ← amber capsule + play glyph
│                      │
│  29:41               │ ← hero LCD green, monospaced
│                      │
│ ▮▮▮▮▮▮▯▯▯ 142 BPM    │ ← VU + zone-tinted BPM
│ DIST          3.2 KM │
│ PACE       5'42"/km  │
└──────────────────────┘
```

### watchOS–iOS coherence

- Same `#39FF14` LCD green, same `#FFB02E` amber SIDE A tag, same `#1C2330` ink, same monospaced family
- Same "now-playing" header pattern: `[SIDE A]` capsule → `▶` glyph → phase name → timer
- Same VU-meter logic (HR-mapped, paused turns amber)
- Watch is the "playback head," iOS is the "device" — narratively coherent

### Implementation approach

1. **Source asset.** Find a CC0/PD top-down photo of a portable cassette player or composite one from PD parts. Wikimedia Commons "Cassette tape.svg" by Paul Sherman (already used for `MixtapeReel`) has the reel; Wikimedia has several PD Walkman-class photos. License must be CC0 / PD / CC-BY (with attribution in `Settings → About → Credits`). Brand marks removed in Pixelmator/Photoshop.
2. **Crop into 3 regions:** `MixtapeWalkmanFull` (timer screen full), `MixtapeWalkmanCard` (dashboard CTA card, ~120pt tall), `MixtapeWalkmanCalmTint` (navy + scanline fallback).
3. **Define the "screen hole."** A `Rect` constant (fraction of image) telling overlays where the live LCD/VU cutout sits. Hero positions content inside that rect.
4. **Hero refactor.** Drop the J-card, big-LCD-panel, decorative-reels-row, transport-button drawing code from `MixtapeTimerHero.swift` (~400 LOC out). Replace with: `Image("MixtapeWalkmanFull")` background + overlay aligned to the screen-hole rect containing timer/VU/HR/pace/transport. Net ~150 LOC.
5. **Background routing.** Modify `ThemedScreenBackground` so Mixtape returns `MixtapeCalmBackground` for non-timer surfaces, and timer surfaces opt into the full Walkman image themselves via a `.mixtapeTimerScreenBackground()` modifier called from `iPhoneWorkoutTimerView` only.
6. **Delete `MixtapeCassetteScene` and `MixtapeLayoutConstants`** once Step 4–5 land.

### Difficulty: **Medium**

### Key risks

- **Asset sourcing.** A genuinely beautiful PD photo of an iconic Walkman is the make-or-break. If the best we can find is mediocre, the whole concept collapses. Mitigation: prototype with a placeholder photo, get user sign-off on the device before doing the cleanup work.
- **Hue blending.** The yellow Walkman in the user's reference doesn't match our navy palette. We'd either accept that yellow IS the new Mixtape accent (re-tunes the theme) or hue-shift the body to navy in post (looks weird if done wrong).
- **Dynamic Type / large screen sizes.** A bitmap photo at iPhone Pro Max 6.7" upscales — needs `@3x` at minimum 1290×2796 px, ~600KB asset. Acceptable but worth noting.
- **Theme uniqueness vs accessibility.** A photo background reduces text contrast unless we overlay a darkening gradient. The Clean theme remains the calm cardiac baseline; users who can't read this can switch themes.

---

## Concept B — "J-Card Travel Wallet" (photo-textured paper, not the device)

**Tagline:** *The case, not the player — every screen is a J-card insert.*

### Core visual approach

Flip the metaphor: instead of putting a Walkman behind the UI, put a **cassette J-card paper insert** behind it. The J-card is the folded paper booklet that came in every cassette case — the side with track listings, hand-lettered titles, photocopied collage, marker doodles, ruled lines, sticker residue. This works on every screen because a J-card is naturally a column of typography on paper — exactly what list-based UI already is.

Source a high-resolution scan of a real cream/manila J-card paper (CC0 from Internet Archive or Unsplash) — laid-paper texture, slight aging, faint ruled lines, real fiber. Use it as a tiled background. Forms, settings, analytics, templates ALL become "filled-in J-card pages." The Walkman device only appears on the workout-active timer screen as an envelope around the card.

### iOS timer screen mockup

```
┌─────────────────────────────────┐
│ ░░░ ruled cream paper texture ░░│ ← real paper scan, full bleed
│                                 │
│  ┌─Mixtape #14 ── 2026 spring──┐│
│  │ SIDE A     ●REC   ▶︎ 1of3   ││ ← handwritten-style label header
│  ├─────────────────────────────┤│
│  │  01. WARM-UP          5:00  ││ ← tracklist styled as J-card
│  │  02. RUN              0:90 ◀││   current row highlighted with
│  │  03. WALK             1:30  ││   a red marker stripe (felt pad)
│  │  04. RUN              0:90  ││
│  │  05. WALK             1:30  ││
│  │  ─────────────────────────  ││
│  │  TOTAL  31:14 / 45:00       ││
│  └─────────────────────────────┘│
│                                 │
│  ┌─LCD readout─────────────────┐│ ← cream paper "die-cut" window
│  │   29:41   142 BPM Z3        ││   reveals dark LCD beneath
│  │   ▮▮▮▮▮▮▯▯ 5'42"/km        ││
│  └─────────────────────────────┘│
│                                 │
│  [REW]    [PAUSE]    [FF] [STOP]│ ← felt-tip-marker style buttons
└─────────────────────────────────┘
```

### iOS non-timer screens

Same paper texture, different content layouts. Section headers look like marker-pen subheads. Cards are "track entries" with that distinct J-card hand-lettered numbering (`01.` `02.` `03.`). Lists use the felt-pad red stripe to mark current/selected items.

```
┌─────────────────────────────┐
│ ░░░ ruled cream paper ░░░░░░│
│                             │
│ ┌─ MY MIXTAPES ────────────┐│ ← marker-pen section header
│ │ 01. Couch to 5K    [▶]   ││
│ │ 02. Hill repeats   [▶]   ││
│ │ 03. Recovery walk  [▶]   ││ ← red felt-pad stripe = active
│ │ 04. Free run       [▶]   ││
│ └──────────────────────────┘│
│                             │
│ ┌─ THIS WEEK ──────────────┐│
│ │ Mon  ●  5.2km  28:14     ││
│ │ Tue  ○  rest             ││
│ │ Wed  ●  3.1km  16:02     ││
│ └──────────────────────────┘│
└─────────────────────────────┘
```

### watchOS timer mockup

The watch is **the LCD inside the cassette window** — same as Concept A's watch (current `MixtapeWatchDeck`). The "case" metaphor doesn't translate to a 41mm round-cornered rectangle; the watch stays as the live readout it already is.

```
┌──────────────────────┐
│ [SIDE A] ▶ RUN 2/8   │
│  1:48                │ ← matches step countdown
│ ▮▮▮▮▮▮▯▯ 142 BPM     │
│ DIST          3.2 KM │
│ PACE       5'42"/km  │
└──────────────────────┘
```

### watchOS–iOS coherence

- iOS = the paper insert (case-side); watch = the LCD readout (device-side). They're literally two parts of the same physical object.
- Shared red felt-pad accent: marker stripe on iOS list rows = amber SIDE A capsule on watch (warm-accent role)
- Shared monospaced typeface for all numerics on both platforms
- Shared "SIDE A" / "SIDE B" wording — A while active, B on summary/complete

### Implementation approach

1. **Source paper scan.** One high-res cream paper texture (CC0, Unsplash or Internet Archive). Tile as `MixtapePaperTexture@2x.png` (~150KB), used as `.themedScreenBackground()` for Mixtape on all screens.
2. **Hand-lettered display font.** Either bundle a free script font (e.g. "Permanent Marker" via Google Fonts, OFL-licensed, ~40KB) for section headers + handwritten flourishes, OR use system rounded-bold with a slight rotation as a cheap approximation.
3. **Replace `MixtapeCassetteScene`** with `MixtapePaperBackground` view (~50 LOC: image + felt-pad red stripe on leading edge as the signature shape).
4. **Rewrite `MixtapeTimerHero`** to be a "J-card insert" — tracklist of steps with current row marker-striped, LCD die-cut window, transport buttons styled as marker-drawn squares.
5. **Re-style list rows app-wide** via the existing `.themedCard()` modifier — Mixtape variant becomes the J-card tracklist style. Other themes unaffected.
6. **No new image of a device** — saves asset weight and dodges the "which Walkman?" debate.

### Difficulty: **Medium-Hard**

### Key risks

- **Typography becomes the design.** This concept lives or dies on the hand-lettered font choice. Wrong font = "scrapbooking app." Right font = "this is the coolest fitness app on the App Store." High variance.
- **Tracklist-as-timeline is a UX gamble.** It's beautiful but adds vertical space the timer used to own. The hero LCD is small. Cardiac-rehab users mid-workout need glanceability; a track listing is more information than they need.
- **Cohesion with neutral surfaces.** Forms (template editor, plan editor) will look strange on paper. We'd either accept "all Mixtape screens are paper" (consistent but quirky) or carve out modal sheets to stay neutral. The latter is correct but adds complexity.
- **Bundled font** adds ~40KB and a dependency on font-loading; not zero-cost.

---

## Concept C — "Hybrid Hardware Window" (drawn shell stays, but only on timer + summary)

**Tagline:** *Keep the drawn cassette, but stop letting it leak — it's a chrome frame, not a wallpaper.*

### Core visual approach

The most conservative concept. Acknowledges that the existing `MixtapeCassetteScene` is well-built and the user has emotional investment in it (it's the current build's identity), and that the real problems are (a) it shows up where it shouldn't and (b) it has two-reel-systems duplication. Fix those, don't replace it.

The cassette shell stays on the **timer screen** and the **workout summary screen** ONLY. Everywhere else: a calm tinted-navy background with the felt-pad signature shape used as a small chrome accent (e.g. as the leading edge of section headers, as a tab indicator). Drop the duplicate static reels — the hero owns reels exclusively.

### iOS timer screen mockup

```
┌─────────────────────────────────┐
│ ┌────────────────────────────┐  │ ← drawn shell (existing scene)
│ │ ⊗──── J-CARD ──────────⊗  │  │   smoke-blue ABS, screws,
│ │ │ SIDE A ● 5K RUN  29:41 │ │  │   write-protect tabs
│ │ └────────────────────────┘ │  │
│ │                            │  │
│ │   ╔══════════════════════╗ │  │ ← single hero LCD panel
│ │   ║   29:41              ║ │  │   (existing big LCD)
│ │   ║   STEP 2/8     [RUN] ║ │  │
│ │   ╚══════════════════════╝ │  │
│ │                            │  │
│ │  HR ▮▮▮▮▮▮▯▯▯  142 BPM Z3 │  │
│ │  SPD ━━━━●━━━   5'42"/km  │  │
│ │                            │  │
│ │   ◉ supply   ━━━━━━ ◉ takeup│ │ ← single reel pair owned
│ │   spin slow     spin fast  │  │   by hero (no duplicate
│ │                            │  │   static reels behind)
│ │ ⊗  [REW][PLAY][FF][STOP] ⊗ │  │
│ │ ── IEC TYPE II · HIGH BIAS │  │
│ └────────────────────────────┘  │
└─────────────────────────────────┘
```

### iOS non-timer screens

```
┌─────────────────────────────┐
│ Dashboard           ⚙       │ ← solid #161E29, no shell, no
│                             │   J-card, no hubs
│  ┃ TODAY                    │ ← felt-pad red stripe as section
│  ┌─────────────────────────┐│   header accent (signature shape)
│  │ 5K Walk-Run         ▶  ││
│  └─────────────────────────┘│
│                             │
│  ┃ RECENT                   │
│  • Mon  5.2km  28:14        │
│  • Sun  3.1km  16:02        │
└─────────────────────────────┘
```

The felt-pad red capsule (`Color(red: 0.722, green: 0.271, blue: 0.227)`) becomes the Mixtape **signature shape** on neutral surfaces — used everywhere as a small accent stripe, marker, or chip. This satisfies the "one signature shape per theme" design DNA rule without putting the drawn cassette on every screen.

### watchOS timer mockup

Unchanged — current `MixtapeWatchDeck` is already correct.

```
┌──────────────────────┐
│ [SIDE A] ▶ ELAPSED   │
│  29:41               │
│ ▮▮▮▮▮▮▯▯ 142 BPM     │
│ DIST          3.2 KM │
│ PACE       5'42"/km  │
└──────────────────────┘
```

### watchOS–iOS coherence

- Shared felt-pad red as the "warm accent" signature on both platforms (capsule on watch SIDE A tag = stripe on iOS section headers)
- Shared LCD green for timer + numerics
- Drawn-shell stays an iOS-only flourish; watch never had room for it anyway

### Implementation approach

1. **Move `MixtapeCassetteScene` invocation OUT of `themedScreenBackground()`** — that's the leak source. Make `ThemedScreenBackground` return `MixtapeCalmBackground` (solid navy + faint scanlines, ~20 LOC) for Mixtape.
2. **Add `.mixtapeTimerScreenBackground()` view modifier** called explicitly by `iPhoneWorkoutTimerView` AND `WorkoutSummaryView` only. Internally it renders `MixtapeCassetteScene(showJCard: true, showHubs: false)`. Two screens, one modifier.
3. **Delete the static reels** from `MixtapeCassetteScene` permanently — the hero owns reels. Remove `MixtapeLayoutConstants` since the hero positions its own reels in its own coordinate space.
4. **Add `MixtapeFeltPadAccent` view** (~20 LOC) — a 4pt × 24pt red capsule reusable as a section-header leading stripe, list-row selection indicator, summary medal accent. This becomes the signature shape on neutral surfaces.
5. **No new image assets.** No paper texture, no Walkman photo. Lowest-risk path.

### Difficulty: **Easy**

### Key risks

- **Doesn't address the user's core question.** They asked "why generated, not real photo?" — this concept's answer is "because we already built the generated one and it's pretty good if we fix the leaks." That may not satisfy them.
- **Still leaves the theme feeling generic vs. iconic.** A drawn cassette is a drawn cassette; it doesn't become a Walkman by fixing layering bugs.
- **Smallest delta = smallest payoff.** Quick to ship, but doesn't move the needle on "subscription-worthy theme" the way Concept A would.
- **The drawn shell is at risk of feeling dated** as competitor apps lean into authentic photography (Athlytic, Bevel, Rainbow Player). We'd be playing defense rather than offense.

---

## Comparison table

| Dimension | A. Real Walkman Wallpaper | B. J-Card Travel Wallet | C. Hybrid Hardware Window |
|---|---|---|---|
| Wow factor | High | High (if font lands) | Low |
| Effort | Medium (~3 days) | Medium-Hard (~4 days) | Easy (~1 day) |
| Asset weight | +600 KB (photo) | +150 KB (paper) + 40 KB (font) | 0 |
| Fixes leak bug | Yes | Yes | Yes |
| Answers user's question | Directly | Sideways (paper not device) | No |
| Risk | Asset sourcing | Font choice + tracklist UX | Doesn't excite |
| Reversibility | Easy (swap image) | Hard (whole layout) | Trivial |
| watchOS change | None | None | None |
| Unique vs other fitness apps | Very (no one does this) | Very (no one does this) | Low |
| Cardiac-rehab safety | OK with darkening overlay | OK | OK |

---

## Recommendation

**Implement Concept A (Real Walkman Wallpaper) as the v1 redesign,** with the asset-sourcing step as a hard gate before committing engineering effort.

**Why A over B or C:**

1. It directly answers the user's question — they asked for the Rainbow Player approach and Concept A is exactly that. B and C answer different questions.
2. It is *less risky than B*. B requires a font choice that could go wrong; A requires a photo choice with clear pass/fail criteria the user can sign off on in 30 minutes.
3. The hero refactor it requires (–400 LOC, +150 LOC) also delivers Concept C's leak fix as a side effect. We get the best of both for one round of work.
4. The watch design we landed on this month (full-screen LCD, no reels, zone-via-colour) already follows the philosophy "commit to the screen, the chrome carries the identity." Concept A applies that same philosophy to iOS — chrome (photo) carries identity, screen (overlay) carries data. That's a coherent product story.

**Concrete next steps to unblock implementation:**

1. **Asset gate.** Spend an hour searching Wikimedia Commons / Internet Archive / Pexels (CC0) for top-down portable cassette player photos. Pick 3 candidates. User picks one or rejects all. If all rejected, fall back to Concept C as the cheap-and-safe path.
2. **Hue decision.** Decide whether the new player photo retunes the Mixtape palette (yellow becomes the accent) or whether we hue-shift to existing navy. Recommend: retune. The current navy was a Canvas-era compromise; a real yellow Walkman is more iconic.
3. **Spin out `ios.md` and `watch.md` hand-off specs** once the asset is approved. The watch spec is essentially "preserve current state, document the shared palette tokens." The iOS spec is the meaty one — screen-hole rect, overlay layout, calm-background fallback for non-timer screens, dashboard CTA card variant.

**If the user rejects Concept A's asset:** skip directly to Concept C as the minimum viable fix, ship it in a day, and revisit photo-based work later when a better asset surfaces.
