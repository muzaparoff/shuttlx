# Audit follow-up waves (October 2026)

The owner approved every recommended pick on 2026-10-24: the feature review page, the four-part audit page (iOS design, watchOS design, code, algorithms), Simple mode option A, and the model unification plan's recommendations. The work is split into waves so that no two agents edit the same files at once. Every wave ends with both builds, `swift test` and the e2e suites (`smoke,workout10,discard`). Pushing to TestFlight needs the owner's word each time.

Review pages: feature review https://claude.ai/artifact/RgR4dZXNtFUthKSf6vArV7, audit https://claude.ai/artifact/P2wVbUqiEmZkKJUrbZTJzj. Audit sources: the session scratchpad `audit2/` and `research/` notes.

| Wave | Content | Owner | State |
|---|---|---|---|
| 0 | Watch history wipe (C1), even route thinning on the watch, Reset to detected, large-text fixes in Fix a part and the map sheet | watch + iOS | committed 9797791 |
| 1 | Safety and data: strict watch reads made lenient; haptic vocabulary (W2); heart-limit mode hysteresis and wording (W3); above-limit alert needs two fresh samples; zone word without a guessed age; End confirm card (W6); BPM on metrics and controls pages (W1); gym VoiceOver force unwrap; summary haptic on a failed Health save. iOS: even route thinning; labelled timer controls with Discard in a menu (D6); hard-coded 185 replaced by the heart limit; distance fusion that never goes down | watch agent (watch + Shared), iOS agent (ShuttlX/) | committed ad21ce0 |
| 2 | First feature release: Run/Walk and Mixed regroup (feature 1), km/mile split alert and toast (2), unit setting (3), Run/Walk watch metrics page (4), splits table on iPhone and in the watch summary (5), cardio fitness from Health instead of the guessed estimate (18) | watch + iOS | committed (Wave 2) |
| 3 | Simple mode option A; HR chart verdict and limit line (D2); Start card on Today (D3); Trends active-minutes hero (D7); onboarding steps (D8); contrast and run/walk glyphs (D4); locale clock (D5) | iOS (+ watch sync of the switch) | planned |
| 4 | Model unification (Part A, models only) and the widget slim decode, shipped as their own build; then routes in their own files (Part B) with the pre-migration backup kept for one release | architect + iOS + watch | planned |
| 5 | Code health: per-page watch views and @Observable (C2), iOS root re-render (C3), shared interval engine on the watch and an app test target (C4), strict concurrency (C5), background decode (C6), one WatchConnectivity router (C7), ordered watch queue saves (C8) | architect + both | planned |
| 6 | Remaining algorithm picks: least-squares pace, cadence-first run/walk classifier, net-MET calories, time-weighted HR average, HRR averaged over 55-65 s, training load | watch + Shared | planned |

Open questions still with the owner: whether Simple mode is on by default after a beta-blocker "yes", whether the two large-text fixes stay, which Simple mode screens come first, and the social sharing feature (discussed, not approved).
