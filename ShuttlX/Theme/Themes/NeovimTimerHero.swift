import SwiftUI
import ShuttlXShared

/// Neovim-themed iPhone workout timer hero.
///
/// Renders the **full visible workout body** for the Neovim theme during an
/// active iPhone workout. The composition follows the live `workout.log` nvim
/// buffer concept from `design/proposals/timer-theme-redesigns/neovim.md`:
///
///   - Tabline-style header: file name = workout name, `[+]` modified indicator
///   - Left gutter: 4-digit relative line numbers (current line bright fg)
///   - Buffer body: `AttributedString` log lines with Gruvbox syntax colours —
///     keyword (orange), `=` (fg), value (bright green for numbers),
///     comment (dim gray). The LATEST line is the hero readout at ~60pt.
///   - `CursorLine` highlight (Gruvbox bg1) on the active variable row.
///   - Blinking block cursor (`█`) on the current step-remaining value,
///     driven by `TimelineView(.animation(minimumInterval: 0.5))`.
///   - Status line pinned to the bottom via `safeAreaInset(edge: .bottom)`:
///       `-- INSERT --` (yellow) = WORK
///       `-- NORMAL --` (fg cream) = REST
///       `-- VISUAL --` (cyan) = PAUSED
///       `-- COMMAND --` (red) = finishing/idle
///   - Command-line bar: `:set hr=<N> pace=<X>` live status.
///   - Controls styled as `:wq` / `:q!` / `:stop` / `:pause` command-line
///     entries rendered as touch targets.
///
/// **Read-only on workout state.** All data flows through `controller`; no
/// logic is modified here.
struct NeovimTimerHero: View {

    @ObservedObject var controller: iPhoneWorkoutController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingFinishConfirmation = false
    @State private var showingCancelConfirmation = false

    // Gruvbox Dark palette — hard-wired because this struct is only ever
    // displayed when `themeManager.current.id == "neovim"`.
    private let bg0h     = Color(red: 0.114, green: 0.125, blue: 0.129)  // #1D2021 bg0_hard
    private let bg0      = Color(red: 0.157, green: 0.157, blue: 0.157)  // #282828 bg0
    private let bg1      = Color(red: 0.235, green: 0.220, blue: 0.212)  // #3C3836 bg1 (cursor line)
    private let bg2      = Color(red: 0.314, green: 0.286, blue: 0.271)  // #504945 bg2
    private let bg3      = Color(red: 0.388, green: 0.357, blue: 0.337)  // #665C54 bg3
    private let fg       = Color(red: 0.922, green: 0.859, blue: 0.698)  // #EBDBB2 fg
    private let fgDim    = Color(red: 0.573, green: 0.514, blue: 0.455)  // #928374 gray (gutter / comments)
    private let fgGutter = Color(red: 0.388, green: 0.357, blue: 0.337)  // #665C54 bg3 used for line numbers
    private let red      = Color(red: 0.984, green: 0.286, blue: 0.204)  // #FB4934
    private let green    = Color(red: 0.722, green: 0.733, blue: 0.149)  // #B8BB26
    private let yellow   = Color(red: 0.980, green: 0.741, blue: 0.184)  // #FABD2F
    private let blue     = Color(red: 0.514, green: 0.647, blue: 0.596)  // #83A598
    private let purple   = Color(red: 0.827, green: 0.525, blue: 0.608)  // #D3869B
    private let aqua     = Color(red: 0.557, green: 0.753, blue: 0.486)  // #8EC07C
    private let orange   = Color(red: 0.996, green: 0.502, blue: 0.098)  // #FE8019

    // Gutter constant — matches neovimBackground gutter stripe width
    private let gutterWidth: CGFloat = 48

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Gruvbox background ────────────────────────────────────────
            bg0h.ignoresSafeArea()

            // Left gutter stripe (mirrors neovimBackground on iOS)
            HStack(spacing: 0) {
                bg0.frame(width: gutterWidth)
                    .ignoresSafeArea()
                Spacer()
            }
            .allowsHitTesting(false)

            // ── Foreground ────────────────────────────────────────────────
            VStack(spacing: 0) {
                // Tabline header
                tabline
                    .padding(.top, 8)

                // Divider under tabline
                Rectangle()
                    .fill(bg3)
                    .frame(height: 1)

                // Buffer scroll area
                if reduceMotion {
                    bufferBody(cursorVisible: true)
                } else {
                    TimelineView(.animation(minimumInterval: 0.5)) { tl in
                        let blink = Int(tl.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
                        bufferBody(cursorVisible: blink)
                    }
                }

                Spacer(minLength: 0)

                // Command-line `:set hr=... pace=...`
                commandLine
                    .padding(.horizontal, 0)

                // Status line (modal indicator + ruler)
                statusLine
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Controls bar pinned below the status line
            controlsBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(bg0)
        }
        .ignoresSafeArea(edges: .top)
        .alert("Finish Workout", isPresented: $showingFinishConfirmation) {
            Button("Save & Finish") {
                _ = controller.finish()
                dismiss()
            }
            Button("Discard", role: .destructive) {
                controller.cancel()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this workout to your history?")
        }
        .alert("Cancel Workout?", isPresented: $showingCancelConfirmation) {
            Button("Discard", role: .destructive) {
                controller.cancel()
                dismiss()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("This will end the workout without saving.")
        }
    }

    // MARK: - Tabline

    private var tabline: some View {
        HStack(spacing: 0) {
            // Left gutter placeholder
            Color.clear.frame(width: gutterWidth)

            // Active "buffer" tab
            HStack(spacing: 6) {
                Text("workout.log")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(fg)
                Text("[+]")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(yellow)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(bg0)
            .overlay(
                Rectangle()
                    .fill(orange)
                    .frame(height: 2),
                alignment: .top
            )

            // Remaining tabline space
            Spacer()

            Text("~/workouts/\(todayString)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(fgDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.trailing, 12)
        }
        .frame(height: 34)
        .background(bg1)
        .accessibilityHidden(true)
    }

    private var todayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date()) + ".log"
    }

    // MARK: - Buffer body

    @ViewBuilder
    private func bufferBody(cursorVisible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Line 1 — workout name assignment (header info)
            bufferLine(
                lineNumber: 1,
                isCursorLine: false,
                content: nameLineAttributed
            )

            // Line 2 — elapsed (hero: large display)
            elapsedHeroLine(cursorVisible: cursorVisible)

            // Line 3 — HR
            bufferLine(
                lineNumber: 3,
                isCursorLine: false,
                content: hrLineAttributed
            )

            // Line 4 — pace
            bufferLine(
                lineNumber: 4,
                isCursorLine: false,
                content: paceLineAttributed
            )

            // Line 5 — distance
            bufferLine(
                lineNumber: 5,
                isCursorLine: false,
                content: distLineAttributed
            )

            // Blank line 6
            bufferBlankLine(lineNumber: 6)

            // Lines 7-11: step block (interval mode) or free-run info
            stepBlock(cursorVisible: cursorVisible)

            // Tilde lines (empty buffer markers below content)
            ForEach(0..<3, id: \.self) { i in
                tildeLine(lineNumber: 12 + i)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(bufferA11yLabel)
    }

    // MARK: - Individual buffer lines

    /// A standard `gutter + content` line row.
    private func bufferLine(
        lineNumber: Int,
        isCursorLine: Bool,
        content: AttributedString
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // Gutter (line number)
            Text(String(format: "%4d", lineNumber))
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(isCursorLine ? fg : fgGutter)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 6)

            // Content
            Text(content)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(isCursorLine ? bg1 : Color.clear)
    }

    /// Line 2 hero — shows the most time-critical value at 60pt.
    ///
    /// - Interval mode: shows the current step countdown (`remaining`) so the
    ///   athlete can see exactly how long until the next phase. Elapsed drops to
    ///   a 14pt secondary on the same line (right-aligned).
    /// - Free-run / gym-recovery: shows elapsed as the primary value (no
    ///   step countdown is relevant in those modes).
    private func elapsedHeroLine(cursorVisible: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // Gutter
            Text("   2")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(fg)  // current line = bright
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 6)

            if controller.mode == .interval,
               let engine = controller.intervalEngine {
                // ── Interval: step countdown is the hero ──────────────────
                let remaining = max(0, engine.currentStepTimeRemaining)
                let stepColor = engine.currentStep.map { sharedStepColor($0.type) } ?? green

                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text("remaining")
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundStyle(orange)
                    Text(" = ")
                        .font(.system(size: 18, weight: .regular, design: .monospaced))
                        .foregroundStyle(fg)
                    Text(FormattingUtils.formatTimer(remaining))
                        .font(.system(size: 60, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(stepColor)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if cursorVisible {
                        Text("█")
                            .font(.system(size: 60, weight: .regular, design: .monospaced))
                            .foregroundStyle(fg.opacity(0.85))
                    } else {
                        Text(" ")
                            .font(.system(size: 60, weight: .regular, design: .monospaced))
                    }

                    Spacer(minLength: 4)

                    // Secondary: elapsed in small text
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("elapsed")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(fgDim)
                        Text(FormattingUtils.formatTimer(controller.elapsedTime))
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(fgDim)
                            .contentTransition(.numericText())
                    }
                    .padding(.trailing, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 12)

            } else {
                // ── Free-run / gym-recovery: elapsed is the hero ──────────
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text("elapsed")
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundStyle(orange)
                    Text(" = ")
                        .font(.system(size: 18, weight: .regular, design: .monospaced))
                        .foregroundStyle(fg)
                    Text(FormattingUtils.formatTimer(controller.elapsedTime))
                        .font(.system(size: 60, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(green)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if cursorVisible {
                        Text("█")
                            .font(.system(size: 60, weight: .regular, design: .monospaced))
                            .foregroundStyle(fg.opacity(0.85))
                    } else {
                        Text(" ")
                            .font(.system(size: 60, weight: .regular, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .background(bg1)  // CursorLine highlight always on the hero
    }

    /// A tilde `~` row for below-file visual (standard nvim empty-buffer marker).
    private func tildeLine(lineNumber: Int) -> some View {
        HStack(spacing: 0) {
            Text(String(format: "%4d", lineNumber))
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(bg2)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 6)
            Text("~")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(bg2)
            Spacer()
        }
        .padding(.vertical, 3)
    }

    private func bufferBlankLine(lineNumber: Int) -> some View {
        HStack(spacing: 0) {
            Text(String(format: "%4d", lineNumber))
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(fgGutter)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 6)
            Spacer()
        }
        .padding(.vertical, 3)
    }

    // MARK: - Step block (lines 7-11)

    @ViewBuilder
    private func stepBlock(cursorVisible: Bool) -> some View {
        switch controller.mode {
        case .interval:
            if let engine = controller.intervalEngine, let step = engine.currentStep {
                let appT = appType(for: step.type)
                let stepColor = sharedStepColor(step.type)
                let remaining = engine.currentStepTimeRemaining

                // line 7: `step[N] = {`
                bufferLine(
                    lineNumber: 7,
                    isCursorLine: false,
                    content: stepOpenAttributed(index: engine.currentStepIndex + 1, total: engine.totalStepsCount)
                )
                // line 8: `  type     = "work",`
                bufferLine(
                    lineNumber: 8,
                    isCursorLine: false,
                    content: typeLineAttributed(typeName: appT.displayName, color: stepColor)
                )
                // line 9: `  remaining = MM:SS█` (cursor + CursorLine)
                stepRemainingLine(
                    lineNumber: 9,
                    remaining: remaining,
                    color: stepColor,
                    cursorVisible: cursorVisible
                )
                // line 10: `  target   = MM:SS,`
                bufferLine(
                    lineNumber: 10,
                    isCursorLine: false,
                    content: targetLineAttributed(duration: step.duration)
                )
                // line 11: `}`
                bufferLine(
                    lineNumber: 11,
                    isCursorLine: false,
                    content: closeBraceAttributed
                )
            } else {
                tildeLine(lineNumber: 7)
            }
        case .gymRecovery:
            let gymInfo: (String, TimeInterval) = {
                switch controller.recoveryState {
                case .idle: return ("idle", 0)
                case .work: return ("work", controller.stationElapsedTime)
                case .rest: return ("rest", controller.restElapsedTime)
                }
            }()
            bufferLine(
                lineNumber: 7,
                isCursorLine: false,
                content: gymStateAttributed(state: gymInfo.0, time: gymInfo.1)
            )
            bufferLine(
                lineNumber: 8,
                isCursorLine: false,
                content: stepsAttributed
            )
        case .freeRun:
            bufferLine(
                lineNumber: 7,
                isCursorLine: false,
                content: stepsAttributed
            )
        }
    }

    /// Line 9 inside the step block — secondary elapsed readout.
    ///
    /// In interval mode the hero (line 2) already displays `remaining` at 60pt,
    /// so this line shows `elapsed` as a confirmatory detail at normal size.
    /// The `remaining` and `color` parameters are retained for the accessibility
    /// label but the visual display uses elapsed.
    private func stepRemainingLine(
        lineNumber: Int,
        remaining: TimeInterval,
        color: Color,
        cursorVisible: Bool
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(String(format: "%4d", lineNumber))
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(fgGutter)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 6)

            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("  elapsed")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(orange)
                Text("  = ")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(fg)
                Text(FormattingUtils.formatTimer(controller.elapsedTime))
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(fgDim)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(Color.clear)
    }

    // MARK: - AttributedString builders

    private var nameLineAttributed: AttributedString {
        var s = AttributedString("workout")
        s.foregroundColor = orange
        s.font = .system(size: 14, design: .monospaced)

        var eq = AttributedString(" = ")
        eq.foregroundColor = UIColor(fg)
        eq.font = .system(size: 14, design: .monospaced)

        var name = AttributedString("\"\(controller.workoutName)\"")
        name.foregroundColor = UIColor(green)
        name.font = .system(size: 14, weight: .medium, design: .monospaced)

        return s + eq + name
    }

    private var hrLineAttributed: AttributedString {
        let bpm = controller.heartRateMonitor.current
        let valueStr = bpm > 0 ? "\(bpm)bpm" : "—"
        let zoneStr = bpm > 0 ? "  -- zone: \(hrZoneLabel(bpm))" : ""

        var key = AttributedString("hr")
        key.foregroundColor = UIColor(orange)
        key.font = .system(size: 14, design: .monospaced)

        var pad = AttributedString("      ")
        pad.foregroundColor = UIColor(fg)
        pad.font = .system(size: 14, design: .monospaced)

        var eq = AttributedString(" = ")
        eq.foregroundColor = UIColor(fg)
        eq.font = .system(size: 14, design: .monospaced)

        var val = AttributedString(valueStr)
        val.foregroundColor = UIColor(bpm > 0 ? ShuttlXColor.forHRZone(bpm) : fgDim)
        val.font = .system(size: 14, weight: .semibold, design: .monospaced)

        var comment = AttributedString(zoneStr)
        comment.foregroundColor = UIColor(fgDim)
        comment.font = .system(size: 13, design: .monospaced)

        return key + pad + eq + val + comment
    }

    private var paceLineAttributed: AttributedString {
        let paceStr = controller.currentPace.map { FormattingUtils.formatPace($0) } ?? "—"
        let unitStr = controller.currentPace != nil ? " / km" : ""

        var key = AttributedString("pace")
        key.foregroundColor = UIColor(orange)
        key.font = .system(size: 14, design: .monospaced)

        var pad = AttributedString("    ")
        pad.foregroundColor = UIColor(fg)
        pad.font = .system(size: 14, design: .monospaced)

        var eq = AttributedString(" = ")
        eq.foregroundColor = UIColor(fg)
        eq.font = .system(size: 14, design: .monospaced)

        var val = AttributedString(paceStr)
        val.foregroundColor = UIColor(purple)
        val.font = .system(size: 14, weight: .semibold, design: .monospaced)

        var unit = AttributedString(unitStr)
        unit.foregroundColor = UIColor(fgDim)
        unit.font = .system(size: 13, design: .monospaced)

        return key + pad + eq + val + unit
    }

    private var distLineAttributed: AttributedString {
        let distStr = FormattingUtils.formatDistance(controller.totalDistance)

        var key = AttributedString("dist")
        key.foregroundColor = UIColor(orange)
        key.font = .system(size: 14, design: .monospaced)

        var pad = AttributedString("    ")
        pad.foregroundColor = UIColor(fg)
        pad.font = .system(size: 14, design: .monospaced)

        var eq = AttributedString(" = ")
        eq.foregroundColor = UIColor(fg)
        eq.font = .system(size: 14, design: .monospaced)

        var val = AttributedString("\(distStr) km")
        val.foregroundColor = UIColor(aqua)
        val.font = .system(size: 14, weight: .semibold, design: .monospaced)

        return key + pad + eq + val
    }

    private var stepsAttributed: AttributedString {
        var key = AttributedString("steps")
        key.foregroundColor = UIColor(orange)
        key.font = .system(size: 14, design: .monospaced)

        var pad = AttributedString("   ")
        pad.foregroundColor = UIColor(fg)
        pad.font = .system(size: 14, design: .monospaced)

        var eq = AttributedString(" = ")
        eq.foregroundColor = UIColor(fg)
        eq.font = .system(size: 14, design: .monospaced)

        var val = AttributedString("\(controller.totalSteps)")
        val.foregroundColor = UIColor(yellow)
        val.font = .system(size: 14, weight: .semibold, design: .monospaced)

        return key + pad + eq + val
    }

    private func stepOpenAttributed(index: Int, total: Int) -> AttributedString {
        var key = AttributedString("step")
        key.foregroundColor = UIColor(orange)
        key.font = .system(size: 14, design: .monospaced)

        var idx = AttributedString("[\(index)/\(total)]")
        idx.foregroundColor = UIColor(yellow)
        idx.font = .system(size: 14, design: .monospaced)

        var rest = AttributedString(" = {")
        rest.foregroundColor = UIColor(fg)
        rest.font = .system(size: 14, design: .monospaced)

        return key + idx + rest
    }

    private func typeLineAttributed(typeName: String, color: Color) -> AttributedString {
        var pad = AttributedString("  type     ")
        pad.foregroundColor = UIColor(orange)
        pad.font = .system(size: 14, design: .monospaced)

        var eq = AttributedString("= ")
        eq.foregroundColor = UIColor(fg)
        eq.font = .system(size: 14, design: .monospaced)

        var val = AttributedString("\"\(typeName.lowercased())\"")
        val.foregroundColor = UIColor(color)
        val.font = .system(size: 14, weight: .semibold, design: .monospaced)

        var comma = AttributedString(",")
        comma.foregroundColor = UIColor(fg)
        comma.font = .system(size: 14, design: .monospaced)

        return pad + eq + val + comma
    }

    private func targetLineAttributed(duration: TimeInterval) -> AttributedString {
        var pad = AttributedString("  target   ")
        pad.foregroundColor = UIColor(orange)
        pad.font = .system(size: 14, design: .monospaced)

        var eq = AttributedString("= ")
        eq.foregroundColor = UIColor(fg)
        eq.font = .system(size: 14, design: .monospaced)

        var val = AttributedString("\(FormattingUtils.formatTimer(duration)),")
        val.foregroundColor = UIColor(green)
        val.font = .system(size: 14, design: .monospaced)

        return pad + eq + val
    }

    private var closeBraceAttributed: AttributedString {
        var s = AttributedString("}")
        s.foregroundColor = UIColor(fg)
        s.font = .system(size: 14, design: .monospaced)
        return s
    }

    private func gymStateAttributed(state: String, time: TimeInterval) -> AttributedString {
        var key = AttributedString("state")
        key.foregroundColor = UIColor(orange)
        key.font = .system(size: 14, design: .monospaced)

        var pad = AttributedString("   ")
        pad.foregroundColor = UIColor(fg)
        pad.font = .system(size: 14, design: .monospaced)

        var eq = AttributedString(" = ")
        eq.foregroundColor = UIColor(fg)
        eq.font = .system(size: 14, design: .monospaced)

        var val = AttributedString("\"\(state)\"")
        val.foregroundColor = UIColor(state == "rest" ? blue : red)
        val.font = .system(size: 14, weight: .semibold, design: .monospaced)

        let timeStr = time > 0 ? "  -- \(FormattingUtils.formatTimer(time))" : ""
        var comment = AttributedString(timeStr)
        comment.foregroundColor = UIColor(fgDim)
        comment.font = .system(size: 13, design: .monospaced)

        return key + pad + eq + val + comment
    }

    // MARK: - Command line

    private var commandLine: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth)
            Text(commandLineText)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(fgDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 3)
                .padding(.trailing, 12)
            Spacer()
        }
        .background(bg0)
        .accessibilityHidden(true)
    }

    private var commandLineText: String {
        let bpm = controller.heartRateMonitor.current
        let hrPart = bpm > 0 ? "hr=\(bpm)" : "hr=—"
        let pacePart: String = {
            guard let pace = controller.currentPace else { return "pace=—" }
            return "pace=\(FormattingUtils.formatPace(pace))"
        }()
        return ":\(hrPart) \(pacePart) dist=\(FormattingUtils.formatDistance(controller.totalDistance))km"
    }

    // MARK: - Status line (modal indicator + ruler)

    private var statusLine: some View {
        HStack(spacing: 0) {
            // Gutter placeholder (same width as left gutter)
            Color.clear.frame(width: 0)

            // Mode pill
            HStack(spacing: 0) {
                Text(" \(modeString) ")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(bg0h)
                    .background(modeColor)
            }

            Spacer(minLength: 4)

            // Workout name in the centre
            Text(controller.workoutName)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(fg.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            // Ruler: line,col     progress%
            Text(rulerText)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(fgDim)
                .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .background(bg1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout mode: \(modeString). Progress \(Int(workoutProgress * 100)) percent")
    }

    private var modeString: String {
        if controller.isPaused { return "-- VISUAL --" }
        switch controller.mode {
        case .freeRun: return "-- INSERT --"
        case .interval:
            guard let step = controller.intervalEngine?.currentStep else { return "-- NORMAL --" }
            let appT = appType(for: step.type)
            switch appT {
            case .work:     return "-- INSERT --"
            case .rest:     return "-- NORMAL --"
            case .warmup:   return "-- INSERT --"
            case .cooldown: return "-- NORMAL --"
            }
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle: return "-- COMMAND --"
            case .work: return "-- INSERT --"
            case .rest: return "-- NORMAL --"
            }
        }
    }

    private var modeColor: Color {
        if controller.isPaused { return aqua }
        let mode = modeString
        switch mode {
        case "-- INSERT --":  return yellow
        case "-- NORMAL --":  return blue
        case "-- VISUAL --":  return aqua
        case "-- COMMAND --": return red
        default:              return fgDim
        }
    }

    /// nvim-style ruler: `<line>,<col>     <percent>%`
    /// Here line = current step index (1-based), col = step seconds elapsed,
    /// percent = workout completion %.
    private var rulerText: String {
        let line: Int
        let col: Int
        switch controller.mode {
        case .freeRun:
            line = 2
            col = Int(controller.elapsedTime) % 60
        case .interval:
            line = (controller.intervalEngine?.currentStepIndex ?? 0) + 7
            let remaining = controller.intervalEngine?.currentStepTimeRemaining ?? 0
            let stepDur = controller.intervalEngine?.currentStep?.duration ?? 1
            col = max(0, Int(stepDur - remaining))
        case .gymRecovery:
            line = controller.recoverySetNumber + 6
            col = Int(controller.stationElapsedTime) % 60
        }
        let pct = Int(workoutProgress * 100)
        return "\(line),\(String(format: "%02d", col))      \(pct)%"
    }

    private var workoutProgress: Double {
        switch controller.mode {
        case .freeRun:
            return min(1.0, controller.elapsedTime / 1800.0)
        case .interval:
            let engine = controller.intervalEngine
            let remaining = engine?.currentStepTimeRemaining ?? 0
            let approxTotal = controller.elapsedTime + remaining
            guard approxTotal > 0 else { return 0 }
            return min(1.0, controller.elapsedTime / approxTotal)
        case .gymRecovery:
            return min(1.0, controller.elapsedTime / 1800.0)
        }
    }

    // MARK: - Controls bar (`:cmd` styled buttons)

    private var controlsBar: some View {
        HStack(spacing: 10) {
            // :q! — cancel without saving
            cmdButton(
                label: ":q!",
                a11yLabel: "Cancel workout",
                a11yHint: "Ends without saving",
                color: red,
                background: bg1
            ) {
                showingCancelConfirmation = true
            }

            // :skip — skip current step (interval only)
            if controller.mode == .interval, controller.intervalEngine?.isComplete == false {
                cmdButton(
                    label: ":next",
                    a11yLabel: "Skip step",
                    a11yHint: "Advances to the next step",
                    color: aqua,
                    background: bg1
                ) {
                    controller.skipStep()
                }
            }

            // :pause / :resume — primary wide button
            Button {
                if controller.isPaused { controller.resume() } else { controller.pause() }
            } label: {
                Text(controller.isPaused ? ":resume" : ":pause")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(bg0h)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(controller.isPaused ? aqua : yellow)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke((controller.isPaused ? aqua : yellow).opacity(0.5), lineWidth: 1)
                    )
            }
            .accessibilityLabel(controller.isPaused ? "Resume workout" : "Pause workout")

            // :wq — save and quit
            cmdButton(
                label: ":wq",
                a11yLabel: "Finish workout",
                a11yHint: "Saves and ends",
                color: green,
                background: bg1
            ) {
                showingFinishConfirmation = true
            }
        }
    }

    private func cmdButton(
        label: String,
        a11yLabel: String,
        a11yHint: String,
        color: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .frame(width: 60, height: 52)
                .foregroundStyle(color)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(background)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(color.opacity(0.4), lineWidth: 1)
                        )
                )
        }
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(a11yHint)
    }

    // MARK: - Accessibility

    private var bufferA11yLabel: String {
        let elapsed = FormattingUtils.formatTimeAccessible(controller.elapsedTime)
        let bpm = controller.heartRateMonitor.current
        let hrStr = bpm > 0 ? "Heart rate \(bpm) beats per minute, \(hrZoneLabel(bpm)). " : ""
        switch controller.mode {
        case .freeRun:
            return "Elapsed \(elapsed). \(hrStr)Distance \(FormattingUtils.formatDistance(controller.totalDistance)) kilometers."
        case .interval:
            let remaining = controller.intervalEngine?.currentStepTimeRemaining ?? 0
            let stepName = controller.intervalEngine?.currentStep.map { appType(for: $0.type).displayName } ?? "step"
            return "Elapsed \(elapsed). \(hrStr)Time remaining in \(stepName), \(FormattingUtils.formatTimeAccessible(remaining))."
        case .gymRecovery:
            return "Elapsed \(elapsed). \(hrStr)Station \(controller.recoverySetNumber)."
        }
    }

    // MARK: - Helpers (mirrors iPhoneWorkoutTimerView helpers)

    private func appType(for sharedType: ShuttlXShared.IntervalType) -> IntervalType {
        IntervalType(rawValue: sharedType.rawValue) ?? .work
    }

    private func sharedStepColor(_ sharedType: ShuttlXShared.IntervalType) -> Color {
        ShuttlXColor.forStepType(appType(for: sharedType))
    }

    private func hrZoneLabel(_ bpm: Int) -> String {
        guard bpm > 0 else { return "" }
        let pct = Double(bpm) / 185.0
        switch pct {
        case ..<0.60:      return "Z1"
        case 0.60..<0.70:  return "Z2"
        case 0.70..<0.80:  return "Z3"
        case 0.80..<0.90:  return "Z4"
        default:           return "Z5"
        }
    }
}

#if DEBUG
#Preview("Neovim Hero — Free Run") {
    let controller = iPhoneWorkoutController()
    NeovimTimerHero(controller: controller)
        .environment(ThemeManager.shared)
}
#endif
