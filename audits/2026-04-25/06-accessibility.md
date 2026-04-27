# ShuttlX Accessibility Audit — WCAG 2.2 AA + Apple A11y

Audit date: 2026-04-25
Scope: iOS 18+ (`ShuttlX/`), watchOS 11.5+ (`ShuttlX Watch App/`), Live Activity (`ShuttlXLiveActivity/`)
Method: Read-only static review of Swift sources + theme palettes. No simulator/device runs.

User population context: cardiac-rehab-adjacent. Plan for older eyes, possibly tremor or cognitive load, and for users who run accessibility settings turned up. Treat AA as a floor.

Summary count: 16 findings (4 P0, 6 P1, 4 P2, 2 P3). The team has done meaningful baseline work — `accessibilityLabel`/`accessibilityHint` coverage is good on most interactive elements, `accessibilityReduceMotion` is honored in 3 places, and the watch metric rows expose composite labels with `.updatesFrequently`. The biggest risks are (1) Dynamic Type silently capped or broken by hardcoded `.font(.system(size:))` literals across all 7 themes, (2) several color-only signals on iOS, and (3) deaf-user exclusion for the watch high-intensity warning and interval transitions.

---

## P0 — Blockers

### P0-1. Dynamic Type bypassed across all themes (hardcoded `.font(.system(size:))`)

- File: `ShuttlX/Theme/ThemeAssets.swift:354,362,365,368,447,458,609,647,650,728,735,878,899,910,927,931,936,962,966,971,996,1000,1005,1030,1039,1042`
- File: `ShuttlX/Theme/ThemeModifiers.swift:151,168,487,494,502,526,532,536,557,582,601,681,700,711,752`
- File: `ShuttlX Watch App/Theme/ThemeAssets.swift` (mirrors the iOS list)
- File: `ShuttlX Watch App/Theme/ThemeModifiers.swift` (mirrors the iOS list)
- File: `ShuttlX Watch App/Views/TrainingView.swift:114, 119, 125, 147, 203, 208, 370`

Why it matters: WCAG 2.2 SC 1.4.4 (Resize Text) requires text scaling up to 200%. `.font(.system(size: N))` returns a fixed-point font that does NOT respond to Dynamic Type. Cardiac-rehab users are statistically more likely to run Larger Text settings; on a watch, AX5 Dynamic Type is heavily used by users with low vision. The iOS Synthwave/VU Meter/ClassicRadio "status line" decorations (sizes 5-10pt) are already at the minimum legible size in default text — at AX5 they still render at the same pixel size, which is below WCAG's "non-text" effective size for many users.

The project's own design-system rule `.claude/rules/design-system.md` states: "Always use `ShuttlXFont.*` constants or `theme.fonts.*` — never raw `.font(.system(size:))`". The rule is violated in 60+ places across both targets, including the watch Training screen body (lines 114, 147, 203, 208).

Suggested fix direction: Replace decorative bottom-bar sizes with relative system fonts (e.g. `.system(.caption2, design: .monospaced)`) and let SwiftUI scale. For the watch timer in `TrainingView.swift:114`, use `ShuttlXFont.watchTimerDisplay` (already exists). For the in-content sizes at lines 138-139, gate via `@Environment(\.dynamicTypeSize)` and choose a `.scaledToFit`/`minimumScaleFactor(0.5)` strategy or break the layout to a single column on AX3+.

Confidence: high.

---

### P0-2. iOS timer screen uses hardcoded 52pt — never tested at AX5

- File: `.claude/rules/design-system.md` codifies "52pt monospaced timer" with no Dynamic Type accommodation.
- Likely site of the iOS active-workout timer (not located in scope here but referenced as the iOS Timer Screen rule).

Why it matters: For a workout timer the cardiac-rehab user must be able to glance and read at a distance with possibly impaired vision. A 52pt fixed display is fine for default vision, but at AX5 + low vision these users currently have no path to grow text. WCAG 2.2 SC 1.4.4 violation if the timer is the primary readable element.

Suggested fix direction: Use `.font(.system(size: 52, weight: .semibold, design: .monospaced))` paired with `.dynamicTypeSize(.large ... .accessibility5)` or a manual `@ScaledMetric(relativeTo: .largeTitle) var timerSize: CGFloat = 52`. Don't suppress scaling.

Confidence: medium (rule is documented but the actual site was not directly read; flag for verification of the iOS timer screen file).

---

### P0-3. Watch high-intensity warning is haptic + visual but pauses are auditory-equivalent — actual P0 is the AOD (always-on display) text contrast on Synthwave/Arcade themes

- File: `ShuttlX Watch App/Views/TrainingView.swift:110-132`

Why it matters: The AOD view (`aodMinimalView`) hardcodes `.foregroundColor(.white.opacity(0.7))` for the timer (line 116) and `.red.opacity(0.7)` for HR (line 121) on a `.black` background (line 131). With opacity 0.7 white on black ≈ 14.7:1 (passes AA-Large). However the red.opacity(0.7) on black evaluates to roughly 6.4:1 for system red — passes AA-Normal. The bigger issue is the IntervalType color at line 126 with `.opacity(0.6)`. For Synthwave `stepRest` (#FFB800 amber) on black at 0.6 opacity ≈ 4.0:1 — fails AA-Normal for the 14pt text used on line 125. For Arcade `stepWarmup` (#00AAFF blue) on black at 0.6 opacity ≈ 3.6:1 — fails AA-Normal.

In AOD mode the screen is the primary clock face for hours-long workouts; the rehab user must be able to read step type in low ambient light without lifting the wrist.

Suggested fix direction: Drop `.opacity(0.6)` on the step label, or boost the underlying color. AOD content should be designed to clear AA at a fixed 1.0 alpha.

Confidence: medium (contrast computed manually; needs verification with a contrast tool).

---

### P0-4. Live Activity uses raw `.green`/`.orange`/`.red` only for paused/active state with no text equivalent for color-blind users

- File: `ShuttlXLiveActivity/LockScreenView.swift:12-22`

Why it matters: Lines 12-14 fill a small status dot orange when paused, green when active. The accompanying text label (line 15) does say "Paused" vs the activity name, so primary state is text-labeled — that part is fine. HOWEVER the dot is the most prominent visual hierarchy element on the lock screen at a glance. Worse, lines 30-39 use raw `Color.red`, `Color.green`, `Color.orange`, `Color.purple` directly for all metric pills with NO accessibility label on the `MetricPill` struct (lines 98-112). VoiceOver will read the raw value but lose the metric semantic ("142" instead of "heart rate 142"). For a deuteranopic user looking at the lock screen, all four pills look similar in luminance; only the SF Symbol icons disambiguate, and at lock-screen icon size the icons are below the WCAG 2.2 SC 1.4.11 (3:1 non-text contrast) effective minimum on a dark `activityBackgroundTint(.black.opacity(0.75))` background.

No `accessibilityLabel` on `LockScreenView` itself or on `MetricPill`. No `accessibilityElement(children: .combine)` on the parent.

Suggested fix direction: Add `accessibilityElement(children: .combine)` and a comprehensive `accessibilityLabel` summarizing the running state on `LockScreenView`'s root VStack. Add `.accessibilityLabel("\(metricName) \(value)")` to each `MetricPill`. For visual differentiation, ensure the heart/flame/location SF Symbols meet 3:1 contrast on the dark background — increase opacity or add a thin contrasting stroke.

Confidence: high.

---

## P1 — Major

### P1-1. Color-only signaling for HR zones: 5 zones use only color, no shape or label

- File: `ShuttlX/Theme/ThemeColors.swift:84-92` (and watch mirror)
- Used by: `ShuttlX Watch App/Views/TrainingView.swift:167` (HR row colored by `forHRZone`)
- Used by: `ShuttlX/Views/Charts/HRZoneChart.swift:24` (BarMark `.foregroundStyle(zone.color)`)

Why it matters: HR zones are the primary cardiac-rehab signal. Five colors (blue/green/yellow/orange/red across themes) carry the only shape information. Deuteranopic and protanopic users cannot reliably distinguish zones 3 (yellow/amber), 4 (orange), 5 (red). On the watch HR display, `forHRZone(heartRate)` returns just a color — no zone number is ever shown next to the BPM. A user in zone 5 sees red text but a colorblind user sees the same color as zone 3.

WCAG 2.2 SC 1.4.1 (Use of Color) violation. This is the single most important medical signal in the app.

Suggested fix direction: Show zone number explicitly next to BPM ("142 BPM · Z3") on watch. In `HRZoneChart.swift`, add a textured pattern or emoji glyph per zone (Apple's `Chart`/`SwiftUI` supports `symbol(.shape)`); each zone gets its own shape (circle, triangle, square, diamond, star). For VoiceOver `forHRZone` should be paired with `accessibilityValue("Zone \(n)")`.

Confidence: high.

---

### P1-2. Synthwave/Arcade neon glow shadows ignore `accessibilityReduceTransparency`

- File: `ShuttlX/Theme/ThemeModifiers.swift:180-184` (`neonGlow`)
- File: `ShuttlX/Theme/ThemeAssets.swift:145, 151-152, 906, 912, 933, 968, 1002, 1032, 1044, 1110`

Why it matters: The Synthwave and Arcade themes pile `.shadow(color: ..., radius: 6-12)` halos behind text. Users with `Reduce Transparency` enabled (a meaningful subset of low-vision users — Apple gates this with the same accessibility preference cluster as `Increase Contrast`) expect glow effects to flatten. Currently the modifier never reads `@Environment(\.accessibilityReduceTransparency)`. A glowing magenta heart-rate value smears against the dark background and reduces effective contrast for low-vision users — exactly the population the app serves.

There is no use of `differentiateWithoutColor` or `reduceTransparency` anywhere in the `ShuttlX/` or `ShuttlX Watch App/` source trees (verified via grep).

Suggested fix direction: Add `@Environment(\.accessibilityReduceTransparency) var reduceTransparency` to `neonGlow`; when true, return `self` unchanged (no shadow). Same for the LCD/CRT/scanline/grid overlays in `ThemeModifiers.swift:188`, `:207`, etc.

Confidence: high.

---

### P1-3. Mixtape scanline overlay not gated by `accessibilityReduceMotion` or `reduceTransparency`

- File: `ShuttlX/Theme/ThemeModifiers.swift:188-203`
- File: `ShuttlX/Theme/Themes/MixtapeTheme.swift:85` (`hasScanlines: true`)
- File: `ShuttlX/Theme/Themes/ArcadeTheme.swift:93` (`hasCRTEffect: true`)

Why it matters: Static scanlines overlay the entire screen in Mixtape; CRT vignette + scanlines in Arcade. While these don't move (no flicker), the dense 1-pixel horizontal striping covering 100% of the canvas is a documented vestibular and migraine trigger for users with photosensitive conditions. WCAG 2.2 SC 2.3.3 (Animation from Interactions) is borderline — but more importantly Apple HIG calls out that decorative pattern overlays should respect `Reduce Transparency`.

Suggested fix direction: In `scanlineOverlay`, read `@Environment(\.accessibilityReduceTransparency)` and return `self` plain when on. Same for Arcade CRT effect.

Confidence: medium.

---

### P1-4. iOS LiveWorkoutCard pulse animation reads `reduceMotion` but the static dot remains color-only and uses raw `Color.green`

- File: `ShuttlX/Views/Dashboard/LiveWorkoutCard.swift:28-31`
- File: `ShuttlX/Views/Dashboard/LiveWorkoutCard.swift:13-21` (raw `.secondary` for stationary)

Why it matters: The pulsing dot is the only at-a-glance signal that the watch workout is live. With reduce motion the pulse correctly stops (line 125). However the dot itself is `ShuttlXColor.running` (the active green) when paused or running — line 33's text correctly says "Paused" or "Live Workout", so labeling is OK, but the colored dot doesn't change between states. A returning user glancing at the card can't tell paused vs live from the dot alone. Also `activityColor` (line 15-21) returns `.secondary` for unknown states which on the dark `running.opacity(0.08)` background may not meet 3:1 (SwiftUI `.secondary` is dynamic; in Dark Mode it's ~#EBEBF599 which clears 3:1 but is below 4.5:1 for body text).

Suggested fix direction: Use a paused-state color (e.g. `ShuttlXColor.ctaWarning`) when `liveIsPaused`, and pair the dot with an SF Symbol (`pause.circle.fill` vs `circle.fill`). Add `accessibilityValue` distinguishing paused/active — currently line 95's label string conditionally embeds neither paused nor running state.

Confidence: high.

---

### P1-5. Watch interval-step transitions are haptic-only — deaf or hard-of-hearing users miss step changes

- File: `ShuttlX Watch App/Services/IntervalEngine.swift:130-140` (`fireHaptic`)
- File: `ShuttlX Watch App/Services/IntervalEngine.swift:60` (5-second countdown)

Why it matters: The watch fires `.start`/`.directionDown`/`.click` haptics on each step change. Visually the dot color changes and the ring resets (`TrainingView.swift:283-284`), but only with a 0.3s ease-in animation that's gated by `reduceMotion` to opacity-only. For a deaf user with reduce motion ON, the step transition becomes a quiet color change with no spatial movement and no announcement. A user who is hard-of-hearing AND wears the watch on the non-dominant wrist may miss the haptic. The 5-second countdown haptic (`IntervalEngine.swift:60`) is the only warning the rest period is ending; missing it means continuing to walk into a work interval.

WCAG 2.2 SC 1.2.1 / 1.4.7 — not strictly applicable (no audio media), but the principle applies: any time-critical signal must have a redundant modality.

Suggested fix direction: When step changes, fire `AccessibilityNotification.Announcement("Work interval starting")` via `accessibilityNotification(.announcement)` so VoiceOver speaks. For users without VoiceOver, add a brief full-screen banner overlay (e.g. "WORK" badge that fades in/out) in addition to haptic. Add a 3-second countdown VISUAL flash (number) in the center of the ring at line 260 area — currently the countdown digits are the only signal and they're 22pt monospaced inside a 56pt ring, so visually small.

Confidence: high.

---

### P1-6. iOS InteralResultsView per-row uses 8pt color dot only — color-only signal for interval type

- File: `ShuttlX/Views/IntervalResultsView.swift:49-51, 187, 226-228`

Why it matters: Each completed interval row shows an 8pt circle filled with `forStepType(intervalType)` color. The only differentiation between work/rest/warmup/cooldown is hue. The text label `interval.label ?? interval.intervalType.displayName` (line 55) is text — so if the user has a label, they can read it; if `nil`, they fall back to `displayName` which is text — OK there. But the timeline bar (lines 30-39) is pure color stripes with no shape. Color-blind users cannot read a 5-bar interval timeline.

Suggested fix direction: Add `.accessibilityLabel` on each timeline segment with the type name and duration. Visually, add diagonal hatching for warmup/cooldown to differentiate from work/rest beyond color.

Confidence: high.

---

## P2 — Moderate

### P2-1. Watch ProgramSelectionView free-run/template buttons may not meet 60pt active-workout tap target — but pre-workout, so 44pt baseline applies

- File: `ShuttlX Watch App/Views/ProgramSelectionView.swift:69-145`

Why it matters: The card buttons use `ShuttlXSpacing.lg` (12pt) horizontal + `ShuttlXSpacing.md` (8pt) vertical padding around content. With watchTemplateTitle font (`.body`) plus subtitle, the row height is roughly 44-50pt — clears 44pt baseline. NOT critical on the start screen since the user is stationary. The TrainingView control buttons at `controlButtonDiameter = 64pt` (`ShuttlXTheme.swift:139`) DO clear the active-workout 60pt+ target, which is good.

Risk: at large Dynamic Type sizes the cards stack subtitle+title and may push other content off-screen on 41mm watches.

Suggested fix direction: Test with `dynamicTypeSize(.accessibility5)`. Accept that during Free Run/Templates startup the user is stationary so 44pt is acceptable, but consider raising to 50pt+ vertical for cardiac-rehab user with possible motor tremor.

Confidence: medium.

---

### P2-2. iOS PlanDetailView mark-complete button uses unfilled circle, no color, no semantic state announcement

- File: `ShuttlX/Views/PlanDetailView.swift:136-149`

Why it matters: The button correctly hits 44pt frame (line 143) and has `accessibilityLabel("Mark as completed")`. However the icon is `Image(systemName: "circle")` in `.secondary` color — a thin stroke that may fall below 3:1 against `.themedCard` backgrounds on some themes (Mixtape's blue surface, Arcade's dark purple). SF Symbol stroke widths have known low contrast against medium-dark fills.

Suggested fix direction: Use `circle.dashed` or add a fill backing; verify `.secondary` against each theme's card surface.

Confidence: medium.

---

### P2-3. SettingsView watch-status indicator is color-coded dot with no shape change

- File: `ShuttlX/Views/SettingsView.swift:120-125`

Why it matters: A `Circle()` filled `ShuttlXColor.positive` (green) when paired and `Color.secondary` when not. The composite element correctly merges into one accessibility element with `accessibilityValue(watchStatusText)` (line 129), so VoiceOver works. Visually for a color-blind user the green vs secondary dot is hard to distinguish in some themes (e.g. Synthwave green and Synthwave gray-secondary). The text label `watchStatusText` carries the truth, so this is borderline — but adding a checkmark.circle.fill vs circle SF Symbol would be a 1-line improvement and better matches Apple's HIG guidance.

Suggested fix direction: Replace `Circle()` with `Image(systemName: watchPaired ? "checkmark.circle.fill" : "circle.dotted")`.

Confidence: medium.

---

### P2-4. WeekStripView session-count uses up to 3 small dots — 4pt circles likely fail 3:1 non-text contrast on some themes

- File: `ShuttlX/Views/Charts/WeekStripView.swift:40-48`

Why it matters: 4pt circles are below SC 1.4.11 (Non-text Contrast) effective bounding-box minimum. On Mixtape the green `running` color (#39FF14) on the day-card surface (transparent over dark blue body) clears contrast, but the 4pt dimension is so small it functionally disappears at AX dynamic type. The accessibility label on line 58 says "X sessions" so VoiceOver works fine. Visual fix only.

Suggested fix direction: Use a single text "Nx" badge at AX1+ instead of dots. At default text size, 6pt circles or bars would help.

Confidence: medium.

---

## P3 — Minor

### P3-1. No `accessibilityRotor` defined anywhere

- File: every `ScrollView` in `ShuttlX/Views/`

Why it matters: For a long screen like `AnalyticsView`, `TrainingHistoryView`, or `PlanDetailView`, VoiceOver users currently have no rotor shortcut to jump between weeks/sessions/zones. Apple's HIG recommends rotors for heterogeneous lists. Not strictly a WCAG failure — there's no SC for rotors — but it materially harms the experience for VoiceOver users.

Suggested fix direction: On `TrainingHistoryView`, add `.accessibilityRotor("Sessions") { ForEach(sessions) { ... } }`. On `PlanDetailView`, add a "Weeks" rotor.

Confidence: low (this is enhancement, not violation).

---

### P3-2. Mixtape ctaPrimary and ctaPause are the same blue — pause-state visual encoding lost on this theme

- File: `ShuttlX/Theme/Themes/MixtapeTheme.swift:23,26`

Why it matters: `ctaPrimary` and `ctaPause` both equal `Color(red: 0.29, green: 0.54, blue: 0.79)`. On the watch TrainingView at lines 308-310, the play/pause button changes color from `ctaPrimary` (when paused, showing play icon) to `ctaPause` (when running, showing pause icon). On Mixtape these are identical, so the only signal is the icon shape (`pause.fill` vs `play.fill`) — which is OK, since shape carries semantics and SF Symbols are highly distinct. But this is an accidental degradation that breaks the visual-state design pattern. A one-character fix.

Suggested fix direction: Either (a) acknowledge in design: shape carries the state, color is intentionally invariant; or (b) make `ctaPause` a distinct hue (LED red `#FF3333`?) for parity with other themes. Either is fine — document the choice.

Confidence: high.

---

## What is GOOD (worth keeping)

- Watch TrainingView metric rows (lines 198-219) correctly use `accessibilityElement(children: .combine)` + composite `accessibilityLabel` like "Heart rate 142 beats per minute" + `.updatesFrequently` trait. This is textbook.
- Onboarding (`OnboardingView.swift:21,34,38,47-53,70-107`) has thorough labels, hints, hidden decoration, and `.isHeader` traits. Good pattern.
- TemplateEditorView (`TemplateEditorView.swift:72,107,118,145,233`) wraps composite rows with `.accessibilityElement(children: .contain)` and provides full labels including dynamic state. Good pattern.
- Reduce Motion is honored in 3 places (DashboardView:11, LiveWorkoutCard:121, TrainingView watch:19) — extend to the rest.
- `controlButtonDiameter = 64pt` (`ShuttlXTheme.swift:139`) clears the watch active-workout 60pt+ guideline.
- iOS TrainingHistoryView correctly uses `frame(minWidth: 44, minHeight: 44)` (lines 81, 95).
- AOD luminance-reduced view exists (`TrainingView.swift:101-132`) and switches to a minimal layout — good per-Apple pattern, just needs the contrast fix above.

---

## Recommended remediation order

1. P0-1 (Dynamic Type / hardcoded sizes): mechanical replace, 60+ sites, high impact.
2. P0-3 (AOD step-color contrast): 3-line fix in `TrainingView.swift`.
3. P0-4 (Live Activity labels): add `accessibilityElement` + `accessibilityLabel` to `LockScreenView` and `MetricPill`.
4. P1-1 (HR zone color-only): add zone number text + symbol shapes. This is the highest medical-significance item.
5. P1-5 (haptic-only step transitions): add `AccessibilityNotification.Announcement` + visual banner.
6. P1-2, P1-3 (transparency/glow gating): add 1-line `@Environment(\.accessibilityReduceTransparency)` reads to 4 modifiers.
7. P0-2 (iOS 52pt timer): once located, wrap with `@ScaledMetric`.
8. Remaining P1/P2/P3 in convenience order.
