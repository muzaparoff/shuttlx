# Neovim Timer — Watch Variant

## 1. Watch-adapted hero metaphor

Same `nvim` buffer — but the buffer is **trimmed to 4 visible lines** plus the modal status line. The elapsed time is still presented as a **variable assignment** (`elapsed = 03:24`) but is rendered at hero size (40pt mono), breaking the "everything is one font size" rule because glanceability beats verisimilitude. The line-number gutter survives (it's the brand). The `step[3] = { ... }` multi-line block from iPhone collapses to a single line.

## 2. What's cut from the iPhone version

- The 11-line buffer view — trimmed to 4 lines (`elapsed`, `hr`, `step`, one of pace/dist)
- The multi-line `step[3] = { type, remaining, target }` block — collapsed to one line
- The `:` command line at the very bottom — dropped (overlaps page-indicator dots)
- The ruler `<line>,<col> <percent>%` — dropped
- The `~` tilde column for empty lines — dropped (we only show 4 lines, no empties)
- `workout.log [+]` file-info status line — dropped

## 3. Five elements on screen (priority order)

1. `elapsed = 03:24` line, with `03:24` rendered at hero size (40pt mono, Gruvbox bright-green)
2. Modal status line — `-- INSERT --` / `-- NORMAL --` / `-- VISUAL --` (14pt, Gruvbox bright-yellow, bottom)
3. `hr = 142  -- zone 3` line (16pt, mono)
4. `step = work 02:12` line (16pt, mono, on the CursorLine highlight w/ blinking `█`)
5. Line-number gutter `1 2 3 4` (12pt, dim gray `#7C6F64`, left edge)

## 4. ASCII layout (30 col)

```
 1  elapsed =
 2
 2    0 3 : 2 4   ← hero
 2
 3  hr = 142  -- z3
 4  step = work 02:12█
 ────────────────────────
 -- INSERT --
```

## 5. SwiftUI primitives

- `VStack(alignment: .leading, spacing: 4)` of `Text` views (the buffer lines) — each line is an `AttributedString` composed of Gruvbox-colored runs (keyword orange, `=` fg, number bright-green).
- Hero time: a SECOND `Text` inside line 2, sized via `ShuttlXFont.timerDisplay` (~40pt), `.monospacedDigit()`. The "line 2" gutter number repeats vertically beside the hero to fake it spanning multiple visual rows.
- Cursor block: a `Text("█")` toggled via `TimelineView(.animation(minimumInterval: 0.5))` between `█` and ` `, appended to the `step` line.
- Modal line: a single `Text` pinned via `safeAreaInset(edge: .bottom)`, switches string off controller state — but inset uses small height (~18pt) so it sits ABOVE the page-indicator zone.
- Gutter: handled by existing `neovimBackground` left stripe + a `VStack` of right-aligned `Text` line-number labels.
- No Canvas needed.
