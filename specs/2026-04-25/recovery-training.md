# Recovery Training Mode — Design Spec

**Status:** Design only, no code committed
**Target build:** ShuttlX iOS 18+ / watchOS 11.5+
**Author date:** 2026-04-25
**Owner:** TBD (architect review required)

This spec describes a calm, cardiac-rehab-appropriate Recovery Training mode that combines a watch-driven live heart-rate trace, automatic HR-and-motion segmentation (work / recovery / rest), and Heart Rate Recovery (HRR) measurement at 1 minute and 2 minutes after effort segments. It is grounded in the existing ShuttlX architecture and reuses `WatchWorkoutManager` lifecycle patterns where possible.

This is a **fitness wellness feature**, not a medical device. No diagnostic claims. Cautionary language is deliberate throughout (see section 11).

---

## 1. Apple Platform Constraints (honest accounting)

Before any algorithm or UI: third-party apps cannot do certain things. The spec is built around these limits, not around them.

| Want | Available? | What we do instead |
|---|---|---|
| Live ECG waveform | NO. Apple's `HKElectrocardiogram` is read-only and only after the user records one with Apple's own ECG app. There is no public live-ECG API. | Render a live **heart rate** trace (1 Hz) styled like a clinical chart, but **always labeled "Heart Rate (bpm)"**. Never "ECG", never with a waveform shape that looks like PQRST. |
| Continuous HR > 1 Hz | NO. `HKLiveWorkoutBuilder` typically delivers ~1 Hz HR samples. | Treat HR as 1 Hz. UI is designed for 1-second cadence. |
| Stream prior ECG samples in real time | NO, but we can read them post-hoc via `HKElectrocardiogramQuery` (entitlement required, iOS only). | Surface the most recent ECG sample (classification + average HR) in the post-recovery summary, with deep-link to Health app for the full waveform. |
| Trigger Apple's ECG recording programmatically | NO. | After cooldown ends, the watch shows a soft prompt: "If you'd like, open the ECG app and take a 30-second reading." User-initiated only. |

Constraint that drives the rest of the spec: **the live trace is HR, not ECG, and must be labeled as such everywhere.**

---

## 2. User Flow

### 2.1 Entry (iPhone)

- New tile on the iPhone home screen below the existing "Free Run" card: **"Recovery Training"** with copy "Gentle session with HR recovery check".
- Tapping opens `RecoveryIntroView` (iOS), which shows: a one-paragraph plain-language explanation, current resting HR (last 7-day average from HealthKit), age-derived HRmax (already computed by `HeartRateZoneCalculator`, ref. WatchWorkoutManager.swift:204), and an optional duration picker (default 20 min, range 10-40 min).
- Two buttons: **Start on Watch** (sends a `WCSession` message instructing the watch to enter Recovery mode) and **Settings** (HRR thresholds, see section 4.5).
- If the watch is unreachable: show "Open ShuttlX on your Apple Watch and tap Recovery." The session **must be started on the watch** because all sensor work is watch-side; iPhone is a viewer.

### 2.2 Start (Watch)

- New entry on the watch home screen: **"Recovery"** card, mint-green accent in Clean theme, theme-appropriate accent in others (see section 8.5).
- Tap → `RecoveryStartView` (watch). One large green Start button, 44pt+ touch target. Pre-flight checks displayed as a compact list: HealthKit authorized, motion authorized, optional location off (recovery sessions don't need GPS by default — saves battery and reduces noise; user can enable).
- On Start: `WatchWorkoutManager.startRecoveryWorkout(template:)` (new method, mirrors `startIntervalWorkout` at WatchWorkoutManager.swift:312). Session enters **Warmup** state.

### 2.3 In-Workout (Watch)

Single screen, three rows top-to-bottom:

1. **Phase pill** — "Warmup" / "Work" / "Recovery" / "Rest" / "Cooldown", colored by phase. Centered, 18pt rounded.
2. **HR trace** — Canvas-rendered live HR line, last 60 seconds, with a horizontal target band (see section 6). Labeled "Heart Rate (bpm)" along the top. Current HR value large (40pt monospaced) at right edge.
3. **Phase timer + controls** — elapsed time in current phase (28pt mono), green pause / red stop circular buttons (existing pattern, watchos rule).

A subtle haptic (`.start` for Apple Watch — already used at WatchWorkoutManager.swift:647) marks every phase transition. A second, distinct haptic (`.success`) at the moment of HRR1 capture, and again at HRR2.

### 2.4 In-Workout (iPhone, mirror)

- `RecoveryLiveView` (iOS) shows the same data the watch is broadcasting, plus a wider HR chart (last 5 minutes via `Swift Charts` on iOS — Swift Charts is iOS-only, watchOS uses Canvas). Updates throttled to every 3 seconds via existing live-metrics pipeline (WatchWorkoutManager.swift:538-572). No controls — iPhone view is read-only during a recovery session.

### 2.5 Post-Workout

- On stop: `WatchWorkoutManager.saveWorkoutData()` runs the existing path (WatchWorkoutManager.swift:988) extended to attach a `RecoveryReport` payload to the `TrainingSession`.
- Watch shows a 3-line summary screen: average HR, HRR1 ("HR drop after first minute of recovery: NN bpm"), HRR2.
- iPhone summary screen (`RecoverySummaryView`): full HR chart, all detected segments with phase labels, HRR1 and HRR2 prominently displayed with a one-line interpretation in cautious language ("This is informational, not a diagnosis"), most recent ECG sample if available.

---

## 3. State Machine

States and transitions for one Recovery Training session:

```
[Idle] -- user taps Start --> [Warmup]
[Warmup] -- 5 min elapsed OR user advances --> [Work]
[Work] -- HR sustained > workThresholdBPM for >= 30s --> [Work] (stays)
[Work] -- HR drops below recoveryEntryBPM AND motion drops to walking/stationary for >= debounce --> [Recovery]
[Recovery] -- t = 60s after entry --> capture HRR1, stay in [Recovery]
[Recovery] -- t = 120s after entry --> capture HRR2, transition to [Rest]
[Rest] -- HR rises again above workThresholdBPM AND motion intensity rises --> [Work]
[Rest] -- user taps Cooldown OR scheduled cooldown time reached --> [Cooldown]
[Cooldown] -- 5 min elapsed OR user stops --> [Stopped]
[Stopped] -- saveWorkoutData() --> persist + send to iOS
```

Notes on the machine:

- **Warmup** is a fixed-time low-effort phase, not auto-detected. We do not start measuring HRR until at least one full Work phase has occurred.
- **Recovery** is the HRR measurement window. Once entered, HRR1 is captured at +60s and HRR2 at +120s **regardless of what HR does in between** — the measurement is anchored to clock time, not to HR getting back to a target.
- HRR capture writes to a buffer, not to UI directly; UI reads from the buffer (section 4.4).
- Multiple Work-Recovery cycles in one session are allowed. Each produces its own `HRRMeasurement`. Only the **first** is the "primary" HRR for the session summary; all are stored.
- If user pauses during a Recovery window, that measurement is **invalidated** and discarded (HRR is not meaningful with paused effort). We log a flag and surface "HRR was interrupted — measurement skipped" in the summary.
- Cooldown is fixed-time and does not retrigger Work.
- The state machine lives in a new class `RecoverySessionEngine` (watch-side), parallel to the existing `IntervalEngine` referenced at WatchWorkoutManager.swift:49.

---

## 4. HRR Algorithm

### 4.1 Definitions

- **Peak HR (workPeakHR)**: the maximum HR sample observed during a Work phase, from 10 seconds after Work-entry to the moment Work exits. The 10-second buffer prevents a stale high HR from a previous segment from being captured before the new effort starts.
- **HRR1**: `workPeakHR − HR(at t = recoveryStart + 60s)`
- **HRR2**: `workPeakHR − HR(at t = recoveryStart + 120s)`
- All values in BPM, integer rounded.

### 4.2 Sampling

- Watch HR is delivered by `HKAnchoredObjectQuery` updates (WatchWorkoutManager.swift:775-786). These are typically 1 Hz but can have gaps.
- For HRR capture we want the HR **closest to** t+60s (and t+120s), not the latest. Implementation: maintain a ring buffer of the last 180 seconds of HR samples (timestamp + bpm). At capture time, pick the sample whose timestamp is nearest to the target time within a +/- 3-second window.
- If no sample lies within +/- 3s, capture is **failed**, recorded as `nil`, and the summary shows "Couldn't measure HRR — heart rate data was unavailable for that moment."

### 4.3 Noise / outlier handling

- Single-sample dropouts (e.g., an isolated 0 bpm reading): ignore samples where bpm < 30 or > 220 — these are sensor errors. (Existing code at WatchWorkoutManager.swift:807 already takes the latest BPM blindly; we add a guard for the recovery feature path only.)
- Median-of-3 smoothing for the HRR target value: pick the 3 samples nearest to t+60s (within +/- 5s) and use the median, not the single nearest. This guards against a single beat-detection glitch tanking HRR1 for the user.
- If sustained data loss > 10 seconds during the recovery window, mark the measurement as `qualityFlag = .unreliable` (still saved, but the UI shows a hint).

### 4.4 Attention flag

- If HRR1 is computed and **HRR1 < 12 bpm**, surface an "Attention" pill on the summary view. Copy: "Your heart rate dropped less than 12 bpm in the first minute. This is just one measurement on one day — if you see it repeatedly or it concerns you, mention it to your doctor at your next visit."
- This is **not a diagnosis**. The 12 bpm number comes from epidemiological literature (Cole et al. 1999; widely cited in cardiac rehab). Section 9 calls out that the threshold for THIS user population may need adjustment.
- Never use the words "abnormal", "concerning", "warning", or any clinical term in user-facing copy. Section 11.

### 4.5 User-tunable thresholds (Settings)

- HRR attention threshold (default 12 bpm, range 6-20)
- Work-detection threshold relative to HRmax (default 70%, range 60-85%)
- Recovery-entry threshold relative to HRmax (default 60%, range 50-75%)
- All persisted to App Group UserDefaults, keys `recovery.hrr.attentionThreshold`, `recovery.work.thresholdPct`, `recovery.recovery.entryThresholdPct`. Watch reads via `SharedDataManager` (existing pattern).

---

## 5. Auto-Segmentation Algorithm

The goal: classify every second into one of `{warmup, work, recovery, rest, cooldown}` without the user pressing buttons. Inputs are HR (1 Hz from HK) and CMMotion activity (walking / running / stationary, already wired at WatchWorkoutManager.swift:594-619).

### 5.1 Features

Per second, compute:

- `hrPct` = current HR / HRmax (HRmax from `HeartRateZoneCalculator`)
- `hrSlope10s` = (HR_now − HR_10s_ago) / 10  bpm per second
- `motionTier` = `running` (3) | `walking` (2) | `stationary` (1) | `unknown` (0) — already classified by `CMMotionActivity`
- `secondsInPhase` = elapsed time since current phase entry

### 5.2 Transition rules

State machine inside `RecoverySessionEngine`. Hysteresis values are intentionally generous to prevent flapping in cardiac-rehab users whose HR responses are slower than athletes.

**Warmup → Work**:
- `hrPct >= workThresholdPct` (default 0.70) sustained for >= 30 seconds, OR
- user taps "Start work" override.

**Work → Recovery**:
- `hrSlope10s <= -0.3 bpm/s` (HR is dropping at least 3 bpm over 10 seconds), AND
- `hrPct < recoveryEntryThresholdPct` (default 0.60), AND
- `motionTier <= 2` (walking or stationary), AND
- all of the above sustained for >= 15 seconds (debounce).

**Recovery → Rest**:
- automatic 120 seconds after Recovery entry (after HRR2 captured).

**Rest → Work**:
- `hrPct >= workThresholdPct` sustained for >= 30 seconds, AND `motionTier >= 2`.

**Any → Cooldown**:
- session elapsed time >= (totalDuration − 5 minutes), or user explicitly initiates.

### 5.3 Debounce / hysteresis

- The existing motion debounce (`activityDebounceInterval = 5.0` at WatchWorkoutManager.swift:96) is reused.
- HR-based transitions add a separate 15-30 second sustain window (per rule above). This is longer than motion debounce because HR responds slowly.
- Once a transition is committed, no transition out of that state for at least 20 seconds. Prevents A→B→A flapping.

### 5.4 Manual override

- If auto-segmentation gets it wrong, the user can long-press the phase pill on the watch to bring up `[Force: Work | Recovery | Rest | Cooldown]`. Selection forces the state and freezes auto-detection for 60 seconds, after which auto resumes.
- All forced transitions are logged as `wasManual = true` on the resulting `Segment` for later analysis.

### 5.5 Fallback to manual

- If `CMMotionActivityManager.isActivityAvailable() == false` (simulator, or rare hardware failure) the engine falls back to **HR-only** transitions, with a banner: "Motion detection unavailable — phases will be detected from heart rate alone."
- If both HR and motion are unavailable, the session degrades to a freeRun-style timer with no auto-segmentation and HRR cannot be measured. Banner: "Heart rate unavailable — recovery measurements are paused."

---

## 6. Live HR Trace

### 6.1 Watch buffer

- New struct `HRTracePoint { let timestamp: Date; let bpm: Int }`.
- `RecoverySessionEngine` keeps a ring buffer of the **last 180 points** (3 minutes at 1 Hz). Memory: ~3 KB. Negligible.
- Buffer fed from the existing `processHeartRateSamples` path (WatchWorkoutManager.swift:793-813), with a new branch that pushes points into the engine when `workoutMode == .recovery`.

### 6.2 Watch render

- `RecoveryHRTraceView` (watch, SwiftUI) draws via `Canvas` (Charts is iOS-only). The chart shows the most recent 60 seconds plus a 30-second future "ghost" so the line draws right-to-left without snapping.
- A horizontal target band is drawn behind the line: `[recoveryEntryBPM, workThresholdBPM]`, 35% opacity in the active theme's accent color.
- Line weight 2pt, anti-aliased, smoothed via 3-point moving average (purely visual; the buffered values used for HRR are unsmoothed).
- Top-left label: "Heart Rate (bpm)". Right-edge label: current bpm large.
- Theme bridging: line color = `ShuttlXColor.heartRate`. Background = `ShuttlXColor.surface`. Band fill = `ShuttlXColor.heartRate.opacity(0.35)`.

### 6.3 iPhone render

- `RecoveryLiveView` uses `Charts.framework` `LineMark` + `RuleMark` for the target band. Time window = last 5 minutes.
- Data feed: every 3 seconds the watch broadcasts `liveMetrics` (existing pipeline at WatchWorkoutManager.swift:548-571) extended with a new optional field `"hrTraceTail"` containing the most recent 9 HR points (the 9 since the previous broadcast). iPhone appends to its own ring buffer.
- Why a tail and not the full buffer: keeps message size small and matches the existing 3-second cadence. We accept that an iPhone-side viewer joining mid-session will only see HR from the moment they opened the view forward.

### 6.4 Labeling — non-negotiable

- Any view that shows the trace **must** include the literal string "Heart Rate" or "HR" within view of the line, in at least 12pt type.
- Style choices that resemble a clinical ECG (sharp PQRST shapes, grid graph paper, red-on-green color schemes, the term "ECG", "EKG", "rhythm strip", "lead II") are forbidden in this view. Section 11.

---

## 7. Data Model Changes

All changes must be applied to **both** `ShuttlX/Models/` and `ShuttlX Watch App/Models/` (models rule).

### 7.1 New types

```
struct HRRMeasurement: Codable, Hashable, Identifiable {
    let id: UUID
    var capturedAt: Date            // moment the recovery window started
    var workPeakBPM: Int            // peak HR during preceding work segment
    var hrr1BPM: Int?               // nil if data quality failed
    var hrr2BPM: Int?
    var hrr1Drop: Int?              // workPeakBPM - hrr1BPM, redundant for fast lookup
    var hrr2Drop: Int?
    var qualityFlag: HRRQuality     // .ok | .unreliable | .interrupted | .failed
    var wasFlagged: Bool            // true if drop < attention threshold
}

enum HRRQuality: String, Codable { case ok, unreliable, interrupted, failed }

struct RecoveryReport: Codable, Hashable {
    var measurements: [HRRMeasurement]
    var thresholdsUsed: ThresholdSnapshot   // value of all settings at session start, for reproducibility
    var attentionThresholdBPM: Int
    var hrTrace: [HRTracePointStored]?      // optional, off by default — large
}

struct HRTracePointStored: Codable { let t: TimeInterval; let bpm: Int } // t = seconds since session start

struct ThresholdSnapshot: Codable, Hashable {
    var workThresholdPct: Double
    var recoveryEntryThresholdPct: Double
    var attentionThresholdBPM: Int
}
```

### 7.2 TrainingSession additions

Add to `TrainingSession` (both copies):

```
var recoveryReport: RecoveryReport?       // present iff this session was a Recovery session
var sessionMode: SessionMode?             // .freeRun | .interval | .recovery, replaces inference from workoutMode
```

`SessionMode` is a new String-rawValue enum. Old sessions decode with `nil` (backward compatible — models rule).

### 7.3 WorkoutTemplate additions

A Recovery session does not need an interval list, but we'll reuse `WorkoutTemplate` for consistency:

- Add `var isRecoveryTemplate: Bool = false` (default false; backward compatible).
- For Recovery, `intervals` may be empty. Duration is configured via `warmup`, target session length stored as a single `IntervalStep` of type `.work` with the chosen total duration, and `cooldown`. The engine ignores the steps and runs auto-segmentation, but storing them keeps the model uniform and lets the iPhone show a "Plan: 5min warmup → ~10min movement → 5min cooldown" preview.

### 7.4 No schema-breaking changes

All new fields are optional or have defaults. JSON written by an older client is still decodable by the new client. JSON written by the new client (with `recoveryReport` present) is still decodable by an older client — the field is simply ignored. No migration script needed.

---

## 8. HealthKit Integration

### 8.1 Activity type

`HKWorkoutActivityType.mixedCardio`. Rationale: Recovery sessions mix walking, brief jogging, and stationary periods; `.mixedCardio` reflects that without overclaiming a specific sport. **Do not** use `.cardiacRehabilitation` — that activity type is reserved for actual rehab programs and may be flagged in App Review for medical positioning. Section 11.

### 8.2 What's saved

| Data | Where | How |
|---|---|---|
| HKWorkout | HealthKit workout database | via `HKLiveWorkoutBuilder.finishWorkout()` (existing, WatchWorkoutManager.swift:1046) |
| HR samples | HealthKit (system saves, not us) | continuous from sensor |
| Active energy | HealthKit | `HKLiveWorkoutBuilder` |
| Workout events (segment markers) | HealthKit, attached to HKWorkout | `HKWorkoutBuilder.addWorkoutEvents([HKWorkoutEvent.segment(...)])` at each phase transition |
| HRR1, HRR2, peak HR, attention flag | HealthKit metadata on HKWorkout, AND `TrainingSession.recoveryReport` | metadata keys below |
| Full HR trace | NOT to HealthKit (system already has the underlying samples). Optionally to `TrainingSession.recoveryReport.hrTrace` for our own UI. | local JSON only |

### 8.3 Metadata keys

Custom keys on the HKWorkout, namespaced:

- `com.shuttlx.recovery.hrr1.bpm` (Int)
- `com.shuttlx.recovery.hrr2.bpm` (Int)
- `com.shuttlx.recovery.peakWorkHR.bpm` (Int)
- `com.shuttlx.recovery.attentionFlag` (Bool)
- `com.shuttlx.recovery.sessionMode` (String, "recovery")
- `com.shuttlx.recovery.qualityFlag` (String, raw value of `HRRQuality`)

Apple's reserved `HKMetadataKeyAverageMETs` etc. are unaffected. Custom keys are silently ignored by other apps, so this is safe.

### 8.4 Workout events

- Emit one `HKWorkoutEvent` of type `.segment` at every phase transition. Use the `metadata` field to record the phase: `["com.shuttlx.recovery.phase": "Work"]`.
- The HKWorkoutSession `pause/resume` events are already emitted by the existing implementation.

### 8.5 ECG read-back (post-session, iOS only)

- After a Recovery session finishes, the iPhone summary view calls `HKElectrocardiogramQuery` for the most recent ECG sample within the **last hour** (so we only show one the user just took). Requires entitlement `com.apple.developer.healthkit` plus the `HKObjectType.electrocardiogramType()` read permission.
- Permission added to the existing HealthKit type bundle (WatchWorkoutManager.swift:163-184) is **iOS only** — watchOS does not need ECG read access since the prompt and read both happen on iPhone.
- If a sample is found: show classification (`sinusRhythm` / `atrialFibrillation` / `inconclusive` / etc.), average HR, sampling rate, and a button "Open in Health" (via `x-apple-health://`).
- If none in the last hour: show the soft prompt "If you'd like, take an ECG using the ECG app on your watch." with a "Why?" disclosure linking to neutral copy.

---

## 9. HealthKit Permissions Delta

Current types requested (WatchWorkoutManager.swift:167-183):
- read: `heartRate`, `activeEnergyBurned`, `distanceWalkingRunning`, `stepCount`, `dateOfBirth`
- write: `activeEnergyBurned`, `distanceWalkingRunning`, `HKWorkoutType`

**New for Recovery:**
- read: `HKObjectType.electrocardiogramType()` — iOS only, gated behind a UI explaining why.
- read: `restingHeartRate` — used in the iPhone intro view to display the user's current resting HR baseline. iOS only.
- read: `heartRateVariabilitySDNN` — optional, stretch goal for v1.1: log HRV at session end as a recovery indicator. Not blocking.

**Info.plist changes:**
- iOS Info.plist: `NSHealthClinicalHealthRecordsShareUsageDescription` is **NOT** needed (we don't read clinical records). Existing `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` strings should be updated to mention "heart rate recovery measurements" so the system prompt is accurate.

**Permission UX:**
- Don't bundle ECG and resting-HR read into the existing first-launch authorization sheet. Request them lazily, **only when the user first opens the Recovery feature on iPhone**. Splitting the prompts keeps the initial install funnel clean and avoids users denying ECG out of confusion when they don't even know what Recovery mode is yet.

---

## 10. Battery and Runtime Impact Estimate

Baseline: a current ShuttlX free-run workout on Series 9 / Series 10 burns roughly 18-22% battery per hour with HR + GPS + motion + pedometer.

Recovery mode by default disables GPS and pedometer (no distance / pace tracking), which saves ~6-8% per hour. Adds:

- Continuous HR sampling and ring buffer: **+0%** (HR is already running for free-run, the ring buffer is in-memory and trivial).
- 1 Hz canvas redraw of the HR trace while screen is on: **+0.5-1%** per hour — `Canvas` is GPU-cheap.
- Live metrics broadcast at 3-second cadence with `hrTraceTail`: **negligible** — the existing live-metrics broadcast is already running at the same cadence.
- Phase-transition haptic feedback: **negligible**.

**Net estimate: 12-15% battery per hour**, ~33% better than free-run thanks to no GPS. A 30-minute Recovery session should consume ~6-8% on a healthy battery — entirely reasonable for a cardiac-rehab user who may take their watch off frequently.

watchOS background runtime: the `workout-processing` background mode is already declared. Recovery sessions pause if the user is mid-session and the app is force-quit, recovered via `recoverCrashedWorkout()` (WatchWorkoutManager.swift:938). The recovered session loses its HR ring buffer (in-memory only) — HRR captured before the crash is preserved (it's in `RecoveryReport`, persisted on every phase transition).

iPhone impact: only when the live mirror view is open. Charts framework + 1 Hz append + every-3-second broadcast: < 2% battery per hour on iPhone 15+.

Memory: HR trace ring buffer is bounded at 180 points x ~32 bytes ≈ 6 KB. Stored trace (if user opts in, default off) is ~4 KB per minute of session.

---

## 11. Risks and App Review Concerns

### 11.1 Medical-claims language to avoid

App Review's medical-device guidelines (App Review Guideline 1.4.1, plus the "Health & Fitness" review heuristic) reject apps that:

- Diagnose conditions
- Suggest a user has a medical condition
- Imply ECG-equivalence for non-ECG data
- Use the words "abnormal", "irregular rhythm", "arrhythmia", "atrial fibrillation" (unless surfacing an actual `HKElectrocardiogram` classification verbatim — and even then, attribute it to the Apple ECG app)
- Use clinical iconography (ECG waveforms, hospital-cross icons, stethoscope, heart with crack, ER/911 imagery)

**Banned strings in copy and assets:**
- "ECG" / "EKG" anywhere referring to our HR trace
- "diagnosis", "diagnose", "abnormal", "arrhythmia", "atrial fibrillation", "AFib"
- "warning", "danger", "emergency", "critical", "alert" — softer phrasing only ("attention", "heads up", "something to mention to your doctor")
- "medical-grade", "clinical", "FDA-cleared", "doctor recommended"
- "heart attack", "cardiac event", "stroke"

**Acceptable phrasing template** for the HRR attention flag:
> Your heart rate dropped less than 12 bpm in the first minute after that work segment. This is informational. One reading on one day doesn't mean anything by itself — if you see it often or you're concerned, mention it to your doctor at your next visit.

### 11.2 App Review specifics

- App Review may ask: "Does your app diagnose heart conditions?" Answer: No. The app surfaces HR data and a non-clinical fitness measurement (HRR). The user-facing copy is informational only.
- App Review may push back on the term "Recovery Training" if interpreted as "cardiac rehab program". Mitigation: in the App Store description and any in-app onboarding, frame this as "for general fitness recovery awareness". Avoid the words "rehab", "rehabilitation", "patient", "therapy".
- We do not use `HKWorkoutActivityType.cardiacRehabilitation`. Section 8.1.

### 11.3 Other risks

- Users with arrhythmias may have HR readings that confuse the auto-segmentation (e.g., pacemaker-paced rates that don't drop). Mitigation: settings let the user fix the work/recovery thresholds; manual override on the phase pill.
- Users on beta-blockers will have blunted HR responses — HRR1 < 12 bpm may be normal for them. Mitigation: section 9 question 1.
- If a user records a real ECG, our app will display the classification. We must clearly attribute it to Apple, e.g., "ECG result from the Apple Watch ECG app, recorded 2 minutes ago", with the Apple Health icon.
- Privacy: the HR trace JSON, if persisted, contains health data. It's stored only in the App Group container with `.completeFileProtection` (existing pattern, WatchWorkoutManager.swift:930). It should never be sent to any server. Existing CloudKit sync of `TrainingSession` includes the `recoveryReport` field — confirm with security-reviewer that CloudKit private database is the right home for this (it is).

---

## 12. Public API Surface

These are the new symbols a senior iOS dev would touch to ship Phase 1.

**Watch:**
- `WatchWorkoutManager.startRecoveryWorkout(template: WorkoutTemplate)` — entry point, mirrors `startIntervalWorkout` (WatchWorkoutManager.swift:312).
- `WatchWorkoutManager.workoutMode` — extend the enum to add `.recovery`. Existing enum at WatchWorkoutManager.swift:46.
- `RecoverySessionEngine` — new class in `ShuttlX Watch App/Services/RecoverySessionEngine.swift`. Owns the state machine, HR ring buffer, HRR capture timers, and emits `Segment` updates back to `WatchWorkoutManager`.
  - `func tick(heartRate: Int, motionTier: MotionTier, now: Date)` — called once per second from the existing display timer (WatchWorkoutManager.swift:512).
  - `func currentPhase: RecoveryPhase` — observable.
  - `func snapshot() -> RecoveryReport` — called at session end.
  - `func forcePhase(_:)` — manual override.

**iOS:**
- `RecoveryIntroView` — new SwiftUI view, entry point.
- `RecoveryLiveView` — new SwiftUI view, live mirror.
- `RecoverySummaryView` — new SwiftUI view, post-session.
- `ECGSummaryProvider` — new actor wrapping `HKElectrocardiogramQuery`. Returns the most recent sample within the last hour, or nil.

**Shared:**
- Models from section 7.

**Sync:**
- Live metrics payload (existing, WatchWorkoutManager.swift:548) gains `"hrTraceTail": [Int]` and `"recoveryPhase": String`. Backward compatible — old iPhone clients ignore unknown keys.
- New `applicationContext` payload key `"recoveryReport"` sent on session end so iPhone receives it even if not foregrounded.

---

## 13. Implementation Phases

### Phase 1 — minimum shippable slice (~1 week)

Goal: a Recovery session can be started, runs the state machine, captures HRR1+HRR2, persists, displays summary. **No live trace UI yet, no iPhone mirror, no ECG read-back.**

1. Models in section 7 added to both targets. Build green.
2. `RecoverySessionEngine` with state machine, HR ring buffer, HRR capture. Unit-test the engine with synthetic HR streams (fast Work → Recovery → check HRR computed).
3. `WatchWorkoutManager` extended: `.recovery` mode, `startRecoveryWorkout`, engine wired to the existing per-second tick (WatchWorkoutManager.swift:512).
4. `RecoveryStartView` and a minimal in-workout view (just phase pill, current HR, timer).
5. `RecoverySummaryView` watch-side: average HR, HRR1, HRR2, attention flag if applicable.
6. iOS receives `TrainingSession` with `recoveryReport`, displays HRR1/HRR2 on the existing session detail view.
7. HealthKit metadata keys written.
8. Settings UI for thresholds.

Acceptance: a user can complete a 15-minute Recovery session, see HRR1 and HRR2 in the summary, and the data persists across app relaunch.

### Phase 2 — live HR trace (~3-5 days)

1. Watch `RecoveryHRTraceView` with `Canvas` rendering and target band.
2. iPhone `RecoveryLiveView` with Charts framework.
3. `liveMetrics` payload extended with `hrTraceTail` and `recoveryPhase`.
4. Theme integration verified across all 7 themes.

Acceptance: iPhone and watch both show a live HR trace labeled "Heart Rate (bpm)". Works on Clean, Synthwave, and Neovim themes (sample of 3 — others must visually pass review).

### Phase 3 — ECG read-back and polish (~3 days)

1. iOS `ECGSummaryProvider` + permission request flow.
2. Soft prompt at end of recovery to take an ECG.
3. Most-recent-ECG card on the iPhone summary.
4. Manual phase override on the watch (long-press phase pill).
5. Recovery template stored on iPhone, sent to watch, used as session config.
6. Accessibility audit (VoiceOver labels for the trace, Dynamic Type on the summary).

Acceptance: full feature parity with this spec. Beta-tested with at least 3 users for 1 week.

### Phase 4 (post-launch, not required for ship)

- Multi-session HRR trend chart on iPhone (HRR1 over the last 30 days).
- HRV (heartRateVariabilitySDNN) capture as an additional recovery signal.
- Voice cues at phase transitions ("Entering recovery — stand still or walk slowly").

---

## 14. Edge Cases

| Scenario | Behavior |
|---|---|
| HR sensor dropout during Recovery window | If gap > 10s, mark `qualityFlag = .unreliable`. Capture using best available sample within +/- 3s of target time. If no sample, capture is `nil` and quality is `.failed`. |
| User pauses during Recovery window | Discard the in-progress measurement, mark `qualityFlag = .interrupted`. UI: "HRR measurement was interrupted." |
| App backgrounded mid-session | watchOS `workout-processing` background mode keeps the session running. HR query and engine continue. Trace still buffers. |
| Workout force-quit / device reboot mid-session | `recoverCrashedWorkout()` (WatchWorkoutManager.swift:938) restores the `TrainingSession` with whatever HRR was already captured. Live trace is lost (in-memory only). |
| External Bluetooth chest strap paired | `HKAnchoredObjectQuery` will receive samples from the chest strap as HR data source — same code path. No special handling. We don't differentiate sources for HRR. |
| User has HRmax not set / no DOB in HealthKit | Fallback to age 50 → HRmax 170 (Tanaka). Surface a banner on the intro view: "Set your age in Settings for more accurate work-zone detection." Do not block. |
| User is on a beta-blocker | Engine doesn't know this. Threshold settings are user-tunable so they can lower the work threshold to match their actual exertion HR. See open question 1. |
| User is in atrial fibrillation during the session | HR samples may be highly variable. The median-of-3 smoothing helps slightly, but HRR may be unreliable. `qualityFlag` will reflect data noise. We do not detect AFib from HR alone (banned, see section 11). |
| Session shorter than 5 minutes | No HRR captured (no Work phase had time to enter Recovery). Summary shows "Session too short for recovery measurement." |
| User taps Stop during Recovery window | Capture whatever fraction is available; mark `qualityFlag = .interrupted`. Save and exit. |

---

## 15. Open Questions for Human Review

These need a human (clinician, product owner, or both) before we ship.

1. **HRR1 threshold for THIS user population.** The default 12 bpm is from Cole et al. 1999, which studied unmedicated adults during stress tests. ShuttlX users include older adults, possibly on beta-blockers or rate-controlling medication. Should we (a) keep 12 bpm but make it user-tunable, (b) ask the user during onboarding whether they take HR-affecting medication and pick a different default, or (c) ship with a higher default like 15 bpm and let users lower it? **Recommendation: ship 12 bpm tunable, ask in onboarding only if we see in beta that defaults are wrong.**

2. **Should we even compute HRR2 (2-minute drop)?** It's less established in the literature than HRR1. Some clinical references use it; some don't. Computing both costs nothing technically. Question is whether displaying HRR2 alongside HRR1 confuses non-expert users or helps them. **Recommendation: store both, display both, but make HRR1 the primary number with HRR2 in smaller type.**

3. **What's the right session duration default?** Cardiac-rehab guidance often suggests 20-30 minutes. Beginners may want 10-15. Athletes wanting to use this for active recovery may want 30-45. Default 20 minutes is a guess. **Recommendation: ship 20 default with 10/20/30/40 picker, instrument actual usage, adjust in v1.1.**

4. **(Stretch) Should the attention flag also fire on consistently low HR variability (HRV)?** HRV adds nuance but also complexity and another permission prompt. Defer.

5. **(Stretch) Per-segment calorie attribution.** `HKLiveWorkoutBuilder` collects total active energy continuously but doesn't expose a per-time-window calorie value to the live UI in a clean way. We can approximate by snapshotting `totalCaloriesAccumulated` (WatchWorkoutManager.swift:73) at each phase transition and computing `caloriesInPhase = endSnap - startSnap`. Acceptable approximation? Or wait until v1.1 with a more accurate per-segment query? **Recommendation: snapshot-difference approach in Phase 1, displayed only on the summary, not live.**

---

## 16. Data Flow Diagram (text)

```
[Apple Watch HR sensor]
  └──> HKHealthStore (system)
         └──> HKAnchoredObjectQuery (1 Hz)
                └──> WatchWorkoutManager.processHeartRateSamples
                       ├──> ring buffer (HRTracePoint, last 180s)
                       ├──> RecoverySessionEngine.tick(hr, motion, now)
                       │      ├──> state machine -> phase transitions
                       │      ├──> HRR capture timers (60s, 120s)
                       │      └──> HRRMeasurement appended to RecoveryReport
                       ├──> @Published heartRate (drives watch UI)
                       └──> broadcastLiveMetricsIfNeeded (every 3s)
                              └──> WCSession.sendMessage
                                     └──> [iPhone] SharedDataManager
                                            ├──> RecoveryLiveView (chart)
                                            └──> live HR trace ring buffer

[CMMotionActivityManager]
  └──> handleMotionActivity (5s debounce)
         └──> RecoverySessionEngine (motionTier feature)

[Session end on watch]
  └──> WatchWorkoutManager.saveWorkoutData
         ├──> HKLiveWorkoutBuilder.finishWorkout (with metadata)
         ├──> TrainingSession + RecoveryReport
         │      ├──> JSON to App Group container
         │      └──> WCSession.transferUserInfo to iPhone
         └──> SharedDataManager.sendSessionToiOS
                └──> [iPhone] DataManager -> RecoverySummaryView
                       └──> ECGSummaryProvider.fetchMostRecent()
                              └──> HKElectrocardiogramQuery
                                     └──> shown in summary card
```

---

## 17. Summary

This spec ships a Recovery Training mode that:

- Uses Apple-only frameworks, zero new dependencies.
- Runs entirely within the existing `WatchWorkoutManager` lifecycle, adding one new engine class and a handful of model fields (all backward compatible).
- Reuses the existing live-metrics broadcast pipeline.
- Computes HRR1 and HRR2 with explicit handling of HR dropouts and noise.
- Auto-segments work / recovery / rest / cooldown using both HR and motion signals with hysteresis tuned for cardiac-rehab-appropriate populations.
- Surfaces an attention flag with explicitly non-medical language.
- Avoids every App Review pitfall around medical-device claims.
- Phases ship value incrementally — Phase 1 is shippable on its own.

A senior iOS developer should be able to pick up Phase 1 from this document. Open questions in section 15 require human input before Phase 3 ships.
