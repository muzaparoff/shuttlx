import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        NavigationView {
            if workoutManager.isWorkoutActive {
                TrainingView()
            } else {
                ProgramSelectionView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchWorkoutManager())
}
