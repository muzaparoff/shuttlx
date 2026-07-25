# ShuttlX — De-genericization Design Sprint (2026-07-24)

Author: `product-designer` · Scope: `design/proposals/**` only (no Swift touched)

---

## 0. Two corrections to the brief before anything else

### 0.1 There are **2 themes**, not 7

The brief (and `CLAUDE.md`, and `.claude/rules/design-system.md`) describe 7 themes. The
codebase has **two**:

```
ShuttlX/Theme/Themes/           → CleanTheme.swift, MixtapeTheme.swift
ShuttlX Watch App/Theme/Themes/ → CleanTheme.swift, MixtapeTheme.swift
```

`ThemeEffects.CardStyle` has exactly two cases (`.glass`, `.lcd`), and
`themedScreenBackground()` switches on exactly two ids:

```swift
switch theme.current.id {
case "clean":   self.cleanMeshBackground()
case "mixtape": self.mixtapeBackground()
default:        self.cleanMeshBackground()
}
```

`docs/memory/MEMORY.md` records the July 2026 reduction; the rules files were never updated.
**These proposals are designed for Clean + Mixtape.** Each spec includes a "if a theme is
revived" table so the dispatch pattern stays N-theme-ready, but I am not designing five
themes that do not exist. → routed to `docs-keeper` as an open question.

### 0.2 The full-screen timers are already good — they are not the problem

`ShuttlX/Theme/Themes/MixtapeTimerHero.swift` (730 lines) and
`ShuttlX Watch App/.../MixtapeTimerHero.swift` (`MixtapeWatchDeck`) are genuinely designed
surfaces: J-card spine, LCD well with a ghost `88:88` dead-pixel layer, 10-segment VU,
transport keys, pace needle. That is the quality bar and it is already met.

The "AI-generated" feeling the user is reacting to is coming from **the surfaces that never
got the treatment**, and one specific rendering bug. See §2.

---

## 1. Research — what makes premium fitness apps not feel generic

Sources at the bottom. Five patterns worth stealing, and one worth refusing.

| # | Pattern | What it means here |
|---|---|---|
| 1 | **One loud thing per screen.** Strava is a dark field with a *single* saturated orange accent; hierarchy comes from restraint, not from tinting everything. | ShuttlX currently tints card fills, borders, icons, and values with the same accent. Pick one. |
| 2 | **Data viz is custom, never stock.** Whoop's recovery ring, Garmin's stacked zone bars, Bevel's dot-matrix week strip — none of them look like a charting library default. Stock `Swift Charts` styling is the single loudest "generic" tell. | `WeekSummaryCard`'s 7 grey/green circles are the most generic element on the dashboard. |
| 3 | **Numerals are the typography.** Premium fitness apps invest their type budget in the numerals — tabular, tight tracking, oversized — and keep labels tiny and quiet. | ShuttlX does this well on the timer, and not at all on the dashboard cards, where labels and values are near-equal weight. |
| 4 | **Motion is event-driven, never idle.** Apple Fitness+ and Whoop animate on *state change* (zone crossing, split, goal met) and are otherwise still. Idle loops read as decoration and cost battery. | ShuttlX has an idle 6s sheen loop and a 1s pulse loop. Budget them. |
| 5 | **Empty states are branded, not apologetic.** Waterllama and Gentler Streak treat the empty state as the strongest brand moment because it is the first thing a new user sees. | ShuttlX's dead state is where the theme most conspicuously disappears. |

**The one to refuse:** the search results push "AI-powered personalized adaptive dashboards"
and "confetti bursts". For a product whose primary users include 55+ post-cardiac-event
patients, celebratory motion and shifting layouts are a liability. Layout stability is a
feature. Clean stays the calm baseline.

---

## 2. Diagnosis — where "generic" actually lives in this codebase

I read the four surfaces named in the brief. Ranked by how much they hurt:

### P0 — `mixtapeBackground()` collides with scrolling content

This is the "cassette reels overlapping awkwardly into the button row" in the user's
screenshot, and it is a **rendering bug, not a taste problem**.

`themedScreenBackground()` → `mixtapeBackground()` draws a full-bleed `MixtapeCassetteScene`
with `showHubs: true`. The hub bezels are positioned at fixed fractions of the *screen*:

```swift
// ThemedSceneBackground.swift
static let hubCenterXFractions: (CGFloat, CGFloat) = (0.30, 0.70)
static let hubCenterYFraction: CGFloat = 0.42
static let hubDiameter: CGFloat = 96
```

y = 42% of screen height, on an iPhone 15 (~852pt) ≈ **358pt from the top** — which on the
Dashboard lands squarely on `LiveWorkoutCard`'s metric pills / control row. The card sits in
a `ScrollView`; the bezels do not scroll. So two 96pt circles sit *behind arbitrary content*
at all times, and the relationship changes as you scroll.

The timer screen already knows about this and opts out (`showHubs: false` via
`timerScreenBackground`). Nothing else does.

**Fix direction (all three proposals depend on it):** cards on scrolling surfaces must be
**opaque faceplates**, and `mixtapeBackground()` should pass `showHubs: false` for scrolling
screens. Chrome must never sit behind data — that is the anti-goal in the design rules,
currently violated by the theme's own background.

### P1 — `LiveWorkoutCard.swift` has zero theme dispatch

Every other hero surface dispatches on `themeManager.current.id`. This one does not. It is
hardcoded:

```swift
RoundedRectangle(cornerRadius: 16)
    .fill((isStale ? Color.yellow : ShuttlXColor.running).opacity(0.08))
```

Hardcoded radius 16 (Mixtape's is 8), hardcoded `Color.yellow`, `Color.primary.opacity(0.06)`
button fills, `Divider()` (banned by the design rules), and `.font(ShuttlXFont.cardTitle)` on
buttons. In Mixtape this renders as *a green-tinted iOS card floating on a cassette*. It is
the single most generic view in the app — and it is on the home screen during the moment of
highest engagement.

### P1 — `WeekSummaryCard` is the generic data-viz tell

7 × `Circle().fill(sessionCount > 0 ? running : surface)`. This is the exact "charting
library default" failure from research pattern #2. Meanwhile the app already contains a
**10-segment VU bar (iOS)** and a **12-segment VU meter (watch)** — a far more distinctive
component that is already written, already themed, and currently used on exactly one screen.

### P2 — watch timer for Clean shows three progress indicators at once

`fullWorkoutDisplayTab` in interval mode simultaneously renders `OverallProgressStrip` (3pt,
top), the countdown hero's own capsule (3pt), and `IntervalStepWash` — three encodings of
"how far along am I", on a 176×215pt screen with a 5-element budget. Also the fixed
`labelWidth = h * 0.20` label column burns ~20% of the width on the words "DIST"/"PACE".

Mixtape's watch deck (`MixtapeWatchDeck`) already solved this. Clean did not get the pass.

---

## 3. The three proposals

| # | Folder | Surface | Core move |
|---|---|---|---|
| 1 | [`live-workout-card/`](live-workout-card/) | iOS Dashboard live card | Card becomes an opaque **deck faceplate** with real transport keys — reuses `ThemedTransportButtonStyle` |
| 2 | [`watch-timer/`](watch-timer/) | watchOS timer, **Clean** theme | Kill the label column + collapse 3 progress indicators into **one step-tick rail** |
| 3 | [`dashboard/`](dashboard/) | iOS Dashboard idle state | Promote the VU segment bar to a shared component; week strip + empty states use it |

Each folder has an HTML mockup (before/after, annotated) and a hand-off `.md`.

### The connecting idea

All three follow one rule, which is the thing that separates this app from a template:

> **A themed surface must own its own background.**

Today ShuttlX themes *tint* surfaces (accent fill at 8% opacity, accent border at 30%) and
lets a decorative scene show through from behind. That is what "a label on top of a generic
dark card" means mechanically. The timer heroes don't do this — they build opaque wells
(`Color(red: 0.01, green: 0.06, blue: 0.01)` LCD glass) and draw on them. Extending that one
rule to the card surfaces gets ~80% of the perceived quality jump, and it is cheap.

### Component consolidation this sprint proposes

Three things already exist twice and should be extracted once — this is net **less** code:

| New shared component | Replaces | Used by |
|---|---|---|
| `SegmentBar` (parametric, N segments, colour bands) | `hrVUStrip` inner `ForEach(0..<10)` (iOS hero), `MixtapeVUMeter` (watch) | live card, week strip, watch HR |
| `LCDWell` (opaque well + ghost-digit layer + border) | inline `bigLCDPanel` background, `MixtapeWatchDeck` `lcdWell` | live card, both timers |
| `JCardSpine` (cream strip, SIDE A box, REC dot) | `jCardStrip` (iOS hero), `nowPlayingRow` (watch deck), `CassetteHeaderView` | live card, last-workout card, both timers |

---

## 4. Motion budget (applies to all three)

| Allowed | Trigger | Cost |
|---|---|---|
| Numeral roll | `.contentTransition(.numericText())` on value change | free |
| Segment lights | HR tick, `.easeOut(0.5)` on lit-count change | event-driven |
| Step-tick fill | interval boundary, 0.3s | 1× per step |
| Transport key latch | tap, 0.15s | 1× per tap |

| Banned | Why |
|---|---|
| Idle sheen loop (`repeatForever`, 6s) — currently in `vuAndPaceStrips` | Runs forever on an active-workout screen; the design rules already ban idle animation |
| Pulsing dot (`PulseModifier`, `repeatForever`) | Replaced by the REC lamp, which is *static-lit* while recording — a real deck's REC lamp does not blink |
| Any watch idle animation | battery |

Both banned loops already correctly honour `accessibilityReduceMotion`; the proposal is to
drop them for everyone, since neither encodes information.

---

## 5. Open questions for the lead

1. **Theme count** — confirm 2 is intentional and correct, then `docs-keeper` should fix
   `CLAUDE.md` + `.claude/rules/design-system.md` (both still claim 7/8 and list signature
   shapes for 5 deleted themes).
2. **P0 hub collision** — should this be split out as a bugfix task ahead of the redesign?
   It is a one-line change (`showHubs: false` in `mixtapeBackground()`) and improves every
   screen immediately, independent of whether these proposals ship.
3. Are the three shared components (§3) in scope this sprint, or should each proposal ship
   self-contained and consolidate later?

---

## Sources

- [Fitness App UI/UX Design 2026 — Fireart](https://fireart.studio/blog/user-interface-design-for-a-fitness-app/) — colour/motion as emotional register; Strava dark + single accent
- [Fitness App UI Design: Key Principles — Stormotion](https://stormotion.io/blog/fitness-app-ux/) — hierarchy for at-a-glance stats, progress visualization
- [10 Best Fitness App Designs — DesignRush](https://www.designrush.com/best-designs/apps/trends/fitness-app-design-examples) — custom data-viz as differentiator, micro-interactions
- [Workout — watchOS Human Interface Guidelines, Apple](https://developers.apple.com/design/human-interface-guidelines/watchos/interaction/workout/) — "recognize an active session at a glance"; **"you can further distinguish the metrics screen by using a unique layout"** (direct support for per-theme watch faces)
- [Health & Fitness patterns — Mobbin](https://mobbin.com/explore/mobile/app-categories/health-fitness) — current card/empty-state conventions
- [Apple Watch vs Garmin — BikeLab](https://www.bikelabhq.com/articles/apple-watch-vs-garmin-why-i-switched-to-garmin-and-dont-regret-it) — granular metric density expectations from serious users
