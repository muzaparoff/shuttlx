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
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadProfileData() {
        isLoading = true
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadMonthlyStats() }
                group.addTask { await self.loadRecentAchievements() }
                group.addTask { await self.loadRecentWorkouts() }
            }
            
            isLoading = false
        }
    }
    
    private func loadMonthlyStats() async {
        // Calculate stats for current month
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        // Simulate loading monthly statistics
        // In real implementation, this would query from Core Data or API
        await MainActor.run {
            monthlyWorkouts = Int.random(in: 8...25)
            monthlyHours = Double.random(in: 6.0...40.0)
            monthlyCalories = Int.random(in: 2000...8000)
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
                id: UUID(),
                title: "First Steps",
                description: "Complete your first workout",
                iconName: "figure.walk",
                category: .milestone,
                threshold: 1,
                currentProgress: 1,
                earnedDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                isUnlocked: true
            ),
            Achievement(
                id: UUID(),
                title: "Speed Demon",
                description: "Complete a shuttle run in under 60 seconds",
                iconName: "bolt.fill",
                category: .performance,
                threshold: 1,
                currentProgress: 1,
                earnedDate: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                isUnlocked: true
            ),
            Achievement(
                id: UUID(),
                title: "Week Warrior",
                description: "Work out 5 days in a week",
                iconName: "calendar",
                category: .consistency,
                threshold: 5,
                currentProgress: 5,
                earnedDate: Date().addingTimeInterval(-86400 * 1), // Yesterday
                isUnlocked: true
            ),
            Achievement(
                id: UUID(),
                title: "Calorie Crusher",
                description: "Burn 500 calories in a single workout",
                iconName: "flame.fill",
                category: .performance,
                threshold: 500,
                currentProgress: 523,
                earnedDate: Date().addingTimeInterval(-86400 * 7), // 1 week ago
                isUnlocked: true
            )
        ]
    }
    
    private func generateSampleRecentWorkouts() -> [TrainingSession] {
        let workoutTypes: [WorkoutType] = [.shuttleRun, .hiit, .tabata, .pyramid, .runWalk]
        
        return (0..<5).map { index in
            let workoutType = workoutTypes.randomElement() ?? .shuttleRun
            let startTime = Date().addingTimeInterval(TimeInterval(-86400 * index - Int.random(in: 3600...7200)))
            let duration = TimeInterval.random(in: 300...2400) // 5-40 minutes
            
            return TrainingSession(
                id: UUID(),
                workoutType: workoutType,
                startTime: startTime,
                endTime: startTime.addingTimeInterval(duration),
                duration: duration,
                intervals: [], // Simplified for profile view
                heartRateData: [],
                locationData: [],
                caloriesBurned: Double.random(in: 100...500),
                averageHeartRate: Double.random(in: 120...180),
                maxHeartRate: Double.random(in: 160...200),
                distanceCovered: workoutType.hasDistance ? Double.random(in: 1.0...5.0) : nil,
                averagePace: workoutType.hasDistance ? Double.random(in: 4.0...8.0) : nil,
                notes: nil,
                weather: nil,
                perceivedExertion: nil,
                tags: []
            )
        }
    }
}

// MARK: - Extensions

extension WorkoutType {
    var hasDistance: Bool {
        switch self {
        case .shuttleRun, .runWalk:
            return true
        case .hiit, .tabata, .pyramid:
            return false
        }
    }
}
