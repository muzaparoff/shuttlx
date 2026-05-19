# FM Tuner Theme — iOS Implementation Spec

**Target:** iOS 18.0+
**Owner:** senior-ios-developer
**Files mirrored on watchOS:** see `watch.md`

## 0. Read these first

- `design/proposals/2026-05-19-fm-tuner-theme/README.md` — research & rationale
- `design/proposals/2026-05-19-fm-tuner-theme/assets/ascii-mockups.md` — all 9 mockups
- `ShuttlX/Theme/Themes/VUMeterTheme.swift` — closest existing pattern (monospaced, chrome-heavy)
- `ShuttlX/Theme/ThemeModifiers.swift` — where chrome header/footer overlays live

## 1. ThemeColors token table (all 40 tokens)

```swift
ThemeColors(
    // Background & surfaces
    background:        Color(red: 0.008, green: 0.063, blue: 0.094),  // #021018 deep navy LCD
    surface:           Color(red: 0.024, green: 0.125, blue: 0.161),  // #062029 panel
    surfaceBorder:     Color(red: 0.039, green: 0.294, blue: 0.361),  // #0A4B5C PCB silk

    // Activity (workout color coding) — all cyan-family
    running:           Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF bright cyan
    walking:           Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8 mid cyan
    heartRate:         Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF bright cyan
    steps:             Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8 mid cyan
    calories:          Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF bright cyan
    stationary:        Color(red: 0.055, green: 0.396, blue: 0.502),  // #0E6580 dim cyan

    // Sport — variation by brightness only
    cycling:           Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF
    swimming:          Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8
    hiking:            Color(red: 0.055, green: 0.396, blue: 0.502),  // #0E6580
    elliptical:        Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF
    crossTraining:     Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8

    // CTA
    ctaPrimary:        Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF bright cyan
    ctaDestructive:    Color(red: 1.000, green: 0.420, blue: 0.420),  // #FF6B6B (the ONLY non-cyan)
    ctaWarning:        Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF (no separate warning color — use blink)
    ctaPause:          Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF
    iconOnCTA:         Color(red: 0.008, green: 0.063, blue: 0.094),  // #021018 (background — for icons on filled CTAs)

    // HR Zones (1-5) — step from dim → bright as intensity climbs
    hrZone1:           Color(red: 0.055, green: 0.396, blue: 0.502),  // #0E6580 dim (zone 1: easy)
    hrZone2:           Color(red: 0.137, green: 0.490, blue: 0.580),  // #237CA5 (interpolated)
    hrZone3:           Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8 mid
    hrZone4:           Color(red: 0.345, green: 0.694, blue: 0.831),  // #58B1D4 (interpolated)
    hrZone5:           Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF bright (zone 5: max)

    // Interval steps
    stepWork:          Color(red: 0.486, green: 0.847, blue: 1.000),  // bright cyan
    stepRest:          Color(red: 0.227, green: 0.561, blue: 0.659),  // mid cyan
    stepWarmup:        Color(red: 0.345, green: 0.694, blue: 0.831),  // interp
    stepCooldown:      Color(red: 0.137, green: 0.490, blue: 0.580),  // interp dim

    // Semantic
    pace:              Color(red: 0.486, green: 0.847, blue: 1.000),  // bright
    positive:          Color(red: 0.486, green: 0.847, blue: 1.000),  // bright (no green in this theme)
    negative:          Color(red: 1.000, green: 0.420, blue: 0.420),  // #FF6B6B red

    // Recovery
    recoveryFresh:     Color(red: 0.486, green: 0.847, blue: 1.000),  // bright
    recoveryNormal:    Color(red: 0.345, green: 0.694, blue: 0.831),
    recoveryFatigued:  Color(red: 0.227, green: 0.561, blue: 0.659),
    recoveryOverreaching: Color(red: 1.000, green: 0.420, blue: 0.420),  // red

    // Pace zones
    paceInterval:      Color(red: 0.486, green: 0.847, blue: 1.000),  // bright
    paceThreshold:     Color(red: 0.345, green: 0.694, blue: 0.831),
    paceTempo:         Color(red: 0.227, green: 0.561, blue: 0.659),
    paceModerate:      Color(red: 0.137, green: 0.490, blue: 0.580),
    paceEasy:          Color(red: 0.055, green: 0.396, blue: 0.502),  // dim

    // Text
    textPrimary:       Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF (12.5:1 on #021018)
    textSecondary:     Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8 (4.8:1 — meets AA)

    // Card backgrounds
    cardBackground:    Color(red: 0.024, green: 0.125, blue: 0.161),  // #062029

    // Watch surfaces (slightly darker for OLED)
    watchCardBackground:   Color(red: 0.016, green: 0.094, blue: 0.125),  // #04181F
    watchButtonBackground: Color(red: 0.039, green: 0.196, blue: 0.251)   // #0A3240
)
```

### Contrast verification

| Pair | Ratio | Standard |
|------|-------|----------|
| `textPrimary` `#7CD8FF` on `background` `#021018` | ~12.5:1 | AAA |
| `textSecondary` `#3A8FA8` on `background` `#021018` | ~4.8:1 | AA |
| `ctaDestructive` `#FF6B6B` on `background` `#021018` | ~5.6:1 | AA |
| `textPrimary` on `surface` `#062029` | ~11.4:1 | AAA |

## 2. ThemeFonts spec (all tokens)

Everything `.monospaced` `.heavy`. iOS sizes:

```swift
ThemeFonts(
    // Shared — iOS sizes here, watch overrides in watch.md
    timerDisplay:        .system(size: 56, weight: .heavy, design: .monospaced),
    metricLarge:         .system(size: 44, weight: .heavy, design: .monospaced),
    metricMedium:        .system(size: 28, weight: .heavy, design: .monospaced),
    metricSmall:         .system(size: 16, weight: .bold,  design: .monospaced),
    cardTitle:           .system(size: 16, weight: .heavy, design: .monospaced),
    cardSubtitle:        .system(size: 12, weight: .bold,  design: .monospaced),
    cardCaption:         .system(size: 10, weight: .bold,  design: .monospaced),
    sectionHeader:       .system(size: 13, weight: .heavy, design: .monospaced),

    // iOS-specific
    heroIcon:            .system(size: 48, weight: .heavy),
    onboardingIcon:      .system(size: 72, weight: .heavy),
    prValue:             .system(size: 22, weight: .heavy, design: .monospaced),
    microLabel:          .system(size: 9,  weight: .bold,  design: .monospaced),
    debugMono:           .system(size: 10, weight: .regular, design: .monospaced),

    // watchOS-specific (these tokens still exist on the iOS-side struct; values used only on watch)
    watchTimerDisplay:       .system(size: 40, weight: .heavy, design: .monospaced),
    watchMetricDisplay:      .system(size: 36, weight: .heavy, design: .monospaced),
    watchMetricSecondary:    .system(size: 22, weight: .heavy, design: .monospaced),
    watchStepLabel:          .system(size: 13, weight: .heavy, design: .monospaced),
    watchControlIcon:        .system(size: 26, weight: .heavy),
    watchControlLabel:       .system(size: 11, weight: .heavy, design: .monospaced),
    watchStatusBadge:        .system(size: 13, weight: .heavy, design: .monospaced),
    watchSummaryTimer:       .system(size: 28, weight: .heavy, design: .monospaced),
    watchSummaryMetric:      .system(size: 16, weight: .heavy, design: .monospaced),
    watchHeroIcon:           .system(size: 32, weight: .heavy),
    watchHeroTitle:          .system(size: 18, weight: .heavy, design: .monospaced),
    watchTemplateTitle:      .system(size: 14, weight: .heavy, design: .monospaced)
)
```

## 3. ThemeEffects spec

```swift
ThemeEffects(
    cardStyle: .lcd,                  // reuse Mixtape's LCD card style — chunky bordered rect
    hasNeonGlow: false,
    hasScanlines: false,              // we will add VU column + chrome via the background modifier
    hasGridBackground: false,
    neonGlowColor: nil,
    cardCornerRadius: 4,              // tight, pixel-edged
    buttonCornerRadius: 4,
    hasMeshBackground: false,
    hasHorizonGrid: false,
    hasLCDDotMatrix: false,
    hasCRTEffect: false,
    cardAccentBarWidth: 0
)
```

**Important — do NOT add a new `CardStyle` case.** The `.lcd` style already renders a bordered surface rect with crisp edges (see `ThemeModifiers.swift` line 72-83). The FM Tuner distinct chrome (header/footer/VU column) is rendered by **the background modifier**, not by `themedCard()`. This avoids touching every screen and keeps the change contained to:
- The new theme file
- The `themedScreenBackground()` switch
- A new `fmTunerBackground()` modifier

## 4. VU column — Canvas rendering spec

Drawn by `fmTunerBackground()` as an overlay on the leading edge.

**Geometry (iOS):**
- 18 stacked rectangles
- Each rect: width 4pt, height 6pt
- Vertical gap: 2pt
- Total column height: `18 * 6 + 17 * 2 = 142pt`
- Pinned to leading edge with `.padding(.leading, 6)`
- Vertically centered (use `geo.size.height / 2`)

**Fill rule:**
- The column expects a `value: Double` (0.0–1.0). It is read from `ThemeManager.shared.vuMeterValue` (new `@Observable` property on the manager — see Section 6).
- Number of filled segments: `Int((value * 18).rounded())`
- Segments below threshold: fill `#7CD8FF` (bright cyan)
- Segments above threshold: stroke `#0E6580` (dim cyan) at 0.5pt, no fill

**Crisp pixels:**
- Use `Canvas { ctx, size in ... }` (no anti-aliasing for these rects)
- Each segment: `ctx.fill(Path(rect), with: .color(...))`
- Do NOT use `RoundedRectangle` — sharp corners are part of the aesthetic

**Idle pulse:**
- When `value == 0` or unset, animate a breathing pulse: `value` interpolates `0.3 → 0.5 → 0.3` over 2.0s using `withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true))`.
- The manager owns this — see Section 6.

## 5. Chrome decorations (header + footer)

Both are overlays on `fmTunerBackground()`. They appear on **all screens** when FM Tuner is active. Implementation: extend the modifier to also overlay these views.

### Header bar — `FMTunerHeader.swift`

```
[📡 antenna.radiowaves.left.and.right]  [DATA SYNC ◀ 3 ▶]  [• • • •]
↑                                       ↑                    ↑
24pt SF Symbol, bright cyan             pill, 10pt mono       4 dots, alternating bright/dim
```

- Height: 28pt
- Padded `.padding(.horizontal, 16).padding(.top, 8)`
- Pill border: `Color.surfaceBorder`, 1pt stroke, corner radius 4
- Signal dots: 4 circles, 4pt each, 4pt gap; dots fill based on `ThemeManager.shared.signalStrength` (0–4 Int). Decorative for v1 — default to 3.
- Antenna SF Symbol: `Image(systemName: "antenna.radiowaves.left.and.right")`

### Footer info box — `FMTunerFooter.swift`

```
┌────────────────────────────────────┐
│ TUNED  88.5 MHz   ZONE 3   STEREO  │
│ STEP 8 / 12        ELAPSED 14:22   │
│ NEXT REST  00:30                   │
└────────────────────────────────────┘
```

- 1pt bordered rectangle, `Color.surfaceBorder`, corner radius 4
- Padding: 8pt horizontal, 6pt vertical
- Text: 10pt mono heavy, `textSecondary` (`#3A8FA8`) for labels, `textPrimary` for values
- Three lines, each `Text(...).frame(maxWidth: .infinity, alignment: .leading)`
- **The footer reads from `ThemeManager.shared.footerStatusLines: [String]`** — a `@Observable` property the active screen sets in `.onAppear`.
- Default value when no screen has set it: `["READY", "NO SIGNAL", "TUNE STATION"]`.

### Header/footer visibility

- **Always visible** when theme is FM Tuner, on every screen except onboarding / paywall (where they would compete with critical content). Use `ThemeManager.shared.chromeVisible: Bool` flag, default `true`, set to `false` in onboarding view's `.onAppear`.

## 6. ThemeManager additions

Add these `@Observable` properties to `ThemeManager` (both iOS and watchOS):

```swift
// FM Tuner chrome state (also harmless for other themes — modifier ignores them)
var vuMeterValue: Double = 0.0
var signalStrength: Int = 3
var footerStatusLines: [String] = ["READY", "NO SIGNAL", "TUNE STATION"]
var chromeVisible: Bool = true
```

Screens drive these in `.onAppear` / `.task`:

```swift
// IntervalWorkoutView active step example
.task(id: currentBPM) {
    ThemeManager.shared.vuMeterValue = min(1.0, Double(currentBPM) / 200.0)
    ThemeManager.shared.footerStatusLines = [
        "TUNED  \(stationFreq(template))   ZONE \(zone)   STEREO",
        "STEP \(currentStep)/\(totalSteps)        ELAPSED \(formattedElapsed)",
        "NEXT \(nextStepLabel)  \(formattedNextDuration)"
    ]
}
.onDisappear {
    ThemeManager.shared.vuMeterValue = 0
    ThemeManager.shared.footerStatusLines = ["READY", "NO SIGNAL", "TUNE STATION"]
}
```

**Justification for putting state on ThemeManager**: it lets every existing screen stay theme-agnostic. Non-FM-Tuner themes simply ignore these values. The alternative (preference keys on every view) would touch many more files.

## 7. Station frequency tag (`FMTunerStationTag`)

A reusable mini-component for template cards and home tiles:

```swift
struct FMTunerStationTag: View {
    let id: UUID
    var body: some View {
        Text(frequency)
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(ShuttlXColor.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(ShuttlXColor.surfaceBorder, lineWidth: 1)
            )
    }
    private var frequency: String {
        let n = abs(id.uuidString.hashValue) % 200 + 880
        return String(format: "%.1f", Double(n) / 10.0)
    }
}
```

Live this in `ShuttlX/Components/FMTunerStationTag.swift`. Other themes can render it conditionally (`if themeManager.current.id == "fmtuner"`) inside template cards.

## 8. Step pill (work / rest banner)

```
╔══════════════════════╗
║      W O R K         ║
╚══════════════════════╝
```

Renders as a double-bordered rectangle (outer 1pt, inner 1pt, 2pt gap) using two stacked `RoundedRectangle(cornerRadius: 2)`. Text is `ShuttlXFont.metricSmall` (16pt mono heavy), letter-spaced (`.tracking(4)`).

Implementation lives in `ShuttlX/Components/FMTunerStepPill.swift`. Only rendered when theme is FM Tuner — wrap in `if`. Existing step labels remain in other themes.

## 9. AppTheme.all registration

```swift
// AppTheme.swift
static let all: [AppTheme] = [
    .clean, .synthwave, .mixtape, .arcade,
    .classicRadio, .vuMeter, .neovim, .fmTuner   // new
]
```

## 10. Background modifier

Add to `ShuttlX/Theme/ThemeModifiers.swift`:

```swift
@ViewBuilder
func fmTunerBackground() -> some View {
    let theme = ThemeManager.shared
    self
        .background(
            ZStack {
                Color(red: 0.008, green: 0.063, blue: 0.094)  // #021018
                // Subtle horizontal scanline grain (very faint — LCD substrate effect)
                Canvas { ctx, size in
                    let lineColor = Color(red: 0.486, green: 0.847, blue: 1.000).opacity(0.015)
                    for y in stride(from: CGFloat(0), to: size.height, by: 4) {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        )
        // VU column overlay (leading edge, vertically centered)
        .overlay(alignment: .leading) {
            if theme.chromeVisible {
                FMTunerVUColumn(value: theme.vuMeterValue)
                    .padding(.leading, 6)
                    .allowsHitTesting(false)
            }
        }
        // Header chrome (top)
        .overlay(alignment: .top) {
            if theme.chromeVisible {
                FMTunerHeader()
                    .allowsHitTesting(false)
            }
        }
        // Footer chrome (bottom, above safe area)
        .overlay(alignment: .bottom) {
            if theme.chromeVisible {
                FMTunerFooter(lines: theme.footerStatusLines)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 70)  // above tab bar
                    .allowsHitTesting(false)
            }
        }
}
```

Add the `case "fmtuner": self.fmTunerBackground()` line to `themedScreenBackground()`.

## 11. State variants (per mockups file, section "State variants")

Every dynamic screen using FM Tuner must explicitly handle: idle / loading / running / paused / error / empty. The ascii-mockups.md file enumerates the exact treatment per state. Key rules:

- **Paused** colon-blink: `Text(":").opacity(blink ? 1.0 : 0.3)` driven by `Timer.publish(every: 0.5)`
- **Error**: step pill flips to `║ NO SIGNAL ║` rendered in `ctaDestructive` `#FF6B6B`. This is the ONLY screen where the step pill is red.
- **Loading**: VU column holds steady at 0.5, no animation, dim cyan only

## 12. Implementation hand-off

- **Files to create:**
  - `ShuttlX/Theme/Themes/FMTunerTheme.swift` — the AppTheme extension
  - `ShuttlX/Components/FMTunerHeader.swift` — header chrome
  - `ShuttlX/Components/FMTunerFooter.swift` — footer info box
  - `ShuttlX/Components/FMTunerVUColumn.swift` — Canvas-rendered VU bar
  - `ShuttlX/Components/FMTunerStationTag.swift` — frequency tag for cards
  - `ShuttlX/Components/FMTunerStepPill.swift` — double-bordered W O R K / R E S T pill

- **Files to modify:**
  - `ShuttlX/Theme/AppTheme.swift` — add `.fmTuner` to `all`
  - `ShuttlX/Theme/ThemeManager.swift` — add `vuMeterValue`, `signalStrength`, `footerStatusLines`, `chromeVisible`
  - `ShuttlX/Theme/ThemeModifiers.swift` — add `fmTunerBackground()` modifier, add case to `themedScreenBackground()` switch
  - `ShuttlX/Views/Workout/IntervalWorkoutView.swift` (or equivalent active-workout view) — write to `ThemeManager.shared.vuMeterValue` + `footerStatusLines` in `.task(id:)`
  - `ShuttlX/Views/Workout/RecoveryWorkoutView.swift` — same, for BPM-driven VU
  - `ShuttlX/Views/Workout/FreeRunView.swift` — same, for distance/pace footer
  - `ShuttlX/Views/Programs/ProgramsView.swift` — wrap template cards with `FMTunerStationTag` when theme is FM Tuner

- **Reuse existing:**
  - `ThemeEffects.CardStyle.lcd` (no new case needed — the chrome is in the background, not the card)
  - `ShuttlXColor.*` / `ShuttlXFont.*` bridges (no changes — they auto-track the active theme)
  - `.themedCard()` (the LCD case already renders a bordered surface that fits FM Tuner)
  - `.themedScreenBackground()` (add one switch case)

- **Theme variants verified:** Clean, Synthwave, Mixtape, Arcade, Classic Radio, VU Meter, Neovim. The new `vuMeterValue` / `footerStatusLines` / `signalStrength` / `chromeVisible` properties on `ThemeManager` are inert for the other 7 themes (their background modifiers don't read them). No per-theme adjustments needed.

- **Open questions for dev:**
  - The footer info box overlaps the bottom tab bar on screens that have one. Recommended fix: pass a `bottomInset` parameter (or use `.safeAreaInset(edge: .bottom)`) — but only do this if the 70pt hard-coded offset above looks wrong on iPhone SE (smaller safe area). Verify on iPhone SE 3rd gen and iPhone 17 Pro Max.
  - The "DATA SYNC ◀ 3 ▶" pill is decorative for v1. If you want it real, wire it to `SharedDataManager.shared.pendingSyncCount` — but only if you have time. Decorative is acceptable for first ship.
  - Currently `WorkoutTemplate` is the iOS+watch shared model — adding nothing to it is fine. `FMTunerStationTag` derives the frequency deterministically from `template.id` and stores nothing.
  - The existing `RecoveryWorkoutView` (after Sprint 7 Phase 1c, see commit c567b0c) sets manual stations — confirm where the "current station number" is read from and pipe it into the step pill text.
