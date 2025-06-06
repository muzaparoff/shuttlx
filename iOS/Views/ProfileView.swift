//
//  ProfileView.swift
//  ShuttlX
//
//  Enhanced comprehensive user profile with social integration
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import HealthKit

struct ProfileView: View {
    @EnvironmentObject var socialService: SocialService
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var settingsService = SettingsService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingHealthPermissions = false
    @State private var showingAchievements = false
    @State private var showingWorkoutHistory = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Profile Header
                    profileHeaderSection
                    
                    // Statistics Overview
                    statisticsSection
                    
                    // Today's Activity
                    todaysActivitySection
                    
                    // Recent Achievements
                    achievementsSection
                    
                    // Recent Workouts
                    recentWorkoutsSection
                    
                    // Social Stats
                    socialStatsSection
                    
                    // Health & Fitness Integration
                    healthIntegrationSection
                    
                    // Quick Actions
                    quickActionsSection
                }
                .padding(.horizontal)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditProfile = true
                    }
                    .foregroundColor(.accentColor)
                }
            }
            .refreshable {
                await refreshProfileData()
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingHealthPermissions) {
            HealthKitPermissionsView()
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsView()
        }
        .sheet(isPresented: $showingWorkoutHistory) {
            WorkoutHistoryView()
        }
        .onAppear {
            Task {
                await viewModel.loadProfileData()
                await refreshProfileData()
            }
        }
    }
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Picture and Basic Info
            HStack(spacing: 16) {
                Button(action: { showingEditProfile = true }) {
                    AsyncImage(url: URL(string: socialService.currentUserProfile?.avatarURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 80, height: 80)
                            
                            if let profile = socialService.currentUserProfile {
                                Text(profile.displayName.prefix(1).uppercased())
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 3)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    if let profile = socialService.currentUserProfile {
                        Text(profile.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("@\(profile.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let location = profile.location {
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(location)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let memberSince = profile.joinDate {
                            Text("Member since \(memberSince, formatter: yearFormatter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("User Profile")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
            
            // Bio
            if let profile = socialService.currentUserProfile, !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Social Stats
            HStack(spacing: 24) {
                ProfileSocialStat(
                    title: "Following",
                    count: socialService.followingCount
                )
                
                ProfileSocialStat(
                    title: "Followers",
                    count: socialService.followersCount
                )
                
                ProfileSocialStat(
                    title: "Posts",
                    count: socialService.userPostsCount
                )
                
                ProfileSocialStat(
                    title: "Challenges",
                    count: socialService.activeChallengesCount
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Month")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ProfileStatCard(
                    title: "Workouts",
                    value: "\(viewModel.monthlyWorkouts)",
                    subtitle: "+\(viewModel.workoutGrowth)% vs last month",
                    icon: "figure.run",
                    color: .blue
                )
                
                ProfileStatCard(
                    title: "Hours Trained",
                    value: String(format: "%.1f", viewModel.monthlyHours),
                    subtitle: "\(Int(viewModel.monthlyHours * 60)) minutes",
                    icon: "clock.fill",
                    color: .green
                )
                
                ProfileStatCard(
                    title: "Calories Burned",
                    value: "\(viewModel.monthlyCalories)",
                    subtitle: "Avg: \(viewModel.avgCaloriesPerWorkout) per workout",
                    icon: "flame.fill",
                    color: .orange
                )
                
                ProfileStatCard(
                    title: "Distance",
                    value: String(format: "%.1f km", viewModel.monthlyDistance),
                    subtitle: "Best: \(String(format: "%.1f", viewModel.longestDistance)) km",
                    icon: "location",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var todaysActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let todaysStats = healthManager.todaysStats {
                HStack(spacing: 16) {
                    TodayActivityItem(
                        title: "Steps",
                        value: "\(Int(todaysStats.steps))",
                        goal: settingsService.settings.workout.dailyGoal.steps,
                        color: .blue,
                        icon: "figure.walk"
                    )
                    
                    TodayActivityItem(
                        title: "Calories",
                        value: "\(Int(todaysStats.caloriesBurned))",
                        goal: settingsService.settings.workout.dailyGoal.calories,
                        color: .orange,
                        icon: "flame.fill"
                    )
                }
                
                if let currentHeartRate = healthManager.currentHeartRate {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Heart Rate")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(Int(currentHeartRate)) BPM")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        if let zone = healthManager.getCurrentHeartRateZone() {
                            Text(zone.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(zone.color)
                                )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.red.opacity(0.1))
                    )
                }
            } else {
                Text("No activity data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Achievements")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingAchievements = true
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            
            if viewModel.recentAchievements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "medal")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("Complete workouts to earn achievements!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.recentAchievements.prefix(5)) { achievement in
                            AchievementBadge(achievement: achievement)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Workouts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingWorkoutHistory = true
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            
            if viewModel.recentWorkouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("Start your first workout to see activity here!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.recentWorkouts.prefix(3)) { workout in
                        RecentWorkoutCard(workout: workout)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var socialStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Social Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                SocialStatCard(
                    title: "Challenges Completed",
                    value: "\(socialService.completedChallengesCount)",
                    icon: "trophy.fill",
                    color: .yellow
                )
                
                SocialStatCard(
                    title: "Team Activities",
                    value: "\(socialService.teamActivitiesCount)",
                    icon: "person.3.fill",
                    color: .blue
                )
            }
            
            HStack(spacing: 16) {
                SocialStatCard(
                    title: "Workout Streak",
                    value: "\(viewModel.currentStreak) days",
                    icon: "flame.fill",
                    color: .orange
                )
                
                SocialStatCard(
                    title: "Total Likes",
                    value: "\(socialService.totalLikesReceived)",
                    icon: "heart.fill",
                    color: .red
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var healthIntegrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Integration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // HealthKit Status
                HealthIntegrationRow(
                    title: "HealthKit",
                    subtitle: healthManager.isAuthorized ? "Connected" : "Not Connected",
                    icon: "heart.fill",
                    isConnected: healthManager.isAuthorized
                ) {
                    if !healthManager.isAuthorized {
                        showingHealthPermissions = true
                    }
                }
                
                // Recovery Status
                if let recoveryData = healthManager.recoveryAnalysis {
                    HStack(spacing: 12) {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recovery Score")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(Int(recoveryData.readinessScore))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(recoveryData.readinessScore > 70 ? .green : recoveryData.readinessScore > 40 ? .orange : .red)
                        }
                        
                        Spacer()
                        
                        RecoveryStatusBadge(score: recoveryData.readinessScore)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue.opacity(0.1))
                    )
                }
                
                // Heart Rate Zones
                if !healthManager.heartRateZones.isEmpty {
                    NavigationLink(destination: HeartRateZonesDetailView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Heart Rate Zones")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("\(healthManager.heartRateZones.count) zones configured")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.red.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    QuickActionButton(
                        title: "Settings",
                        icon: "gearshape.fill",
                        color: .gray
                    ) {
                        showingSettings = true
                    }
                    
                    QuickActionButton(
                        title: "Share Profile",
                        icon: "square.and.arrow.up",
                        color: .blue
                    ) {
                        shareProfile()
                    }
                }
                
                HStack(spacing: 12) {
                    QuickActionButton(
                        title: "Export Data",
                        icon: "square.and.arrow.down",
                        color: .green
                    ) {
                        exportUserData()
                    }
                    
                    QuickActionButton(
                        title: "Support",
                        icon: "questionmark.circle.fill",
                        color: .orange
                    ) {
                        openSupport()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helper Methods
    
    private func refreshProfileData() async {
        await socialService.refreshUserProfile()
        await healthManager.fetchTodaysHealthData()
        await viewModel.loadProfileData()
    }
    
    private func shareProfile() {
        // Implement profile sharing
        if let profile = socialService.currentUserProfile {
            let shareText = "Check out my ShuttlX profile: @\(profile.username)"
            // Use system share sheet
        }
    }
    
    private func exportUserData() {
        // Implement data export
        // This could trigger the data export functionality from SettingsView
    }
    
    private func openSupport() {
        // Open support/help
        // This could open a web view or email
    }
}

// MARK: - Supporting Views

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.iconName)
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
    }
}

struct RecentWorkoutCard: View {
    let workout: TrainingSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Workout Icon
            Image(systemName: workout.workoutType.iconName)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(.orange.opacity(0.1))
                )
            
            // Workout Info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(workout.startTime, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Duration & Calories
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(workout.duration / 60)):\(String(format: "%02d", Int(workout.duration) % 60))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let calories = workout.caloriesBurned {
                    Text("\(Int(calories)) cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct HealthIntegrationRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isConnected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isConnected ? .green : .gray)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isConnected ? .green : .secondary)
                }
                
                Spacer()
                
                if !isConnected {
                    Text("Connect")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.orange.opacity(0.1))
                        )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileInfoRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.gray)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Placeholder Views

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Edit Profile")
            // TODO: Implement edit profile functionality
                .navigationTitle("Edit Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Settings")
            // TODO: Implement settings functionality
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct HealthPermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var healthManager: HealthManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                VStack(spacing: 16) {
                    Text("Connect to Health")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("ShuttlX would like to access your health data to provide personalized workout recommendations and track your fitness progress.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    PermissionItem(
                        icon: "heart.fill",
                        title: "Heart Rate",
                        description: "Monitor workout intensity"
                    )
                    
                    PermissionItem(
                        icon: "figure.run",
                        title: "Workouts",
                        description: "Save and track your activities"
                    )
                    
                    PermissionItem(
                        icon: "flame.fill",
                        title: "Active Energy",
                        description: "Track calories burned"
                    )
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Allow Access") {
                        Task {
                            await healthManager.requestAuthorization()
                            dismiss()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Not Now") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Health Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PermissionItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct AchievementsView: View {
    var body: some View {
        Text("Achievements View")
        // TODO: Implement full achievements view
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.orange)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
    }
}

// MARK: - Formatters

private let yearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return formatter
}()

#Preview {
    ProfileView()
        .environmentObject(AppViewModel())
        .environmentObject(HealthManager())
}
