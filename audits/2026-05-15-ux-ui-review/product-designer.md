# Product Designer Review — 2026-05-15

Scope: every SwiftUI view under `ShuttlX/Views/**`, `ShuttlX/Components/**`, `ShuttlX Watch App/Views/**`, `ShuttlX Watch App/Components/**`. Evaluated for hierarchy, glanceability, state coverage, theme robustness across all 7 themes, motion, cardiac-rehab fit, and the sub-3-tap workout-start rule.

Overall the app is in much better shape than typical indie fitness apps — there is real discipline in `ShuttlXFont` / `ShuttlXColor` bridge tokens, accessibility labels are present nearly everywhere, monospaced digits and `contentTransition(.numericText())` are used consistently, and the multi-theme system means most screens already respect `themedCard()` / `themedScreenBackground()`. The big wins available now are about **hierarchy and glanceability** (especially on watch), **two missing screen states** (loading + offline) that are silently missing on the dashboard, and **a sub-3-tap mismatch** on iOS where workout start is actually 4–5 taps via the watch (the iOS app cannot start a workout — that's fine, but the messaging undersells it).

---

## Top 10 highest-impact improvements (ranked)

### 1. Watch `TrainingView` interval timer is far smaller than free-run timer — wrong hierarchy
- **Screen**: `ShuttlX Watch App/Views/TrainingView.swift:262-326`
- **Problem**: In free-run/walk mode the timer renders at `valueSize = h * 0.19` (~40pt) on the metric-row track. In interval mode, `intervalTimerLine` uses a fixed 56pt ring with `ShuttlXFont.watchMetricSecondary` (which is materially smaller than the 40pt monospaced number elsewhere). The "WHICH step am I in / how long left" is the single most important question during an interval — it must be the biggest thing on screen, not smaller than DIST or HR.
- **Proposed change**: Promote the interval countdown number to ~`valueSize` (matching other metric rows), keep the progress ring but enlarge to ~80pt diameter, and move the step badge (`Z3`-style pill) **inline next to** the countdown rather than below. The "1/12" step counter belongs as a thin top-edge label, not a footer. Use the step's color (`ShuttlXColor.forStepType`) as the ring stroke and as the dominant tint of the entire screen so peripheral vision can read state without focusing eyes — peripheral color recognition is faster than text recognition mid-run.
- **Severity**: P0

### 2. iOS Dashboard has no loading state — silently blank on first launch / cold sync
- **Screen**: `ShuttlX/Views/DashboardView.swift:51-126`
- **Problem**: When `dataManager.sessions` is being loaded from App Group or CloudKit, `cachedLastSession` is `nil`, `cachedStreak` is 0, and `sharedData.isWorkoutActiveOnWatch` is `false` — the user sees `StartOnWatchCard` and `WeekSummaryCard` with empty bars. No skeletons, no "Loading…", no clue that data is coming. The dashboard then "pops" content in 1–2 seconds later, which feels like a bug to a 55-year-old user.
- **Proposed change**: Add a `dataManager.isLoading` flag. While loading, show three `RedactedShimmer` cards (use `.redacted(reason: .placeholder)` + a subtle shimmering opacity animation that respects `reduceMotion`). When empty (loaded but no sessions), promote `StartOnWatchCard` and add a single educational hero card: "Open ShuttlX on Apple Watch to start your first workout." Reuse `themedCard()` for both states so they pick up the active theme.
- **Severity**: P0

### 3. Watch `StartTrainingView` violates 3-tap rule when user has multiple templates
- **Screen**: `ShuttlX Watch App/Views/ProgramSelectionView.swift:34-200`
- **Problem**: The screen is one long unsegmented `ScrollView`: Greeting → Free Run → Gym Recovery → Template 1 → Template 2 → Template N. With 4 templates the user must scroll 1–2 screens down to find their most-used workout. There is no "recents" or "last used" hoist — `lastSessionFor(template:)` just adds a subtitle to the existing row. A cardiac patient who always does the same gym recovery has to scroll past Free Run every single time.
- **Proposed change**: Surface the **single most recently used** template as the first card (with an "Again" badge), then group the rest below under a "More" header. If there is no history, default order is: Free Run, Gym Recovery, Templates. Use a faint `themedCard()` divider between hoisted-recent and the rest. Watch screen real estate is ~200pt tall — one tap should always be enough.
- **Severity**: P0 (this is the literal contract from CLAUDE.md: "sub-3-tap workout start")

### 4. iOS Settings appearance section has no visual preview of each theme — users must select & navigate to see it
- **Screen**: `ShuttlX/Views/SettingsView.swift:299-353`
- **Problem**: Each theme row is `icon + name + subtitle + checkmark`. The single "Preview" swatch at the bottom shows only the **currently selected** theme's colors. To preview Synthwave the user has to (a) tap it, (b) leave Settings, (c) check Dashboard, (d) come back. The themes are the app's signature feature — selling them flat-listed is a missed delight moment.
- **Proposed change**: Replace the flat list with a 2-column `LazyVGrid` of **theme cards**. Each card shows: a tiny 80×40pt mock workout strip (timer + HR + step badge) rendered in that theme's actual palette + font. Tap to select. Currently selected card gets a 2pt `ctaPrimary` ring + checkmark overlay. The swatch row at the bottom can stay as a confirmation. This is the same pattern Apple uses for wallpaper / focus-mode pickers.
- **Severity**: P1 (high impact for retention/delight — themes are the differentiation)

### 5. Watch `RecoveryWorkoutView.restView` color logic conflicts with cardiac-safety messaging
- **Screen**: `ShuttlX Watch App/Views/RecoveryWorkoutView.swift:157-206, 227-231`
- **Problem**: `restTimerColor` makes the rest timer **orange** between 1:00–2:00 and **green** (`ctaPrimary`) after 2:00. Orange means "warning" elsewhere in this very codebase (`ShuttlXColor.ctaWarning`), but here orange means "good, you've passed the 1-minute milestone." For cardiac-rehab users this is dangerously ambiguous — orange-timer + still-elevated-HR could read as "I'm in trouble."
- **Proposed change**: Use a single dimension for safety (HR vs threshold), not time. Color the rest **timer** in `textPrimary` always (it's a clock, not a status). Move all "you're recovered" affordance to the HR readout: the arrow icon next to HR can be `ctaPrimary` when HR drops below 70% maxHR, `ctaWarning` if still above. Keep the 1:00 / 2:00 milestone badges as green-when-reached — those are objective achievement markers. Add an explicit textual "Safe to start next set" label under the HR when `isHRSafe == true`.
- **Severity**: P0 (patient-safety semantics)

### 6. iOS `LiveWorkoutCard` doesn't adapt to theme — uses hardcoded `running` accent only
- **Screen**: `ShuttlX/Views/Dashboard/LiveWorkoutCard.swift:86-93`
- **Problem**: The card uses `RoundedRectangle(cornerRadius: 16).fill(ShuttlXColor.running.opacity(0.08))` directly — it bypasses `.themedCard()`. In Neovim theme this gives a faint green tint on a green-gutter background that nearly disappears. In Mixtape (blue body) the green tint looks dirty. In Arcade (CRT phosphor green background) it's almost invisible.
- **Proposed change**: Replace the inline RoundedRectangle with `.themedCard(accent: ShuttlXColor.running, headerLabel: sharedData.liveIsPaused ? "PAUSED" : "LIVE")`. Keep the pulsing dot but use `ShuttlXColor.ctaPrimary` (theme-aware) for the dot instead of `.running` — "live" is a state, not an activity. Verify in all 7 themes — particularly Neovim (gutter stripe should read as "active file") and Arcade (the pixel border should feel "powered-on").
- **Severity**: P1

### 7. Watch `controlsTab` Pause button uses `ShuttlXColor.ctaPause` — color contract differs from CLAUDE.md
- **Screen**: `ShuttlX Watch App/Views/TrainingView.swift:330-384`
- **Problem**: CLAUDE.md and `.claude/rules/design-system.md` say "Circular buttons: green for pause, red for stop." Current code uses `ctaPause` for pause (which is yellow/orange in most themes) and `ctaDestructive` for finish. That is **actually a better safety signal** than the rule states — green means "go" cognitively, not "pause" — but the docs say green. Either the code or the doc is wrong.
- **Proposed change**: Keep yellow-pause / red-stop (it's the correct convention industry-wide: pause = caution, stop = destructive). Add green play-fill **only** when paused (already done at line 348 — good). Update CLAUDE.md and `.claude/rules/design-system.md` to read "Circular buttons: green play when paused, yellow/amber pause when running, red stop." Leave a note in this audit for `docs-keeper` rather than editing those files myself.
- **Severity**: P1 (documentation drift, not a UX bug — but the rule is repeatedly cited)

### 8. iOS `DashboardView` greeting uses "Hi, <name>" or fallback "Training" — loses time-of-day signal that Watch has
- **Screen**: `ShuttlX/Views/DashboardView.swift:13-19` vs `ShuttlX Watch App/Views/ProgramSelectionView.swift:27-32`
- **Problem**: The watch greets with "Good morning / afternoon / evening" — context-rich and warm. The iPhone greets with "Hi, Sergey" (when signed in) or just "Training" (when not). The iPhone is where most users land first; the muted "Training" title for a signed-out user is cold and uninformative.
- **Proposed change**: Merge both: `"Good morning"` (always) on line 1, `"Hi, Sergey"` (when signed in) on line 2 as `cardCaption` secondary. When signed out, line 2 becomes `"Ready when you are"`. Move from `.navigationTitle()` to an inline `VStack` at the top of the scroll content (more space, more impact, more parallel to Watch). The system nav title still says "ShuttlX" for a-11y.
- **Severity**: P1

### 9. Empty + error states across iOS are inconsistent — three different visual treatments
- **Screen**: `ShuttlX/Views/AnalyticsView.swift:69-88`, `ShuttlX/Views/TrainingHistoryView.swift:190-209`, `ShuttlX/Views/Dashboard/StartOnWatchCard.swift` (implicit empty)
- **Problem**: AnalyticsView wraps its empty state in `.themedCard()` with a centered icon and two text lines. TrainingHistoryView uses an un-carded centered VStack with `.secondary` icon. The dashboard has no empty state at all (just renders an absent live card). Three different empty patterns means users learn nothing.
- **Proposed change**: Extract a `ShuttlXEmptyState` component: `ShuttlXEmptyState(icon: String, title: String, message: String, action: (label: String, handler: () -> Void)? = nil)`. Always carded with `.themedCard()`, always centered, always optional CTA. Use it in 4 places: AnalyticsView empty, TrainingHistoryView empty, TemplateListView when no custom templates exist (currently a footer "Tap + to create" — should be a hero), PlanListView when no custom plans.
- **Severity**: P1

### 10. `SessionRowView` uses `themedCard` with a "MODE STATUS" line (Neovim-style) on every theme — looks great in Neovim, noisy elsewhere
- **Screen**: `ShuttlX/Views/SessionRowView.swift:61-65`
- **Problem**: The `statusLine: (mode: "RUN", file: "session.json", position: "2:1")` adornment is rendered by `themedCard` and is **brilliant** in Neovim (looks like a vim modeline). In Clean and Mixtape themes it's just visual noise — three short cryptic labels at the bottom of every row that don't help glanceability and consume vertical space (~12pt per row × 30 rows visible = 360pt of waste in History view).
- **Proposed change**: Make `themedCard`'s status-line param **theme-aware**: render only when the active theme's `cardStyle == .terminal` (Neovim) — for all other styles, ignore the `statusLine` argument. Callers don't have to change. Verify by reading `ThemeEffects.swift` for the existing CardStyle enum. This is a single-file change in `ThemeModifiers.swift`. Frees ~360pt in History and makes Clean / Mixtape themes denser-feeling without losing the Neovim flavor.
- **Severity**: P1

---

## Per-screen findings

### iOS DashboardView (`ShuttlX/Views/DashboardView.swift:51`)
- **What works**: The card order is correct (Live > StartOnWatch > Plan > Last > Week > Streak). `refreshCachedData()` keyed on session count is efficient. `reduceMotion` is honored.
- **What doesn't**:
  - No loading state (see #2 above).
  - `LiveWorkoutCard` doesn't use themed background (see #6).
  - The streak threshold is `> 1` — a "Day 1" streak deserves celebration too. First-streak users get nothing.
  - When the watch isn't reachable, `StartOnWatchCard` shows a tiny status dot and the word "Not reachable" — the user has no idea what action to take. No troubleshooting hint, no link to settings.
  - `WeekSummaryCard` "day dots" use a fixed 8pt circle (10 for today). At Dynamic Type AX1+ the labels above grow but the dots stay 8pt — they look like flyspecks under XL text.
- **Mockup of improvement** (loading state):
```
+------------------------------------------+
| Good morning                             |
| Hi, Sergey                               |
+------------------------------------------+
|  [shimmer]  Live or Start card           |
+------------------------------------------+
|  [shimmer]  Last workout                 |
+------------------------------------------+
|  [shimmer]  This week                    |
+------------------------------------------+
```
- **Files to change**: `DashboardView.swift`, `LiveWorkoutCard.swift`, `WeekSummaryCard.swift`, `StartOnWatchCard.swift`

### iOS AnalyticsView (`ShuttlX/Views/AnalyticsView.swift:22`)
- **What works**: Empty state is carded and clear. Caches recomputation via `.task(id:)`. Recovery card has color semantics tied to status.
- **What doesn't**:
  - The first thing visible is a "Recovery Status" card whose value (e.g., "Normal") is rendered at `metricLarge` (~32pt) but the explanatory "Form +12" is at `metricMedium` to the right. The user's eye lands on "Form" as much as on the recovery state because they're roughly co-equal in size.
  - The fitness/fatigue/form `MetricCard` row uses 3 cards but `MetricCard` is designed to be a 2-up grid item. At small widths the cards become too narrow and the values clip.
  - `fitnessTrendChart` LineMark + AreaMark gradient is hardcoded `ShuttlXColor.running` — should be `ShuttlXColor.ctaPrimary` to inherit theme accent, otherwise it looks identical to the next chart (weekly distance) which is genuinely about running.
- **Mockup**:
```
+------------------------------------------+
| RECOVERY                                 |
|                                          |
|         NORMAL              Form +12     |
|         (large, color)      (small)      |
+------------------------------------------+
| [Fitness 42]  [Fatigue 28]  [Form +12]   |
+------------------------------------------+
```
- **Files to change**: `AnalyticsView.swift`, possibly `MetricCard.swift` if we add a `.ultraCompact` variant.

### iOS TrainingHistoryView (`ShuttlX/Views/TrainingHistoryView.swift:29`)
- **What works**: Segmented Day/Week/Month picker is idiomatic. Period navigator has 44pt+ tap targets. Charts collapse cleanly when there's no data.
- **What doesn't**:
  - The `metricSummary` LazyVGrid shows up to 4 cards but renders **empty cells** for missing metrics (because of `if let` guards). At small data densities the grid looks ragged.
  - No way to filter by sport type or template. With months of data the list becomes a flat firehose.
  - Empty state is the bare-vstack pattern (see #9).
  - On a Day view with one session, you still get the segmented control + week strip + arrow navigator + empty header — way too much chrome for one row.
- **Files to change**: `TrainingHistoryView.swift`

### iOS SettingsView (`ShuttlX/Views/SettingsView.swift:32`)
- **What works**: Sectioning is logical. Watch status, HealthKit status, sync now action with progress indicator, theme list, paywall, body metrics — all in one place. Accessibility labels are thorough.
- **What doesn't**:
  - Theme picker is flat (see #4 above — top finding).
  - "Max Heart Rate" override field shows the Tanaka estimate as placeholder text, but only after the user has entered Age. If Age is blank the placeholder is `"--"`-ish and the user doesn't know what valid range looks like.
  - "Body Metrics" is buried — for cardiac-rehab users Age + Max HR are the most important settings and should be on top. Currently they sit after Devices.
  - "Watch Status" connectivity health % is shown as a number ("87%") with no qualitative anchor. Below 50% turns warning-orange but above is silent. What does 60% mean to a user?
- **Files to change**: `SettingsView.swift`

### iOS OnboardingView (`ShuttlX/Views/OnboardingView.swift:11`)
- **What works**: 3 pages, clear icons, single CTA per page. HealthKit explanation is good. `symbolEffect(.bounce)` is delightful.
- **What doesn't**:
  - No theme picker in onboarding — first-run users land on Clean and never discover the 6 other themes unless they go to Settings. The single biggest visual feature is hidden.
  - Page 1 "Welcome" has no value prop — it just says "Move at your own pace, guided by your heart rate." For a cardiac-rehab patient that's the **whole pitch** but the copy treats it as a tagline.
  - No "Sign in with Apple" step — users discover iCloud sync only later. Should be optional page 4 (or upgrade Page 2 to combine).
- **Mockup of new Page 4**:
```
+------------------------------------------+
|                                          |
|         Make it yours                    |
|                                          |
|  [Clean]    [Synthwave]   [Mixtape]      |
|  [card]     [card]        [card]         |
|                                          |
|  [Arcade]   [Radio]       [VU Meter]     |
|                                          |
|  [Neovim]                                |
|                                          |
|              [ Use Clean ]               |
+------------------------------------------+
```
- **Files to change**: `OnboardingView.swift` (add page), new component `ThemePickerGrid`.

### iOS TemplateListView (`ShuttlX/Views/TemplateListView.swift:23`)
- **What works**: Free Run and Gym Recovery are pinned as non-deletable top sections. Step preview badges in `templateRow` are a nice density signal.
- **What doesn't**:
  - **Critical UX confusion**: Tapping a template **opens the editor**, not "start workout." But the watch starts the workout when you tap. The mental model splits across platforms. The phone has no "start" — but the row gives no indication of that. Add either an explicit "Open on Watch" badge or remove the misleading tap-to-edit affordance (use a chevron + "Edit" swipe action instead).
  - "Tap + to create an interval workout" as footer text disappears under section padding. Should be an empty-state hero (see #9).
  - The `stepBadge` row at the bottom of each template row clips horribly for templates with 8+ intervals.
- **Files to change**: `TemplateListView.swift`

### iOS ProgramsTabView (`ShuttlX/Views/ProgramsTabView.swift:7`)
- **What works**: Clean two-row index into Training Plans + Interval Workouts. Active plan promoted to top.
- **What doesn't**:
  - This is a redundant index — both children are themselves lists. Users tap twice (Programs tab → Training Plans → plan detail). The Programs **tab** could just be the active plan + a unified scrollable feed of plans + templates, eliminating one tap.
  - Active plan progress bar uses `ctaPrimary` tint — good — but the "Week X, Day Y" pill is also `ctaPrimary`. Too much same-color, no hierarchy.
- **Files to change**: `ProgramsTabView.swift`

### iOS SessionDetailView (`ShuttlX/Views/SessionDetailView.swift:6`)
- **What works**: Duration as hero metric, badges below, segments timeline, route map. Good vertical narrative.
- **What doesn't**:
  - The metric grid (`metricGrid`) has up to 6 cards in a 2-col grid. For a Free Run session with no Pace and no Sport, you can get 3 cards which produces a lopsided grid (2 on top, 1 alone on bottom).
  - No "Compare to last similar session" affordance. A user finishing their 5th Couch-to-5K Week 2 Day 1 has no idea if today was better/worse than the last time.
  - No share-as-image — common ask for fitness apps.
- **Files to change**: `SessionDetailView.swift`

### Watch StartTrainingView / ProgramSelectionView (`ShuttlX Watch App/Views/ProgramSelectionView.swift:34`)
- **What works**: Time-of-day greeting (warmer than iPhone), explicit "Last: 32m Yesterday" subtitles, separate Free Run and Gym Recovery cards. Error banner for HealthKit denial is well done.
- **What doesn't**:
  - No "most recent" hoist (see #3).
  - Greeting takes ~22pt vertical real estate (`watchHeroTitle`) + caption. On 41mm watch that's ~15% of screen before the first card. Could be a single line.
  - Loading state (`isStarting`) replaces the icon with a `ProgressView` but the rest of the row stays — fine. But if HealthKit auth is denied and `workoutManager.startWorkout()` fails, the loader spins and then collapses with no error message anywhere visible. Need an inline toast.
- **Files to change**: `ProgramSelectionView.swift`

### Watch TrainingView free-run/walk display (`ShuttlX Watch App/Views/TrainingView.swift:147`)
- **What works**: Computes sizes from `screenHeight` — adapts well to 41mm vs 49mm. `forHRZone()` for HR color is excellent. High-intensity warning haptic + visual badge is properly cardiac-aware.
- **What doesn't**:
  - 4-row layout (workout name, time, dist, HR, pace) plus optional high-intensity badge = up to 6 stacked rows. At 41mm screen height (197pt), valueSize = ~37pt × 5 rows + spacing = ~210pt. Already overflowing; only saved by `minimumScaleFactor(0.6)`. The smallest watch loses readability fast.
  - Pace label "PACE" is always shown even when pace is `--/KM` (no data). Walking workouts have no meaningful pace for the first 30 seconds — fill that slot with cadence or steps instead until pace stabilizes.
  - The workout name UPPERCASED at top in `ctaPrimary` (or `ctaWarning` when paused) competes with the timer for first-glance. The user already knows what workout they're in — make it smaller.
- **Mockup** (slimmer hierarchy):
```
+---------------------+
| TIME    25:34       |  <- 40pt timer, hero
|                     |
| HR      [142] Z3    |  <- 40pt HR, zone pill
|                     |
| DIST    2.4 km      |  <- 28pt, supporting
| PACE    5:12 /km    |  <- 28pt, supporting (hide if --)
+---------------------+
```
- **Files to change**: `TrainingView.swift`

### Watch TrainingView interval display (`ShuttlX Watch App/Views/TrainingView.swift:274`)
- See #1 above for the main finding. Additionally:
  - The progress ring is `4pt` line width — on a 49mm watch in bright sunlight, 4pt at low contrast (15% opacity track) is invisible. Bump to 6pt and increase track opacity to 0.25.
  - The `Z3`-style zone pill on the HR row is small and gets clipped against the right edge at narrow screen widths.
- **Files to change**: `TrainingView.swift`

### Watch RecoveryWorkoutView idle/work/rest (`ShuttlX Watch App/Views/RecoveryWorkoutView.swift:15`)
- **What works**: Three-state machine (`idle`/`work`/`rest`) is the right model. Idle's progress ring around HR while "Detecting station…" is a beautifully gentle affordance. Milestone badges at 1:00 and 2:00 are textbook HRR1/HRR2 UX.
- **What doesn't**:
  - Color semantics in restView (see #5).
  - In the `workView`, the HR readout uses `forHRZone` color. But Station 1 (warm up to first set) and Station 5 (peak) will look identical if the user happens to hit Z3 both times. Add a thin progress dot row above (e.g., `● ● ● ○ ○`) showing how many sets are recorded.
  - Idle's "Sit on machine" prompt is `textSecondary` at `labelSize` (small). For a 55-year-old user this is the **first** instruction in the entire flow. Make it larger and use `ctaPrimary`.
  - Hard-coded `185.0` max HR in `hrZoneLabel` (line 213) and `isHRSafe` (line 224) is bypassing the `HeartRateZoneCalculator` system. A 70-year-old user's max HR is closer to 150 — this miscalibrates everything for the people who need it most.
- **Files to change**: `RecoveryWorkoutView.swift` (urgent: use `HeartRateZoneCalculator.fromSharedDefaults()` instead of literal 185)

### Watch WorkoutSummaryView (`ShuttlX Watch App/Views/TrainingView.swift:468`)
- **What works**: Spring-in badge animation, hero timer, scrollable metrics. Done CTA has primary style.
- **What doesn't**:
  - No "Share to iPhone" button — the data syncs automatically but a user finishing on watch has no obvious affordance that says "the iPhone has it now." A single line "Synced to iPhone ✓" would close the loop.
  - The metrics section is wrapped in `.themedCard()` but each row inside is a flat HStack — no visual separation between rows. Subtle dividers would help glanceability when scrolling through 7+ rows.
- **Files to change**: `TrainingView.swift`

---

## Missing screens / states that should exist

### Dashboard skeleton-loading state
- **Where**: `ShuttlX/Views/DashboardView.swift`
- **Why**: Cold launches and CloudKit syncs feel like the app is broken for ~1–2s.
- **Sketch**: 3 redacted `themedCard()` placeholders with shimmering opacity. See #2.

### Watch offline / unreachable banner
- **Where**: `ShuttlX/Views/Dashboard/StartOnWatchCard.swift`
- **Why**: When watch is unpaired or app not installed, current UI just shows a grey dot. User has no recovery path.
- **Sketch**:
```
+------------------------------------------+
| 🔗 Watch not reachable                   |
| Open ShuttlX on your Apple Watch          |
| or check Bluetooth & Watch app.          |
| [ Troubleshoot ]                         |
+------------------------------------------+
```

### Workout-start error toast on watch
- **Where**: `ShuttlX Watch App/Views/ProgramSelectionView.swift`
- **Why**: HealthKit can fail to start (auth, busy session, etc.). Currently the spinner just stops with no message.
- **Sketch**: 2-line toast slides from top: "Couldn't start — Health access denied" + "Open Settings" button.

### Theme picker as part of onboarding
- **Where**: `ShuttlX/Views/OnboardingView.swift` — new page 4 (or replace page 3 watch-pairing on a paired device).
- **Why**: 7 themes are the visible differentiator. Burying them in Settings hides the magic. See #4.

### Empty-template hero on Programs tab
- **Where**: `ShuttlX/Views/TemplateListView.swift`
- **Why**: New users see only Free Run + Gym Recovery + footer text. They miss that they can build their own intervals.
- **Sketch**: After the two pinned cards, a dashed-border card with "Tap to build your first interval workout" — large, inviting, themed.

### Per-step preview when starting an interval template (watch)
- **Where**: Between tapping a template and the workout starting, the watch should show a 1-screen "ready" view with: "12 sets of (30s work + 30s rest), 14 min total. Starting in 3…"
- **Why**: Cardiac-rehab users benefit from previewing intensity before commit. Currently it jumps straight to live timer.

### Plan-completion celebration
- **Where**: `ShuttlX/Views/PlanDetailView.swift` when `completion == 1.0`
- **Why**: Couch-to-5K finishing on day 1 of week 9 is a huge moment with no recognition. A confetti badge + share screen would drive retention/word-of-mouth.

---

## Cross-cutting opportunities

### A. Extract a `ShuttlXEmptyState` component
Three different empty patterns (AnalyticsView, TrainingHistoryView, TemplateListView, PlanListView) — unify behind one component. Already detailed in #9. Single component, four call sites, drops ~80 LOC.

### B. Make `themedCard`'s status-line theme-aware
The `statusLine: (mode:, file:, position:)` adornment is brilliant for Neovim and noise for everything else. Gate behind `themeEffects.cardStyle == .terminal`. One-file change in `ThemeModifiers.swift`. Removes visual clutter from ~6 screens. See #10.

### C. Centralise time-of-day greeting
Both `DashboardView.swift:13` and `ProgramSelectionView.swift:27` compute their own greeting. Move to a single `Greeting.current()` helper in shared formatting. (Models are duplicated per `.claude/rules/models.md` — put it in a shared utility folder that's safely mirrored.)

### D. Unify "Last session" subtitle pattern
`ProgramSelectionView.lastSubtitle`, `TemplateListView` row, `LastWorkoutCard`, and `DashboardView`'s plan card all format "Last: 32m Today" slightly differently. Create one `LastSessionLabel(session: TrainingSession)` view.

### E. Adopt `MetricCard.ultraCompact` variant for 3-up rows
`AnalyticsView.fitnessOverviewRow` and `TrainingHistoryView.metricSummary` both squeeze 3+ MetricCards into one row. Add a third `compact` mode (icon inline with value, label below) so the cards don't clip at small widths. Single component change benefits 4 screens.

### F. Theme-test all custom backgrounds (urgent)
The audit flagged `LiveWorkoutCard` (#6) as bypassing `themedCard`. Grep for `RoundedRectangle(cornerRadius:` and `.fill(Color.` outside the Theme folder. Likely candidates also include: `IntervalResultsView`, `OnboardingView` (the page indicator), `SignInView` button, sundry chart fills. Each is a 1-line fix to use `themedCard` or `ShuttlXColor.*`.

### G. Animate the dashboard reorder when a workout starts/ends
Currently the live card appears/disappears with the existing spring transition (good), but `StartOnWatchCard` and other cards just hop into the gap. Wrap the entire VStack in a `withAnimation` block keyed on `isWorkoutActiveOnWatch` to smooth the reflow. Already partly done at `DashboardView.swift:122` — extend to the inner cards.

### H. Dynamic Type stress test
Several screens (`WeekSummaryCard` day dots, `RecoveryWorkoutView` milestone badges, `MetricCard.compact`) use fixed pixel sizes for non-text elements but Dynamic Type text alongside them. At AX1+ the proportions break. Audit pass: every `.frame(width:`/`height:` adjacent to a `.font()` element.

### I. Audit hardcoded max-HR
`RecoveryWorkoutView.hrZoneLabel` uses literal `185.0`. There's a real `HeartRateZoneCalculator.fromSharedDefaults()` already in use elsewhere on this screen's parent (`TrainingView`). Single-file change but **affects cardiac safety semantics** — bump priority. Open question for `swiftui-watchos-specialist`.

---

## Open questions / leave-behinds for other agents

- `senior-ios-developer`: The `themedCard` status-line is rendered on every theme — should the gating live in `ThemeModifiers.swift` or in each call site? I recommend the former.
- `swiftui-watchos-specialist`: `RecoveryWorkoutView` literal `185.0` max HR — bug or intentional default before user enters age? Likely bug; see cross-cutting #I.
- `docs-keeper`: CLAUDE.md and `.claude/rules/design-system.md` say "green=pause, red=stop" — actual code is yellow-pause/red-stop. Update the docs (see #7).
- `healthkit-domain-expert`: `isHRSafe` cardiac threshold is hardcoded at `0.70 * 185` in `RecoveryWorkoutView.swift:222-225`. Is 70% the right safety floor for post-cardiac-event patients, and should it be a user-configurable setting in Body Metrics?
- `accessibility-auditor`: Sweep Dynamic Type AX1+ on `WeekSummaryCard` day dots and `MetricCard.compact` — likely broken proportions.
