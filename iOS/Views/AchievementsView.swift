//
//  AchievementsView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct AchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()
    @State private var selectedCategory: AchievementCategory = .all
    @State private var selectedAchievement: Achievement?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Stats Overview
                    statsOverviewSection
                    
                    // Category Filter
                    categoryFilterSection
                    
                    // Achievements Grid
                    achievementsSection
                    
                    // Milestones Section
                    milestonesSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshData()
            }
            .onAppear {
                viewModel.loadAchievements()
            }
            .sheet(item: $selectedAchievement) { achievement in
                AchievementDetailView(achievement: achievement)
            }
        }
    }
    
    // MARK: - Stats Overview Section
    private var statsOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Progress")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                OverviewStatCard(
                    icon: "trophy.fill",
                    title: "Achievements",
                    value: "\(viewModel.unlockedCount)/\(viewModel.totalAchievements)",
                    subtitle: "Unlocked",
                    color: .gold
                )
                
                OverviewStatCard(
                    icon: "star.fill",
                    title: "Total Points",
                    value: "\(viewModel.totalPoints)",
                    subtitle: "Achievement Points",
                    color: .blue
                )
                
                OverviewStatCard(
                    icon: "flame.fill",
                    title: "Current Streak",
                    value: "\(viewModel.currentStreak)",
                    subtitle: "Days",
                    color: .orange
                )
                
                OverviewStatCard(
                    icon: "target",
                    title: "Completion",
                    value: "\(Int(viewModel.completionPercentage))%",
                    subtitle: "Complete",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Category Filter Section
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    CategoryFilterChip(
                        category: category,
                        isSelected: selectedCategory == category,
                        count: viewModel.getAchievementCount(for: category)
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Achievements Section
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedCategory == .all ? "All Achievements" : selectedCategory.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(viewModel.getUnlockedCount(for: selectedCategory))/\(viewModel.getAchievementCount(for: selectedCategory))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(viewModel.getFilteredAchievements(for: selectedCategory)) { achievement in
                    AchievementCard(achievement: achievement) {
                        selectedAchievement = achievement
                    }
                }
            }
        }
    }
    
    // MARK: - Milestones Section
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Milestones")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ForEach(viewModel.upcomingMilestones) { achievement in
                    MilestoneProgressCard(achievement: achievement)
                }
            }
            
            if viewModel.upcomingMilestones.isEmpty {
                EmptyMilestonesView()
                    .padding(.vertical, 20)
            }
        }
    }
}

// MARK: - Supporting Views

struct OverviewStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct CategoryFilterChip: View {
    let category: AchievementCategory
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption)
                
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(20)
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Achievement Icon
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ? achievement.tier.color : Color(.systemGray5))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: achievement.icon)
                        .font(.title2)
                        .foregroundColor(achievement.isUnlocked ? .white : .secondary)
                    
                    if achievement.isUnlocked {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                        }
                        .frame(width: 60, height: 60)
                    }
                }
                
                // Achievement Info
                VStack(spacing: 4) {
                    Text(achievement.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text(achievement.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    // Points
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(achievement.tier.color)
                        
                        Text("\(achievement.points) pts")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(achievement.tier.color)
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(height: 140)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(achievement.isUnlocked ? achievement.tier.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(achievement.isUnlocked ? 1.0 : 0.95)
            .opacity(achievement.isUnlocked ? 1.0 : 0.7)
        }
        .buttonStyle(.plain)
    }
}

struct MilestoneProgressCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Icon
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundColor(achievement.tier.color)
                    .frame(width: 32, height: 32)
                    .background(achievement.tier.color.opacity(0.1))
                    .cornerRadius(8)
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(achievement.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Progress
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(achievement.currentValue)/\(achievement.targetValue)")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("\(Int(achievement.progressPercentage))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress Bar
            ProgressView(value: achievement.progressPercentage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: achievement.tier.color))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct EmptyMilestonesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("All caught up!")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("You've completed all nearby milestones. Keep working out to unlock new achievements!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Models and Enums

struct Achievement: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var icon: String
    var category: AchievementCategory
    var tier: AchievementTier
    var points: Int
    var targetValue: Int
    var currentValue: Int
    var isUnlocked: Bool
    var unlockedAt: Date?
    
    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue) * 100, 100)
    }
    
    var isNearCompletion: Bool {
        progressPercentage >= 75 && !isUnlocked
    }
}

enum AchievementCategory: String, CaseIterable {
    case all = "all"
    case workouts = "workouts"
    case distance = "distance"
    case streaks = "streaks"
    case personal = "personal"
    case social = "social"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .workouts: return "Workouts"
        case .distance: return "Distance"
        case .streaks: return "Streaks"
        case .personal: return "Personal"
        case .social: return "Social"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .workouts: return "dumbbell"
        case .distance: return "location"
        case .streaks: return "flame"
        case .personal: return "person"
        case .social: return "person.2"
        }
    }
}

enum AchievementTier: String, CaseIterable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case platinum = "platinum"
    
    var color: Color {
        switch self {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .gold
        case .platinum: return .purple
        }
    }
    
    var points: Int {
        switch self {
        case .bronze: return 10
        case .silver: return 25
        case .gold: return 50
        case .platinum: return 100
        }
    }
}

// Color extension for gold
extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let brown = Color(red: 0.6, green: 0.4, blue: 0.2)
}

#Preview {
    AchievementsView()
}
