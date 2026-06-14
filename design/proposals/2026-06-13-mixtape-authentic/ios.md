# Mixtape Authentic — iOS hand-off spec

Reader: `senior-ios-developer`. SwiftUI only, no new deps. All hex below are the **theme
definition** (the cassette chrome IS the theme), so explicit `Color(red:green:blue:)` is allowed for
chrome; **text/metrics must stay on `ShuttlXColor`/`ShuttlXFont`.**

Read first: `ShuttlX/Theme/Themes/MixtapeTimerHero.swift` (reuse `drawReel()`),
`ShuttlX/Theme/AppTheme.swift` (`mixtapeBackground()`), `ShuttlX/Theme/ThemeModifiers.swift`,
`ShuttlX/Views/Workout/iPhoneWorkoutTimerView.swift` (controller API + `themedTimerBody` dispatch).

---

## 1. Palette (cassette chrome)

| Token | Hex | `Color(r,g,b)` | Use |
|---|---|---|---|
| shellTop | `#26303F` | (0.149, 0.188, 0.247) | shell gradient top |
| shellBottom | `#161E29` | (0.086, 0.118, 0.161) | shell gradient bottom |
| moldLine | white 2.5% | — | horizontal plastic texture |
| screwRim | `#8A93A0` | (0.541, 0.576, 0.627) | screw metal rim |
| screwRecess | `#3A4250` | (0.227, 0.259, 0.314) | screw recess |
| hubWindowBezel | `#0E1420` | (0.055, 0.078, 0.125) | hub window cut-out ring |
| labelPaper | `#EDE7D3` | (0.929, 0.906, 0.827) | J-card cream |
| labelInk | `#1C2330` | (0.110, 0.137, 0.188) | handwritten title ink |
| feltPad | `#B8453A` | (0.722, 0.271, 0.227) | tape-window felt pad |
| keyCapTop | `#C7CCD4` | (0.780, 0.800, 0.831) | transport keycap top |
| keyCapBottom | `#9AA1AC` | (0.604, 0.631, 0.675) | transport keycap bottom |
| keyChannel | `#0E1420` | (0.055, 0.078, 0.125) | key well/channel |
| keyGlyph | `#2A3038` | (0.165, 0.188, 0.220) | embossed glyph |
| lcdGreen | `#39FF14` | (0.22, 1.0, 0.08) | counter (existing token) |
| amberPause | `#F2A61A` | (0.95, 0.65, 0.10) | paused state (existing `ctaPause`) |
| ledRed | `#FF3333` | (1.0, 0.20, 0.20) | REC dot / stop (existing) |

Tape oxide / reel internals reuse `MixtapeTimerHero.drawReel()` values unchanged.

---

## 2. iOS timer screen — IDLE / ACTIVE / PAUSED / COMPLETE

ASCII mockup (iPhone, active workout). Content sits ON the J-card label area; reels show through hub
windows cut into the shell.

```
┌──────────────────────────────────────────────┐  ← shell, shellTop→shellBottom gradient
│ ●            ▢ write-protect ▢            ● │   ← corner screws (top), tab wells
│  ┌──────────────────────────────────────┐   │
│  │ SIDE A ⟋ ●REC                          │   │  ← J-card label well (labelPaper)
│  │  ✎ Morning Intervals      ⟋3:12 / km    │   │  ← slanted felt-tip title (italic, -3°)
│  │  ─────────────────────────────────────  │   │  ← ruled baseline
│  │              [ 04 : 18 ]                 │   │  ← lcdGreen counter, ShuttlXFont.timerDisplay
│  │              STEP 3 / 8                  │   │
│  └──────────────────────────────────────┘   │
│      ╭───────╮               ╭───────╮       │
│      │ ◎▦▦◎ │  hub windows  │ ◎▦◎◎ │       │  ← reels through circular windows (drawReel)
│      ╰───────╯  supply↓  take-up↑ ╰───────╯  │
│  ┌──────────────────────────────────────┐   │
│  │ HR ▮▮▮▮▮▮▯▯▯▯  148 bpm   ▰felt pad     │   │  ← tape window strip: VU HR + pace needle
│  │ SPD ──────●──────  3:12/km             │   │
│  └──────────────────────────────────────┘   │
│   ┌────┐  ┌────┐  ┌──────────┐  ┌────┐      │
│   │ ◀◀ │  │ ▶▶ │  │  ▶ PLAY  │  │ ■  │      │  ← Walkman transport keys (silver, seated)
│   └────┘  └────┘  └──────────┘  └────┘      │     PLAY latches DOWN while running
│ ●          BASF Type II · 90      brand   ● │  ← corner screws (bottom) + brand strip
└──────────────────────────────────────────────┘
```

State variants:

- **IDLE** (workout chosen, not started): reels static, oxide fully on supply (left full, right
  empty), counter shows `00:00 READY`, PLAY key UP (not latched), bottom strip shows `--/km`,
  `-- bpm`. The cassette looks *loaded but not running*.
- **ACTIVE**: reels spin (24fps), supply shrinks / take-up grows by `progress`, PLAY key **latched
  down** (`isLatched: !controller.isPaused`), HR VU + pace needle live.
- **PAUSED**: reels stop (no snap-back — keep existing accumulated-angle approach), PLAY key pops
  **up**, PAUSE glyph key reads depressed, title ink + counter tint to `amberPause`, a literal
  `PAUSED` chip appears on the label baseline (primary cue, per accessibility stance).
- **COMPLETE**: label re-prints `SIDE A COMPLETE`, reels park with all oxide on take-up (right full),
  a small `▶▶ FLIP TO SIDE B?` hint maps to "start another". Counter freezes at final time.

```
COMPLETE:                          EMPTY (no template / picker has nothing):
┌───── SIDE A COMPLETE ─────┐      ┌──── NO TAPE LOADED ────┐
│  ✎ Morning Intervals      │      │   ╭───╮      ╭───╮      │
│   [ 28 : 40 ]  ●●●● done   │      │   │   │  ∅   │   │      │  ← empty hub windows, no oxide
│   ╭───╮          ╭━━━╮     │      │   ╰───╯      ╰───╯      │
│   │ ◦ │ all wound│███│     │      │  Insert a workout      │
│   ╰───╯  ▶▶ FLIP TO B?     │      │  [ Choose a Tape ▶ ]   │
└───────────────────────────┘      └────────────────────────┘
```

---

## 3. Non-timer screen — template picker as "choose a tape"

The cassette idiom must carry beyond the timer. Template/program selection becomes a **rack of
cassettes**, each a mini J-card.

```
┌──── Choose a Tape ──────────────────────────┐
│  ┌──────────────┐  ┌──────────────┐          │
│  │● SIDE A     ●│  │● SIDE A     ●│          │  ← each card = MixtapeCassetteScene(mini)
│  │ ✎ 5K Builder │  │ ✎ HIIT 4x4   │          │     reels static, oxide full-left
│  │ ╭─╮     ╭─╮  │  │ ╭─╮     ╭─╮  │          │
│  │ ╰─╯ 32m ╰─╯  │  │ ╰─╯ 18m ╰─╯  │          │
│  │● Type II    ●│  │● Type I     ●│          │
│  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐          │
│  │ ✎ Recovery   │  │   + New Tape  │          │  ← "blank tape" affordance for create
│  └──────────────┘  └──────────────┘          │
└──────────────────────────────────────────────┘
```

Implementation: a small `MixtapeCassetteScene(progress: 0, isRunning: false, reduceDetail: true)`
used as the card background inside the existing template grid; title via `ShuttlXFont.cardTitle`
rotated `-3°`. This reuses `.themedCard()` for the `.lcd` style outline so other themes still render
their own card chrome on the same screen.

---

## 4. Component specs (exact geometry)

### 4.1 Shell + screws (`MixtapeCassetteScene`)
- Outer `RoundedRectangle(cornerRadius: 16)`, vertical `LinearGradient(shellTop→shellBottom)`.
- Mold lines: reuse `mixtapeBackground` Canvas loop, `lineSpacing: 8`, `white.opacity(0.025)`.
- Screws: 4 at insets `(20, 20)` from each corner. Each = `Circle(d: 12)` radial gradient
  `screwRim→screwRecess` + a `Path` cross/slot stroke `screwRecess`, `lineWidth: 1.2`; top-left
  specular dot `white.opacity(0.4)`.
- Content safe inset (where label/hero content lives): `EdgeInsets(top: 96, leading: 28,
  bottom: 150, trailing: 28)`.

### 4.2 J-card label well
- `RoundedRectangle(6)` fill `labelPaper`, inner shadow `black.opacity(0.15)` top edge.
- Title: workout name, `ShuttlXFont.cardTitle` (theme already monospaced), `.foregroundStyle(labelInk)`,
  `.italic()`, `.rotationEffect(.degrees(-3))`, `lineLimit(1)`, `minimumScaleFactor(0.65)`.
- Baseline rule: `Rectangle().frame(height: 1).foregroundStyle(labelInk.opacity(0.3))`.
- "SIDE A" box: top-left, monospaced 9pt heavy, 1pt border `labelInk.opacity(0.5)`.
- REC dot: existing pulsing `ledRed` circle from the hero.
- Counter: keep existing `lcdCounter` (lcdGreen, shadow radius 4) — DO NOT restyle; it's the legible
  primary readout.

### 4.3 Hub windows + reels
- Two `Circle(d: 96)` "windows", centers at `0.30w` and `0.70w`, vertically below the label.
- Window = `Circle().fill(hubWindowBezel)` + inner shadow (`.shadow` on an inset stroke) to read as a
  cut-out; clip the reel Canvas inside with `.clipShape(Circle())`.
- Reel content: **reuse `drawReel(ctx:size:isSupply:)` verbatim** from `MixtapeTimerHero`. Keep the
  `reelAngle` accumulation + pause behavior. Wrap in `TimelineView(.animation(minimumInterval:
  1.0/24.0, paused: !isRunning))`.

### 4.4 Tape-window strip (VU + pace)
- Reuse existing `hrVUStrip` and `paceSpeedStrip` from the hero, wrapped in a darker
  `RoundedRectangle(4)` with a `Capsule().fill(feltPad)` accent on the left edge (the felt pad).

### 4.5 Transport keys — see §6 for the `ButtonStyle`. Layout: `HStack(spacing: 10)`:
`◀◀ Cancel` · `▶▶ Skip` (interval only) · `▶ PLAY/PAUSE` (flex width, 56pt tall) · `■ Stop`.
Each fixed key 56×56 (visual), min 44pt hit area. Map to the SAME controller calls the current hero
uses (`cancel`, `skipStep`, `pause/resume`, `finish`).

---

## 5. Reduce Motion / Low Power
- `reduceDetail = (reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled)`.
- When true: reels static (no `TimelineView`), screws drawn without specular, transport travel = 0
  (color/shadow swap only), tape oxide frozen at current `progress`.

---

## 6. Framework structs to add (the reusable part)

### 6.1 `ThemedTransportButtonStyle`
```swift
// Theme/Components/ThemedTransportButton.swift  (NEW — mirror to watch)
struct TransportButtonSpec: Equatable {
    var cornerRadius: CGFloat
    var travel: CGFloat
    var capTop: Color
    var capBottom: Color
    var channel: Color
    var glyph: Color
    var highlight: Color
    var depressLatches: Bool
    var haptic: SensoryFeedback
}

enum TransportRole: Equatable {
    case play, pause, stop, rewind, fastForward, skip
    var sfSymbol: String {
        switch self {
        case .play: "play.fill";  case .pause: "pause.fill";  case .stop: "stop.fill"
        case .rewind: "backward.end.fill"; case .fastForward: "forward.fill"; case .skip: "forward.end.fill"
        }
    }
}

struct ThemedTransportButtonStyle: ButtonStyle {
    let role: TransportRole
    var isLatched: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spec: TransportButtonSpec { Self.spec(for: ThemeManager.shared.current.id) }

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed || (spec.depressLatches && isLatched)
        let travel = reduceMotion ? 0 : (down ? spec.travel : 0)
        return ZStack {
            // channel / well
            RoundedRectangle(cornerRadius: spec.cornerRadius).fill(spec.channel)
            // keycap
            configuration.label
                .foregroundStyle(spec.glyph)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: spec.cornerRadius)
                        .fill(LinearGradient(colors: [spec.capTop, spec.capBottom],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: spec.cornerRadius)
                                .fill(spec.highlight.opacity(down ? 0 : 0.6))
                                .frame(height: 2).padding(.horizontal, 4).padding(.top, 1)
                        }
                )
                .padding(down ? 2 : 0)        // cap recesses into channel
                .offset(y: travel)
                .shadow(color: .black.opacity(down ? 0.15 : 0.45),
                        radius: down ? 1 : 4, y: down ? 1 : 3)
        }
        .contentShape(Rectangle())
        .frame(minWidth: 44, minHeight: 44)
        .sensoryFeedback(spec.haptic, trigger: configuration.isPressed)
    }

    static func spec(for themeID: String) -> TransportButtonSpec {
        switch themeID {
        case "mixtape":
            return .init(cornerRadius: 8, travel: 3,
                capTop: Color(red: 0.780, green: 0.800, blue: 0.831),
                capBottom: Color(red: 0.604, green: 0.631, blue: 0.675),
                channel: Color(red: 0.055, green: 0.078, blue: 0.125),
                glyph: Color(red: 0.165, green: 0.188, blue: 0.220),
                highlight: .white, depressLatches: true, haptic: .impact(weight: .heavy))
        default: // Clean / fallback: flat, no travel
            return .init(cornerRadius: ThemeManager.shared.effects.buttonCornerRadius, travel: 0,
                capTop: ThemeManager.shared.colors.ctaPrimary,
                capBottom: ThemeManager.shared.colors.ctaPrimary,
                channel: .clear, glyph: ThemeManager.shared.colors.iconOnCTA,
                highlight: .clear, depressLatches: false, haptic: .selection)
        }
    }
}
```
Usage replaces the hero's PLAY button:
```swift
Button { controller.isPaused ? controller.resume() : controller.pause() } label: {
    HStack(spacing: 6) {
        Image(systemName: controller.isPaused ? "play.fill" : "pause.fill")
        Text(controller.isPaused ? "PLAY" : "PAUSE").font(ShuttlXFont.microLabel)
    }.frame(maxWidth: .infinity).frame(height: 56)
}
.buttonStyle(ThemedTransportButtonStyle(role: .play, isLatched: !controller.isPaused))
.accessibilityLabel(controller.isPaused ? "Resume workout" : "Pause workout")
.accessibilityHint("Walkman play key")
```

### 6.2 `MixtapeCassetteScene` (the full-bleed scene)
```swift
// Theme/Components/ThemedSceneBackground.swift  (NEW — mirror to watch)
protocol ThemedScene: View { var contentSafeInsets: EdgeInsets { get } }

struct MixtapeCassetteScene: View, ThemedScene {
    var progress: Double = 0
    var isRunning: Bool = false
    var reduceDetail: Bool = false
    var contentSafeInsets: EdgeInsets { .init(top: 96, leading: 28, bottom: 150, trailing: 28) }
    var body: some View { /* shell gradient + mold lines + 4 screws + 2 hub windows + tape window
        + label well; reels reuse drawReel(); see §4 geometry */ }
}
```
Wire into `AppTheme.swift`:
```swift
func mixtapeBackground() -> some View {
    self.background(
        MixtapeCassetteScene(
            progress: ThemeManager.shared.scenProgress,   // see Open Q on plumbing
            isRunning: ThemeManager.shared.sceneIsRunning,
            reduceDetail: ProcessInfo.processInfo.isLowPowerModeEnabled
        ).ignoresSafeArea())
}
```

---

## Implementation hand-off
- **Files to create:**
  - `ShuttlX/Theme/Components/ThemedTransportButton.swift` (`TransportButtonSpec`, `TransportRole`, `ThemedTransportButtonStyle`)
  - `ShuttlX/Theme/Components/ThemedSceneBackground.swift` (`ThemedScene` protocol, `MixtapeCassetteScene`)
- **Files to modify:**
  - `ShuttlX/Theme/AppTheme.swift` — replace `mixtapeBackground()` body to render `MixtapeCassetteScene`
  - `ShuttlX/Theme/Themes/MixtapeTimerHero.swift` — clip reels into the scene's hub windows; replace `transportButton`/PLAY with `ThemedTransportButtonStyle`; add IDLE/COMPLETE/EMPTY label states; add a literal `PAUSED` chip
  - template picker view (find via `WorkoutTemplate` list usage) — add `MixtapeCassetteScene` mini card background behind `.themedCard()`
- **Reuse existing:** `drawReel()` + `reelAngle` + `hrVUStrip` + `paceSpeedStrip` + `lcdCounter` from `MixtapeTimerHero`; `mixtapeBackground` mold-line Canvas; `ShuttlXColor.forHRZone`, `ShuttlXFont.*`, `.themedCard()`, `ctaPause`/`ctaDestructive` tokens
- **Theme variants verified:** spec routes through `ThemedTransportButtonStyle.spec(for:)` so Clean (flat, travel 0) and the other 6 themes still compile via the `default` branch — no regression; only Mixtape changes visually now
- **Open questions for dev:** below

## Open questions for dev
1. **Scene progress plumbing.** `MixtapeCassetteScene` needs `progress` + `isRunning` to drive reel
   liveness from `.themedScreenBackground()` (which has no controller). Options: (a) add two
   lightweight published values on `ThemeManager` set by the active timer view, or (b) keep the
   scene "resting" (progress 0, static) globally and let `MixtapeTimerHero` draw its OWN live reels
   on top inside the hero only. I lean (b) — simpler, no ThemeManager state creep. Dev/architect to
   decide.
2. Should `TransportButtonSpec` live as a real token on `ThemeEffects` (cleaner, but touches the
   `Equatable` impl and all 8 theme files) or stay in the `static spec(for:)` switch (lower blast
   radius now)? I propose the switch for Mixtape, promote to a token when the 2nd theme adopts it.
3. The existing `CassetteHeaderView`/`ReelCounterView` card chrome in `ThemeModifiers.swift` may now
   be redundant once the scene carries the cassette identity — leave for `senior-ios-developer` to
   decide whether to retire or keep for non-workout cards.
