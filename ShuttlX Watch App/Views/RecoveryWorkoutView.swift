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
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "heart.circle")
                .font(.system(size: 34))
                .foregroundColor(ShuttlXColor.heartRate.opacity(0.7))
            Text("Ready")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.textPrimary)
            Text("Start your first station")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(ShuttlXColor.textSecondary)
                .multilineTextAlignment(.center)
            Text(FormattingUtils.formatTimer(workoutManager.elapsedTime))
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(ShuttlXColor.textSecondary)
                .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart recovery monitoring ready. Sit on your first machine to begin.")
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
                    .foregroundColor(ShuttlXColor.heartRate.opacity(0.7))
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
