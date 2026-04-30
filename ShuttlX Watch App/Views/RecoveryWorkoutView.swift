import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct RecoveryWorkoutView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    #if os(watchOS)
    private let screenHeight = WKInterfaceDevice.current().screenBounds.height
    #else
    private let screenHeight: CGFloat = 224
    #endif

    var body: some View {
        switch workoutManager.recoveryState {
        case .idle:
            idleView
        case .work:
            workView
        case .rest:
            restView
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        let h = screenHeight
        let hrSize = max(34, h * 0.21)
        let labelSize = max(10, h * 0.075)
        let ringSize = h * 0.40
        let progress = workoutManager.stationCandidateProgress

        return VStack(spacing: h * 0.02) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                    .frame(width: ringSize, height: ringSize)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.green.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
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
                    Text("BPM")
                        .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                        .foregroundColor(ShuttlXColor.textSecondary)
                }
            }
            Text(progress > 0 ? "Detecting..." : "Sit on machine")
                .font(.system(size: labelSize, weight: .regular, design: .monospaced))
                .foregroundColor(progress > 0 ? ShuttlXColor.ctaPrimary : ShuttlXColor.textSecondary)
                .animation(.easeInOut, value: progress > 0)
            Text(FormattingUtils.formatTimer(workoutManager.elapsedTime))
                .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(ShuttlXColor.textSecondary)
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            progress > 0
                ? "Detecting station. Heart rate \(workoutManager.heartRate) BPM."
                : "Heart recovery monitoring ready. Sit on machine to begin."
        )
    }

    // MARK: - Work

    private var workView: some View {
        let h = screenHeight
        let hrSize = max(44, h * 0.26)
        let labelSize = max(10, h * 0.08)
        let stationTimeSize = max(12, h * 0.09)

        return VStack(spacing: h * 0.018) {
            Text("Station \(workoutManager.recoverySetNumber)")
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.ctaPrimary)

            Text(workoutManager.heartRate > 0 ? "\(workoutManager.heartRate)" : "---")
                .font(.system(size: hrSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(ShuttlXColor.forHRZone(workoutManager.heartRate))
                .contentTransition(.numericText())

            Text("BPM")
                .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                .foregroundColor(ShuttlXColor.textSecondary)

            Text(hrZoneLabel(workoutManager.heartRate))
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.forHRZone(workoutManager.heartRate))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ShuttlXColor.forHRZone(workoutManager.heartRate).opacity(0.15))
                )
                .opacity(workoutManager.heartRate > 0 ? 1 : 0)

            HStack(spacing: 6) {
                Text("Station")
                    .font(.system(size: labelSize, weight: .regular, design: .monospaced))
                    .foregroundColor(ShuttlXColor.textSecondary)
                Text(FormattingUtils.formatTimer(workoutManager.stationElapsedTime))
                    .font(.system(size: stationTimeSize, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(ShuttlXColor.textPrimary)
            }
            .padding(.top, 4)

            if workoutManager.currentCadence > 0 {
                HStack(spacing: 6) {
                    Text("RPM")
                        .font(.system(size: labelSize, weight: .regular, design: .monospaced))
                        .foregroundColor(ShuttlXColor.textSecondary)
                    Text("\(workoutManager.currentCadence)")
                        .font(.system(size: stationTimeSize, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(ShuttlXColor.textPrimary)
                        .contentTransition(.numericText())
                }
            }

            HStack(spacing: 6) {
                Text("Total")
                    .font(.system(size: labelSize, weight: .regular, design: .monospaced))
                    .foregroundColor(ShuttlXColor.textSecondary)
                Text(FormattingUtils.formatTimer(workoutManager.elapsedTime))
                    .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(ShuttlXColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Station \(workoutManager.recoverySetNumber) in progress. Heart rate \(workoutManager.heartRate) BPM. Station time \(FormattingUtils.formatTimeAccessible(workoutManager.stationElapsedTime)).")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Rest

    private var restView: some View {
        let h = screenHeight
        let timerSize = max(36, h * 0.20)
        let labelSize = max(10, h * 0.075)
        let hrSize = max(20, h * 0.115)
        let restSecs = workoutManager.restElapsedTime
        let passed1min = restSecs >= 60
        let passed2min = restSecs >= 120

        return VStack(spacing: h * 0.02) {
            Text("REST")
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)

            Text(FormattingUtils.formatTimer(restSecs))
                .font(.system(size: timerSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(restTimerColor(restSecs: restSecs))
                .contentTransition(.numericText())
                .accessibilityLabel("Rest time \(FormattingUtils.formatTimeAccessible(restSecs))")
                .accessibilityAddTraits(.updatesFrequently)

            HStack(spacing: 8) {
                milestoneBadge(label: "1:00", reached: passed1min, value: workoutManager.latestHRR1)
                milestoneBadge(label: "2:00", reached: passed2min, value: workoutManager.latestHRR2)
            }

            HStack(spacing: 4) {
                Text(workoutManager.heartRate > 0 ? "\(workoutManager.heartRate)" : "---")
                    .font(.system(size: hrSize, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(ShuttlXColor.heartRate)
                    .contentTransition(.numericText())
                Image(systemName: "arrow.down")
                    .font(.system(size: hrSize * 0.6))
                    .foregroundColor(
                        isHRSafe(workoutManager.heartRate)
                            ? ShuttlXColor.ctaPrimary.opacity(0.7)
                            : ShuttlXColor.heartRate.opacity(0.7)
                    )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(workoutManager.heartRate) beats per minute, recovering")
            .accessibilityAddTraits(.updatesFrequently)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func isHRSafe(_ bpm: Int) -> Bool {
        guard bpm > 0 else { return false }
        return Double(bpm) / 185.0 < 0.70
    }

    private func restTimerColor(restSecs: TimeInterval) -> Color {
        if restSecs >= 120 { return ShuttlXColor.ctaPrimary }
        if restSecs >= 60  { return .orange }
        return ShuttlXColor.textPrimary
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
        .foregroundColor(reached ? .white : .gray)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(reached ? Color.green.opacity(0.25) : Color.gray.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(reached ? Color.green.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1)
        )
        .accessibilityLabel(
            reached
                ? (value != nil ? "\(label) mark: \(value!) BPM drop" : "\(label) reached")
                : "\(label) mark not yet reached"
        )
    }
}
