//
//  TrainingPlansViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import SwiftUI

@MainActor
class TrainingPlansViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var allPlans: [TrainingPlan] = []
    @Published var activePlan: TrainingPlan?
    @Published var recommendedPlans: [TrainingPlan] = []
    @Published var sortBy: SortOption = .recent
    @Published var isLoading = false
    
    // Stats
    @Published var completedPlansCount: Int = 0
    @Published var totalTrainingHours: Int = 0
    @Published var currentStreak: Int = 0
    @Published var weeklyAverage: Int = 0
    
    // MARK: - Computed Properties
    var sortedPlans: [TrainingPlan] {
        var sorted = allPlans
        
        switch sortBy {
        case .name:
            sorted.sort { $0.name < $1.name }
        case .duration:
            sorted.sort { $0.totalWeeks < $1.totalWeeks }
        case .difficulty:
            sorted.sort { $0.difficulty.sortValue < $1.difficulty.sortValue }
        case .recent:
            sorted.sort { $0.createdAt > $1.createdAt }
        }
        
        return sorted
    }
    
    // MARK: - Methods
    func loadTrainingPlans() {
        isLoading = true
        
        // Load predefined plans and user's custom plans
        allPlans = defaultTrainingPlans + loadCustomPlans()
        
        // Load active plan
        activePlan = allPlans.first { $0.isActive }
        
        // Generate recommendations
        generateRecommendations()
        
        // Load statistics
        loadStatistics()
        
        isLoading = false
    }
    
    @MainActor
    func refreshData() async {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        loadTrainingPlans()
    }
    
    func addTrainingPlan(_ plan: TrainingPlan) {
        allPlans.append(plan)
        saveCustomPlans()
    }
    
    func deletePlan(_ plan: TrainingPlan) {
        allPlans.removeAll { $0.id == plan.id }
        
        if activePlan?.id == plan.id {
            activePlan = nil
        }
        
        saveCustomPlans()
    }
    
    func startPlan(_ plan: TrainingPlan) {
        // Deactivate current active plan
        if let activeIndex = allPlans.firstIndex(where: { $0.isActive }) {
            allPlans[activeIndex].isActive = false
        }
        
        // Activate the new plan
        if let planIndex = allPlans.firstIndex(where: { $0.id == plan.id }) {
            allPlans[planIndex].isActive = true
            activePlan = allPlans[planIndex]
        }
        
        saveCustomPlans()
    }
    
    // MARK: - Private Methods
    private func loadCustomPlans() -> [TrainingPlan] {
        // Load from UserDefaults or Core Data
        // For now, return empty array
        return []
    }
    
    private func saveCustomPlans() {
        // Save custom plans to persistent storage
        let customPlans = allPlans.filter { !$0.isBuiltIn }
        // Implementation would save to UserDefaults or Core Data
    }
    
    private func generateRecommendations() {
        // Generate recommendations based on user's fitness level, completed workouts, etc.
        recommendedPlans = Array(allPlans.prefix(3))
    }
    
    private func loadStatistics() {
        // Load user statistics from persistent storage
        completedPlansCount = 3
        totalTrainingHours = 47
        currentStreak = 12
        weeklyAverage = 5
    }
    
    // MARK: - Default Training Plans
    private var defaultTrainingPlans: [TrainingPlan] {
        return [
            // Beginner Shuttle Run Plan
            TrainingPlan(
                name: "Beginner Shuttle Run Mastery",
                description: "Master the basics of shuttle running with this progressive 6-week plan designed for beginners",
                type: .shuttleRun,
                difficulty: .beginner,
                totalWeeks: 6,
                completedWeeks: 0,
                workouts: generateBeginnerShuttleWorkouts(),
                tags: ["beginner", "shuttle", "technique"],
                isActive: false,
                createdAt: Date()
            ),
            
            // Intermediate HIIT Plan
            TrainingPlan(
                name: "HIIT Performance Builder",
                description: "Build explosive power and endurance with this challenging 8-week HIIT program",
                type: .hiit,
                difficulty: .intermediate,
                totalWeeks: 8,
                completedWeeks: 0,
                workouts: generateHIITWorkouts(),
                tags: ["hiit", "power", "cardio", "intermediate"],
                isActive: false,
                createdAt: Date()
            ),
            
            // Advanced Endurance Plan
            TrainingPlan(
                name: "Elite Endurance Program",
                description: "Push your limits with this comprehensive 12-week endurance and conditioning program",
                type: .endurance,
                difficulty: .advanced,
                totalWeeks: 12,
                completedWeeks: 0,
                workouts: generateEnduranceWorkouts(),
                tags: ["endurance", "advanced", "conditioning"],
                isActive: false,
                createdAt: Date()
            ),
            
            // Mixed Training Plan
            TrainingPlan(
                name: "Complete Fitness Journey",
                description: "A well-rounded 10-week program combining shuttle runs, HIIT, and endurance training",
                type: .mixed,
                difficulty: .intermediate,
                totalWeeks: 10,
                completedWeeks: 0,
                workouts: generateMixedWorkouts(),
                tags: ["mixed", "complete", "variety"],
                isActive: false,
                createdAt: Date()
            ),
            
            // Quick Start Plan
            TrainingPlan(
                name: "Quick Start Challenge",
                description: "Get moving with this intensive 4-week plan designed to build momentum",
                type: .mixed,
                difficulty: .beginner,
                totalWeeks: 4,
                completedWeeks: 0,
                workouts: generateQuickStartWorkouts(),
                tags: ["quick", "starter", "momentum"],
                isActive: false,
                createdAt: Date()
            )
        ]
    }
    
    // MARK: - Workout Generation Methods
    private func generateBeginnerShuttleWorkouts() -> [PlannedWorkout] {
        var workouts: [PlannedWorkout] = []
        
        for week in 1...6 {
            for day in [1, 3, 5] { // Monday, Wednesday, Friday
                let intensity: ExerciseIntensity = week <= 2 ? .low : week <= 4 ? .moderate : .high
                let rounds = min(5 + week, 12)
                
                let workout = CustomWorkout(
                    name: "Week \(week) Shuttle Training",
                    type: .shuttleRun,
                    difficulty: .beginner,
                    intervals: [
                        WorkoutInterval(type: .warmup, duration: 300, intensity: .low, distance: nil, notes: "Dynamic warmup"),
                        WorkoutInterval(type: .work, duration: 15, intensity: intensity, distance: 20, notes: "20m shuttle run"),
                        WorkoutInterval(type: .rest, duration: 45, intensity: .low, distance: nil, notes: "Active recovery"),
                        WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Cool down stretch")
                    ],
                    estimatedDuration: TimeInterval((rounds * 60) + 600),
                    estimatedCalories: 150 + (week * 10),
                    notes: "Focus on proper form and technique",
                    tags: ["beginner", "shuttle", "week\(week)"]
                )
                
                workouts.append(PlannedWorkout(
                    name: "Shuttle Training - Week \(week), Day \(day)",
                    description: "Progressive shuttle run training session",
                    week: week,
                    day: day,
                    workout: workout,
                    isCompleted: false
                ))
            }
        }
        
        return workouts
    }
    
    private func generateHIITWorkouts() -> [PlannedWorkout] {
        var workouts: [PlannedWorkout] = []
        
        for week in 1...8 {
            for day in [1, 3, 5] {
                let workDuration = min(30 + (week * 5), 60)
                let restDuration = max(30 - (week * 2), 15)
                let cycles = min(6 + week, 12)
                
                var intervals: [WorkoutInterval] = [
                    WorkoutInterval(type: .warmup, duration: 300, intensity: .moderate, distance: nil, notes: "HIIT warmup")
                ]
                
                for _ in 1...cycles {
                    intervals.append(WorkoutInterval(type: .work, duration: TimeInterval(workDuration), intensity: .veryHigh, distance: nil, notes: "High intensity work"))
                    intervals.append(WorkoutInterval(type: .rest, duration: TimeInterval(restDuration), intensity: .low, distance: nil, notes: "Recovery"))
                }
                
                intervals.append(WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "HIIT cooldown"))
                
                let workout = CustomWorkout(
                    name: "HIIT Week \(week)",
                    type: .hiit,
                    difficulty: .intermediate,
                    intervals: intervals,
                    estimatedDuration: TimeInterval(600 + (cycles * (workDuration + restDuration))),
                    estimatedCalories: 200 + (week * 15),
                    notes: "Push yourself during work intervals",
                    tags: ["hiit", "week\(week)"]
                )
                
                workouts.append(PlannedWorkout(
                    name: "HIIT Session - Week \(week), Day \(day)",
                    description: "High-intensity interval training",
                    week: week,
                    day: day,
                    workout: workout,
                    isCompleted: false
                ))
            }
        }
        
        return workouts
    }
    
    private func generateEnduranceWorkouts() -> [PlannedWorkout] {
        var workouts: [PlannedWorkout] = []
        
        for week in 1...12 {
            for day in [1, 3, 5] {
                let duration = min(20 + (week * 2), 45)
                let intensity: ExerciseIntensity = week <= 4 ? .moderate : week <= 8 ? .high : .veryHigh
                
                let workout = CustomWorkout(
                    name: "Endurance Week \(week)",
                    type: .intervals,
                    difficulty: .advanced,
                    intervals: [
                        WorkoutInterval(type: .warmup, duration: 600, intensity: .moderate, distance: nil, notes: "Extended warmup"),
                        WorkoutInterval(type: .work, duration: TimeInterval(duration * 60), intensity: intensity, distance: nil, notes: "Steady state endurance work"),
                        WorkoutInterval(type: .cooldown, duration: 600, intensity: .low, distance: nil, notes: "Extended cooldown")
                    ],
                    estimatedDuration: TimeInterval((duration * 60) + 1200),
                    estimatedCalories: 250 + (week * 20),
                    notes: "Focus on maintaining steady intensity",
                    tags: ["endurance", "week\(week)"]
                )
                
                workouts.append(PlannedWorkout(
                    name: "Endurance - Week \(week), Day \(day)",
                    description: "Endurance building session",
                    week: week,
                    day: day,
                    workout: workout,
                    isCompleted: false
                ))
            }
        }
        
        return workouts
    }
    
    private func generateMixedWorkouts() -> [PlannedWorkout] {
        var workouts: [PlannedWorkout] = []
        
        for week in 1...10 {
            let workoutTypes: [WorkoutType] = [.shuttleRun, .hiit, .intervals]
            
            for (index, day) in [1, 3, 5].enumerated() {
                let workoutType = workoutTypes[index]
                
                let workout = CustomWorkout(
                    name: "Mixed Training Week \(week) - \(workoutType.displayName)",
                    type: workoutType,
                    difficulty: .intermediate,
                    intervals: generateMixedIntervals(for: workoutType, week: week),
                    estimatedDuration: TimeInterval(25 * 60),
                    estimatedCalories: 180 + (week * 10),
                    notes: "Mixed training for complete fitness",
                    tags: ["mixed", "week\(week)", workoutType.rawValue]
                )
                
                workouts.append(PlannedWorkout(
                    name: "Mixed Training - Week \(week), Day \(day)",
                    description: "\(workoutType.displayName) focused session",
                    week: week,
                    day: day,
                    workout: workout,
                    isCompleted: false
                ))
            }
        }
        
        return workouts
    }
    
    private func generateQuickStartWorkouts() -> [PlannedWorkout] {
        var workouts: [PlannedWorkout] = []
        
        for week in 1...4 {
            for day in [1, 3, 5] {
                let workout = CustomWorkout(
                    name: "Quick Start Week \(week)",
                    type: .mixed,
                    difficulty: .beginner,
                    intervals: [
                        WorkoutInterval(type: .warmup, duration: 180, intensity: .low, distance: nil, notes: "Quick warmup"),
                        WorkoutInterval(type: .work, duration: 300, intensity: .moderate, distance: nil, notes: "Main workout"),
                        WorkoutInterval(type: .rest, duration: 60, intensity: .low, distance: nil, notes: "Recovery"),
                        WorkoutInterval(type: .work, duration: 300, intensity: .moderate, distance: nil, notes: "Second set"),
                        WorkoutInterval(type: .cooldown, duration: 180, intensity: .low, distance: nil, notes: "Quick cooldown")
                    ],
                    estimatedDuration: TimeInterval(15 * 60),
                    estimatedCalories: 100 + (week * 15),
                    notes: "Quick and effective workout to build the habit",
                    tags: ["quick", "starter", "week\(week)"]
                )
                
                workouts.append(PlannedWorkout(
                    name: "Quick Start - Week \(week), Day \(day)",
                    description: "Short effective workout",
                    week: week,
                    day: day,
                    workout: workout,
                    isCompleted: false
                ))
            }
        }
        
        return workouts
    }
    
    private func generateMixedIntervals(for type: WorkoutType, week: Int) -> [WorkoutInterval] {
        switch type {
        case .shuttleRun:
            return [
                WorkoutInterval(type: .warmup, duration: 300, intensity: .moderate, distance: nil, notes: "Shuttle warmup"),
                WorkoutInterval(type: .work, duration: 20, intensity: .high, distance: 20, notes: "Shuttle runs"),
                WorkoutInterval(type: .rest, duration: 40, intensity: .low, distance: nil, notes: "Recovery"),
                WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Shuttle cooldown")
            ]
        case .hiit:
            return [
                WorkoutInterval(type: .warmup, duration: 240, intensity: .moderate, distance: nil, notes: "HIIT prep"),
                WorkoutInterval(type: .work, duration: 45, intensity: .veryHigh, distance: nil, notes: "High intensity"),
                WorkoutInterval(type: .rest, duration: 15, intensity: .low, distance: nil, notes: "Rest"),
                WorkoutInterval(type: .cooldown, duration: 240, intensity: .low, distance: nil, notes: "HIIT recovery")
            ]
        case .intervals:
            return [
                WorkoutInterval(type: .warmup, duration: 300, intensity: .moderate, distance: nil, notes: "Interval warmup"),
                WorkoutInterval(type: .work, duration: 120, intensity: .high, distance: nil, notes: "Work interval"),
                WorkoutInterval(type: .rest, duration: 60, intensity: .low, distance: nil, notes: "Rest interval"),
                WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Interval cooldown")
            ]
        default:
            return []
        }
    }
}

// MARK: - Extensions

extension TrainingPlan {
    var isBuiltIn: Bool {
        // Check if this is a built-in plan
        return !tags.contains("custom")
    }
}

extension DifficultyLevel {
    var sortValue: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert: return 4
        }
    }
}

enum SortOption: String, CaseIterable {
    case name = "Name"
    case duration = "Duration"
    case difficulty = "Difficulty"
    case recent = "Recent"
}

#Preview {
    TrainingPlansView()
}
