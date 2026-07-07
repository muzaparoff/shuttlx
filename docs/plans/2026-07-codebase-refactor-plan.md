# Codebase Readability & Maintainability Refactor Plan — July 2026

> **Status (2026-07-07):** Phase 0 DONE (CI runs swift test; parity guard added).
> Phase 1 DONE (dead theme code deleted; PhoneSyncCoordinator/WatchSyncCoordinator
> rename; iOS helper dedup). Phase 2 DONE-with-scope-note: RoutePoint, HRZC,
> FormattingUtils, WorkoutSport (split), SessionMode, TrainingPlan, BuiltInPlans,
> ExerciseDevice, ActivitySegment+DetectedActivity all moved to ShuttlXShared;
> TrainingSession + WorkoutTemplate BLOCKED on the IntervalType name collision
> with the package engine — they move as part of Phase 4. Phases 3–5 pending.

Synthesis of a 4-agent read-only audit (senior-architect: repo structure; senior-ios-developer: iOS god-files; swiftui-watchos-specialist: watch decomposition; test-author: safety net). Companion to `2026-07-stability-and-design-plan.md` (freeze fixes + design). Everything here is structure-only — zero behavior change — except Phase 4, which is explicitly flagged.

## Corrected facts (verified by audit — update mental model & docs)

- iOS **already imports ShuttlXShared** (8 files). Only the watch target ignores the package. It is half-wired, not unused.
- `Shared/` holds 4 files: IntervalEngine, RecoverySegmenter, DetectedActivity, HapticPlayer.
- The 8 duplicated models are byte-identical or comment-only drifted — NOT functionally diverged. Low-risk to consolidate now.
- The watch `Services/IntervalEngine.swift` is a genuinely **different implementation** from `Shared/IntervalEngine.swift` (WorkoutTemplate-coupled, direct WKInterfaceDevice haptics vs descriptor-based, protocol-injected haptics). Phone and watch can produce divergent interval behavior today.
- 28 passing tests exist (`tests/ShuttlXTests/`, `swift test` → 28/28) but **CI never runs them**.
- Long *functions* are not a problem (only 15 ≥80 lines, longest 139, mostly Canvas drawing). The problem is god-*files* (WatchWorkoutManager 1,622; ThemeAssets 1,137/1,030; TrainingView 980; heroes 756–1,013; SharedDataManager 864/799).

## Phase 0 — Safety net (BEFORE anything moves)

| # | Task | Effort |
|---|---|---|
| 0.1 | Add `swift test` step to `.github/workflows/test.yml` (28 existing tests become CI-enforced) | S |
| 0.2 | Watch-parity test file for `Services/RecoverySegmenter` (no WatchKit dep — SPM-testable) mirroring the 19 Shared tests | S |
| 0.3 | Minimal Xcode-hosted iOS XCTest target (`ShuttlXAppTests`, name avoids SPM module collision) + model Codable round-trip & backward-compat decode suite for the 8 shared models | M |

Do NOT characterization-test WatchWorkoutManager pace/cadence/HR math as-is — no seam exists; extract first (Phase 3), test the extracted value types.

## Phase 1 — Zero-risk deletions, renames, dedup

| # | Task | Effort |
|---|---|---|
| 1.1 | Delete dead theme code: `ThemePreset.swift` (both targets, only referenced by a comment), `CardStyle.meter` case, `.meter` modifier block + `VUGaugeHeader`/`VUScaleFooter` in ThemeModifiers (both) | S |
| 1.2 | Rename the misnamed pair: iOS `SharedDataManager` → `PhoneSyncCoordinator`, watch `SharedDataManager` → `WatchSyncCoordinator` (1,267 diff lines, opposite jobs, neither shared). Fix false doc comments ("watch consumes ShuttlXShared directly" — it doesn't) | S |
| 1.3 | iOS cross-cutting dedup: new `ShuttlX/Theme/IntervalTypeThemeHelpers.swift` with `appType(for:)`, `hrZoneLabel(_:)`, `stepColor(for:)` — byte-identical private copies exist in 6 files (iPhoneWorkoutTimerView + 5 TimerHeroes). Also dedupe the identical Finish/Cancel alert pair and the ×3 `StepPillInfo` struct. HR-zone threshold changes currently require 6 identical edits | S |

## Phase 2 — Consolidate shared code (kills the duplication rule)

| # | Task | Effort |
|---|---|---|
| 2.1 | Add ShuttlXShared to the watch target (link only; nothing changes) | S |
| 2.2 | Move 8 Foundation-only files to `Shared/`, one commit each, build both after each: BuiltInPlans, ExerciseDevice, HeartRateZoneCalculator, RoutePoint, TrainingPlan, TrainingSession, WorkoutTemplate, FormattingUtils. Mark `public`, delete both target copies | S→M |
| 2.3 | Split `ActivitySegment` + `WorkoutSport`: Codable core → package; `Color`/`HKWorkoutActivityType` extensions stay per-target. Collapse the ×3 `DetectedActivity` definitions to the package one in the same commit | M |

Retires the "models are duplicated — update BOTH copies" rule permanently. App Group access stays out of the package (verified: no SHARE candidate touches the container).

## Phase 3 — God-file splits (pure moves; compiler-verified)

### iOS (ranked payoff vs risk)
| # | File | Split | Effort |
|---|---|---|---|
| 3.1 | ThemeModifiers.swift (776) | core modifiers / ThemeScreenBackgrounds / ThemeCardChrome | S |
| 3.2 | ThemedSceneBackground.swift (512) | ThemedScene protocol / MixtapeCassetteScene | S |
| 3.3 | SettingsView.swift (653) | extract 9 sections to computed vars; move ToastView + HealthPermissionsInfoView out | M |
| 3.4 | iPhoneWorkoutTimerView.swift (728) | root+dispatcher / +StandardBody / +FMTuner / helpers (delete → use 1.3) | M |
| 3.5 | PhoneSyncCoordinator (864) | move WCSessionDelegate extension (629–864) then Sync extension to own files | M |
| 3.6 | ThemeAssets.swift (1,137) | dispatchers stay; Frame+Badge per theme → fold into existing `Themes/<Name>.swift`; 5 shared Canvas shapes → ThemeAssetsShapes | M |
| 3.7 | iPhoneWorkoutController.swift (686) | core / +Sensors / +GymRecovery — tightest-coupled, do last, only if needed | M–L |
| — | 5 × TimerHero files | do NOT split beyond 1.3 dedup — single-responsibility Canvas art, no external consumers | — |

### watchOS
| # | Task | Effort |
|---|---|---|
| 3.8 | TrainingView.swift (980) → 6 files, pure moves: WorkoutSummaryView first (self-contained), then +Metrics, +Controls, +ThemeChrome, IntervalStepWash. Note: Mixtape branch replaces the metrics body — stays in dispatch | M |
| 3.9 | WatchWorkoutManager (1,622) staged decomposition (full function→unit map in agent report, preserved below): Step 0 move delegate extensions to files (S) → HealthKitAuthService (S) → WorkoutPersistence + `WorkoutSnapshot` value type (M) → LiveMetricsBroadcaster (M) → WorkoutSessionCoordinator (L) → SensorPipeline (L). Root stays the @Published view-model; collaborators are plain @MainActor classes pushing via callbacks — NOT ObservableObject (avoids double-render regression noted at :56-61) | S→L staged |

Key decomposition rules (from watch specialist):
- All `@Published` stay on WatchWorkoutManager — zero view changes.
- Manager holds strong refs to collaborators (they become the weak HK/CL delegates).
- `WorkoutSnapshot` (Sendable) is the seam that later lets persistence go off-main-actor and enables periodic checkpointing — aligns with freeze-fix Phase 1/2.
- No concurrency changes in this refactor; every unit stays @MainActor.

## Phase 4 — Engine unification (ONLY behavior-risky step)

Migrate the watch onto `Shared/IntervalEngine`: build `[IntervalStepDescriptor]` from WorkoutTemplate at the call sites, add `WatchHapticPlayer: HapticPlayer` (mirror of iPhoneHapticPlayer), delete watch `Services/IntervalEngine.swift` + `Services/RecoverySegmenter.swift`. Effort L.

Gates before merging:
1. Dual-engine scenario tests: same inputs through both engines, assert identical step sequences/results (the existing 28 tests only pin Shared's behavior, not the watch's).
2. Real-workout QA pass on device.

This also removes the phone/watch interval-behavior divergence risk.

## Phase 5 — Docs refresh

Update CLAUDE.md, `.claude/rules/*`, `docs/memory/*`: stale line counts (WatchWorkoutManager "944"→post-split reality, TrainingView "357"→980, etc.), "Shared/ doesn't exist" (it does, 4 files, iOS consumes it), retire the "update BOTH copies" model rule after 2.2, dead VU-meter references, new file map. Consider consolidating root clutter (`theme-previews/`, `audits/`, `specs/`, loose root .md files) under `docs/`.

## Interleaving with the freeze fixes (2026-07-stability-and-design-plan.md)

Recommended combined order:
1. Phase 0 (safety net) — 1 short session
2. **Freeze-fix Phase 1** (wall-clock countdown, periodic checkpoint, recoverActiveWorkoutSession, didChangeTo handling) — into current code, small diffs; users are losing data today
3. Refactor Phases 1–2 (deletions, renames, dedup, shared models)
4. Refactor Phase 3 (god-file splits; watch decomposition creates the seams freeze-fix Phase 2 needs)
5. **Freeze-fix Phase 2** (persistence off main actor, sensor coalescing) — now trivial on the decomposed structure
6. Phase 4 (engine unification) + Phase 5 (docs)

Theme decision dependency: if the 7→5 theme cut (Classic Radio + FM Tuner) is approved, do it BEFORE 3.6/3.1 theme-file splits — no point splitting files that get deleted.

## Effort summary
- Phase 0: ~1 day · Phase 1: ~0.5 day · Phase 2: ~1–1.5 days · Phase 3: ~3–4 days staged · Phase 4: ~1–2 days + QA · Phase 5: ~0.5 day
- Every step leaves both targets building; one commit per move so any regression bisects to a single mechanical change.
