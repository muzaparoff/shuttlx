import SwiftUI

// MARK: - Neovim watchOS workout hero chrome
//
// Watch-adapted Neovim timer chrome. The iPhone variant renders a full nvim
// buffer view: 11 visible lines of Lua/Vimscript-styled metric assignments, a
// multi-line `step[3] = { ... }` block, the `~` empty-line tilde column,
// `workout.log [+]` file-info status line, line-number gutter, a CursorLine
// highlight, plus the `:` command line and ruler at the very bottom.
//
// On the 41mm watch we cannot show 11 lines without each one becoming
// illegible, and we must not overlap the page-indicator dots at the bottom.
// Per design/proposals/timer-theme-redesigns/neovim-watch.md we keep only the
// three brand-defining elements that survive at this size:
//
//   * Top tabline strip — `workout.log` filename rendered like an nvim buffer
//     tab so the user reads "this is a code editor", not "this is a watch face"
//   * Left gutter column with a single bright line number (nvim's brand cue)
//   * Bottom modal status line — `-- INSERT --` / `-- NORMAL --` / `-- VISUAL --`
//     that switches off controller state (WORK / REST or free-run / PAUSED).
//     This is the *single* element that signals workout state in the nvim
//     vocabulary; it replaces the iPhone variant's per-line color runs.
//
// What we cut from the iPhone version:
//   * 11-line buffer view — trimmed: base TrainingView paints the metrics
//   * Multi-line `step[3] = { type, remaining, target }` block
//   * Per-line `:` command line at very bottom (would overlap page-dots)
//   * `<line>,<col> <percent>%` ruler
//   * `~` tilde column for empty lines (we don't render empty lines)
//   * `workout.log [+]` file-info status (the tabline header carries it)
//
// IMPORTANT: this overlay is purely decorative. It uses
// `.allowsHitTesting(false)` so the crown, swipe, and tap targets in
// TrainingView are untouched. It does not modify timer text, the HR row,
// or any workout logic.

struct NeovimTimerOverlay: View {
    @ObservedObject var workoutManager: WatchWorkoutManager

    // Gruvbox palette (mirrors NeovimTheme tokens)
    private var bg0: Color { Color(red: 0.114, green: 0.125, blue: 0.129) }       // #1D2021 bg0_h
    private var bg1: Color { Color(red: 0.235, green: 0.220, blue: 0.212) }       // #3C3836 bg1
    private var bg2: Color { Color(red: 0.314, green: 0.286, blue: 0.271) }       // #504945 bg2
    private var fg: Color { Color(red: 0.922, green: 0.859, blue: 0.698) }        // #EBDBB2 fg
    private var grayDim: Color { Color(red: 0.486, green: 0.435, blue: 0.392) }   // #7C6F64 gutter gray
    private var yellow: Color { Color(red: 0.980, green: 0.741, blue: 0.184) }    // #FABD2F bright yellow
    private var blue: Color { Color(red: 0.514, green: 0.647, blue: 0.596) }      // #83A598 blue
    private var green: Color { Color(red: 0.722, green: 0.733, blue: 0.149) }     // #B8BB26 green

    /// Tabline height — slim, just enough room for one 10pt monospaced filename
    /// glyph plus a couple of points of vertical breathing room.
    private let tablineHeight: CGFloat = 14

    /// Modal status line height — sized to clear the page-indicator dot row
    /// (nvim's status line sits ABOVE the command line in real life, so it
    /// being above the page dots is metaphor-correct).
    private let statusLineHeight: CGFloat = 14

    /// Left gutter strip width — narrow enough not to crowd the metrics column,
    /// wide enough that a 9pt line-number digit reads.
    private let gutterWidth: CGFloat = 10

    /// Modal indicator string driven by workout state.
    ///
    /// * PAUSED -> `-- VISUAL --` (blue) — selection mode, no input flowing
    /// * Interval WORK -> `-- INSERT --` (yellow) — actively writing into the buffer
    /// * Interval REST / WARMUP / COOLDOWN -> `-- NORMAL --` (white) — between edits
    /// * Free-run / gym -> `-- NORMAL --` (white) — no interval state to signal
    ///
    /// Yellow for INSERT mirrors the iPhone variant's bright-yellow status line.
    private var modeText: String {
        if workoutManager.isPaused { return "-- VISUAL --" }
        if workoutManager.workoutMode == .interval,
           let step = workoutManager.intervalEngine?.currentStep,
           step.type == .work {
            return "-- INSERT --"
        }
        return "-- NORMAL --"
    }

    private var modeColor: Color {
        if workoutManager.isPaused { return blue }
        if workoutManager.workoutMode == .interval,
           let step = workoutManager.intervalEngine?.currentStep,
           step.type == .work {
            return yellow
        }
        return fg
    }

    /// Tabline filename — `workout.log` for free-run, derived slug for templates.
    /// The trailing `[+]` mimics nvim's "modified buffer" marker since the
    /// workout is continuously appending data.
    private var bufferName: String {
        let raw = workoutManager.workoutName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        let trimmed = raw.isEmpty ? "workout" : String(raw.prefix(12))
        return "\(trimmed).log [+]"
    }

    var body: some View {
        ZStack {
            // Top tabline + left gutter form an L-shape around the metrics.
            VStack(spacing: 0) {
                tablineStrip
                    .frame(height: tablineHeight)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                statusLine
                    .frame(height: statusLineHeight)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                gutterStrip
                    .frame(width: gutterWidth)
                    .frame(maxHeight: .infinity)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Tabline strip
    //
    // A horizontal strip representing the nvim tabline at the top of every
    // buffer view. We don't draw multiple tabs — one is enough to carry the
    // metaphor at glance distance. A faint bottom hairline separates the tab
    // from the buffer body, matching nvim's default `WinSeparator` color.
    private var tablineStrip: some View {
        ZStack {
            Rectangle()
                .fill(bg1.opacity(0.85))

            HStack(spacing: 4) {
                // Active tab "swatch" — bright fill, slightly lighter than the
                // tabline base, with a 1pt yellow underline (nvim's `TabLineSel`).
                HStack(spacing: 3) {
                    Text(bufferName)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(fg)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    Rectangle().fill(bg2.opacity(0.7))
                )
                .overlay(
                    Rectangle()
                        .fill(yellow.opacity(0.9))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                )

                Spacer(minLength: 0)
            }
            .padding(.leading, gutterWidth + 2)
            .padding(.trailing, 4)

            // Hairline at the bottom of the tabline — separates from buffer.
            VStack {
                Spacer()
                Rectangle()
                    .fill(bg2.opacity(0.6))
                    .frame(height: 0.5)
            }
        }
    }

    // MARK: - Gutter strip
    //
    // Vertical strip on the left edge mimicking the nvim line-number gutter.
    // The `neovimBackground` background modifier already paints a faint solid
    // gutter on iOS but on watchOS it falls back to a plain solid color, so we
    // re-add a slightly lighter band here ourselves. A single bright "current
    // line" number sits roughly where the hero timer is centered — a small but
    // unmistakable brand cue.
    private var gutterStrip: some View {
        ZStack(alignment: .center) {
            // Faint background band — just barely lighter than bg0 so the
            // gutter reads as an inset column without competing with the
            // timer's color wash.
            Rectangle()
                .fill(bg2.opacity(0.25))

            // Right edge hairline — separates gutter from the buffer body.
            HStack {
                Spacer()
                Rectangle()
                    .fill(bg2.opacity(0.5))
                    .frame(width: 0.5)
            }

            // Single bright line number aligned with the timer hero. nvim's
            // `CursorLineNr` highlight makes the active line yellow; we mirror
            // that since the hero timer IS the active line in our metaphor.
            VStack(spacing: 0) {
                Spacer()
                Text("2")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(yellow.opacity(0.85))
                    .monospacedDigit()
                Spacer()
            }
            .padding(.top, tablineHeight)
            .padding(.bottom, statusLineHeight)
        }
    }

    // MARK: - Status line
    //
    // Bottom-pinned modal indicator. In real nvim this is the line where
    // `-- INSERT --` flashes when you press `i`. We pin it above the page
    // indicator zone (the page dots TabView renders) by limiting our overlay
    // height to ~14pt — the indicator dots still get their bottom edge.
    //
    // The text is centered, monospaced, and color-coded:
    //   * yellow  -> INSERT (WORK)
    //   * white   -> NORMAL (REST / free-run)
    //   * blue    -> VISUAL (PAUSED)
    private var statusLine: some View {
        ZStack {
            Rectangle()
                .fill(bg1.opacity(0.85))

            // Top hairline — separates buffer body from status line.
            VStack {
                Rectangle()
                    .fill(bg2.opacity(0.6))
                    .frame(height: 0.5)
                Spacer()
            }

            Text(modeText)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(modeColor)
                .lineLimit(1)
                .padding(.leading, gutterWidth + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
