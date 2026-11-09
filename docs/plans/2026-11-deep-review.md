# Deep review: 24 accepted ideas (2026-11-09)

Source: review page https://claude.ai/artifact/7GMo9BxBkPAkW8NWkU9Y9j ("38 ideas to make ShuttlX the calm heart-limit app for Apple Watch").
Research behind it: market scan (19 apps), Apple data inventory (SDK 26/27 headers), design audit D1-D24.

## Owner decisions

The owner said "use your picks" (2026-11-09), and separately chose D5 = In on the page (2026-11-08).

- **In (24):** H1, H2, R1-R8, A1, A2, A6, D1-D5, D7, S1, S3, S4, T1, T2.
- **Later (11):** H3 care-team PDF, H4 effort per set, R9 spoken cues, A3 guided 6-minute walk, A4 movement-based effort, A5 Apple alerts on History, A7 AirPods heart rate, A10 medication list, D6 usual-range band, S2 Live Activity + StandBy, S5 price model.
- **Out (3):** H5 weights and reps, A8 HRV readiness score, A9 Apple live zones.

Defaults taken where an item left a choice open (any of these can be changed):

- R3: time in zone uses today's limit, labelled "with your current limit". The limit is not stored per session (no model change).
- R1: the repeat rule is worded as a suggestion ("Repeat this day?"), never as advice.
- H1, T2: each starts with a device check. If the check fails, the item stops and is reported.

## Waves

Each wave is planned, built on both platforms, shown to the owner and committed only when the owner approves.

| Wave | Items | Platform | Size | Notes |
|------|-------|----------|------|-------|
| 1. Small fixes and wording | R6, R4, R5, D2, D3, D4, D7, S4, T2 (Help line) | iOS + watch | S each | No model or sync change. S4 = a wording rule in `.claude/rules/` plus Help and onboarding copy. |
| 2. Trust | T1 remove CloudKit session sync | iOS | S | Hard to reverse for the few users still signed in from an old build: their cloud copies stop updating, and the local history stays. Announce it in the release notes. |
| 3. Watch pages | R7 (= watch plan step 3), R8, D5 | watch | M | Ships with Wave 5 C2c, as already planned. Then watch plan steps 4-6 as written. |
| 4. Signature ring | D1 | Shared + iOS + watch | M | Move `GlassRingProgress` from the widgets to `Shared/`. Weekly goal shown as "92 of 150 min", never red. |
| 5. After the workout | R2 one-line story, R3 time in zone | iOS + Shared | M | `Shared/WorkoutStory.swift` (pure, tested). Describe only. |
| 6. Heart Recovery data | H1 write HRR to Health, H2 8-week trend card | watch + iOS | M | H1 device check first: can an app write `heartRateRecoveryOneMinute`? |
| 7. Apple data | A1 resting + walking HR, A2 walking speed + 6-minute walk, A6 background import | iOS | M | Read-only. A6 adds the `healthkit.background-delivery` entitlement (hourly). |
| 8. Ladders | R1 "Walk 30 minutes", "Walk to Run" | Shared + iOS + watch | M | Built on `TrainingPlan` / `BuiltInPlans`. |
| 9. Reach | S1 Control + Smart Stack, then S3 new store screenshots | watch + store | M | Screenshots go last, after the UI has settled. |

## Rules that bind every wave

- Describe, never diagnose. No "good", "recovered", "abnormal". No red/green grading of heart recovery. Compare users only with their own past.
- The medication answer stays on the iPhone. Effort never goes to Health or telemetry.
- Watch sizes are solved, never scaled. Snapshot-check 40 mm and 46 mm.
- Build both platforms after each change. Never kill xcodebuild/simctl (a shared CI runner uses this Mac).
- A bug found along the way: report it with 3 ways to fix it, then wait for the owner.

## Status

- 2026-11-09: plan written; the owner said "go" for Wave 1.
- 2026-11-09: Wave 1 implemented, uncommitted. Both platforms build. Snapshot-checked on 40 mm and 46 mm and on iPhone.
  - Not checked yet: the effort edit sheet (the simulator could not tap it), the Today tiles at accessibility text sizes, and the watch numerals on a real device.
  - Open for the owner: whether "detects" is banned everywhere (the agent replaced "auto-detects" in the run/walk copy) or only in heart claims.
  - Theme follow-up for the owner: the watch summary numbers still use SF Rounded (`watchSummaryMetric`); the unused `hrZone1-5`, `forHRZone` and monospaced timer tokens could be deleted.
- 2026-11-09: Wave 2 T1 implemented, uncommitted. CloudKit session push/pull, merge, `migrateLocalData`, `pushTemplates`, the debounced sync in `DataManager`, the scenePhase sync and `RouteExternalize.forUpload` (+ its test) are deleted. Kept: `CloudKitSyncManager.deleteAllUserData` (Delete Account), entitlement and container. Template sync never ran (`pushTemplates` had no caller, no pull). iOS builds, `swift test` 260 passing (one removed test).
- 2026-11-09: Wave 3 implemented, uncommitted (with Wave 5 C2c). Watch and iOS build; snapshot-checked on 40 mm and 46 mm. R7: Controls | Workout | More in every mode, Workout page with time / part timer / distance / BPM + word, interval page down to 5 elements (DIST / PACE / TIME / CAL on More). R8: Always-On on every page shows the cue (gym READY / SET n / REST clock, interval step + countdown, free-run zone word, PAUSED) as system timer text. D5: Liquid Glass on Keep going, Skip and the Home / Mixed rows (watchOS 26+), safety cards solid.
  - Not checked on a device: Always-On timer seconds with a real session, glass contrast in sunlight, the page order by touch.
  - Owner: keep the "RUN/WALK" part row before the first classification, even though it equals the total time (2026-11-09).

