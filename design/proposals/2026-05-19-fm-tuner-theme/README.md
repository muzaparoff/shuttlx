# FM Tuner Theme — Research & Rationale

**Status:** Proposed (2026-05-19)
**Owner:** product-designer
**Implementers:** senior-ios-developer (iOS), swiftui-watchos-specialist (watchOS)

## Inspiration

The 8th theme draws from the **insideGadgets Orange FM DIY board** — a Game Boy Color-era FM radio receiver shield. The visual language is unmistakable to anyone who grew up around 8-bit hardware:

- A monochrome cyan/teal LCD on a deep navy substrate
- Chunky pixel-rendered numerals as the hero element (the station frequency)
- A vertical bar VU meter pinned to one edge of the screen
- Antenna/signal SF Symbol-style glyphs in the chrome
- A bordered footer "info box" with status text
- Everything monospaced, heavyweight, no anti-aliasing

This is the **anti-Clean**: where Clean uses MeshGradient softness and SF Pro variable weight, FM Tuner is rigid, pixel-perfect, and unapologetically retro-functional. It also reads as **clinical** at a glance — the cyan-on-navy is the same palette as medical monitor displays, which serves the cardiac-rehab user base well.

## Why this theme earns its slot

| Theme | Vibe | When user picks it |
|-------|------|-------------------|
| Clean | Modern Apple | Default; doesn't want a "look" |
| Synthwave | 80s neon | Wants something fun |
| Mixtape | Sony Walkman | Nostalgia, music-tape era |
| Arcade | 80s coin-op | Loud, gamified |
| Classic Radio | 50s tabletop radio | Warm, mature |
| VU Meter | Hi-fi receiver | Analog meters, audiophile |
| Neovim | Code editor | Developer flex |
| **FM Tuner** | **DIY radio kit, medical monitor** | **Wants clinical-looking, hardware-tinkerer aesthetic** |

FM Tuner is the **only** theme where the dominant accent is cyan/teal. Every other theme leans warm (amber, orange, brown, pink) or cool-but-saturated (Synthwave magenta, Neovim olive). This fills a real palette gap.

## Reference palette (extracted from the Orange FM board)

```
Deep navy LCD body:    #021018
Surface (panel):       #062029
Border (PCB silk):     #0A4B5C
Bright cyan (lit):     #7CD8FF
Dim cyan (unlit):      #0E6580
Walking/rest cyan:     #3A8FA8
Danger red (only):     #FF6B6B
```

The discipline is: **everything is cyan except the destructive CTA**. This makes stop/danger genuinely jump off the screen, which is exactly what we want for a cardiac-rehab population that may be panicking mid-workout.

## Cardiac-rehab considerations

This palette is unusually friendly to the 55+ user:

1. **High contrast at all sizes.** `#7CD8FF` on `#021018` is ~12.5:1 — well above WCAG AAA (7:1).
2. **No color hierarchy required.** Because the whole UI is one hue, the user does not need to decode "what does orange mean vs red mean." Brightness alone signals intensity.
3. **The single red CTA is unambiguous.** Stop is red. Nothing else is red. There is no second-guessing.
4. **Pixel-heavy monospaced digits** are easier to read at a glance for users with mild macular degeneration — letterforms don't ligature or visually blend.

## Mood references

- insideGadgets Orange FM PCB (the primary reference)
- 1980s tabletop FM stereo tuners (Pioneer TX-9500, Sansui TU-X1)
- Hospital pulse-oximeter displays (cyan-on-black numerics)
- Game Boy Color FM radio shield homebrew

## Open design questions deferred to implementation

- Should the VU bar appear on the home screen too, or only on workout/recovery? (Recommendation: workout/recovery only, to keep home calm.)
- Should the "DATA SYNC ◀ 3 ▶" header pill use a real sync counter, or stay decorative? (Recommendation: decorative for v1, wire up to `SharedDataManager.pendingSyncCount` in a future pass.)
- On Apple Watch the VU column may be too wide at 41mm. Spec uses 3px bars and 1px gaps on watchOS instead of 4/2.

## Hand-off

- `ios.md` — iOS implementation spec (read by senior-ios-developer)
- `watch.md` — watchOS implementation spec (read by swiftui-watchos-specialist)
- `assets/ascii-mockups.md` — all 9 ASCII mockups in one file
