---
globs:
  - "**/Services/**"
---

# Services Rules

## Thread Safety

- Use `@MainActor` on `ObservableObject` classes — never `@unchecked Sendable`
- Timer creation and access must be on the same actor
- Avoid `Task.detached` → `MainActor.run` chains that risk deadlock
- Weak references: always use `guard let self = self else { return }` pattern

## No Force Unwraps

- Never use `!` or `[0]` for array access
- Pattern: `FileManager.default.urls(for:in:)` → use `.first` with `guard let`
- Pattern: `HKQuantityType(...)` → use `guard let` or `if let`

## JSON Persistence

- Never silently fail: use `do/catch` with `os.log` for encode/decode errors
- Always encode/decode inside `do { try } catch { Logger.error(...) }`

## WatchConnectivity

- `WCSession.default.activate()` must be called at the correct lifecycle point
- Handle `WCSessionActivationState` changes properly
- Sync retries: use exponential backoff, max 5 retries, prevent stacking
- Always check `isReachable` before `sendMessage`, fall back to `transferUserInfo`
- Theme sync: iPhone sends `"syncTheme"` action via `updateApplicationContext` → Watch updates `ThemeManager.shared.selectedThemeID`

## HealthKit

- `requestAuthorization()` must handle denial gracefully (no force unwraps on types)
- Background delivery requires `com.apple.developer.healthkit.background-delivery` entitlement
- Workout sessions: save on pause/stop, implement crash recovery

## Deep Links

Deep links route widgets/controls/external URLs into the app to start workouts or navigate. **Widget processes cannot run WatchConnectivity** — iOS widgets must deep-link to the host app, which then calls `PhoneSyncCoordinator.startWatchWorkout()`.

- **iOS schemes**: `shuttlx://start-template/{uuid}`, `shuttlx://start-freerun`, `shuttlx://dashboard`, `shuttlx://session/{id}`, `shuttlx://plan`, `shuttlx://last-workout`.
- **watchOS schemes**: `shuttlx://start-workout` (free run, direct call to `workoutManager.startWorkout()`), `shuttlx://start-template/{uuid}` (resolve template → `startIntervalWorkout(template:)`), `shuttlx://home` (navigate to home), `shuttlx://last-workout`.
- **DeepLinkRouter** (iOS): `ShuttlXApp.onOpenURL` parses and writes into the `DeepLinkRouter` environment object's pending properties. Consumers MUST read the pending value both on mount (`.task`/`.onAppear`) AND via `.onChange` — onChange alone never fires for a value set before the view mounted (cold-launch widget taps), which was a real shipped bug. If the target data isn't loaded yet, keep the pending value and retry when the data source changes (consume-on-load); clear it only after successful consumption.
- **New link registration**: use hyphenated hosts (e.g., `start-template`, not `startTemplate` or `start/template`).
