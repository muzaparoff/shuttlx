//
//  AchievementsViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import SwiftUI

@MainActor
class AchievementsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var achievements: [Achievement] = []
    @Published var isLoading = false
    
    // Stats
    @Published var totalPoints: Int = 0
    @Published var currentStreak: Int = 0
    @Published var unlockedCount: Int = 0
    @Published var totalAchievements: Int = 0
    @Published var completionPercentage: Double = 0.0
    
    // MARK: - Computed Properties
    var upcomingMilestones: [Achievement] {
        achievements.filter { $0.isNearCompletion }
            .sorted { $0.progressPercentage > $1.progressPercentage }
            .prefix(5)
            .map { $0 }
    }
    
    // MARK: - Methods
    func loadAchievements() {
        isLoading = true
        
        // Load achievements from storage and merge with defaults
        achievements = defaultAchievements
        updateUserProgress()
        calculateStats()
        
        isLoading = false
    }
    
    @MainActor
    func refreshData() async {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        loadAchievements()
    }
    
    func getAchievementCount(for category: AchievementCategory) -> Int {
        if category == .all {
            return achievements.count
        }
        return achievements.filter { $0.category == category }.count
    }
    
    func getUnlockedCount(for category: AchievementCategory) -> Int {
        if category == .all {
            return achievements.filter { $0.isUnlocked }.count
        }
        return achievements.filter { $0.category == category && $0.isUnlocked }.count
    }
    
    func getFilteredAchievements(for category: AchievementCategory) -> [Achievement] {
        if category == .all {
            return achievements.sorted { achievement1, achievement2 in
                if achievement1.isUnlocked != achievement2.isUnlocked {
                    return achievement1.isUnlocked && !achievement2.isUnlocked
                }
                return achievement1.tier.points > achievement2.tier.points
            }
        }
        return achievements.filter { $0.category == category }
            .sorted { achievement1, achievement2 in
                if achievement1.isUnlocked != achievement2.isUnlocked {
                    return achievement1.isUnlocked && !achievement2.isUnlocked
                }
                return achievement1.tier.points > achievement2.tier.points
            }
    }
    
    // MARK: - Private Methods
    private func updateUserProgress() {
        // Simulate user progress based on app usage
        // In a real app, this would come from HealthKit, Core Data, or user defaults
        
        for index in achievements.indices {
            switch achievements[index].category {
            case .workouts:
                achievements[index].currentValue = Int.random(in: 0...achievements[index].targetValue)
            case .distance:
                achievements[index].currentValue = Int.random(in: 0...achievements[index].targetValue)
            case .streaks:
                achievements[index].currentValue = min(12, achievements[index].targetValue) // Current streak is 12
            case .personal:
                achievements[index].currentValue = Int.random(in: 0...achievements[index].targetValue)
            case .social:
                achievements[index].currentValue = Int.random(in: 0...achievements[index].targetValue)
            case .all:
                break
            }
            
            // Mark as unlocked if target is reached
            if achievements[index].currentValue >= achievements[index].targetValue {
                achievements[index].isUnlocked = true
                achievements[index].unlockedAt = Date()
            }
        }
    }
    
    private func calculateStats() {
        unlockedCount = achievements.filter { $0.isUnlocked }.count
        totalAchievements = achievements.count
        totalPoints = achievements.filter { $0.isUnlocked }.reduce(0) { $0 + $1.points }
        currentStreak = 12 // This would come from user data
        
        if totalAchievements > 0 {
            completionPercentage = Double(unlockedCount) / Double(totalAchievements) * 100
        }
    }
    
    // MARK: - Default Achievements
    private var defaultAchievements: [Achievement] {
        return [
            // Workout Achievements
            Achievement(
                title: "First Steps",
                description: "Complete your first workout",
                icon: "figure.walk",
                category: .workouts,
                tier: .bronze,
                points: 10,
                targetValue: 1,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Getting Started",
                description: "Complete 5 workouts",
                icon: "dumbbell",
                category: .workouts,
                tier: .bronze,
                points: 10,
                targetValue: 5,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Workout Warrior",
                description: "Complete 25 workouts",
                icon: "dumbbell.fill",
                category: .workouts,
                tier: .silver,
                points: 25,
                targetValue: 25,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Fitness Fanatic",
                description: "Complete 50 workouts",
                icon: "star.circle.fill",
                category: .workouts,
                tier: .gold,
                points: 50,
                targetValue: 50,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Elite Athlete",
                description: "Complete 100 workouts",
                icon: "crown.fill",
                category: .workouts,
                tier: .platinum,
                points: 100,
                targetValue: 100,
                currentValue: 0,
                isUnlocked: false
            ),
            
            // Distance Achievements
            Achievement(
                title: "First Mile",
                description: "Cover 1 mile in shuttle runs",
                icon: "location",
                category: .distance,
                tier: .bronze,
                points: 10,
                targetValue: 1,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Distance Runner",
                description: "Cover 10 miles in total",
                icon: "location.fill",
                category: .distance,
                tier: .silver,
                points: 25,
                targetValue: 10,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Marathon Spirit",
                description: "Cover 26.2 miles in total",
                icon: "figure.run",
                category: .distance,
                tier: .gold,
                points: 50,
                targetValue: 26,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Ultra Runner",
                description: "Cover 100 miles in total",
                icon: "speedometer",
                category: .distance,
                tier: .platinum,
                points: 100,
                targetValue: 100,
                currentValue: 0,
                isUnlocked: false
            ),
            
            // Streak Achievements
            Achievement(
                title: "Consistency",
                description: "Workout 3 days in a row",
                icon: "flame",
                category: .streaks,
                tier: .bronze,
                points: 10,
                targetValue: 3,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Week Warrior",
                description: "Workout 7 days in a row",
                icon: "flame.fill",
                category: .streaks,
                tier: .silver,
                points: 25,
                targetValue: 7,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Monthly Master",
                description: "Workout 30 days in a row",
                icon: "calendar",
                category: .streaks,
                tier: .gold,
                points: 50,
                targetValue: 30,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Habit Hero",
                description: "Workout 100 days in a row",
                icon: "star.circle",
                category: .streaks,
                tier: .platinum,
                points: 100,
                targetValue: 100,
                currentValue: 0,
                isUnlocked: false
            ),
            
            // Personal Achievements
            Achievement(
                title: "Speed Demon",
                description: "Complete a sub-10 second 20m shuttle",
                icon: "bolt.fill",
                category: .personal,
                tier: .silver,
                points: 25,
                targetValue: 1,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Endurance Beast",
                description: "Complete a 45-minute workout",
                icon: "heart.fill",
                category: .personal,
                tier: .gold,
                points: 50,
                targetValue: 1,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "HIIT Master",
                description: "Complete 20 HIIT workouts",
                icon: "timer",
                category: .personal,
                tier: .gold,
                points: 50,
                targetValue: 20,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Perfect Form",
                description: "Achieve 95% form score in 10 workouts",
                icon: "checkmark.seal.fill",
                category: .personal,
                tier: .platinum,
                points: 100,
                targetValue: 10,
                currentValue: 0,
                isUnlocked: false
            ),
            
            // Social Achievements
            Achievement(
                title: "Social Butterfly",
                description: "Share your first workout",
                icon: "square.and.arrow.up",
                category: .social,
                tier: .bronze,
                points: 10,
                targetValue: 1,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Motivator",
                description: "Receive 10 likes on shared workouts",
                icon: "heart.circle.fill",
                category: .social,
                tier: .silver,
                points: 25,
                targetValue: 10,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Community Leader",
                description: "Help 5 friends complete their first workout",
                icon: "person.2.fill",
                category: .social,
                tier: .gold,
                points: 50,
                targetValue: 5,
                currentValue: 0,
                isUnlocked: false
            ),
            
            Achievement(
                title: "Influencer",
                description: "Get 100 followers",
                icon: "megaphone.fill",
                category: .social,
                tier: .platinum,
                points: 100,
                targetValue: 100,
                currentValue: 0,
                isUnlocked: false
            )
        ]
    }
}

#Preview {
    AchievementsView()
}
