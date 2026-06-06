# Feature Roadmap & Phases

## Implemented (as of Build 33 / 2026-03-03)

### Core
- [x] Free Run workout (iOS + Watch)
- [x] Custom Interval Workouts — templates, editor, IntervalEngine, haptics, per-interval results
- [x] Template sync iPhone → Watch
- [x] HealthKit integration — HR, calories, distance, workout sessions
- [x] Crash recovery — local JSON backup on pause/stop

### Watch App
- [x] Home screen — Free Run + per-template cards with last-session info
- [x] Active workout view — two-tab pager (metrics + controls)
- [x] Circular controls (green=pause, red=stop)
- [x] Drift-proof DispatchSourceTimer

### Analytics & History
- [x] AnalyticsEngine — fitness/fatigue/form (TSB), VO2max estimate, personal records
- [x] Pace zone distribution, elevation summary
- [x] Weekly volume chart, fitness trend chart, HR zone chart
- [x] Training history — Day/Week/Month filter, date navigation
- [x] Session detail — route map, activity segments, interval results, km splits

### Training Plans
- [x] 3 built-in plans: Couch to 5K (8w), HIIT Starter (4w), 5K Improvement (6w)
- [x] Custom plan creation, progress tracking, dashboard card
- [x] PlanManager with start/complete/next-workout flow

### Sync & Cloud
- [x] WatchConnectivity — live metrics (3s), templates, sessions, themes
- [x] Retry queues with fallback (sendMessage → transferUserInfo)
- [x] Sign in with Apple + CloudKit sync (basic pull/push, no push-triggered)

### UI & Theming
- [x] 4 selectable themes: Clean, Synthwave, Casio LCD, Arcade
- [x] ThemeManager @Observable singleton, dual-target mirrored files
- [x] .themedCard(), .neonGlow(), .lcdPanel(), .scanlineOverlay(), .synthwaveGrid()
- [x] Theme sync iPhone → Watch via applicationContext

### Live Activity & Widgets
- [x] Dynamic Island + Lock Screen live activity during workout
- [x] 2 iOS widgets (Small: streak, Medium: stats)
- [x] 3 Watch complications (LastWorkout, WeeklyProgress, QuickStart)

### Maps & Routes
- [x] Live route map during workout, post-workout route with km pace markers
- [x] Elevation profile chart, color-coded segments
- [x] HKWorkoutRouteBuilder integration

### Other
- [x] Onboarding — 3-page first-launch flow
- [x] Settings — themes, account, Watch, HealthKit, data management

## NOT Implemented — Prioritized by User Demand

### Priority 1: Highest Impact (Subscription-worthy)
1. **Voice/Audio Coaching** — interval announcements, pace/HR zone alerts, km milestones via Watch speaker (AVSpeechSynthesizer). #1 most requested feature across all running apps.
2. **Export & Sharing** — GPX export, share workout as image/link, basic Strava integration. Users expect data portability.
3. **StoreKit Subscriptions** — paywall infrastructure, premium tier, free trial. Required before gating any features.

### Priority 2: Quick Wins
4. **Cadence (SPM)** — CMPedometer data already captured, just compute steps/minute and display. Low effort, high value.
5. **Auto-Pause** — pause workout at stoplights/stops, resume on movement. Top user complaint when missing.
6. **Custom Fonts** — bundle 7-segment (Casio) & pixel (Arcade) OFL fonts. Theme polish.
7. **Pace/HR Alerts** — configurable alerts when pace or HR exits target zone.

### Priority 3: Growth
8. **Multi-Sport Sensors** — cycling cadence, swim stroke count, hiking altitude gain. Model supports 8 sports but only run/walk have real sensor stacks.
9. **Route Navigation** — follow pre-planned routes on Watch. High differentiation (WorkOutDoors' main draw).
10. **Social Sharing** — share templates, workout summaries, leaderboards.

### Priority 4: Advanced
11. **Adaptive Training Plans** — AI-adjusted plans based on performance/fatigue (like Runna).
12. **Template Marketplace** — browse/download community interval templates.

## Partial Implementations (need completion)
- **Multi-Sport**: 8 sport types in model + HealthKit mapping, but non-running sports lack dedicated sensors/UI
- **Cadence**: Step count tracked via CMPedometer, SPM not computed
- **CloudKit**: Basic sync works, no push-triggered sync or conflict UI

## Decision Log
| Date | Decision | Status |
|------|----------|--------|
| 2026-02-28 | Custom Interval Workouts = #1 priority | ✅ Done (Build 21) |
| 2026-03-01 | Unified design system tokenization | ✅ Done |
| 2026-03-03 | Dynamic theme system: 4 themes | ✅ Done (Build 29) |
| 2026-03-03 | Watch home screen redesign | ✅ Done (Build 30-32) |
| 2026-03-03 | iOS Free Run as built-in program | ✅ Done (Build 33) |
