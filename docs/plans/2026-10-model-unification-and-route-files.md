# Model unification and route files (October 2026)

Status: Part A (A0-A3) and step W implemented on 2026-10-24 (uncommitted at the time of writing); Part B (B0-B6) not started. Owner picked option 1 of Phase 3 in
`docs/plans/2026-10-open-dev-items.md`: first unify `TrainingSession` and `WorkoutTemplate`
into `Shared/` (part A), then move `route` out of `sessions.json` into `routes/<uuid>.json`
(part B).

Everything in this plan comes from reading the code at HEAD `8e5c969` plus the uncommitted
working tree (HistoryMapView, SessionDetailView, SegmentEdits are modified locally). Unless a
line says "measured", treat it as an **unverified finding from code reading**. Line numbers
refer to the current working tree and will drift.

## 1. Measured facts

From the scratch harness (`scratchpad/measure`, a copy of the current model, synthetic 60-minute
run/walk sessions with 30 segments and 8 km splits, macOS release build, M-series Mac):

| Route points per session | Bytes per session | 50 sessions | 200 sessions | Decode 200 sessions |
|---|---|---|---|---|
| 0 (no route) | 9.6 KB | 0.46 MB | 1.83 MB | 18 ms |
| 750 | 150 KB | 7.1 MB | 28.5 MB | 232 ms |
| 1000 | 196 KB | 9.4 MB | 37.4 MB | 307 ms |
| 2000 (watch cap) | 383 KB | 18.3 MB | 73.0 MB | 582 ms |
| 6000 (iPhone cap) | 1.13 MB | 53.8 MB | 215 MB | 1,775 ms |

About 186 bytes per route point; routes are about 95 percent of the file. After part B a
200-session `sessions.json` is about 1.8 MB and decodes in about 18 ms on the Mac (iPhone timing
not measured).

Every save rewrites the whole file (`DataManager.startSave`, `DataManager.swift:421`), and the
iOS widgets decode all of it on every timeline build (`WidgetDataProvider.swift:37`). The
widget memory-limit crash is an **unverified hypothesis**; section 9 says how to check it.

## 2. Part A: unify `TrainingSession` and `WorkoutTemplate`

### 2.1 Exact differences between the copies

- `ShuttlX/Models/TrainingSession.swift` (256 lines) vs `ShuttlX Watch App/Models/TrainingSession.swift`
  (254 lines): **comments only.** The iOS copy has three trailing comments on `HRRCapture.peakHR`,
  `hrAt60s`, `hrAt120s` and two doc comments on `hrr1` / `hrr2`. Fields, inits, `==`, `hash`,
  and the helper types (`HRRCapture`, `RecoveryReport`, `LegacyCompletedInterval`,
  `CompletedInterval`, `KmSplitData`) are identical.
- `ShuttlX/Models/WorkoutTemplate.swift` vs the watch copy (98 lines each): **byte-identical**
  (`diff` prints nothing).

So unification is a move, not a merge. No field needs to be reconciled.

### 2.2 Which targets compile the models today

From `project.pbxproj`:

| Target | TrainingSession / WorkoutTemplate source | Links ShuttlXShared |
|---|---|---|
| ShuttlX (iOS app) | iOS copy (`A5923505`, `D5923001`) | yes |
| ShuttlXWidgets | iOS copy (`WG000013`, `WG000015`) | yes |
| ShuttlXWatchWidgets | **iOS copy** (`WW100007`, `WW100009` point at the iOS file refs) | yes |
| ShuttlX Watch App | watch copy (synchronized folder, no pbxproj entry) | yes |
| ShuttlXLiveActivity | none | no (not needed) |

All four consumers already link the package, so no linking change is needed.

### 2.3 The name collision and the smallest fix

`Shared/IntervalEngine.swift:173` defines `public enum IntervalType: String { warmup, work, rest, cooldown }`.
The app copy (`WorkoutTemplate.swift:6`) defines `enum IntervalType` with the **same cases and
raw values** plus a `displayName`. Inside an app target the local type shadows the package one,
which is why the models cannot move into `Shared/` as they are: inside the package there would be
two `IntervalType`s.

`CompletedInterval` does not collide (the package's equivalent is `IntervalResult`). No other
moved type name exists in `Shared/` (`IntervalStep`, `HRRCapture`, `RecoveryReport`,
`KmSplitData`, `LegacyCompletedInterval` were checked). The watch's own `IntervalEngine` class
shadows `ShuttlXShared.IntervalEngine` today and keeps doing so; part A does not touch it.

Three ways to resolve it:

1. **Delete the app enum and keep the package one** (add `public var displayName` to
   `Shared/IntervalEngine.swift`'s `IntervalType`). Raw values are identical, so the JSON does not
   change. `ShuttlXColor.forStepType(_ type: IntervalType)` (both targets), `TemplateEditorView`,
   `WatchWorkoutManager.plannedActivity(for:)` and the watch `IntervalEngine` keep compiling
   because the name now resolves to the package enum. The bridge in
   `ShuttlX/Theme/IntervalTypeThemeHelpers.swift:14` (`appType(for:)`) and the conversions at
   `iPhoneWorkoutController.swift:201` and `:423` become identity conversions; they still compile
   and can be simplified later. Effort S.
2. Rename the package engine's enum (for example `EngineStepType`) and keep two enums. Touches
   every engine call site and test (`IntervalEngineTests`, iOS timer views) and keeps the bridge
   code forever. Effort M, no benefit.
3. Move the app enum into `Shared/` under a new name (`StepType`) used by the models, keep the
   engine's enum separate. Two identical enums in one module; every model reader changes its type
   name. Effort M.

**Pick: 1.** It deletes code and changes no wire format.

### 2.4 What moves

One new file per model in `Shared/`: `Shared/WorkoutTemplate.swift` (`IntervalStep`,
`WorkoutTemplate`) and `Shared/TrainingSession.swift` (`HRRCapture`, `RecoveryReport`,
`TrainingSession`, `LegacyCompletedInterval`, `CompletedInterval`, `KmSplitData`). Changes needed
for a package:

- `public` on every type, stored property, computed property and method used outside
  (`displayName`, `totalRunningDuration`, the four calorie rollups, `allSteps`, `totalDuration`,
  `summaryText`, `hrr1`, `hrr2`, `averageHRR1`, `averageHRR2`, `hash(into:)`, `==`).
- Explicit `public init`s. `RecoveryReport` is built with its memberwise init in three places
  (`WatchWorkoutManager.swift:2089`, `:2498`, `iPhoneWorkoutController.swift:371`), so it needs
  `public init(sets:captures:avgWorkHR: = nil, avgRestHR: = nil)`.
- `Sendable` on all of them (every member type is already `Sendable` in the package).
- The one app-side extension, `extension TrainingSession` in `TodayTimeline.swift:10`, adds only
  methods; it keeps working from another module.
- 18 files use these types without `import ShuttlXShared` today and need the import added
  (iOS: ContentView, ShuttlXTheme, DebugView, WeekStripView, CloudKitSyncManager,
  TemplateListView, SessionHeartRateLoader, FeedbackPrompt; watch: ShuttlXTheme,
  ProgramSelectionView, Services/IntervalEngine; iOS widgets: MediumWidget, StartTrainingWidget,
  WidgetTemplateProvider, StartIntents, WorkoutTemplateEntity; watch widgets:
  LastWorkoutComplication, WatchWidgetDataProvider). Do not use `@_exported import`.
- pbxproj: remove the four build-file entries in section 2.2, the two file refs and the group
  children for the iOS copies. Delete the two watch files (synchronized folder, no pbxproj edit).

Out of scope for part A: migrating the watch onto the package `IntervalEngine` and deleting the
watch `Services/IntervalEngine.swift` / `RecoverySegmenter.swift` (the rest of Phase 4 in
`2026-07-codebase-refactor-plan.md`). That step changes workout behavior and needs dual-engine
tests and device QA; part B does not need it. See decision 1.

### 2.5 Wire compatibility of part A

Synthesized `Codable` uses property names as keys and the enums' raw values. Moving a type into
another module changes neither, so `sessions.json`, `workout_templates.json`, the WatchConnectivity
payloads, the CloudKit `jsonData` assets, `pending_sessions/`, `rejected_sessions/`, the watch
checkpoint files and `iphone_workout_checkpoint.json` stay byte-compatible. A golden-file test
(section 7) pins this instead of trusting the reasoning.

## 3. Part B: where `route` is read and written today

### 3.1 Writers (code that sets `TrainingSession.route`)

| File:line | What |
|---|---|
| `ShuttlX Watch App/Services/WatchWorkoutManager.swift:2473` | final watch session: `route: routePoints` |
| `ShuttlX Watch App/Services/WatchWorkoutManager.swift:2073` | 15 s checkpoint session built with `route: nil` |
| `ShuttlX Watch App/Services/WorkoutPersistence.swift:32` | checkpoint strips `route` (route goes to `active_workout_route.json`) |
| `ShuttlX Watch App/Services/WorkoutPersistence.swift:67-71` | crash recovery merges the route side file back in |
| `ShuttlX/Services/iPhoneWorkoutController.swift:362` | iPhone workout session: `route: routePoints` (capped at 6000, `:125`) |
| `ShuttlX/Services/HealthKitImporter.swift:196-197` | Health import loads `HKWorkoutRoute` (capped at 2000, `:29`) |
| `ShuttlX/ShuttlXApp.swift:552-560, 626` | DEBUG demo data |
| `ShuttlX/Views/SessionDetailView.swift:243`, `RouteMapView.swift:170` | previews only |

Every iOS writer hands the session to `DataManager.handleReceivedSessions`
(`iPhoneWorkoutController.swift:439, :442, :479`, `HealthKitImporter.swift:119`,
`CloudKitSyncManager.swift:86`, `PhoneSyncCoordinator.swift:124, :184, :250`,
`DataManager.swift:545` inbox drain). That single entry point is what makes part B tractable.

### 3.2 Readers of a stored session's route

| File:line | What it needs |
|---|---|
| `ShuttlX/Views/SessionDetailView.swift:28-29` | full route for `RouteMapView` (+ elevation) of one session |
| `ShuttlX/Views/Dashboard/TodayTimeline.swift:193` | "has a route with at least 2 points" |
| `ShuttlX/Views/Dashboard/TodayTimeline.swift:258` | `RouteSnapshotCache.image` (already `async`): about 150 points |
| `ShuttlX/Views/HistoryMapView.swift:56` | has-route check |
| `ShuttlX/Views/HistoryMapView.swift:68` | pieces for every routed session of the month (decimated to about 200 points) |
| `ShuttlX/Views/HistoryMapView.swift:104, :107` | first point of each route (same-route grouping) |
| `ShuttlX/Views/HistoryMapView.swift:124` | km marks, full route of the selected session |
| `ShuttlX/Views/HistoryMapView.swift:202` | first point of the selected session |
| `ShuttlX/Views/HistoryMapView.swift:325` | all points of the routed sessions (camera fit) |
| `ShuttlX/Views/HistoryMapView.swift:417` | `RouteThumbnail` per list row |
| `ShuttlX/Services/AnalyticsEngine.swift:298` | `elevationSummary`: altitudes of **every** session in the period |
| `ShuttlX/Services/AnalyticsEngine.swift:333-336` | `latestElevationRoute`: one full route |
| `ShuttlX/ShuttlXApp.swift:256` | demo: "first session with a route" |
| `ShuttlX/Services/PhoneSyncCoordinator.swift:229` | sanity check on the **incoming wire** session (`routeCount`) |
| `ShuttlX Watch App/Services/WatchSyncCoordinator.swift:307` | log line (route point count) |
| `ShuttlX Watch App/Services/WatchWorkoutManager.swift:2307` | crash recovery restores `routePoints` from the backup |

Not affected: `LiveRouteView` and `PhoneSyncCoordinator.liveRoutePoints` (live points, not a
stored session), `ElevationProfileView` and `RouteMapView` (take an array), widgets (never read
`route`).

### 3.3 Where full sessions (with routes) are encoded or decoded

- iOS `sessions.json`: `DataManager` load `:498`, save `:434`; debug read `PhoneSyncCoordinator.swift:729`.
- iOS `sessions_archive.json`: `DataManager.appendToArchive` `:283-312` (write-only; nothing reads it back).
- iOS `pending_sessions/<uuid>.json` and `rejected_sessions/<uuid>.json`: `SessionInbox` (`Shared/StoreSupport.swift:77`).
- iOS `iphone_workout_checkpoint.json`: `PhoneWorkoutCheckpoint`.
- WatchConnectivity receive: `PhoneSyncCoordinator.swift:826` (bulk reply), `:1107`, `:1164`, `:1230`, `:1306` (file transfer).
- CloudKit: `CloudKitSyncManager.makeRecord` `:305` and `applySession` `:217` encode the whole session into the `jsonData` CKAsset; `decodeSession` `:350` decodes it.
- Widgets: `WidgetDataProvider.swift:37` (iOS), `WatchWidgetDataProvider.swift:35` (watch).
- Watch `sessions.json`: `WatchSyncCoordinator.appendSessionToStore` `:617`, `updateSessionEffort` `:601`, `loadSessionsFromStore` `:1175`, purge `:1357`.

## 4. Part B design

### 4.1 The model

`TrainingSession` (now one copy in `Shared/`) changes in two ways:

- The stored property `route` is renamed to `inlineRoute`, with an explicit `CodingKeys` entry
  `case inlineRoute = "route"`. The JSON key stays `"route"`, so every wire format is unchanged,
  but every Swift reader stops compiling and has to be moved on purpose. `inlineRoute` means
  "the route travels inside this value" (WatchConnectivity, CloudKit, inbox, checkpoints, the
  watch's own store). On the iPhone, sessions held by `DataManager` have `inlineRoute == nil`
  once their route is in a file.
- New optional `routeSummary: RouteSummary?` (default nil, decodes from old data):
  `pointCount`, `startLatitude`, `startLongitude`, `ascent`, `descent`, `maxAltitude?`.
  It is computed by a pure `RouteSummary(points:)` in `Shared/` that uses the exact loop in
  `AnalyticsEngine.elevationSummary` today (raw altitude differences, no smoothing).

New `Shared/RouteStore.swift`: a small value type over a directory (`routes/` in the App Group
container) with `write(_ points:, id:)` (encode `[RoutePoint]`, `StoreFile.writeOptions`, so
atomic and readable after first unlock), `read(id:) -> [RoutePoint]?`, `remove(ids:)`,
`storedIDs()`. Plain Foundation, so `swift test` covers it. It follows the pattern the watch
already uses for `active_workout_route.json` (`WorkoutPersistence`).

### 4.2 The single writer

`DataManager` stays the only writer of `sessions.json` and becomes the only writer of `routes/`.

- **Ingest** (`handleReceivedSessions`) and **load** (`mergeLoadedSessions`): for each session
  with an `inlineRoute`, compute `routeSummary`, move the points into a private
  `pendingRouteWrites: [UUID: [RoutePoint]]`, and keep the session in `sessions` without the
  route. Memory drops right away; readers find the points in `pendingRouteWrites` until they are
  on disk.
- **Save** (`startSave`, on `storeQueue`, serial): first write every pending route file, then
  encode the snapshot and write `sessions.json`. A session whose route file write failed is
  encoded **with** its inline route in that snapshot (the format accepts both), and stays pending
  for the next save. `pendingRouteWrites` entries are cleared on the main actor after their file
  write succeeded. The inbox is acknowledged after the `sessions.json` write, as today.
- **Readers** call `DataManager.route(for id: UUID) async -> [RoutePoint]?`: pending writes,
  then an `NSCache` (bounded, for example 30 routes), then `RouteStore.read` on a background
  queue. List screens use `routeSummary` and never load points unless they draw them.
- **Archive** (`appendToArchive`): evicted sessions get their route read back and stored inline
  in `sessions_archive.json` (as today), then their route files are deleted. This keeps
  `routes/` equal to the active list, which makes the orphan sweep safe.
- **Orphan sweep** after the first load: delete `routes/<id>.json` files whose id is not in
  `sessions` and whose modification date is older than 24 hours (the age guard avoids racing a
  session that is still in the inbox).
- **Replacement** (`SessionMerge` victims in `handleReceivedSessions:136-149`): a victim with a
  different id (the phone placeholder) has its route file deleted, which matches today's
  behavior (the placeholder's route is dropped). A same-id victim (a Health copy) keeps its
  file unless the incoming watch session brings its own route, which overwrites it.
- **Effort, Fix a part, effective sessions**: unchanged; they never touch the route.
- `PhoneSyncCoordinator.syncedSessions` (the in-memory relay, `:13`) keeps full sessions with
  routes for the life of the process. After forwarding, it can drop `inlineRoute` from its
  copies. Small fix, same commit as the externalizing step.

### 4.3 Migration of existing `sessions.json`

The migration is the normal path above, not separate code: the first load after the update
finds inline routes, moves them to `pendingRouteWrites`, and requests a save. Before that first
externalizing save, `DataManager` copies `sessions.json` to `sessions_pre_routes_backup.json`
once (only if that file does not exist yet).

Order on `storeQueue`, and what a crash at each point leaves:

1. Copy to `sessions_pre_routes_backup.json`. Crash here: nothing has changed; the next launch repeats it.
2. Write each `routes/<id>.json` (atomic per file). Crash in the middle: `sessions.json` still has every route inline; the next launch rewrites the same files (idempotent).
3. Write the stripped `sessions.json` (atomic replace). This is the moment the old inline data is gone, and by then every route file it pointed to already exists. Crash after it: the routes are in files; nothing is lost.
4. The old copy (`sessions_pre_routes_backup.json`) is deleted one release later (step B6), and by both wipes immediately.

If `sessions.json` is unreadable as a whole, saves are already blocked (`savesBlockedByCorruption`);
the migration does not run until the user starts a new history, so a corrupt file is never
stripped.

Peak memory during the migration is about what a launch uses today (the whole file is decoded
once); after it, every launch decodes about 5 percent of it.

### 4.4 Wipes, purge, Delete Account, rejected sessions

- `DataManager.wipeLocalUserData` (`:589`, used by Clear All Training Sessions and Delete
  Account): add `"routes"` and `"sessions_pre_routes_backup.json"` to `names` (`:607`);
  `removeItem` removes the directory. It runs inside the same `storeQueue.sync`, so a route
  write in progress finishes first and cannot recreate a file afterwards; clear
  `pendingRouteWrites` and the cache in the same call.
- `rejected_sessions/`: quarantined sessions keep their inline route inside the quarantine file
  and never reach `routes/`. The wipe already removes the folder.
- Watch purge (`purgeSessions`): the watch has no `routes/` folder in this plan; nothing changes.
- CloudKit `deleteAllUserData`: the routes live inside the session records' assets; already deleted.
- Debug "clear sessions" (`DebugView.swift:34`) only empties memory; the orphan sweep removes the
  files a day later.

### 4.5 Watch to phone transport (8 MB cap)

The route keeps travelling inside the session payload. The watch caps routes at 2000 points
(`WatchWorkoutManager.swift:253`), about 383 KB raw, and sessions over the 60 KB dictionary budget
already go by `transferFile` (`WatchSyncCoordinator.swift:181-190`, `sendSessionViaFileTransfer`).
The phone refuses anything above `WCPayloadValidation.maxSessionBytes` (8 MB) and more than 200,000
route points, so there is about 20 times headroom. The phone writes the payload to
`pending_sessions/<uuid>.json` unchanged (crash safety), `DataManager` writes `routes/<uuid>.json`
on ingest, then the stripped `sessions.json`, then removes the inbox entry. See decision 4 for the
alternatives.

### 4.6 CloudKit

The record format stays "the whole session as JSON in `jsonData`", with the route inline, so
other devices and older builds keep getting routes.

- Push (`pushSessions`, `makeRecord`, `applySession`): before encoding, re-attach the route
  (`inlineRoute = await dataManager.route(for:)`) one session at a time. If a session has a
  `routeSummary` but its route cannot be read, **skip that session** for this sync instead of
  pushing it without a route: the conflict retry (`applySession`) overwrites server fields with
  local data, so a route-less push could erase the route in iCloud.
- Pull: decoded sessions carry inline routes and enter through `handleReceivedSessions`, which
  writes their files. Nothing else changes.
- `migrateLocalData` pushes `dataManager.sessions`; it needs the same hydration.

### 4.7 Widgets

Add `Shared/SessionHeadline.swift`: a `Decodable` struct with only what widgets read: `id`,
`startDate`, `duration`, `averageHeartRate`, `caloriesBurned`, `distance`, `sportType`,
`programName`, `sessionMode` (for `displayName`) and `segments` (for `SegmentEdits.effective`).
`JSONDecoder` skips every other key, including `"route"`. Decode it with `LenientJSON.decodeArray`
so one bad record no longer empties the widget (today a strict decode returns nothing on any
error).

Use it in both `WidgetDataProvider` (iOS) and `WatchWidgetDataProvider` (watch). The watch
matters more after part B, because the watch `sessions.json` keeps its inline routes. The slim
type still has to read the whole file into memory and scan it, so it reduces work but does not
remove the size problem on the iPhone; part B does.

`MediumWidget.swift:48` and `LastWorkoutComplication.swift:22` hold a `TrainingSession` in their
entry; they switch to `SessionHeadline`. This step does not depend on part B and can ship right
after part A.

### 4.8 Wire compatibility summary for part B

| Surface | Before | After | Compatible |
|---|---|---|---|
| WC session payload (all channels) | session with `"route"` | same | yes, unchanged |
| WC bulk reply `sessionsData` | array with routes | same | yes |
| CloudKit `jsonData` asset | session with `"route"` | same (hydrated on push) | yes, old and new builds read each other |
| `pending_sessions/`, `rejected_sessions/` | session with `"route"` | same | yes |
| iOS `sessions.json` | records with `"route"` | records without `"route"`, with `"routeSummary"` | old builds decode it (missing optional = nil) but show no maps; new builds read both shapes |
| iOS `sessions_archive.json` | with routes | with routes | yes |
| iOS widgets | full decode | slim decode, no route | yes |
| Watch `sessions.json`, watch widgets | with routes | unchanged (slim decode in the widget) | yes |
| Watch checkpoint files | route side file | unchanged | yes |

## 5. Steps (each one ships on its own)

Every step: `bash tests/build_and_test_both_platforms.sh --clean --build`, `swift test`, and the
e2e suites `smoke,workout10,discard` before asking to push. The uncommitted working-tree edits to
`HistoryMapView.swift` and `SessionDetailView.swift` must be committed (or dropped) before B3.

**A0. Golden fixtures (S).** Generate `tests/ShuttlXTests/Fixtures/session_v1.json` (a fully
populated session including route, interval results, recovery report, legacy fields) and
`template_v1.json` from the **current** model with the scratch harness, before anything moves.
Checkpoint: files committed; no code change.

**A1. Move `WorkoutTemplate` (S).** Add `displayName` to the package `IntervalType`; create
`Shared/WorkoutTemplate.swift` (public); delete both target copies and the app `IntervalType`;
remove the pbxproj entries; add the missing imports. Test: `template_v1.json` decodes and
re-encodes to the same key set. Checkpoint: four targets build.

**A2. Move `TrainingSession` (S-M).** Create `Shared/TrainingSession.swift` (public, `Sendable`,
public inits incl. `RecoveryReport`); delete both copies and the pbxproj entries; add imports.
Test: `session_v1.json` round-trip, key set pinned. Checkpoint: four targets build, `swift test`.

**A3. Docs (S).** Retire "update BOTH copies" in `.claude/rules/models.md` and CLAUDE.md; update
`docs/memory/`. Ship A as its own TestFlight build and let it run a few days.

**W. Widget slim decode (S).** `Shared/SessionHeadline.swift`, both widget providers and the two
entry types. Test: decodes `session_v1.json` arrays, skips a bad record, ignores `"route"`.

**B0. Pure parts (S).** `RouteSummary`, `RouteStore`, `routeSummary` property (unused yet).
Tests in section 7. No behavior change.

**B1. Rename `route` to `inlineRoute` (S).** Explicit `CodingKeys` with `"route"`; mechanical
edit of every site in section 3 (watch included). The golden test proves the JSON did not change.
No behavior change.

**B2. Readers go through `DataManager.route(for:)` and `routeSummary` (M).** While no route file
exists yet, `route(for:)` returns the inline route, so behavior is unchanged; summaries are
filled in memory on load. Per reader: SessionDetailView loads its route in `.task(id:)`;
TodayTimeline checks `routeSummary.pointCount >= 2` and `RouteSnapshotCache.image` loads the
route inside its existing `async`; HistoryMapView loads the visible month's routes into a
`[UUID: [RoutePoint]]` state when `sessions` changes (off the main thread) and uses the summary's
start point for grouping; `elevationSummary` reads summaries only; `latestElevationRoute` picks
the newest session with altitude from summaries and loads that one route; the DEBUG demo seeds
`pendingRouteWrites` so screenshots keep their maps. Checkpoint: snapshot History map, Today, a
session detail and Trends elevation on the simulator with demo data and compare with the
pre-change screenshots.

**B3. Externalize (M, the only risky step).** Section 4.2-4.4: ingest/load stripping, save order,
pre-migration backup, archive rehydration, orphan sweep, wipe list, relay stripping. The
ordering logic lives in a Shared function (`RouteStore` plus a small `writeSnapshot` helper that
takes the sessions, the pending routes and a container URL) so `swift test` can exercise the
crash cases. Checkpoint: on a simulator, seed a real-sized history (demo generator writing to the
App Group, DEBUG), launch the new build, check that `routes/` has one file per routed session,
that `sessions.json` has no `"route"` key and is about 5 percent of its old size, and that every
map still draws. Then kill the app during the migration (breakpoint between route writes and the
`sessions.json` write) and relaunch: no route lost.

**B4. CloudKit hydration (S).** Section 4.6. Checkpoint: signed-in simulator account; push a new
session; on a second simulator, pull it and see its map.

**B5. Device pass.** Install over the App Store build on the owner's iPhone with real history
(download the App Group container from Xcode first as a backup), run a workout on the watch,
check the map, the widget, Clear All Training Sessions (`routes/` gone).

**B6. Cleanup, one release later (S).** Delete `sessions_pre_routes_backup.json` on launch; docs.

Rough effort: A about 1 day, W half a day, B0-B2 about 1.5 days, B3-B4 about 1.5 days, plus
device time. Total L, as estimated in the open-items plan.

## 6. Rollback

- **A, W, B0, B1, B2:** no on-disk change. Revert the commit.
- **B3 and later:** once a stripped `sessions.json` is on a device, a build without B3 still
  decodes it (the missing `"route"` key is nil) but shows no maps. Its saves keep the file
  stripped; route files are left alone. Reinstalling the new build shows the maps again
  (summaries are rebuilt from the files when missing). App Store users cannot downgrade, so this
  only applies to TestFlight.
- **Emergency fix-forward:** keep the reader that accepts inline routes forever, and keep a
  DEBUG / hidden-Sync-Debug action "Put routes back into history" that hydrates every session
  and writes an inline `sessions.json`. The pre-migration backup is the last resort for one
  release.
- **Data-loss guard:** the only moment old route data disappears is the atomic replace of
  `sessions.json`, after every route file it depends on has been written.

## 7. Tests to add (`swift test`, all pure)

1. `ModelWireCompatibilityTests`: `session_v1.json` and `template_v1.json` decode; re-encoding
   gives the same key set; `IntervalType` raw values pinned; after B1, `inlineRoute` encodes as
   `"route"`.
2. `RouteSummaryTests`: same ascent, descent and max as the current `elevationSummary` loop on
   a fixed route; no altitudes gives nil `maxAltitude`; 0 and 1 point.
3. `RouteStoreTests` (temp directory): write/read round-trip, missing file is nil, corrupt file is
   nil and does not throw, `remove`, `storedIDs`.
4. `RouteExternalizeTests`: stripped snapshot has no `"route"` key; a failing route write leaves
   that session inline in the written file; a failing `sessions.json` write leaves the old file
   and the route files; a second run is idempotent; a file with mixed records (inline and
   stripped) loads.
5. `SessionHeadlineTests`: decodes full sessions, skips a bad record, ignores the route.
6. `SessionsFileSizeTests`: 200 generated 60-minute sessions with 1000 points each give a stripped
   file under 2.5 MB (the "Check" from the open-items plan).
7. A wipe-list test if the file list moves into a Shared constant (it should contain `routes`).

DataManager itself is not in a test target. Its wiring is covered by the simulator checkpoints
in B2, B3 and B5 and by the e2e suites.

## 8. Risks

- **A reader still expects the inline route** and shows no map. Not data loss. The B1 rename
  makes the compiler find every reader; the B2 snapshots check the visible ones.
- **Route file write fails** (disk full). The session stays inline in `sessions.json` and is
  retried; nothing is dropped.
- **Summary math drifts** from the current elevation numbers on Trends. Pinned by test 2.
- **History map month load cost**: about 30 file reads of about 190 KB for a busy month. Not
  measured on device; done off the main thread with a cache.
- **CloudKit erases a route** if a session is pushed without it. Guarded by skipping sessions
  whose route cannot be read (section 4.6). Unverified until B4's two-simulator check.
- **Watch `sessions.json` keeps growing with routes.** From code reading, the watch never trims
  it (only a phone wipe purges it), and every new session decodes and re-encodes the whole file
  on the watch (`appendSessionToStore`, `WatchSyncCoordinator.swift:617`). Unverified; not part
  of this plan. See decision 5.
- **Pending-route memory before the first save** equals today's in-memory routes, and only until
  the save finishes.
- **Uncommitted local edits** in HistoryMapView and SessionDetailView will conflict with B2 if
  they are not committed first.

## 9. Verification still owed (unverified hypotheses)

- **Widget memory crash:** reproduce before claiming it. Seed a 200-session, 1000-point history
  in the simulator App Group (DEBUG generator), add a temporary `os_proc_available_memory()` log
  before and after the decode in `WidgetDataProvider.loadSessions`, reload timelines, and look
  for the log plus a jetsam / `EXC_RESOURCE` report in Console. Repeat after W and after B3.
- **iPhone decode time** for the current history: log the load duration in
  `DataManager.loadSessionsFromAppGroup` (an `OSSignposter` interval) on the owner's device,
  before and after B3.
- **Watch store growth:** read the watch `sessions.json` size from the Sync Debug screen or a
  log line on the owner's watch.

## 10. Hardest decisions, three ways each

### Decision A: how the model carries the route after the split

1. Keep `route` as is and strip it only when `DataManager` writes `sessions.json`; readers switch
   to `route(for:)` as they are found. Smallest diff (no watch edits), but a missed reader silently
   reads nil, and new code will keep reaching for `session.route`. Effort M.
2. **Rename to `inlineRoute` (JSON key still `"route"`), add `routeSummary`, read points through
   `DataManager.route(for:)`.** The compiler lists every reader; the wire stays identical; list
   screens use the summary. Costs explicit `CodingKeys` (about 30 keys, pinned by the golden test)
   and mechanical edits in about six watch lines. Effort M-L.
3. Remove the route from `TrainingSession` entirely; send it as its own object (new WC action,
   new CloudKit field or record type). Cleanest model, but breaks wire compatibility with older
   watch builds and existing CloudKit records, so it needs dual decoding for a long time.
   Effort XL.

**Pick: 2.**

### Decision B: what list screens (History map, Today cards, Trends elevation) read

1. **Summary in `sessions.json` (point count, start point, ascent, descent, max altitude) plus
   lazy loading of the points for what is on screen** (one session, one month). Smallest file,
   a bit more code in HistoryMapView. Effort M.
2. Keep a decimated preview polyline (about 150 points) inline in `sessions.json`. Simplest
   readers, but about 28 KB per session (about 5.6 MB at 200 sessions), so the file and the widget
   decode grow again. Effort S-M.
3. Load all routes when History opens. Simple, but memory and time are what they are today,
   only moved to the History tab. Effort S.

**Pick: 1.**

### Decision C: how the route travels from the watch

1. **Unchanged: inside the session payload**, `transferFile` for large sessions, 8 MB cap with
   about 20 times headroom. No wire change. Effort none.
2. A separate route file transfer after the session. Smaller first payload, but two-part delivery,
   ordering and retry for both parts. Effort M.
3. The phone reads the route from Apple Health (the watch saves an `HKWorkoutRoute`). Removes
   the route from WatchConnectivity, but depends on Health permissions and on the route save,
   which is not yet verified on device. Effort M, risky.

**Pick: 1.**

### Decision D: migration style

1. **Implicit and idempotent: any inline route found on load or ingest is externalized on the
   next save, after a one-time backup copy.** One code path for new and old data. Effort S on top
   of B3.
2. A dedicated migrator with a version marker and a journal. Explicit, but a second code path
   that runs once and is hard to test later. Effort M.
3. Batch migration (for example 20 sessions per launch) to cap the work per launch. Spreads the
   cost, but `sessions.json` stays mixed for many launches and every save still writes the
   remaining routes. Effort M.

**Pick: 1.**

## 11. Decisions the owner must make

1. **Scope of part A:** models only (this plan), or also move the watch onto the package
   `IntervalEngine` now (Phase 4 proper, behavior-affecting, needs dual-engine tests and a device
   QA pass)? Recommendation: models only.
2. **Decision A** (route shape in the model): option 2?
3. **Decision B** (list screens): summary plus lazy loading?
4. **Phone placeholder route:** when a watch session replaces the iPhone's placeholder, keep
   today's behavior (the phone's GPS route is dropped), or keep the phone route when the watch
   session has none?
5. **Watch `sessions.json` growth:** accept as is, or plan a follow-up (for example, drop routes
   from watch sessions older than 30 days that the phone has acknowledged, and cap the file)?
6. **Release shape:** ship A (with W) as its own TestFlight build before starting B? Recommended.
7. **Pre-migration backup:** keep `sessions_pre_routes_backup.json` for one release (costs disk
   equal to today's file), or skip it?
