---
globs:
  - "ShuttlX Watch App/**"
---

# watchOS Rules

## General

- Scheme name: `ShuttlX Watch App`
- watchOS target path: `ShuttlX Watch App/`
- Build: `xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlX Watch App" -sdk watchsimulator build`
- Background mode: `workout-processing` for active workouts

## Timer Display

- Use 40pt monospaced font for timer on watch (smaller than iOS 52pt)
- Use `DispatchSourceTimer` (not `Timer`) — drift-proof, works when screen off
- Must work during wrist-down (screen off) state
- Test with long workouts (30+ minutes)

## Controls

- Circular buttons: green for pause, red for stop
- Keep controls large and tappable (min 44pt touch target)

## Workout Lifecycle

- HealthKit workout session must survive app backgrounding
- Save workout data on pause AND on stop (crash recovery)
- If app is killed mid-workout, data must be recoverable from local storage

## Watch Complications / Widgets

- Widget files are in `ShuttlX Watch App/Widgets/`
- Types: LastWorkout, QuickStart, WeeklyProgress
- Data provided via `WatchWidgetDataProvider`

## Theme System

- All 6 themes (Clean, Synthwave, Mixtape, Arcade, Classic Radio, VU Meter) are supported on watchOS
- Theme files mirrored in `ShuttlX Watch App/Theme/` with watch-specific font sizes
- Theme selection synced from iPhone via WCSession `applicationContext`
- `ThemeManager.shared` injected at app root in `ShuttlXWatchApp.swift`
- Use `ShuttlXColor.*` / `ShuttlXFont.*` (bridges to active theme) or `@Environment(ThemeManager.self)`

## Sync

- Watch-side sync is in `SharedDataManager.swift` (525 lines)
- Phone-side sync is in iOS `SharedDataManager.swift` (605 lines)
- Both must handle offline gracefully — queue and retry
- Theme sync: `handleIncomingPayload` handles `"syncTheme"` action from iPhone
