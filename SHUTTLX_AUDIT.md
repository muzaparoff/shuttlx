# ShuttlX Comprehensive Audit Report

**Date:** 2026-04-09
**Audited by:** 5 parallel agents (Safety, Architecture, Compliance, UX/Accessibility, Performance)
**Codebase:** ~13,200 LOC across 117 Swift files (iOS 18.0+ / watchOS 11.5+)
**Overall App Store Readiness Score: 4/10**

---

## Executive Summary

ShuttlX has a solid SwiftUI foundation with well-structured WatchConnectivity sync, good crash recovery patterns, and a creative 7-theme system. However, the audit uncovered **3 showstopper bugs** that break the app's core value proposition, **multiple App Store rejection risks**, and systemic gaps in accessibility and data protection. The most critical finding: **workouts are never actually saved to HealthKit** — the app's primary purpose is non-functional.

---

## CRITICAL (Must fix before App Store submission)

### S1. Workouts Not Saved to HealthKit
**Impact: Core app functionality is broken**
`WatchWorkoutManager.saveWorkoutData()` sends data to iOS via WCSession but **never calls `HKLiveWorkoutBuilder.finishWorkout()` or `healthStore.save()`** with an `HKWorkout`. No workout appears in the Health app or Activity rings. The route builder's `finalizeRouteBuilder()` searches for a matching HKWorkout that doesn't exist, so GPS routes are also silently discarded.
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:862-917`
- Fix: Use `HKLiveWorkoutBuilder` or construct+save an `HKWorkout` via `HKWorkoutBuilder` before calling `finalizeRouteBuilder()`

### S2. Workout Starts Without HealthKit Authorization
**Impact: Silent data loss — users believe data is recorded when it isn't**
`startWorkout()` calls `requestHealthKitPermissionsIfNeeded()` then immediately starts the session, timer, and all queries without awaiting authorization. If the user denies permissions, everything runs against an unauthorized store.
- File: `ShuttlX Watch App/Services/WatchWorkoutManager.swift:160-167`
- Fix: Await authorization before starting the workout session. Gate `startWorkoutSession()` on `healthKitAuthorized`

### S3. HR Zones Hardcoded — Dangerous for Older Users
**Impact: Health risk — incorrect intensity feedback**
Three separate HR zone definitions use fixed absolute BPM thresholds (e.g., Zone 5 >= 167 BPM) with no user age or max HR input. A 60-year-old (max HR ~160) working at near-maximal intensity would be shown "Zone 3 Cardio" instead of a danger warning. Zone boundaries also differ across files (Zone 1 is <100 in one file, <104 in another).
- Files: `ThemeColors.swift:84-91`, `TrainingView.swift:306-313`, `ChartData.swift:27-33`
- Fix: Require age or max HR in onboarding. Compute zones as % of max HR (50-60%, 60-70%, 70-80%, 80-90%, 90-100%)

### S4. No File Protection on GPS Route Data
**Impact: Privacy violation — precise location history readable from backups**
All `sessions.json` writes use `.atomic` but not `.completeFileProtection`. App Group containers default to `NSFileProtectionNone`. GPS routes (latitude, longitude, altitude, speed, timestamp) are readable from backup extractions. Crash-recovery backup in temp directory has zero protection.
- Files: `DataManager.swift:125`, `SharedDataManager.swift:270,304` (iOS), `SharedDataManager.swift:135,220,271,559` (watchOS), `WatchWorkoutManager.swift:804`
- Fix: Pass `[.atomic, .completeFileProtection]` as write options for all session files

### S5. Missing Privacy Manifests for Extensions
**Impact: Automated App Store rejection**
`ShuttlXWidgets/`, `ShuttlXWatchWidgets/`, and `ShuttlXLiveActivity/` extensions have no `PrivacyInfo.xcprivacy`. All read from `UserDefaults(suiteName:)` which requires `NSPrivacyAccessedAPICategoryUserDefaults` declaration. Enforced since spring 2024.
- Fix: Add `PrivacyInfo.xcprivacy` to each extension target declaring at minimum `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`

### S6. No File-Level Concurrency Protection for sessions.json
**Impact: Data corruption — read-modify-write race between app and widget extension**
Multiple processes (main app, widget extension, potentially Watch extension) read/write `sessions.json` with no coordination. `.atomic` prevents partial writes but not lost updates. One process's write can silently overwrite another's.
- Files: `DataManager.swift:119-131`, `SharedDataManager.swift:248-278` (watchOS), `WidgetDataProvider.swift:13-39`
- Fix: Use `NSFileCoordinator` for App Group file access, or migrate to SQLite/SwiftData

---

## HIGH PRIORITY (Fix in next sprint)

### Data Integrity

| # | Issue | File | Impact |
|---|-------|------|--------|
| H1 | Calorie double-counting on pause/resume — new `HKAnchoredObjectQuery` replays samples | `WatchWorkoutManager.swift:700-758` | Inflated calorie counts (2-3x) |
| H2 | `loadSessionsFromAppGroup()` silently returns `[]` on decode error — next save overwrites with empty, destroying all history | `SharedDataManager.swift:283-293` (iOS) | Permanent silent data loss |
| H3 | `handleReceivedSession()` never calls `saveSessionsToSharedStorage()` — sessions lost on termination if DataManager is nil | `SharedDataManager.swift:166-181` (iOS) | Sessions lost on app kill |
| H4 | VO2max estimate uses `lowestAvgHR * 0.65` as resting HR proxy — no physiological basis | `AnalyticsEngine.swift:373-388` | Wrong VO2max values |
| H5 | Training load assumes universal resting HR 60 / max HR 200 — recovery status wrong for age outliers | `AnalyticsEngine.swift:319-322` | "Fresh" shown when overreaching |
| H6 | No schema versioning — adding a required field to any model silently wipes all stored sessions | All model files | Future data loss risk |

### Architecture

| # | Issue | File | Impact |
|---|-------|------|--------|
| H7 | CloudKit full-table scan on every sync — no `CKServerChangeToken` caching | `CloudKitSyncManager.swift:142-162` | Hits rate limits at scale |
| H8 | CloudKit `.changedKeys` save policy without fetching server record — last write wins | `CloudKitSyncManager.swift:95` | Silent data overwrites |
| H9 | 4 redundant sync operations fire on every app foreground (2 duplicate WCSession messages) | `ShuttlXApp.swift:43-51` | Wasted battery + bandwidth |
| H10 | `sendAllStoredSessions()` fires on every WCSession reachability change during workout | `SharedDataManager.swift:307-319` (watchOS) | Battery drain mid-workout |
| H11 | `routePoints` array grows unbounded — marathon could hit 32MB watchOS limit | `WatchWorkoutManager.swift:75` | OOM crash on long workouts |
| H12 | App Group container resolved eagerly as stored `let` — permanently nil if entitlement unavailable at init | `SharedDataManager.swift:34`, `DataManager.swift:22` (iOS) | Silent storage failure |

### Performance

| # | Issue | File | Impact |
|---|-------|------|--------|
| H13 | `Thread.sleep(10)` blocks system thread in `performExpiringActivity` on every workout save | `WatchWorkoutManager.swift:910-916` | Watchdog risk |
| H14 | Synchronous full sessions.json decode+re-encode on every save — on watchOS `@MainActor` | `SharedDataManager.swift:248-278` (watchOS) | UI freeze on save |
| H15 | `kCLLocationAccuracyBest` on watchOS — maximum GPS power drain | `WatchWorkoutManager.swift:557` | 30-50% excess battery |
| H16 | `AnalyticsView` recomputes 9 analytics functions on every body evaluation — no caching | `AnalyticsView.swift:7-17` | Frame drops with 100+ sessions |
| H17 | iOS `log()` allocates new `DateFormatter` on every call (fires every 3s during live workout) | `SharedDataManager.swift:519-527` (iOS) | Unnecessary allocations |

### Compliance

| # | Issue | File | Impact |
|---|-------|------|--------|
| H18 | No `kSecAttrService` on Keychain item — could collide with other apps using same account string | `AuthenticationManager.swift:126-132` | Credential collision risk |
| H19 | Unused `recalibrate-estimates` entitlement on Watch — no API call exists | `ShuttlX Watch App.entitlements:9` | App Review scrutiny |
| H20 | False `NSPrivacyAccessedAPICategoryDiskSpace` in privacy manifests — API never called | Both `PrivacyInfo.xcprivacy` files | Review question / rejection |
| H21 | User display name from Sign In with Apple stored in plaintext `UserDefaults.standard` | `AuthenticationManager.swift:37` | PII in unencrypted backups |

### Accessibility

| # | Issue | File | Impact |
|---|-------|------|--------|
| H22 | No `@Environment(\.accessibilityReduceMotion)` anywhere — all animations unconditional | `LiveWorkoutCard.swift:119-128`, `TrainingView.swift:121` | Vestibular disorder users affected |
| H23 | `TemplateEditorView` has zero accessibility labels — VoiceOver users cannot create workouts | `TemplateEditorView.swift` | Primary flow inaccessible |
| H24 | `SignInView` has zero accessibility labels | `SignInView.swift` | Auth flow inaccessible |
| H25 | 3 of 7 themes fail WCAG text contrast — Mixtape primary 3.1:1, VU Meter secondary 2.3:1 | Theme files under `Themes/` | Text unreadable for low-vision |
| H26 | All watchOS font sizes are absolute — do not respond to Dynamic Type preference | All 7 watchOS theme files | Watch fonts never scale |

---

## MEDIUM PRIORITY (Nice to have / hardening)

### Safety & Data
- Calorie MET formula uses raw HR/maxHR instead of Karvonen reserve ratio (`CalorieEstimationEngine.swift:84-103`)
- Workout backup only written on pause, not periodically — 45-min unpaused workout has no backup (`WatchWorkoutManager.swift:769`)
- Crash-recovered sessions sent silently to iOS — no user notification or review (`ShuttlXWatchApp.swift:48-51`)
- `clearWorkoutBackup()` called before WCSession delivery confirmation (`WatchWorkoutManager.swift:906`)
- `processHeartRateSamples` race condition with `isPaused` check on nonisolated path (`WatchWorkoutManager.swift:680-683`)
- Session cap at 500 silently drops new sessions with no user notification (`DataManager.swift:53-56`)
- `RoutePoint.id` uses `Date` — collision risk for sub-millisecond GPS points (`RoutePoint.swift:4`)
- `TrainingSession` Equatable only checks `id + startDate` — prevents merge/update of modified sessions (`TrainingSession.swift:86-93`)

### Architecture
- `DataManager.setupBindings()` Combine subscription duplicates the direct forwarding path — double processing (`DataManager.swift:38-45`)
- Mixed `@Observable` / `@ObservableObject` patterns create dual injection overhead (`ShuttlXApp.swift:7-12`)
- Multiple views use `@ObservedObject var sharedData = SharedDataManager.shared` instead of `@EnvironmentObject` (`DashboardView.swift:7`, `DebugView.swift:5`, etc.)
- watchOS `retryPendingSessions` sends ALL pending on every retry — can queue duplicate transfers (`SharedDataManager.swift:57-67`)
- 15-second background sync timer runs indefinitely even with no active workout (`SharedDataManager.swift:69-78` iOS)
- CloudKit temp files not cleaned up on failure path (`CloudKitSyncManager.swift:166-186`)
- No offline queue for CloudKit operations (`CloudKitSyncManager.swift:37-67`)
- Models lack explicit `CodingKeys` — property rename breaks all stored data

### Performance
- `TrainingView` `GeometryReader` recalculates layout values every 1s timer tick (`TrainingView.swift:105-145`)
- `IntervalEngine.tick()` publishes 3+ `@Published` changes per second — no batching (`IntervalEngine.swift:46-68`)
- `scanlineOverlay` creates ~131 `Rectangle` views instead of Canvas (`ThemeModifiers.swift:188-203`)
- `sendTemplatesToWatch` sends via BOTH `applicationContext` AND `transferUserInfo` — duplicate delivery (`SharedDataManager.swift:449-474` iOS)
- `syncLog.removeFirst()` is O(n) on a 100-entry array, called every 3s during live workout (`SharedDataManager.swift:519-528` iOS)
- `ProgramSelectionView.loadLastSession()` decodes full sessions.json on every `.onAppear` (`ProgramSelectionView.swift:178-195`)

### Accessibility
- `LiveWorkoutCard` metrics lack units in VoiceOver — HR says just "152" not "152 beats per minute" (`LiveWorkoutCard.swift:101-117`)
- `WeekSummaryCard` day dots use color as sole indicator — inaccessible to colorblind users (`WeekSummaryCard.swift:45-67`)
- No `@Environment(\.colorSchemeContrast)` — Increase Contrast mode not supported (all theme files)
- Charts expose generic labels with no data values to VoiceOver (`WeeklyDistanceChart.swift:47`, `HRZoneChart.swift:45`, `PaceTrendChart.swift:62`)
- AOD view hardcodes colors bypassing theme and accessibility (`TrainingView.swift:79-100`)
- Onboarding HealthKit page doesn't explain consequences of denying (`OnboardingView.swift:87-99`)

### Compliance
- `print()` in `#Preview` block compiles into release builds (`TemplateEditorView.swift:256`)
- `SECRETS_MIGRATION.md` committed to repo reveals CI secret names and internal repo structure
- Fallback to documents directory when App Group fails — no error surfaced (`DataManager.swift:25-29`)
- CloudKit temp files written without file protection (`CloudKitSyncManager.swift:177-179`)
- `NSPrivacyAccessedAPICategoryFileTimestamp` reason may be over-broad — verify actual API usage
- `AuthenticationManager` NotificationCenter observer never removed (`AuthenticationManager.swift:101-111`)

---

## Individual Domain Scores

| Domain | Score | Summary |
|--------|-------|---------|
| Safety & Health Data | **3/10** | Core HealthKit save is broken. HR zones are unsafe. Calorie counting is wrong on pause/resume. |
| Architecture | **6.5/10** | Good patterns overall but file persistence has no concurrency protection, CloudKit sync is naive, and memory grows unbounded. |
| Compliance | **6/10** | Entitlements mostly correct. Missing extension privacy manifests will cause rejection. GPS data unprotected. |
| UX & Accessibility | **5/10** | Primary workout views have good VoiceOver. Two key flows have zero labels. Reduce Motion not honored. 3 themes fail contrast. |
| Performance & Battery | **5/10** | Timer path is solid. `Thread.sleep(10)` on save, GPS accuracy too high, synchronous JSON encode on main thread, and analytics recomputation are the main concerns. |

---

## Recommended Fix Order

### Phase 1: Ship-blockers (before any TestFlight)
1. **S1** — Save workouts to HealthKit (the entire app's purpose)
2. **S2** — Await HealthKit authorization before starting workout
3. **S5** — Add privacy manifests to all 3 extensions
4. **H20** — Remove false DiskSpace API declaration from privacy manifests
5. **H19** — Remove unused `recalibrate-estimates` entitlement

### Phase 2: Data integrity (before public release)
6. **S4** — Add file protection to all session JSON writes
7. **S6** — Add NSFileCoordinator for App Group file access
8. **H1** — Fix calorie double-counting on pause/resume
9. **H2** — Add logging + backup on decode error (prevent silent data wipe)
10. **H3** — Save syncedSessions to disk after receiving

### Phase 3: Health accuracy (before public release)
11. **S3** — Personalize HR zones with age/max HR input
12. **H4/H5** — Fix VO2max and training load calculations
13. **H6** — Add schema versioning to JSON storage

### Phase 4: Performance & UX (next sprint)
14. **H13** — Remove Thread.sleep, use semaphore
15. **H14** — Move JSON encode off main thread
16. **H15** — Switch to `kCLLocationAccuracyNearestTenMeters`
17. **H9** — Deduplicate foreground sync calls
18. **H11** — Cap routePoints array for long workouts
19. **H22** — Add Reduce Motion support
20. **H23/H24** — Add VoiceOver labels to TemplateEditor and SignIn

### Phase 5: Polish
21. Fix theme contrast ratios (Mixtape, VU Meter, Synthwave secondary)
22. Add Dynamic Type support to watchOS fonts
23. Add CKServerChangeToken to CloudKit sync
24. Cache AnalyticsView computations
25. Fix Keychain attributes

---

## Detailed Reports

Individual audit reports are available from the agents:
- **SAFETY_REPORT**: HealthKit ops, HR zones, workout lifecycle, data loss risks
- **ARCHITECTURE_REPORT**: State management, WatchConnectivity, persistence, CloudKit, memory
- **COMPLIANCE_REPORT**: Info.plist, entitlements, privacy manifests, data protection
- **UX_REPORT**: VoiceOver coverage, Dynamic Type, contrast ratios, onboarding
- **PERFORMANCE_REPORT**: Battery usage, main thread blocking, sync frequency, memory growth
