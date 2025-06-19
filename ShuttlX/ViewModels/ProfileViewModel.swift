//
//  ProfileViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var monthlyWorkouts: Int = 0
    @Published var monthlyHours: Double = 0.0
    @Published var monthlyCalories: Int = 0
    @Published var recentAchievements: [Achievement] = []
    @Published var recentWorkouts: [TrainingSession] = []
    @Published var isLoading = false
    
    // Additional properties used in ProfileView
    @Published var userName: String = "User"
    @Published var totalWorkouts: Int = 0
    @Published var weeklyWorkouts: Int = 0
    @Published var averageHeartRate: Double = 0
    @Published var totalCalories: Double = 0
    @Published var totalDistance: Double = 0
    @Published var totalActiveTime: TimeInterval = 0
    
    // User profile integration
    @Published var userProfile: UserProfile? = nil
    @Published var isProfileComplete: Bool = false
    @Published var profileCompletionMessage: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    private let userProfileService = UserProfileService.shared
    
    func loadProfileData() {
        isLoading = true
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadUserProfile() }
                group.addTask { await self.loadMonthlyStats() }
                group.addTask { await self.loadRecentAchievements() }
                group.addTask { await self.loadRecentWorkouts() }
            }
            
            isLoading = false
        }
    }
    
    private func loadUserProfile() async {
        do {
            let profile = try await userProfileService.getCurrentProfile()
            await MainActor.run {
                self.userProfile = profile
                self.userName = profile.name
                self.isProfileComplete = userProfileService.isProfileComplete()
                self.profileCompletionMessage = self.generateProfileCompletionMessage()
            }
        } catch {
            print("Error loading user profile: \(error)")
            await MainActor.run {
                self.userName = "User"
                self.isProfileComplete = false
                self.profileCompletionMessage = "Please complete your profile setup"
            }
        }
    }
    
    private func loadMonthlyStats() async {
        // Calculate stats for current month
        let calendar = Calendar.current
        let now = Date()
        let _ = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        // Simulate loading monthly statistics
        // In real implementation, this would query from Core Data or API
        await MainActor.run {
            monthlyWorkouts = Int.random(in: 8...25)
            monthlyHours = Double.random(in: 6.0...40.0)
            monthlyCalories = Int.random(in: 2000...8000)
            
            // Populate additional properties, using user profile data if available
            if let profile = userProfile {
                userName = profile.name
                // Use actual BMI and heart rate zones if available
                if let restingHR = profile.restingHeartRate {
                    averageHeartRate = Double(restingHR + 50) // Rough estimate
                }
            } else {
                userName = "Fitness User"
                averageHeartRate = Double.random(in: 130...160)
            }
            
            totalWorkouts = Int.random(in: 15...80)
            weeklyWorkouts = Int.random(in: 2...7)
            totalCalories = Double.random(in: 5000...15000)
            totalDistance = Double.random(in: 25...150)
            totalActiveTime = TimeInterval.random(in: 7200...36000) // 2-10 hours
        }
    }
    
    private func loadRecentAchievements() async {
        // Simulate loading recent achievements
        // In real implementation, this would fetch from user's achievement data
        await MainActor.run {
            recentAchievements = generateSampleAchievements()
        }
    }
    
    private func loadRecentWorkouts() async {
        // Simulate loading recent workouts
        // In real implementation, this would fetch from Core Data
        await MainActor.run {
            recentWorkouts = generateSampleRecentWorkouts()
        }
    }
    
    // MARK: - Sample Data Generation
    
    private func generateSampleAchievements() -> [Achievement] {
        return [
            Achievement(
                title: "First Steps",
                description: "Complete your first workout",
                iconName: "figure.walk",
                unlockedDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                isUnlocked: true,
                category: .frequency
            ),
            Achievement(
                title: "Speed Demon",
                description: "Complete a shuttle run in under 60 seconds",
                iconName: "bolt.fill",
                unlockedDate: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                isUnlocked: true,
                category: .improvement
            ),
            Achievement(
                title: "Week Warrior",
                description: "Work out 5 days in a week",
                iconName: "calendar",
                unlockedDate: Date().addingTimeInterval(-86400 * 1), // Yesterday
                isUnlocked: true,
                category: .streak
            ),
            Achievement(
                title: "Calorie Crusher",
                description: "Burn 500 calories in a single workout",
                iconName: "flame.fill",
                unlockedDate: Date().addingTimeInterval(-86400 * 7), // 1 week ago
                isUnlocked: true,
                category: .duration
            )
        ]
    }
    
    private func generateSampleRecentWorkouts() -> [TrainingSession] {
        let workoutTypes: [WorkoutType] = [.intervalRunning]
        
        return (0..<5).map { index in
            let workoutType = workoutTypes.randomElement() ?? .intervalRunning
            let startTime = Date().addingTimeInterval(TimeInterval(-86400 * index - Int.random(in: 3600...7200)))
            let duration = TimeInterval.random(in: 300...2400) // 5-40 minutes
            
            return TrainingSession(
                startTime: startTime,
                endTime: startTime.addingTimeInterval(duration),
                workoutType: workoutType.displayName,
                duration: duration,
                distance: workoutType.hasDistance ? Double.random(in: 1.0...5.0) : 0.0,
                calories: Double.random(in: 100...500),
                averageHeartRate: Double.random(in: 120...180),
                maxHeartRate: Double.random(in: 160...200),
                steps: Int.random(in: 1000...8000),
                notes: nil
            )
        }
    }
    
    private func generateProfileCompletionMessage() -> String {
        guard userProfile != nil else {
            return "Please complete your profile setup"
        }
        
        let missingFields = userProfileService.getMissingProfileFields()
        if missingFields.isEmpty {
            return "Profile complete!"
        } else {
            return "Missing: \(missingFields.joined(separator: ", "))"
        }
    }
}

// MARK: - Extensions

extension WorkoutType {
    var hasDistance: Bool {
        switch self {
        case .intervalRunning:
            return true
        }
    }
}
