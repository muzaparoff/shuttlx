---
name: Per-Theme Timer Hero Pattern
description: How a theme renders a unique hero visualization on iOS and watchOS; the watch chrome overlay pattern; dispatch mechanics. No hero ships today: Mixtape (the last one) was deleted in October 2026.
type: project
originSessionId: timer-redesign-sprint-2026-06-06
---

# Per-Theme Timer Hero Pattern

## Overview

Introduced in Build 34, a theme can own a unique, theme-branded **hero** visualization that plays during the active-workout timer display. The hero is the dominant visual element that brings the theme's personality to the timer screen.

The theme reductions (July 2026 to 2 themes, October 2026 to Clean only) mean **no hero ships today** — Mixtape's was deleted (Clean stays intentionally minimal). The dispatch pattern below is how any future theme's hero gets added.

## File Structure

No hero files exist today. A future hero lives in `ShuttlX/Theme/Themes/` (iOS) and `ShuttlX Watch App/Theme/Themes/Decorations/` (watch). Each is **independent per target** — iOS and watchOS have different frame budgets, font sizes, and layout constraints.

## Shipped Hero

None. Clean is minimal (the shared layout) — the calm accessibility baseline. Mixtape (twin reels on iOS, `MixtapeWatchDeck` on watch) was deleted in October 2026.

## Dispatch Mechanism

### iOS

`iPhoneWorkoutTimerView.swift` renders `standardTimerBody`. To add a hero, switch on `themeManager.current.id` there and fall through to `standardTimerBody` as the default.

The hero receives the **same `iPhoneWorkoutController`** instance that drives metrics (HR, pace, distance, etc.). No controller logic lives in the theme files — they are **pure view** only.

### watchOS

In `TrainingView+Metrics.swift`, `fullWorkoutDisplayTab` renders the shared metrics stack. A themed deck would be an `if themeManager.current.id == "<id>"` branch in that ZStack.

**Key constraint**: decorative overlays use `.allowsHitTesting(false)` so pause/stop controls remain tappable underneath.

## Data Flow

Heroes read metric properties from the target's workout engine (`iPhoneWorkoutController` on iOS, `WatchWorkoutManager` on watch): `currentHeartRate`, `currentPace`, `currentDistance`, `elapsedTime`, pause state. Both targets expose equivalent metric APIs, so hero code can be structurally similar even when the frame budgets differ.

## Implementation Notes

### Layout Constraints

- **iOS**: full-screen timer region; hero can use Canvas, complex animations, multiple layers
- **watchOS**: constrained by 40/46mm screen; the metrics page is size-solved (see `.claude/rules/watchos.md` for the size-solving rules); avoid layouts that trigger silent scale-to-fit

### Animation Patterns

- Heroes are **event-driven**: they animate based on workout state (paused vs. active) and metric changes
- Drive any watch rotation from `elapsedTime` — monotonic, so it halts on pause with no catch-up snap; respect Reduce Motion
- On iOS, any `TimelineView(.animation)` must pass `paused:` tied to the workout pause state

### Reuse of Controller Data

- **Do NOT** duplicate state from the controller into the hero — always read from the instance passed in
- **Do NOT** call controller methods (e.g., `pause()`, `stop()`) from hero code — the hero is view-only
- If a hero needs to transform a metric, define a helper inside the hero file, not in the controller

### Non-hittable Overlays on Watch

`.allowsHitTesting(false)` on decorations is essential because:

1. Decorative layers (especially wide Canvas-based ones) can accidentally block taps on buttons below
2. Users must always be able to pause/stop, even if a visual glitch happens in the hero
3. The hero is supplementary — controls take priority

## Testing

Heroes should be tested:

1. **At workout start** — hero renders correctly with initial 0 metrics
2. **During active workout** — hero responds to metric updates (pace, HR, distance)
3. **On pause** — hero freezes or transitions to paused state gracefully
4. **On resume** — hero resumes animation without artifacts
5. **Long workout (30+ min)** — no memory leaks, animations remain smooth

## Future Extensions

- Clean theme keeps a minimal hero (default case of the dispatch switch) — it is the accessibility baseline
- If a future theme is added, add a hero file to both targets and a case in each dispatch site (grep every `switch`/`if` on theme id in BOTH targets)

## Related Docs

- `.claude/rules/design-system.md` — Per-theme Timer Hero subsection documents dispatch and reuse rules
- `.claude/rules/watchos.md` — size-solving rules
- `docs/incidents/2026-06-06-pace-10min.md` — pace rolling-window fix that keeps metric-driven animations stable
