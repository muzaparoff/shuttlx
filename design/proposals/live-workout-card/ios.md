# Proposal 1 — Live Workout Card → "The Deck Card" (iOS hand-off)

Mockup: [`ios-mockup.html`](ios-mockup.html) · Surface: `ShuttlX/Views/Dashboard/LiveWorkoutCard.swift`

---

## 1. Why

`LiveWorkoutCard` is the only hero surface with **no theme dispatch**. Concretely, in the
current file:

| Line | Code | Problem |
|---|---|---|
| 175 | `RoundedRectangle(cornerRadius: 16)` | Hardcoded. Mixtape's is 8 (`effects.cardCornerRadius`) |
| 176 | `.fill((isStale ? Color.yellow : ShuttlXColor.running).opacity(0.08))` | Translucent → the cassette scene shows through; `Color.yellow` is not a token |
| 128 | `Divider()` | Banned by `.claude/rules/design-system.md` |
| 150 | `.fill(Color.primary.opacity(0.06))` | Not a token |
| 144 | `.font(ShuttlXFont.cardTitle)` on a button | Card title font on a control |

Combined with the P0 background collision (§2) this is what reads as "generic dark card with
a label on top".

## 2. P0 dependency — hub-bezel collision (fix first, independently shippable)

`mixtapeBackground()` draws `MixtapeCassetteScene` with `showHubs` defaulting to `true`. Hub
bezels are pinned at:

```swift
hubCenterXFractions = (0.30, 0.70)   // of screen width
hubCenterYFraction  = 0.42           // of screen HEIGHT
hubDiameter         = 96
```

On a 852pt-tall iPhone that is two 96pt circles at y ≈ 358pt, fixed, while Dashboard content
scrolls past them. They land on `LiveWorkoutCard`'s metric/control rows. The timer screen
already opts out via `timerScreenBackground(themeID:)`.

**Recommended fix** — `ShuttlX/Theme/ThemeModifiers.swift`, `mixtapeBackground()`:
pass `showHubs: false`. The shell, screws, J-card well, tape window and brand strip all
remain; only the two floating bezels go. Cards then read as components *mounted on* the
shell rather than holes punched through it.

This is a 1-line change that improves every Mixtape screen and is worth doing whether or not
the rest of this proposal ships.

## 3. Structure — four slots

The card becomes a dispatcher over a fixed skeleton. Same shape in both themes; only
material changes.

```
┌──────────────────────────────────────┐
│ 1 SPINE   SIDE A ● MORNING INTERVALS │  28pt — identity + name + status
│                        0.42 KM/612 ST│
├──────────────────────────────────────┤
│ 2 WELL        ┌──────────────────┐   │  recessed display
│               │     01:14        │   │  52pt hero
│               │  STEP 3/8 [RUN]  │   │  9pt sublabel + step pill
│               └──────────────────┘   │
├──────────────────────────────────────┤
│ 3 STRIP  HR ▉▉▉▉▉▉▊░░░      142 bpm  │  VU + zone numeral
│          SPD ──────┃───────  5:38/km │  needle track + pace
├──────────────────────────────────────┤
│ 4 KEYS   [⏮ REW][ ⏸ PAUSE  ][ ⏹ STOP]│  54pt transport keys
└──────────────────────────────────────┘
```

## 4. Files

### Create

**`ShuttlX/Views/Dashboard/LiveWorkoutCardStyles.swift`** — the two bodies.

```swift
struct MixtapeLiveDeckCard: View {
    @ObservedObject var sharedData: PhoneSyncCoordinator
    let isStale: Bool
    let onPause: () -> Void
    let onStop: () -> Void
}

struct CleanLiveCard: View { /* same init signature */ }
```

Keep **all** controller/sync logic in `LiveWorkoutCard` — theme bodies stay pure-presentation,
matching the rule that no controller logic lives in theme-dispatched views.

### Modify

**`ShuttlX/Views/Dashboard/LiveWorkoutCard.swift`** — becomes the dispatcher. Keep
`TimelineView(.periodic(by: 1.0))`, the staleness computation, and the
`confirmationDialog`; replace `content(isStale:)`'s body with:

```swift
@ViewBuilder
private func content(isStale: Bool) -> some View {
    switch themeManager.current.id {
    case "mixtape": MixtapeLiveDeckCard(sharedData: sharedData, isStale: isStale, …)
    default:        CleanLiveCard(sharedData: sharedData, isStale: isStale, …)
    }
}
```

Add `@Environment(ThemeManager.self) private var themeManager` — required so the card
re-renders on theme switch (the `ShuttlXColor.*` bridge reads `ThemeManager.shared` outside
the tracking graph and will **not** invalidate this view on its own; see
`/observable-theme-patterns`).

**`ShuttlX/Theme/ThemeModifiers.swift`** — `showHubs: false` in `mixtapeBackground()` (§2).

### Reuse — do not rebuild

| Existing | Use for |
|---|---|
| `ThemedTransportButtonStyle(role:isLatched:)` + `TransportRole` | slot 4 keys, verbatim |
| `MixtapeTimerHero.jCardStrip` structure | slot 1 (extract to `JCardSpine`, see below) |
| `MixtapeTimerHero.hrVUStrip` segment loop | slot 3 VU |
| `MixtapeTimerHero.paceSpeedStrip` | slot 3 needle track |
| `ShuttlXColor.forHRZone(_:)` | HR numeral tint |
| `ShuttlXColor.forStepType(_:)` | step pill |
| `FormattingUtils.formatTimer/formatDistance/formatPace` | all values |
| `theme.effects.cardCornerRadius` | card corner — replaces the hardcoded 16 |

### Suggested extraction (optional, reduces net LOC)

Three components are about to exist twice. Extracting them into
`ShuttlX/Theme/Components/` makes this proposal *remove* code:

- `JCardSpine(name:status:trailing:)` ← `jCardStrip` + `CassetteHeaderView`
- `LCDWell<Content>(ghost:)` ← `bigLCDPanel` background + ghost layer
- `SegmentBar(count:level:bands:height:)` ← `hrVUStrip` inner loop (also unblocks Proposal 3)

Coordinate with whoever owns the timer hero — if that is a conflict this sprint, ship the
card with local copies and consolidate after.

## 5. States

| State | Condition | Spine | Well | Keys |
|---|---|---|---|---|
| Recording | default | REC lamp **steady lit**, name in ink | `colors.running`, glow r8 | PAUSE latched |
| Paused | `liveIsPaused` | lamp @28%, amber `PAUSED` chip | all amber `ctaPause` | PLAY raised |
| Signal lost | `> 5s` since `liveMetricsLastUpdated` | misregistration stripes, `NO SIG` chip, `—— DROPOUT ——` | value @42% grey, `LAST KNOWN · TAPE DROPOUT` | all disabled |
| Connecting | live active, no metrics yet | `CUEING…` @50% | ghost `88:88` only, `SPOOLING UP` | disabled |
| Complete | engine complete | `SIDE B` | `COMPLETE` | STOP only |

Note the "connecting" state is currently **undesigned** — today the card renders `00:00`
with no pills, which looks like a stalled app. The ghost `88:88` layer doubles as the
skeleton loader at zero cost.

## 6. Accessibility

- Keep the existing `.accessibilityElement(children: .combine)` + composed label; extend the
  stale label with "tape dropout" wording only in the *visual* layer — the a11y string stays
  plain English ("Watch signal lost. Last known: …"). **Do not** put cassette metaphors in
  VoiceOver output.
- Transport keys need individual labels + hints (copy from the timer hero: "Pause workout" /
  "Play key. Latches down while tape is running.").
- VU bar is decorative → `.accessibilityHidden(true)`; the HR numeral carries
  "142 beats per minute, zone 3".
- Cardiac-safety: the amber paused state must be distinguishable from the green running
  state **without colour** — the latched/raised key position and the `PAUSED` chip both do
  this. Verify with Differentiate Without Colour on.
- Dynamic Type: at AX3+ the strip drops to numerals-only (hide `SegmentBar`) and the key row
  wraps to 2×2. Timer uses `minimumScaleFactor(0.55)` as in the hero.
- Minimum touch target 54pt on keys (> 44pt).

## 7. Motion budget

| Keep | Drop |
|---|---|
| `.contentTransition(.numericText())` on timer/HR/pace | `PulseModifier` (`repeatForever` dot) → replaced by steady REC lamp |
| Segment lit-count `.easeInOut(0.2)` | The 6s `sheenOffset` `repeatForever` loop — **do not** port it to the card |
| Key press 0.15s (in the button style) | — |
| Existing insertion/removal transition in `DashboardView` | — |

Rationale: a real deck's REC lamp is steady while recording. Blinking encodes nothing here
and costs a permanent animation on the home screen.

---

## Implementation hand-off

- **Files to create:** `ShuttlX/Views/Dashboard/LiveWorkoutCardStyles.swift` (`MixtapeLiveDeckCard`, `CleanLiveCard`). Optional: `ShuttlX/Theme/Components/JCardSpine.swift`, `LCDWell.swift`, `SegmentBar.swift`.
- **Files to modify:** `ShuttlX/Views/Dashboard/LiveWorkoutCard.swift` (→ dispatcher, add `@Environment(ThemeManager.self)`); `ShuttlX/Theme/ThemeModifiers.swift` (`showHubs: false` in `mixtapeBackground()`).
- **Reuse existing:** `ThemedTransportButtonStyle` + `TransportRole`; `ShuttlXColor.forHRZone/forStepType`; `FormattingUtils.*`; `theme.effects.cardCornerRadius`; VU/needle/J-card patterns from `MixtapeTimerHero.swift`.
- **Theme variants verified:** **2 themes exist** (Clean, Mixtape) — both fully specified above. The brief's other 5 are deleted from the codebase (see `../README.md` §0.1); the 4-slot skeleton is the extension point if any are revived. New pbxproj entries required — files under `ShuttlX/` are not auto-synchronized.
- **Watch performance check:** N/A — iOS only. No watch payload or `WCSession` change; the card is a pure re-render of existing `liveXxx` published properties.
- **Open questions for dev:**
  1. Ship the `showHubs: false` fix as a separate P0 commit first? It stands alone.
  2. Extract the 3 shared components now, or local-copy and consolidate later? (Touches `MixtapeTimerHero.swift`, which may be owned by another task this sprint.)
  3. Card grows ~210pt → ~246pt. Confirm `StartOnWatchCard` / `PlanProgressCard` still land acceptably below the fold on a 6.1".
  4. Is there a real "connecting" flag, or must it be inferred from `isWorkoutActiveOnWatch && liveMetricsLastUpdated == nil`? The latter works but is implicit.
