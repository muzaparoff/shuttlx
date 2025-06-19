import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        TabView {
            ProgramListView()
                .tabItem {
                    Label("Programs", systemImage: "list.bullet")
                }
            
            TrainingHistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
        }
        .onAppear {
            // Request necessary permissions on first launch
            requestPermissions()
        }
    }
    
    private func requestPermissions() {
        // This will be expanded to request HealthKit and other permissions
        // For now, just a placeholder
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
