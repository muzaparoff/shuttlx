//
//  WorkoutStatsManager.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/11/25.
//

import Foundation
import SwiftUI

/// Comprehensive workout statistics and analytics manager for iOS
@MainActor
class WorkoutStatsManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var todaysWorkout: WorkoutResults?
    @Published var weeklyStats: WeeklyStats = WeeklyStats.empty
    @Published var monthlyStats: MonthlyStats = MonthlyStats.empty
    @Published var progressTrends: ProgressTrends = ProgressTrends.empty
    @Published var achievements: [Achievement] = []
    @Published var personalBests: PersonalBests = PersonalBests.empty
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let trainingProgramManager = TrainingProgramManager.shared
    
    // MARK: - Singleton
    static let shared = WorkoutStatsManager()
    
    private init() {
        loadStats()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Load and calculate all workout statistics
    func loadStats() async {
        isLoading = true
        
        // Load workout data
        let allWorkouts = loadAllWorkouts()
        
        // Calculate today's workout
        todaysWorkout = getTodaysWorkout(from: allWorkouts)
        
        // Calculate weekly stats
        weeklyStats = calculateWeeklyStats(from: allWorkouts)
        
        // Calculate monthly stats
        monthlyStats = calculateMonthlyStats(from: allWorkouts)
        
        // Calculate progress trends
        progressTrends = calculateProgressTrends(from: allWorkouts)
        
        // Update personal bests
        personalBests = calculatePersonalBests(from: allWorkouts)
        
        // Check for new achievements
        achievements = checkAchievements(from: allWorkouts)
        
        isLoading = false
    }
    
    /// Refresh stats when new workout data is available
    func refreshStats() {
        Task {
            await loadStats()
        }
    }
    
    /// Get formatted today's activity summary
    func getTodaysActivitySummary() -> ActivitySummary {
        let workouts = loadAllWorkouts()
        let todaysWorkouts = workouts.filter { Calendar.current.isDateInToday($0.startDate) }
        
        let totalCalories = todaysWorkouts.reduce(0) { $0 + $1.activeCalories }
        let totalDistance = todaysWorkouts.reduce(0) { $0 + $1.distance }
        let totalDuration = todaysWorkouts.reduce(0) { $0 + $1.totalDuration }
        let workoutCount = todaysWorkouts.count
        
        return ActivitySummary(
            workoutCount: workoutCount,
            totalCalories: totalCalories,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            averageHeartRate: todaysWorkouts.isEmpty ? 0 : todaysWorkouts.reduce(0) { $0 + $1.averageHeartRate } / Double(todaysWorkouts.count)
        )
    }
    
    /// Get workout statistics for specific time period
    func getStatsForPeriod(_ period: StatsPeriod) -> PeriodStats {
        let workouts = loadAllWorkouts()
        let filteredWorkouts = filterWorkouts(workouts, for: period)
        
        return calculatePeriodStats(from: filteredWorkouts)
    }
    
    /// Get custom workout performance analytics
    func getCustomWorkoutAnalytics() -> CustomWorkoutAnalytics {
        let allWorkouts = loadAllWorkouts()
        let customPrograms = trainingProgramManager.customPrograms
        
        let customWorkoutCount = customPrograms.count
        let completedCustomWorkouts = allWorkouts.filter { workout in
            // Match workout with custom programs by duration/intervals
            customPrograms.contains { program in
                abs(workout.totalDuration - (program.totalDuration * 60)) < 120 // Within 2 minutes
            }
        }
        
        let avgCaloriesPerCustomWorkout = completedCustomWorkouts.isEmpty ? 0 :
            completedCustomWorkouts.reduce(0) { $0 + $1.activeCalories } / Double(completedCustomWorkouts.count)
        
        let avgDistancePerCustomWorkout = completedCustomWorkouts.isEmpty ? 0 :
            completedCustomWorkouts.reduce(0) { $0 + $1.distance } / Double(completedCustomWorkouts.count)
        
        return CustomWorkoutAnalytics(
            totalCustomWorkouts: customWorkoutCount,
            completedCustomWorkouts: completedCustomWorkouts.count,
            averageCaloriesPerWorkout: avgCaloriesPerCustomWorkout,
            averageDistancePerWorkout: avgDistancePerCustomWorkout,
            mostFrequentDifficulty: customPrograms.mostFrequent(by: \.difficulty)?.displayName ?? "N/A",
            averageDuration: customPrograms.isEmpty ? 0 : customPrograms.reduce(0) { $0 + $1.totalDuration } / Double(customPrograms.count)
        )
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .workoutCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshStats()
        }
        
        NotificationCenter.default.addObserver(
            forName: .customWorkoutCreated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshStats()
        }
    }
    
    private func loadAllWorkouts() -> [WorkoutResults] {
        // Load from iOS completed workouts
        var allWorkouts: [WorkoutResults] = []
        
        // Load iOS workouts
        if let iosData = userDefaults.data(forKey: "completedWorkouts_iOS"),
           let iosWorkouts = try? JSONDecoder().decode([WorkoutResults].self, from: iosData) {
            allWorkouts.append(contentsOf: iosWorkouts)
        }
        
        // Load watch workouts if not already synced
        if let watchData = userDefaults.data(forKey: "lastWorkoutResults"),
           let watchWorkout = try? JSONDecoder().decode(WorkoutResults.self, from: watchData) {
            // Check if this workout is already in iOS data
            if !allWorkouts.contains(where: { $0.workoutId == watchWorkout.workoutId }) {
                allWorkouts.append(watchWorkout)
            }
        }
        
        // Sort by date (most recent first)
        return allWorkouts.sorted { $0.startDate > $1.startDate }
    }
    
    private func getTodaysWorkout(from workouts: [WorkoutResults]) -> WorkoutResults? {
        return workouts.first { Calendar.current.isDateInToday($0.startDate) }
    }
    
    private func calculateWeeklyStats(from workouts: [WorkoutResults]) -> WeeklyStats {
        let weekWorkouts = filterWorkoutsForCurrentWeek(workouts)
        
        let totalWorkouts = weekWorkouts.count
        let totalCalories = weekWorkouts.reduce(0) { $0 + $1.activeCalories }
        let totalDistance = weekWorkouts.reduce(0) { $0 + $1.distance }
        let totalDuration = weekWorkouts.reduce(0) { $0 + $1.totalDuration }
        let avgHeartRate = weekWorkouts.isEmpty ? 0 : weekWorkouts.reduce(0) { $0 + $1.averageHeartRate } / Double(weekWorkouts.count)
        
        // Calculate daily breakdown
        var dailyWorkouts: [Int] = Array(repeating: 0, count: 7)
        var dailyCalories: [Double] = Array(repeating: 0, count: 7)
        
        for workout in weekWorkouts {
            let weekday = Calendar.current.component(.weekday, from: workout.startDate) - 1 // 0-6
            dailyWorkouts[weekday] += 1
            dailyCalories[weekday] += workout.activeCalories
        }
        
        return WeeklyStats(
            totalWorkouts: totalWorkouts,
            totalCalories: totalCalories,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            averageHeartRate: avgHeartRate,
            dailyWorkouts: dailyWorkouts,
            dailyCalories: dailyCalories,
            goalProgress: min(1.0, Double(totalWorkouts) / 5.0) // Goal: 5 workouts per week
        )
    }
    
    private func calculateMonthlyStats(from workouts: [WorkoutResults]) -> MonthlyStats {
        let monthWorkouts = filterWorkoutsForCurrentMonth(workouts)
        
        let totalWorkouts = monthWorkouts.count
        let totalCalories = monthWorkouts.reduce(0) { $0 + $1.activeCalories }
        let totalDistance = monthWorkouts.reduce(0) { $0 + $1.distance }
        let totalDuration = monthWorkouts.reduce(0) { $0 + $1.totalDuration }
        
        // Calculate weekly breakdown for the month
        var weeklyBreakdown: [Double] = []
        let calendar = Calendar.current
        let now = Date()
        
        for week in 0..<4 {
            let weekStart = calendar.date(byAdding: .weekOfMonth, value: -week, to: now) ?? now
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
            
            let weekWorkouts = monthWorkouts.filter { workout in
                workout.startDate >= weekStart && workout.startDate < weekEnd
            }
            
            let weekCalories = weekWorkouts.reduce(0) { $0 + $1.activeCalories }
            weeklyBreakdown.insert(weekCalories, at: 0)
        }
        
        return MonthlyStats(
            totalWorkouts: totalWorkouts,
            totalCalories: totalCalories,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            weeklyCaloriesBreakdown: weeklyBreakdown,
            averageWorkoutsPerWeek: Double(totalWorkouts) / 4.0,
            monthlyGoalProgress: min(1.0, Double(totalWorkouts) / 20.0) // Goal: 20 workouts per month
        )
    }
    
    private func calculateProgressTrends(from workouts: [WorkoutResults]) -> ProgressTrends {
        let recentWorkouts = Array(workouts.prefix(10)) // Last 10 workouts
        let previousWorkouts = Array(workouts.dropFirst(10).prefix(10)) // Previous 10 workouts
        
        let recentAvgCalories = recentWorkouts.isEmpty ? 0 : recentWorkouts.reduce(0) { $0 + $1.activeCalories } / Double(recentWorkouts.count)
        let previousAvgCalories = previousWorkouts.isEmpty ? 0 : previousWorkouts.reduce(0) { $0 + $1.activeCalories } / Double(previousWorkouts.count)
        
        let recentAvgDistance = recentWorkouts.isEmpty ? 0 : recentWorkouts.reduce(0) { $0 + $1.distance } / Double(recentWorkouts.count)
        let previousAvgDistance = previousWorkouts.isEmpty ? 0 : previousWorkouts.reduce(0) { $0 + $1.distance } / Double(previousWorkouts.count)
        
        let recentAvgDuration = recentWorkouts.isEmpty ? 0 : recentWorkouts.reduce(0) { $0 + $1.totalDuration } / Double(recentWorkouts.count)
        let previousAvgDuration = previousWorkouts.isEmpty ? 0 : previousWorkouts.reduce(0) { $0 + $1.totalDuration } / Double(previousWorkouts.count)
        
        let caloriesTrend = calculateTrendDirection(recent: recentAvgCalories, previous: previousAvgCalories)
        let distanceTrend = calculateTrendDirection(recent: recentAvgDistance, previous: previousAvgDistance)
        let durationTrend = calculateTrendDirection(recent: recentAvgDuration, previous: previousAvgDuration)
        
        return ProgressTrends(
            caloriesTrend: caloriesTrend,
            distanceTrend: distanceTrend,
            durationTrend: durationTrend,
            overallTrend: calculateOverallTrend([caloriesTrend, distanceTrend, durationTrend]),
            weeklyProgression: calculateWeeklyProgression(from: workouts)
        )
    }
    
    private func calculatePersonalBests(from workouts: [WorkoutResults]) -> PersonalBests {
        guard !workouts.isEmpty else { return PersonalBests.empty }
        
        let maxCalories = workouts.max { $0.activeCalories < $1.activeCalories }?.activeCalories ?? 0
        let maxDistance = workouts.max { $0.distance < $1.distance }?.distance ?? 0
        let maxDuration = workouts.max { $0.totalDuration < $1.totalDuration }?.totalDuration ?? 0
        let maxHeartRate = workouts.max { $0.maxHeartRate < $1.maxHeartRate }?.maxHeartRate ?? 0
        let maxIntervals = workouts.max { $0.completedIntervals < $1.completedIntervals }?.completedIntervals ?? 0
        
        return PersonalBests(
            maxCaloriesInWorkout: maxCalories,
            maxDistanceInWorkout: maxDistance,
            longestWorkoutDuration: maxDuration,
            maxHeartRate: maxHeartRate,
            maxIntervalsCompleted: maxIntervals,
            bestPace: calculateBestPace(from: workouts)
        )
    }
    
    private func checkAchievements(from workouts: [WorkoutResults]) -> [Achievement] {
        var achievements: [Achievement] = []
        
        // First workout achievement
        if workouts.count >= 1 && achievements.isEmpty {
            achievements.append(Achievement(
                title: "First Steps",
                description: "Completed your first workout",
                iconName: "figure.run",
                unlockedDate: workouts.last?.startDate,
                isUnlocked: true,
                category: .milestone
            ))
        }
        
        // Weekly streak achievements
        let currentStreak = calculateCurrentStreak(from: workouts)
        if currentStreak >= 7 {
            achievements.append(Achievement(
                title: "Week Warrior",
                description: "Completed 7 days in a row",
                iconName: "calendar",
                unlockedDate: Date(),
                isUnlocked: true,
                category: .streak
            ))
        }
        
        // Distance achievements
        let totalDistance = workouts.reduce(0) { $0 + $1.distance }
        if totalDistance >= 50000 { // 50km
            achievements.append(Achievement(
                title: "Distance Destroyer",
                description: "Covered 50km total distance",
                iconName: "location.fill",
                unlockedDate: Date(),
                isUnlocked: true,
                category: .distance
            ))
        }
        
        // Calorie achievements
        let totalCalories = workouts.reduce(0) { $0 + $1.activeCalories }
        if totalCalories >= 5000 {
            achievements.append(Achievement(
                title: "Calorie Crusher",
                description: "Burned 5000 total calories",
                iconName: "flame.fill",
                unlockedDate: Date(),
                isUnlocked: true,
                category: .calories
            ))
        }
        
        return achievements
    }
    
    // MARK: - Helper Methods
    
    private func filterWorkoutsForCurrentWeek(_ workouts: [WorkoutResults]) -> [WorkoutResults] {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        return workouts.filter { $0.startDate >= weekStart }
    }
    
    private func filterWorkoutsForCurrentMonth(_ workouts: [WorkoutResults]) -> [WorkoutResults] {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return workouts.filter { $0.startDate >= monthStart }
    }
    
    private func filterWorkouts(_ workouts: [WorkoutResults], for period: StatsPeriod) -> [WorkoutResults] {
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return workouts.filter { $0.startDate >= weekStart }
        case .month:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return workouts.filter { $0.startDate >= monthStart }
        case .year:
            let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return workouts.filter { $0.startDate >= yearStart }
        case .allTime:
            return workouts
        }
    }
    
    private func calculatePeriodStats(from workouts: [WorkoutResults]) -> PeriodStats {
        let totalWorkouts = workouts.count
        let totalCalories = workouts.reduce(0) { $0 + $1.activeCalories }
        let totalDistance = workouts.reduce(0) { $0 + $1.distance }
        let totalDuration = workouts.reduce(0) { $0 + $1.totalDuration }
        let avgHeartRate = workouts.isEmpty ? 0 : workouts.reduce(0) { $0 + $1.averageHeartRate } / Double(workouts.count)
        
        return PeriodStats(
            totalWorkouts: totalWorkouts,
            totalCalories: totalCalories,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            averageHeartRate: avgHeartRate
        )
    }
    
    private func calculateTrendDirection(recent: Double, previous: Double) -> TrendDirection {
        guard previous > 0 else { return .stable }
        
        let changePercent = ((recent - previous) / previous) * 100
        
        if changePercent > 5 {
            return .improving
        } else if changePercent < -5 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func calculateOverallTrend(_ trends: [TrendDirection]) -> TrendDirection {
        let improving = trends.filter { $0 == .improving }.count
        let declining = trends.filter { $0 == .declining }.count
        
        if improving > declining {
            return .improving
        } else if declining > improving {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func calculateWeeklyProgression(from workouts: [WorkoutResults]) -> [Double] {
        let calendar = Calendar.current
        let now = Date()
        var progression: [Double] = []
        
        for week in 0..<8 { // Last 8 weeks
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: now) ?? now
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
            
            let weekWorkouts = workouts.filter { workout in
                workout.startDate >= weekStart && workout.startDate < weekEnd
            }
            
            let weekCalories = weekWorkouts.reduce(0) { $0 + $1.activeCalories }
            progression.insert(weekCalories, at: 0)
        }
        
        return progression
    }
    
    private func calculateBestPace(from workouts: [WorkoutResults]) -> Double {
        let validPaces = workouts.compactMap { workout -> Double? in
            guard workout.distance > 0 && workout.totalDuration > 0 else { return nil }
            return (workout.totalDuration / 60.0) / (workout.distance / 1000.0) // minutes per km
        }
        
        return validPaces.min() ?? 0 // Best (fastest) pace
    }
    
    private func calculateCurrentStreak(from workouts: [WorkoutResults]) -> Int {
        let calendar = Calendar.current
        let sortedWorkouts = workouts.sorted { $0.startDate > $1.startDate }
        
        var streak = 0
        var currentDate = Date()
        
        for workout in sortedWorkouts {
            if calendar.isDate(workout.startDate, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
}

// MARK: - Supporting Data Models

struct ActivitySummary {
    let workoutCount: Int
    let totalCalories: Double
    let totalDistance: Double
    let totalDuration: TimeInterval
    let averageHeartRate: Double
    
    var formattedDistance: String {
        return String(format: "%.1f km", totalDistance / 1000)
    }
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct WeeklyStats {
    let totalWorkouts: Int
    let totalCalories: Double
    let totalDistance: Double
    let totalDuration: TimeInterval
    let averageHeartRate: Double
    let dailyWorkouts: [Int]
    let dailyCalories: [Double]
    let goalProgress: Double
    
    static let empty = WeeklyStats(
        totalWorkouts: 0,
        totalCalories: 0,
        totalDistance: 0,
        totalDuration: 0,
        averageHeartRate: 0,
        dailyWorkouts: Array(repeating: 0, count: 7),
        dailyCalories: Array(repeating: 0, count: 7),
        goalProgress: 0
    )
}

struct MonthlyStats {
    let totalWorkouts: Int
    let totalCalories: Double
    let totalDistance: Double
    let totalDuration: TimeInterval
    let weeklyCaloriesBreakdown: [Double]
    let averageWorkoutsPerWeek: Double
    let monthlyGoalProgress: Double
    
    static let empty = MonthlyStats(
        totalWorkouts: 0,
        totalCalories: 0,
        totalDistance: 0,
        totalDuration: 0,
        weeklyCaloriesBreakdown: Array(repeating: 0, count: 4),
        averageWorkoutsPerWeek: 0,
        monthlyGoalProgress: 0
    )
}

struct ProgressTrends {
    let caloriesTrend: TrendDirection
    let distanceTrend: TrendDirection
    let durationTrend: TrendDirection
    let overallTrend: TrendDirection
    let weeklyProgression: [Double]
    
    static let empty = ProgressTrends(
        caloriesTrend: .stable,
        distanceTrend: .stable,
        durationTrend: .stable,
        overallTrend: .stable,
        weeklyProgression: Array(repeating: 0, count: 8)
    )
}

struct PersonalBests {
    let maxCaloriesInWorkout: Double
    let maxDistanceInWorkout: Double
    let longestWorkoutDuration: TimeInterval
    let maxHeartRate: Double
    let maxIntervalsCompleted: Int
    let bestPace: Double
    
    static let empty = PersonalBests(
        maxCaloriesInWorkout: 0,
        maxDistanceInWorkout: 0,
        longestWorkoutDuration: 0,
        maxHeartRate: 0,
        maxIntervalsCompleted: 0,
        bestPace: 0
    )
}

struct CustomWorkoutAnalytics {
    let totalCustomWorkouts: Int
    let completedCustomWorkouts: Int
    let averageCaloriesPerWorkout: Double
    let averageDistancePerWorkout: Double
    let mostFrequentDifficulty: String
    let averageDuration: Double
}

struct PeriodStats {
    let totalWorkouts: Int
    let totalCalories: Double
    let totalDistance: Double
    let totalDuration: TimeInterval
    let averageHeartRate: Double
}

enum StatsPeriod: CaseIterable {
    case week, month, year, allTime
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .allTime: return "All Time"
        }
    }
}

enum TrendDirection: CaseIterable {
    case improving, stable, declining
    
    var displayName: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }
    
    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up.circle.fill"
        case .stable: return "minus.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let workoutCompleted = Notification.Name("workoutCompleted")
    static let customWorkoutCreated = Notification.Name("customWorkoutCreated")
}

// MARK: - Array Extensions

extension Array {
    func mostFrequent<T: Hashable>(by keyPath: KeyPath<Element, T>) -> Element? {
        let grouped = Dictionary(grouping: self) { $0[keyPath: keyPath] }
        return grouped.max { $0.value.count < $1.value.count }?.value.first
    }
}
