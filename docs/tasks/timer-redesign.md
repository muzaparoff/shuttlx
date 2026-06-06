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
| T3.1a | 3 wave 1 | Synthwave hero — iOS | senior-ios-developer | TODO | ShuttlX/Theme/Themes/SynthwaveHero.swift | New file per theme |
| T3.1b | 3 wave 1 | Synthwave hero — watch | swiftui-watchos-specialist | TODO | ShuttlX Watch App/Theme/Themes/SynthwaveHero.swift | |
| T3.2a | 3 wave 1 | Mixtape hero — iOS | senior-ios-developer | TODO | ShuttlX/Theme/Themes/MixtapeHero.swift | |
| T3.2b | 3 wave 1 | Mixtape hero — watch | swiftui-watchos-specialist | TODO | ShuttlX Watch App/Theme/Themes/MixtapeHero.swift | |
| T3.3a | 3 wave 1 | Arcade hero — iOS | senior-ios-developer | TODO | ShuttlX/Theme/Themes/ArcadeHero.swift | |
| T3.3b | 3 wave 1 | Arcade hero — watch | swiftui-watchos-specialist | TODO | ShuttlX Watch App/Theme/Themes/ArcadeHero.swift | |
| T3.W1 | 3 wave 1 | Push + TestFlight checkpoint | lead | TODO | — | After 3.1-3.3 land |
| T3.4a | 3 wave 2 | Classic Radio hero — iOS | senior-ios-developer | TODO | ShuttlX/Theme/Themes/ClassicRadioHero.swift | |
| T3.4b | 3 wave 2 | Classic Radio hero — watch | swiftui-watchos-specialist | TODO | ShuttlX Watch App/Theme/Themes/ClassicRadioHero.swift | |
| T3.5a | 3 wave 2 | VU Meter hero — iOS | senior-ios-developer | TODO | ShuttlX/Theme/Themes/VUMeterHero.swift | |
| T3.5b | 3 wave 2 | VU Meter hero — watch | swiftui-watchos-specialist | TODO | ShuttlX Watch App/Theme/Themes/VUMeterHero.swift | |
| T3.6a | 3 wave 2 | Neovim hero — iOS | senior-ios-developer | TODO | ShuttlX/Theme/Themes/NeovimHero.swift | |
| T3.6b | 3 wave 2 | Neovim hero — watch | swiftui-watchos-specialist | TODO | ShuttlX Watch App/Theme/Themes/NeovimHero.swift | |
| T3.W2 | 3 wave 2 | Push + TestFlight checkpoint | lead | TODO | — | After 3.4-3.6 land |
| T4.1 | 4 | QA walk all 6 timers on both sims | qa-engineer | TODO | — | Report P0/P1/P2 |
| T4.2 | 4 | Update CLAUDE.md theme table + rules + memory | docs-keeper | TODO | CLAUDE.md, .claude/rules/design-system.md | |
| T5.0 | 5 | (Awaiting approval) Watch/iOS unification — scope SPM package | swift-architect | BLOCKED | Package.swift | Phase 5 requires explicit kickoff |

## Legend
- `TODO` — not started
- `IN_PROGRESS` — agent currently executing
- `BLOCKED` — waiting on dependency or user input
- `DONE` — merged + pushed
