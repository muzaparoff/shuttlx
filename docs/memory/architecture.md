---
name: Architecture & File Map
description: Current file structure, LOC, key service/view/model files, data flow
type: project
---

# ShuttlX Architecture

## File Map (120+ files, ~13,300 LOC)

### iOS Target (65 files, ~7,900 LOC)

| File | Lines | Purpose |
|------|-------|---------|
| **App** | | |
| ShuttlXApp.swift | 40 | App entry, environment setup |
| ContentView.swift | 66 | Tab bar: Dashboard / Programs / History / Settings |
| **Services/** | | |
| SharedDataManager.swift | 605 | WatchConnectivity sync, live metrics |
| iPhoneWorkoutController.swift | 780+ | Core iOS workout engine, HealthKit, pace rolling-window |
| AnalyticsEngine.swift | 413 | Data analytics, trends, weekly stats |
| CloudKitSyncManager.swift | 247 | CloudKit sync |
| DataManager.swift | 153 | Session persistence, HealthKit queries |
| PlanManager.swift | 148 | Training plan CRUD |
| AuthenticationManager.swift | 137 | Sign-in/auth flow |
| LiveActivityManager.swift | 136 | Lock Screen / Dynamic Island |
| TemplateManager.swift | 78 | Template CRUD + auto-sync to Watch |
| WidgetDataProvider.swift | 57 | Widget data bridge |
| **Models/** (8 shared with watchOS) | | |
| TrainingSession.swift | 148 | Session model (segments, intervals, route) |
| TrainingPlan.swift | 114 | Multi-week plan definition |
| BuiltInPlans.swift | 107 | Preset training plans |
| WorkoutTemplate.swift | 95 | Interval program definition |
| WorkoutSport.swift | 88 | Sport type enum + metadata |
| ActivitySegment.swift | 60 | Running/walking/stationary tracking |
| RoutePoint.swift | 19 | GPS coordinate |
| ExerciseDevice.swift | 70+ | Device type enum + metadata (6 built-in + custom) |
| ChartData.swift | 81 | Chart helpers (iOS only) |
| WorkoutActivityAttributes.swift | 17 | Live Activity attributes (iOS only) |
| **Theme/** (16 files, 8 themes) | | |
| ThemeManager.swift | 80+ | @Observable theme manager, persistence, WCSession sync |
| AppTheme.swift | 40+ | Theme struct: colors + fonts + effects |
| ThemeColors.swift | 120+ | ~40 color tokens per theme |
| ThemeFonts.swift | 80+ | ~20 font tokens per theme |
| ThemeEffects.swift | 50+ | Visual effects config (glow, scanlines, grid) |
| ThemeModifiers.swift | 200+ | View modifiers: themedCard, neonGlow, lcdPanel, etc. |
| Themes/Clean.swift | 60+ | Theme definition |
| Themes/Synthwave.swift | 60+ | Synthwave theme |
| Themes/Mixtape.swift | 60+ | Mixtape theme |
| Themes/Arcade.swift | 60+ | Arcade theme |
| Themes/ClassicRadio.swift | 60+ | Classic Radio theme |
| Themes/VUMeter.swift | 60+ | VU Meter theme |
| Themes/Neovim.swift | 60+ | Neovim theme |
| Themes/FMTuner.swift | 60+ | FM Tuner theme |
| Themes/*Hero.swift | 150–300 ea | Per-theme hero visualizations (Synthwave, Mixtape, Arcade, ClassicRadio, VUMeter, Neovim) |
| Components/FMTunerHeader.swift | 100+ | FM Tuner chrome header (iOS) |
| Components/FMTunerVUColumn.swift | 100+ | FM Tuner VU meter column (iOS) |
| **Views/** | | |
| Workout/iPhoneWorkoutTimerView.swift | 420+ | Active workout timer + metrics + hero dispatch |
| AnalyticsView.swift | 514 | Analytics & trends |
| TrainingHistoryView.swift | 234 | Session list with filter/sort |
| SettingsView.swift | 322 | App settings |
| SessionDetailView.swift | 269 | Full session breakdown |
| TemplateEditorView.swift | 257 | Create/edit intervals |
| OnboardingView.swift | 214 | First-launch flow |
| PlanDetailView.swift | 191 | Plan details & preview |
| SyncDebugView.swift | 170 | Debug sync |
| PlanEditorView.swift | 170 | Create/edit plans |
| TemplateListView.swift | 165 | Template list + empty state |
| IntervalResultsView.swift | 137 | Per-interval performance |
| RouteMapView.swift | 182 | GPS route on map |
| DashboardView.swift | 124 | Home dashboard |
| SessionRowView.swift | 122 | Session list row |
| DebugView.swift | 122 | Debug tools |
| ProgramsTabView.swift | 111 | Programs/plans tab |
| PlanListView.swift | 109 | Training plans list |
| ElevationProfileView.swift | 142 | Elevation chart |
| SignInView.swift | 85 | Login screen |
| LiveRouteView.swift | 69 | Route during workout |
| ProgramListView.swift | 61 | Quick programs |
| **Dashboard Cards** | | |
| Dashboard/LiveWorkoutCard.swift | 133 | Real-time watch metrics |
| Dashboard/WeekSummaryCard.swift | 108 | Weekly stats |
| Dashboard/StartOnWatchCard.swift | 45 | Start CTA |
| Dashboard/LastWorkoutCard.swift | 86 | Recent session |
| Dashboard/PlanProgressCard.swift | 66 | Plan progress |
| Dashboard/FreeRunCard.swift | 150+ | Free Run quick-start card (iOS) |
| **Charts** | | |
| Charts/WeekStripView.swift | 94 | Week overview strip |
| Charts/PaceTrendChart.swift | 73 | Pace trends |
| Charts/WeeklyDistanceChart.swift | 63 | Distance per week |
| Charts/HRZoneChart.swift | 56 | Heart rate zones |
| **Utilities** | | |
| Utilities/FormattingUtils.swift | 66 | String/number formatting |
| Components/MetricCard.swift | 38 | Metric display card |
| Components/ActivityBadge.swift | 28 | Activity type pill |
| Components/StreakBadge.swift | 23 | Streak display |

### watchOS Target (38+ files, ~4,600 LOC)

| File | Lines | Purpose |
|------|-------|---------|
| **App** | | |
| ShuttlXWatchApp.swift | 53 | Watch app entry, theme injection |
| ContentView.swift | 38 | Root navigation |
| **Services/** | | |
| WatchWorkoutManager.swift | 944 | Core watch workout engine, HealthKit, sensors, pace rolling-window |
| SharedDataManager.swift | 525 | Watch-side WatchConnectivity |
| IntervalEngine.swift | 134 | Interval countdown state machine |
| **Models/** (8 shared with iOS) | | |
| ActivitySegment.swift | 60 | Running/walking/stationary tracking |
| BuiltInPlans.swift | 107 | Preset training plans |
| RoutePoint.swift | 19 | GPS coordinate |
| TrainingPlan.swift | 114 | Multi-week plan definition |
| TrainingSession.swift | 148 | Session model |
| WorkoutSport.swift | 88 | Sport type enum |
| WorkoutTemplate.swift | 95 | Interval program definition |
| ExerciseDevice.swift | 70+ | Device type enum |
| **Theme/** (16 files, 8 themes) | | |
| ThemeManager.swift | 80+ | @Observable theme manager (same as iOS) |
| AppTheme.swift | 40+ | Theme struct (same as iOS) |
| ThemeColors.swift | 120+ | ~40 color tokens (same as iOS) |
| ThemeFonts.swift | 80+ | ~20 font tokens (watch-sized) |
| ThemeEffects.swift | 50+ | Visual effects (watch variant) |
| ThemeModifiers.swift | 200+ | View modifiers (watch-sized) |
| Themes/*.swift | 60+ ea | 8 theme definitions (watch-sized) |
| Themes/*Hero.swift | 80–150 ea | Per-theme hero visualizations (compact for watch) |
| Components/FMTunerCompactHeader.swift | 60+ | FM Tuner compact header (watch) |
| Components/FMTunerWatchVUColumn.swift | 60+ | FM Tuner VU meter (watch) |
| **Views/** | | |
| TrainingView.swift | 357 | Active workout UI (timer + metrics + hero overlays + controls) |
| ProgramSelectionView.swift | 200 | Program picker |
| DebugView.swift | 113 | Watch debug console |
| **Utilities** | | |
| Utilities/FormattingUtils.swift | 50 | Watch formatting |
| Components/MetricCard.swift | 28 | Watch metric card |
| **Widgets/** | | |
| ShuttlXWatchWidgets.swift | 10 | Widget bundle entry |
| LastWorkoutComplication.swift | 89 | Last workout complication |
| WeeklyProgressComplication.swift | 58 | Weekly progress |
| QuickStartComplication.swift | 47 | Quick start |
| WatchWidgetDataProvider.swift | 33 | Widget data provider |

### Live Activity Extension (3 files, ~226 LOC)

| File | Lines | Purpose |
|------|-------|---------|
| ShuttlXLiveActivityBundle.swift | 9 | Bundle entry |
| ShuttlXLiveActivity.swift | 105 | Main Live Activity view |
| LockScreenView.swift | 112 | Lock screen widget |

### Widgets Extension (3 files, ~264 LOC)

| File | Lines | Purpose |
|------|-------|---------|
| ShuttlXWidgetsBundle.swift | 10 | Bundle entry |
| SmallWidget.swift | 94 | Home screen widget (small) |
| MediumWidget.swift | 160 | Home screen widget (medium) |

## Data Flow

```
iPhone creates template → TemplateManager.save()
  → persist to App Group → sendTemplatesToWatch() via WCSession
  → Watch receives → stores in SharedDataManager.workoutTemplates

Watch starts workout → WatchWorkoutManager.startIntervalWorkout(template)
  → HealthKit session + DispatchSourceTimer + sensors (CMPedometer, CMMotionActivity)
  → Every 1s: IntervalEngine.tick() + metrics computed (HR, pace rolling-window, distance, cadence)
  → Broadcast live metrics to iPhone via WCSession
  → On complete: saveWorkoutData() → TrainingSession sent via WCSession

iPhone receives session → SharedDataManager → DataManager → persists → UI updates
  → AnalyticsEngine processes trends, computes VO2max/TSB/PRs
  → WidgetDataProvider refreshes widgets
  → LiveActivityManager updates Dynamic Island during active workout

Theme changes:
  iPhone: Settings → ThemeManager.shared.selectTheme(id) → UserDefaults (App Group)
    → SharedDataManager.sendThemeToWatch() via applicationContext
  Watch: receives → ThemeManager.shared.selectedThemeID → UI re-renders
```

## Key Architectural Patterns

### Controllers vs. Managers
- **iPhoneWorkoutController** — stateful workout engine for iOS (HealthKit, timers, metrics)
- **WatchWorkoutManager** — stateful workout engine for watch (HealthKit, sensors, metrics)
- Both compute metrics independently with equivalent algorithms (pace rolling-window, cadence fallback, etc.)

### Theme Dispatch
- iOS: Switch on `themeManager.current.id` in `iPhoneWorkoutTimerView` to select hero component
- watchOS: Conditional `if themeManager.current.id == "<name>"` blocks in `TrainingView.fullWorkoutDisplayTab`

### Dual-Target Model Duplication
8 models are currently duplicated between `ShuttlX/Models/` and `ShuttlX Watch App/Models/`. Tracked as tech debt; Phase 5 (Watch/iOS unification) will move to shared SPM package.

## Frameworks Used

SwiftUI, HealthKit, WatchConnectivity, CoreLocation, CoreMotion, ActivityKit, Combine, os.log, WatchKit, CloudKit, AuthenticationServices
