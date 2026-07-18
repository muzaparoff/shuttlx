---
description: "@Observable and theme-system correctness checklist for ShuttlX — tracking gotchas, bridge re-render gap, theme sync, mirrored-file drift"
user_invocable: true
---

# /observable-theme-patterns

Apply when writing or reviewing any code in `Theme/` directories, `ThemeManager`, or views that must react to live theme changes.

## @Observable tracking rules

- [ ] `@Observable` only tracks **stored** properties — computed properties do NOT trigger view updates. `ThemeManager.current` is stored for exactly this reason; keep it stored.
- [ ] Avoid `didSet` on `@Observable` properties — use explicit methods (`selectTheme(id)`), never set `selectedThemeID` directly.
- [ ] **Bridge tokens DO track (verified July 2026)**: `ShuttlXColor.*` / `ShuttlXFont.*` static computed props read the stored `current` property synchronously inside the body's observation scope, so Observation registers the dependency and bridge-only views DO re-render on theme change. Do NOT add `@Environment(ThemeManager.self)` as ceremony. The tracking breaks only if a token is read OUTSIDE a body scope: cached into a stored `let` at init, read in an escaping/deferred closure, or used via an imperative UIKit path — flag those patterns in review.

## Theme sync flow (end-to-end)

iPhone `selectTheme(id)` → App Group UserDefaults `selectedThemeID` → `sendThemeToWatch()` via applicationContext `"syncTheme"` → watch `handleIncomingPayload` → `ThemeManager.shared.selectedThemeID` → UI re-render.

- [ ] Theme application on the watch must be atomic — no partial re-render states.
- [ ] applicationContext writers must merge, never clobber the `"syncTheme"` key (see /wcsession-sync-review).
- [ ] Verify theme changes end-to-end on device, not just compilation.

## Mirrored-file drift (15 files × 2 targets)

- [ ] `ShuttlX/Theme/` and `ShuttlX Watch App/Theme/` are hand-mirrored — every theme change must update BOTH. When reviewing, diff the counterpart file for drift.
- [ ] Theme dispatch switches (e.g. `ThemedCompletionBadge`) must cover ALL 7 theme ids: `clean`, `synthwave`, `mixtape`, `arcade`, `classicradio`, `neovim`, `fmtuner`. A missing case silently falls back to Clean — when adding a theme, grep for every `switch` on theme id in BOTH targets.
- [ ] TrainingSession/WorkoutTemplate are also duplicated per target — keep byte-identical (watch-parity guard test in `swift test`).

## Design-system compliance on themed surfaces

- [ ] Themed surfaces (dashboard hero, analytics viz, workout summary, empty states, watch home, timer) must dispatch on `themeManager.current.id` — theme-colored stock SwiftUI is not enough.
- [ ] Raw semantic fonts (`.font(.body)`, `.font(.headline)`) are violations on themed surfaces — use `ShuttlXFont.*`.
- [ ] Neutral surfaces (forms, settings, paywall, editors) use theme colors only — keep legible.
- [ ] One parametric Canvas per theme signature shape — never N illustrations per state.
- [ ] Dead code check: chrome state on ThemeManager (`vuMeterValue`, `signalStrength`, `footerStatusLines`, `chromeVisible`) is currently never written by shipped code — do not build on it without wiring it up first.
