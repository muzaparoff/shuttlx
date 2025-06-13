//
//  StatsView.swift
//  ShuttlX MVP
//
//  Created by ShuttlX on 6/8/25.
//

import SwiftUI
import HealthKit

// MARK: - Data Models for Stats

struct ActivitySummary {
    let workoutCount: Int
    let totalCalories: Double
    let totalDistance: Double
    let totalDuration: TimeInterval
    let averageHeartRate: Double
    
    static let empty = ActivitySummary(
        workoutCount: 0,
        totalCalories: 0,
        totalDistance: 0,
        totalDuration: 0,
        averageHeartRate: 0
    )
}

struct WeeklyStats {
    let workoutCount: Int
    let totalCalories: Double
    let totalDistance: Double
    let totalDuration: TimeInterval
    let averageIntensity: Double
    
    // Computed property for compatibility
    var totalWorkouts: Int { workoutCount }
    
    static let empty = WeeklyStats(
        workoutCount: 0,
        totalCalories: 0,
        totalDistance: 0,
        totalDuration: 0,
        averageIntensity: 0
    )
}

struct MonthlyStats {
    let workoutCount: Int
    let totalCalories: Double
    let totalDistance: Double
    let totalDuration: TimeInterval
    let averageWorkoutsPerWeek: Double
    
    static let empty = MonthlyStats(
        workoutCount: 0,
        totalCalories: 0,
        totalDistance: 0,
        totalDuration: 0,
        averageWorkoutsPerWeek: 0
    )
}

struct ProgressTrends {
    let caloriesTrend: TrendDirection
    let durationTrend: TrendDirection
    let frequencyTrend: TrendDirection
    let intensityTrend: TrendDirection
    
    // Add missing distanceTrend property
    var distanceTrend: TrendDirection {
        // For now, return the same as duration trend as a placeholder
        return durationTrend
    }
    
    // Computed properties for compatibility
    var overallTrend: TrendDirection {
        let trends = [caloriesTrend, durationTrend, frequencyTrend, intensityTrend]
        let upCount = trends.filter { $0 == .up || $0 == .improving }.count
        let downCount = trends.filter { $0 == .down }.count
        
        if upCount > downCount { return .improving }
        else if downCount > upCount { return .down }
        else { return .stable }
    }
    
    var weeklyProgression: [Double] {
        // Mock data for weekly progression
        return [0.8, 0.6, 0.9, 1.0, 0.7, 1.2, 1.1]
    }
    
    static let empty = ProgressTrends(
        caloriesTrend: .stable,
        durationTrend: .stable,
        frequencyTrend: .stable,
        intensityTrend: .stable
    )
}

struct PersonalBests {
    let maxCalories: Double
    let maxDuration: TimeInterval
    let maxDistance: Double
    let maxHeartRate: Double
    let maxIntervalsCompleted: Int
    
    // Aliases for backward compatibility
    var maxCaloriesInWorkout: Double { maxCalories }
    var maxDistanceInWorkout: Double { maxDistance }
    var longestWorkoutDuration: TimeInterval { maxDuration }
    var maxHeartRateInWorkout: Double { maxHeartRate }
    
    static let empty = PersonalBests(
        maxCalories: 0,
        maxDuration: 0,
        maxDistance: 0,
        maxHeartRate: 0,
        maxIntervalsCompleted: 0
    )
}

enum TrendDirection: String, CaseIterable {
    case up = "↗"
    case down = "↘"
    case stable = "→"
    case improving = "📈" // Trending upward
    
    var color: Color {
        switch self {
        case .up, .improving: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .up, .improving: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    // Add missing displayName property
    var displayName: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .stable: return "Stable"
        case .improving: return "Improving"
        }
    }
}

enum TimeFrame: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var displayName: String {
        return self.rawValue
    }
}

// Add missing CustomWorkoutAnalytics struct
struct CustomWorkoutAnalytics {
    let totalCustomWorkouts: Int
    let completedCustomWorkouts: Int
    let averageCaloriesPerWorkout: Double
    let averageDuration: Double
    let mostFrequentDifficulty: String
    
    static let empty = CustomWorkoutAnalytics(
        totalCustomWorkouts: 0,
        completedCustomWorkouts: 0,
        averageCaloriesPerWorkout: 0,
        averageDuration: 0,
        mostFrequentDifficulty: "Beginner"
    )
}

// Add missing goalProgress property to WeeklyStats
extension WeeklyStats {
    var goalProgress: Double {
        // Mock goal progress calculation - assuming a goal of 3 workouts per week
        let weeklyGoal = 3.0
        return min(Double(workoutCount) / weeklyGoal, 1.0)
    }
}

// MARK: - Simple Workout Stats Manager

@MainActor
class WorkoutStatsManager: ObservableObject {
    @Published var isLoading = false
    @Published var todaysWorkout: WorkoutResults?
    @Published var weeklyStats: WeeklyStats = WeeklyStats.empty
    @Published var monthlyStats: MonthlyStats = MonthlyStats.empty
    @Published var progressTrends: ProgressTrends = ProgressTrends.empty
    @Published var personalBests: PersonalBests = PersonalBests.empty
    
    static let shared = WorkoutStatsManager()
    
    private init() {
        loadStats()
    }
    
    func loadStats() {
        // Load workout data
        let allWorkouts = loadAllWorkouts()
        
        // Calculate stats
        todaysWorkout = getTodaysWorkout(from: allWorkouts)
        weeklyStats = calculateWeeklyStats(from: allWorkouts)
        monthlyStats = calculateMonthlyStats(from: allWorkouts)
        progressTrends = calculateTrends(from: allWorkouts)
        personalBests = calculatePersonalBests(from: allWorkouts)
    }
    
    func refreshStats() {
        loadStats()
    }
    
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
    
    // Add missing getCustomWorkoutAnalytics method
    func getCustomWorkoutAnalytics() -> CustomWorkoutAnalytics {
        // For MVP, return empty analytics since we don't have persistent custom workout storage yet
        return CustomWorkoutAnalytics(
            totalCustomWorkouts: 0,
            completedCustomWorkouts: 0,
            averageCaloriesPerWorkout: 0,
            averageDuration: 0,
            mostFrequentDifficulty: "Beginner"
        )
    }
    
    private func loadAllWorkouts() -> [WorkoutResults] {
        guard let data = UserDefaults.standard.data(forKey: "completedWorkouts_iOS"),
              let workouts = try? JSONDecoder().decode([WorkoutResults].self, from: data) else {
            return []
        }
        return workouts
    }
    
    private func getTodaysWorkout(from workouts: [WorkoutResults]) -> WorkoutResults? {
        return workouts.first { Calendar.current.isDateInToday($0.startDate) }
    }
    
    private func calculateWeeklyStats(from workouts: [WorkoutResults]) -> WeeklyStats {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklyWorkouts = workouts.filter { $0.startDate >= weekAgo }
        
        return WeeklyStats(
            workoutCount: weeklyWorkouts.count,
            totalCalories: weeklyWorkouts.reduce(0) { $0 + $1.activeCalories },
            totalDistance: weeklyWorkouts.reduce(0) { $0 + $1.distance },
            totalDuration: weeklyWorkouts.reduce(0) { $0 + $1.totalDuration },
            averageIntensity: weeklyWorkouts.isEmpty ? 0 : weeklyWorkouts.reduce(0) { $0 + $1.averageHeartRate } / Double(weeklyWorkouts.count)
        )
    }
    
    private func calculateMonthlyStats(from workouts: [WorkoutResults]) -> MonthlyStats {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let monthlyWorkouts = workouts.filter { $0.startDate >= monthAgo }
        
        return MonthlyStats(
            workoutCount: monthlyWorkouts.count,
            totalCalories: monthlyWorkouts.reduce(0) { $0 + $1.activeCalories },
            totalDistance: monthlyWorkouts.reduce(0) { $0 + $1.distance },
            totalDuration: monthlyWorkouts.reduce(0) { $0 + $1.totalDuration },
            averageWorkoutsPerWeek: Double(monthlyWorkouts.count) / 4.0
        )
    }
    
    private func calculateTrends(from workouts: [WorkoutResults]) -> ProgressTrends {
        // Simple trend calculation - compare last week vs previous week
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        
        let lastWeek = workouts.filter { $0.startDate >= weekAgo && $0.startDate < now }
        let previousWeek = workouts.filter { $0.startDate >= twoWeeksAgo && $0.startDate < weekAgo }
        
        let lastWeekCalories = lastWeek.reduce(0) { $0 + $1.activeCalories }
        let previousWeekCalories = previousWeek.reduce(0) { $0 + $1.activeCalories }
        
        let caloriesTrend: TrendDirection = {
            if lastWeekCalories > previousWeekCalories * 1.1 { return .up }
            else if lastWeekCalories < previousWeekCalories * 0.9 { return .down }
            else { return .stable }
        }()
        
        return ProgressTrends(
            caloriesTrend: caloriesTrend,
            durationTrend: .stable,
            frequencyTrend: lastWeek.count > previousWeek.count ? .up : (lastWeek.count < previousWeek.count ? .down : .stable),
            intensityTrend: .stable
        )
    }
    
    private func calculatePersonalBests(from workouts: [WorkoutResults]) -> PersonalBests {
        guard !workouts.isEmpty else { return PersonalBests.empty }
        
        return PersonalBests(
            maxCalories: workouts.map { $0.activeCalories }.max() ?? 0,
            maxDuration: workouts.map { $0.totalDuration }.max() ?? 0,
            maxDistance: workouts.map { $0.distance }.max() ?? 0,
            maxHeartRate: workouts.map { $0.averageHeartRate }.max() ?? 0,
            maxIntervalsCompleted: workouts.map { $0.completedIntervals }.max() ?? 0
        )
    }
}

struct StatsView: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    @StateObject private var statsManager = WorkoutStatsManager.shared
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    @State private var selectedTimeframe: TimeFrame = .week
    @State private var dataLoadingTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            OptimizedScrollView {
                VStack(spacing: 20) {
                    // Performance Indicator (when memory usage is high)
                    if performanceService.memoryUsage != .normal {
                        PerformanceIndicatorView()
                            .padding(.horizontal)
                    }
                    
                    // Today's Summary Section (ENHANCED)
                    todaysSummarySection
                        .optimizedForLists()
                    
                    // Workout Analytics Section (NEW)
                    workoutAnalyticsSection
                        .optimizedForLists()
                    
                    // Timeframe Picker
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        Text("Week").tag(TimeFrame.week)
                        Text("Month").tag(TimeFrame.month)
                        Text("Year").tag(TimeFrame.year)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: selectedTimeframe) { _, _ in
                        loadDataOptimized()
                    }
                    
                    // Enhanced Health Stats Cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        HealthStatCard(
                            title: "Heart Rate",
                            value: serviceLocator.healthManager.currentHeartRate > 0 ? "\(Int(serviceLocator.healthManager.currentHeartRate))" : "--",
                            unit: "BPM",
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        HealthStatCard(
                            title: "Active Energy",
                            value: "\(Int(getTodaysStats().totalCalories))",
                            unit: "CAL",
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        HealthStatCard(
                            title: "Distance",
                            value: String(format: "%.1f", getTodaysStats().totalDistance / 1000),
                            unit: "KM",
                            icon: "location.fill",
                            color: .green
                        )
                        
                        HealthStatCard(
                            title: "Workouts",
                            value: "\(getTodaysStats().workoutCount)",
                            unit: "TODAY",
                            icon: "figure.run",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    // Progress Trends Section (NEW)
                    progressTrendsSection
                    
                    // Training Programs Overview (ENHANCED)
                    trainingProgramsOverview
                    
                    // Personal Bests Section (NEW)
                    personalBestsSection
                    
                    // Custom Workout Analytics (NEW)
                    customWorkoutAnalyticsSection
                    
                    // Heart Rate Zones
                    HeartRateZonesCard()
                        .padding(.horizontal)
                    
                    // Recent Workouts (ENHANCED)
                    RecentWorkoutsCard()
                        .padding(.horizontal)
                    
                    // Weekly Progress Chart (NEW)
                    weeklyProgressChart
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("ShuttlX Home")
            .onAppear {
                loadDataOptimized()
            }
            .refreshable {
                statsManager.refreshStats()
            }
            .onDisappear {
                // Cancel any running tasks to prevent memory leaks
                dataLoadingTask?.cancel()
                performanceService.performMemoryCleanup()
            }
        }
    }
    
    // MARK: - Optimized Data Loading
    private func loadDataOptimized() {
        // Cancel previous task
        dataLoadingTask?.cancel()
        
        // Start new optimized loading task
        dataLoadingTask = Task {
            statsManager.refreshStats()
        }
    }
    
    // MARK: - Today's Summary Section
    private var todaysSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Activity")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Check for recent workout data
            if let todaysWorkout = statsManager.todaysWorkout {
                // Show today's workout summary
                TodaysWorkoutCard(workout: todaysWorkout)
            }
            
            // Quick Today Stats
            let todaysStats = getTodaysStats()
            HStack(spacing: 20) {
                TodayStatView(
                    title: "Steps",
                    value: "\(Int(serviceLocator.healthManager.todaySteps))",
                    icon: "figure.walk",
                    color: .blue,
                    target: "10,000"
                )
                
                TodayStatView(
                    title: "Calories",
                    value: "\(Int(todaysStats.totalCalories))",
                    icon: "flame.fill",
                    color: .orange,
                    target: "500"
                )
                
                TodayStatView(
                    title: "Distance",
                    value: String(format: "%.1f", todaysStats.totalDistance / 1000),
                    icon: "location.fill",
                    color: .green,
                    target: "5.0 km"
                )
            }
            
            // Apple Watch Training Reminder
            if todaysStats.workoutCount == 0 {
                HStack {
                    Image(systemName: "applewatch")
                        .foregroundColor(.blue)
                    Text("Ready for a workout? Start training on your Apple Watch!")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Workout Analytics Section
    private var workoutAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Workout Analytics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
            }
            
            let weeklyStats = statsManager.weeklyStats
            
            HStack(spacing: 16) {
                AnalyticsStatBubble(
                    title: "This Week",
                    value: "\(weeklyStats.totalWorkouts)",
                    subtitle: "Workouts",
                    icon: "figure.run",
                    color: .blue,
                    trend: weeklyStats.totalWorkouts > 0 ? .improving : .stable
                )
                
                AnalyticsStatBubble(
                    title: "Calories",
                    value: "\(Int(weeklyStats.totalCalories))",
                    subtitle: "Burned",
                    icon: "flame.fill",
                    color: .orange,
                    trend: statsManager.progressTrends.caloriesTrend
                )
                
                AnalyticsStatBubble(
                    title: "Distance",
                    value: String(format: "%.1f", weeklyStats.totalDistance / 1000),
                    subtitle: "km",
                    icon: "location.fill",
                    color: .green,
                    trend: statsManager.progressTrends.distanceTrend
                )
            }
            
            // Weekly Goal Progress
            if weeklyStats.goalProgress > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Weekly Goal Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(weeklyStats.goalProgress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: weeklyStats.goalProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Progress Trends Section
    private var progressTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Progress Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: statsManager.progressTrends.overallTrend.icon)
                    .foregroundColor(statsManager.progressTrends.overallTrend.color)
            }
            
            HStack(spacing: 16) {
                TrendIndicator(
                    title: "Calories",
                    trend: statsManager.progressTrends.caloriesTrend
                )
                
                TrendIndicator(
                    title: "Distance",
                    trend: statsManager.progressTrends.distanceTrend
                )
                
                TrendIndicator(
                    title: "Duration",
                    trend: statsManager.progressTrends.durationTrend
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Personal Bests Section
    private var personalBestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Personal Bests")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
            }
            
            let personalBests = statsManager.personalBests
            
            if personalBests.maxCaloriesInWorkout > 0 {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    PersonalBestCard(
                        title: "Max Calories",
                        value: "\(Int(personalBests.maxCaloriesInWorkout))",
                        unit: "cal",
                        icon: "flame.fill",
                        color: .orange
                    )
                    
                    PersonalBestCard(
                        title: "Max Distance",
                        value: String(format: "%.1f", personalBests.maxDistanceInWorkout / 1000),
                        unit: "km",
                        icon: "location.fill",
                        color: .green
                    )
                    
                    PersonalBestCard(
                        title: "Longest Workout",
                        value: formatDuration(personalBests.longestWorkoutDuration),
                        unit: "",
                        icon: "timer",
                        color: .blue
                    )
                    
                    PersonalBestCard(
                        title: "Max Intervals",
                        value: "\(personalBests.maxIntervalsCompleted)",
                        unit: "intervals",
                        icon: "arrow.triangle.2.circlepath",
                        color: .purple
                    )
                }
            } else {
                Text("Complete your first workout to see personal bests!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Custom Workout Analytics Section
    private var customWorkoutAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Custom Workout Analytics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.purple)
            }
            
            let customAnalytics = statsManager.getCustomWorkoutAnalytics()
            
            if customAnalytics.totalCustomWorkouts > 0 {
                HStack(spacing: 16) {
                    CustomWorkoutStatBubble(
                        title: "Created",
                        value: "\(customAnalytics.totalCustomWorkouts)",
                        subtitle: "Custom",
                        color: .purple
                    )
                    
                    CustomWorkoutStatBubble(
                        title: "Completed",
                        value: "\(customAnalytics.completedCustomWorkouts)",
                        subtitle: "Sessions",
                        color: .green
                    )
                    
                    CustomWorkoutStatBubble(
                        title: "Avg Calories",
                        value: "\(Int(customAnalytics.averageCaloriesPerWorkout))",
                        subtitle: "per workout",
                        color: .orange
                    )
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Most Frequent Difficulty")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(customAnalytics.mostFrequentDifficulty)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Average Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(customAnalytics.averageDuration)) min")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "star")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Text("No custom workouts yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    NavigationLink("Create Your First Custom Workout", destination: ProgramsView())
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Weekly Progress Chart
    private var weeklyProgressChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("Last 8 Weeks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            let progression = statsManager.progressTrends.weeklyProgression
            
            if progression.max() ?? 0 > 0 {
                OptimizedProgressChart(
                    data: progression, 
                    color: .blue
                )
                .frame(height: 60)
                .padding(.vertical)
            } else {
                Text("Start working out to see progress trends!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Training Programs Overview
    private var trainingProgramsOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Training Programs")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                NavigationLink("View All", destination: ProgramsView())
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            let customAnalytics = statsManager.getCustomWorkoutAnalytics()
            let weeklyStats = statsManager.weeklyStats
            
            HStack(spacing: 20) {
                ProgramStatBubble(
                    title: "Available",
                    value: "6", // Default programs count
                    icon: "list.bullet.circle.fill",
                    color: .orange
                )
                
                ProgramStatBubble(
                    title: "Custom",
                    value: "\(customAnalytics.totalCustomWorkouts)",
                    icon: "star.circle.fill",
                    color: .purple
                )
                
                ProgramStatBubble(
                    title: "Completed",
                    value: "\(weeklyStats.totalWorkouts)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    private func getTodaysStats() -> ActivitySummary {
        return statsManager.getTodaysActivitySummary()
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

// MARK: - Health Stat Card
struct HealthStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Heart Rate Zones Card
struct HeartRateZonesCard: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Heart Rate Zones")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(Array(HeartRateZone.allCases.enumerated()), id: \.offset) { index, zone in
                    HStack {
                        Circle()
                            .fill(Color(zone.color))
                            .frame(width: 12, height: 12)
                        
                        Text(zone.displayName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("0:00") // TODO: Get actual time in zone
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Recent Workouts Card
struct RecentWorkoutsCard: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Workouts")
                .font(.headline)
                .fontWeight(.semibold)
            
            if true { // Simplified for MVP - no workout history in SimpleHealthManager
                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start your first workout to see it here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    // Simplified for MVP - no workout history available
                    Text("No recent workouts")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Workout Row View
struct WorkoutRowView: View {
    let workout: TrainingSession
    
    var body: some View {
        HStack {
            Image(systemName: "figure.run")
                .foregroundColor(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(workout.startTime, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(workout.duration))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(Int(workout.calories)) cal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}

// MARK: - Today Stat View
struct TodayStatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let target: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("/ \(target)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Program Stat Bubble
struct ProgramStatBubble: View {
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
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - StatsView Helper Functions
extension StatsView {
    // Helper functions have been moved to the main view body
}

// MARK: - Today's Workout Card
struct TodaysWorkoutCard: View {
    let workout: WorkoutResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "applewatch")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest Workout")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Completed \(workout.startDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
            
            // Workout metrics
            HStack(spacing: 20) {
                WorkoutMetric(
                    title: "Duration",
                    value: formatDuration(workout.totalDuration),
                    icon: "timer",
                    color: .blue
                )
                
                WorkoutMetric(
                    title: "Calories",
                    value: "\(Int(workout.activeCalories))",
                    icon: "flame.fill",
                    color: .orange
                )
                
                WorkoutMetric(
                    title: "Distance",
                    value: String(format: "%.1f km", workout.distance / 1000),
                    icon: "location.fill",
                    color: .green
                )
            }
            
            // Intervals completed
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.purple)
                
                Text("\(workout.completedIntervals) intervals completed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if workout.averageHeartRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("\(Int(workout.averageHeartRate)) BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

// MARK: - Workout Metric Component
struct WorkoutMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - New Enhanced Components

struct AnalyticsStatBubble: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Spacer()
                Image(systemName: trend.icon)
                    .font(.caption2)
                    .foregroundColor(trend.color)
            }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TrendIndicator: View {
    let title: String
    let trend: TrendDirection
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: trend.icon)
                .font(.title3)
                .foregroundColor(trend.color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            
            Text(trend.displayName)
                .font(.caption2)
                .foregroundColor(trend.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(trend.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PersonalBestCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct CustomWorkoutStatBubble: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
