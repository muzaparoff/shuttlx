---
description: Review checklist for WatchConnectivity sync code — payload limits, applicationContext semantics, retry rules, and known ShuttlX sync pitfalls
user_invocable: true
---

# /wcsession-sync-review

Apply when writing or reviewing any code touching `WCSession`, `PhoneSyncCoordinator`, `WatchSyncCoordinator`, or `LiveMetricsBroadcaster`.

## Hard platform limits (verify against every payload path)

- [ ] `sendMessage` payload AND its reply are capped at ~65 KB. Any code building a reply from a **collection** of items must enforce a *cumulative* byte budget (~50 KB safe), not just per-item size checks. Overflow goes to `transferUserInfo` / `transferFile`.
- [ ] `updateApplicationContext` **replaces the entire dictionary** on every call. Any new writer must merge with existing keys, never write a partial dictionary. iOS has `updateCombinedApplicationContext(merging:)` (PhoneSyncCoordinator.swift) — the watch side must use an equivalent merged-context helper. Grep for all `updateApplicationContext(` call sites and confirm exactly ONE merge-aware funnel per platform.
- [ ] `transferUserInfo` and `transferFile` queues survive app termination; `sendMessage` does not. Anything that must not be lost goes through a durable channel or a disk-backed pending queue.

## Retry & reachability rules

- [ ] Exponential backoff, max 5 retries, single-flight guard (see `isBurstScheduled` pattern in WatchSyncCoordinator.swift — keep it).
- [ ] Retrying an operation that failed due to **size** must not retry the same oversized payload — split or reroute first.
- [ ] Check `isReachable` before `sendMessage`; fall back to `transferUserInfo`.
- [ ] Retry loops over N pending items must not trigger O(N) full-file re-encodes per tick; batch instead.
- [ ] Pending queues (`pending_sync_sessions.json`) must be bounded by age or count — never unbounded growth during offline stretches.

## Session/data integrity

- [ ] Inbound sessions on iOS go through ONE handler path that persists, buffers (if DataManager is nil), and dedups. Never append to an in-memory array without persisting.
- [ ] Dedup relies on stable `TrainingSession.id` — an id must be created ONCE per workout and passed to every save (checkpoint, final, recovery). Never rely on `UUID()` default init in multiple save paths.
- [ ] Exactly one owner writes each JSON file per platform (see /json-persistence-safety).

## Known ShuttlX history (do not regress)

- Large-session sync fix: sessions >200 KB route via file transfer (WatchSyncCoordinator size-tier routing).
- Theme sync uses `"syncTheme"` action via applicationContext — a metrics tick must never clobber it.
- `sendAllStoredSessions` is throttled 60 s per reachability flip — keep the throttle.
