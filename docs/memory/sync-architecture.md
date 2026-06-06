# Watch → iOS Sync Architecture

## Data Flow
1. Watch `WatchWorkoutManager.saveWorkoutData()` (line 791) builds `TrainingSession` with full `routePoints`, `segments`, `kmSplits`
2. Calls `SharedDataManager.sendSessionToiOS()` (watch, line 99)
3. Session is JSON-encoded → base64-encoded → packed into `[String: Any]` dict
4. Sent via `transferUserInfo` (guaranteed, background) AND `sendMessage` (immediate, if reachable)
5. iOS receives via `didReceiveUserInfo` (line 524) or `didReceiveMessage` (line 543)
6. Decoded: base64 → Data → JSONDecoder → TrainingSession
7. Stored: `handleReceivedSession()` → `syncedSessions` → `sessions.json` in App Group

## iOS Pull Path
- `requestSessionsFromWatch()` (iOS line 322) sends `"requestAllSessions"` via sendMessage
- Watch handler (line 300) loads ALL local sessions, encodes ALL into one reply
- iOS `handleSessionRequestReply()` (line 360) decodes the bulk response
- Triggered on: app foreground, watch reachability change, post-activation

## Payload Size Problem (BUG — long workouts don't sync)
- Each RoutePoint: ~148 bytes JSON (lat, lon, altitude, timestamp, speed, horizontalAccuracy)
- 91-min workout at 10m distance filter: ~1,500-1,800 route points
- Total: 230-275 KB JSON → 305-365 KB base64
- `sendMessage` limit: ~65 KB — SILENTLY FAILS
- `transferUserInfo` limit: ~256 KB — may also fail for very long sessions
- `requestAllSessions` reply: encodes ALL sessions in one message — even worse
- `sendAllStoredSessions()` (line 373): uses ONLY sendMessage, no transferUserInfo fallback

## Key Files
- Watch sending: `ShuttlX Watch App/Services/SharedDataManager.swift` (537 lines)
  - `sendSessionToiOS()` line 99-152
  - `sendSessionViaUserInfo()` line 154-165
  - `sendAllStoredSessions()` line 373-405 (sendMessage only!)
  - `requestAllSessions` handler line 300-311 (all sessions in one reply!)
- iOS receiving: `ShuttlX/Services/SharedDataManager.swift` (622 lines)
  - `didReceiveUserInfo` line 524-541
  - `didReceiveMessage` line 543-570
  - `requestSessionsFromWatch()` line 322-358
  - `handleSessionRequestReply()` line 360-390
- Watch workout: `ShuttlX Watch App/Services/WatchWorkoutManager.swift` (944 lines)
  - `saveWorkoutData()` line 791-834
  - `routePoints` array line 74
  - `heartRateSamples` array line 62
  - `broadcastLiveMetricsIfNeeded()` line 396-432 (live metrics, separate channel)

## Retry & Fallback
- Watch queues unsent sessions in `pendingSessions` → `pending_sync_sessions.json`
- Retries every 15s and on reachability change
- Local backup: `active_workout_backup.json` saved on pause/crash
- App Group `sessions.json` readable by both targets
