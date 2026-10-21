# Timeline redesign plan (October 2026)

Status: approved by the owner on 2026-10-20 (answers to the review page). Step status as of 2026-10-21, checked against the code at HEAD 02779c3 (the v1.9.0 → v1.10.0 range, 50f9061..02779c3). Device behaviour is marked unverified where it has not been tested on hardware. Nothing is pushed without the owner's approval.

Design reference: the published review page "ShuttlX Timeline Design" (private artifact https://claude.ai/artifact/DULM5WKtR7rZo5GAk7N9Aa). Sample data only.

## Owner decisions

- Base concept is Timeline. Route Home becomes the Map mode of the History tab, showing the trainings of the selected period on Apple Maps.
- Four tabs: Today, History, Trends, Settings. History holds a calendar, a list and a map as three modes of one segmented control; the map follows the selected period (changed 2026-10-20 from a separate Map tab). Programs and Plans become a row on Today. There is no Plans tab.
- "Same route · 4×" stays in the Map mode.
- Zone words EASY / STEADY / HARD, with cut-offs at 70% and 90% of the heart limit.
- The beta-blocker question is asked in onboarding for everyone. "Not sure" is treated as "Yes".
- Auto-pause after 60 s without heart rate and without motion. Both devices get a notification that the session was paused for no motion.
- Alerts: heart rate above the limit, heart rate below the low limit, signal lost, no motion. The sudden-jump alert is dropped. **Code check (2026-10-21):** the sudden-jump check is still in the code (see Open items).
- AirPods Pro 3 is built behind `#available(iOS 26, *)`. The owner tests it on a physical device.
- Run versus walk is a suggestion the user can fix. Cycling versus on-foot is automatic.

## What the research limits (see the Feasibility table on the page)

- A saved HKWorkout cannot be edited, and walking is not a leg type of Apple's multisport workout. ShuttlX keeps its own segments and the Health workout stays one type.
- There is no public real-time wrist-detection API. Auto-pause is a heuristic.
- How AirPods heart rate reaches the app live is unverified until the owner's device test.
- `CMMotionActivityManager` is documented for watchOS 2+, but its live behaviour on a watch is unverified.

## Steps

1. **Design tokens, DayRibbon, session detail redesign.** Display only, built on existing segments and routes. No new logic. Files: `ShuttlX/Components/DayRibbon.swift`; `SessionDetailView.swift`; pbxproj registration. **Status: done** (d0bd86c). `ActivityRibbon` and `SessionPartRow` are in DayRibbon.swift. The design tokens were not checked separately. Session detail later gained the HR chart (SessionHeartRateLoader, 583b787) and Fix a part split/merge (583b787, 75f1900).
2. **History tab.** `HistoryView` (calendar / list / map) replacing `TrainingHistoryView`; `HistoryMapView` reusing the polyline code from `RouteMapView`, activity filter chips, session sheet, "Same route" list. **Status: done** (8e5178e, rebuilt in 26c8fbc). `TrainingHistoryView`, `LastWorkoutCard` and `PlanProgressCard` are deleted. Map following the selected period is unverified on device.
3. **Today timeline and four tabs.** Replaces the Training tab; Programs/Plans become a row; live card with Pause and End & Save. **Status: done** (0e46a76, rebuilt in 4d0e64e). The Today live card (`LiveWorkoutCard`) has Pause/Resume and "End & Save" (with confirmation). Programs is a row on Today (`DashboardView` → `ProgramsTabView`).
4. **Classifier, Fix a part sheet, overrides store, watch auto-switch.** The new logic. Needs real sessions to tune. **Status: done in code** (4a: 2485419; 4b watch GPS auto-switch: cc76484). Fix a part is now `FixPartSheet` (type, Split, Merge, scrubber) backed by `SegmentEdits` (v2 envelope). Threshold tuning on real sessions: not done.
5. **Presence monitor, auto-pause, alerts, Live Activity buttons.** Watch raises alerts; the phone mirrors them. Device test with the watch off the wrist. **Status: done in code** (2932557, 88fbdcd). Device test: not done, unverified. The phone's pause reason is inferred from the `noMotion` heartAlert (PhoneSyncCoordinator sets `livePauseReason`). No separate field is sent. *Inferred.* The `suddenJump` alert is still emitted (see Open items).
6. **Onboarding (beta-blocker, heart limit, low limit) and "Heart & alerts" settings; AirPods Pro 3 source. **Status: partial** (344ec5e, rebuilt in 499f203). Done: onboarding beta-blocker question, low limit, "Heart & alerts" screen (`HeartAlertsView`, nav title "Heart & alerts", reached from Settings → Heart). AirPods Pro 3: the source row is gated with `#available(iOS 26, *)` and sets only the `useAirPodsHeartRate` intent flag. There is no runtime path that reads AirPods heart rate. Unverified until a device test.**
7. **Watch one-word screen, heart-limit mode, effort prompt.** **Status: done in code** (97ac4ca): EASY / STEADY / HARD zone word, "Ease off — HR high" banner, post-workout effort (`EffortView`, sent via `updateSessionEffort`; iOS applies it by id or parks it in `PendingSessionEffort`). Device behaviour unverified.
8. **Settings cut and Trends trim.** **Status: done** (3358fc2, 75f1900, 26c8fbc). Settings cut: Exercise Devices and the theme preview are removed; Account is kept as a section that shows only while signed in (75f1900). Debug is behind a 1 s long-press on About. `DeviceListView` has no entry point in code now. Trends trim: done. `TrendsOverview` is a Week / Month / Year hero (see Open items for past periods).

Step 4a status (committed as 2485419): done on shared + iOS. `DetectedActivity.cycling`; `Shared/ActivityClassifier.swift` (`SpeedActivityClassifier`, pure, with 30 s / 60 s hysteresis; tests in `ActivityClassifierTests`); iOS `SegmentOverrideStore` (`segment_overrides.json`) and the "Fix a part" sheet in `SessionDetailView`. Step 4b (watch auto-switch, cc76484) is done. Not done: tuning thresholds on real sessions.

## Rules for every step

- Build both schemes after each change. Never pass `-sdk` to xcodebuild.
- New views use `ShuttlXFont` and `ShuttlXColor` only, and `.themedCard()` where cards remain. Clean is the only theme (`ThemeID.valid`); new views must render under it.
- iOS files need explicit pbxproj registration. Watch files are picked up by the synchronized folder.
- Update `HelpView` and the docs when a user-facing flow changes.
- The medication answer is health data: device only, never sent to TelemetryDeck or written to Health metadata.

## Open items

- **AirPods Pro 3 runtime path**: not built. Only the `useAirPodsHeartRate` intent flag exists. Needs the owner's device test first.
- **Trends past periods**: not built. Week / Month / Year show the current period only; there is no navigation to earlier periods.
- **Widgets read raw `sessions.json`**: `ShuttlX/Services/WidgetDataProvider.swift` reads the stored file, not `DataManager.effectiveSessions`, so Fix a part edits do not reach the iOS widgets.
- **No reset-to-detected**: a Fix a part correction cannot be reverted to the detected segments (no code path).
- **Dynamic Island**: the expanded, compact and minimal regions are defined in `ShuttlXLiveActivity/ShuttlXLiveActivity.swift`. Rendering on a device is not verified.
- **Sudden-jump alert (owner decision needed)**: the plan says it is dropped, but the code still emits it: `HeartAlertEvaluator` (`.suddenJump`, default on), the watch `UnusualHeartRateView` overlay, and a default-on "Sudden jump (+40 bpm in 10 s)" toggle in `HeartAlertsView`. Either remove it in code or change this plan.
- **Device tests pending**: no-motion pause with the watch off the wrist; GPS cycling switch thresholds; heart alerts end to end; Live Activity; the History map following the selected period; AirPods Pro 3 heart rate.
- A numeric default for the low heart-rate limit. Suggest: off until the user sets it, asked as an optional field next to the upper limit. **Code:** `lowLimit` is nil (off) by default, shown as "Off" in Settings. Owner confirmation pending.
