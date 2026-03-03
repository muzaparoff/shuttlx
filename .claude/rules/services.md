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
