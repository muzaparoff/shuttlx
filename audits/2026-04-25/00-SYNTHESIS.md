# ShuttlX Audit Synthesis — 2026-04-25

Synthesis of 7 specialist audits (`01`–`07`) plus the Recovery Training spec (`specs/2026-04-25/recovery-training.md`).

## Findings tally

| Report | P0 | P1 | P2 | P3 | Total |
|---|---|---|---|---|---|
| 01 swift-architect | 0 | 4 | 5 | 1 | 10 |
| 02 swiftui-watchos | 0 | 1 | 5 | 2 | 8 |
| 03 healthkit | 0 | 6 | 5 | 2 | 13 |
| 04 performance | 0 | 2 | 5 | 2 | 9 |
| 05 ux-ui | 1 | 3 | 3 | 2 | 9 |
| 06 accessibility | 4 | 6 | 4 | 2 | 16 |
| 07 security-privacy | 0 | 2 | 4 | 3 | 9 |
| **Total** | **5** | **24** | **31** | **14** | **74** |

The audit-only run found no crash-class P0s. The five P0s are: cardiac-safety HR threshold framing (UX), three Dynamic-Type / contrast WCAG blockers (Accessibility), and Live Activity unlabeled metric pills (Accessibility). All five are fixable in days, not weeks.

---

## Top 10 P0/P1 issues, ranked by (impact × confidence ÷ fix-cost)

| # | Severity | Where | Issue | Fix-cost | Impact |
|---|---|---|---|---|---|
| 1 | P0 | `TrainingView.swift:369-383`; `HeartRateZoneCalculator.swift:28` | "HIGH INTENSITY" fires at 85% HRmax with Tanaka 190 fallback when age is missing. A 70-year-old can hit 161 BPM with no warning. Athlete copy on a cardiac screen. (UX F1) | 0.5 day | Patient safety |
| 2 | P1 | `ShuttlX/PrivacyInfo.xcprivacy` | Privacy manifest omits `ProductInteraction`, `DeviceID`, `PurchaseHistory` collected by bundled RevenueCat + TelemetryDeck SDKs. App Review reject risk; nutrition label is wrong. (Security F2) | 1 hour | App Store compliance |
| 3 | P1 | `WatchWorkoutManager.swift:1099-1107` + `:341` | `saveWorkoutDataToLocalStorage()` runs twice on every pause: once explicitly, once from the HK delegate. Two atomic writes of the full session JSON each pause. (Performance F2) | 1 hour | Latency, disk wear |
| 4 | P1 | `WatchWorkoutManager.swift:1042-1049` | `builder.finishWorkout()` writes no metadata. Saved `HKWorkout` has no template name, interval count, or indoor flag — invisible to clinicians on Apple Health export. (HealthKit F3) | 0.5 day | Clinical export integrity |
| 5 | P1 | `WatchWorkoutManager.swift:755-790, 833-869` | HR and calorie anchored queries filter by time only. A paired chest strap or third-party app contaminates the workout average. Two clinically reportable HR averages for one session. (HealthKit F6) | 1 day | Clinical correctness |
| 6 | P1 | `IntervalEngine.swift` + `WatchWorkoutManager.swift` | Zero `HKWorkoutEvent` markers — interval boundaries, km splits, motion-paused are invisible to HealthKit. Rehab structure is lost on export. (HealthKit F2) | 1.5 days | Rehab integration |
| 7 | P1 | `ShuttlX/Theme/ShuttlXTheme.swift:5-94` (+ watch mirror) | `ShuttlXColor`/`ShuttlXFont` are static-var bridges; `@Observable` does not register reads from static accessors. Watch theme push via WCSession likely doesn't re-render the watch UI until view re-instantiation. (SwiftUI F1) | 2-3 days | User-visible bug + cross-cutting |
| 8 | P1 | `ThemeColors.swift:84-92`; `TrainingView.swift:167` | HR zones encoded by color only. Zone number never shown beside BPM. Cardiac patients with deuteranopia cannot distinguish Z3/Z4/Z5. WCAG 1.4.1. (Accessibility P1-1) | 1 day | Clinical signal + WCAG |
| 9 | P0 | `Theme/ThemeAssets.swift` (60+ sites), `Theme/ThemeModifiers.swift`, watch mirrors, `TrainingView.swift:114,119,125,147,203,208,370` | `.font(.system(size: N))` literals everywhere — Dynamic Type bypassed. Violates WCAG 1.4.4 and the project's own design-system rule. (Accessibility P0-1) | 3-4 days | WCAG + cardiac demographic |
| 10 | P1 | `WatchWorkoutManager.swift` | 1184-LOC god object owning HK auth, session lifecycle, sensors, location, splits, broadcast, persistence, save. Single biggest blocker for adding recovery mode cleanly + impossible to unit-test. (Architect F1) | 5+ days | Structural; recovery feature blocker |

Tie-breakers: items 2-5 have fix-costs of hours-to-a-day and unblock either App Review or clinical reporting; that pushes them above structural items even though item 10's impact is larger.

---

## Cross-cutting themes (issues found independently by 2+ agents — these are real)

1. **Theme reactivity is broken or fragile.** SwiftUI specialist F1 (static bridge does not register `@Observable` reads), Performance F5 (Canvas backgrounds re-evaluate on any `ThemeManager` mutation), Architect F4 (`ThemeManager` not `@MainActor`). Three agents converging means the theme system is structurally fragile despite working today.
2. **WatchWorkoutManager is the single biggest risk surface.** Architect F1 (god object), Performance F1 (1Hz re-render churn), HealthKit F1/F6/F7/F13 (multiple parallel data sources living inside it). Four agents all point at the same file.
3. **Multiple disagreeing data sources for the same metric.** HealthKit F1, F6, F7, F11, F13 all describe HR or calorie values that diverge between HK builder, anchored queries, CMPedometer, and `CalorieEstimationEngine`. UX F1 indirectly hits the same problem (HR-warning math depends on which max-HR formula).
4. **Pause-state correctness is half-implemented.** SwiftUI F2 (broadcasts continue during pause with stale elapsed), Performance F2 (double-save on pause), HealthKit F13 (HK builder counts paused-window samples while in-app sum excludes them). Three agents, same lifecycle hole.
5. **Hardcoded sizes vs Dynamic Type.** Accessibility P0-1 (60+ sites), UX F6 (watch metric font drops below 40pt on 40mm hardware), Performance F9 (`scanlineOverlay` 150 hardcoded `Rectangle`s as decoration). All three relate to "this should be relative, not fixed."
6. **External SDKs in a "zero dependencies" project.** Security F1 (RevenueCat + TelemetryDeck imports contradict CLAUDE.md), Performance F7 (RevenueCat init blocks first frame), SwiftUI specialist out-of-scope note (same observation), Architect F3 (singletons including SubscriptionManager). Four agents flagged the doc/code drift independently.
7. **Cardiac-rehab demographic mismatches.** UX F1 (HR threshold), UX F3 (athlete onboarding tone), UX F4 (VU Meter contrast), UX F8 (Arcade saturation), Accessibility P1-1 (HR zones color-only), Accessibility P1-5 (interval transitions haptic-only — excludes deaf users), HealthKit F4 (no RPE for Borg-style intensity tracking). Two agents converging on multiple instances of the same pattern: the app reads as a performance app, not a rehab app.

---

## Conflicts between agents (flag for human triage)

- **Combine sink vs direct callback in iOS sync** (Architect F2): the swift-architect recommends removing the Combine sink and using only the imperative `setDataManager` callback. The performance auditor's Finding 6 (`updateConnectivityHealth` running on every WC message) does not address the sink directly but its mitigation suggests rate-limiting on the WC delegate side. These do not conflict, but they touch the same file (`SharedDataManager.swift:178-184` vs `:705-736`) and the fixes should be designed together to avoid stepping on each other.
- **HR/calorie source-of-truth** (HealthKit F1 vs F6 vs F11): the HealthKit specialist gives three different recommendations across findings (use `builder.statistics(for:)`, OR filter by `HKDevice.local()`, OR adopt the Tanaka formula everywhere). They are coherent if applied together but a partial fix could make the discrepancy worse — needs a single design pass not piecemeal patches.
- **Live Activity start signal** (SwiftUI F6): two start signals (`workoutStarted` userInfo + `liveMetrics` sendMessage) — the auditor recommends dropping one. The choice (drop userInfo vs drop sendMessage trigger) is non-obvious and affects whether iOS can show a Live Activity when launched cold mid-workout. Human decision required.
- **`pauseWorkout` save behaviour**: Performance F2 says remove the duplicate save in the HK delegate; Architect F6 implies the timer-tick `saveWorkoutData()` itself can race. Choice between "remove the delegate save" vs "guard the function with `isSaving = false`" needs a design call. Both fixes together is the safest answer.
- **Recovery feature spec scope**: the recovery-feature-architect notes that `.claude/rules/watchos.md` and `.claude/rules/design-system.md` still list 6 themes (missing Neovim) — minor doc drift, but it indicates the agents are working from slightly different views of the project. Reconcile docs.

---

## Three fix-batches

### Batch 1 — This week (8 days estimated, mostly hours-each)

Goal: ship the patient-safety blockers and the App Review compliance fixes. Each item is small and standalone; can be parallel-merged.

| Item | Source | Effort |
|---|---|---|
| 1.1 Add `ProductInteraction` / `DeviceID` / `PurchaseHistory` to `ShuttlX/PrivacyInfo.xcprivacy` | Security F2 | 1 hour |
| 1.2 Switch RevenueCat `entitlementVerificationMode` from `.informational` to `.enforced` | Security F4 | 1 hour |
| 1.3 Make `Watch SharedDataManager.init()` private (matches iOS) | Architect F8 | 5 min |
| 1.4 Remove duplicate `saveWorkoutDataToLocalStorage()` from `HKWorkoutSessionDelegate` | Performance F2 | 1 hour |
| 1.5 Drop `Timer.scheduledTimer` re-creation in `handleLiveMetrics`; use single `Date` timestamp | Performance F6, SwiftUI F7 | 2 hours |
| 1.6 Lower default HR-warning threshold to 70%; force age entry; rename "HIGH INTENSITY" copy; rename `RecoveryStatus.overreaching` raw display | UX F1 | 0.5 day |
| 1.7 AOD step-color contrast fix (drop `.opacity(0.6)` on step label in `TrainingView.swift:126`) | Accessibility P0-3 | 1 hour |
| 1.8 Add `accessibilityElement` + labels to `LockScreenView` and `MetricPill` | Accessibility P0-4 | 2 hours |
| 1.9 Set `valueSize` floor to 40pt in `TrainingView.swift:138` | UX F6 | 5 min |
| 1.10 Add `HKMetadataKeyIndoorWorkout` + template name + interval count to `builder.finishWorkout()` | HealthKit F3 | 0.5 day |
| 1.11 Update CLAUDE.md to reflect RevenueCat + TelemetryDeck dependencies; sync `.claude/rules/*.md` to 7 themes | Security F1, Recovery spec note | 1 hour |
| 1.12 Add corrupt-backup-file 7-day cleanup in `SharedDataManager` | Security F8 | 1 hour |
| 1.13 Mixtape `ctaPause` color disambiguation | Accessibility P3-2 | 5 min |

### Batch 2 — This sprint (~17 days estimated)

Goal: clinical correctness, accessibility WCAG cleanup, structural prep for the recovery feature.

| Item | Source | Effort |
|---|---|---|
| 2.1 Replace parallel HR / calorie anchored queries with `workoutBuilder.statistics(for:)`; filter by `HKDevice.local()` if anchored stays | HealthKit F1, F6, F7, F13 | 2 days |
| 2.2 Add `HKWorkoutEvent.segment` for interval transitions; `.lap` for km splits | HealthKit F2 | 1.5 days |
| 2.3 Add HR zone number text + per-zone symbol shape on watch HR row, on `HRZoneChart`, and `accessibilityValue("Zone N")` | Accessibility P1-1 | 1 day |
| 2.4 Theme reactivity: add `.observingTheme()` modifier or `@Environment(ThemeManager.self)` reads to every screen; verify watch theme switch end-to-end | SwiftUI F1, Performance F5 | 2-3 days |
| 2.5 Add Tanaka-as-canonical max-HR formula in `CalorieEstimationEngine` (replace Fox 220-age) | HealthKit F11 | 0.5 day |
| 2.6 Pause correctness: freeze `elapsedTime` immediately on pause; gate `broadcastLiveMetricsIfNeeded` to a single transition payload | SwiftUI F2 | 0.5 day |
| 2.7 Live Activity: smarter `cleanupStaleActivities()` (adopt instead of kill); pick one start signal | SwiftUI F5, F6 | 1 day |
| 2.8 Onboarding tone: walking icon + calmer headline + iPhone-only path on page 3 | UX F3 | 1 day |
| 2.9 VU Meter `textPrimary` to high-luminance cream | UX F4 | 1 hour |
| 2.10 SettingsView: separate "Danger Zone" for `Clear All Sessions` / `Delete Account` | UX F5 | 0.5 day |
| 2.11 `accessibilityReduceTransparency` gating in `neonGlow`, `lcdPanel`, `scanlineOverlay`, `arcadeCRT*`, `vuMeter*`, `synthwaveHorizon*` | Accessibility P1-2, P1-3 | 1 day |
| 2.12 `AccessibilityNotification.Announcement` + visual banner for interval transitions | Accessibility P1-5 | 0.5 day |
| 2.13 `IntervalResultsView` timeline: hatch patterns + per-segment a11y labels | Accessibility P1-6 | 0.5 day |
| 2.14 LiveWorkoutCard pause-state color + symbol + accessibilityValue | Accessibility P1-4 | 0.5 day |
| 2.15 Add `distanceCycling` + `distanceSwimming` to HK auth set; read per-sport via `builder.statistics` | HealthKit F8 | 0.5 day |
| 2.16 Collapse iOS `SharedDataManager` dual data path (drop `@Published syncedSessions` + Combine sink) | Architect F2 | 1 day |
| 2.17 `WidgetDataProvider` actor-isolate or drop the static cache | Architect F7 | 0.5 day |
| 2.18 Force-unwrap cleanup at `Watch SharedDataManager.swift:336` and `DataManager.swift:82` | Architect F10 | 15 min |
| 2.19 `motionActivityManager.startActivityUpdates(to:)` move off `.main` queue | Performance F8 | 30 min |

### Batch 3 — Backlog (~25 days estimated)

Goal: structural debt and deeper rehab features. Each item is large enough to be its own piece of work; sequence as you have appetite.

| Item | Source | Effort |
|---|---|---|
| 3.1 Split `WatchWorkoutManager` into `WorkoutSensorCoordinator`, `WorkoutHealthKitClient`, `WorkoutBroadcaster` | Architect F1 | 5+ days |
| 3.2 Introduce `WatchSyncing` / `CloudSyncing` / `LiveActivityHosting` protocols + DI; enable unit tests | Architect F3 | 3 days |
| 3.3 Mechanical replace of `.font(.system(size: N))` (60+ sites) → `ShuttlXFont.*` or `@ScaledMetric` | Accessibility P0-1, P0-2 | 3-4 days |
| 3.4 RPE / `HKWorkoutEffortScore` capture + UI prompt; `HKWorkoutEffortRelationship` | HealthKit F4 | 2 days |
| 3.5 HK background-delivery entitlement + HRR capture window (becomes part of recovery feature) | HealthKit F9 | 2 days |
| 3.6 `HKWorkoutSession.startMirroringToCompanionDevice` adoption | HealthKit F12 | 1.5 days |
| 3.7 Single `SyncCoordinator` collapsing 5 reactive loops into one `AsyncStream` | Architect F5 | 3-5 days |
| 3.8 `WatchWorkoutManager` 1Hz re-render: split observable into LiveMetrics + WorkoutState | Performance F1 | 2-3 days |
| 3.9 AnalyticsEngine: cache `weeklyTrainingLoads`, merge `form()`, move to background, static `DateFormatter` | Performance F3 | 1 day |
| 3.10 `liveRoutePoints` cap on iOS to 1000 with stride-halving | Performance F4 | 1 hour |
| 3.11 Move `RevenueCat` + `TelemetryDeck` init off `App.init()` to first `.onAppear` | Performance F7 | 0.5 day |
| 3.12 `scanlineOverlay` rewrite as single `Canvas` (drop 150-`Rectangle` `VStack`) | Performance F9 | 1 hour |
| 3.13 Decision: strip `route` from CloudKit record OR add explicit GPS-in-iCloud disclosure | Security F5 | 1 day |
| 3.14 Move RevenueCat / TelemetryDeck keys to `*.xcconfig` not committed | Security F3 | 0.5 day |
| 3.15 `ThemeManager` `@MainActor` annotation (Swift 6 prep) | Architect F4 | 1 day |
| 3.16 Soft-deny detection on iOS HealthKit reads (no samples → prompt) | HealthKit F10 | 0.5 day |
| 3.17 Crash recovery: mark recovered sessions `source: .localOnly` | HealthKit F5 | 0.5 day |
| 3.18 Post-workout share/export (PDF or text) on `SessionDetailView` | UX F7 | 2 days |
| 3.19 Arcade `ctaPrimary` ≠ `running` separation; theme-intensity metadata | UX F8 | 0.5 day |
| 3.20 Body metrics localised units + age-required gate | UX F9 | 1 day |
| 3.21 AOD coalesced UI updates (TimelineView(.everyMinute)) | SwiftUI F4 | 1 day |
| 3.22 `intervalEngine` proper `@Observable` binding in `TrainingView` | SwiftUI F3 | 0.5 day |
| 3.23 Watch retry timer to `DispatchSourceTimer` | SwiftUI F7 | 0.5 day |
| 3.24 `ThemeManager` init partial-failure path + assertion for `selectedThemeID == current.id` | SwiftUI F8 | 0.5 day |
| 3.25 `ProgramSelectionView` AX5 layout test + cardiac-rehab tap-target raise | Accessibility P2-1 | 0.5 day |
| 3.26 Accessibility rotors on `TrainingHistoryView`, `PlanDetailView`, `AnalyticsView` | Accessibility P3-1 | 0.5 day |
| 3.27 Four small a11y polish (P2-2/P2-3/P2-4) | Accessibility P2-2/3/4 | 1 day |
| 3.28 iOS Dashboard: tappable `StartOnWatchCard` deep-linking to watch | UX F2 | 0.5 day |

---

## Total estimated effort

- Batch 1: ~3.5 dev-days (parallelisable; can ship in a single PR cluster within a week)
- Batch 2: ~17 dev-days
- Batch 3: ~30 dev-days
- **Total: ~50 dev-days** of work (≈10 weeks of solo focused work, more in practice once interrupted by App Review cycles).

Confidence on the totals: low. Solo-dev estimates routinely double when refactors expose secondary issues — particularly Architect F1 (`WatchWorkoutManager` split) and Accessibility P0-1 (Dynamic Type sweep) are the line items most likely to balloon.

---

## Integration plan: how the recovery-training spec sequences against the audit fixes

The recovery spec (`specs/2026-04-25/recovery-training.md`) declares zero schema-breaking changes and a Phase 1 sized at ~1 dev-week. Several audit fixes are *load-bearing* for it.

### Hard blockers (recovery cannot land cleanly without these)

| Recovery dep | Audit fix | Batch | Why it blocks |
|---|---|---|---|
| HRR capture during 60-120s post-stop window | HealthKit F9 (background-delivery entitlement) | Batch 3.5 | The recovery spec's marquee algorithm needs HR samples while the workout session is closing — current entitlements don't allow that. |
| Live HR trace correctness | HealthKit F6 (HR source filter) | Batch 2.1 | HRR computed from a HR average contaminated by chest-strap or third-party samples is medically wrong. |
| Recovery sessions exportable to clinicians | HealthKit F2 + F3 (events + metadata) | Batch 2.2 + Batch 1.10 | Recovery sessions need `HKWorkoutEvent` for the work→recovery transition and metadata for `RecoveryReport`. Without them, a recovered HRR value is invisible to Health export. |
| Cardiac-safe HR threshold throughout app | UX F1 | Batch 1.6 | Patient population overlap is total. Shipping recovery while the rest of the app still fires "HIGH INTENSITY" at 161 BPM for a 70-year-old creates safety inconsistency. |
| Theme reactivity on watch live HR trace | SwiftUI F1 | Batch 2.4 | The recovery UI's live HR trace will break on theme switch with the current static-bridge design. |

### Soft blockers (recovery will work but adding it makes Architect F1 + F2 + F3 hurt more)

| Architecture fix | Why it should land first |
|---|---|
| Architect F2 (collapse iOS dual data path) | Recovery sends new payload types from watch → iOS. Adding a third channel into the existing two-path tangle multiplies the surface area. **Strong recommendation: land before recovery code.** |
| Architect F3 (introduce `WatchSyncing` protocol) | Recovery has its own sync (live HR trace tail, recovery report). Routing it through a clean protocol now is much easier than later. |
| Architect F1 (WatchWorkoutManager split) | The recovery state machine wants to sit beside `IntervalEngine` as a peer. Splitting `WatchWorkoutManager` into the proposed three collaborators gives recovery a natural place to attach without bloating the god object further. **Optional but compounding** — every month delayed makes the eventual split larger. |

### Recommended sequencing

1. **Land Batch 1 in week 1.** All quick wins. App is safer, more compliant, and the patient-safety hole closes.
2. **In the same week as Batch 1**, land Architect F2 (Batch 2.16) and start Architect F3 (Batch 3.2). These are the structural prep items the recovery spec needs to plug into.
3. **Sprint 1 of Batch 2**, prioritise: HealthKit F6 (2.1), F2 (2.2), Theme reactivity (2.4). These are the hard blockers above.
4. **Sprint 2 of Batch 2**, the rest of Batch 2 + Architect F3 follow-through.
5. **Then start recovery feature Phase 1.** With HK source filtering, workout events, and sync protocols in place, the recovery spec's "no schema-breaking changes" claim holds and the new code does not have to plug into three separate sync paths.
6. **HK background delivery (Batch 3.5)** can land *with* recovery Phase 2 (the post-workout HRR window), not before. Phase 1 captures HRR during a session-still-active period, so it works with the existing entitlements.

### Recovery spec items the audits did NOT touch (the spec stands on its own here)

- HRR algorithm specifics (3s tolerance, median-of-3 smoothing, 180-sample ring buffer)
- Auto-segmentation state machine + hysteresis
- Choice of `HKWorkoutActivityType.mixedCardio` (avoiding `.cardiacRehabilitation` to dodge medical-positioning App Review flags)
- Battery estimate of ~12-15%/hr
- The three open human-decision questions: HRR threshold for medicated users, HRR2 display, default session duration

Those are clean spec decisions — no audit pre-work needed.
