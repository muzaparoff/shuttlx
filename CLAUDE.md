# ShuttlX - Full Fix & App Store Distribution Plan

> **Status: ALL AGENTS COMPLETE — Both targets build successfully (iOS + watchOS)**
> Build verified: `xcodebuild` iOS (iPhone 17 Pro sim) and watchOS (generic sim) both pass.

## Project Overview

**ShuttlX** is an interval training app for iOS (18.0+) and watchOS (11.5+) built with SwiftUI.
- Bundle ID: `com.shuttlx.ShuttlX` / `com.shuttlx.ShuttlX.watchkitapp`
- Team ID: `83HPSY452Y`
- App Group: `group.com.shuttlx.shared`
- CloudKit Container: `iCloud.com.shuttlx.app`
- ~5,400 lines of Swift across 31 files, zero external dependencies

## Build Commands

```bash
# Build both platforms (simulator)
bash tests/build_and_test_both_platforms.sh --clean --build

# Build for physical device
bash tests/build_for_physical_device.sh

# iOS only
xcodebuild -project ShuttlX.xcodeproj -scheme ShuttlX -sdk iphonesimulator build

# watchOS only
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlXWatch Watch App" -sdk watchsimulator build
```

---

## Agent Roles

| Agent ID | Role | Focus Area |
|----------|------|------------|
| **AGENT-1** | iOS Build & Config Engineer | Xcode project, Info.plist, entitlements, signing, Privacy Manifest |
| **AGENT-2** | Swift Safety & Quality Engineer | Force unwraps, crashes, thread safety, deprecated APIs |
| **AGENT-3** | watchOS & Sync Engineer | Watch app fixes, WatchConnectivity, HealthKit workout |
| **AGENT-4** | UI/UX & Accessibility Engineer | Accessibility, dark mode, dynamic type, launch screen |
| **AGENT-5** | App Store Submission Engineer | Screenshots, metadata, review prep, TestFlight, distribution |

---

## AGENT-1: iOS Build & Config Engineer

### CRITICAL — App Store Blockers

- [ ] **T1.1** Create `PrivacyInfo.xcprivacy` for iOS target
  - File: `ShuttlX/PrivacyInfo.xcprivacy`
  - Declare: NSPrivacyAccessedAPICategoryHealthKit, NSPrivacyAccessedAPICategoryFileTimestamp (if applicable)
  - Declare data collection: Health & Fitness data
  - Add to Xcode target membership
  - **Blocks**: AGENT-5 (cannot submit without this)

- [ ] **T1.2** Create `PrivacyInfo.xcprivacy` for watchOS target
  - File: `ShuttlXWatch Watch App Watch App/PrivacyInfo.xcprivacy`
  - Declare same privacy types as iOS
  - Add to Xcode target membership
  - **Blocks**: AGENT-5

- [ ] **T1.3** Fix version mismatch between iOS and watchOS
  - iOS Info.plist: version `1.1.0` build `1`
  - watchOS Info.plist: version `1.0` build `1` → **change to `1.1.0`**
  - File: `ShuttlXWatch Watch App Watch App/Info.plist`
  - **Blocks**: AGENT-5

- [ ] **T1.4** Remove `NSAllowsArbitraryLoads` from watchOS Info.plist
  - File: `ShuttlXWatch Watch App Watch App/Info.plist` (lines 10-12)
  - Remove the entire `NSAppTransportSecurity` dict (app makes no HTTP calls)
  - **Blocks**: AGENT-5

### HIGH — Entitlements & Signing

- [ ] **T1.5** Fix entitlements inconsistency
  - watchOS `ShuttlXWatch.entitlements` is MISSING `com.apple.developer.healthkit.background-delivery`
  - iOS has it, watchOS should too (watchOS does the actual workouts)
  - Verify `aps-environment` key — remove if push notifications not used

- [ ] **T1.6** Verify CloudKit container exists in Apple Developer Portal
  - Container: `iCloud.com.shuttlx.app`
  - If CloudKit is NOT actively used, consider removing CloudKit/CloudDocuments entitlements to avoid review questions
  - Files: `ShuttlX/ShuttlX.entitlements`, `ShuttlXWatch Watch App Watch App/ShuttlXWatch.entitlements`

- [ ] **T1.7** Verify iOS Assets.xcassets exists and has all required icons
  - Check if iOS target has an asset catalog (watchOS has one, iOS may be missing)
  - Required: AppIcon set with 1024x1024 for App Store
  - Icons available in `shuttlx_icon_set/` — ensure they are in the asset catalog
  - **Blocks**: AGENT-5

- [ ] **T1.8** Configure proper Launch Screen
  - iOS Info.plist has empty `<key>UILaunchScreen</key><dict/>`
  - Either add `UILaunchStoryboardName` or configure LaunchScreen colors/image
  - File: `ShuttlX/Info.plist`

- [ ] **T1.9** Add iOS background modes if needed
  - If app needs to receive Watch data in background, add `UIBackgroundModes` with `remote-notification` or `processing`
  - File: `ShuttlX/Info.plist`

- [ ] **T1.10** Clean up duplicate entitlement files in watchOS
  - Two entitlement files exist:
    - `ShuttlXWatch Watch App Watch App/ShuttlXWatch.entitlements`
    - `ShuttlXWatch Watch App Watch App/ShuttlXWatch Watch App Watch App.entitlements`
  - Verify which one is actually used by the build target, remove the other

### MEDIUM — Package & Project Cleanup

- [ ] **T1.11** Fix Package.swift or remove if unused
  - Declares `ShuttlXShared` library but `Shared/` directory doesn't exist
  - Platform targets (iOS 16, watchOS 9) don't match project targets (iOS 18, watchOS 11.5)
  - Either implement shared package for models or delete Package.swift

- [ ] **T1.12** Verify provisioning profiles & certificates
  - Ensure distribution certificate exists (not just development)
  - Ensure App Store provisioning profiles exist for both targets
  - Team ID: `83HPSY452Y`

### Shared With AGENT-3
- T1.5 (entitlements) — AGENT-3 validates HealthKit functionality after fix
- T1.6 (CloudKit) — AGENT-3 validates sync after changes

---

## AGENT-2: Swift Safety & Quality Engineer

### CRITICAL — Crash Prevention

- [ ] **T2.1** Replace all force unwraps with safe alternatives
  - `ShuttlX/Services/DataManager.swift:25` — `urls(...).first!` → use `guard let`
  - `ShuttlX/Services/DataManager.swift:242-244` — `HKQuantityType(...)!` → use `guard let`
  - `ShuttlX/Services/SharedDataManager.swift:32` — `urls(...).first!` → use `guard let`
  - Pattern: `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!`

- [ ] **T2.2** Replace all `[0]` array access with `.first` + guard
  - `ShuttlXWatch Watch App Watch App/Services/SharedDataManager.swift:225`
  - `ShuttlXWatch Watch App Watch App/Services/SharedDataManager.swift:437`
  - `ShuttlXWatch Watch App Watch App/Services/SharedDataManager.swift:721`
  - `ShuttlXWatch Watch App Watch App/Services/SharedDataManager.swift:788`
  - Pattern: `fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]` → `.first` with guard

- [ ] **T2.3** Audit `@unchecked Sendable` usage
  - `ShuttlX/Services/DataManager.swift:5` — `class DataManager: ObservableObject, @unchecked Sendable`
  - Verify thread safety or add proper `@MainActor` isolation
  - Check if `nonisolated` methods access shared state unsafely

### HIGH — Thread Safety

- [ ] **T2.4** Fix potential race condition in SharedDataManager timer setup
  - `ShuttlX/Services/SharedDataManager.swift:62-78` — Timer scheduled inside `DispatchQueue.main.asyncAfter`
  - Ensure timer creation and access are on same actor
  - Verify no deadlock risk in `Task.detached` → `MainActor.run` chain (`DataManager.swift:44-58`)

- [ ] **T2.5** Audit weak reference access patterns
  - `ShuttlX/Services/SharedDataManager.swift:40` — `private weak var dataManager: DataManager?`
  - Verify all access sites use `guard let dataManager = dataManager else { return }`
  - Lines 87, 119-122 need verification

### MEDIUM — Code Quality

- [ ] **T2.6** Replace deprecated `Alert` API
  - `ShuttlX/Views/DebugView.swift` — `Alert(title:...)` is deprecated
  - `ShuttlXWatch Watch App Watch App/Views/DebugView.swift` — same issue
  - Use `.alert(_:isPresented:actions:message:)` instead

- [ ] **T2.7** Add proper error handling for JSON encode/decode
  - Multiple `try?` silent failures in data persistence
  - Add logging for failed encode/decode operations
  - Files: `DataManager.swift`, both `SharedDataManager.swift` files

- [ ] **T2.8** Fix session deduplication logic
  - `DataManager.swift:100-120` — dedup by UUID only, doesn't handle same-data-different-UUID
  - Consider adding timestamp-based dedup for robustness

- [ ] **T2.9** Remove or gate debug/development code
  - `SyncDebugView.swift` (247 lines) — should be `#if DEBUG` gated
  - `DebugView.swift` in both targets — should be `#if DEBUG` gated
  - Print statements throughout code — replace with `os.log` or wrap in `#if DEBUG`

### Shared With AGENT-3
- T2.1, T2.2 (force unwraps in watchOS) — AGENT-3 tests after fix
- T2.4 (thread safety) — AGENT-3 validates sync behavior

---

## AGENT-3: watchOS & Sync Engineer

### HIGH — Watch App Fixes

- [ ] **T3.1** Validate WatchWorkoutManager HealthKit authorization flow
  - File: `ShuttlXWatch Watch App Watch App/Services/WatchWorkoutManager.swift`
  - Ensure `HKHealthStore.requestAuthorization()` handles denial gracefully
  - Verify workout session starts/stops correctly
  - Test background workout processing mode

- [ ] **T3.2** Verify WatchConnectivity session activation
  - File: `ShuttlXWatch Watch App Watch App/Services/SharedDataManager.swift`
  - Ensure `WCSession.default.activate()` is called at correct lifecycle point
  - Handle `WCSessionActivationState` changes properly
  - Test: Phone locked, Watch background, Airplane mode scenarios

- [ ] **T3.3** Fix sync retry mechanism
  - watchOS SharedDataManager has max 5 retries
  - Verify exponential backoff or fixed interval
  - Ensure retry doesn't stack (multiple concurrent retry chains)
  - Add timeout for sync operations

- [ ] **T3.4** Test HealthKit background delivery on watchOS
  - Verify `workout-processing` background mode works
  - Ensure workout data saves if app is killed mid-workout
  - Test crash recovery: can workout resume?

### MEDIUM — Data Integrity

- [ ] **T3.5** Validate bidirectional sync completeness
  - iOS → watchOS: programs sync correctly
  - watchOS → iOS: completed sessions sync back
  - Test: Create program on iOS, run on Watch, verify session appears on iOS
  - Test: Modify program on iOS while Watch has old version

- [ ] **T3.6** Test App Group shared container
  - Verify both targets can read/write to `group.com.shuttlx.shared`
  - Test fallback when WatchConnectivity is unavailable
  - File paths: `programs.json`, `sessions.json` in shared container

- [ ] **T3.7** Verify timer accuracy on watchOS
  - `TrainingView.swift` uses `DispatchSourceTimer` — verify it doesn't drift
  - Test long workouts (30+ minutes)
  - Test when Watch screen turns off (wrist down)

### LOW — Optimization

- [ ] **T3.8** Optimize sync payload size
  - Full program list synced every time — consider delta sync
  - Session data includes all intervals — consider summary-only for initial sync

### Shared With AGENT-1
- Receives: T1.5 (entitlements fix) — then validates T3.1, T3.4
- Receives: T1.6 (CloudKit changes) — then validates T3.5

### Shared With AGENT-2
- Receives: T2.1, T2.2 (crash fixes) — then validates T3.2, T3.3

---

## AGENT-4: UI/UX & Accessibility Engineer

### HIGH — Accessibility (App Store Risk)

- [ ] **T4.1** Add VoiceOver accessibility labels to all interactive elements
  - `ShuttlX/Views/ProgramListView.swift` — program rows, create button
  - `ShuttlX/Views/ProgramEditorView.swift` — all form fields, save button
  - `ShuttlX/Views/TrainingHistoryView.swift` — session rows
  - `ShuttlX/Views/SettingsView.swift` — all toggles and pickers
  - `ShuttlX/Views/ContentView.swift` — tab bar items
  - Use `.accessibilityLabel()`, `.accessibilityValue()`, `.accessibilityHint()`

- [ ] **T4.2** Add VoiceOver labels to watchOS views
  - `ShuttlXWatch Watch App Watch App/Views/ProgramSelectionView.swift`
  - `ShuttlXWatch Watch App Watch App/Views/TrainingView.swift` — timer, intervals, progress
  - Critical: timer countdown must announce to VoiceOver users

- [ ] **T4.3** Add Dynamic Type support
  - Review all views for fixed-size text that won't scale
  - Use `.font(.body)` / `.font(.headline)` (which auto-scale) instead of fixed sizes
  - Test with Accessibility Inspector → largest text size
  - All 9 iOS views + 3 watchOS views

### MEDIUM — Visual Polish

- [ ] **T4.4** Audit dark mode compatibility
  - Replace any hardcoded `Color.blue`, `Color.white` etc with semantic colors
  - Use `Color.primary`, `Color.secondary`, `Color.accentColor`
  - Test in both light and dark mode
  - Files: All Views/ in both targets

- [ ] **T4.5** Implement proper Launch Screen
  - Create a branded launch screen (app icon + name)
  - Or configure `UILaunchScreen` in Info.plist with background color
  - Coordinate with AGENT-1 (T1.8)

- [ ] **T4.6** Review OnboardingView flow
  - `ShuttlX/Views/OnboardingView.swift` — exists but may be disabled
  - Verify it shows on first launch
  - Should request HealthKit permissions during onboarding
  - Should explain Watch pairing

### LOW — Localization Prep

- [ ] **T4.7** Extract hardcoded strings for localization readiness
  - Not required for initial release if English-only
  - But prepare by using `String(localized:)` or `LocalizedStringKey`
  - Estimate: ~150 hardcoded strings across all views

### Shared With AGENT-1
- Receives: T1.8 (launch screen config) — then implements T4.5

### Shared With AGENT-5
- Provides: T4.1-T4.3 must complete before AGENT-5 takes final screenshots

---

## AGENT-5: App Store Submission Engineer

### PREREQUISITES (Wait for other agents)

This agent's work DEPENDS on completion of:
- AGENT-1: T1.1, T1.2, T1.3, T1.4, T1.7, T1.12 (all critical config)
- AGENT-2: T2.1, T2.2 (crash fixes)
- AGENT-4: T4.1-T4.3 (accessibility for screenshots)

### CRITICAL — App Store Connect Setup

- [ ] **T5.1** Create App Store Connect record
  - Create app record for bundle ID `com.shuttlx.ShuttlX`
  - Set primary language: English
  - Set app category: Health & Fitness
  - Set secondary category: Sports (optional)
  - Set content rights: Does not contain third-party content

- [ ] **T5.2** Prepare App Store metadata
  - App name: "ShuttlX" (verify availability)
  - Subtitle (30 chars): "Interval Training Tracker"
  - Keywords (100 chars): "interval,training,workout,HIIT,running,walking,fitness,health,watch,timer"
  - Description (4000 chars): Write compelling description
  - Promotional text (170 chars): Short feature highlight
  - Support URL: Required — must provide
  - Privacy Policy URL: **REQUIRED** — must create and host

- [ ] **T5.3** Create Privacy Policy
  - Must cover: HealthKit data usage, CloudKit sync, no third-party sharing
  - Host on a public URL (GitHub Pages, simple website)
  - **Blocks**: T5.2, T5.8

- [ ] **T5.4** Prepare screenshots
  - **iPhone**: 6.7" (iPhone 15 Pro Max) — REQUIRED
  - **iPhone**: 6.5" (iPhone 11 Pro Max) — REQUIRED
  - **iPhone**: 5.5" (iPhone 8 Plus) — if supporting older devices
  - **iPad**: 12.9" (iPad Pro) — if iPad supported
  - **Apple Watch**: Series 10 (46mm) — REQUIRED for watchOS
  - Minimum 3 screenshots per device size
  - Show: Program list, Active workout, History, Settings

- [ ] **T5.5** Complete Age Rating questionnaire
  - No violence, gambling, etc.
  - Health/Medical Information: YES (HealthKit)
  - User Generated Content: NO
  - Expected rating: 4+

- [ ] **T5.6** Complete Export Compliance
  - App uses standard Apple encryption (HTTPS/CloudKit)
  - Set `ITSAppUsesNonExemptEncryption = NO` in Info.plist (both targets)
  - Or complete encryption declaration in App Store Connect

- [ ] **T5.7** Set pricing and availability
  - Free app (no IAP)
  - Available in all territories (or specific countries)
  - Set availability date

### HIGH — Build & Upload

- [ ] **T5.8** Create Archive build
  - Set build configuration to Release
  - Ensure correct provisioning profiles (App Store Distribution)
  - Archive via Xcode: Product → Archive
  - Verify no warnings in archive

- [ ] **T5.9** Upload to App Store Connect
  - Use Xcode Organizer or `xcrun altool` / Transporter
  - Validate before uploading (catches many issues)
  - Wait for App Store Connect processing (~15-30 min)

- [ ] **T5.10** Submit for TestFlight (recommended first)
  - Add internal testers
  - Complete TestFlight compliance info
  - Test on real devices before public release
  - Verify: HealthKit permissions, Watch sync, workout tracking

- [ ] **T5.11** Submit for App Review
  - Add App Review notes explaining:
    - HealthKit usage (workout tracking)
    - Watch companion app
    - How to test features
  - Provide demo account if needed (not applicable for this app)
  - Set release method: Manual or Automatic

---

## Task Dependency Graph

```
AGENT-1 (Config)          AGENT-2 (Safety)         AGENT-3 (Watch)
  T1.1 ──────────────────────────────────────────────────────────→ T5.8
  T1.2 ──────────────────────────────────────────────────────────→ T5.8
  T1.3 ──────────────────────────────────────────────────────────→ T5.8
  T1.4 ──────────────────────────────────────────────────────────→ T5.8
  T1.5 ──→ T3.1, T3.4
  T1.7 ──────────────────────────────────────────────────────────→ T5.8
  T1.8 ──→ T4.5
  T1.12 ─────────────────────────────────────────────────────────→ T5.8
                            T2.1 ──→ T3.2, T3.3
                            T2.2 ──→ T3.2, T3.3
                            T2.1 ────────────────────────────────→ T5.8
                            T2.2 ────────────────────────────────→ T5.8

AGENT-4 (UI/UX)
  T4.1-T4.3 ────────────────────────────────────────────────────→ T5.4

AGENT-5 (Submission)
  T5.3 (Privacy Policy) ──→ T5.2, T5.8
  T5.1-T5.7 ──→ T5.8 ──→ T5.9 ──→ T5.10 ──→ T5.11
```

## Parallel Execution Plan

**Phase 1 — All agents work in parallel:**
- AGENT-1: T1.1-T1.10 (config fixes)
- AGENT-2: T2.1-T2.5 (safety fixes)
- AGENT-3: T3.1-T3.4 (watch validation, after AGENT-1/2 fixes land)
- AGENT-4: T4.1-T4.4 (accessibility & UI)
- AGENT-5: T5.1-T5.3, T5.5-T5.7 (metadata & policy — no code needed)

**Phase 2 — Integration (after Phase 1):**
- AGENT-1: T1.11-T1.12 (cleanup & signing verification)
- AGENT-2: T2.6-T2.9 (quality improvements)
- AGENT-3: T3.5-T3.8 (sync testing)
- AGENT-4: T4.5-T4.7 (polish)
- AGENT-5: T5.4 (screenshots — needs UI finalized)

**Phase 3 — Submission:**
- AGENT-5: T5.8-T5.11 (archive, upload, TestFlight, submit)
- All agents: Final review and sign-off

---

## Key File Reference

| File | Target | Purpose |
|------|--------|---------|
| `ShuttlX/Info.plist` | iOS | App config, permissions, version |
| `ShuttlX/ShuttlX.entitlements` | iOS | HealthKit, CloudKit, App Groups |
| `ShuttlX/Services/DataManager.swift` | iOS | Data persistence, HealthKit |
| `ShuttlX/Services/SharedDataManager.swift` | iOS | WatchConnectivity sync (1097 lines) |
| `ShuttlX/Views/*.swift` | iOS | 9 view files |
| `ShuttlXWatch Watch App Watch App/Info.plist` | watchOS | Watch config |
| `ShuttlXWatch Watch App Watch App/ShuttlXWatch.entitlements` | watchOS | Watch capabilities |
| `ShuttlXWatch Watch App Watch App/Services/WatchWorkoutManager.swift` | watchOS | Workout execution |
| `ShuttlXWatch Watch App Watch App/Services/SharedDataManager.swift` | watchOS | Watch-side sync (844 lines) |
| `ShuttlXWatch Watch App Watch App/Views/TrainingView.swift` | watchOS | Active workout UI (410 lines) |
| `ShuttlX.xcodeproj/project.pbxproj` | Both | Xcode build config |

---

## Bug Summary

| # | Severity | Description | File(s) | Agent |
|---|----------|-------------|---------|-------|
| 1 | CRITICAL | Missing PrivacyInfo.xcprivacy | Both targets | AGENT-1 |
| 2 | CRITICAL | Version mismatch iOS/watchOS | watchOS Info.plist | AGENT-1 |
| 3 | CRITICAL | NSAllowsArbitraryLoads=true | watchOS Info.plist | AGENT-1 |
| 4 | HIGH | Force unwraps crash risk (6+ locations) | DataManager, SharedDataManager | AGENT-2 |
| 5 | HIGH | Array `[0]` access crash risk (4 locations) | watchOS SharedDataManager | AGENT-2 |
| 6 | HIGH | Entitlements inconsistency (background delivery) | watchOS entitlements | AGENT-1 |
| 7 | HIGH | Missing/empty iOS asset catalog | iOS target | AGENT-1 |
| 8 | HIGH | No privacy policy URL | App Store requirement | AGENT-5 |
| 9 | MEDIUM | @unchecked Sendable hides thread issues | DataManager.swift | AGENT-2 |
| 10 | MEDIUM | Race condition in timer setup | iOS SharedDataManager | AGENT-2 |
| 11 | MEDIUM | No accessibility labels | All views | AGENT-4 |
| 12 | MEDIUM | Empty launch screen | iOS Info.plist | AGENT-1/4 |
| 13 | MEDIUM | Deprecated Alert API | Both DebugView.swift | AGENT-2 |
| 14 | MEDIUM | Debug views not gated with #if DEBUG | SyncDebugView, DebugView | AGENT-2 |
| 15 | MEDIUM | CloudKit configured but unused/incomplete | Entitlements | AGENT-1 |
| 16 | MEDIUM | Duplicate model files (not shared) | Models/ in both targets | AGENT-1 |
| 17 | LOW | No localization | All views | AGENT-4 |
| 18 | LOW | Hardcoded colors (dark mode) | Various views | AGENT-4 |
| 19 | LOW | Package.swift broken/unused | Package.swift | AGENT-1 |
| 20 | LOW | Missing ITSAppUsesNonExemptEncryption | Both Info.plist | AGENT-1/5 |
