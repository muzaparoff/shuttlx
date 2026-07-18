---
description: Swift concurrency review checklist for ShuttlX — actor isolation, queue conventions, delegate hopping, known-good patterns to preserve
user_invocable: true
---

# /swift-concurrency-review

Apply when writing or reviewing any code in `Services/`, `Managers/`, or anything touching actors, queues, or `Task`.

## Actor isolation

- [ ] `@MainActor` on `ObservableObject` / `@Observable` UI-facing classes — never `@unchecked Sendable` as an escape hatch.
- [ ] Timer creation and access on the same actor.
- [ ] No `Task.detached` → `MainActor.run` chains (deadlock risk) — use structured `Task { @MainActor in ... }` hops.
- [ ] Delegate callbacks (WCSession, HealthKit) arrive on arbitrary queues — hop to `@MainActor` via `Task`, but read any callback-scoped values (e.g. `WCSessionFile.fileURL`) synchronously BEFORE the hop (known-good pattern: PhoneSyncCoordinator file-receive handler).

## Queue conventions in this repo

- [ ] File I/O for session stores goes through the dedicated serial queue (`sessionStoreQueue` pattern, both platforms) — never ad-hoc `DispatchQueue.global()` for store access.
- [ ] Heavy JSON decode/encode stays off the main actor — reads and writes both (writes fixed in 4890fb1/f7d1e3e; hold new code to the same bar).
- [ ] One serial queue per resource, not per operation — adding a second queue for the same file reintroduces races.

## Known-good patterns to preserve (from July 2026 audit)

- Single-flight guard `isBurstScheduled` (WatchSyncCoordinator) prevents retry-burst stacking — reuse this pattern for any new periodic retry.
- Id-based dedup in `handleReceivedSession` before persistence.
- Off-main-actor session-store queues on both platforms.

## General

- [ ] `guard let self = self else { return }` in escaping closures.
- [ ] No fire-and-forget `Task {}` whose failure would lose user data — ordering matters (e.g. backup clear must not race the save it follows).
- [ ] Async work triggered per-tick (1 s metrics, 15 s retries) must be idempotent and non-accumulating — verify a slow iteration cannot overlap the next.
