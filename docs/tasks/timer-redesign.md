# Task Board — Timer Redesign Sprint

Last updated: 2026-06-06

| ID | Phase | Task | Owner | State | Files | Notes |
|----|-------|------|-------|-------|-------|-------|
| T0.1 | 0 | Convert free-run DIST/PACE/CAD to compactMetric two-up rows | lead | DONE | ShuttlX Watch App/Views/TrainingView.swift | Fixes BPM-not-showing in walk/run — layout overflow on 41mm |
| T1.1 | 1 | Watch-sized spec — Synthwave | product-designer | DONE | design/proposals/timer-theme-redesigns/synthwave-watch.md | |
| T1.2 | 1 | Watch-sized spec — Mixtape | product-designer | DONE | design/proposals/timer-theme-redesigns/mixtape-watch.md | |
| T1.3 | 1 | Watch-sized spec — Arcade | product-designer | DONE | design/proposals/timer-theme-redesigns/arcade-watch.md | |
| T1.4 | 1 | Watch-sized spec — Classic Radio | product-designer | DONE | design/proposals/timer-theme-redesigns/classic-radio-watch.md | |
| T1.5 | 1 | Watch-sized spec — VU Meter | product-designer | DONE | design/proposals/timer-theme-redesigns/vu-meter-watch.md | |
| T1.6 | 1 | Watch-sized spec — Neovim | product-designer | DONE | design/proposals/timer-theme-redesigns/neovim-watch.md | |
| T2.1 | 2 | Add `themedTimerBody` switch on iOS | lead | DONE | iPhoneWorkoutTimerView.swift | Dispatch ready for Phase 3 cases |
| T2.2 | 2 | Watch dispatch via existing FM Tuner conditional pattern | lead | DONE | TrainingView.swift | Phase 3 watch agents add `if themeManager.current.id == "<theme>"` chrome overlays mirroring the FM Tuner block |
| T3.1a | 3 wave 1 | Synthwave hero — iOS | senior-ios-developer | DONE | ShuttlX/Theme/Themes/SynthwaveHero.swift | New file per theme |
| T3.1b | 3 wave 1 | Synthwave hero — watch | swiftui-watchos-specialist | DONE | ShuttlX Watch App/Theme/Themes/SynthwaveHero.swift | |
| T3.2a | 3 wave 1 | Mixtape hero — iOS | senior-ios-developer | DONE | ShuttlX/Theme/Themes/MixtapeHero.swift | |
| T3.2b | 3 wave 1 | Mixtape hero — watch | swiftui-watchos-specialist | DONE | ShuttlX Watch App/Theme/Themes/MixtapeHero.swift | |
| T3.3a | 3 wave 1 | Arcade hero — iOS | senior-ios-developer | DONE | ShuttlX/Theme/Themes/ArcadeHero.swift | |
| T3.3b | 3 wave 1 | Arcade hero — watch | swiftui-watchos-specialist | DONE | ShuttlX Watch App/Theme/Themes/ArcadeHero.swift | |
| T3.W1 | 3 wave 1 | Push + TestFlight checkpoint | lead | DONE | — | After 3.1-3.3 land |
| T3.4a | 3 wave 2 | Classic Radio hero — iOS | senior-ios-developer | DONE | ShuttlX/Theme/Themes/ClassicRadioHero.swift | |
| T3.4b | 3 wave 2 | Classic Radio hero — watch | swiftui-watchos-specialist | DONE | ShuttlX Watch App/Theme/Themes/ClassicRadioHero.swift | |
| T3.5a | 3 wave 2 | VU Meter hero — iOS | senior-ios-developer | DONE | ShuttlX/Theme/Themes/VUMeterHero.swift | |
| T3.5b | 3 wave 2 | VU Meter hero — watch | swiftui-watchos-specialist | DONE | ShuttlX Watch App/Theme/Themes/VUMeterHero.swift | |
| T3.6a | 3 wave 2 | Neovim hero — iOS | senior-ios-developer | DONE | ShuttlX/Theme/Themes/NeovimHero.swift | |
| T3.6b | 3 wave 2 | Neovim hero — watch | swiftui-watchos-specialist | DONE | ShuttlX Watch App/Theme/Themes/NeovimHero.swift | |
| T3.W2 | 3 wave 2 | Push + TestFlight checkpoint | lead | DONE | — | After 3.4-3.6 land |
| T4.1 | 4 | QA walk all 6 timers on both sims | qa-engineer | DONE | — | Found + routed 1 P0 + 2 P1 + 3 P2 bugs; all fixed in follow-up commits |
| T4.2 | 4 | Update CLAUDE.md theme table + rules + memory | docs-keeper | DONE | CLAUDE.md, .claude/rules/design-system.md, .claude/rules/watchos.md, memory | |
| T5.0 | 5 | Watch/iOS unification — scope SPM package | swift-architect | CLOSED — DEFERRED | docs/decisions/2026-06-06-phase5-unification.md | Per-area decision matrix + re-entry conditions documented. ShuttlXShared package is not a stub (4 production files); SwiftUI exclusion was a deliberate prior decision. Theme + manager copies have real semantic divergence, not just drift. Models could be partially unified later but only as a dedicated 1-day branch with no in-flight Services edits. |
| T-METRICS.1 | 4.5 | Audit every metric in walk/run timer (TIME / HR / DIST / PACE / STEPS / CAD) | general-purpose | DONE | iPhoneWorkoutController.swift, WatchWorkoutManager.swift | Root cause: `currentPace = elapsedTime / totalDistance` is cumulative average. Pedometer warmup spike (30s / 0.05km = 600s) pinned at 10'00. See docs/incidents/2026-06-06-pace-10min.md |
| T-METRICS.2 | 4.5 | Fix pace 10'00 bug (rolling 30s window + early-workout guard) | lead | DONE | iPhoneWorkoutController.swift, WatchWorkoutManager.swift | Both targets now use sliding 30s window; pace stays nil ("—") until ≥20s elapsed AND ≥50m moved |
| T-METRICS.3 | 4.5 | P1: fuse GPS distance into totalDistance (treadmill / indoor accuracy) | senior-ios-developer | DONE | iPhoneWorkoutController.swift | CLLocation samples filtered (≤20m accuracy, 1-100m delta) accumulate into gpsAccumulatedDistanceKm; after 3 valid samples gpsHasUsableFix flips true and overrides pedometer distance. Pedometer remains fallback for treadmill/indoor. |
| T-METRICS.4 | 4.5 | P1: prefer HKLiveWorkoutBuilder distance on watch | swiftui-watchos-specialist | DONE | WatchWorkoutManager.swift | HKLiveWorkoutBuilderDelegate now reads distanceWalkingRunning statistic. When hkDistanceKm > 0 it's preferred over pedometer; updatePaceAndSplits always receives the chosen value so rolling pace + km splits use the authoritative source. |
| T-TOOL.1 | 6 | XCTHealthKit adoption (test target SPM dep) | TBD | TODO — needs SPM test target | Package.swift / tests target | Verified: StanfordBDHG/XCTHealthKit updated 2026-06-01 (recent). Per-user action: add `.package(url: "https://github.com/StanfordBDHG/XCTHealthKit.git", from: "1.0.0")` to test target dependencies. |
| T-TOOL.2 | 6 | ios-simulator-mcp install | TBD | TODO — needs ~/.claude/mcp.json edit | (user machine config) | Verified candidate: joshuayoes/ios-simulator-mcp. Requires `pipx install fb-idb` + npx wrapper in mcp.json. User-machine-only — not committable. |
| T-TOOL.3 | 6 | Privacy Manifest Fixer integration | TBD | TODO — pre-release hook candidate | tools/check-privacy-manifest.sh (proposed) | Verified: crasowas/app_privacy_manifest_fixer 237★ updated 2026-05-26. Best run as a pre-push hook OR a release-shepherd skill — defer install until next App Store submission. |
| T-TOOL.4 | 6 | App Store Connect MCP | TBD | TODO — needs ~/.claude/mcp.json edit | (user machine config) | Multiple impls — user picks best-maintained variant before install. Reuses existing ASC API key. |
| T-TOOL.5 | 6 | VoltAgent fork — prompt review | TBD | TODO — reference work | .claude/agents/ | Read-only research pass to cherry-pick prompt improvements for senior-ios-developer / swiftui-watchos-specialist. Low priority. |

## Sprint Closed

All tasks in Phases 0-4 completed. Phase 5 (Watch/iOS unification via SPM) remains BLOCKED pending explicit approval for a separate sprint.

## Legend
- `TODO` — not started
- `IN_PROGRESS` — agent currently executing
- `BLOCKED` — waiting on dependency or user input
- `DONE` — merged + pushed
