import SwiftUI
import WatchKit
import ShuttlXShared

extension TrainingView {
    // MARK: - Controls Tab (two big circles: green Pause, red End)

    var controlsTab: some View {
        let d = max(56, WatchScale.pt(70))
        return VStack(spacing: 0) {
            HStack(spacing: WatchScale.pt(16)) {
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
                    controlCircle(workoutManager.isPaused ? "RESUME" : "PAUSE",
                                  fill: ShuttlXColor.ctaPrimary, text: ShuttlXColor.iconOnCTA, diameter: d)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(workoutManager.isPaused ? "Resume workout" : "Pause workout")

                Button(action: {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.stop)
                    #endif
                    showingStopConfirmation = true
                }) {
                    controlCircle("END", fill: ShuttlXColor.ctaDestructive, text: .white, diameter: d)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End workout")
                .accessibilityHint("Saves the workout and shows your summary")
            }

            Text("Swipe right: back to workout")
                .font(.system(size: WatchScale.text(11)))
                .foregroundStyle(ShuttlXColor.textSecondary)
                .padding(.top, WatchScale.pt(14))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controlCircle(_ label: String, fill: Color, text: Color, diameter: CGFloat) -> some View {
        Text(label)
            .font(.system(size: WatchScale.pt(12), weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(text)
            .lineLimit(1)
            .fixedSize()
            .frame(width: diameter, height: diameter)
            .background(fill, in: Circle())
            .contentShape(Circle())
    }
}
