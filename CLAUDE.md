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
- **Codebase**: ~13,500 LOC across 145 Swift files
- **CI**: thin GitHub Actions callers of the shared `muzaparoff/appstore-kit@v1` reusable workflows (`.github/workflows/`): `test.yml` runs CI on push to main and auto-bumps the semver tag from conventional commits; the `v*` tag triggers `deploy.yml` → archive, sign, upload to TestFlight. `store-release.yml` (manual) stages the App Store listing from `fastlane/metadata` + `marketing/appstore/final`. Fastlane the tool is NOT part of CI; `scripts/bump_version.sh` no longer exists — versioning is fully automatic

## Targets

| Target | Scheme | Files | Key Files |
|--------|--------|-------|-----------|
| iOS | `ShuttlX` | ~74 | PhoneSyncCoordinator (~1,130), AnalyticsView, DeviceManager, CalorieEstimationEngine, ThemeManager + theme files, HelpView |
| watchOS | `ShuttlX Watch App` | ~38 | WatchWorkoutManager (~1,680, being decomposed — see HealthKitAuthService/WorkoutPersistence/LiveMetricsBroadcaster), WatchSyncCoordinator (~1,200), TrainingView (122 + 2 extension files: +Controls, +Metrics), ThemeManager + theme files |
| Shared (SPM) | `ShuttlXShared` | 13 | models (see `.claude/rules/models.md`), IntervalEngine (canonical), RecoverySegmenter, HapticPlayer |
| Live Activity | `ShuttlXLiveActivity` | 3 | ShuttlXLiveActivity, LockScreenView |
| iOS Widgets | `ShuttlXWidgets` | 11 | StartTrainingWidget (W1, configurable), QuickStartControl (W2), WeeklyGoalRingWidget (W3) + Shared/ (WidgetTheme, WidgetProgressShapes, WidgetTemplateProvider, WorkoutTemplateEntity, StartIntents) |
| watchOS Widgets | `ShuttlXWatchWidgets` | 6 | QuickStartComplication (now with accessoryCorner), LastWorkoutComplication, WeeklyProgressComplication, TodayWorkoutComplication, WatchWidgetDataProvider |

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
  → Watch receives → stores in WatchSyncCoordinator.workoutTemplates

Watch starts workout → WatchWorkoutManager.startIntervalWorkout(template)
  → HealthKit session + timer + sensors
  → Every 1s: IntervalEngine.tick() + broadcast live metrics to iPhone
  → On complete: saveWorkoutData() → TrainingSession sent via WCSession

iPhone receives session → PhoneSyncCoordinator → DataManager → UI updates

Widget/Control deep-link flow (iOS):
  Widget → widgetURL "shuttlx://start-template/{id}" or "shuttlx://start-freerun"
  → ShuttlXApp.onOpenURL → DeepLinkRouter
  → PhoneSyncCoordinator.startWatchWorkout(...) via WCSession
  → watch receives, starts workout via WorkoutManager

Watch complication deep-link flow:
  Complication → widgetURL "shuttlx://start-workout" or "shuttlx://start-template/{id}"
  → ShuttlXWatchApp.onOpenURL → workoutManager.startWorkout/startIntervalWorkout

Theme sync:
  iPhone: Settings → ThemeManager.selectedThemeID → UserDefaults (App Group)
    → PhoneSyncCoordinator.sendThemeToWatch() via applicationContext
  Watch: receives → ThemeManager.shared.selectedThemeID → UI updates
```

## Theme System

- `ThemeManager` (`@Observable` singleton) manages active theme, persists to App Group UserDefaults
- **Switching**: call `ThemeManager.shared.selectTheme(id)` — never set `selectedThemeID` directly
- `current` is a **stored** property (not computed) — ensures `@Observable` generates proper tracking
- `ShuttlXColor.*` / `ShuttlXFont.*` enums bridge to `ThemeManager.shared` — all existing code is theme-aware
- Theme structs: `AppTheme` → `ThemeColors` (~40 tokens) + `ThemeFonts` (~20 tokens) + `ThemeEffects` + `ThemeChartStyle`
- **2 themes** (`validIDs` in ThemeManager: `"clean"`, `"mixtape"`): Clean (default — glass cards, system fonts, calm cardiac-patient baseline), Mixtape (Walkman cassette deck — blue player body, spinning reels, tape-counter aesthetics). The July 2026 theme reduction deleted Synthwave, Arcade, Classic Radio, Neovim, FM Tuner and VU Meter app-wide (see the note in `ShuttlXWidgets/Shared/WidgetTheme.swift`); the architecture still supports adding themes via `AppTheme.all` + a new `Themes/<Name>Theme.swift` pair
- **Screen backgrounds**: `.themedScreenBackground()` on all major views — Clean: MeshGradient (iOS)/LinearGradient (watchOS), Mixtape: blue body + texture lines (`ThemedSceneBackground.swift` dispatches; `.cleanMeshBackground()` / `.mixtapeBackground()` are the per-theme modifiers)
- View modifiers: `.themedCard()` (all card containers), `.lcdPanel()` (defined in ThemeModifiers, Mixtape LCD panels)
- `ThemeEffects.CardStyle` values: `.glass` (Clean), `.lcd` (Mixtape)
- Files under `Theme/` (mirrored per target): ThemeManager, AppTheme, ThemeColors, ThemeFonts, ThemeEffects, ThemeModifiers, ThemeAssets, ShuttlXTheme, Themes/CleanTheme, Themes/MixtapeTheme, Themes/MixtapeTimerHero (watch: Themes/Decorations/MixtapeTimerHero), Components/ThemedSceneBackground, Components/ThemedTransportButton; iOS additionally has ThemeChartStyle + IntervalTypeThemeHelpers

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
- **Dynamic multi-theme UI**: 2 themes (Clean, Mixtape) — selectable in Settings (reduced from 7 in July 2026; the theme system still supports adding more)
- **In-app Help**: `ShuttlX/Views/HelpView.swift`, reachable from Settings → Help — update it when user-facing flows change
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

### Domain review checklists (July 2026 audit-derived — agents MUST apply the relevant one before implementing or reviewing in its domain)

- `/wcsession-sync-review` — WCSession payload limits, applicationContext merge semantics, retry rules
- `/watchos-constraints` — battery/memory budgets, TimelineView `paused:`, AOD, workout survival
- `/observable-theme-patterns` — `@Observable` tracking gotchas, bridge re-render gap, mirrored-file drift, 2-theme switch coverage
- `/json-persistence-safety` — single-writer rule, corruption recovery, schema versioning, id-stable dedup
- `/swift-concurrency-review` — actor isolation, queue conventions, known-good patterns to preserve

## Agent-First Workflow (MANDATORY)

Every non-trivial task or bug follows this loop — the lead session orchestrates, agents do the work:

1. **Route**: When the user reports a task/bug, pick the right specialist agent(s) from the table below (use the Routing Rules). Don't implement directly in the lead session except for one-line fixes explicitly approved by the user.
2. **Audit first**: The assigned agent investigates and produces a diagnosis with runtime evidence (logs, reproduction) — never code-reading alone. Unverifiable diagnoses must be labeled *unverified hypothesis*.
3. **Implement**: The same (or a writing) agent applies changes within its file-ownership scope.
4. **Verify**: The lead builds both platforms (`bash tests/build_and_test_both_platforms.sh --clean --build` or per-platform xcodebuild). Build failure → route the errors straight back to the implementing agent to fix; repeat until green.
5. **Review & approve**: The lead summarizes what changed and shows results to the user. Only the user approves the final result (and any commit/push).

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

> Prompt: *Create a read-only team: healthkit-domain-expert, performance-auditor. Coordinate on a single clinical-grade audit doc.*

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
