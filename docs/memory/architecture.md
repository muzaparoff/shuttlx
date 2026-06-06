# ShuttlX Architecture

## File Map (91 files, ~12,300 LOC)

### iOS Target (47 files, ~7,700 LOC)

| File | Lines | Purpose |
|------|-------|---------|
| **App** | | |
| ShuttlXApp.swift | 40 | App entry, environment setup |
| ContentView.swift | 66 | Tab bar: Dashboard / Programs / History / Settings |
| **Services/** | | |
| SharedDataManager.swift | 605 | WatchConnectivity sync, live metrics |
| AnalyticsEngine.swift | 413 | Data analytics, trends, weekly stats |
| CloudKitSyncManager.swift | 247 | CloudKit sync |
| DataManager.swift | 153 | Session persistence, HealthKit queries |
| PlanManager.swift | 148 | Training plan CRUD |
| AuthenticationManager.swift | 137 | Sign-in/auth flow |
| LiveActivityManager.swift | 136 | Lock Screen / Dynamic Island |
| TemplateManager.swift | 78 | Template CRUD + auto-sync to Watch |
| WidgetDataProvider.swift | 57 | Widget data bridge |
| **Models/** | | |
| TrainingSession.swift | 148 | Session model (segments, intervals, route) |
| TrainingPlan.swift | 114 | Multi-week plan definition |
| BuiltInPlans.swift | 107 | Preset training plans |
| WorkoutTemplate.swift | 95 | Interval program definition |
| WorkoutSport.swift | 88 | Sport type enum + metadata |
| ChartData.swift | 81 | Chart helpers (iOS only) |
| ActivitySegment.swift | 60 | Running/walking/stationary tracking |
| RoutePoint.swift | 19 | GPS coordinate |
| WorkoutActivityAttributes.swift | 17 | Live Activity attributes (iOS only) |
| **Theme & Utilities** | | |
| Theme/ShuttlXTheme.swift | 174 | Static color/font tokens (legacy, being replaced by dynamic theme) |
| Theme/ThemeManager.swift | — | @Observable theme manager, persistence, WCSession sync (PLANNED) |
| Theme/AppTheme.swift | — | Theme struct: colors + fonts + effects (PLANNED) |
| Theme/ThemeColors.swift | — | ~40 color tokens per theme (PLANNED) |
| Theme/ThemeFonts.swift | — | ~20 font tokens per theme (PLANNED) |
| Theme/ThemeEffects.swift | — | Visual effects config (glow, scanlines, grid) (PLANNED) |
| Theme/ThemeModifiers.swift | — | View modifiers: themedCard, neonGlow, lcdPanel (PLANNED) |
| Theme/Themes/*.swift | — | 4 theme definitions: Clean, Synthwave, Casio, Arcade (PLANNED) |
| Utilities/FormattingUtils.swift | 66 | String/number formatting |
| **Components** | | |
| Components/MetricCard.swift | 38 | Metric display card |
| Components/ActivityBadge.swift | 28 | Activity type pill |
| Components/StreakBadge.swift | 23 | Streak display |
| **Views/** | | |
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
| **Charts** | | |
| Charts/WeekStripView.swift | 94 | Week overview strip |
| Charts/PaceTrendChart.swift | 73 | Pace trends |
| Charts/WeeklyDistanceChart.swift | 63 | Distance per week |
| Charts/HRZoneChart.swift | 56 | Heart rate zones |

### watchOS Target (24 files, ~4,300 LOC)

| File | Lines | Purpose |
|------|-------|---------|
| **App** | | |
| ShuttlXWatchApp.swift | 53 | Watch app entry |
| ContentView.swift | 38 | Root navigation |
| **Services/** | | |
| WatchWorkoutManager.swift | 944 | Core workout engine, HealthKit, sensors |
| SharedDataManager.swift | 525 | Watch-side WatchConnectivity |
| IntervalEngine.swift | 134 | Interval countdown state machine |
| **Models/** (7 files, duplicated from iOS) | | |
| ActivitySegment.swift | 60 | |
| BuiltInPlans.swift | 107 | |
| RoutePoint.swift | 19 | |
| TrainingPlan.swift | 114 | |
| TrainingSession.swift | 148 | |
| WorkoutSport.swift | 88 | |
| WorkoutTemplate.swift | 95 | |
| **Theme & Utilities** | | |
| Theme/ShuttlXTheme.swift | 156 | Watch color/font variants (legacy, being replaced by dynamic theme) |
| Utilities/FormattingUtils.swift | 50 | Watch formatting |
| Components/MetricCard.swift | 28 | Watch metric card |
| **Views/** | | |
| ProgramSelectionView.swift | 200 | Program picker |
| TrainingView.swift | 357 | Active workout UI (timer + metrics + controls) |
| DebugView.swift | 113 | Watch debug console |
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
  → HealthKit session + timer + sensors
  → Every 1s: IntervalEngine.tick() + broadcast live metrics to iPhone
  → On complete: saveWorkoutData() → TrainingSession sent via WCSession

iPhone receives session → SharedDataManager → DataManager → UI updates
  → AnalyticsEngine processes trends → WidgetDataProvider updates widgets
```

## Frameworks Used (zero external deps)

SwiftUI, HealthKit, WatchConnectivity, CoreLocation, CoreMotion, ActivityKit, Combine, os.log, WatchKit, CloudKit, AuthenticationServices
