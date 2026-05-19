# FM Tuner Theme — watchOS Implementation Spec

**Target:** watchOS 11.5+
**Owner:** swiftui-watchos-specialist
**Files mirrored on iOS:** see `ios.md`

## 0. Read these first

- `design/proposals/2026-05-19-fm-tuner-theme/README.md` — research & rationale
- `design/proposals/2026-05-19-fm-tuner-theme/assets/ascii-mockups.md` — mockups 7, 8, 9 are watchOS-specific
- `design/proposals/2026-05-19-fm-tuner-theme/ios.md` — keep these mirrored
- `ShuttlX Watch App/Theme/Themes/VUMeterTheme.swift` — closest existing pattern

## 1. ThemeColors — identical to iOS

Copy the full `ThemeColors(...)` initializer from `ios.md` Section 1 verbatim. Models and themes are duplicated between targets per `.claude/rules/models.md` — both files must stay byte-identical except for font sizes.

## 2. ThemeFonts — watchOS sizes

Smaller hero, but everything still `.monospaced` `.heavy`. Use these sizes on the watch file:

```swift
ThemeFonts(
    // Shared (iOS values still listed for compile parity — watchOS uses the watch-specific ones below)
    timerDisplay:        .system(size: 40, weight: .heavy, design: .monospaced),  // smaller than iOS 56
    metricLarge:         .system(size: 36, weight: .heavy, design: .monospaced),
    metricMedium:        .system(size: 22, weight: .heavy, design: .monospaced),
    metricSmall:         .system(size: 14, weight: .heavy, design: .monospaced),
    cardTitle:           .system(size: 14, weight: .heavy, design: .monospaced),
    cardSubtitle:        .system(size: 11, weight: .heavy, design: .monospaced),
    cardCaption:         .system(size: 9,  weight: .heavy, design: .monospaced),
    sectionHeader:       .system(size: 12, weight: .heavy, design: .monospaced),

    // iOS-specific (declared for type parity; not referenced on watch)
    heroIcon:            .system(size: 32, weight: .heavy),
    onboardingIcon:      .system(size: 48, weight: .heavy),
    prValue:             .system(size: 18, weight: .heavy, design: .monospaced),
    microLabel:          .system(size: 8,  weight: .bold,  design: .monospaced),
    debugMono:           .system(size: 9,  weight: .regular, design: .monospaced),

    // watchOS-specific (these are the ones that matter on this target)
    watchTimerDisplay:       .system(size: 40, weight: .heavy, design: .monospaced),
    watchMetricDisplay:      .system(size: 36, weight: .heavy, design: .monospaced),
    watchMetricSecondary:    .system(size: 22, weight: .heavy, design: .monospaced),
    watchStepLabel:          .system(size: 13, weight: .heavy, design: .monospaced),
    watchControlIcon:        .system(size: 22, weight: .heavy),
    watchControlLabel:       .system(size: 11, weight: .heavy, design: .monospaced),
    watchStatusBadge:        .system(size: 12, weight: .heavy, design: .monospaced),
    watchSummaryTimer:       .system(size: 26, weight: .heavy, design: .monospaced),
    watchSummaryMetric:      .system(size: 15, weight: .heavy, design: .monospaced),
    watchHeroIcon:           .system(size: 26, weight: .heavy),
    watchHeroTitle:          .system(size: 16, weight: .heavy, design: .monospaced),
    watchTemplateTitle:      .system(size: 13, weight: .heavy, design: .monospaced)
)
```

## 3. ThemeEffects — identical to iOS

```swift
ThemeEffects(
    cardStyle: .lcd,
    hasNeonGlow: false,
    hasScanlines: false,
    hasGridBackground: false,
    neonGlowColor: nil,
    cardCornerRadius: 4,
    buttonCornerRadius: 4,
    hasMeshBackground: false,
    hasHorizonGrid: false,
    hasLCDDotMatrix: false,
    hasCRTEffect: false,
    cardAccentBarWidth: 0
)
```

## 4. VU column — watch-sized

Same Canvas approach as iOS, but smaller geometry to fit 41mm/45mm/49mm:

- 14 stacked rectangles (instead of 18)
- Each rect: width **3pt**, height **4pt**
- Vertical gap: **1pt**
- Total column height: `14 * 4 + 13 * 1 = 69pt`
- Pinned to leading edge with `.padding(.leading, 2)`
- Vertically centered

Same fill rule, same idle-pulse animation, same `value = Double(bpm) / 200.0` source.

## 5. Chrome decorations — minimal on watch

The 41mm screen does **not** have room for the full iOS chrome. Per the watchOS rules ("max ~5 visible elements"), strip down to:

- **No header bar at all** on workout/recovery screens. The step pill becomes the de facto header.
- **Single-line footer info box** instead of three lines. Width-constrained, mono 9pt, one line of status text.
- The home screen gets an even smaller chrome strip: 📡 icon + 3 signal dots, no pill.

### Header (home only) — `FMTunerWatchHomeHeader.swift`

```
📡 ░░  ▓ ▓ ▓
```

Height: 16pt. Padding: `.horizontal 8, .top 4`. Antenna icon at 12pt, three dots 3pt each.

### Footer (workout + recovery) — `FMTunerWatchFooter.swift`

A single-line bordered rectangle:

```
┌─────────────────────────┐
│ STN 01:48 · TOT 12:34   │
└─────────────────────────┘
```

- Border: 1pt `Color.surfaceBorder`, corner radius 3
- Text: 9pt mono heavy, `textSecondary` for labels, `textPrimary` for values, separated by ` · `
- Padding: `.horizontal 6, .vertical 3`
- Reads `ThemeManager.shared.footerStatusLines.first ?? ""` (joins lines with `· ` on watch — we only render one line)

## 6. ThemeManager additions — identical to iOS

The watchOS `ThemeManager` gets the same four new properties:

```swift
var vuMeterValue: Double = 0.0
var signalStrength: Int = 3
var footerStatusLines: [String] = ["READY · NO SIGNAL"]
var chromeVisible: Bool = true
```

The watch-side workout view (`TrainingView.swift` or `WatchWorkoutManager` consumers) writes to these in `.task(id: currentBPM)` blocks. Pattern:

```swift
.task(id: workoutManager.currentBPM) {
    ThemeManager.shared.vuMeterValue = min(1.0, Double(workoutManager.currentBPM) / 200.0)
    ThemeManager.shared.footerStatusLines = [
        "STEP \(workoutManager.currentStep)/\(workoutManager.totalSteps) · Z\(zone) · \(elapsedFormatted)"
    ]
}
.onDisappear {
    ThemeManager.shared.vuMeterValue = 0
    ThemeManager.shared.footerStatusLines = ["READY · NO SIGNAL"]
}
```

## 7. Background modifier (watch version)

Add to `ShuttlX Watch App/Theme/ThemeModifiers.swift`:

```swift
@ViewBuilder
func fmTunerBackground() -> some View {
    let theme = ThemeManager.shared
    self
        .background(
            Color(red: 0.008, green: 0.063, blue: 0.094)  // #021018
                .ignoresSafeArea()
        )
        // Scanlines omitted on watch — OLED + 41mm + the Canvas cost isn't worth it
        .overlay(alignment: .leading) {
            if theme.chromeVisible {
                FMTunerWatchVUColumn(value: theme.vuMeterValue)
                    .padding(.leading, 2)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if theme.chromeVisible {
                FMTunerWatchFooter(line: theme.footerStatusLines.first ?? "")
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                    .allowsHitTesting(false)
            }
        }
}
```

Add the `case "fmtuner": self.fmTunerBackground()` line to `themedScreenBackground()` in the watchOS modifiers file.

**Note:** No header overlay on the workout screens. The home screen view itself includes `FMTunerWatchHomeHeader()` at the top of its `VStack` (rendered explicitly when theme is FM Tuner).

## 8. watchOS-specific layout adaptations

Per `.claude/rules/watchos.md`:

- Timer is 40pt mono heavy (`watchTimerDisplay`)
- Circular buttons: green pause / red stop (already conventional). On FM Tuner, the "green" pause becomes `ctaPrimary` `#7CD8FF` (cyan) since there is no green in this theme. The red stop stays red (`ctaDestructive` `#FF6B6B`).
- Min 44pt touch targets — every button in mockups 7-9 meets this.
- `DispatchSourceTimer` already drives the colon-blink in paused state (no new timer infrastructure needed — use the existing pause-state observable).

## 9. Step pill — watch version

Same double-bordered visual treatment as iOS, but:

- Inner padding: 4pt horizontal, 2pt vertical
- Text: 13pt mono heavy (`watchStepLabel`), `.tracking(3)` instead of 4
- Single line only — no descenders, no wrap

Lives in `ShuttlX Watch App/Components/FMTunerStepPill.swift` (mirror of iOS).

## 10. Implementation hand-off

- **Files to create:**
  - `ShuttlX Watch App/Theme/Themes/FMTunerTheme.swift` — the AppTheme extension (mirror of iOS, watch font sizes)
  - `ShuttlX Watch App/Components/FMTunerWatchVUColumn.swift` — Canvas VU bar, 14 segments
  - `ShuttlX Watch App/Components/FMTunerWatchFooter.swift` — single-line bordered footer
  - `ShuttlX Watch App/Components/FMTunerWatchHomeHeader.swift` — minimal antenna + dots strip
  - `ShuttlX Watch App/Components/FMTunerStepPill.swift` — double-bordered pill, watch sizing
  - `ShuttlX Watch App/Components/FMTunerStationTag.swift` — mirror of iOS for any template tiles

- **Files to modify:**
  - `ShuttlX Watch App/Theme/AppTheme.swift` — add `.fmTuner` to `all`
  - `ShuttlX Watch App/Theme/ThemeManager.swift` — add `vuMeterValue`, `signalStrength`, `footerStatusLines`, `chromeVisible`
  - `ShuttlX Watch App/Theme/ThemeModifiers.swift` — add `fmTunerBackground()`, add case to `themedScreenBackground()`
  - `ShuttlX Watch App/Views/TrainingView.swift` — write to `ThemeManager.shared.vuMeterValue` + `footerStatusLines` in `.task(id: currentBPM)`
  - `ShuttlX Watch App/Views/RecoveryWorkoutView.swift` — same, for BPM-driven VU and station status
  - `ShuttlX Watch App/Views/HomeView.swift` (or whatever the watch home is named) — conditionally render `FMTunerWatchHomeHeader()` at top + `FMTunerStationTag` on mode tiles when theme is FM Tuner

- **Reuse existing:**
  - `ThemeEffects.CardStyle.lcd` (no new case)
  - `ShuttlXColor.*` / `ShuttlXFont.*` bridges
  - `.themedCard()` LCD path
  - `.themedScreenBackground()` (add switch case)
  - `WatchWorkoutManager.currentBPM` (already published — wire to vuMeterValue)
  - Theme sync via `applicationContext` — no changes needed, the new "fmtuner" id propagates the same way as other themes (per `.claude/rules/services.md` and `.claude/rules/watchos.md`)

- **Theme variants verified:** Clean, Synthwave, Mixtape, Arcade, Classic Radio, VU Meter, Neovim. New `ThemeManager` properties are inert for the other 7 themes. The watchOS Clean theme's `LinearGradient` fallback (for the lack of `MeshGradient` on watchOS) is unaffected.

- **Open questions for dev:**
  - The 49mm Apple Watch Ultra has more vertical room — should the watch footer expand to two lines on Ultra? Recommendation: keep one line always for consistency; users may toggle wrists between mid-workout devices. Worth testing if it looks too sparse on Ultra.
  - The watch `ThemeManager` already syncs `selectedThemeID` from iPhone — confirm that selecting FM Tuner on iPhone correctly pushes "fmtuner" via `applicationContext` (this is the existing path in `SharedDataManager.handleIncomingPayload`'s `"syncTheme"` action — should Just Work but verify).
  - During the 1Hz colon blink in paused state, the VU column also freezes at its last value — the dev should make sure `vuMeterValue` does not update while paused (gate the write in the view's `.task` with `if !workoutManager.isPaused`). Otherwise the bar will keep tracking ambient HR drift and break the "frozen" illusion.
  - `WatchWorkoutManager` is 944 lines and currently the heaviest file on the target. Do NOT refactor it as part of this work — only add the four-line `ThemeManager.shared.vuMeterValue = ...` writes in the consuming view, not inside the manager itself.
