---
globs:
  - "**/Views/**"
  - "**/Components/**"
  - "**/Theme/**"
---

# Design System Rules

All new UI code must follow these conventions. Existing code should be migrated when touched.

## Signature Shape DNA

Each theme owns ONE signature shape, reused across surfaces so the whole app feels themed without redesigning every screen per theme:

| Theme | Signature shape |
|---|---|
| Clean | soft glass ring |

Reuse as: chart frame, progress indicator, summary medal, empty/loading state. One parametric `Canvas` per theme — never N illustrations per state.

### Themed vs Neutral Surfaces

- **Themed** (must carry full identity, dispatch on `themeManager.current.id`): dashboard hero, analytics data-viz, workout summary/celebration, empty states, watch home, timer
- **Neutral** (theme colors only — keep legible): forms, settings rows, sign-in, paywall, plan/template editors, maps (accent polyline only), modal sheets
- **Anti-goals**: no idle animations (watch battery), no per-theme icon sets (SF Symbols + tint), Clean stays the calm cardiac-patient accessibility baseline, chrome never competes with data
- Raw semantic fonts (`.font(.body)`, `.font(.headline)`) are violations on themed surfaces — they block per-theme typography; use `ShuttlXFont.*`

## Theme System

- 1 theme: **Clean** (October 2026 deleted Mixtape; the July 2026 reduction deleted Synthwave, Arcade, Classic Radio, Neovim, FM Tuner and VU Meter). The system still supports adding themes — register in `AppTheme.all` and `ThemeID.valid`. Saved/synced ids outside `ThemeID.valid` fall back to `clean`
- `ThemeManager.shared` is the `@Observable` singleton — injected via `.environment(ThemeManager.shared)` at app root
- **Theme switching**: always call `ThemeManager.shared.selectTheme(id)` — never set `selectedThemeID` directly
- `current` is a stored `@Observable` property (not computed) — ensures SwiftUI re-renders on theme change
- Views can access theme via `@Environment(ThemeManager.self) var themeManager` then `themeManager.colors.*`, `themeManager.fonts.*`
- `ShuttlXColor.*` and `ShuttlXFont.*` enums **bridge** to `ThemeManager.shared` — existing code is automatically theme-aware
- Theme files: `ShuttlX/Theme/` (iOS) and `ShuttlX Watch App/Theme/` (watchOS) — mirrored
- Theme ID persisted in App Group UserDefaults, synced to Watch via WCSession

## Screen Backgrounds

- Use `.themedScreenBackground()` on every major screen's outermost container (NavigationStack, ScrollView, List, TabView)
- Switches automatically per active theme: mesh gradient (Clean)
- Background modifier: `.cleanMeshBackground()` (called directly by `.themedScreenBackground()` while there is a single theme)
- `MeshGradient` is iOS-only — watchOS Clean theme uses `LinearGradient` fallback
- All background overlays use `.allowsHitTesting(false)` and `.ignoresSafeArea()`

## Cards & Containers

- Flat screens (Today, History, Trends and its detail screens, Session detail, `MetricCard`) use `.timelineCard()` + `.timelineScreenBackground()` (`Theme/TimelineStyle.swift`); `.themedCard()` remains for the glass look elsewhere
- Use `.themedCard()` for all card containers — adapts per theme via `ThemeEffects.CardStyle`: `.glass` (Clean)
- `.glassBackground(cornerRadius:)` still available as a fallback for Clean-only contexts
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
- `ActivityRibbon` / `SessionPartRow` — per-part timeline ribbon and row (`ShuttlX/Components/DayRibbon.swift`), used on Today cards and SessionDetailView

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

No theme currently ships a custom hero: Clean is the minimal, calm accessibility baseline and both timers render the shared layout (iOS `standardTimerBody`, watch `fullWorkoutDisplayTab`). If a theme adds one later, dispatch on `themeManager.current.id` (iOS in `iPhoneWorkoutTimerView`, watch in `TrainingView+Metrics`), keep the hero in its own file under `Theme/Themes/`, reuse the same `controller` / `workoutManager` data, and mark overlays `.allowsHitTesting(false)`.

## iOS Timer Screen

- 52pt monospaced timer, 28pt bold metrics, no emoji/icons

## Watch Controls

- Circular buttons (green=pause, red=stop)
