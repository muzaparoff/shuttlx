---
globs:
  - "**/Views/**"
  - "**/Components/**"
  - "**/Theme/**"
---

# Design System Rules

All new UI code must follow these conventions. Existing code should be migrated when touched.

## Theme System

- 8 selectable themes: **Clean** (default), **Synthwave**, **Mixtape**, **Arcade**, **Classic Radio**, **VU Meter**, **Neovim**, **FM Tuner**
- `ThemeManager.shared` is the `@Observable` singleton — injected via `.environment(ThemeManager.shared)` at app root
- **Theme switching**: always call `ThemeManager.shared.selectTheme(id)` — never set `selectedThemeID` directly
- `current` is a stored `@Observable` property (not computed) — ensures SwiftUI re-renders on theme change
- Views can access theme via `@Environment(ThemeManager.self) var themeManager` then `themeManager.colors.*`, `themeManager.fonts.*`
- `ShuttlXColor.*` and `ShuttlXFont.*` enums **bridge** to `ThemeManager.shared` — existing code is automatically theme-aware
- Theme files: `ShuttlX/Theme/` (iOS) and `ShuttlX Watch App/Theme/` (watchOS) — mirrored
- Theme ID persisted in App Group UserDefaults, synced to Watch via WCSession

## Screen Backgrounds

- Use `.themedScreenBackground()` on every major screen's outermost container (NavigationStack, ScrollView, List, TabView)
- Switches automatically per active theme: mesh gradient (Clean), horizon grid (Synthwave), blue body texture (Mixtape), CRT scanlines (Arcade), warm brown grain (Classic Radio), amber glow panels (VU Meter), Gruvbox solid + gutter stripe (Neovim), navy solid + chrome overlay (FM Tuner)
- Background modifiers: `.cleanMeshBackground()`, `.synthwaveHorizonBackground()`, `.mixtapeBackground()`, `.arcadeCRTBackground()`, `.classicRadioBackground()`, `.vuMeterBackground()`, `.neovimBackground()`, `.fmTunerBackground()`
- `MeshGradient` is iOS-only — watchOS Clean theme uses `LinearGradient` fallback
- All background overlays use `.allowsHitTesting(false)` and `.ignoresSafeArea()`

## Cards & Containers

- Use `.themedCard()` for all card containers — adapts per theme (glass/neon/lcd/pixel/tape/meter/terminal)
- `.glassBackground(cornerRadius:)` still available as a fallback for Clean-only contexts
- Theme-specific modifiers: `.neonGlow()`, `.lcdPanel()`, `.scanlineOverlay()`, `.synthwaveGrid()`
- FM Tuner cards use `.lcd` CardStyle (shared with Mixtape)
- Never use `Divider()` between list items — use vertical spacing (`LazyVStack(spacing: 12)`)
- Standard card padding: `.padding(16)`

## Colors

- Always use `ShuttlXColor.*` constants or `theme.colors.*` — never hardcoded `Color.green`, `Color.red`, etc.
- `ShuttlXColor.*` bridges to the active theme automatically
- Activity colors: `.running`, `.walking`, `.heartRate`, `.steps`, `.calories`, `.stationary`
- Sport colors: `.cycling`, `.swimming`, `.hiking`, `.elliptical`, `.crossTraining`
- CTA colors: `.ctaPrimary`, `.ctaDestructive`, `.ctaWarning`
- Text colors: `.textPrimary`, `.textSecondary`
- Surface colors: `.background`, `.surface`, `.surfaceBorder`

## Typography

- Always use `ShuttlXFont.*` constants or `theme.fonts.*` — never raw `.font(.system(size:))`
- `ShuttlXFont.*` bridges to the active theme automatically
- Key fonts: `.metricLarge`, `.metricMedium`, `.metricSmall`, `.timerDisplay`, `.sectionHeader`, `.cardTitle`, `.cardSubtitle`, `.cardCaption`

## Numerics

- All numeric displays must use `.monospacedDigit()` for stable layout

## Accessibility

- Every interactive element needs `.accessibilityLabel()`
- Use `.accessibilityElement(children: .combine)` for composite rows
- Add `.accessibilityHint()` for non-obvious actions

## Reusable Components

- `MetricCard` — standard metric display (icon, value, label, color, compact flag)
- `ActivityBadge` — activity type pill (activity, duration)
- `StreakBadge` — streak display
- `ElevationProfileView` — elevation chart from route data

## Layout Patterns

- Standard scrollable screen:
  ```swift
  NavigationStack {
      ScrollView {
          VStack(spacing: 16) { ... }
              .padding(.horizontal)
              .padding(.top, 8)
      }
      .navigationTitle(...)
  }
  ```
- Metric grid: `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10)`

## Per-theme Timer Hero

Each theme renders a unique animated **hero** element during the active-workout timer display:

- **iOS dispatch**: `iPhoneWorkoutTimerView.swift` calls `@ViewBuilder themedTimerBody(controller:)` — switch on `themeManager.current.id`
- **Watch dispatch**: `TrainingView.fullWorkoutDisplayTab` conditionally renders theme-specific overlays via `if themeManager.current.id == "<id>"` blocks (pattern from FM Tuner chrome)
- **File structure**: Each theme owns its own `Theme/Themes/<Name>Hero.swift` file (iOS: `ShuttlX/Theme/Themes/`, watch: `ShuttlX Watch App/Theme/Themes/`)
- **Watch Chrome Pattern**: Overlays placed inside the ZStack of `fullWorkoutDisplayTab` (below metrics, above background) — all overlays use `.allowsHitTesting(false)` to avoid blocking tap controls
- **Controller Reuse**: all heroes access the same `controller` / `workoutManager` data (HR, pace, distance, etc.) — no controller logic lives in theme files
- **6 Themes with Heroes**: Synthwave (speedometer needle + grid), Mixtape (dual spinning reels + tape counter), Arcade (7-segment score + INSERT COIN blink), Classic Radio (tuning needle sweep), VU Meter (dual vertical needles + dB scale), Neovim (command-line status line with elapsed time register)
- **Clean & FM Tuner**: Clean uses minimal hero (optional), FM Tuner uses existing `FMTunerHeader` + `FMTunerVUColumn` pattern

## iOS Timer Screen

- 52pt monospaced timer, 28pt bold metrics, no emoji/icons

## Watch Controls

- Circular buttons (green=pause, red=stop)
