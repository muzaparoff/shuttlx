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
- **Free-run walk/run layout**: Use `compactMetric` two-up rows for DIST/PACE/CADENCE (not full-size `metricRow`) — total budget is ~180pt on 41mm screen; 5 large rows overflow and push HR off-screen. See 2026-06-06 BPM visibility fix.

## Pace (Rolling vs Cumulative)

- Pace is computed from a **sliding 30-second window**, not cumulative average from workout start
- Guards: must be ≥20s into workout AND ≥0.05km total distance AND window ≥5s AND ≥5m moved, else shows "—"
- CMPedometer distance has ~30s warmup lag; first sample arrives skewed (e.g. 30s / 0.05km = 10'00). Sliding window avoids the warmup artifact entirely
- Root cause doc: `docs/incidents/2026-06-06-pace-10min.md`

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

- All 8 themes (Clean, Synthwave, Mixtape, Arcade, Classic Radio, VU Meter, Neovim, FM Tuner) are supported on watchOS
- Theme files mirrored in `ShuttlX Watch App/Theme/` with watch-specific font sizes
- Theme selection synced from iPhone via WCSession `applicationContext`
- `ThemeManager.shared` injected at app root in `ShuttlXWatchApp.swift`
- Use `ShuttlXColor.*` / `ShuttlXFont.*` (bridges to active theme) or `@Environment(ThemeManager.self)`
- FM Tuner on watch: plain #021018 navy background; screens add FMTunerCompactHeader and FMTunerWatchVUColumn(level:) directly

## Sync

- Watch-side sync is in `SharedDataManager.swift` (525 lines)
- Phone-side sync is in iOS `SharedDataManager.swift` (605 lines)
- Both must handle offline gracefully — queue and retry
- Theme sync: `handleIncomingPayload` handles `"syncTheme"` action from iPhone
