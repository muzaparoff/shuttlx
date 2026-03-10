import SwiftUI
import os.log

struct ContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "ContentView")

    var body: some View {
        NavigationStack {
            if workoutManager.isWorkoutActive {
                TrainingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .onAppear {
                        logger.info("TrainingView appeared - workout active")
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
