# ShuttlX

Interval training app for iOS (18.0+) and watchOS (11.5+) built with SwiftUI.

**External dependencies (SPM):**
- **RevenueCat** (`purchases-ios-spm`) — in-app subscriptions (iOS only)
- **TelemetryDeck** (`SwiftSDK`) — anonymous analytics (iOS only, no biometrics)

These are declared in `PrivacyInfo.xcprivacy` (ProductInteraction, DeviceID, PurchaseHistory).  
The watchOS target remains Apple-frameworks-only.

- **Bundle**: `com.shuttlx.ShuttlX` / `com.shuttlx.ShuttlX.watchkitapp`
- **Team**: `83HPSY452Y`
- **App Group**: `group.com.shuttlx.shared`
- **CloudKit**: `iCloud.com.shuttlx.app`
- **Codebase**: ~13,200 LOC across 117 Swift files
- **CI**: GitHub Actions → App Store Connect → TestFlight (auto on push to main)

## Targets

| Target | Scheme | Files | Key Files |
|--------|--------|-------|-----------|
| iOS | `ShuttlX` | ~60 | PhoneSyncCoordinator (~875), AnalyticsView, DeviceManager, CalorieEstimationEngine, ThemeManager + theme files |
| watchOS | `ShuttlX Watch App` | ~45 | WatchWorkoutManager (~1,450, being decomposed — see HealthKitAuthService/WorkoutPersistence/LiveMetricsBroadcaster), WatchSyncCoordinator, TrainingView (137 + 4 extension files), ThemeManager + theme files |
| Shared (SPM) | `ShuttlXShared` | 13 | models (see `.claude/rules/models.md`), IntervalEngine (canonical), RecoverySegmenter, HapticPlayer |
| Live Activity | `ShuttlXLiveActivity` | 3 | ShuttlXLiveActivity, LockScreenView |
| Widgets | `ShuttlXWidgets` | 3 | SmallWidget, MediumWidget |

## Build Commands

```bash
# Build both platforms (simulator)
bash tests/build_and_test_both_platforms.sh --clean --build

# Build for physical device
bash tests/build_for_physical_device.sh

# iOS only (destination only — passing -sdk breaks SPM deps of companion targets)
xcodebuild -project ShuttlX.xcodeproj -scheme ShuttlX -destination 'generic/platform=iOS Simulator' build

# watchOS only
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlX Watch App" -destination 'generic/platform=watchOS Simulator' build
```

## Architecture

```
iPhone creates template → TemplateManager.save()
  → persist to App Group → sendTemplatesToWatch() via WCSession
  → Watch receives → stores in SharedDataManager.workoutTemplates

Watch starts workout → WatchWorkoutManager.startIntervalWorkout(template)
  → HealthKit session + timer + sensors
  → Every 1s: IntervalEngine.tick() + broadcast live metrics to iPhone
  → On complete: saveWorkoutData() → TrainingSession sent via WCSession

iPhone receives session → SharedDataManager → DataManager → UI updates

Theme sync:
  iPhone: Settings → ThemeManager.selectedThemeID → UserDefaults (App Group)
    → SharedDataManager.sendThemeToWatch() via applicationContext
  Watch: receives → ThemeManager.shared.selectedThemeID → UI updates
```

## Theme System

- `ThemeManager` (`@Observable` singleton) manages active theme, persists to App Group UserDefaults
- **Switching**: call `ThemeManager.shared.selectTheme(id)` — never set `selectedThemeID` directly
- `current` is a **stored** property (not computed) — ensures `@Observable` generates proper tracking
- **FM Tuner chrome state** (4 properties, FM Tuner theme only): `vuMeterValue` (0.0–1.0), `signalStrength` (0–5), `footerStatusLines` ([String]), `chromeVisible` (Bool) — other themes ignore these
- `ShuttlXColor.*` / `ShuttlXFont.*` enums bridge to `ThemeManager.shared` — all existing code is theme-aware
- Theme structs: `AppTheme` → `ThemeColors` (~40 tokens) + `ThemeFonts` (~20 tokens) + `ThemeEffects`
- 7 themes: Clean (glass cards, system fonts), Synthwave (Outrun dashboard + scrolling perspective grid), Mixtape (Walkman with spinning cassette reels), Arcade (7-segment HI-SCORE display + INSERT COIN), Classic Radio (horizontal tuning dial with sweeping needle), Neovim (modal `:command` status line + line-number gutter), FM Tuner (deep navy LCD, cyan monospaced)
- **Screen backgrounds**: `.themedScreenBackground()` on all major views — Clean: MeshGradient (iOS)/LinearGradient (watchOS), Synthwave: horizon grid, Mixtape: blue body + texture lines, Arcade: CRT scanlines+vignette, Classic Radio: warm brown grain + vignette, Neovim: #1D2021 solid + left gutter stripe (iOS) / solid (watchOS), FM Tuner: #021018 solid + FMTunerHeader chrome overlay + FMTunerVUColumn overlay (Canvas, 18 segments)
- View modifiers: `.themedCard()`, `.neonGlow()`, `.lcdPanel()`, `.scanlineOverlay()`, `.synthwaveGrid()`
- `ThemeEffects.CardStyle` values: `.glass`, `.neon`, `.lcd`, `.pixel`, `.tape`, `.terminal` (Neovim)
- Files: 15 per target under `Theme/` (ThemeColors, ThemeFonts, ThemeEffects, AppTheme, ThemeManager, ThemeModifiers, Themes/Clean, Themes/Synthwave, Themes/Mixtape, Themes/Arcade, Themes/ClassicRadio, Themes/Neovim, Themes/FMTuner, Components/FMTunerHeader, Components/FMTunerVUColumn)

## Data Storage

- JSON files in App Group container: `sessions.json`, `workout_templates.json`, `exercise_devices.json`
- Theme selection: App Group UserDefaults key `selectedThemeID`
- Sync: WatchConnectivity (`sendMessage` + `transferUserInfo` + `applicationContext`)
- HealthKit: workout sessions, heart rate, distance, calories

## Development Rules

- **Build both platforms after every change**: `bash tests/build_and_test_both_platforms.sh --clean --build`
- **Minimal external dependencies** — iOS target uses RevenueCat + TelemetryDeck (SPM); watchOS target is Apple-frameworks-only. Do not add new external dependencies without explicit approval
- **Discuss features before implementing** — never start without explicit approval
- **Plan before implementing**: analyze codebase, identify affected files, create a plan, then implement
- **Dynamic multi-theme UI**: 7 themes (Clean, Synthwave, Mixtape, Arcade, Classic Radio, Neovim, FM Tuner) — selectable in Settings
- **Most models live in the ShuttlXShared package** (`Shared/`) — single source of truth, `import ShuttlXShared`. Only `TrainingSession` and `WorkoutTemplate` remain duplicated per target (update BOTH copies) until the Phase 4 engine unification — see `.claude/rules/models.md`
- **Theme files are duplicated** between iOS (`ShuttlX/Theme/`) and watchOS (`ShuttlX Watch App/Theme/`) — update BOTH when changing
- **Always update docs**: when adding/changing features, update CLAUDE.md, relevant `.claude/rules/`, `.claude/agents/`, `.claude/skills/`, and memory files to reflect the current architecture and status

## Path-Scoped Rules

Additional rules load automatically based on the files being edited:

| Rule | Applies to | Content |
|------|-----------|---------|
| `.claude/rules/design-system.md` | `**/Views/**`, `**/Components/**`, `**/Theme/**` | Colors, fonts, cards, accessibility, layout |
| `.claude/rules/services.md` | `**/Services/**` | Thread safety, error handling, sync patterns |
| `.claude/rules/watchos.md` | `ShuttlX Watch App/**` | Watch-specific constraints, timer, workout |
| `.claude/rules/models.md` | `**/Models/**` | Model conventions, dual-target sync |

## Slash Commands

- `/build` — Build both platforms, report pass/fail
- `/deploy` — Push to main, monitor CI, report TestFlight result
- `/review-changes` — Check git diff against design system & safety rules

## Agents

| Agent | Purpose | Model |
|-------|---------|-------|
| `project-manager` | Orchestrates multi-agent work — owns task board, assigns specialists, surfaces blockers. Spawn for any feature spanning ≥2 platforms or ≥2 domains. | opus |
| `senior-ios-developer` | Review + implement iOS tasks (and watchOS when solo) | sonnet |
| `swiftui-watchos-specialist` | Review + implement watchOS tasks; team-mode owner of `ShuttlX Watch App/**` | opus |
| `senior-architect` | Architecture, data structures, monitoring, production tooling | opus |
| `product-designer` | Proactive UI/UX research + mockup generation; owns `design/proposals/**` | opus |
| `qa-engineer` | Functional QA — walks real workout flows, reports bugs by severity with dev routing | sonnet |
| `test-author` | Writes XCTest / Swift Testing tests; owns `**Tests/**` | sonnet |
| `release-shepherd` | CI + TestFlight + payment-config monitor after push | haiku |
| `docs-keeper` | Keeps CLAUDE.md, `.claude/rules/`, memory in sync after feature work | haiku |
| `app-auditor` | Pre-release readiness audit (crash risks, metadata, features) | sonnet |
| `design-reviewer` | UI/UX + Apple HIG compliance **review** of existing code | sonnet |
| `ux-ui-designer` | Cardiac-rehab UX **audit** | sonnet |
| `growth-strategist` | ASO, marketing, solo-dev launch strategy | opus |
| `accessibility-auditor` | VoiceOver, Dynamic Type, contrast, a11y | sonnet |
| `performance-auditor` | Memory, battery, render efficiency, watchOS limits | sonnet |
| `security-reviewer` | Entitlements, data protection, secrets, privacy | sonnet |
| `watch-debugger` | watchOS workout/sync/HealthKit/timer debugging | sonnet |
| `healthkit-domain-expert` | HealthKit correctness for cardiac rehab — clinical-grade review | opus |

### Agent Routing Rules

**Run in PARALLEL (independent, read-only):**
- `app-auditor` + `design-reviewer` + `growth-strategist` → pre-release report
- `accessibility-auditor` + `performance-auditor` + `security-reviewer` → code health report
- `senior-architect` (review mode) can run in parallel with read-only auditors

**Run SEQUENTIALLY (output feeds the next):**
- `app-auditor` → `senior-ios-developer` (fix what auditor found)
- `design-reviewer` → `senior-ios-developer` (apply UI changes)
- `senior-architect` (review) → `senior-ios-developer` (implement architecture fixes)
- `senior-architect` (review) → `senior-architect` (implement tooling)

**Never parallelize:**
- `senior-ios-developer` + any other writing agent (writes to Swift files)
- `senior-architect` (implement mode) + `senior-ios-developer` (overlapping scope)
- Any two agents that write to the same Swift files

## Agent Teams (experimental — CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)

Teams coordinate via a **shared task list** + **mailbox** between teammates. Use teams when work genuinely parallelizes by file scope (each teammate owns a distinct path). For sequential tasks, prefer single-session or subagents — teams are expensive (tokens scale per teammate).

**Best practice from Anthropic docs**: 3–5 teammates, 5–6 tasks per teammate, no two teammates editing the same file. Each writing agent has a `File ownership (team mode)` clause in its definition.

### Playbook A — Cross-platform feature

Phase 1 (sequential): `product-designer` → `design/proposals/<slug>/{ios.md, watch.md}`.
Phase 2 (parallel team of 3): `senior-ios-developer` (iOS only) + `swiftui-watchos-specialist` (watch only) + `test-author` (tests only). Each reads the relevant spec.
Phase 3: `qa-engineer` walks the flow, routes any P0/P1 back to the responsible dev as new tasks.
Phase 4: `docs-keeper` updates CLAUDE.md / rules / memory.

> Prompt: *Create an agent team to ship <feature>. Phase 1: spawn product-designer to write design/proposals/<slug>/. Phase 2: spawn 3 teammates (senior-ios-developer, swiftui-watchos-specialist, test-author) — each owns their scope, no file overlap. Phase 3: qa-engineer. Phase 4: docs-keeper.*

### Playbook B — Pre-release readiness (parallel review)

Team of 4 read-only reviewers. They never edit code; the lead synthesizes a Go/No-Go.

> Prompt: *Create a 4-teammate read-only review team for the current branch: app-auditor, accessibility-auditor, performance-auditor, security-reviewer. Run in parallel. Synthesize findings into a Go/No-Go list grouped by P0/P1/P2.*

### Playbook C — Bug investigation with competing hypotheses

> Prompt: *Users report <symptom>. Spawn 3 teammates with competing hypotheses: watch-debugger (watch-side cause), senior-architect (architectural cause), healthkit-domain-expert (HealthKit/data cause). Have them debate to disprove each other's theories. Update findings doc with the consensus root cause.*

### Playbook D — New theme

> Prompt: *Spawn 3 teammates to add the "<name>" theme. product-designer (owns design/proposals/, defines palette + visual language). senior-ios-developer (owns ShuttlX/Theme/Themes/<Name>.swift). swiftui-watchos-specialist (owns ShuttlX Watch App/Theme/Themes/<Name>.swift). After all 3 finish, docs-keeper updates the theme table in CLAUDE.md.*

### Playbook E — HealthKit correctness review

> Prompt: *Create a read-only team: healthkit-domain-expert, recovery-feature-architect, performance-engineer. Coordinate on a single clinical-grade audit doc.*

### Playbook F — Visual refresh

> Prompt: *2-teammate team to refresh <screen>: product-designer (mockups + research, owns design/proposals/) and ux-ui-designer (audits cardiac-rehab UX). They message each other to reconcile aesthetic with patient-safety constraints, then produce a unified proposal.*

### Team rules

- **Always clean up**: tell the lead `clean up the team` when done — only the lead can run cleanup
- **One team at a time**: a lead can manage only one team
- **No nested teams**: teammates cannot spawn their own teammates
- **`/resume` does not restore in-process teammates** — if you resume, ask the lead to respawn

## Project Knowledge Persistence

Two locations keep cross-session context for this codebase. Read both at session start when a task is not trivial.

- `docs/memory/` — version-controlled snapshot of project knowledge (architecture, roadmap, tech debt, sync architecture, cadence derivation, social backend plan). Refreshed by the lead at the end of a feature sprint via the snippet in `docs/memory/README.md`.
- `docs/plans/` — phased plans for in-flight work. `project-manager` writes these; specialists read them before starting their phase.
- `docs/tasks/` — per-sprint shared task boards owned by `project-manager`. Each row: id, phase, owner, state, file scope, notes.
- `docs/incidents/` — root-cause + fix summaries from Playbook T3 bug triage.

Auto-memory at `~/.claude/projects/-Users-sergeymuzyukin-github-shuttlx/memory/` is still the live store within a session. `docs/memory/` is the shareable snapshot.

## Frameworks Used

SwiftUI, HealthKit, WatchConnectivity, CoreLocation, CoreMotion, ActivityKit, Combine, os.log, WatchKit
