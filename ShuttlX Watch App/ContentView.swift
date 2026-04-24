import SwiftUI
import os.log

struct ContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "ContentView")

    /// Flip to TrainingView the instant the user taps Start (`isStarting=true`),
    /// not after HealthKit setup finishes. TrainingView itself shows a brief
    /// "Starting…" overlay until `isWorkoutActive=true`, eliminating the
    /// perceived 10-second freeze caused by gating the transition on the full
    /// HealthKit authorization XPC round-trip.
    private var isTrainingVisible: Bool {
        workoutManager.isWorkoutActive || workoutManager.isStarting
    }

    var body: some View {
        NavigationStack {
            if isTrainingVisible {
                TrainingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .onAppear {
                        logger.info("TrainingView appeared - workout active or starting")
                    }
            } else {
                StartTrainingView()
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .onAppear {
                        logger.info("StartTrainingView appeared")
                    }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isTrainingVisible)
        .onAppear {
            logger.info("ContentView rendered")
        }
    }
}

#Preview {
    let dataManager = SharedDataManager.shared
    let workoutManager = WatchWorkoutManager()

    ContentView()
        .environmentObject(dataManager)
        .environmentObject(workoutManager)
        .onAppear {
            workoutManager.setSharedDataManager(dataManager)
        }
}
