import SwiftUI
import os.log

struct ContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "ContentView")

    var body: some View {
        NavigationView {
            if workoutManager.isWorkoutActive && workoutManager.currentProgram != nil {
                TrainingView()
                    .onAppear {
                        logger.info("TrainingView appeared - workout is active")
                        logger.info("Current program: \(workoutManager.currentProgram?.name ?? "nil")")
                        logger.info("Current interval: \(workoutManager.currentInterval?.phase.rawValue ?? "nil")")
                    }
            } else {
                ProgramSelectionView()
                    .onAppear {
                        logger.info("ProgramSelectionView appeared successfully")
                        logger.info("Workout active: \(workoutManager.isWorkoutActive)")
                    }
                    .accessibilityLabel("Program Selection")
            }
        }
        .onAppear {
            logger.info("NavigationView appeared - ContentView rendered successfully")
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
