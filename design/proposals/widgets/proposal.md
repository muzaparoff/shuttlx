# Widget Lineup Expansion — ShuttlX iOS + watchOS

Date: 2026-07-25
Owner: product-designer
Scope: home-screen widgets, lock-screen accessories, iOS 18 Controls, watch complications
Themes in scope: **Clean** (default, soft glass ring) + **Mixtape** (cassette spool/window). Widget extensions can't reach `ThemeManager` — they read `selectedThemeID` from App Group UserDefaults via `WidgetTheme.forID(_:)` (already implemented in `ShuttlXWidgets/MediumWidget.swift`).

---

## 1. Grounding — what exists today

| Platform | Widget | Families | Data | Interaction |
|---|---|---|---|---|
| iOS | `SmallWidget` (Training Streak) | systemSmall | streak, timeSince, trainedToday | `widgetURL` → `shuttlx://dashboard` |
| iOS | `MediumWidget` (Today's Workout) | systemMedium | last/today session metrics + week count | `widgetURL` → `shuttlx://session/{id}` |
| watch | `LastWorkoutComplication` | accessoryRectangular | last session dist/dur | `shuttlx://last-workout` |
| watch | `WeeklyProgressComplication` | accessoryCircular, accessoryRectangular | week count vs goal | none (glance) |
| watch | `QuickStartComplication` | accessoryCircular, accessoryRectangular, accessoryInline | none | `shuttlx://start-workout` (already starts free run on watch) |
| watch | `TodayWorkoutComplication` | accessoryRectangular | today session or week-goal fallback | `shuttlx://home` |

**Gaps this proposal fills:** no configurable (user-chosen) start widget, no iOS 18 Control, no lock-screen accessories on iOS, no systemLarge, no watch `accessoryCorner`, no "next planned workout", no recovery/readiness surface, and no widget carries the **signature-shape theme identity** (all current widgets are flat gradient cards).

### Data available to widgets
- `sessions.json` (App Group) → `WidgetDataProvider` / `WatchWidgetDataProvider`: `lastSession`, `todaySession`, `thisWeekSessionCount`, `currentStreak`.
- `workout_templates.json` → template list (id, name, `summaryText`, sportType) for configuration pickers.
- App Group UserDefaults: `selectedThemeID`, `weeklyWorkoutGoal`.
- Training plans (`ShuttlXShared.TrainingPlan` / `BuiltInPlans`) → next planned day (new provider needed).
- Recovery/readiness: **not persisted yet** — see Open Questions (widget #7 depends on this).

### What starting a workout requires
- **iOS widget → watch**: `PhoneSyncCoordinator.startWatchWorkout(mode:template:)` already exists but runs in-app, not in the widget process. So the iOS start widgets deep-link into the host app (`shuttlx://start/...`), and the host app calls `startWatchWorkout`. **The host `onOpenURL` switch needs a new `start` host** (see iOS hand-off).
- **watch widget → watch app**: `shuttlx://start-workout` already starts a free run directly. A template variant needs `shuttlx://start-template/{id}`.

---

## 2. The lineup — 14 widgets (≥10 requested)

Legend — Effort: **S** ≤0.5d, **M** ~1d, **L** ~2d. Priority tier in §4.

### iOS

#### W1 — Start Training (configurable) ⭐ SHIP FIRST
- **Platform / families:** iOS — systemSmall, systemMedium
- **Purpose:** One-tap start of *the workout the user chose when they added the widget* — put a named session on the Home Screen.
- **Data:** selected template (name, `summaryText`, sport icon) via `AppIntentConfiguration`; falls back to Free Run if none chosen or template deleted.
- **Refresh:** `.never` (static content; re-renders when config changes). Reconfiguration when templates change is best-effort — stale name tolerated, tap still routes by id.
- **Interaction:** `IntentConfiguration` with a `WorkoutTemplateEntity` `@Parameter` (AppEntity query over `workout_templates.json`). Tap → `widgetURL` `shuttlx://start/template/{id}` (or `shuttlx://start/freerun`). Host app resolves id → `startWatchWorkout(mode:"interval",template:)`. Not an in-process AppIntent button because starting needs WatchConnectivity from the host process.
- **Theme treatment:**
  - **Clean:** frosted card, soft glass **ring** hugging a centered `figure.run` / sport glyph; template name below, `summaryText` caption. Ring is the calm signature shape — no fill animation.
  - **Mixtape:** card styled as a **cassette label** — template name on a handwritten-label strip, a small **spool** glyph (circle + 3 spokes) as the play affordance, `▸ PLAY` in the corner. Blue body (`WidgetTheme.mixtape.surface`).
- **States:** configured (name+summary), unconfigured/deleted-template (shows "Free Run · Tap to start"), placeholder (redacted name), error/no-App-Group (defaults to Free Run label — never blank).
- **Effort:** **M** (AppEntity + query + new deep-link host).

```
systemSmall — Clean                systemSmall — Mixtape
┌───────────────┐                  ┌───────────────┐
│   ╭─────╮     │ glass ring       │ ┌───────────┐ │ label strip
│   │ 🏃  │     │                  │ │ 5K Builder│ │
│   ╰─────╯     │                  │ └───────────┘ │
│  5K Builder   │ 15pt semibold    │   ◉  ▸PLAY     │ spool + play
│  8× · 24m     │ 11pt caption     │  8× · 24m      │
└───────────────┘                  └───────────────┘
```

#### W2 — Quick Start Control (iOS 18) ⭐ SHIP FIRST
- **Platform / families:** iOS — `ControlWidget` (Control Center, Lock Screen control slot, Action button).
- **Purpose:** Start a **Free Run** from anywhere without opening the app — the fastest possible "begin moving" affordance.
- **Data:** none (or optional "is a workout already active?" to relabel).
- **Refresh:** static.
- **Interaction:** `ControlWidgetButton` bound to a `StartFreeRunIntent` (AppIntent). Intent opens the app (`openAppWhenRun = true`) via `shuttlx://start/freerun`, host calls `startWatchWorkout(mode:"freeRun")`. (A control can't run WatchConnectivity itself, so it opens the app — still 1 tap, no navigation.)
- **Theme treatment:** Controls are system-tinted monochrome — use SF Symbol `figure.run` + label "Free Run". Theme identity here is just the tint; both themes render the same glyph (respects "no per-theme icon sets" anti-goal).
- **States:** idle ("Free Run"), active-workout ("Open Workout" if we can read a shared flag), unavailable (still shows, opens app).
- **Effort:** **S** (small AppIntent + control; deep link infra shared with W1).

#### W3 — Weekly Goal Ring ⭐ SHIP FIRST
- **Platform / families:** iOS — systemSmall + `accessoryCircular` + `accessoryRectangular` (lock screen).
- **Purpose:** "How many of my weekly workouts are done" — the top daily-return driver for interval/rehab users.
- **Data:** `thisWeekSessionCount()` + `weeklyWorkoutGoal`. Reuses existing provider logic.
- **Refresh:** `.after(+1h)` and on session sync.
- **Interaction:** `widgetURL` → `shuttlx://dashboard`.
- **Theme treatment:**
  - **Clean:** the **soft glass ring** IS the progress gauge — luminous arc, `3/5` centered, "2 to go" caption. This is the canonical Clean signature.
  - **Mixtape:** progress drawn as a **cassette spool winding** — the ring is the reel rim, filled spokes = completed workouts (5 spokes for a 5-goal), center hub shows `3/5`. Custom `Canvas`, not `Gauge` (stock gauge is a "generic" tell on a themed surface).
  - accessoryCircular: system `Gauge(.accessoryCircular)` (monochrome, tint only — lock screen can't theme heavily).
- **States:** in-progress, goal-reached (ring full + subtle check, no confetti — calm), zero (empty ring, "Start your week"), placeholder (redacted count).
- **Effort:** **M** (custom Mixtape spool Canvas).

```
systemSmall — Clean ring           systemSmall — Mixtape spool
┌───────────────┐                  ┌───────────────┐
│   ╭╌╌╌╌╮       │ arc 60% filled   │   ╭─◉─╮        │ reel, 3 of 5
│  ╱  3   ╲      │                  │  │╱│╲│  3/5    │ spokes filled
│ │  ─── │      │                  │  ╲─◉─╱        │
│  ╲  5   ╱      │                  │  THIS WEEK    │
│   ╰────╯       │ "2 to go"        │  ▓▓▓░░         │ tape-wound bar
└───────────────┘                  └───────────────┘
```

#### W4 — Training Streak (restyle existing SmallWidget)
- **Platform / families:** iOS — systemSmall (keep), **add** `accessoryInline` + `accessoryCircular`.
- **Purpose:** Keep the streak visible so users don't break it — loss-aversion is the strongest rehab-adherence lever.
- **Data:** `currentStreak()`, `trainedToday`. Same as today.
- **Refresh:** `.after(+30m)`.
- **Interaction:** `shuttlx://dashboard`.
- **Theme treatment:** Clean — flame in glass ring. Mixtape — streak number on the cassette counter (mechanical 3-digit tape-counter look, monospaced). accessoryInline: "🔥 5-day streak" (SF Symbol allowed inline). accessoryCircular: number in ring.
- **States:** streak>0, streak=0 (shows last-workout time — existing behavior), trained-today badge, placeholder.
- **Effort:** **S** (mostly reskin + 2 new families).

#### W5 — Next Planned Workout
- **Platform / families:** iOS — systemMedium + `accessoryRectangular`.
- **Purpose:** "What's on the plan next" — turns a training plan into a daily nudge; removes the decide-what-to-do friction.
- **Data:** next incomplete `PlanDay` from active `TrainingPlan` (new `PlannedWorkoutProvider` reading plan progress from App Group). Shows day title, target (e.g. "Run 3 · Walk 2 ×6"), scheduled day.
- **Refresh:** `.after(+3h)` + on plan progress change.
- **Interaction:** systemMedium has an interactive **Start** affordance → `shuttlx://start/template/{planTemplateId}`; body tap → `shuttlx://plan`.
- **Theme treatment:** Clean — glass card, thin ring around the day number. Mixtape — "SIDE A · TRACK 4" now-playing framing (reuses the Mixtape deck vocabulary from the watch timer), spool bullet.
- **States:** has-next, plan-complete ("Plan complete — pick a new one"), no-active-plan ("Browse plans"), rest-day ("Rest day — recover"), placeholder.
- **Effort:** **L** (needs plan-progress persistence surfaced to App Group).

#### W6 — Weekly Dashboard (systemLarge)
- **Platform / families:** iOS — systemLarge.
- **Purpose:** One-glance command center: streak + weekly ring + last workout + next planned — for users who want the whole picture on page 1.
- **Data:** composite of W3+W4+W5+last session.
- **Refresh:** `.after(+1h)`.
- **Interaction:** multiple tap zones (iOS 17 widget tap regions): ring→dashboard, next-workout row→`shuttlx://start/template/{id}`, last-workout row→`shuttlx://session/{id}`.
- **Theme treatment:** Clean — glass panels separated by spacing (no dividers per design-system rule), one hero ring top-left. Mixtape — full cassette face: two spools (left = week progress, right = streak), tape window across middle showing last workout, tracklist row for next planned.
- **States:** full, partial (missing plan → hides next-workout row), empty (first-run welcome), placeholder.
- **Effort:** **L**.

```
systemLarge — Mixtape cassette face
┌──────────────────────────────────────┐
│  ◉ WEEK 3/5        STREAK 5 ◉          │ two spools
│  ╞════════ tape window ════════╡       │
│  LAST · Free Run · 28m · 3.2km        │ tape strip
│  ────────────────────────────         │
│  NEXT · Run/Walk ×6 · 24m   [ ▸ ]     │ start button
└──────────────────────────────────────┘
```

#### W7 — Recovery Status (cardiac-rehab)
- **Platform / families:** iOS — systemSmall + `accessoryCircular`.
- **Purpose:** Tell a post-cardiac-event user whether today is a **go** or a **rest** day — safety-first, simpler over flashier.
- **Data:** readiness signal (rest days since last workout, weekly load vs goal, optionally resting-HR trend if surfaced). **Depends on a readiness metric being persisted** — see Open Questions.
- **Refresh:** `.after(+3h)`, morning-biased.
- **Interaction:** `shuttlx://dashboard` (or recovery detail when it exists).
- **Theme treatment:** deliberately **calm in both themes** — Clean glass ring in green/amber; Mixtape uses a muted spool but same 3-state color. No red-alarm styling (avoid anxiety); amber = "consider resting", never "danger".
- **States:** ready (green), caution/rest-suggested (amber), rested-too-long nudge ("3 days off — a gentle walk?"), unknown/insufficient-data ("Log a workout to see recovery"), placeholder.
- **Effort:** **L** (blocked on readiness data model — ship after healthkit/recovery work).

### watchOS

#### W8 — Free Run Start ⭐ SHIP FIRST
- **Platform / families:** watch — `accessoryCircular`, `accessoryCorner`, `accessoryInline`.
- **Purpose:** Start a Free Run **directly from the watch face** with one tap — the user's explicit wish #2.
- **Data:** none (optional: show today's count in corner).
- **Refresh:** static.
- **Interaction:** `widgetURL` `shuttlx://start-workout` (already wired to `workoutManager.startWorkout()` in `ShuttlXWatchApp.swift`). This is effectively a re-family of the existing `QuickStartComplication` into circular+corner+inline. accessoryCorner shows a curved "FREE RUN" label + run glyph.
- **Theme treatment:** SF Symbol `figure.run`, `widgetAccentable()` (watch faces tint complications — heavy theming is off-limits). Corner curved gauge can carve a thin **ring** (Clean) reading as glass; Mixtape can't do much at complication scale, so identity is deferred to the app.
- **States:** idle, workout-active (relabel to "In Workout" if a shared active flag is readable), placeholder.
- **Effort:** **S** (extend existing `QuickStartComplication` families + corner view).

#### W9 — Start Template (configurable, watch)
- **Platform / families:** watch — `accessoryRectangular`, `accessoryCircular`.
- **Purpose:** Put a **specific chosen interval workout** on the watch face — pick once, start daily.
- **Data:** selected template via watch-side `AppIntentConfiguration` (same `WorkoutTemplateEntity`, querying the watch's `workout_templates.json`).
- **Refresh:** static (re-render on config change).
- **Interaction:** `shuttlx://start-template/{id}` → new watch deep-link case → `workoutManager.startIntervalWorkout(template:)`. Rectangular shows template name + `summaryText` + a run glyph; circular shows sport glyph + interval count.
- **Theme treatment:** rectangular can show template name + tiny spool bullet (Mixtape) / dot (Clean); mostly accent-tinted per face.
- **States:** configured, unconfigured ("Pick a workout"), deleted-template (falls back to Free Run), placeholder.
- **Effort:** **M** (watch AppEntity + new deep-link case).

#### W10 — Weekly Ring (extend existing WeeklyProgress)
- **Platform / families:** watch — `accessoryCircular`, `accessoryRectangular` (keep) + **add** `accessoryCorner`.
- **Purpose:** Weekly goal glance on a corner-style watch face (Infograph/Modular).
- **Data:** `thisWeekSessionCount` vs `weeklyWorkoutGoal` (existing).
- **Refresh:** `.after(+1h)`.
- **Interaction:** glance (add `shuttlx://dashboard` optionally).
- **Theme treatment:** corner uses `Gauge(.accessoryCorner)` with count as the current-value label — reads as the Clean ring; identity via accent only.
- **States:** progress, goal-reached, zero, placeholder.
- **Effort:** **S** (one new family + corner layout).

#### W11 — Streak Corner
- **Platform / families:** watch — `accessoryCorner` + `accessoryCircular`.
- **Purpose:** Keep the streak on a corner complication slot for streak-driven users.
- **Data:** `currentStreak()` (needs a watch-side streak helper — `WatchWidgetDataProvider` currently lacks `currentStreak`; port from iOS `WidgetDataProvider`).
- **Refresh:** `.after(+30m)`.
- **Interaction:** `shuttlx://home`.
- **Theme treatment:** flame SF Symbol + curved count; accent tint only.
- **States:** streak>0, streak=0 ("Start"), placeholder.
- **Effort:** **S** (+port `currentStreak` to watch provider).

#### W12 — Today / Next (extend TodayWorkoutComplication)
- **Platform / families:** watch — `accessoryRectangular` (keep) + **add** `accessoryInline`.
- **Purpose:** Rectangular already shows today's workout or weekly-goal fallback; add an inline one-liner for text-slot faces ("✓ Free Run 28m" / "3/5 this week").
- **Data:** existing `TodayWorkoutProvider`.
- **Refresh:** `.after(+30m)`.
- **Interaction:** `shuttlx://home`.
- **Theme treatment:** inline is system text — accent tint only.
- **States:** trained-today, not-yet (weekly goal), placeholder.
- **Effort:** **S**.

#### W13 — Recovery Corner (cardiac-rehab, watch)
- **Platform / families:** watch — `accessoryCircular`, `accessoryCorner`.
- **Purpose:** Watch-face readiness dot — go/rest at a glance for rehab users (mirror of W7).
- **Data:** same readiness signal as W7 (**blocked on readiness model**).
- **Refresh:** `.after(+3h)`.
- **Interaction:** `shuttlx://home`.
- **Theme treatment:** calm 3-state color, `widgetAccentable`. No alarm styling.
- **States:** ready / rest-suggested / unknown / placeholder.
- **Effort:** **M** (blocked on readiness data — ship with W7).

#### W14 — Last Workout (extend existing) + circular
- **Platform / families:** watch — `accessoryRectangular` (keep) + **add** `accessoryCircular` (distance ring).
- **Purpose:** circular slot showing last workout distance/duration for at-a-glance recap.
- **Data:** existing `LastWorkoutComplicationProvider`.
- **Refresh:** `.after(+30m)`.
- **Interaction:** `shuttlx://last-workout`.
- **Theme treatment:** circular = duration in a thin ring (Clean-style), glyph in center.
- **States:** has-session, no-session ("—"), placeholder.
- **Effort:** **S**.

---

## 3. Coverage matrix

| Size / family | iOS widgets | watch widgets |
|---|---|---|
| systemSmall | W1, W3, W4, W7 | — |
| systemMedium | W1, W5 | — |
| systemLarge | W6 | — |
| accessoryInline (lock/face) | W4 | W8, W12 |
| accessoryCircular | W3, W4, W7 | W8, W9, W10, W11, W13, W14 |
| accessoryRectangular | W3, W5 | W9, W10, W12, W14 |
| accessoryCorner | — | W8, W10, W11, W13 |
| iOS 18 Control | W2 | — |
| Configurable (AppIntent) | W1 | W9 |

Every family Apple offers on each platform is now covered, plus a Control and two configurable start widgets.

---

## 4. Prioritization — ship order

**Tier 1 (ship first — highest value ÷ effort, satisfies both explicit user wishes):**
1. **W1 Start Training (configurable)** — user wish #1; the marquee feature. Effort M.
2. **W8 Free Run Start (watch)** — user wish #2; deep link already exists, near-free. Effort S.
3. **W2 Quick Start Control (iOS 18)** — huge convenience, reuses W1's deep-link plumbing. Effort S.
4. **W3 Weekly Goal Ring** — the strongest daily-return driver (goal progress), and it's where the signature-shape identity (glass ring / cassette spool) lands most visibly. Effort M.

Rationale: Tier 1 delivers both requested start widgets, the flashiest new capability (Control), and the retention hook (weekly ring) — while establishing the shared `start` deep-link infra + the reusable spool/ring theme canvases that every later widget reuses.

**Tier 2 (fast follow — mostly reskins/new families of existing providers):**
W4 Streak (+ families), W10 Weekly Ring corner, W11 Streak Corner, W12 Today/Next inline, W14 Last Workout circular, W9 Start Template (watch).

**Tier 3 (needs new data model — schedule after plan-progress + readiness work):**
W5 Next Planned Workout, W6 Weekly Dashboard (large), W7 Recovery Status (iOS), W13 Recovery Corner (watch).

---

## 5. Shared infrastructure these widgets introduce

- **`WorkoutTemplateEntity` (AppEntity) + `TemplateEntityQuery`** — reads `workout_templates.json` from App Group; used by W1 (iOS) and W9 (watch). Must live in a location both the widget extension and app can compile.
- **`StartFreeRunIntent` / `StartTemplateIntent` (AppIntents)** — for the Control (W2) and configurable widgets.
- **`start` deep-link host** — iOS host `onOpenURL` gains `case "start"` → `freerun` / `template/{id}` → `startWatchWorkout(...)`. Watch gains `start-template/{id}` → `startIntervalWorkout(template:)`.
- **Two reusable theme canvases** — `GlassRingProgress` (Clean) + `CassetteSpoolProgress` (Mixtape), parametric on 0...1 progress. These are the widget-side embodiment of the signature-shape rule and are reused by W3/W4/W6/W7/W10/W11.
- **`WidgetTheme` cleanup** — file still carries deleted themes (synthwave/arcade/classicradio/neovim). Leave to devs, but only `clean` + `mixtape` matter now (noted in hand-offs).

See `ios.md` and `watch.md` for per-platform hand-off.
