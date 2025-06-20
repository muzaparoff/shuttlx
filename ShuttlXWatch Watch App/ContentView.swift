import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        NavigationStack {
            if workoutManager.currentProgram == nil {
                ProgramSelectionView()
            } else {
                TrainingView()
            }
        }
        .onAppear {
            // Ensure we have the latest programs from iPhone
            workoutManager.loadPrograms()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchWorkoutManager())
}
