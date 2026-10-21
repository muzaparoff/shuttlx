# Device test checklist — v1.10.0

Install v1.10.0 from TestFlight on the iPhone and the paired Apple Watch. Mark each line pass / fail and note what you saw. Everything here is untested on hardware.

## 1. First launch and onboarding (iPhone)
- [ ] Onboarding has three steps and ends on Today.
- [ ] The beta-blocker question appears. Answer once with "Yes", then repeat on a fresh install with "No".
- [ ] Health permission sheet appears once and is accepted.
- [ ] Settings → Heart & alerts shows the limit and a "Low limit: Off" default.

## 2. Free run on the watch (outdoor, 15+ minutes)
- [ ] Home shows the green Start circle and a Programs row.
- [ ] Running page: tag, clock, one zone word, thin bar, red BPM. No clipping, page dots clear.
- [ ] Swipe left: distance, pace, calories. Swipe right: Pause and End.
- [ ] Walk, then run: the tag switches and the Undo toast appears for about 4 s. Tap Undo: the previous activity returns and does not flip back for about a minute.
- [ ] Ride a bike for 2+ minutes: tag switches to CYCLE. Stop and walk: it returns to on-foot.
- [ ] With no limit set, the "Ease off — HR high" banner only shows when the word says HARD.
- [ ] Set a limit near your working HR: heart-limit mode appears at 90% of it, with a haptic.
- [ ] Digit and word colours agree (note any mismatch).

## 3. Alerts and auto-pause
- [ ] Above-limit alert: haptic on the watch, notification on the phone.
- [ ] Take the watch off the wrist, still running: after about 60 s the workout pauses with "No heart rate" and the phone shows "Paused – no motion".
- [ ] Put it back on and resume.
- [ ] Unusual heart rate screen: note whether it appears on a sudden jump.

## 4. Finish and summary
- [ ] End shows the confirm step, then the summary with the ribbon and "Saved to Health ✓".
- [ ] Done opens the effort screen. Turn the Digital Crown from 0 to 10, tap Save.
- [ ] The phone shows the effort on that session within a minute. Repeat once with the phone out of range and check it arrives later.
- [ ] Deny Health write access once and check the summary shows "Not saved to Health".

## 5. Session on the iPhone
- [ ] The session appears on Today and History with the right parts.
- [ ] Session detail shows the heart-rate chart with a real line and sensible start, end, average and peak. Check it hides when Health access is off.
- [ ] Fix a part: change a part to Rest, split a part by dragging the scrubber, merge two parts, then check Today totals and Trends follow.
- [ ] Rest part shows zero calories.
- [ ] History map: all three rows visible, km labels on the selected route, tap a route to open details.

## 6. Live Activity and Dynamic Island
- [ ] Lock the phone during a workout: card shows state, timer, HR, ribbon.
- [ ] Pause and End & Save buttons work from the lock screen, including after a cold launch of the app.
- [ ] Dynamic Island compact and expanded views look right (never rendered before).

## 7. Settings and account
- [ ] Settings order matches the mockup. Version long-press opens Debug.
- [ ] If still signed in: Account section shows Sign Out and Delete Account. Test Sign Out. Test Delete Account only on a throwaway account.
- [ ] Help has the Fix a part topic.

## 8. Other
- [ ] Imported Health sessions do not trigger the rating prompt.
- [ ] Tap `shuttlx://last-workout` (Notes link or Safari) and check it opens the latest session.
- [ ] AirPods Pro 3 as heart-rate source: record whether the toggle changes anything (runtime path not built yet).
- [ ] Widgets: note whether Fix a part edits show (expected: they do not).
