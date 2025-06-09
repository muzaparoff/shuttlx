import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serviceLocator: ServiceLocator
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Interval Training Tab (Main focus)
            WorkoutDashboardView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("Intervals")
                }
                .tag(0)
            
            // Training Programs Tab
            ProgramsView()
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("Programs")
                }
                .tag(1)
            
            // Statistics Tab
            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
                .tag(2)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Profile")
                }
                .tag(3)
        }
        .onAppear {
            print("📱 Run-Walk MVP ContentView appeared")
            setupHealthKitIfNeeded()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
    }
    
    private func setupHealthKitIfNeeded() {
        Task {
            if !serviceLocator.healthManager.hasHealthKitPermission {
                await serviceLocator.healthManager.requestHealthPermissions()
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