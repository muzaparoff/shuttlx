# UX/UI Audit — ShuttlX — 2026-04-25

Audit scope: iOS 18+ / watchOS 11.5+. Read-only. All findings cite specific file and line numbers verified by reading source.

---

## Finding 1 — HIGH INTENSITY warning uses athlete framing incompatible with cardiac rehab

**Severity: P0**
**File: `ShuttlX Watch App/Views/TrainingView.swift:369-383`; `ShuttlX Watch App/Models/HeartRateZoneCalculator.swift:27-28, 97-104`**
**Confidence: High**

The watch fires "HIGH INTENSITY" (all-caps red text, `.notification` haptic) when heart rate exceeds 85% of estimated max HR. The threshold is hardcoded at `static let highIntensityThreshold: Double = 0.85`. For a post-cardiac-event patient, 85% is far above the safe ceiling that most cardiac-rehab protocols set (typically 60-75% HRmax, depending on phase). The Tanaka fallback maxHR of 190 BPM applies when no age is entered, making the effective warning threshold 161 BPM — dangerously late for a 65-year-old with a true max HR of 140.

The word choice matters too. "HIGH INTENSITY" reads as a performance badge to an athlete; to a cardiac patient it should communicate "slow down immediately." There is no accompanying instruction, no colour differentiation from other warning text, and no second haptic escalation if the user ignores the first.

Additionally, `AnalyticsEngine.RecoveryStatus` raw values of "Overreaching" (`ShuttlX/Services/AnalyticsEngine.swift:37`) are rendered verbatim on screen (`AnalyticsView.swift:99`). "Overreaching" is sports-science jargon that means "you trained too hard this week" — to a cardiac patient it may read as a medical accusation or cause anxiety about their condition.

**User impact:** A patient who has not entered their age gets a 190 BPM fallback maxHR, so no warning fires until ~161 BPM. A 70-year-old cardiac patient's actual physiological max is likely 140-150 BPM. The safety net has a hole large enough to drive through.

**Fix direction:**
- Lower the default watch warning threshold to 70% and provide a clearly labelled per-user override in Settings, scoped to a "cardiac / general / performance" mode.
- Replace "HIGH INTENSITY" copy with "Heart rate high — ease off" or equivalent language that provides direction.
- Replace `RecoveryStatus.overreaching` raw display value with "Rest needed" or "Reduce load."
- Force the age-entry field in onboarding (currently optional) or prompt inline when a workout starts without age data.

---

## Finding 2 — iOS Dashboard has no path to start a workout from iPhone

**Severity: P1**
**File: `ShuttlX/Views/Dashboard/StartOnWatchCard.swift:13-39`; `ShuttlX Watch App/ShuttlXWatchApp.swift:32-36`**
**Confidence: High**

`StartOnWatchCard` shows status ("Ready" or "Not reachable") but has no action button. There is no way to initiate a workout from the iPhone side at all — the card only renders a status pill. The cardiac-rehab use case requires the patient to pick up their phone, not just glance at their wrist.

**User impact:** Patients who follow iOS-first onboarding have no path to start a workout from the phone. They see a connectivity status card with no actionable next step.

**Fix direction:** Add a tappable affordance on `StartOnWatchCard` that sends a `shuttlx://start-workout` deep link to the watch (the watch app already handles this deep link at `ShuttlXWatchApp.swift:32-36`). Gate the button on `isReachable`. When not reachable, show a "Open Watch app" instructional label instead.

---

## Finding 3 — Onboarding tone is athlete-first, unsuitable for cardiac rehab

**Severity: P1**
**File: `ShuttlX/Views/OnboardingView.swift:26-58, 115-162`**
**Confidence: High**

Welcome page headline: "Welcome to ShuttlX." Subtitle: "Auto-detect running and walking with your Apple Watch." Hero icon: `figure.run`. Page 3 CTA: "Start Training."

This framing is that of a performance app for active users. A post-cardiac-event patient discharged with a "start a rehabilitation walking programme" instruction will encounter a running silhouette and "start training" language before they have seen anything that acknowledges their situation, establishes trust, or sets expectations for a gentle start.

Additionally, no skip path for patients who are iPhone-only (no watch). When the watch is not paired, page 3 shows two red `xmark.circle` status rows but offers no alternative — the "Start Training" button still appears (`OnboardingView.swift:151-158`), implying the app is watch-dependent.

**User impact:** Cardiac patients handed this app at discharge will see iconography and copy that signals "performance training," not "rehabilitation." Trust is established or lost in the first three screens.

**Fix direction:**
- Change welcome headline/subtitle to something like "Move at your own pace" or "Your heart rate, your guide."
- Replace the hero `figure.run` icon with `figure.walk` or `heart.circle` on the welcome page.
- Change "Start Training" to "Begin" or "Start your programme."
- On page 3, when watch is not paired, branch to an "iPhone-only mode" path rather than showing red failure states.

---

## Finding 4 — VU Meter theme: amber `textPrimary` collapses semantic contrast

**Severity: P1**
**File: `ShuttlX/Theme/Themes/VUMeterTheme.swift:49`**
**Confidence: High**

`textPrimary` in VU Meter is `Color(red: 0.91, green: 0.63, blue: 0.19)` — the same amber used for `ctaPrimary`, `ctaWarning`, `walking`, `steps`, `calories`, `pace`, and `textPrimary`. This is `#E8A030` on a background of `#1A1610`.

The WCAG 2.1 contrast ratio for `#E8A030` on `#1A1610` is approximately 7.2:1 — passes AA. However, because `textPrimary`, `ctaPrimary`, `ctaWarning`, `walking`, and `steps` all resolve to the same amber value, there is no contrast between semantic status values and plain body text. A warning reads visually identically to a label.

During exercise with sweaty hands — where the user is squinting at the screen — semantic colour distinction is a safety signal, not decoration. In VU Meter, "HIGH INTENSITY" warning text rendered in `ShuttlXColor.ctaDestructive` (`#CC4444`) is readable, but the surrounding metric labels in `textPrimary` amber create ambient visual noise that dilutes the warning's pop.

**User impact:** On the watch mid-workout, metric display rows (TIME, HR, DIST, PACE) use `textSecondary` for labels and `textPrimary` for values. In VU Meter, values render in amber and labels in `#948060`. Luminance difference between label and value is small (~2:1).

**Fix direction:** In `VUMeterTheme.swift`, change `textPrimary` to a near-white or high-luminance cream (`#F5E8C8` or similar) to restore the label/value contrast. Reserve amber for semantic accents only. This mirrors what Classic Radio does correctly with its `textPrimary: #F5E6C8` cream against its dark brown background.

---

## Finding 5 — Settings: destructive operation directly below theme picker

**Severity: P2**
**File: `ShuttlX/ContentView.swift:43-49`; `ShuttlX/Views/SettingsView.swift:299-353, 421`**
**Confidence: High**

Theme selection lives in Settings inside the root TabView. Theme switching navigation is fine for an infrequent action. The pressing concern is "Clear All Training Sessions" with role `.destructive` at `SettingsView.swift:421` — a red-destructive button that sits below the theme picker without a divider or visual separation. A user scrolling down to preview themes could accidentally finger-tap it.

**User impact:** Misfire risk for users with reduced fine motor control.

**Fix direction:** Move destructive data management operations ("Clear All Training Sessions", "Delete Account") to a separate "Danger Zone" section with full-width section label, ideally at the bottom of the list. Consider a toggle-reveal pattern. Surface theme switching earlier in the list, above Body Metrics.

---

## Finding 6 — Watch metric font scaling falls below 40pt on 40mm hardware

**Severity: P2**
**File: `ShuttlX Watch App/Views/TrainingView.swift:137-139, 198-212`**
**Confidence: High**

The watch workout display tab computes font size as a percentage of screen height: `let valueSize = max(20, h * 0.19)`.

- 44mm Apple Watch (~224pt): `valueSize ≈ 42.6pt` — above 40pt minimum.
- 41mm Series 9 (~215pt): `valueSize ≈ 40.9pt` — borderline.
- 40mm Series 6 / SE (~197pt): `valueSize ≈ 37.4pt` — below 40pt.

The `max(20, ...)` floor prevents collapse but only at the extreme low end. Same scaling applies to all metric rows — HR, distance, pace.

**User impact:** Older, smaller Apple Watch hardware — common in the 55+ demographic — will show metrics below the spec minimum.

**Fix direction:** Change `max(20, h * 0.19)` to `max(40, h * 0.19)` for the watch timer/metric `valueSize`.

---

## Finding 7 — Post-workout summary has no clinician-readable export; interval HR data is buried

**Severity: P2**
**File: `ShuttlX Watch App/Views/TrainingView.swift:424-523` (WorkoutSummaryView); `ShuttlX/Views/IntervalResultsView.swift:1-136`; `ShuttlX/Views/SessionDetailView.swift:1-80`**
**Confidence: Medium**

Neither watch nor iOS summary view has an export, share, or print affordance. `IntervalResultsView` on iOS shows average HR per interval segment — the most clinically relevant data point for cardiac rehab — but is only accessible by navigating into a specific session and scrolling.

For the cardiac-rehab roadmap, a clinician reviewing compliance between appointments needs a compact, portable summary. Currently there is no path: no PDF export, no share sheet, no structured text summary.

`WorkoutSummaryView` (watch) shows a "Workout Complete" hero badge animation. The animation is gated on `reduceMotion` correctly, but the celebratory framing is performance-athlete oriented. A quieter "Well done, session saved" with HR zone summary would be more appropriate.

**Fix direction:**
- Add a share button to `SessionDetailView` that produces a plain-text or PDF export of: date, duration, average HR, HR zone distribution by time, interval HR data if available.
- On the watch `WorkoutSummaryView`, add average HR zone as a labelled metric row.
- Tone down the completion animation for a non-performance audience.

---

## Finding 8 — Arcade theme: pure-green saturation collapses semantic hierarchy

**Severity: P3**
**File: `ShuttlX/Theme/Themes/ArcadeTheme.swift:13, 22-23`**
**Confidence: High**

Arcade `ctaPrimary` is `#00FF00` pure phosphor green. `running` and `positive` are also `#00FF00`. When `LiveWorkoutCard` shows a pulsing green status dot and the CTA button is also green and the step-work colour is also green, the entire card reads as uniformly green. Combined with the `surfaceBorder` at green opacity 0.5 and CRT scanline overlay, this creates a busy, high-anxiety visual environment for a user with cardiac anxiety.

**Fix direction:** Differentiate `ctaPrimary` from `running` in Arcade — e.g., use cyan for CTA and keep green for running. Add theme-level metadata describing intensity/stimulation level so future UI can suggest "calm" themes (Clean, Classic Radio) to clinical users.

---

## Finding 9 — Body metrics placeholders and unit handling not localised

**Severity: P3**
**File: `ShuttlX/Views/SettingsView.swift:229-296, 253`**
**Confidence: Medium**

Body metrics fields show "Weight (kg)" hardcoded in English. Placeholders ("70" for weight, "30" for age) represent values appropriate for a younger, fitter adult — not a 65-year-old post-cardiac-event patient. `maxHRPlaceholder` is computed from Tanaka using `deviceManager.userAge`, which is correct, but the placeholder shows "190" (fallback) until the user first enters their age, encouraging manual entry of 190.

**User impact:** A patient who skips Body Metrics on first setup leaves with maxHR = fallback 190, which propagates to both watch HR zone display and the high-intensity warning threshold (Finding 1).

**Fix direction:** Display a prominent inline notice: "Accurate heart rate zones require your age. Tap to set." Gate HR zone display on whether a valid age has been entered. Use locale-appropriate weight units via `UnitMass` and `MeasurementFormatter`.

---

## Summary of findings

| # | Severity | Area | File |
|---|----------|------|------|
| 1 | P0 | Cardiac safety: HR warning threshold, language | `TrainingView.swift:369`, `HeartRateZoneCalculator.swift:28` |
| 2 | P1 | Workout-start friction (iOS has no CTA) | `StartOnWatchCard.swift:13`, `ShuttlXWatchApp.swift:32` |
| 3 | P1 | Onboarding tone unsuitable for cardiac patients | `OnboardingView.swift:26` |
| 4 | P1 | VU Meter amber textPrimary collapses semantic contrast | `VUMeterTheme.swift:49` |
| 5 | P2 | Destructive action adjacent to theme picker | `SettingsView.swift:421` |
| 6 | P2 | Watch metric font can fall below 40pt on 40mm | `TrainingView.swift:138` |
| 7 | P2 | Post-workout summary not shareable | `TrainingView.swift:424` |
| 8 | P3 | Arcade pure-green saturation | `ArcadeTheme.swift:22` |
| 9 | P3 | Body metrics placeholders + unit handling | `SettingsView.swift:253` |

---

## What is working well (do not change)

- **Watch control buttons sized correctly** at 64pt diameter (well above 44pt HIG minimum).
- **Always-On Display branch present and correct** — `TrainingView.swift:101-132` strips back to 36pt timer + 22pt HR.
- **`accessibilityReduceMotion` respected throughout** — exemplary.
- **Modal pattern for destructive actions correct** — gated behind `.alert`.
- **Watch tab-swipe for controls discoverable** — correct watchOS pattern.
- **Empty states exist on Analytics** — themed empty state card with clear copy.
