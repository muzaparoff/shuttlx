import SwiftUI
import HealthKit
import WatchKit
import ShuttlXShared

extension TrainingView {
    // MARK: - Controls Tab (Translucent Circles)

    var controlsTab: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: ShuttlXSpacing.xxl) {
                // Pause / Resume
                Button(action: {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(workoutManager.isPaused ? .directionUp : .directionDown)
                    #endif
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                }) {
                    Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        .font(ShuttlXFont.watchControlIcon)
                        .foregroundColor(workoutManager.isPaused ? ShuttlXColor.ctaPrimary : ShuttlXColor.ctaPause)
                }
                .buttonStyle(ThemedControlButtonStyle())
                .accessibilityLabel(workoutManager.isPaused ? "Resume workout" : "Pause workout")

                // Finish
                Button(action: {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.stop)
                    #endif
                    showingStopConfirmation = true
                }) {
                    Image(systemName: "stop.fill")
                        .font(ShuttlXFont.watchControlIcon)
                        .foregroundColor(ShuttlXColor.ctaDestructive)
                }
                .buttonStyle(ThemedControlButtonStyle())
                .accessibilityLabel("Finish workout")
                .accessibilityHint("Saves the workout and shows your summary")
            }

            // Labels
            HStack(spacing: ShuttlXSpacing.xxl) {
                Text(workoutManager.isPaused ? "Resume" : "Pause")
                    .font(ShuttlXFont.watchControlLabel)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .frame(width: ShuttlXSize.controlButtonDiameter)
                Text("End")
                    .font(ShuttlXFont.watchControlLabel)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .frame(width: ShuttlXSize.controlButtonDiameter)
            }
            .padding(.top, ShuttlXSpacing.sm)

            Spacer()
        }
    }
}
