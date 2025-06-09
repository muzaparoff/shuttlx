import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serviceLocator: ServiceLocator
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Workouts Tab
            WorkoutDashboardView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Workouts")
                }
                .tag(0)
            
            // Statistics Tab
            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
                .tag(1)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Profile")
                }
                .tag(2)
        }
        .onAppear {
            print("📱 MVP ContentView appeared")
            setupHealthKitIfNeeded()
        }
    }
    
    private func setupHealthKitIfNeeded() {
        Task {
            if healthManager.permissionStatus == .notDetermined {
                await healthManager.requestPermissions()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ServiceLocator.shared)
    }
}