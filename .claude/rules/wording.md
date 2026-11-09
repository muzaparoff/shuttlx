# Wording Rules (app, Help, store copy)

Positioning line: **"Calm workouts with a heart limit on your wrist."**

- Describe, never diagnose. Say what the number is ("Your heart rate was above your limit for 4 min"), never what it means for the person's health.
- Banned in app strings and in `fastlane/metadata/**`: "cardiac rehab app", "detects" (about the heart or health; activity wording is "finds run and walk by itself"), "abnormal", "safe for your heart", and "good" / "recovered" applied to heart numbers.
- Compare a user only with their own past (last week, last month), never with other people or norms.
- The doctor reminder must stay in Help (Heart limits & alerts) and in the store description: "Talk to your doctor before starting a new exercise plan." Onboarding keeps "Not medical advice. Your doctor knows your safe limit best."
- Limits are the user's or their doctor's; our estimate is "an estimate, not a prescription".
- Chest strap tip (Help): pairing a Bluetooth chest strap with the Apple Watch is suggested for steadier heart rate; do not claim ShuttlX reads it (unverified).
- Check before a release: `grep -rniE "cardiac rehab|detects|abnormal|safe for your heart|recovered" ShuttlX fastlane/metadata`.
