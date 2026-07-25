# Proposal 3 — Dashboard idle state (iOS hand-off)

Mockup: [`idle-state-mockup.html`](idle-state-mockup.html)
Surfaces: `ShuttlX/Views/Dashboard/LastWorkoutCard.swift`, `ShuttlX/Views/Dashboard/WeekSummaryCard.swift`

---

## 1. Why

Two specific failures, both named in the research (`../README.md` §1):

1. **`WeekSummaryCard` is stock data-viz.** `7 × Circle().fill(sessionCount > 0 ? running : surface)`
   encodes a boolean and discards duration — which the card then prints as 9pt text underneath,
   because the chart could not carry it.
2. **The Mixtape treatment is a sticker.** `themedCard(headerLabel:)` wraps
   `CassetteHeaderView` ("IEC TYPE II") and `ReelCounterView` ("◀◀ REW  0000:00  FF ▶▶") around
   an otherwise untouched generic card. `0000:00` is **hardcoded and always reads zero** — it is
   decoration pretending to be a readout. That is exactly "a label on top of a generic dark card".

Also: both cards inherit the P0 hub-bezel collision from `mixtapeBackground()` (see
`../live-workout-card/ios.md` §2).

## 2. Core moves

### 2.1 `session.segments` → a tracklist

`TrainingSession.segments: [ActivitySegment]` already exists and is already read by
`LastWorkoutCard` (to sum `totalRunningDuration` / `totalWalkingDuration` into two badges).
Render each segment as a numbered track instead:

```
A1  RUN    ▓▓▓▓▓▓▓▓░░░░   12:04
A2  WALK   ▓▓▓▓░░░░░░░░    6:30
A3  RUN    ▓▓▓▓▓▓▓░░░░░    9:12
    + 5 MORE TRACKS ›
```

- Bar level = `segment.duration / maxSegmentDuration`
- Tint = `ShuttlXColor.forStepType` / activity colour
- **Cap at 3 tracks + "+ N MORE"** — the card must not grow unbounded on a 20-step template.
  Tapping the card already navigates to `SessionDetailView`, which is the right place for all of them.
- Free-run sessions have 1 segment → show as a single track. Gym recovery → stations as tracks.

### 2.2 `WeekSummaryCard` dots → segment columns

7 columns × 8 vertical segments. `litCount = round(dayDuration / weekMaxDuration * 8)`.
Days above the weekly-goal pace get amber caps. Today's label brightens (Mixtape) or gets a
ring outline (Clean) — **not** a bigger dot.

### 2.3 Chrome must carry data

Replace the fake `ReelCounterView` readout:

| Fake today | Real replacement |
|---|---|
| `0000:00` (hardcoded) | `31:20 TOTAL` — actual session duration |
| `◀◀ REW / FF ▶▶` | `8 TRACKS` — actual segment count |
| `IEC TYPE II` (static) | keep as a bottom brand strip only — it is fine as *branding*, wrong as a *header* |

Recommendation: **delete `ReelCounterView`** rather than fix it. A control affordance that
does nothing is worse than no chrome.

### 2.4 Deduplicate titles

`LastWorkoutCard` currently renders "Last Workout" as a `Text` **and** passes
`headerLabel: "LAST WORKOUT"` to `.themedCard()`. Pick one — the header strip. The body then
uses that space for the actual workout name, which is currently not shown at all.

## 3. Files

### Create
- **`ShuttlX/Theme/Components/SegmentBar.swift`**
  ```swift
  struct SegmentBar: View {
      let count: Int              // segments
      let level: Double           // 0…1
      var axis: Axis = .horizontal
      var bands: [(upTo: Int, color: Color)]   // colour by index
      var segmentSize: CGFloat = 8
      var spacing: CGFloat = 2
  }
  ```
  Shared by this proposal and Proposal 1. See the table at the bottom of the mockup for all
  five call sites (two already exist as private duplicates).
- **`ShuttlX/Views/Dashboard/LastWorkoutCardStyles.swift`** — `MixtapeRecordingCard`, `CleanLastWorkoutCard`
- **`ShuttlX/Views/Dashboard/WeekSummaryCardStyles.swift`** — `MixtapeWeekVU`, `CleanWeekBars`

### Modify
- **`LastWorkoutCard.swift`** → dispatcher on `themeManager.current.id`; keep the `session`
  input and the a11y label. Add `@Environment(ThemeManager.self)`.
- **`WeekSummaryCard.swift`** → dispatcher. **Keep `weekDays` / `weekTotalDuration` /
  `weekSessionCount` exactly as they are** — the data layer is correct, only the rendering changes.
- **`ThemeModifiers.swift`** → `showHubs: false` in `mixtapeBackground()` (shared with Proposal 1
  — whoever lands first does it).

### Delete
- `ReelCounterView` (fake readout) and the `headerLabel`-driven `CassetteHeaderView` path in
  `themedCard()` **if** all callers move to the new dispatched cards. Audit callers first:
  `LastWorkoutCard`, `WeekSummaryCard`, and possibly others pass `headerLabel:`.

### Reuse
`ActivityBadge` (still useful in `SessionDetailView`), `FormattingUtils.*`,
`ShuttlXColor.forStepType/running/walking/heartRate/calories`, `theme.effects.cardCornerRadius`,
`PressScaleButtonStyle` (the `NavigationLink` wrapper in `DashboardView` stays unchanged).

## 4. States — both cards

| State | Last Workout (Mixtape) | Last Workout (Clean) | Week (Mixtape) | Week (Clean) |
|---|---|---|---|---|
| Populated | J-card + tracklist + totals | Glass + stacked bar + legend | 7 VU columns | 7 rounded bars |
| Empty | Blank ruled J-card, `PRESS REC ON YOUR WATCH` | Open ring, "Your first workout" | 7 unlit columns | 7 empty troughs |
| Loading | Ghost segments @12% (the `88:88` trick) | Ring @25%, no spin | ghost columns | dimmed troughs |
| Error / no sync | Misregistered J-card + `NO SIG` | Ring in `ctaWarning` + Retry | last-known + stale note | same |
| Partial data (no HR) | `—` in the AVG BPM slot, slot retained | same | n/a | n/a |

**The empty week state costs nothing**: it is the same view with `litCount = 0`, and unlike the
dots it still communicates the week's structure.

Today `DashboardView` simply omits `LastWorkoutCard` when `cachedLastSession == nil`. The
empty state is therefore a **new** surface — it is the first thing a new user sees on the
Dashboard and currently does not exist.

## 5. Accessibility

- Keep both existing combined `accessibilityLabel` strings verbatim.
- Tracklist: each track combines to `"Track 1, running, 12 minutes 4 seconds"`. Bars are
  `.accessibilityHidden(true)`.
- Week columns: one element per day —
  `"Tuesday, 31 minutes"` / `"Wednesday, no workout"`. `.accessibilityValue` carries the duration.
- **Do not** put cassette metaphors in VoiceOver output. "Track"/"SIDE A" are visual only;
  spoken output stays "Interval 1, running".
- Dynamic Type: tracklist rows must stay single-line — use `minimumScaleFactor(0.7)` on the
  duration and truncate the name. At AX3+ drop the bar column entirely (label + duration only).
- Contrast: `textSecondary #8CADCC` on `#030F03` is fine; the 8.5pt `+ N MORE TRACKS` line must
  scale with Dynamic Type — do not hardcode it below 11pt in the shipped version.

## 6. Motion

Appear-only. Segments fill (left→right horizontal, bottom→up vertical) over 0.35s with a 20ms
per-index stagger, then completely static. `accessibilityReduceMotion` → jump to final state.
No loops on the Dashboard — it is the most-opened screen in the app.

---

## Implementation hand-off

- **Files to create:** `ShuttlX/Theme/Components/SegmentBar.swift`; `ShuttlX/Views/Dashboard/LastWorkoutCardStyles.swift`; `ShuttlX/Views/Dashboard/WeekSummaryCardStyles.swift`
- **Files to modify:** `ShuttlX/Views/Dashboard/LastWorkoutCard.swift` (→ dispatcher); `ShuttlX/Views/Dashboard/WeekSummaryCard.swift` (→ dispatcher, keep all data computation); `ShuttlX/Theme/ThemeModifiers.swift` (`showHubs:false`; delete `ReelCounterView` after auditing `headerLabel:` callers); `ShuttlX/Views/DashboardView.swift` (render the empty-state card instead of omitting it when `cachedLastSession == nil`)
- **Reuse existing:** `TrainingSession.segments` / `ActivitySegment` (no model change); `FormattingUtils.*`; `ShuttlXColor.forStepType` + activity colours; `theme.effects.cardCornerRadius`; `PressScaleButtonStyle`; the existing `weekDays` computation
- **Theme variants verified:** 2 themes exist — Clean and Mixtape both fully specified for populated / empty / loading / error / partial. `SegmentBar` is the per-theme extension point (discrete LCD segments vs continuous glass bar) if a theme is revived. **New files under `ShuttlX/` require explicit pbxproj registration.**
- **Watch performance check:** N/A — iOS only. No watch or `WCSession` impact; both cards read already-synced `TrainingSession` data.
- **Open questions for dev:**
  1. **Is `ReelCounterView` safe to delete?** Audit every `.themedCard(headerLabel:)` caller — some may rely on the header/footer strip.
  2. Track cap: 3 + "N more" is my proposal. Should it be 4 on larger devices, or duration-driven?
  3. Gym-recovery sessions — do `segments` map cleanly to stations, or is a separate track-naming rule needed? (`RecoverySegmenter` may already answer this.)
  4. Weekly goal threshold for the amber caps — does a user goal exist, or should it be derived (e.g. 7-day trailing mean)? If neither, ship green-only and add amber later.
  5. `SegmentBar` lives in `ShuttlX/Theme/Components/` — if the watch should share the API, it must be duplicated per target like every other theme file (or moved to `ShuttlXShared`, but it is a SwiftUI view, so per-target duplication matches existing convention).
