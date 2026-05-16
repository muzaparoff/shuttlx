import SwiftUI
#if os(watchOS)
import WatchKit
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
            // Top row — total elapsed left, state pill right
            HStack(spacing: 6) {
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
            pillContent(
                text: "STATION \(workoutManager.recoverySetNumber) · \(FormattingUtils.formatTimer(workoutManager.stationElapsedTime))",
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
                .minimumScaleFactor(0.7)
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
            Button {
                #if os(watchOS)
                WKInterfaceDevice.current().play(.start)
                #endif
                workoutManager.manualStartStation()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                    Text("Start Station")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: labelSize + 2, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Capsule().fill(ShuttlXColor.ctaPrimary))
                .foregroundColor(ShuttlXColor.iconOnCTA)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start Station")
            .accessibilityHint(workoutManager.recoveryState == .rest
                               ? "Begins the next station and records this rest period"
                               : "Begins station 1 of your gym recovery workout")
        case .work:
            Button {
                #if os(watchOS)
                WKInterfaceDevice.current().play(.stop)
                #endif
                workoutManager.manualEndStation()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                    Text("End Station")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: labelSize + 2, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Capsule().fill(ShuttlXColor.ctaDestructive))
                .foregroundColor(ShuttlXColor.iconOnCTA)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End Station")
            .accessibilityHint("Ends station \(workoutManager.recoverySetNumber) and starts a rest period")
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
