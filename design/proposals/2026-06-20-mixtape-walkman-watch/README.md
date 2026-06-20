# Mixtape watch timer → "Walkman deck LCD" redesign

**Date:** 2026-06-20
**Surface:** watchOS active-workout timer face, Mixtape theme only
**Replaces:** `MixtapeWatchDeck` in `ShuttlX Watch App/Theme/Themes/Decorations/MixtapeTimerHero.swift` (line 113)
**Spec for engineer:** [`watch.md`](./watch.md)
**Mockups:** `assets/freerun-41mm.svg`, `assets/freerun-45mm.svg`, `assets/interval-41mm.svg`, `assets/interval-45mm.svg`

---

## Direction in one line

Stop drawing the *cassette*. Draw the *deck that plays it.* One amber/green LCD
panel, one VU bar that breathes with the runner's effort, one transport glyph that
says PLAY/PAUSE — the cassette is implied by a thin top reel band + a SIDE A tag,
not by two spinning asterisks bolted to the screen edges.

## The 5 problems this fixes (from the on-wrist photo)

| # | Old problem | Fix |
|---|---|---|
| 1 | **Reels read as snowflake buttons** — 14–26pt asterisks pinned to the far left/right edges, no cassette body around them. | Reels demoted to a single 16pt twin-reel-with-tape **header band** (one cohesive cassette cue, centered, framed). They never flank the metrics or steal column width. |
| 2 | **Four fighting visual languages** — green LCD + red BPM rule + cream SIDE-A pill + blue reel cogs. | **One LCD material.** Everything that's "data" lives on a single recessed amber/green LCD well. HR keeps its zone color (safety-critical) but sits *inside* the same LCD, not on a separate red rule. SIDE A becomes a small engraved tag on the deck body, not a cream pill competing with the LCD. |
| 3 | **"DIST" clipped to "IST 1.92"** at the left edge. | Labels live in a fixed-width gutter with guaranteed padding; values right-align in their own column. Nothing touches a screen edge — 6pt minimum inset everywhere. |
| 4 | **Dead vertical space** between timer window and HR row. | A **VU meter bar** fills that band and earns its keep: it's the cassette-deck signature element AND a live HR/effort readout. No wasted pixels. |
| 5 | **Cheap, un-skeuomorphic feel** — tiny ornaments that don't register at watch size. | A coherent matte-deck body (subtle vertical gradient), a confident type hierarchy, an engraved LCD bezel, a real transport glyph. Premium hi-fi, one accent, nothing scattered. |

## At-a-glance layout (Free-Run)

```
┌─────────────────────────────────┐  matte deck body (charcoal gradient)
│ ◷◯══tape══◯  SIDE A      ▶       │  header band: twin 16pt reels + SIDE A tag + transport glyph
│ ┌─────────────────────────────┐ │
│ │  ⌜ELAPSED⌟              ◷    │ │  ← LCD WELL (one recessed amber/green panel)
│ │      2 0 : 1 2              │ │  ← HERO, 7-seg-styled mono, ~0.20·H
│ │  ▮▮▮▮▮▮▮▮▯▯▯▯▯▯  HR Z2       │ │  ← VU BAR (12 seg) + HR readout, zone-colored
│ │   142 BPM                   │ │  ← BPM big, inside the LCD
│ │  DIST  1.92 km   PACE 10'10"│ │  ← two-up, gutter-aligned, no clipping
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

In **Interval mode** the hero becomes the step countdown, `ELAPSED` becomes
`WARMUP 2/8` in the step-type color, and the VU bar + HR + DIST/PACE are unchanged.

## Real references borrowed

- **Nakamichi 670ZX / Cassette Deck 1** — peak-reading VU meter, **-40 dB → +7 dB**,
  segmented bar with a hot zone at the top. We borrow the **segmented bar reading
  left→cold to right→hot** and the **amber phosphor** color
  ([Nakamichi 670ZX, WorthPoint](https://www.worthpoint.com/worthopedia/nakamichi-670zx-discrete-three-head-116802114);
  [Tapeheads — digital displays](https://www.tapeheads.net/threads/cassette-decks-with-the-best-digital-displays.22127/)).
  Amber displays were the Nakamichi/JVC/Pioneer/Yamaha house style — that's our LCD tint vocabulary.
- **Sony Walkman WM-EX90** — built-in **LCD digital counter + SIDE A/B** indicator on
  a small recessed display. We borrow the **engraved-LCD counter look** for the hero
  window and the **SIDE A tag** as a tiny deck label, not a loud pill
  ([Walkman history](https://obsoletesony.substack.com/p/history-of-the-walkman-1979-2004)).
- **Transport iconography** — the universal cassette-deck **▶ / ‖** glyph as the
  running-state cue (play while running, pause-bars when paused), the single most
  recognizable "this is a tape deck" signal after the reels.

## Why this is sellable

It reads as a *piece of hi-fi gear* at arm's length: one glowing panel, a meter that
moves with your heart, a play light. Every pixel is either data or the ONE cassette
cue. That's the difference between "looks cheap" and "looks like a product."
