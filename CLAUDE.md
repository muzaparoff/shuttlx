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
| iOS | `ShuttlX` | 59 | SharedDataManager (605), AnalyticsView (514), ThemeManager + 12 theme files |
| watchOS | `ShuttlX Watch App` | 36 | WatchWorkoutManager (944), TrainingView (357), ThemeManager + 12 theme files |
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
- 6 themes: Clean (glass cards, system fonts), Synthwave (neon glow, monospaced), Mixtape (blue portable player, green LCD), Arcade (heavy weights, pixel borders), Classic Radio (warm brown, cream/amber), VU Meter (dark panel, amber gauges)
- **Screen backgrounds**: `.themedScreenBackground()` on all major views — Clean: MeshGradient (iOS)/LinearGradient (watchOS), Synthwave: horizon grid, Mixtape: blue body + texture lines, Arcade: CRT scanlines+vignette, Classic Radio: warm brown grain + vignette, VU Meter: amber glow + panel lines
- View modifiers: `.themedCard()`, `.neonGlow()`, `.lcdPanel()`, `.scanlineOverlay()`, `.synthwaveGrid()`
- Files: 12 per target under `Theme/` (ThemeColors, ThemeFonts, ThemeEffects, AppTheme, ThemeManager, ThemeModifiers, Themes/Clean, Themes/Synthwave, Themes/Mixtape, Themes/Arcade, Themes/ClassicRadio, Themes/VUMeter)

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
- **Dynamic multi-theme UI**: 6 themes (Clean, Synthwave, Mixtape, Arcade, Classic Radio, VU Meter) — selectable in Settings
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

## Agents

| Agent | Purpose | Model |
|-------|---------|-------|
| `senior-ios-developer` | Review + implement iOS/watchOS tasks with Apple platform best practices | sonnet |
| `senior-architect` | Architecture, data structures, monitoring, production tooling review + implementation | opus |
| `app-auditor` | Pre-release readiness audit (crash risks, metadata, features) | sonnet |
| `design-reviewer` | UI/UX + Apple HIG compliance review | sonnet |
| `growth-strategist` | ASO, marketing, solo-dev launch strategy | opus |
| `accessibility-auditor` | VoiceOver, Dynamic Type, contrast, a11y | sonnet |
| `performance-auditor` | Memory, battery, render efficiency, watchOS limits | sonnet |
| `security-reviewer` | Entitlements, data protection, secrets, privacy | sonnet |
| `watch-debugger` | watchOS workout/sync/HealthKit/timer debugging | sonnet |

### Agent Routing Rules

**Run in PARALLEL (independent, read-only):**
- `app-auditor` + `design-reviewer` + `growth-strategist` → pre-release report
- `accessibility-auditor` + `performance-auditor` + `security-reviewer` → code health report
- `senior-architect` (review mode) can run in parallel with read-only auditors

**Run SEQUENTIALLY (output feeds the next):**
- `app-auditor` → `senior-ios-developer` (fix what auditor found)
- `design-reviewer` → `senior-ios-developer` (apply UI changes)
- `senior-architect` (review) → `senior-ios-developer` (implement architecture fixes)
- `senior-architect` (review) → `senior-architect` (implement tooling)

**Never parallelize:**
- `senior-ios-developer` + any other writing agent (writes to Swift files)
- `senior-architect` (implement mode) + `senior-ios-developer` (overlapping scope)
- Any two agents that write to the same Swift files

## Frameworks Used

SwiftUI, HealthKit, WatchConnectivity, CoreLocation, CoreMotion, ActivityKit, Combine, os.log, WatchKit
