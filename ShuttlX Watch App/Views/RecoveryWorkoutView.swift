import SwiftUI
#if os(watchOS)
import WatchKit
import ShuttlXShared
#endif

/// Single-layout gym-recovery view: BPM is always the hero, a state pill
/// communicates `READY` / `STATION N · station-elapsed` / `REST · rest-elapsed`,
/// and one big contextual button drives the manual flow:
///
///   - `.idle` / `.rest` → "Start Station" (green ctaPrimary)
///   - `.work`           → "End Station"   (red ctaDestructive)
///
/// Designed for 40 mm screens — BPM keeps its 56pt+ size in every state by
/// avoiding side-by-side buttons.
struct RecoveryWorkoutView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var themeManager

    #if os(watchOS)
    private let screenHeight = WKInterfaceDevice.current().screenBounds.height
    #else
    private let screenHeight: CGFloat = 224
    #endif

    var body: some View {
        let h = screenHeight
        let hrSize       = max(48, h * 0.30)   // hero — BIG in every state
        let labelSize    = max(10, h * 0.075)
        let pillSize     = max(11, h * 0.085)
        let buttonHeight = max(36, h * 0.21)

        return VStack(spacing: h * 0.018) {
            // Top row — total elapsed left, state pill right.
            // Mixtape: a small spinning reel rides at the leading edge so the
            // recovery screen carries the same cassette metaphor as the
            // interval / free-run timers (the cassette shell + screws already
            // come from .themedScreenBackground()). Reel spins from elapsedTime
            // and parks when paused — identical behavior to MixtapeReelBadge
            // elsewhere. Other themes render this row unchanged.
            HStack(spacing: 6) {
                if themeManager.current.id == "mixtape" {
                    MixtapeReelBadge(workoutManager: workoutManager, diameter: 22)
                }
                Text(FormattingUtils.formatTimer(workoutManager.elapsedTime))
                    .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(ShuttlXColor.textSecondary)
                Spacer(minLength: 0)
                statePill(pillSize: pillSize)
            }

            // HR hero — always centered, always the largest element.
            VStack(spacing: 2) {
                Text(workoutManager.heartRate > 0 ? "\(workoutManager.heartRate)" : "—")
                    .font(.system(size: hrSize, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(
                        workoutManager.heartRate > 0
                            ? ShuttlXColor.forHRZone(workoutManager.heartRate)
                            : ShuttlXColor.textSecondary
                    )
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 6) {
                    Text("BPM")
                        .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                        .foregroundColor(ShuttlXColor.textSecondary)
                    if workoutManager.heartRate > 0 {
                        Text(hrZoneLabel(workoutManager.heartRate))
                            .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                            .foregroundColor(ShuttlXColor.forHRZone(workoutManager.heartRate))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3)
                                .stroke(ShuttlXColor.forHRZone(workoutManager.heartRate).opacity(0.5), lineWidth: 1))
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(workoutManager.heartRate > 0
                                ? "Heart rate \(workoutManager.heartRate) beats per minute"
                                : "Heart rate no data")
            .accessibilityAddTraits(.updatesFrequently)

            // Rest state inserts the HRR milestone pills directly under HR.
            if workoutManager.recoveryState == .rest {
                HStack(spacing: 6) {
                    milestoneBadge(label: "1:00",
                                   reached: workoutManager.restElapsedTime >= 60,
                                   value: workoutManager.latestHRR1)
                    milestoneBadge(label: "2:00",
                                   reached: workoutManager.restElapsedTime >= 120,
                                   value: workoutManager.latestHRR2)
                }
            }

            Spacer(minLength: 0)

            // Single contextual button — label + color flip on state.
            stationButton(height: buttonHeight, labelSize: labelSize)
        }
        .padding(.horizontal, ShuttlXSpacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - State pill (READY / STATION N · 02:14 / REST · 00:48)

    @ViewBuilder
    private func statePill(pillSize: CGFloat) -> some View {
        switch workoutManager.recoveryState {
        case .idle:
            pillContent(text: "READY", color: ShuttlXColor.textSecondary, pillSize: pillSize)
        case .work:
            // Station number only — no station-elapsed clock here. Total elapsed
            // already shows top-left, and (unlike the REST timer, which feeds the
            // HRR 1:00/2:00 milestones) the station clock drives no feature. With
            // the mixtape reel badge sharing this row, "STATION N · MM:SS" was the
            // longest string and overflowed even 46mm, truncating to "STATION…".
            pillContent(
                text: "STATION \(workoutManager.recoverySetNumber)",
                color: ShuttlXColor.ctaPrimary,
                pillSize: pillSize
            )
        case .rest:
            pillContent(
                text: "REST · \(FormattingUtils.formatTimer(workoutManager.restElapsedTime))",
                color: ShuttlXColor.ctaWarning,
                pillSize: pillSize
            )
        }
    }

    private func pillContent(text: String, color: Color, pillSize: CGFloat) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: pillSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(color)
                .lineLimit(1)
                // 0.5 floor (was 0.7): the WORK-state pill ("STATION 1 · 00:34")
                // is the longest, and the mixtape reel badge now sharing the top
                // row tightened the width — at 0.7 it clipped to "STATION…".
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.12)))
    }

    // MARK: - Contextual station button

    @ViewBuilder
    private func stationButton(height: CGFloat, labelSize: CGFloat) -> some View {
        switch workoutManager.recoveryState {
        case .idle, .rest:
            contextualButton(
                title: "Start Station", icon: "play.fill",
                capColor: ShuttlXColor.ctaPrimary, height: height, labelSize: labelSize,
                accessibilityLabel: "Start Station",
                accessibilityHint: workoutManager.recoveryState == .rest
                    ? "Begins the next station and records this rest period"
                    : "Begins station 1 of your gym recovery workout"
            ) {
                #if os(watchOS)
                WKInterfaceDevice.current().play(.start)
                #endif
                workoutManager.manualStartStation()
            }
        case .work:
            contextualButton(
                title: "End Station", icon: "stop.fill",
                capColor: ShuttlXColor.ctaDestructive, height: height, labelSize: labelSize,
                accessibilityLabel: "End Station",
                accessibilityHint: "Ends station \(workoutManager.recoverySetNumber) and starts a rest period"
            ) {
                #if os(watchOS)
                WKInterfaceDevice.current().play(.stop)
                #endif
                workoutManager.manualEndStation()
            }
        }
    }

    /// The single contextual control. Mixtape renders it as a chunky cassette key
    /// keycap that depresses mechanically on press (reusing the cassette
    /// channel/highlight material from `ThemedTransportButtonStyle.spec`), while
    /// keeping the green=go / red=stop cap color so the Start vs End affordance
    /// stays unambiguous. Every other theme keeps the original CTA capsule.
    @ViewBuilder
    private func contextualButton(title: String, icon: String, capColor: Color,
                                  height: CGFloat, labelSize: CGFloat,
                                  accessibilityLabel: String, accessibilityHint: String,
                                  action: @escaping () -> Void) -> some View {
        let label = HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: labelSize + 2, weight: .bold, design: .monospaced))
        .frame(maxWidth: .infinity)
        .frame(height: height)

        if themeManager.current.id == "mixtape" {
            Button(action: action) { label }
                .buttonStyle(CassetteRecoveryKeyStyle(capColor: capColor))
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(accessibilityHint)
        } else {
            Button(action: action) {
                label
                    .background(Capsule().fill(capColor))
                    .foregroundColor(ShuttlXColor.iconOnCTA)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
        }
    }

    // MARK: - Helpers

    private func hrZoneLabel(_ bpm: Int) -> String {
        guard bpm > 0 else { return "" }
        let pct = Double(bpm) / 185.0
        switch pct {
        case ..<0.60: return "Z1"
        case 0.60..<0.70: return "Z2"
        case 0.70..<0.80: return "Z3"
        case 0.80..<0.90: return "Z4"
        default: return "Z5"
        }
    }

    private func milestoneBadge(label: String, reached: Bool, value: Int?) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            if reached, let v = value {
                Text("-\(v)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(ShuttlXColor.ctaPrimary)
            }
        }
        .foregroundColor(reached ? ShuttlXColor.textPrimary : ShuttlXColor.textSecondary)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4)
            .fill(reached ? ShuttlXColor.positive.opacity(0.25) : ShuttlXColor.surface))
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(reached ? ShuttlXColor.positive.opacity(0.6) : ShuttlXColor.surfaceBorder, lineWidth: 1))
        .accessibilityLabel(reached
                            ? (value != nil ? "\(label) mark: \(value!) BPM drop" : "\(label) reached")
                            : "\(label) mark not yet reached")
    }
}

// MARK: - Cassette keycap style for the recovery control (Mixtape only)
//
// Reuses the cassette channel / highlight / travel / haptic constants from
// `ThemedTransportButtonStyle.spec(for: "mixtape")` so the recovery key feels
// identical to the transport keys on the controls page — but takes an explicit
// `capColor` so Start stays green and End stays red (the shared transport style
// only colors the PLAY key, which would make a destructive End key read silver).
private struct CassetteRecoveryKeyStyle: ButtonStyle {
    let capColor: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let spec = ThemedTransportButtonStyle.spec(for: "mixtape")
        let down = configuration.isPressed
        let travel = reduceMotion ? 0 : (down ? spec.travel : 0)

        return ZStack {
            // Recessed channel the cap sinks into.
            RoundedRectangle(cornerRadius: spec.cornerRadius)
                .fill(spec.channel)

            configuration.label
                .foregroundColor(ShuttlXColor.iconOnCTA)
                .background(
                    RoundedRectangle(cornerRadius: spec.cornerRadius)
                        .fill(LinearGradient(colors: [capColor, capColor.opacity(0.78)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: spec.cornerRadius)
                                .fill(spec.highlight.opacity(down ? 0 : 0.5))
                                .frame(height: 2)
                                .padding(.horizontal, 6)
                                .padding(.top, 1)
                        }
                )
                .padding(down ? 2 : 0)
                .offset(y: travel)
                .shadow(color: .black.opacity(down ? 0.15 : 0.45),
                        radius: down ? 1 : 4, y: down ? 1 : 3)
        }
        .contentShape(Rectangle())
        .sensoryFeedback(spec.haptic, trigger: configuration.isPressed)
    }
}
