# Timeline redesign plan (October 2026)

Status: approved by the owner on 2026-10-20 (answers to the review page). Step 1 is cleared to start. Steps 2 and later each need the owner's go-ahead before work begins. Nothing is committed or pushed without the owner's approval.

Design reference: the published review page "ShuttlX Timeline Design" (private artifact https://claude.ai/artifact/DULM5WKtR7rZo5GAk7N9Aa). Sample data only.

## Owner decisions

- Base concept is Timeline. Route Home becomes the Map mode of the History tab, showing the trainings of the selected period on Apple Maps.
- Four tabs: Today, History, Trends, Settings. History holds a calendar, a list and a map as three modes of one segmented control; the map follows the selected period (changed 2026-10-20 from a separate Map tab). Programs and Plans become a row on Today. There is no Plans tab.
- "Same route · 4×" stays in the Map mode.
- Zone words EASY / STEADY / HARD, with cut-offs at 70% and 90% of the heart limit.
- The beta-blocker question is asked in onboarding for everyone. "Not sure" is treated as "Yes".
- Auto-pause after 60 s without heart rate and without motion. Both devices get a notification that the session was paused for no motion.
- Alerts: heart rate above the limit, heart rate below the low limit, signal lost, no motion. The sudden-jump alert is dropped.
- AirPods Pro 3 is built behind `#available(iOS 26, *)`. The owner tests it on a physical device.
- Run versus walk is a suggestion the user can fix. Cycling versus on-foot is automatic.

## What the research limits (see the Feasibility table on the page)

- A saved HKWorkout cannot be edited, and walking is not a leg type of Apple's multisport workout. ShuttlX keeps its own segments and the Health workout stays one type.
- There is no public real-time wrist-detection API. Auto-pause is a heuristic.
- How AirPods heart rate reaches the app live is unverified until the owner's device test.
- `CMMotionActivityManager` is documented for watchOS 2+, but its live behaviour on a watch is unverified.

## Steps

1. **Design tokens, DayRibbon, session detail redesign.** Display only, built on existing segments and routes. No new logic. Files: new `ShuttlX/Components/DayRibbon.swift` (done); `SessionDetailView.swift`; pbxproj registration.
2. **History tab.** `HistoryView` (calendar / list / map) replacing `TrainingHistoryView`; `HistoryMapView` reusing the polyline code from `RouteMapView`, activity filter chips, session sheet, "Same route" list.
3. **Today timeline and four tabs.** Replaces the Training tab; Programs/Plans become a row; live card with Pause and End & Save.
4. **Classifier, Fix a part sheet, overrides store, watch auto-switch.** The new logic. Needs real sessions to tune.
5. **Presence monitor, auto-pause, alerts, Live Activity buttons.** Watch raises alerts; the phone mirrors them. Device test with the watch off the wrist.
6. **Onboarding (beta-blocker, heart limit, low limit) and "Heart & alerts" settings; AirPods Pro 3 source.**
7. **Watch one-word screen, heart-limit mode, effort prompt.**
8. **Settings cut and Trends trim.**

## Rules for every step

- Build both schemes after each change. Never pass `-sdk` to xcodebuild.
- New views use `ShuttlXFont` and `ShuttlXColor` only, and `.themedCard()` where cards remain. Both themes (Clean, Mixtape) must still render.
- iOS files need explicit pbxproj registration. Watch files are picked up by the synchronized folder.
- Update `HelpView` and the docs when a user-facing flow changes.
- The medication answer is health data: device only, never sent to TelemetryDeck or written to Health metadata.

## Open items

- A numeric default for the low heart-rate limit. Suggest: off until the user sets it, asked as an optional field next to the upper limit.
