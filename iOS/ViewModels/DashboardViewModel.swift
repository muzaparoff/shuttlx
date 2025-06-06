//
//  DashboardViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var readinessScore: Double?
    @Published var todaysWorkouts = 0
    @Published var todaysCalories = 0
    @Published var todaysDuration: TimeInterval = 0
    @Published var recentWorkouts: [TrainingSession] = []
    @Published var recentAchievements: [Achievement] = []
    @Published var currentWeather: WeatherConditions?
    @Published var personalizedRecommendations: [PersonalizedRecommendation] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    var todaysDurationText: String {
        let minutes = Int(todaysDuration) / 60
        let seconds = Int(todaysDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init() {
        loadDashboardData()
    }
    
    func loadDashboardData() {
        isLoading = true
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadReadinessScore() }
                group.addTask { await self.loadTodaysStats() }
                group.addTask { await self.loadRecentWorkouts() }
                group.addTask { await self.loadRecentAchievements() }
                group.addTask { await self.loadWeatherData() }
                group.addTask { await self.loadPersonalizedRecommendations() }
            }
            
            isLoading = false
        }
    }
    
    func refreshData() async {
        await loadDashboardData()
    }
    
    func startQuickWorkout(_ workoutType: WorkoutType) {
        // Create a quick workout configuration based on the type
        let quickConfig = createQuickWorkoutConfiguration(for: workoutType)
        
        // Start the workout
        NotificationCenter.default.post(
            name: .startQuickWorkout,
            object: quickConfig
        )
    }
    
    private func loadReadinessScore() async {
        // Calculate readiness score based on various factors
        let baseScore = 75.0
        var adjustments = 0.0
        
        // Factor in recent workout load
        if recentWorkouts.count > 0 {
            let recentWorkoutLoad = calculateRecentWorkoutLoad()
            adjustments -= recentWorkoutLoad * 10 // Heavy load reduces readiness
        }
        
        // Factor in sleep quality (simulated for now)
        let sleepQuality = Double.random(in: 0.7...1.0)
        adjustments += (sleepQuality - 0.8) * 50
        
        // Factor in heart rate variability (simulated)
        let hrvScore = Double.random(in: 0.8...1.2)
        adjustments += (hrvScore - 1.0) * 25
        
        readinessScore = max(0, min(100, baseScore + adjustments))
    }
    
    private func loadTodaysStats() async {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Filter workouts for today
        let todaysWorkoutsList = recentWorkouts.filter { workout in
            workout.startTime >= today && workout.startTime < tomorrow
        }
        
        todaysWorkouts = todaysWorkoutsList.count
        todaysCalories = Int(todaysWorkoutsList.compactMap { $0.caloriesBurned }.reduce(0, +))
        todaysDuration = todaysWorkoutsList.map { $0.duration }.reduce(0, +)
    }
    
    private func loadRecentWorkouts() async {
        // Simulate loading recent workouts
        recentWorkouts = generateSampleWorkouts()
    }
    
    private func loadRecentAchievements() async {
        // Simulate loading recent achievements
        recentAchievements = generateSampleAchievements()
    }
    
    private func loadWeatherData() async {
        // Simulate weather API call
        currentWeather = WeatherConditions(
            temperature: Double.random(in: 15...25),
            humidity: Double.random(in: 40...80),
            windSpeed: Double.random(in: 5...15),
            condition: ["Sunny", "Cloudy", "Partly Cloudy", "Light Rain"].randomElement()!,
            visibility: 10.0,
            uvIndex: Int.random(in: 1...8),
            airQuality: .good
        )
    }
    
    private func loadPersonalizedRecommendations() async {
        var recommendations: [PersonalizedRecommendation] = []
        
        // Add recommendations based on user data
        if let readiness = readinessScore {
            if readiness < 60 {
                recommendations.append(PersonalizedRecommendation(
                    title: "Focus on Recovery",
                    description: "Your readiness score suggests light activity today",
                    icon: "bed.double.fill",
                    priority: .high
                ))
            } else if readiness > 85 {
                recommendations.append(PersonalizedRecommendation(
                    title: "Time for Intensity",
                    description: "You're ready for a challenging workout",
                    icon: "bolt.fill",
                    priority: .medium
                ))
            }
        }
        
        // Add hydration reminder
        recommendations.append(PersonalizedRecommendation(
            title: "Stay Hydrated",
            description: "Remember to drink water before your workout",
            icon: "drop.fill",
            priority: .low
        ))
        
        personalizedRecommendations = recommendations
    }
    
    private func calculateRecentWorkoutLoad() -> Double {
        let lastWeekWorkouts = recentWorkouts.filter { workout in
            workout.startTime > Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }
        
        let totalDuration = lastWeekWorkouts.map { $0.duration }.reduce(0, +)
        let averageIntensity = lastWeekWorkouts.compactMap { workout in
            // Estimate intensity based on workout type
            switch workout.workoutConfiguration.type {
            case .shuttleRun, .hiit, .tabata: return 0.8
            case .pyramid: return 0.7
            case .runWalk: return 0.5
            case .custom: return 0.6
            }
        }.reduce(0, +) / Double(max(1, lastWeekWorkouts.count))
        
        return (totalDuration / 3600.0) * averageIntensity // Hours * intensity
    }
    
    private func createQuickWorkoutConfiguration(for workoutType: WorkoutType) -> WorkoutConfiguration {
        switch workoutType {
        case .shuttleRun:
            return WorkoutConfiguration(
                type: .shuttleRun,
                name: "Quick Shuttle Run",
                description: "10-minute shuttle run session",
                duration: 600, // 10 minutes
                intervals: createShuttleRunIntervals(),
                restPeriods: [RestPeriod(duration: 30, type: .active, adaptiveRest: true)],
                difficulty: .intermediate,
                targetHeartRateZone: .zone3,
                audioCoaching: createDefaultAudioSettings(),
                hapticFeedback: createDefaultHapticSettings()
            )
            
        case .hiit:
            return WorkoutConfiguration(
                type: .hiit,
                name: "Quick HIIT",
                description: "15-minute high-intensity interval training",
                duration: 900, // 15 minutes
                intervals: createHIITIntervals(),
                restPeriods: [RestPeriod(duration: 60, type: .active, adaptiveRest: true)],
                difficulty: .intermediate,
                targetHeartRateZone: .zone4,
                audioCoaching: createDefaultAudioSettings(),
                hapticFeedback: createDefaultHapticSettings()
            )
            
        case .tabata:
            return WorkoutConfiguration(
                type: .tabata,
                name: "Quick Tabata",
                description: "4-minute Tabata session",
                duration: 240, // 4 minutes
                intervals: createTabataIntervals(),
                restPeriods: [RestPeriod(duration: 10, type: .complete, adaptiveRest: false)],
                difficulty: .advanced,
                targetHeartRateZone: .zone5,
                audioCoaching: createDefaultAudioSettings(),
                hapticFeedback: createDefaultHapticSettings()
            )
            
        case .pyramid:
            return WorkoutConfiguration(
                type: .pyramid,
                name: "Quick Pyramid",
                description: "12-minute pyramid training",
                duration: 720, // 12 minutes
                intervals: createPyramidIntervals(),
                restPeriods: [RestPeriod(duration: 45, type: .active, adaptiveRest: true)],
                difficulty: .intermediate,
                targetHeartRateZone: .zone3,
                audioCoaching: createDefaultAudioSettings(),
                hapticFeedback: createDefaultHapticSettings()
            )
            
        case .runWalk:
            return WorkoutConfiguration(
                type: .runWalk,
                name: "Quick Run/Walk",
                description: "20-minute run/walk session",
                duration: 1200, // 20 minutes
                intervals: createRunWalkIntervals(),
                restPeriods: [RestPeriod(duration: 60, type: .active, adaptiveRest: false)],
                difficulty: .beginner,
                targetHeartRateZone: .zone2,
                audioCoaching: createDefaultAudioSettings(),
                hapticFeedback: createDefaultHapticSettings()
            )
            
        case .custom:
            return WorkoutConfiguration(
                type: .custom,
                name: "Quick Custom",
                description: "10-minute custom workout",
                duration: 600, // 10 minutes
                intervals: createCustomIntervals(),
                restPeriods: [RestPeriod(duration: 30, type: .active, adaptiveRest: true)],
                difficulty: .intermediate,
                targetHeartRateZone: .zone3,
                audioCoaching: createDefaultAudioSettings(),
                hapticFeedback: createDefaultHapticSettings()
            )
        }
    }
    
    // MARK: - Interval Creation Methods
    private func createShuttleRunIntervals() -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // Warm-up
        intervals.append(WorkoutInterval(
            type: .warmup,
            duration: 120,
            intensity: .light,
            distance: nil,
            targetPace: nil,
            instructions: "Start with a gentle warm-up"
        ))
        
        // Main shuttle runs
        for i in 1...8 {
            intervals.append(WorkoutInterval(
                type: .work,
                duration: 30,
                intensity: .vigorous,
                distance: 20, // 20 meters
                targetPace: 2.0, // 2 seconds per meter
                instructions: "Sprint 20 meters, turn, sprint back"
            ))
            
            if i < 8 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: 30,
                    intensity: .veryLight,
                    distance: nil,
                    targetPace: nil,
                    instructions: "Active recovery - walk or light jog"
                ))
            }
        }
        
        // Cool-down
        intervals.append(WorkoutInterval(
            type: .cooldown,
            duration: 120,
            intensity: .veryLight,
            distance: nil,
            targetPace: nil,
            instructions: "Cool down with gentle movement"
        ))
        
        return intervals
    }
    
    private func createHIITIntervals() -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // Warm-up
        intervals.append(WorkoutInterval(
            type: .warmup,
            duration: 180,
            intensity: .light,
            distance: nil,
            targetPace: nil,
            instructions: "Warm up with dynamic movements"
        ))
        
        // HIIT rounds
        for i in 1...6 {
            intervals.append(WorkoutInterval(
                type: .work,
                duration: 45,
                intensity: .vigorous,
                distance: nil,
                targetPace: nil,
                instructions: "High intensity effort"
            ))
            
            if i < 6 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: 75,
                    intensity: .light,
                    distance: nil,
                    targetPace: nil,
                    instructions: "Active recovery"
                ))
            }
        }
        
        // Cool-down
        intervals.append(WorkoutInterval(
            type: .cooldown,
            duration: 180,
            intensity: .veryLight,
            distance: nil,
            targetPace: nil,
            instructions: "Cool down and stretch"
        ))
        
        return intervals
    }
    
    private func createTabataIntervals() -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // 8 rounds of 20s work, 10s rest
        for i in 1...8 {
            intervals.append(WorkoutInterval(
                type: .work,
                duration: 20,
                intensity: .maximal,
                distance: nil,
                targetPace: nil,
                instructions: "Maximum effort for 20 seconds"
            ))
            
            if i < 8 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: 10,
                    intensity: .veryLight,
                    distance: nil,
                    targetPace: nil,
                    instructions: "Complete rest"
                ))
            }
        }
        
        return intervals
    }
    
    private func createPyramidIntervals() -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        let durations = [30, 60, 90, 120, 90, 60, 30] // Pyramid pattern
        
        for (index, duration) in durations.enumerated() {
            intervals.append(WorkoutInterval(
                type: .work,
                duration: TimeInterval(duration),
                intensity: .vigorous,
                distance: nil,
                targetPace: nil,
                instructions: "Maintain steady high effort"
            ))
            
            if index < durations.count - 1 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: TimeInterval(duration / 2),
                    intensity: .light,
                    distance: nil,
                    targetPace: nil,
                    instructions: "Active recovery"
                ))
            }
        }
        
        return intervals
    }
    
    private func createRunWalkIntervals() -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // Alternate run and walk intervals
        for i in 1...10 {
            // Run interval
            intervals.append(WorkoutInterval(
                type: .work,
                duration: 60,
                intensity: .moderate,
                distance: nil,
                targetPace: nil,
                instructions: "Comfortable running pace"
            ))
            
            // Walk interval
            intervals.append(WorkoutInterval(
                type: .rest,
                duration: 60,
                intensity: .light,
                distance: nil,
                targetPace: nil,
                instructions: "Brisk walk recovery"
            ))
        }
        
        return intervals
    }
    
    private func createCustomIntervals() -> [WorkoutInterval] {
        // Simple custom workout
        return [
            WorkoutInterval(
                type: .warmup,
                duration: 120,
                intensity: .light,
                distance: nil,
                targetPace: nil,
                instructions: "Warm up"
            ),
            WorkoutInterval(
                type: .work,
                duration: 360,
                intensity: .moderate,
                distance: nil,
                targetPace: nil,
                instructions: "Steady effort"
            ),
            WorkoutInterval(
                type: .cooldown,
                duration: 120,
                intensity: .veryLight,
                distance: nil,
                targetPace: nil,
                instructions: "Cool down"
            )
        ]
    }
    
    private func createDefaultAudioSettings() -> AudioCoachingSettings {
        return AudioCoachingSettings(
            enabled: true,
            voiceType: .neutral,
            encouragementLevel: .moderate,
            techniqueTips: true,
            intervalAnnouncements: true,
            heartRateAnnouncements: false,
            paceGuidance: true
        )
    }
    
    private func createDefaultHapticSettings() -> HapticFeedbackSettings {
        return HapticFeedbackSettings(
            enabled: true,
            intervalTransitions: true,
            heartRateAlerts: false,
            paceAlerts: false,
            motivationalTaps: true,
            intensity: .medium
        )
    }
    
    // MARK: - Sample Data Generation
    private func generateSampleWorkouts() -> [TrainingSession] {
        // Generate sample workout data for demonstration
        return []
    }
    
    private func generateSampleAchievements() -> [Achievement] {
        return [
            Achievement(
                title: "First Workout",
                description: "Complete your first workout",
                icon: "star.fill",
                category: .special,
                pointValue: 50,
                requirement: Achievement.AchievementRequirement(
                    type: .workoutCount,
                    value: 1,
                    timeframe: .allTime
                ),
                unlockedAt: Date(),
                isHidden: false
            ),
            Achievement(
                title: "Speed Demon",
                description: "Reach maximum heart rate zone",
                icon: "bolt.fill",
                category: .speed,
                pointValue: 100,
                requirement: Achievement.AchievementRequirement(
                    type: .maxSpeed,
                    value: 90,
                    timeframe: .day
                ),
                unlockedAt: nil,
                isHidden: false
            )
        ]
    }
}

// MARK: - Supporting Models
struct PersonalizedRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let priority: Priority
    
    enum Priority {
        case low, medium, high
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let startQuickWorkout = Notification.Name("startQuickWorkout")
}
