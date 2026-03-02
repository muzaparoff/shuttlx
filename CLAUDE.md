# ShuttlX

Interval training app for iOS (18.0+) and watchOS (11.5+) built with SwiftUI. Zero external dependencies.

- **Bundle**: `com.shuttlx.ShuttlX` / `com.shuttlx.ShuttlX.watchkitapp`
- **Team**: `83HPSY452Y`
- **App Group**: `group.com.shuttlx.shared`
- **CloudKit**: `iCloud.com.shuttlx.app`
- **Codebase**: ~12,300 LOC across 91 Swift files
- **CI**: GitHub Actions → App Store Connect → TestFlight (auto on push to main)

## Targets

| Target | Scheme | Files | Key Files |
|--------|--------|-------|-----------|
| iOS | `ShuttlX` | 47 | SharedDataManager (605), AnalyticsView (514), SettingsView (322) |
| watchOS | `ShuttlX Watch App` | 24 | WatchWorkoutManager (944), TrainingView (357), SharedDataManager (525) |
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
```

## Data Storage

- JSON files in App Group container: `sessions.json`, `workout_templates.json`
- Sync: WatchConnectivity (`sendMessage` + `transferUserInfo` + `applicationContext`)
- HealthKit: workout sessions, heart rate, distance, calories

## Development Rules

- **Build both platforms after every change**: `bash tests/build_and_test_both_platforms.sh --clean --build`
- **Zero external dependencies** — Apple frameworks only
- **Discuss features before implementing** — never start without explicit approval
- **Apple Fitness-style UI**: big bold numbers, minimal icons, clean design
- **Models are duplicated** between iOS and watchOS — update BOTH copies when changing

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
