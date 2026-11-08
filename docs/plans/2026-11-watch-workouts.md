# Watch workouts: gym recovery on the watch, Workout page, guided rest (Nov 2026)

Review page: https://claude.ai/artifact/RKT2Etu2PD8Us2c67atSKS (audit + mockups, 8 Nov 2026).

## Owner decisions (2026-11-08, "all recommended picks")

1. Gym entry: first row inside "Mixed": heart icon, "Heart Recovery", subtitle "Sets with rest checks". Home unchanged.
2. Run/walk pages: Controls | Workout | More, opening on Workout. Same order (Controls left of the main page) in interval and gym modes.
3. Workout page hero: total time; the part timer ("RUN 4:12") sits under it.
4. Bugs:
   - B1 (gym page has no safety cues, fixed 185 max HR): option 2. Zone word from `resolvedHeartLimit`, "Ease off" and no-HR banners on the gym page, and the heart-limit page takes over the gym page at 90 % of the limit, as in free run.
   - B2 (phone-tapped gym sets probably lost, unverified): reproduce first, then option 1 (while linked, the phone's set buttons send the tap to the watch; the watch keeps the record).
   - B3 (crash resume restarts the set count): option 1, restore the set number from the saved captures.
   - B4 (double haptic per Start/End tap): option 1, remove the view's haptic.
   - B5 (pause around 60 s skips the 1 min drop): option 1, take the reading at the first tick after 57 s.
5. Wording: "Station" becomes "Set" on the watch. "Mixed" stays.
6. Scope: all steps, in the order below.

Blood oxygen: not built (no third-party live API; see the review page).

## Steps

| # | Step | Size | Ships with |
|---|------|------|-----------|
| 1 | Gym safety fix: B1 option 2 + B4, 44 pt gym button, solved sizes in `RecoveryWorkoutView`, "Station" -> "Set" | S-M | first build |
| 2 | Gym on the watch: Heart Recovery row in `ProgramsListView`, empty-list and Health-denied texts | S | first build |
| 3 | Run/walk Workout page + page order, together with Wave 5 C2c (`@Observable`, split pages) | M | Wave 5 build 2 |
| 4 | Guided rest: `Shared/RestGuidance.swift` (pure, tested), rest target, "Down N in 1 min", "Settled", last sets; B3, B5 | M | later build |
| 5 | Recovery data shown: watch summary SETS list, iPhone session-detail recovery card | S + M | later build |
| 6 | B2: reproduce with a linked phone + watch, then option 1 | S-M | later build |

## Status (2026-11-08)

- Steps 1 and 2: implemented, **uncommitted** (`git diff -- "ShuttlX Watch App"`). Not device-tested.
  - Step 1: B1 option 2 (zone word, "Ease off" / no-HR banners and heart-limit page on the gym page), B4 (view haptic removed; the set event plays `.click` / `.stop`), 44 pt set button, solved sizes, "Station" -> "Set".
  - Step 2: Heart Recovery row first in `ProgramsListView` (Mixed); empty-list text "Add interval programs on your iPhone."; Health-denied text "Allow Health access in the Health app on your iPhone." (`ProgramSelectionView.swift:25`).
- Unverified on device: B4 tap path (one buzz per tap) and the wrist feel of `.click` / `.stop`.
- Banner-width bug (found 2026-11-08, owner picked option 1): `noHeartRateBanner` (`Views/TrainingView+Metrics.swift`) used `HStack { Spacer(); ...; Spacer() }`; the default spacer minimum widened the page on 40 mm and 46 mm (side margins about 4 pt instead of 10). Fixed with `Spacer(minLength: 0)`.

Rules that bind every step: part timer never `@Published` per second (1 Hz isolation); sizes solved, never scaled; HR and safety banners never leave the screen (snapshot 40 mm + 46 mm); wording describes, never diagnoses (no "good", "recovered", "abnormal", no green/red grading of the drop).
