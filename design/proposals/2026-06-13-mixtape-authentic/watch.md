# Mixtape Authentic — watchOS hand-off spec

Reader: `swiftui-watchos-specialist`. Same cassette identity as iOS, **compressed to a ~180pt
height budget on 41mm** (per `.claude/rules/watchos.md`). SwiftUI only, no new deps.

Read first: `ShuttlX Watch App/Theme/Themes/Decorations/MixtapeTimerHero.swift` (the current
single-reel overlay — reuse its `reelCanvas`), `ShuttlX Watch App/Views/TrainingView.swift`
(`fullWorkoutDisplayTab` chrome injection pattern + controls page), the watch
`mixtapeBackground()` in `ShuttlX Watch App/Theme/AppTheme.swift`.

Hard constraints honored:
- **No idle animation outside an active workout** — reels static unless `isRunning`.
- **Static Canvas where possible** — only the reels animate; shell/screws are drawn once.
- **HR + time glanceability is paramount** — cassette chrome never overlaps the timer/HR text.
- Transport keys ≥44pt touch target.

---

## 1. Compressed cassette identity on 41mm

We keep the *shell silhouette* (so it reads as a cassette, not a tint) but shrink to essentials:
a thin shell frame with 2 corner screws, **one** hub window with a live reel (the metaphor carrier),
a tiny J-card strip behind the workout name, and the transport keys on the dedicated controls page.
The base `TrainingView` keeps drawing the monospaced timer + HR row — we do NOT double-draw them.

```
ACTIVE (full workout tab, 41mm ~180pt budget):
┌────────────────────────────┐  ← shell frame (shellTop→shellBottom), 1pt border
│●  ✎ Intervals      A ●     │  ← screw · slanted name on cream strip · SIDE A · screw   (28pt)
│  ╭────╮                     │
│  │◎▦◎│   04:18              │  ← ONE hub window + reel (52pt) · watchTimerDisplay LCD   (56pt)
│  ╰────╯   STEP 3/8          │
│   ▮▮▮▮▮▯▯  148 BPM          │  ← HR VU mini + bpm (existing row)                         (40pt)
│   ──●──  3:12/km            │  ← pace needle mini                                        (28pt)
└────────────────────────────┘   (~152pt + spacing → fits)
```

Controls page (separate tab — keep current watch pattern, swap buttons for Walkman keys):

```
┌────────────────────────────┐
│   ┌──────┐    ┌──────┐      │
│   │ ▶    │    │  ■   │      │  ← PLAY/PAUSE (green/amber latch) + STOP (red)  each ≥44pt
│   │ PLAY │    │ STOP │      │
│   └──────┘    └──────┘      │
│   ◀◀ Cancel    ▶▶ Skip      │  ← secondary (interval only) as smaller keys
└────────────────────────────┘
```

---

## 2. States

- **IDLE / not started:** reel static, oxide full-left, name strip shows program, no spin. (Rule:
  no idle animation — enforce via `TimelineView(paused: !isRunning)`.)
- **ACTIVE:** reel spins (reuse existing `spinDegrees` from `elapsedTime`, 1 rev / 4s), PLAY key
  latched green-down on controls page.
- **PAUSED:** reel halts (existing pause-clean behavior, no snap-back), name strip + bpm tint to
  amber, a `PAUSED` glyph appears next to the timer (primary cue), PLAY pops up / PAUSE depressed.
- **COMPLETE:** summary screen header reads `SIDE A COMPLETE`, reel parked oxide-full-right (reuse
  existing summary view; just change the header string + a static parked reel).
- **EMPTY:** no template → start screen shows an empty hub window outline + "Insert a workout".

```
PAUSED:                         COMPLETE (summary header):
┌──────────────────┐            ┌──────────────────┐
│ ╭───╮ ⏸ 04:18    │            │  SIDE A COMPLETE │
│ │ ◦ │ PAUSED amber│            │   28:40  ●●●●     │
│ ╰───╯ 148 BPM     │            │   ╭───╮ wound→    │
└──────────────────┘            └──────────────────┘
```

---

## 3. Component specs (watch geometry)

- **Shell frame:** the existing `mixtapeBackground` stays as the fill; ADD a `RoundedRectangle(12)
  .strokeBorder` `shellTop`→`shellBottom` inset 2pt to imply the shell edge, plus 2 corner screws
  (`Circle(d: 8)`, top-left + top-right only, to save space) drawn once (static).
- **Hub window + reel:** reuse the watch hero's `reelStack`/`reelCanvas` verbatim. Keep
  `reelDiameter: 52` (was 56; trim 4pt for the shell border). Pin to upper-left as today, but place
  it inside a `Circle().fill(hubWindowBezel)` window so it reads as a cut-out, not a floating disc.
  Keep `.allowsHitTesting(false)`.
- **J-card name strip:** behind the workout name row drawn by `TrainingView`. A `Capsule`/
  `RoundedRectangle(4)` `labelPaper.opacity(0.9)`, name in `ShuttlXFont.watchTemplateTitle`
  `labelInk`, `.italic()`, `.rotationEffect(.degrees(-3))`, `lineLimit(1)`,
  `minimumScaleFactor(0.6)`. **Do not** rotate or restyle the timer/BPM — only the name.
- **HR VU + pace mini:** keep the existing watch rows; no change required for the metaphor (the
  reel + name strip carry it).
- **Transport keys (controls page):** use `ThemedTransportButtonStyle` (same struct as iOS, mirrored
  file). Watch keycap min 48×48 to clear the 44pt rule comfortably; travel 2pt (smaller than iOS 3pt
  for the smaller screen); haptic `.impact(weight: .medium)` on watch (heavy feels muddy on the
  Taptic Engine). PLAY uses `theme.colors.running` (green) cap when up, amber when latched-paused.

Palette: identical hex to `ios.md §1`. The watch hero already hard-codes the matching tokens
(`deckBody #1A3060`, `deckBorder #4A6A9A`, `amber #F2A61A`) — reuse those constants.

---

## 4. Performance check (watch)
- Only **one** `Canvas` reel animates, gated by `TimelineView(.animation(minimumInterval: 1/24,
  paused: !isRunning))` — already the pattern in the current overlay. Shell + screws + name strip are
  **static** (drawn once, no TimelineView).
- `reduceDetail = (reduceMotion || isLowPowerModeEnabled)` → reel static, screws omitted, no key
  travel. Same gate as iOS.
- No new timers, no extra `@Published`. Wrist-down: reel halts because `TimelineView` is paused when
  `!isRunning`/paused; `spinDegrees` derives from `elapsedTime` so no snap-back on wake (unchanged
  from today's overlay).
- Budget: 1 animated Canvas at 24fps of ~52pt — well within the watch render budget; equal to the
  current single-reel overlay, so no regression.

---

## 5. Framework reuse note
The `ThemedTransportButtonStyle` + `TransportButtonSpec` + `ThemedScene` types from `ios.md §6` are
**mirrored** into the watch `Theme/` per the dual-target rule. The watch `spec(for: "mixtape")`
differs only in `travel` (2 vs 3) and `haptic` (`.medium` vs `.heavy`) — keep these in the watch
copy's `static spec(for:)`. `MixtapeCassetteScene` on watch is the compressed frame above (no full
shell), exposed via the same protocol so future watch themes follow suit.

---

## Implementation hand-off
- **Files to create:**
  - `ShuttlX Watch App/Theme/Components/ThemedTransportButton.swift` (mirror of iOS, watch travel/haptic values)
  - `ShuttlX Watch App/Theme/Components/ThemedSceneBackground.swift` (compressed `MixtapeCassetteScene` + `ThemedScene`)
- **Files to modify:**
  - `ShuttlX Watch App/Theme/Themes/Decorations/MixtapeTimerHero.swift` — wrap the reel in a `hubWindowBezel` cut-out; trim `reelDiameter` to 52; add IDLE/PAUSED reel-parked states
  - `ShuttlX Watch App/Theme/AppTheme.swift` — `mixtapeBackground()` adds the static shell-frame stroke + 2 corner screws
  - `ShuttlX Watch App/Views/TrainingView.swift` — controls page: replace circular pause/stop with `ThemedTransportButtonStyle` keys; add the J-card name strip behind the workout-name row; `PAUSED` glyph next to timer
  - the watch summary view — `SIDE A COMPLETE` header + parked reel (find via the completion summary in `TrainingView`/summary screen)
- **Reuse existing:** watch hero `reelStack`/`reelCanvas`/`spinDegrees`; existing HR VU + pace rows; `mixtapeBackground`; `deckBody`/`deckBorder`/`amber` constants; `ShuttlXFont.watch*` tokens; `theme.colors.running`/`ctaPause`/`ctaDestructive`
- **Theme variants verified:** keys route through `spec(for:)`; the 7 other watch themes hit the `default` flat spec → no visual change to them; shell frame only renders for `current.id == "mixtape"`
- **Watch perf check:** 1 animated 24fps Canvas reel (== current), all other chrome static, `TimelineView(paused:)` on idle/pause, `reduceDetail` low-power gate — no new regression vs today
- **Open questions for dev:** below

## Open questions for dev
1. On 41mm with Largest Dynamic Type, does the name strip + reel + timer + HR + pace still fit the
   ~180pt budget, or should the pace mini row drop to a 2-up `compactMetric` (per the watchos rule's
   free-run note)? Needs a device check.
2. Controls page vs full tab: confirm the current Mixtape watch controls live on the dedicated
   controls page (not the workout tab) so the Walkman keys don't steal glanceable space — I assumed
   yes from the overlay's comment. Verify before moving buttons.
3. Same as iOS Q1: should the static shell-frame know `isRunning` (for the reel) via a ThemeManager
   value, or does the hero overlay own the only live reel and the background stays inert? I lean: the
   overlay owns the live reel; `mixtapeBackground` draws only the static frame.
