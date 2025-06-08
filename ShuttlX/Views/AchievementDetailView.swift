//
//  AchievementDetailView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct AchievementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let achievement: Achievement
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Achievement Header
                    achievementHeaderSection
                    
                    // Progress Section
                    progressSection
                    
                    // Achievement Info
                    achievementInfoSection
                    
                    // Tips Section
                    if !achievement.isUnlocked {
                        tipsSection
                    }
                    
                    // Related Achievements
                    relatedAchievementsSection
                    
                    // Statistics
                    statisticsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if achievement.isUnlocked {
                        Button("Share") {
                            showingShareSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheetView(achievement: achievement)
            }
        }
    }
    
    // MARK: - Achievement Header Section
    private var achievementHeaderSection: some View {
        VStack(spacing: 20) {
            // Achievement Icon
            ZStack {
                Circle()
                    .fill(
                        achievement.isUnlocked ? 
                        LinearGradient(
                            colors: [achievement.tier.color, achievement.tier.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color(.systemGray5), Color(.systemGray4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: achievement.isUnlocked ? achievement.tier.color.opacity(0.3) : .clear, radius: 10)
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 48))
                    .foregroundColor(achievement.isUnlocked ? .white : .secondary)
                
                if achievement.isUnlocked {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    .frame(width: 120, height: 120)
                }
            }
            
            // Achievement Title and Description
            VStack(spacing: 8) {
                Text(achievement.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Tier and Points
            HStack(spacing: 16) {
                // Tier Badge
                HStack(spacing: 4) {
                    Image(systemName: achievement.tier.icon)
                    Text(achievement.tier.displayName)
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(achievement.tier.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(achievement.tier.color.opacity(0.1))
                .cornerRadius(12)
                
                // Points Badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                    Text("\(achievement.points) pts")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Unlock Date
            if let unlockedAt = achievement.unlockedAt {
                Text("Unlocked on \(unlockedAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                // Progress Bar
                HStack {
                    Text("Current Progress")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(achievement.currentValue)/\(achievement.targetValue)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(achievement.tier.color)
                }
                
                ProgressView(value: achievement.progressPercentage / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: achievement.tier.color))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                HStack {
                    Text("\(Int(achievement.progressPercentage))% Complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !achievement.isUnlocked {
                        let remaining = achievement.targetValue - achievement.currentValue
                        Text("\(remaining) remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Achievement Info Section
    private var achievementInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievement Details")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "tag.fill",
                    title: "Category",
                    value: achievement.category.displayName
                )
                
                InfoRow(
                    icon: "target",
                    title: "Target",
                    value: getTargetDescription()
                )
                
                InfoRow(
                    icon: "star.fill",
                    title: "Difficulty",
                    value: achievement.tier.displayName
                )
                
                InfoRow(
                    icon: "gift.fill",
                    title: "Reward Points",
                    value: "\(achievement.points) points"
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Tips Section
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tips to Unlock")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(getTipsForAchievement(), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 20)
                        
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Related Achievements Section
    private var relatedAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Related Achievements")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(getRelatedAchievements()) { relatedAchievement in
                        RelatedAchievementCard(achievement: relatedAchievement)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    icon: "calendar",
                    title: "Days Active",
                    value: "\(getDaysActive())",
                    color: .blue
                )
                
                StatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Daily Average",
                    value: getDailyAverage(),
                    color: .green
                )
                
                StatCard(
                    icon: "clock",
                    title: "Time to Complete",
                    value: getTimeToComplete(),
                    color: .orange
                )
                
                StatCard(
                    icon: "percent",
                    title: "Completion Rate",
                    value: "\(Int(achievement.progressPercentage))%",
                    color: .purple
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    private func getTargetDescription() -> String {
        switch achievement.category {
        case .workouts:
            return "\(achievement.targetValue) workouts"
        case .distance:
            return "\(achievement.targetValue) miles"
        case .streaks:
            return "\(achievement.targetValue) days"
        case .personal:
            if achievement.title.contains("minute") {
                return "\(achievement.targetValue) minutes"
            } else {
                return "\(achievement.targetValue) sessions"
            }
        case .social:
            if achievement.title.contains("Share") {
                return "\(achievement.targetValue) shares"
            } else if achievement.title.contains("likes") {
                return "\(achievement.targetValue) likes"
            } else {
                return "\(achievement.targetValue) connections"
            }
        case .all:
            return "\(achievement.targetValue)"
        }
    }
    
    private func getTipsForAchievement() -> [String] {
        switch achievement.category {
        case .workouts:
            return [
                "Consistency is key - aim for regular workout sessions",
                "Mix different workout types to stay motivated",
                "Set reminders to maintain your routine",
                "Track your progress to see improvement"
            ]
        case .distance:
            return [
                "Gradually increase your distance each week",
                "Focus on proper form over speed",
                "Mix shuttle runs with other cardio exercises",
                "Stay hydrated during longer sessions"
            ]
        case .streaks:
            return [
                "Start with shorter, easier workouts to build the habit",
                "Schedule workouts at the same time each day",
                "Have backup indoor exercises for bad weather",
                "Don't break the chain - even 5 minutes counts"
            ]
        case .personal:
            return [
                "Gradually increase intensity over time",
                "Focus on proper warm-up and cool-down",
                "Listen to your body and rest when needed",
                "Set intermediate goals to track progress"
            ]
        case .social:
            return [
                "Share your workout achievements with friends",
                "Join workout challenges with others",
                "Encourage friends to start their fitness journey",
                "Post progress photos and celebrate milestones"
            ]
        case .all:
            return [
                "Stay consistent with your workouts",
                "Set realistic and achievable goals",
                "Celebrate small wins along the way"
            ]
        }
    }
    
    private func getRelatedAchievements() -> [Achievement] {
        // Mock related achievements - in real app, this would filter by category/difficulty
        return [
            Achievement(
                title: "Getting Started",
                description: "Complete your first workout",
                icon: "play.fill",
                category: achievement.category,
                tier: .bronze,
                points: 5,
                targetValue: 1,
                currentValue: 1,
                isUnlocked: true
            ),
            Achievement(
                title: "Habit Builder",
                description: "Complete 7 workouts",
                icon: "calendar.badge.plus",
                category: achievement.category,
                tier: .silver,
                points: 15,
                targetValue: 7,
                currentValue: 4,
                isUnlocked: false
            )
        ]
    }
    
    private func getDaysActive() -> Int {
        // Mock calculation - in real app, this would come from user data
        return max(1, achievement.currentValue / 2)
    }
    
    private func getDailyAverage() -> String {
        let days = getDaysActive()
        let average = days > 0 ? Double(achievement.currentValue) / Double(days) : 0
        return String(format: "%.1f", average)
    }
    
    private func getTimeToComplete() -> String {
        if achievement.isUnlocked {
            return "Completed!"
        }
        
        let remaining = achievement.targetValue - achievement.currentValue
        let dailyAverage = Double(achievement.currentValue) / Double(max(getDaysActive(), 1))
        
        if dailyAverage > 0 {
            let daysRemaining = Int(ceil(Double(remaining) / dailyAverage))
            return "\(daysRemaining) days"
        } else {
            return "Start now!"
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct RelatedAchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.tier.color : Color(.systemGray5))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundColor(achievement.isUnlocked ? .white : .secondary)
            }
            
            // Title
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Progress
            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("\(Int(achievement.progressPercentage))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 80)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct ShareSheetView: View {
    let achievement: Achievement
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Share Preview
                sharePreviewSection
                
                // Share Options
                shareOptionsSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Share Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var sharePreviewSection: some View {
        VStack(spacing: 16) {
            Text("Share Your Achievement")
                .font(.title2)
                .fontWeight(.bold)
            
            // Achievement Preview Card
            VStack(spacing: 12) {
                Image(systemName: achievement.icon)
                    .font(.largeTitle)
                    .foregroundColor(achievement.tier.color)
                
                Text(achievement.title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("Just unlocked in ShuttlX!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(achievement.tier.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(achievement.tier.color)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(achievement.points) points")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(achievement.tier.color.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var shareOptionsSection: some View {
        VStack(spacing: 16) {
            Text("Share to")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ShareOptionButton(
                    icon: "message.fill",
                    title: "Messages",
                    color: .green
                ) {
                    shareToMessages()
                }
                
                ShareOptionButton(
                    icon: "square.and.arrow.up",
                    title: "Share Sheet",
                    color: .blue
                ) {
                    shareToSystem()
                }
                
                ShareOptionButton(
                    icon: "photo",
                    title: "Save Image",
                    color: .purple
                ) {
                    saveAsImage()
                }
                
                ShareOptionButton(
                    icon: "doc.on.clipboard",
                    title: "Copy Text",
                    color: .orange
                ) {
                    copyToClipboard()
                }
                
                ShareOptionButton(
                    icon: "person.2.fill",
                    title: "Social",
                    color: .pink
                ) {
                    shareToSocial()
                }
                
                ShareOptionButton(
                    icon: "envelope.fill",
                    title: "Email",
                    color: .cyan
                ) {
                    shareToEmail()
                }
            }
        }
    }
    
    private func shareToMessages() {
        // Implement Messages sharing
        dismiss()
    }
    
    private func shareToSystem() {
        // Implement system share sheet
        dismiss()
    }
    
    private func saveAsImage() {
        // Implement save as image
        dismiss()
    }
    
    private func copyToClipboard() {
        // Implement copy to clipboard
        let text = "Just unlocked '\(achievement.title)' in ShuttlX! 🏆"
        UIPasteboard.general.string = text
        dismiss()
    }
    
    private func shareToSocial() {
        // Implement social media sharing
        dismiss()
    }
    
    private func shareToEmail() {
        // Implement email sharing
        dismiss()
    }
}

struct ShareOptionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AchievementDetailView(
        achievement: Achievement(
            title: "First Steps",
            description: "Complete your first workout",
            icon: "figure.walk",
            category: .workouts,
            tier: .bronze,
            points: 10,
            targetValue: 1,
            currentValue: 1,
            isUnlocked: true,
            unlockedAt: Date()
        )
    )
}
