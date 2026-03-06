# ShuttlX

Interval training app for iOS (18.0+) and watchOS (11.5+) built with SwiftUI. Zero external dependencies.

- **Bundle**: `com.shuttlx.ShuttlX` / `com.shuttlx.ShuttlX.watchkitapp`
- **Team**: `83HPSY452Y`
- **App Group**: `group.com.shuttlx.shared`
- **CloudKit**: `iCloud.com.shuttlx.app`
- **Codebase**: ~12,800 LOC across 111 Swift files
- **CI**: GitHub Actions → App Store Connect → TestFlight (auto on push to main)

## Targets

| Target | Scheme | Files | Key Files |
|--------|--------|-------|-----------|
| iOS | `ShuttlX` | 57 | SharedDataManager (605), AnalyticsView (514), ThemeManager + 10 theme files |
| watchOS | `ShuttlX Watch App` | 34 | WatchWorkoutManager (944), TrainingView (357), ThemeManager + 10 theme files |
| Live Activity | `ShuttlXLiveActivity` | 3 | ShuttlXLiveActivity, LockScreenView |
| Widgets | `ShuttlXWidgets` | 3 | SmallWidget, MediumWidget |

## Build Commands

```bash
# Build both platforms (simulator)
bash tests/build_and_test_both_platforms.sh --clean --build

# Build for physical device
bash tests/build_for_physical_device.sh

# iOS only
xcodebuild -project ShuttlX.xcodeproj -scheme ShuttlX -sdk iphonesimulator build

# watchOS only
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlX Watch App" -sdk watchsimulator build
```

## Architecture

```
iPhone creates template → TemplateManager.save()
  → persist to App Group → sendTemplatesToWatch() via WCSession
  → Watch receives → stores in SharedDataManager.workoutTemplates

Watch starts workout → WatchWorkoutManager.startIntervalWorkout(template)
  → HealthKit session + timer + sensors
  → Every 1s: IntervalEngine.tick() + broadcast live metrics to iPhone
  → On complete: saveWorkoutData() → TrainingSession sent via WCSession

iPhone receives session → SharedDataManager → DataManager → UI updates

Theme sync:
  iPhone: Settings → ThemeManager.selectedThemeID → UserDefaults (App Group)
    → SharedDataManager.sendThemeToWatch() via applicationContext
  Watch: receives → ThemeManager.shared.selectedThemeID → UI updates
```

## Theme System

- `ThemeManager` (`@Observable` singleton) manages active theme, persists to App Group UserDefaults
- **Switching**: call `ThemeManager.shared.selectTheme(id)` — never set `selectedThemeID` directly
- `current` is a **stored** property (not computed) — ensures `@Observable` generates proper tracking
- `ShuttlXColor.*` / `ShuttlXFont.*` enums bridge to `ThemeManager.shared` — all existing code is theme-aware
- Theme structs: `AppTheme` → `ThemeColors` (~40 tokens) + `ThemeFonts` (~20 tokens) + `ThemeEffects`
- 4 themes: Clean (glass cards, system fonts), Synthwave (neon glow, monospaced), Casio LCD (amber/green, monospaced), Arcade (heavy weights, pixel borders)
- **Screen backgrounds**: `.themedScreenBackground()` on all major views — Clean: MeshGradient (iOS)/LinearGradient (watchOS), Synthwave: horizon grid, Casio: dot-matrix, Arcade: CRT scanlines+vignette
- View modifiers: `.themedCard()`, `.neonGlow()`, `.lcdPanel()`, `.scanlineOverlay()`, `.synthwaveGrid()`
- Files: 10 per target under `Theme/` (ThemeColors, ThemeFonts, ThemeEffects, AppTheme, ThemeManager, ThemeModifiers, Themes/Clean, Themes/Synthwave, Themes/Casio, Themes/Arcade)

## Data Storage

- JSON files in App Group container: `sessions.json`, `workout_templates.json`
- Theme selection: App Group UserDefaults key `selectedThemeID`
- Sync: WatchConnectivity (`sendMessage` + `transferUserInfo` + `applicationContext`)
- HealthKit: workout sessions, heart rate, distance, calories

## Development Rules

- **Build both platforms after every change**: `bash tests/build_and_test_both_platforms.sh --clean --build`
- **Zero external dependencies** — Apple frameworks only
- **Discuss features before implementing** — never start without explicit approval
- **Plan before implementing**: analyze codebase, identify affected files, create a plan, then implement
- **Dynamic multi-theme UI**: 4 themes (Clean, Synthwave, Casio LCD, Arcade) — selectable in Settings
- **Models are duplicated** between iOS and watchOS — update BOTH copies when changing
- **Theme files are duplicated** between iOS (`ShuttlX/Theme/`) and watchOS (`ShuttlX Watch App/Theme/`) — update BOTH when changing
- **Always update docs**: when adding/changing features, update CLAUDE.md, relevant `.claude/rules/`, `.claude/agents/`, `.claude/skills/`, and memory files to reflect the current architecture and status

## Path-Scoped Rules

Additional rules load automatically based on the files being edited:

| Rule | Applies to | Content |
|------|-----------|---------|
| `.claude/rules/design-system.md` | `**/Views/**`, `**/Components/**`, `**/Theme/**` | Colors, fonts, cards, accessibility, layout |
| `.claude/rules/services.md` | `**/Services/**` | Thread safety, error handling, sync patterns |
| `.claude/rules/watchos.md` | `ShuttlX Watch App/**` | Watch-specific constraints, timer, workout |
| `.claude/rules/models.md` | `**/Models/**` | Model conventions, dual-target sync |

## Slash Commands

- `/build` — Build both platforms, report pass/fail
- `/deploy` — Push to main, monitor CI, report TestFlight result
- `/review-changes` — Check git diff against design system & safety rules

## Frameworks Used

SwiftUI, HealthKit, WatchConnectivity, CoreLocation, CoreMotion, ActivityKit, Combine, os.log, WatchKit
