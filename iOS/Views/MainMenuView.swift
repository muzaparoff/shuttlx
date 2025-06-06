//
//  MainMenuView.swift
//  ShuttlX
//
//  Main navigation and menu interface
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct MainMenuView: View {
    @StateObject private var settingsService = SettingsService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var socialService = SocialService.shared
    @StateObject private var messagingService = MessagingService.shared
    @StateObject private var healthManager = HealthManager.shared
    
    @State private var selectedTab: MainTab = .home
    @State private var showingSettings = false
    @State private var showingProfile = false
    @State private var showingNotifications = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == .home ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(MainTab.home)
            
            // Workouts Tab
            WorkoutMenuView()
                .tabItem {
                    Image(systemName: selectedTab == .workouts ? "figure.run.circle.fill" : "figure.run.circle")
                    Text("Workouts")
                }
                .tag(MainTab.workouts)
            
            // AI Coach Tab
            AIFormAnalysisView()
                .tabItem {
                    Image(systemName: selectedTab == .ai ? "brain.head.profile.fill" : "brain.head.profile")
                    Text("AI Coach")
                }
                .tag(MainTab.ai)
            
            // Social Tab
            SocialView()
                .tabItem {
                    Image(systemName: selectedTab == .social ? "person.3.fill" : "person.3")
                    Text("Social")
                }
                .badge(socialService.unreadCount > 0 ? socialService.unreadCount : nil)
                .tag(MainTab.social)
            
            // Health Tab
            HealthDashboardView()
                .tabItem {
                    Image(systemName: selectedTab == .health ? "heart.fill" : "heart")
                    Text("Health")
                }
                .tag(MainTab.health)
        }
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingProfile = true }) {
                    ProfileButton()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    NotificationButton(
                        unreadCount: notificationService.unreadCount,
                        action: { showingNotifications = true }
                    )
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
        .onAppear {
            setupAppearance()
            checkInitialSetup()
        }
    }
    
    private func setupAppearance() {
        // Apply theme from settings
        let theme = settingsService.settings.user.theme
        switch theme {
        case .light:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .light
        case .dark:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .dark
        case .system:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .unspecified
        }
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        
        if settingsService.settings.user.theme == .dark {
            tabBarAppearance.backgroundColor = UIColor.systemBackground
        }
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    private func checkInitialSetup() {
        // Check if this is first launch
        if !UserDefaults.standard.bool(forKey: "has_completed_onboarding") {
            // Show onboarding
        }
        
        // Request permissions
        Task {
            await requestInitialPermissions()
        }
    }
    
    private func requestInitialPermissions() async {
        // Request notification permissions
        _ = await notificationService.requestAuthorization()
        
        // Request health permissions if enabled
        if settingsService.settings.health.healthKitEnabled {
            await healthManager.requestBasicAuthorization()
        }
    }
}

// MARK: - Supporting Views

struct HomeView: View {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Quick Stats Card
                    QuickStatsCard()
                    
                    // Today's Goals
                    TodaysGoalsCard()
                    
                    // Recent Workouts
                    RecentWorkoutsCard()
                    
                    // Achievements
                    RecentAchievementsCard()
                    
                    // Weather & Recommendations
                    WorkoutRecommendationsCard()
                }
                .padding()
            }
            .navigationTitle("ShuttlX")
            .refreshable {
                await refreshHomeData()
            }
        }
    }
    
    private func refreshHomeData() async {
        await healthManager.fetchTodaysHealthData()
        // Refresh other data sources
    }
}

struct WorkoutMenuView: View {
    @State private var selectedWorkoutType: WorkoutType = .shuttleRun
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Quick Start Section
                    QuickStartSection(selectedWorkoutType: $selectedWorkoutType)
                    
                    // Workout Types Grid
                    WorkoutTypesGrid()
                    
                    // Training Programs
                    TrainingProgramsSection()
                    
                    // Workout History
                    WorkoutHistorySection()
                }
                .padding()
            }
            .navigationTitle("Workouts")
        }
    }
}

struct ProfileButton: View {
    @StateObject private var socialService = SocialService.shared
    
    var body: some View {
        Button(action: {}) {
            AsyncImage(url: URL(string: socialService.currentUserProfile?.avatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct NotificationButton: View {
    let unreadCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.primary)
                
                if unreadCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text("\(min(unreadCount, 99))")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                        .offset(x: 12, y: -12)
                }
            }
        }
    }
}

// MARK: - Home Screen Cards

struct QuickStatsCard: View {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Stats")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                StatItem(
                    title: "Steps",
                    value: "\(Int(healthManager.todaysStats?.steps ?? 0))",
                    icon: "figure.walk",
                    color: .blue
                )
                
                StatItem(
                    title: "Distance",
                    value: String(format: "%.1f %@", 
                                healthManager.todaysStats?.distance ?? 0,
                                settingsService.settings.user.units.distanceUnit),
                    icon: "location",
                    color: .green
                )
                
                StatItem(
                    title: "Calories",
                    value: "\(Int(healthManager.todaysStats?.caloriesBurned ?? 0))",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TodaysGoalsCard: View {
    @StateObject private var settingsService = SettingsService.shared
    @StateObject private var healthManager = HealthManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Goals")
                .font(.headline)
                .fontWeight(.semibold)
            
            let dailyGoal = settingsService.settings.workout.dailyGoal
            let todaysStats = healthManager.todaysStats
            
            GoalProgressItem(
                title: "Steps",
                current: Int(todaysStats?.steps ?? 0),
                target: dailyGoal.steps,
                color: .blue
            )
            
            GoalProgressItem(
                title: "Active Minutes",
                current: Int(todaysStats?.activeMinutes ?? 0),
                target: dailyGoal.activeMinutes,
                color: .green
            )
            
            GoalProgressItem(
                title: "Calories",
                current: Int(todaysStats?.caloriesBurned ?? 0),
                target: Int(dailyGoal.caloriesBurned),
                color: .orange
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct GoalProgressItem: View {
    let title: String
    let current: Int
    let target: Int
    let color: Color
    
    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(current)/\(target)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(height: 6)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
        }
    }
}

struct RecentWorkoutsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Workouts")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {
                    // Navigate to workout history
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                ForEach(0..<3) { _ in
                    RecentWorkoutRow()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct RecentWorkoutRow: View {
    var body: some View {
        HStack {
            Image(systemName: "figure.run.circle.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Shuttle Run")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("25 min • 2.3 km • 234 cal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("2h ago")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct RecentAchievementsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Achievements")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {
                    // Navigate to achievements
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5) { _ in
                        AchievementBadge()
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct AchievementBadge: View {
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "medal.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
            }
            
            Text("First 5K")
                .font(.caption2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .frame(width: 70)
    }
}

struct WorkoutRecommendationsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended for You")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                RecommendationItem(
                    title: "Perfect Weather for Outdoor Run",
                    subtitle: "22°C, partly cloudy",
                    icon: "sun.max.fill",
                    color: .orange
                )
                
                RecommendationItem(
                    title: "Rest Day Recommended",
                    subtitle: "Your recovery score is low",
                    icon: "heart.fill",
                    color: .red
                )
                
                RecommendationItem(
                    title: "Try New Challenge",
                    subtitle: "5K Speed Challenge available",
                    icon: "flag.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct RecommendationItem: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Workout Menu Components

struct QuickStartSection: View {
    @Binding var selectedWorkoutType: WorkoutType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: {
                // Start workout immediately
            }) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("Start \(selectedWorkoutType.displayName)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Begin your workout now")
                            .font(.subheadline)
                            .opacity(0.8)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct WorkoutTypesGrid: View {
    let workoutTypes: [WorkoutType] = [.shuttleRun, .intervalTraining, .enduranceRun, .sprint, .recovery]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Types")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(workoutTypes, id: \.self) { workoutType in
                    WorkoutTypeCard(workoutType: workoutType)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct WorkoutTypeCard: View {
    let workoutType: WorkoutType
    
    var body: some View {
        Button(action: {
            // Navigate to workout setup
        }) {
            VStack(spacing: 8) {
                Image(systemName: workoutType.iconName)
                    .font(.title)
                    .foregroundColor(workoutType.color)
                
                Text(workoutType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
    }
}

struct TrainingProgramsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training Programs")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {}
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<3) { _ in
                        TrainingProgramCard()
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct TrainingProgramCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "target")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("5K Training")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("8-week program to complete your first 5K")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Text("Week 3 of 8")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.orange)
        }
        .padding()
        .frame(width: 160, height: 120)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct WorkoutHistorySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workout History")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {}
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                ForEach(0..<5) { _ in
                    WorkoutHistoryRow()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct WorkoutHistoryRow: View {
    var body: some View {
        HStack {
            Image(systemName: "figure.run.circle.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Shuttle Run Training")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Dec 5, 2024")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("32:15")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("3.2 km")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Main Tab Enum

enum MainTab: String, CaseIterable {
    case home = "home"
    case workouts = "workouts"
    case ai = "ai"
    case social = "social"
    case health = "health"
    
    var displayName: String {
        switch self {
        case .home: return "Home"
        case .workouts: return "Workouts"
        case .ai: return "AI Coach"
        case .social: return "Social"
        case .health: return "Health"
        }
    }
}
