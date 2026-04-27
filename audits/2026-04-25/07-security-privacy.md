# Security and Privacy Audit — ShuttlX iOS/watchOS

Date: 2026-04-25
Scope: source tree at `/Users/sergeymuzyukin/github/shuttlx`

## Summary

9 findings across 5 categories. No P0 (App Review reject / PII leak) issues. Most impactful: two third-party SDKs present in a project documented as "zero external dependencies", an app privacy manifest that does not disclose what those SDKs collect, and a RevenueCat public API key hardcoded in source (low-risk per RevenueCat policy but worth awareness). Health data files use `.completeFileProtection`; keychain usage for credentials is correct; CloudKit uses the private database exclusively; ATS is not loosened anywhere in source plists.

---

## F1 — Third-party SDKs present, CLAUDE.md states "zero external dependencies"

**Severity: P1**
**Confidence: High**

The project declares "Zero external dependencies — Apple frameworks only" in CLAUDE.md and agent docs. The codebase ships two SPM packages:

- **RevenueCat** (`RevenueCat/purchases-ios-spm`) — referenced in `ShuttlX.xcodeproj/project.pbxproj` (RC200001), imported in:
  - `ShuttlX/ShuttlXApp.swift:2`
  - `ShuttlX/Services/SubscriptionManager.swift:2`
  - `ShuttlX/Views/SettingsView.swift:5`
  - `ShuttlX/Views/PaywallView.swift:2`
- **TelemetryDeck** (`TelemetryDeck/SwiftSDK`) — imported in:
  - `ShuttlX/ShuttlXApp.swift:3`
  - `ShuttlX/Services/DataManager.swift:6`
  - `ShuttlX/Views/SettingsView.swift:6`

**Risk:** App Store privacy label and privacy manifest must reflect what these SDKs collect. The current manifest does not (see F2). Doc mismatch may also lead other developers/agents to make incorrect assumptions about the data flow.

**Fix direction:** Update CLAUDE.md to reflect the two dependencies and their data scope. Then address F2.

---

## F2 — App PrivacyInfo.xcprivacy omits data types collected by bundled SDKs

**Severity: P1**
**Confidence: High**

`ShuttlX/PrivacyInfo.xcprivacy` declares only `NSPrivacyCollectedDataTypeHealthAndFitness` and `NSPrivacyCollectedDataTypePreciseLocation`. It does not declare:

- `NSPrivacyCollectedDataTypeProductInteraction` — TelemetryDeck's bundled `PrivacyInfo.xcprivacy` declares it collects ProductInteraction and DeviceID for analytics.
- `NSPrivacyCollectedDataTypeDeviceID` — same source.
- `NSPrivacyCollectedDataTypePurchaseHistory` — RevenueCat's bundled `PrivacyInfo.xcprivacy` declares purchase history collection.

Apple's aggregation rules require the **app's** nutrition label and privacy manifest to be the union of what the app and all linked SDKs collect.

**Files:**
- `ShuttlX/PrivacyInfo.xcprivacy` — missing three `NSPrivacyCollectedDataType` entries.
- `ShuttlX Watch App/PrivacyInfo.xcprivacy` — Watch target does not link RevenueCat/TelemetryDeck; otherwise fine.

**Fix direction:** Add `NSPrivacyCollectedDataTypeProductInteraction`, `NSPrivacyCollectedDataTypeDeviceID` (analytics, not linked, not tracking), and `NSPrivacyCollectedDataTypePurchaseHistory` (app functionality, not linked, not tracking) to the iOS `PrivacyInfo.xcprivacy`. Confirm App Store Connect privacy declarations match.

---

## F3 — RevenueCat public API key hardcoded in source

**Severity: P2**
**Confidence: High**

`ShuttlX/Services/SubscriptionManager.swift:13`:
```swift
static let apiKey = "appl_mHeFHuftdLXvNyxHabCOxrzHBIr"
```

RevenueCat's `appl_`-prefixed keys are public read-only keys intended to be shipped in the binary. RevenueCat's docs confirm this carries no compromise risk by itself. The TelemetryDeck App ID `2323535F-7F18-45F3-ACA2-215164CD22BC` (`ShuttlXApp.swift:23`) is similarly public. However:

1. Both values are committed to git history permanently.
2. If the repo is or becomes public these values are permanently exposed.

**Fix direction:** Accept the risk with a comment (current state is acceptable), OR move both values to an `*.xcconfig` excluded from git with values injected at CI build time. Neither is a write-capable credential, so severity is P2.

---

## F4 — RevenueCat entitlement verification mode is `.informational`, not `.enforced`

**Severity: P2**
**Confidence: High**

`ShuttlX/Services/SubscriptionManager.swift:47`:
```swift
.with(entitlementVerificationMode: .informational)
```

In `.informational` mode, RevenueCat logs a warning if JWT-backed entitlement verification fails but does not block access. A jailbroken device could manipulate the receipt to spoof a Pro entitlement and the app would grant access.

**Fix direction:** Change to `.enforced`. Tradeoff is rare false-negative if RevenueCat rotates signing keys. For a subscription-monetised fitness app the correct setting.

---

## F5 — Live metrics WC payload transmits GPS every 3s; route persisted to CloudKit without explicit disclosure

**Severity: P2**
**Confidence: High**

`ShuttlX Watch App/Services/WatchWorkoutManager.swift:562–565`:
```swift
if let lastPoint = routePoints.last {
    payload["latitude"] = lastPoint.latitude
    payload["longitude"] = lastPoint.longitude
}
```

Sent via `WCSession.default.sendMessage` to iPhone every 3 seconds during any active workout. Route is part of `TrainingSession.route: [RoutePoint]?`, encoded to JSON, written to App Group with `.completeFileProtection`, and synced to CloudKit's private database.

The CloudKit path is the concern: session JSON including `RoutePoint` records is pushed via `CKAsset` to CloudKit without any opt-in gate or UI disclosure. `NSHealthShareUsageDescription` mentions fitness data but not location. `NSHealthUpdateUsageDescription` mentions "save your workout data" — broad enough technically, but a user may not expect granular GPS traces in iCloud.

**Fix direction:** Either (a) strip `route` from CloudKit record and keep GPS only on-device, or (b) add an explicit disclosure during onboarding that GPS routes are included in iCloud sync. Privacy best practice leans toward (a) unless user explicitly opts in.

---

## F6 — HealthKit background-delivery entitlement not claimed (correct now, flag for future)

**Severity: P3**
**Confidence: Medium**

`ShuttlX/ShuttlX.entitlements` does not contain `com.apple.developer.healthkit.background-delivery`. Correct for iOS — no `HKObserverQuery` or `enableBackgroundDelivery` calls in iOS source. Watch entitlements also omit it. Watch uses `workout-processing` background mode (`ShuttlX Watch App/Info.plist:36`) and `HKLiveWorkoutBuilder`, which does not require background delivery.

No issue today. Flag: if a future feature adds `HKObserverQuery` on iOS for background HR alerts, the entitlement and `healthkit` background mode must be added before App Store submission. Note: HealthKit specialist's audit (03-healthkit.md F9) flags this as P2 since the recovery feature roadmap requires HRR capture.

---

## F7 — Sign In with Apple email not persisted (correct, noted for awareness)

**Severity: P3**
**Confidence: High**

`ShuttlX/Services/AuthenticationManager.swift:11, 46–47`: `userEmail` is `@Published var` set only from `credential.email` at initial sign-in. Apple only provides email once. The app does not persist email — privacy-respecting. User name correctly migrated from UserDefaults to Keychain (lines 126-130). Apple user ID stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

**No action required.** Future feature flag: any future view trying to display the email after restart will silently show nothing rather than crash.

---

## F8 — Corrupt session backup files accumulate without expiry

**Severity: P3**
**Confidence: High**

`ShuttlX/Services/SharedDataManager.swift:311–313` and `ShuttlX/Services/DataManager.swift:213–216`:

```swift
let backupURL = url.deletingLastPathComponent()
    .appendingPathComponent("sessions_corrupt_\(Int(Date().timeIntervalSince1970)).json")
try? FileManager.default.copyItem(at: readURL, to: backupURL)
```

When `sessions.json` fails to decode, a timestamped backup is written. These files contain the same health data, are protected at rest, and are never deleted. Over time, failed-decode events could accumulate multiple historical health-data copies in the App Group. Files are accessible to any extension sharing `group.com.shuttlx.shared`.

**Fix direction:** After writing the backup, schedule a cleanup that deletes `sessions_corrupt_*.json` files older than 7 days.

---

## F9 — iOS background modes — no issue (audit completeness only)

**Severity: P3**
**Confidence: Low**

`ShuttlX/Info.plist` declares no `UIBackgroundModes`. The iOS app uses `Timer.scheduledTimer` repeating every 15 seconds in `SharedDataManager.setupBackgroundTasks()`. This timer is suspended on backgrounding — correct behaviour, no background mode needed. The Live Activity extension's `Info.plist` declares `NSExtensionPointIdentifier: com.apple.widgetkit-extension` — correct.

**No action required.**

---

## Areas Confirmed Clean

- **ATS exceptions**: No `NSAllowsArbitraryLoads`, `NSExceptionDomains`, or `NSAllowsLocalNetworking` in any source Info.plist.
- **Keychain accessors**: Apple user ID and display name use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. No sensitive credential written to UserDefaults.
- **CloudKit database scope**: Exclusively `privateCloudDatabase` (`CloudKitSyncManager.swift:15`).
- **HealthKit data leaving device**: Only to the user's own CloudKit private DB, WatchConnectivity (on-device), and HealthKit. No third-party server. TelemetryDeck signals (`workoutCompleted`, `themeChanged`) contain only aggregate metadata — no identifiers, no biometrics.
- **Logging hygiene**: No HR values, GPS coordinates, user email, or Apple user ID are interpolated into log messages.
- **No camera / photo library usage**: No `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`; no `AVCaptureSession` / `UIImagePickerController` imports.
- **File protection**: Every `data.write(to:)` in both targets uses `[.atomic, .completeFileProtection]`.
- **Required Reason APIs**: `NSPrivacyAccessedAPICategoryFileTimestamp` (C617.1) and `NSPrivacyAccessedAPICategoryUserDefaults` (CA92.1) are declared in both manifests. SystemBootTime not required (no `mach_absolute_time` / `clock_gettime(CLOCK_MONOTONIC_RAW)` in source).
- **Sign In with Apple revocation**: `listenForRevocation()` correctly observes `ASAuthorizationAppleIDProvider.credentialRevokedNotification` and calls `signOut()`. `verifyCredentialState()` on each cold launch.
- **Widget/Live Activity entitlements**: Correct — only App Group, no HealthKit/CloudKit on extensions.
