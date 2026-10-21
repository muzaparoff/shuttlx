# Device test checklist — v1.10.1

Covers the checks that the simulator and the e2e suites (`e2e/`: smoke, workout10, discard) cannot reach. Install v1.10.1 on the iPhone and the paired Apple Watch. Mark each line pass / fail and note what you saw. Everything here is untested on hardware. The general walk-through in `docs/device-test-checklist-v1.10.md` still applies.

## 1. Heart alerts (real heart rate)

- [ ] Set a heart limit a few beats above your resting rate. Stand still until it is exceeded: the watch gives a haptic, the phone gets a notification. Note the delay in seconds.
- [ ] Set the low limit above your current rate: a below-low alert fires after about 30 s and not before.
- [ ] Take the watch off or cover the sensor for 30 s while running: "signal lost" fires once, then repeats no more often than every 2 min.
- [ ] Sudden jump is OFF by default. Turn it on in Settings → Heart & alerts, then do a quick effort (for example 10 jumping jacks) and note whether one "Check your heart rate" screen appears, and whether a single spike of the sensor triggers it. Turn it off again.
- [ ] Paused, above the limit: the alert repeats about once a minute and stops after you lower the heart rate.

## 2. Off-wrist auto-pause (outdoor run)

- [ ] Start a free run on the watch and run for 2 min with heart rate and motion.
- [ ] Take the watch off and put it on a table, still running. Record the time until the workout pauses (expected about 60 s, reason "No heart rate").
- [ ] The phone shows "Paused – no motion" in the Live Activity within a few seconds of the pause.
- [ ] Put the watch back on and tap Resume on the watch. The workout continues; the pause does not repeat at once.
- [ ] Repeat with an indoor elliptical or cycling session: it must NOT auto-pause (no motion sensing for those).

## 3. Phone-started workout: start handshake and Discard

- [ ] With the watch app in the foreground at the Home screen, start a workout on the iPhone (Today → start). The iPhone timer shows "watch linked" within about 5 s. Repeat with the watch asleep: the link can arrive later, and the timer must still update to linked.
- [ ] While a watch workout is already running, start a workout on the iPhone. The iPhone shows the notice "Your watch did not start this workout…". Check the watch workout is untouched.
- [ ] Start a phone workout (watch linked), then tap Discard on the iPhone. The watch ends the workout WITHOUT a summary and without a Health entry: check the Health app has no new workout for it.
- [ ] Start a watch-only workout (not from the iPhone), then tap Discard on the iPhone while the phone workout is not linked. The watch workout must keep running.
- [ ] Discard while the watch is out of Bluetooth range of the phone (watch linked, sendMessage fails). Bring the watch back into range and check the watch did not keep recording. Note how long the late Discard took to apply.
- [ ] Stop on the phone with the watch linked: the watch saves and the phone shows one session, not two (watch copy replaces the placeholder).

## 4. Slow walk after cycling (GPS activity switch)

- [ ] Ride a bike outdoors for 3 min. The tag shows CYCLE.
- [ ] Get off and walk slowly (about 3 km/h, stop-and-go is fine) for 2 min. Note when the tag returns to WALK. Expected: within about 60 s after the walking starts, because the step cadence or CoreMotion gives on-foot evidence.
- [ ] Stop at a red light on the bike for 30 s. The tag must stay CYCLE.
- [ ] Note any Undo toast mismatch and the time it appeared.

## 5. Live Activity buttons

- [ ] Watch-started workout: lock the phone, tap Pause and Resume on the Live Activity. Check the watch follows each time.
- [ ] Watch-started workout: tap End & Save from the lock screen. Check the session appears on the iPhone once.
- [ ] Phone-only workout (no watch, or watch not linked): tap Pause, Resume and End & Save on the Live Activity. Each must act on the phone workout.
- [ ] Force-quit the app during a phone workout, then tap a Live Activity button (cold launch). Check the control works and the button is not dead.
- [ ] Dynamic Island compact and expanded views (never rendered on device before): note clipping or missing values.

## 6. Delete Account and Keychain medication notes

Use a throwaway account only (still signed in from an earlier build).

- [ ] Before deleting: set the medicine name and daily dose in Settings → Heart & alerts. Note they are shown.
- [ ] Settings → Account → Delete Account, confirm. The local sessions are gone, the Account section disappears, and the app returns to the start state.
- [ ] Reinstall (delete the app, install again from TestFlight) and open Settings → Heart & alerts: the medicine name and dose must be empty. A Keychain item that survives the delete is a failure.
- [ ] Heart-limit notes stay off the watch: the watch limit still works after the wipe.

## 7. Watch checkpoint recovery

- [ ] Start a free run on the watch and run for 3 min. Force-quit the watch app (hold the side button, or kill it from the Dock).
- [ ] Reopen the app. The workout RESUMES with the same elapsed time, not from zero. Note the elapsed time gap and whether the segments are kept.
- [ ] Pause before the kill, force-quit, reopen: the workout comes back paused with the reason kept (no motion or manual).
- [ ] Finish the resumed workout. The summary and the Health entry show one workout with the full duration.

## 8. Route in Health

- [ ] Finish an outdoor watch workout with GPS, then open the Health app → Workouts → the workout. Note whether a map of the route appears (`HKWorkoutRoute`).
- [ ] Watch logs: "HKWorkoutRoute saved" (Console app, watch) rather than "Failed to finalize route".
- [ ] The phone's History map shows the same route.

## 9. Widgets and Fix a part

- [ ] On the iPhone: open a session, Fix a part (change one part to Rest). Wait a few seconds.
- [ ] Check the Small or Medium widget shows the edited totals (expected now: they do, since `WidgetDataProvider` applies `segment_overrides.json`). Record what the widget shows if it does not.
- [ ] Rest part shows zero calories in the widget totals.
- [ ] Widget refresh after the edit: note how long it takes to show the new totals.

## 10. Other checks left from v1.10.0

- [ ] Imported Health sessions do not trigger the rating prompt.
- [ ] AirPods Pro 3 heart-rate source: record whether the toggle changes anything (runtime path not built yet).
- [ ] History map: the three modes, km labels, tap a route to open details.
