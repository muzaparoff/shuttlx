import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serviceLocator: ServiceLocator
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab - Today/Weekly Activity View (Main focus)
            WorkoutDashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            // Programs Tab (unchanged)
            ProgramsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Programs")
                }
                .tag(1)
            
            // Profile Tab with Settings
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Profile")
                }
                .tag(2)
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