//
//  ContentView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var healthManager: HealthManager
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if appViewModel.hasCompletedOnboarding {
                mainAppView
            } else {
                OnboardingView()
            }
        }
        .fullScreenCover(isPresented: $appViewModel.isWorkoutActive) {
            WorkoutView()
        }
    }
    
    private var mainAppView: some View {
        TabView(selection: $selectedTab) {
            // Home/Dashboard Tab
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            // Workouts Tab
            WorkoutsView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Workouts")
                }
                .tag(1)
            
            // Analytics Tab
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Analytics")
                }
                .tag(2)
            
            // Social Tab
            SocialView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Social")
                }
                .tag(3)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(.orange)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
