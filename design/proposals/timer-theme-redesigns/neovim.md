# Neovim Timer — Terminal Text Editor Buffer

## 1. Hero concept

The screen is a **live `nvim` buffer running a fictional `workout.log`**. The hero is not a number — it's the **buffer's content area** rendered as code, with the elapsed time appearing as the value of a variable being live-edited. Line numbers in the gutter, syntax-highlighted Gruvbox tokens, the cursor block (`█`) blinking on the current step's line. The **modal status line** at the bottom switches: `-- INSERT --` while WORK, `-- NORMAL --` while REST, `-- VISUAL --` while paused. The command line at the very bottom shows the elapsed/total like a `:` command.

```
   ~/workouts/2026-06-06.log                       
   1  workout = "5x400m intervals"                 
   2  elapsed = 00:03:24                           ← time as variable
   3  hr      = 142    -- zone: 3 (cardio)         
   4  pace    = 5:42 / km                          
   5  dist    = 1.84 km                            
   6                                               
   7  step[3] = {                                  
   8    type     = "work",                         
   9    remaining = 02:12█  ← cursor               
   10   target   = 03:00,                          
   11 }                                            
   ~                                               
   ~                                               
   workout.log [+]                    3,11      45%
   -- INSERT --                                    
   :                            elapsed 03:24 / —  
```

## 2. Secondary metrics layout

Everything is a **variable assignment line in the buffer**. HR, pace, distance, step are each a syntax-highlighted line: keyword (orange/Gruvbox `bright_red`), `=`, value (Gruvbox `bright_green` for numbers). The current step is the line under the cursor — highlighted with the `CursorLine` Gruvbox background. The **right side of the status line** shows the standard nvim ruler `<line>,<col>     <percent>%` — but `<percent>` is the workout completion %.

## 3. Background composition

Existing `neovimBackground` (#1D2021 solid + left gutter stripe iOS) stays. Add **line numbers in the gutter** (4-digit, right-aligned, dim gray `#7C6F64`) and a **tilde column** below the file's last line — both are Neovim-canonical empty-buffer markers.

## 4. SwiftUI primitives

- `Text` with `AttributedString` — single text view per line, runs of Gruvbox tokens; mono font already comes from the theme.
- `TimelineView(.animation(minimumInterval: 0.5))` — drives the cursor block blink (`█` ↔ ` `).
- `ZStack` — buffer content (a `VStack` of `Text` lines), status line pinned to bottom via `safeAreaInset(edge: .bottom)`.
- `Canvas` (optional) — could draw the gutter stripe + sign column dots, but the existing `neovimBackground` already paints the gutter; just add a `VStack` of `Text("\(lineNumber)")` aligned right.

## 5. Reuse note

Each "variable line" is a tiny computed `AttributedString` from existing controller fields. Cursor position = current interval step index. The percent in the ruler = `elapsedTime / plannedDuration`. The mode-line (`INSERT/NORMAL/VISUAL`) maps to the existing controller state (`work/rest/paused`) with a `switch`. Zero workout-logic touched.
