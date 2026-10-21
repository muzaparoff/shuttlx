# ShuttlX Project Memory

## Quick Reference
- **App**: Interval training iOS + watchOS companion app (SwiftUI; iOS has TelemetryDeck via SPM only, no RevenueCat/StoreKit code; watch is Apple-frameworks-only)
- **ShuttlXShared package** (`Shared/`, July 2026): single source for most models (RoutePoint, TrainingPlan, BuiltInPlans, ExerciseDevice, WorkoutSport core, SessionMode, ActivitySegment, DetectedActivity, HRZC, FormattingUtils) + canonical IntervalEngine (iOS consumes; watch still on its own engine until Phase 4). TrainingSession + WorkoutTemplate still duplicated per target (IntervalType name collision blocks the move)
- **Sync coordinators renamed** (July 2026): iOS `PhoneSyncCoordinator` / watch `WatchSyncCoordinator` (formerly both `SharedDataManager`)
- **pbxproj quirk**: `ShuttlX/` files need explicit pbxproj refs; `ShuttlX Watch App/` is a synchronized folder (file adds/renames free); `Shared/` is SPM. Filenames with `+` must be quoted in pbxproj paths
- **Bundle**: `com.shuttlx.ShuttlX` / `com.shuttlx.ShuttlX.watchkitapp`
- **Team**: `83HPSY452Y`, App Group: `group.com.shuttlx.shared`
- **Targets**: iOS 18.0+, watchOS 11.5+, Live Activity extension, Widgets extension
- **Codebase**: ~27,700 non-blank lines across 164 Swift files (82 iOS, 40 watchOS, 22 Shared, 11 iOS widgets, 6 watch widgets, 3 Live Activity)
- **Storage**: JSON in App Group container (sessions.json, workout_templates.json, exercise_devices.json, segment_overrides.json v2 SegmentEdits); UserDefaults `pendingSessionEffort`
- **Sync**: WatchConnectivity (sendMessage + transferUserInfo + applicationContext)
- **CI**: GitHub Actions → App Store Connect → TestFlight (auto on push to main)

## Assets
- [App Store Screenshots](./reference_screenshots.md) — stored at `/Users/sergeymuzyukin/Desktop/ShuttlX-Screenshots/`

## Detailed Notes
- [Architecture & File Map](./architecture.md)
- [Feature Roadmap & Phases](./roadmap.md)
- [Technical Debt & Known Issues](./tech-debt.md)
- [Sync Architecture & Known Bug](./sync-architecture.md)
- [WCSession Payload Routing](./sync-payload-routing.md) — 65.5KB dictionary cap, fixed 50-200KB dead zone that lost long sessions, transferFile routing (commit 48d3694)
- [Free-run Timer Stall Incident](./project_freerun_timer_incident.md) — 2026-08-04 sync-storm/tick-starvation fix + first-launch orphan-recovery race; device verification pending
- [Cadence (RPM/SPM) Derivation](./cadence-derivation.md) — why CAD card was hidden, CMPedometer warmup quirk, step-delta fallback
- [Social Features & Supabase Plan](./social-backend-plan.md) — 7-phase plan for user registration, social, Supabase backend

## User Preferences
- Discuss each feature before implementing — never start without explicit approval
- [Self-review before handoff](./feedback_self_review_before_handoff.md) — fix obvious defects (truncation/clipped text/unreadable values) before presenting prototypes/screenshots for review
- [Prefers authentic real assets](./feedback_authentic_assets.md) — for skeuomorphic themes, source real CC0/PD imagery over hand-drawn vectors; always verify license before embedding
- **Always plan first**: analyze codebase before implementing, identify affected files
- **Always update docs**: after any feature change, update CLAUDE.md, .claude/rules/, .claude/agents/, .claude/skills/, and memory files
- Theme system reduced to **1 theme: Clean** (July 2026: 7 to 2; Oct 2026: Mixtape deleted on owner approval). `ThemeID.valid` in `Shared/ThemeID.swift`; unknown saved/synced ids fall back to clean
- Wants subscription-ready product — features need to justify payment
- Timer screen: 52pt monospaced timer, 28pt bold metrics, no emoji/icons
- Watch controls: circular buttons (green=pause, red=stop)

## Feature Status (v1.10.0 / 2026-10-21, timeline redesign)
**Done**: Core workout, intervals, Watch app (timeline-mockup screens, crash recovery resumes the workout), sync, analytics (VO2max/TSB/PRs), training plans (3 built-in), themes (1: Clean), Live Activity (Pause/Resume + End & Save intents), iOS widgets Tier 1 (StartTrainingWidget, QuickStartControl, WeeklyGoalRingWidget, Small/Medium), watch complications (QuickStart has accessoryCorner), maps/routes, CloudKit + Sign In (basic), onboarding (beta-blocker question), 4-tab iOS layout (Today timeline / History calendar-list-map / Trends Week-Month-Year / Settings), Fix a part (type, split, merge; SegmentEdits), session heart-rate chart (HealthKit, read-only), Health import into History, heart limits + low limit + "Heart & alerts" screen, watch no-motion auto-pause, watch GPS cycling auto-switch, post-workout effort (watch → phone, PendingSessionEffort), zone words (EASY/STEADY/HARD), deep-link routing (iOS + watch), Account section (signed-in only; Sign Out / Delete Account)
**Pending (Tier 2/3)**: iOS Tier 2 (Streak + families, Next Planned, Weekly Dashboard), watch Tier 2 (Start Template, Weekly Ring corner, Streak Corner, Today/Next inline, Last Workout circular), iOS/watch Tier 3 (Recovery Status — blocked on readiness metric)
**Partial**: Multi-sport (model only), cadence (count only, no SPM), custom fonts (not bundled), AirPods Pro 3 heart rate (`useAirPodsHeartRate` intent flag + iOS 26 source row; no runtime path)
**Open (timeline plan)**: AirPods runtime path; Trends past periods (current period only); widgets read raw sessions.json (Fix a part not applied); no reset-to-detected; Dynamic Island regions defined but not verified on device; sudden-jump alert still emitted although the plan drops it (owner decision)
**Not done**: Voice coaching, export/sharing, StoreKit subscriptions, social groups/challenges, pace alerts, user profile + public CloudKit
**Device-unverified**: no-motion auto-pause with the watch off the wrist; GPS cycling switch thresholds; heart alerts end to end on device; History map following the period; Live Activity on device

## Theme System (1 theme: Clean, Oct 2026)
- `@Observable ThemeManager` singleton, `selectTheme(id)` for switching, stored `current` property
- `ShuttlXColor`/`ShuttlXFont` bridge enums — all code is theme-aware
- **Active themes**: Clean (id: "clean") only
- **Deleted**: Synthwave, Arcade, Classic Radio, Neovim, FM Tuner — all files removed, pbxproj cleaned, both builds pass
- `ThemeEffects` CardStyle: `.glass` (Clean) only
- `ThemeChartStyle` stripped to what Clean uses (smoothArea line, roundedSwiftCharts bars)
- Screen backgrounds: Clean = MeshGradient (iOS) / LinearGradient (watchOS); `themedScreenBackground()` calls it directly
- `MeshGradient` is iOS-only — watchOS uses `LinearGradient` fallback for Clean theme
- iOS timer: single `standardTimerBody` (no per-theme dispatch)
- watchOS timer padding: always 0 (no per-theme hacks remaining)

## Widget Status & Follow-ups (Tier 1 shipped, 2026-07-25)

**Tier 1 (shipped):** W1 StartTrainingWidget (configurable), W2 QuickStartControl (iOS 18), W3 WeeklyGoalRingWidget (3 families), W8 QuickStartComplication corner support. Shared: `WorkoutTemplateEntity` (AppEntity), `StartIntents`, `WidgetProgressShapes` (GlassRingProgress + CassetteSpoolProgress), `WidgetTemplateProvider`, `WidgetTheme`.

**Known follow-ups:**
- `weeklyWorkoutGoal` defaults to 5; no settings UI yet (future roadmap)
- `TemplateManager.save()` does not call `WidgetCenter.shared.reloadTimelines()` — W1 widget stale-name issue when template renamed (add reload call in save method)
- iOS `ios.md` URL style is hyphenated (`start-template`, not `startTemplate`) — watch URLs already follow this convention
- Tier 2 widgets (Streak families, Next Planned, Weekly Dashboard iOS; watch template/corner/inline) pending design/proposals/widgets/ integration
- Tier 3 (Recovery status iOS + watch) blocked on readiness metric (future health-domain work)

## Lessons Learned
- `@Observable` only tracks **stored** properties — computed don't trigger updates
- `didSet` + `@Observable` can interfere — prefer explicit methods
- Always verify theme changes end-to-end on device, not just compilation
- `MeshGradient` is iOS 18+ only — NOT available on watchOS. Use `LinearGradient` fallback on watch
- Widget process cannot run WatchConnectivity — deep-link to host app, which calls `PhoneSyncCoordinator.startWatchWorkout()`
- DeepLinkRouter pending-buffer pattern mandatory to avoid cold-launch URL consumption race conditions
- Corrections never touch `sessions.json`: `SegmentEdits.apply` runs once in `DataManager.effectiveSessions`; only persistence and CloudKit read raw `sessions`
- Watch: SwiftUI silently scale-fits an over-full stack. Size text by solving, never with `minimumScaleFactor`

## MCP Servers
- `xcodebuildmcp` — Xcode build integration
- `mcp-image` (Nano Banana / shinpr/mcp-image) — image generation via Gemini, 3 quality presets
- `svgmaker` (@genwave/svgmaker-mcp) — SVG vector generation (needs SVGMAKER_API_KEY)

## Build Commands
```bash
# Both platforms
bash tests/build_and_test_both_platforms.sh --clean --build
# iOS only — NEVER pass -sdk: it forces companion targets onto the wrong SDK and breaks their SPM deps (TelemetryDeck etc.)
xcodebuild -project ShuttlX.xcodeproj -scheme ShuttlX -destination 'generic/platform=iOS Simulator' build
# watchOS only (same rule: destination only, no -sdk)
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlX Watch App" -destination 'generic/platform=watchOS Simulator' build
# SPM unit tests (29 tests: IntervalEngine, RecoverySegmenter, watch-parity guard) — also runs in CI test.yml
swift test
```

## Current Build
- Current: v1.10.0 (HEAD 02779c3) — timeline redesign: Today/History/Trends/Settings, watch mockup screens, heart alerts, effort
- Previous: v1.9.0
