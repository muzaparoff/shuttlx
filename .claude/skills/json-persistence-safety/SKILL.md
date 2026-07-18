---
description: JSON persistence safety checklist for ShuttlX App Group storage — single-writer rule, corruption recovery, schema versioning, id stability
user_invocable: true
---

# /json-persistence-safety

Apply when writing or reviewing any code that reads or writes `sessions.json`, `workout_templates.json`, `exercise_devices.json`, or any App Group JSON store.

## Single-writer rule

- [ ] Exactly ONE class owns writes to each JSON file per platform. Grep for all writers of the target file before adding another. Known violation to not repeat: iOS `PhoneSyncCoordinator.saveSessionsToSharedStorage` and `DataManager.saveSessionsToAppGroup` both writing `sessions.json` from divergent in-memory arrays (last-writer-wins data loss).
- [ ] If two components need the data, one owns the file and the other holds an in-memory relay.
- [ ] Read-append-write cycles must be atomic per file: serialize through one queue (existing `sessionStoreQueue` pattern) and/or `NSFileCoordinator`.

## Corruption recovery — never destroy data

- [ ] On decode failure: back up the corrupt bytes, then **ABORT the write**. Never continue with an empty array and overwrite the live file — that converts one bad record into total history loss.
- [ ] Corrupt-file backups need an auto-restore path on next launch, and must not be purged before restore is attempted.
- [ ] Never `try?` on encode/decode — `do/catch` with `os.log`.

## Schema evolution

- [ ] Every persisted model needs backward-compatible decoding: new properties get default values.
- [ ] Enums use `String` raw values for stable encoding.
- [ ] Prefer a versioned envelope (`{version, payload}`) for new stores; gate decode on version and run ordered migrations with a pre-migration backup. (`sessions.json` predates this — the S9 refactor adds it.)

## Capacity & eviction

- [ ] Caps must evict OLDEST (to archive), never drop NEWEST. Known violation to not repeat: 500-session cap in `DataManager` discarding incoming new sessions.
- [ ] A dropped/evicted item must be observable in logs — never a silent `guard ... else { return }`.

## Identity & dedup

- [ ] Ids used for dedup must be created once and passed explicitly through every save path (checkpoint, final, recovery, sync). A `UUID()` default parameter re-generating per call breaks dedup silently.

## Performance

- [ ] Reads AND writes of whole-history files stay off the main actor (writes were fixed in 4890fb1/f7d1e3e — hold reads to the same bar).
- [ ] Appends should not decode+re-encode the entire history when avoidable; batch multi-item operations into one read-modify-write.
- [ ] Route-point-heavy payloads (GPS sessions) belong in per-session sidecar files, with the index file holding lightweight summaries (target architecture from audit S9).

## No force unwraps

- [ ] `FileManager.default.urls(for:in:)` → `guard let .first`.
- [ ] Never `!` or `[0]` on decode results.
