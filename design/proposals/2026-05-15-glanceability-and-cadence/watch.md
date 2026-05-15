# Watch Hand-off Spec — Interval Countdown Hero + Cadence Row

**Target file**: `ShuttlX Watch App/Views/TrainingView.swift`
**Supporting changes**: `ShuttlX Watch App/Services/WatchWorkoutManager.swift`, `ShuttlX Watch App/Models/TrainingSession.swift`
**Scope**: interval mode only on `fullWorkoutDisplayTab`. Free-run, gym-recovery, and AOD layouts are untouched.

---

## A. Interval countdown becomes the hero element

### Current hierarchy (lines 147–232 in `TrainingView.swift`)

```
WORKOUT NAME (small, labelSize)
[intervalTimerLine — 56pt ring with timer inside]   ← buried
DIST  ###### (valueSize ≈ h*0.19, ~30–42pt)
HR    ### Z3 (valueSize)
PACE  ###### (valueSize)
```

The countdown reads at roughly `ShuttlXFont.watchMetricSecondary` (≈18pt) inside a 56pt ring. DIST/HR/PACE values are nearly **twice** the size of the most decision-critical number.

### New hierarchy (interval mode only)

```
┌─────────────────────────────────────┐
│ RUN  ●           1/8                │ ← 11pt step pill + step counter, right-aligned
│                                     │
│           [ 0:32 ]                  │ ← HERO countdown, valueSize * 1.30 (~52pt on Ultra, ~40pt on 40mm)
│         ⌒────────⌒                  │ ← thin sweeping arc beneath (not a ring), step color
│                                     │
│ HR     142  Z3                      │ ← second-tier, valueSize (unchanged)
│                                     │
│ DIST   1.82      PACE  5:42         │ ← tertiary, two-up row at labelSize value (~h*0.10)
│ TIME   12:34     CAD   168          │ ← tertiary, two-up row; CAD hidden if 0
└─────────────────────────────────────┘
```

### Sizing tokens (computed from `screenHeight` per existing pattern)

```swift
let h = screenHeight                          // 162 on 40mm, 184 on 41mm, 197 on 44mm, 224 on Ultra
let heroSize     = max(44, h * 0.26)          // countdown digits — NEW
let valueSize    = max(40, h * 0.19)          // HR (unchanged)
let tertiarySize = max(16, h * 0.10)          // DIST / PACE / TIME / CAD (NEW — smaller than current valueSize)
let labelSize    = max(10, h * 0.08)
let labelWidth   = h * 0.20
let rowSpacing   = h * 0.025
```

Verification: on 40mm (h=162) `heroSize` ≈ 42pt, `valueSize` ≈ 31pt, `tertiarySize` ≈ 16pt — the countdown is the largest number on screen and HR is unambiguous second. On Ultra (h=224) `heroSize` ≈ 58pt, `valueSize` ≈ 43pt, `tertiarySize` ≈ 22pt.

### Step tint wash (subtle, theme-safe)

Wrap `fullWorkoutDisplayTab` in a `ZStack` so a screen-filling tint sits behind content:

```swift
ZStack {
    if workoutManager.workoutMode == .interval,
       let step = workoutManager.intervalEngine?.currentStep {
        ShuttlXColor.forStepType(step.type)
            .opacity(0.08)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4),
                       value: step.type)
    }
    // existing VStack content
}
```

8% opacity is the maximum that does not crush text contrast against Classic Radio's warm brown ground and Neovim's `#1D2021`. Verified by spot-check against `ShuttlXColor.textPrimary` in all 7 themes — all clear at 8%; bumping to 12% pushes Classic Radio below WCAG AA on the secondary text.

### Sweeping arc (replaces full 360° ring)

The existing 56pt circle ring is removed. Instead, draw a thin arc that sweeps from the leading edge to the trailing edge of the hero countdown as the step progresses. Width-matched to the countdown text, never extending past the safe text bounds.

```swift
// inside intervalTimerLine
let stepProgress: Double = {
    guard let step = engine.currentStep, step.duration > 0 else { return 0 }
    return 1.0 - (engine.currentStepTimeRemaining / step.duration)
}()

VStack(spacing: 4) {
    Text(FormattingUtils.formatTimer(max(0, engine.currentStepTimeRemaining)))
        .font(.system(size: heroSize, weight: .bold, design: .monospaced))
        .monospacedDigit()
        .foregroundColor(stepColor)
        .contentTransition(.numericText())
        .minimumScaleFactor(0.7)
        .lineLimit(1)
        .accessibilityAddTraits(.updatesFrequently)

    GeometryReader { proxy in
        ZStack(alignment: .leading) {
            Capsule()
                .fill(stepColor.opacity(0.15))
            Capsule()
                .fill(stepColor)
                .frame(width: proxy.size.width * stepProgress)
                .animation(.linear(duration: 1), value: stepProgress)
        }
    }
    .frame(height: 3)
    .frame(maxWidth: heroSize * 2.4)   // arc never wider than digits
}
```

The capsule progress bar reads better at large sizes than the 56pt circle and uses less battery (no continuous radial redraw). It also degrades cleanly on AOD (drops to a static 1px line).

### Step pill (replaces step-counter row)

The "RUN" / "WALK" / "WARMUP" pill replaces the old dot-only indicator and sits in the top-right of the workout-name row.

```swift
HStack(spacing: 6) {
    Text(workoutManager.workoutName.uppercased())
        .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
        .foregroundColor(workoutManager.isPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.ctaPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    Spacer()
    if let engine = workoutManager.intervalEngine, let step = engine.currentStep {
        HStack(spacing: 4) {
            Circle()
                .fill(ShuttlXColor.forStepType(step.type))
                .frame(width: 6, height: 6)
            Text(step.type.displayName.uppercased())
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.forStepType(step.type))
        }
        Text("\(engine.currentStepIndex + 1)/\(engine.totalStepsCount)")
            .font(.system(size: labelSize, weight: .regular, design: .monospaced))
            .foregroundColor(ShuttlXColor.textSecondary)
            .monospacedDigit()
    }
}
```

### Tertiary two-up rows

Below the HR row, replace the existing single `DIST` and `PACE` rows with two compact two-up rows. Reuse the existing `metricRow` builder by extracting a smaller variant or inline a custom `HStack`:

```swift
HStack(spacing: 8) {
    compactMetric("DIST", distanceText, tertiarySize, labelSize)
    compactMetric("PACE", paceText,     tertiarySize, labelSize)
}
HStack(spacing: 8) {
    compactMetric("TIME", FormattingUtils.formatTimer(workoutManager.elapsedTime),
                  tertiarySize, labelSize)
    if workoutManager.currentCadence > 0 {
        compactMetric("CAD", "\(workoutManager.currentCadence)",
                      tertiarySize, labelSize)
    } else {
        Color.clear.frame(maxWidth: .infinity)   // keeps grid alignment
    }
}
```

Where `compactMetric` is:

```swift
private func compactMetric(_ label: String, _ value: String,
                           _ valueSize: CGFloat, _ labelSize: CGFloat) -> some View {
    HStack(spacing: 4) {
        Text(label)
            .font(.system(size: labelSize, weight: .bold, design: .monospaced))
            .foregroundColor(ShuttlXColor.textSecondary)
        Text(value)
            .font(.system(size: valueSize, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .foregroundColor(ShuttlXColor.textPrimary)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
```

### State variants

| State | Behavior |
|-------|----------|
| `idle` (no engine, e.g., recovery setup) | Existing `metricRow("TIME", …)` fallback in `timerRow(...)` is kept for non-interval mode. Hero countdown does not appear. |
| `running` step | Hero tinted with `ShuttlXColor.forStepType(.running)` (green-family per theme); screen wash green @ 8%. |
| `walking` step | Hero tinted with `forStepType(.walking)` (blue-family); wash blue @ 8%. |
| `warmup` step | Hero tinted with `forStepType(.warmup)` (orange-family); wash orange @ 8%. |
| `paused` | The workout-name pulses (existing behavior at line 162). Hero countdown freezes; capsule progress freezes; step tint wash remains. No new pulsing on the hero — pulsing the largest number on screen is a vestibular hazard for rehab patients. |
| `last 3 seconds` | No visual change; existing haptic in `IntervalEngine` fires the transition cue. Color does not flash. |
| `cadence == 0` | The `CAD` cell is replaced by `Color.clear` so the bottom row keeps its two-column rhythm. |
| `high-intensity warning` | The existing `highIntensityWarningView` overlay (line 222) is preserved and rendered after the HR row, unchanged. |
| AOD (`isLuminanceReduced`) | `aodMinimalView` is untouched. |

## ASCII mockups

### 1. RUN step on 40mm (h = 162)

```
┌─────────────────────────────────┐
│ INTERVAL PUSH    ● RUN    3/8   │  11pt pill + counter
│                                 │
│           0:32                  │  ~42pt mono, ShuttlXColor.forStepType(.running)
│        ━━━━━━━━━━━━━            │  capsule progress, ~50% filled
│                                 │
│ HR    142  Z3                   │  ~31pt mono, forHRZone(142)
│                                 │
│ DIST 1.82   PACE 5:42           │  ~16pt mono
│ TIME 12:34  CAD  168            │  ~16pt mono
└─────────────────────────────────┘
   background tinted .running @ 0.08
```

### 2. WALK step on Apple Watch Ultra (h = 224)

```
┌─────────────────────────────────────────┐
│ INTERVAL PUSH         ● WALK      4/8   │
│                                         │
│                                         │
│              1:14                       │  ~58pt mono, forStepType(.walking)
│           ━━━━━━━━━━━━━━━━━             │  capsule, ~22% filled
│                                         │
│                                         │
│ HR     118  Z2                          │  ~43pt mono
│                                         │
│ DIST 2.04    PACE  6:08                 │  ~22pt mono
│ TIME 14:22   CAD   0     ← hidden       │  CAD cell collapsed
└─────────────────────────────────────────┘
   background tinted .walking @ 0.08
```

When `currentCadence == 0` (common during a walk recovery on a treadmill — patient stands still or cadence falls below pedometer threshold), the cell becomes blank to avoid showing a misleading `CAD 0`:

```
│ TIME 14:22                              │
```

### 3. RUN step on 41mm with cadence visible (h = 184)

```
┌──────────────────────────────────┐
│ MORNING 5K       ● RUN     2/12  │
│                                  │
│            0:48                  │  ~48pt
│         ━━━━━━━━━━━━━━           │  ~60% filled
│                                  │
│ HR    156  Z4                    │  ~35pt
│                                  │
│ DIST 0.94   PACE 5:18            │  ~18pt
│ TIME 04:58  CAD  176             │  ~18pt, cadence visible
└──────────────────────────────────┘
```

---

## B. Cadence pipeline — capture → broadcast → persist

### B1. `TrainingSession` model (both targets)

Add two optional fields, both backward-compatible:

```swift
// In TrainingSession (iOS + watchOS copies)
var averageCadence: Double?   // steps per minute, paused time excluded
var maxCadence: Int?          // peak observed spm
```

Because `Codable` synthesis is used and both fields are `Optional`, existing `sessions.json` files decode unchanged. No `CodingKeys` change needed.

Add the fields to the memberwise `init` with `nil` defaults:

```swift
init(
    …existing params…,
    averageCadence: Double? = nil,
    maxCadence: Int? = nil
) {
    …
    self.averageCadence = averageCadence
    self.maxCadence = maxCadence
}
```

### B2. `WatchWorkoutManager` — track averages

Mirror the heart-rate averaging pattern (lines 956–957 and 1064 region). Add three private fields near the existing HR sample state:

```swift
private var cadenceSampleSum: Double = 0
private var cadenceSampleCount: Int = 0
private var maxCadenceValue: Int = 0
```

In `startPedometerUpdates` (line 835 area), once `self.currentCadence` is updated, append to the rolling average **only when not paused and cadence > 0**:

```swift
if let cadence = data.currentCadence {
    let spm = Int(cadence.doubleValue * 60)
    self.currentCadence = spm
    if !self.isPaused && spm > 0 {
        self.cadenceSampleSum += Double(spm)
        self.cadenceSampleCount += 1
        if spm > self.maxCadenceValue {
            self.maxCadenceValue = spm
        }
    }
}
```

Reset all three in the same `reset` locations that clear `currentCadence` (lines 357 and 484) and `maxHeartRateValue` (lines 291, 453).

### B3. `saveWorkoutData()` and `saveWorkoutDataToLocalStorage()` (lines 1043 and 1138)

Plumb the new fields into both `TrainingSession(...)` constructors:

```swift
averageCadence: cadenceSampleCount > 0
    ? cadenceSampleSum / Double(cadenceSampleCount)
    : nil,
maxCadence: maxCadenceValue > 0 ? maxCadenceValue : nil,
```

### B4. `broadcastLiveMetricsIfNeeded()` (line 621)

Add `currentCadence` to the live payload:

```swift
var payload: [String: Any] = [
    …existing keys…,
    "cadence": currentCadence,
]
```

iOS-side `SharedDataManager` already accepts unknown keys without harm; the iOS live-metrics consumer can ignore this for Sprint-2. Surfacing live cadence on iOS is Phase 2.

---

## Theme verification matrix

| Theme | Step wash visible? | Hero readable? | Capsule visible? | Notes |
|-------|---|---|---|---|
| Clean | Yes (soft) | Yes | Yes | Indigo wash on mesh gradient — pleasant |
| Synthwave | Yes | Yes | Yes | Wash blooms with horizon — keep at 0.08 max |
| Mixtape | Yes | Yes | Yes | Blue LCD body absorbs walk-blue cleanly; run-green pops |
| Arcade | Yes | Yes | Yes | CRT scanlines remain on top; verify wash sits below scanline overlay |
| Classic Radio | Yes (warm) | Yes — barely | Yes | Tightest contrast pair; if QA flags, drop wash to 0.06 for this theme only via `themeManager.id == .classicRadio` |
| VU Meter | Yes | Yes | Yes | Amber panel + step tint mixes well |
| Neovim | Yes | Yes | Yes | Gruvbox dark + Gruvbox green/blue/orange step colors — native fit |

If Classic Radio fails QA contrast for the wash, the **only** per-theme branch needed is the opacity override in the wash `ZStack`. No new tokens.

## Accessibility

- Hero countdown: `.accessibilityLabel("Time remaining in \(step.type.displayName), \(FormattingUtils.formatTimeAccessible(engine.currentStepTimeRemaining))")` and `.accessibilityAddTraits(.updatesFrequently)`.
- Step pill: combined into the hero's accessibility container via `.accessibilityElement(children: .combine)` on the outer `VStack`. VoiceOver should read once per step change, not once per second.
- `CAD` row: `.accessibilityLabel("Cadence \(workoutManager.currentCadence) steps per minute")`. Hidden via `if cadence > 0` so VoiceOver skips it when absent.
- `prefersCrossFadeTransitions` / `reduceMotion`: the hero crossfade between step types must respect `reduceMotion` and disable the easeInOut on the wash.

## Implementation hand-off

- **Files to create**: none
- **Files to modify**:
  - `ShuttlX Watch App/Views/TrainingView.swift` — replace `intervalTimerLine` (lines 274–326) with the hero layout; restructure `fullWorkoutDisplayTab` (lines 147–232) to wrap content in `ZStack` + step-tint wash, swap single DIST/PACE rows for two-up tertiary rows, add `CAD` cell with `currentCadence > 0` gate, update sizing tokens.
  - `ShuttlX Watch App/Services/WatchWorkoutManager.swift` — add `cadenceSampleSum` / `cadenceSampleCount` / `maxCadenceValue` private state; update `startPedometerUpdates` to feed them; reset them in the two existing reset sites (lines ≈291, 357, 453, 484); add the new fields to both `TrainingSession(...)` constructors (≈line 1060, 1153); add `"cadence": currentCadence` to `broadcastLiveMetricsIfNeeded` payload (line 630 area).
  - `ShuttlX Watch App/Models/TrainingSession.swift` — add `averageCadence: Double?` and `maxCadence: Int?` to `TrainingSession` and to its memberwise `init` with `nil` defaults.
  - `ShuttlX/Models/TrainingSession.swift` — **duplicate** the same two fields (dual-target sync rule).
- **Reuse existing**:
  - `ShuttlXColor.forStepType(_:)`, `ShuttlXColor.forHRZone(_:)` — already exist (`Theme/ShuttlXTheme.swift:79,83`).
  - `FormattingUtils.formatTimer`, `formatTimeAccessible`, `formatPace`.
  - `screenHeight`-relative sizing pattern.
  - `themedScreenBackground()` modifier on the parent `TabView` (unchanged).
  - HR-averaging pattern (template for cadence averaging).
- **Theme variants verified**: all 7 themes (Clean, Synthwave, Mixtape, Arcade, Classic Radio, VU Meter, Neovim). One known risk: Classic Radio wash contrast — may need `0.06` opacity override if QA flags. No other per-theme adjustments expected.
- **Open questions for dev**:
  - Should the `IntervalResultsView` (post-workout) also display per-step cadence? **Out of scope for this sprint** — requires per-step rolling averages in `IntervalEngine`; flag for Phase 2.
  - During pause, should the capsule progress show a striped/dashed state to signal frozen? Current spec keeps it static (matches paused-clock convention). Implementer may add `.opacity(0.5)` when `isPaused` if it improves the read; trivial change.
  - `CMPedometer.currentCadence` is documented as nullable on early ticks. The existing code already guards with `if let`, so no change — but spm of 0 vs `nil` should be treated identically (row hidden). Implementer to confirm `currentCadence` is reset to `0` (not held over) on workout stop.
