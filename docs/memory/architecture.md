---
name: Architecture & File Map
description: Current file structure per target (October 2026, v1.10.1), key service/view/model files, data flow
type: project
---

# ShuttlX Architecture

## File Map (178 Swift files, ~27,700 non-blank lines, tests excluded)

Counts from ripgrep, October 2026 (v1.10.1 file counts; line counts not re-measured since v1.10.0). Per-file line counts were dropped: the old table was stale. Key file sizes: WatchWorkoutManager ~2,290, PhoneSyncCoordinator ~1,115, WatchSyncCoordinator ~1,220, TrainingView ~166 (+Metrics ~700, +Controls, +Running).

### iOS target (83 files, ~15,200 lines)

- **App**: ShuttlXApp.swift (DeepLinkRouter, onOpenURL), ContentView.swift (tabs Today · History · Trends · Settings)
- **Services/**: DataManager (sessions + `effectiveSessions`), PhoneSyncCoordinator (WCSession), iPhoneWorkoutController, iOSHeartRateMonitor, AnalyticsEngine, CloudKitSyncManager, AuthenticationManager, LiveActivityManager, TemplateManager, PlanManager, DeviceManager, WidgetDataProvider (reads sessions.json + segment_overrides.json), SegmentOverrideStore, SessionHeartRateLoader, HealthKitImporter, CalorieEstimationEngine (iOS overloads), FeedbackPrompt, iPhoneHapticPlayer
- **Models/**: WorkoutSport+Theme, DetectedActivity+Theme, ChartData, WorkoutActivityAttributes, WorkoutControlIntents (Live Activity intents)
- **Theme/**: ShuttlXTheme, ThemeManager, AppTheme, ThemeColors, ThemeFonts, ThemeEffects, ThemeModifiers, ThemeAssets, ThemeChartStyle, TimelineStyle, IntervalTypeThemeHelpers, Themes/CleanTheme
- **Components/**: DayRibbon (ActivityRibbon, SessionPartRow), MetricCard, ActivityBadge, PressScaleButtonStyle
- **Views/**: DashboardView (Today), Dashboard/TodayTimeline, Dashboard/LiveWorkoutCard, Workout/iPhoneWorkoutTimerView, HistoryView (calendar / list / map), HistoryMapView, SessionDetailView (FixPartSheet, HR chart), AnalyticsView, Charts/ (TrendsOverview, WeekStripView, CalendarHeatmapCard, ScrubTimelineHeroCard, WeeklyCarouselCard, ComparisonSplitCard, HRZoneChart, PaceTrendChart, WeeklyDistanceChart, ThemedLineChart, ThemedBarChart), SettingsView, HeartAlertsView ("Heart & alerts"), OnboardingView, HelpView, ProgramsTabView (pushed from Today), ProgramListView, TemplateListView, TemplateEditorView, PlanListView, PlanDetailView, PlanEditorView, RouteMapView, LiveRouteView, ElevationProfileView, IntervalResultsView, DeviceListView (no entry point in code), DevicePickerView, SignInView (unreferenced), DebugView, SyncDebugView

### watchOS target (38 files, ~8,900 lines)

- **App**: ShuttlXWatchApp.swift (WatchAppDelegate, launch recovery), ContentView.swift
- **Services/**: WatchWorkoutManager (+LocationDelegate, +HealthKitDelegates), WatchSyncCoordinator, IntervalEngine (watch copy), ActivityClassifier (watch-only), RecoverySegmenter, HealthKitAuthService, WorkoutPersistence, LiveMetricsBroadcaster, SegmentMetricsLedger, WorkoutPhaseHealthKitWriter, SegmentHygiene
- **Models/**: WorkoutSport+Theme, DetectedActivity+Theme (TrainingSession and WorkoutTemplate live in `Shared/` since Wave 4)
- **Theme/**: ShuttlXTheme, ThemeManager, AppTheme, ThemeColors, ThemeFonts, ThemeEffects, ThemeModifiers, ThemeAssets, Themes/CleanTheme
- **Components/**: MetricCard, WatchScreenParts
- **Views/**: TrainingView (+Controls, +Metrics, +Running), SafetyPromptView (SafetyPromptView, UnusualHeartRateView, WatchPromptCard), WorkoutSummaryView (EffortView), ProgramSelectionView (ProgramsListView), RecoveryWorkoutView, IntervalStepWash, DebugView

### Shared (SPM `ShuttlXShared`, 37 files, ~2,000 lines)

- **Models**: TrainingSession, WorkoutTemplate, SessionHeadline (widget slim decode), ActivitySegment, DetectedActivity, RoutePoint, TrainingPlan, BuiltInPlans, ExerciseDevice, WorkoutSport, SessionMode, HeartRateZoneCalculator, HeartSafetySettings, HeartAlertEvaluator, ActivityClassifier (SpeedActivityClassifier), SegmentEdits, PendingSessionEffort, HealthImportRules, SafetyPromptSchedule, ThemeID, FormattingUtils, CalorieEstimationEngine, DistanceFusion, MedicineVault, PausedSample, PhoneDiscardRule, WCPayloadValidation, WatchLinkRules
- **Engines**: IntervalEngine (canonical, iOS consumes it), RecoverySegmenter, HapticPlayer

### Live Activity (3 files) and widgets

- **ShuttlXLiveActivity/**: ShuttlXLiveActivity (Dynamic Island regions + lock screen), LockScreenView, bundle. Dynamic Island rendering on device is unverified.
- **ShuttlXWidgets/** (iOS, 11): StartTrainingWidget (W1), QuickStartControl (W2), WeeklyGoalRingWidget (W3), SmallWidget, MediumWidget; Shared/ (WidgetTheme, WidgetProgressShapes, WidgetTemplateProvider, WorkoutTemplateEntity, StartIntents)
- **ShuttlXWatchWidgets/** (6): QuickStartComplication, LastWorkoutComplication, WeeklyProgressComplication, TodayWorkoutComplication, WatchWidgetDataProvider, bundle

## Data Flow

```
iPhone creates template → TemplateManager.save()
  → persist to App Group → sendTemplatesToWatch() via WCSession
  → Watch receives → stores in WatchSyncCoordinator.workoutTemplates

Watch starts workout → WatchWorkoutManager.startIntervalWorkout(template)
  → HealthKit session + timer + sensors
  → Every 1s: IntervalEngine.tick() + broadcast live metrics to iPhone
  → On complete: saveWorkoutData() → TrainingSession sent via WCSession

iPhone receives session → PhoneSyncCoordinator → DataManager (sessions = stored, effectiveSessions = + SegmentEdits) → UI updates
  → AnalyticsEngine processes trends
  → Widgets read sessions.json + segment_overrides.json via WidgetDataProvider (Fix a part applied via SegmentEdits.effective)

Effort: watch updateSessionEffort → PhoneSyncCoordinator.handleSessionEffort → DataManager.applyEffort
  (parked in PendingSessionEffort if the session has not arrived)
Phone-started workout: start carries phoneSessionId → watch workoutStarted (+ sessionId) / workoutStartIgnored → iPhone watchLinked
  → Discard / stop reach the watch only while linked (PhoneDiscardRule, WatchLinkRules)
```

## Frameworks Used (zero external deps)

SwiftUI, HealthKit, WatchConnectivity, CoreLocation, CoreMotion, ActivityKit, AppIntents, UserNotifications, Combine, os.log, WatchKit, WidgetKit, MapKit, Charts, CloudKit, AuthenticationServices, StoreKit (requestReview only). iOS SPM: TelemetryDeck only.
