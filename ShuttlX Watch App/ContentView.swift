import SwiftUI
import os.log

struct ContentView: View {
    @Environment(WatchWorkoutManager.self) var workoutManager
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "ContentView")

    var body: some View {
        NavigationStack {
            if workoutManager.isWorkoutActive {
                TrainingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .onAppear {
                        logger.info("TrainingView appeared - workout active")
                    }
            } else if let summary = workoutManager.pendingSummary {
                // S-1 fix: summary is shown here, not inside TrainingView.
                // pendingSummary is set BEFORE stopWorkout() so it's non-nil when
                // ContentView re-renders with isWorkoutActive = false.
                WorkoutSummaryView(summary: summary) {
                    workoutManager.pendingSummary = nil
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .onAppear {
                    logger.info("WorkoutSummaryView appeared")
                }
            } else {
                StartTrainingView()
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .onAppear {
                        logger.info("StartTrainingView appeared")
                    }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: workoutManager.isWorkoutActive)
        .animation(.easeInOut(duration: 0.35), value: workoutManager.pendingSummary != nil)
        .onAppear {
            logger.info("ContentView rendered")
        }
    }
}

#Preview {
    let dataManager = WatchSyncCoordinator.shared
    let workoutManager = WatchWorkoutManager()

    ContentView()
        .environment(dataManager)
        .environment(workoutManager)
        .onAppear {
            workoutManager.setSharedDataManager(dataManager)
        }
}
