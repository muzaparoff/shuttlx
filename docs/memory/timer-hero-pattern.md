---
name: Per-Theme Timer Hero Pattern
description: How each of 6 themes renders a unique hero visualization on iOS and watchOS; the watch chrome overlay pattern; dispatch mechanics
type: project
originSessionId: timer-redesign-sprint-2026-06-06
---

# Per-Theme Timer Hero Pattern

## Overview

Starting in Build 34, 6 of 8 themes each own a unique, theme-branded **hero** visualization that plays during the active-workout timer display. The hero is the dominant visual element that brings each theme's personality to the timer screen.

## File Structure

```
iOS Target:
  ShuttlX/Theme/Themes/SynthwaveHero.swift
  ShuttlX/Theme/Themes/MixtapeHero.swift
  ShuttlX/Theme/Themes/ArcadeHero.swift
  ShuttlX/Theme/Themes/ClassicRadioHero.swift
  ShuttlX/Theme/Themes/VUMeterHero.swift
  ShuttlX/Theme/Themes/NeovimHero.swift

watchOS Target:
  ShuttlX Watch App/Theme/Themes/SynthwaveHero.swift
  ShuttlX Watch App/Theme/Themes/MixtapeHero.swift
  ShuttlX Watch App/Theme/Themes/ArcadeHero.swift
  ShuttlX Watch App/Theme/Themes/ClassicRadioHero.swift
  ShuttlX Watch App/Theme/Themes/VUMeterHero.swift
  ShuttlX Watch App/Theme/Themes/NeovimHero.swift
```

Each file is **independent per target** — iOS and watchOS have different frame budgets, font sizes, and layout constraints, so the hero implementations diverge by platform.

## 6 Themes with Heroes

| Theme | iOS Hero | Watch Hero | Root Cause |
|-------|----------|-----------|-----------|
| Synthwave | Outrun speedometer needle + scrolling perspective grid | Compact speedometer + grid (narrow) | Speed metaphor + road perspective |
| Mixtape | Twin spinning cassette reels + LCD tape counter | Reel animation simplified for watch | Analog tape motion |
| Arcade | 7-segment HI-SCORE display + "INSERT COIN" + blink animation | 7-segment score (compact) | Retro arcade aesthetics |
| Classic Radio | Horizontal tuning dial with sweeping needle + frequency readout | Tuning needle arc (compact) | Analog radio dial metaphor |
| VU Meter | Dual vertical gauge needles (driven by HR and pace) + dB scale | Dual needle meters (vertical) | Live audio metering visual |
| Neovim | Modal `:command` status line + elapsed time in register syntax + blinking cursor | Command line (compact) + register | Terminal/Vim aesthetics |

## Dispatch Mechanism

### iOS

In `iPhoneWorkoutTimerView.swift`, the hero section uses a `@ViewBuilder` switch on `themeManager.current.id`:

```swift
@ViewBuilder
var themedTimerBody: some View {
    switch themeManager.current.id {
    case "synthwave":
        SynthwaveHero(controller: controller)
    case "mixtape":
        MixtapeHero(controller: controller)
    case "arcade":
        ArcadeHero(controller: controller)
    case "classicradio":
        ClassicRadioHero(controller: controller)
    case "vumeter":
        VUMeterHero(controller: controller)
    case "neovim":
        NeovimHero(controller: controller)
    default:
        // Clean theme (minimal hero) or FM Tuner (uses existing FMTunerHeader)
        EmptyView()
    }
}
```

The hero receives the **same `iPhoneWorkoutController`** instance that drives metrics (HR, pace, distance, etc.). No controller logic lives in the theme files — they are **pure view** only.

### watchOS

In `TrainingView.swift`, within the `fullWorkoutDisplayTab` ZStack, each theme has a conditional block:

```swift
ZStack {
    // Metrics rows (DIST, PACE, CAD, HR, etc.)
    VStack { ... }
    
    // Per-theme hero overlay (non-hittable)
    if themeManager.current.id == "synthwave" {
        SynthwaveHero(workoutManager: workoutManager)
            .allowsHitTesting(false)
    }
    if themeManager.current.id == "mixtape" {
        MixtapeHero(workoutManager: workoutManager)
            .allowsHitTesting(false)
    }
    // ... (same for other 4 themes)
}
```

**Key constraint**: all overlays use `.allowsHitTesting(false)` to ensure pause/stop buttons remain tappable underneath. The hero is purely decorative.

## Data Flow

### iOS Hero Receives

Each hero initializer looks like:

```swift
struct SynthwaveHero: View {
    let controller: iPhoneWorkoutController
    
    var body: some View {
        // reads: controller.currentHeartRate, controller.currentPace, 
        //        controller.currentDistance, controller.elapsedTime, etc.
    }
}
```

### watchOS Hero Receives

```swift
struct SynthwaveHero: View {
    let workoutManager: WatchWorkoutManager
    
    var body: some View {
        // reads: workoutManager.currentHeartRate, workoutManager.currentPace,
        //        workoutManager.currentDistance, workoutManager.elapsedTime, etc.
    }
}
```

Both targets have the same public metric properties on their respective workout managers, so hero code can be structurally similar even if the frame budgets differ.

## Implementation Notes

### Layout Constraints

- **iOS**: Full-screen timer region (typically 250–300pt tall, 280pt wide on landscape); hero can use Canvas, complex animations, multiple layers
- **watchOS**: Constrained by 41mm/45mm screen size; hero must fit alongside or beneath the 5–6 metric rows; typical hero height is 80–120pt; avoid horizontal Canvas drawings (use vertical stacks instead)

### Animation Patterns

- Heroes are **event-driven**: they animate based on workout state (paused vs. active) and metric changes
- Use `onChange` to detect pace changes (rolling window updates) and trigger speedometer needle movements
- Use `Timer` or `.onReceive` if periodic animation is needed (e.g., cassette reel spin, cursor blink, needle gauge swing)

### Reuse of Controller Data

- **Do NOT** duplicate state from the controller into the hero — always read from the controller instance passed in
- **Do NOT** call controller methods (e.g., `pause()`, `stop()`) from hero code — the hero is view-only
- If a hero needs to transform a metric (e.g., derive RPM from HR for a VU Meter needle position), define a `@ViewBuilder` helper inside the hero file, not in the controller

### Non-hittable Overlays on Watch

The `.allowsHitTesting(false)` modifier is essential because:

1. Hero layers (especially wide Canvas-based ones) can accidentally block taps on buttons below
2. Users must always be able to pause/stop, even if a visual glitch happens in the hero
3. The hero is supplementary — controls take priority

## Testing

Per-theme heroes should be tested:

1. **At workout start** — hero renders correctly with initial 0 metrics
2. **During active workout** — hero responds to metric updates (pace, HR, distance)
3. **On pause** — hero freezes or transitions to paused state gracefully
4. **On resume** — hero resumes animation without artifacts
5. **Long workout (30+ min)** — no memory leaks, animations remain smooth

## Future Extensions

- FM Tuner theme uses the existing `FMTunerHeader` + `FMTunerVUColumn` pattern (not a per-hero file)
- Clean theme has optional minimal hero (or none) — defined in the default case of the dispatch switch
- If a future theme is added, add a new hero file to both targets and a case in the dispatch switch

## Related Docs

- `.claude/rules/design-system.md` — Per-theme Timer Hero subsection documents dispatch and reuse rules
- `docs/plans/timer-redesign.md` — Phase 3 describes the wiring (Phase 2) and per-theme implementation (Phase 3)
- `docs/incidents/2026-06-06-pace-10min.md` — pace rolling-window fix that makes speedometer/gauge animations stable
