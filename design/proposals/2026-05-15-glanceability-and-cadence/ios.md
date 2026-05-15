# iOS Hand-off Spec — Cadence in Session Detail

**Target file**: `ShuttlX/Views/SessionDetailView.swift`
**Supporting**: `ShuttlX/Models/TrainingSession.swift` (mirror of watch model change)
**Scope**: add cadence tiles to the existing `metricGrid` only. No new screens, no nav changes.

---

## Where the data comes from

The watchOS spec (`watch.md`) adds two fields to `TrainingSession`:

```swift
var averageCadence: Double?    // spm, paused time excluded
var maxCadence: Int?           // peak spm observed
```

Both are `Optional`, both default to `nil` in the memberwise `init`. Existing `sessions.json` decodes unchanged because `JSONDecoder` synthesizes `decodeIfPresent` for `Optional` properties. **No manual `CodingKeys` block is needed and none should be added** — adding one would silently break the legacy fields (`programID`, `programName`, etc.) that currently rely on synthesis.

You must add the same two fields to `ShuttlX/Models/TrainingSession.swift` (the iOS copy) to keep dual-target parity per `.claude/rules/models.md`.

## What changes in `SessionDetailView`

Two new `MetricCard` tiles are added to the existing `LazyVGrid` in `metricGrid` (lines 88–144). They follow the same gated-render pattern as `maxHeartRate` and `caloriesBurned`: render only when the underlying value is present and meaningful.

### Tile 1 — Avg Cadence

```swift
if let cad = session.averageCadence, cad > 0 {
    MetricCard(
        icon: "figure.run.motion",
        value: "\(Int(cad.rounded())) spm",
        label: "Avg Cadence",
        color: ShuttlXColor.steps
    )
}
```

### Tile 2 — Max Cadence

Only shown if it differs meaningfully from the average (within 2 spm = same number → suppress, reduces grid clutter for short walks):

```swift
if let maxCad = session.maxCadence,
   maxCad > 0,
   let avg = session.averageCadence,
   abs(Double(maxCad) - avg) >= 2 {
    MetricCard(
        icon: "figure.run.motion",
        value: "\(maxCad) spm",
        label: "Max Cadence",
        color: ShuttlXColor.steps
    )
}
```

If `averageCadence` is `nil` but `maxCadence > 0` (edge case: very short session), still surface max:

```swift
} else if let maxCad = session.maxCadence,
          maxCad > 0,
          session.averageCadence == nil {
    MetricCard(
        icon: "figure.run.motion",
        value: "\(maxCad) spm",
        label: "Max Cadence",
        color: ShuttlXColor.steps
    )
}
```

### Insertion point

Place the two tiles **after** the `totalSteps` tile and **before** the `Avg Pace` tile (lines 126–142). This keeps step-derived metrics grouped:

```
Distance      | Avg HR
Max HR        | Calories
Steps         | Avg Cadence     ← NEW
Max Cadence   | Avg Pace         ← Max Cadence NEW; Avg Pace shifts down
```

If only `averageCadence` is present (the typical case), the grid stays balanced because `Avg Cadence` simply takes the next slot and `Avg Pace` flows naturally.

## Why `ShuttlXColor.steps` and not a new token

`steps` and `cadence` are conceptually the same instrument (the leg) measured per-minute vs cumulatively. Using `ShuttlXColor.steps` keeps the visual grouping intentional ("everything orange-family is foot-strike data" across all 7 themes). No new color token needed; verified against `ThemeColors.swift` in all 7 theme files.

## ASCII mockup — metric grid in SessionDetailView

```
┌──────────────────────────────────────────────┐
│                                              │
│        SESSION DETAILS                       │
│                                              │
│        Morning 5K                            │
│        ●  Run                                │
│        28:42                                 │
│        Wed May 14 · 7:12 AM                  │
│                                              │
│  [Activity badges]                           │
│  [Activity segments timeline]                │
│  [Route map]                                 │
│  [Interval results, if any]                  │
│                                              │
│  ┌────────────────┐ ┌────────────────┐       │
│  │ 📍              │ │ ❤             │       │
│  │ 3.2 km         │ │ 145 BPM        │       │
│  │ Distance       │ │ Avg Heart Rate │       │
│  └────────────────┘ └────────────────┘       │
│  ┌────────────────┐ ┌────────────────┐       │
│  │ ❤              │ │ 🔥             │       │
│  │ 172 BPM        │ │ 312            │       │
│  │ Max Heart Rate │ │ Calories       │       │
│  └────────────────┘ └────────────────┘       │
│  ┌────────────────┐ ┌────────────────┐       │
│  │ 👟              │ │ 🏃             │       │
│  │ 4280           │ │ 168 spm        │  NEW  │
│  │ Steps          │ │ Avg Cadence    │       │
│  └────────────────┘ └────────────────┘       │
│  ┌────────────────┐ ┌────────────────┐       │
│  │ 🏃             │ │ ⏱             │       │
│  │ 184 spm        │ │ 8:58 /km       │  NEW  │
│  │ Max Cadence    │ │ Avg Pace       │       │
│  └────────────────┘ └────────────────┘       │
│                                              │
└──────────────────────────────────────────────┘
```

(Emoji used in mockup only — real cards use SF Symbols per existing `MetricCard` API.)

## State variants

| Source data | Rendered tiles |
|---|---|
| `averageCadence == nil`, `maxCadence == nil` (legacy session, pre-Sprint-2 data) | Neither tile rendered. Grid identical to today. |
| `averageCadence > 0`, `maxCadence == nil` | Only `Avg Cadence` rendered. |
| `averageCadence > 0`, `maxCadence > 0`, `|max-avg| < 2` | Only `Avg Cadence` rendered (max suppressed as duplicate). |
| `averageCadence > 0`, `maxCadence > 0`, `|max-avg| >= 2` | Both rendered. |
| `averageCadence == nil`, `maxCadence > 0` (edge: very short session) | Only `Max Cadence` rendered. |
| `averageCadence == 0` | Treated as `nil` (no cadence captured — e.g., gym recovery, treadmill with hand-rail grip). Tile suppressed. |

## Accessibility

`MetricCard` already wraps content with combined accessibility per existing usage in this file. The natural reading is "Avg Cadence, 168 spm" / "Max Cadence, 184 spm" — sufficient for VoiceOver without overrides. If `MetricCard` does not yet add the unit in its read-out, the implementer should pass an explicit `.accessibilityLabel("Average cadence \(Int(cad)) steps per minute")` on the outside — but check the existing `MetricCard` implementation first to avoid double-reading.

## Preview update

The `#Preview` at the bottom of `SessionDetailView.swift` (line 250) constructs a `TrainingSession` with positional args. The two new optional params have defaults, so the preview compiles unchanged. **Suggested**: add `averageCadence: 168, maxCadence: 184` to the preview so the new tiles render in the Xcode canvas — useful for the implementer to verify layout.

## Theme verification

All seven themes (Clean, Synthwave, Mixtape, Arcade, Classic Radio, VU Meter, Neovim) render `MetricCard` through `.themedCard()` which already adapts per theme. The only new ink is `ShuttlXColor.steps`, which is defined per theme in `ThemeColors.swift`. No per-theme override needed.

## Implementation hand-off

- **Files to create**: none
- **Files to modify**:
  - `ShuttlX/Models/TrainingSession.swift` — add `averageCadence: Double?` and `maxCadence: Int?` to the struct and to the memberwise `init` with `nil` defaults. Rely on synthesized `Codable` (`decodeIfPresent` is automatic for Optionals). Do **not** add a manual `CodingKeys` block.
  - `ShuttlX/Views/SessionDetailView.swift` — insert the two `MetricCard` blocks inside `metricGrid` (lines 88–144) between the `totalSteps` and `Avg Pace` tiles, gated as specified above.
  - Optional: update the `#Preview` to include `averageCadence: 168, maxCadence: 184` so reviewers see the new tiles.
- **Reuse existing**:
  - `MetricCard` component
  - `ShuttlXColor.steps` token (no new color introduced)
  - SF Symbol `figure.run.motion` (already in SF Symbols 4+; iOS 18 baseline)
  - `LazyVGrid` two-column layout — unchanged
- **Theme variants verified**: all 7 themes via existing `MetricCard` + `.themedCard()` plumbing. No per-theme adjustments required.
- **Open questions for dev**:
  - Should `Avg Cadence` also surface in the analytics/trends view (`AnalyticsView`)? **Out of scope for Sprint-2** — flag for backlog if PM wants a weekly-cadence chart.
  - The `figure.run.motion` glyph reads as a runner, which is correct for run+walk but slightly off for the `gymRecovery` mode where cadence might still be captured incidentally. Recommendation: do not show cadence tiles when `sessionMode == .gymRecovery` (treadmill walking against handrails produces unreliable cadence). Add `&& session.sessionMode != .gymRecovery` to the gate if QA confirms unreliable data in gym mode; otherwise leave as-is.
  - `MetricCard`'s exact accessibility behavior — confirm it speaks the unit ("spm") or supply an explicit `.accessibilityLabel`.
