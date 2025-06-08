//
//  WorkoutConfigurationViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import SwiftUI

@MainActor
class WorkoutConfigurationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedDuration: Int = 15
    @Published var selectedIntensity: ExerciseIntensity = .moderate
    @Published var selectedDifficulty: DifficultyLevel = .beginner
    @Published var showDetailedConfig: Bool = false
    @Published var showAdvancedBuilder: Bool = false
    
    // Shuttle Run Specific
    @Published var shuttleDistance: Int = 20
    @Published var numberOfRounds: Int = 8
    @Published var restBetweenRounds: Int = 60
    
    // HIIT Specific
    @Published var workDuration: Int = 45
    @Published var restDuration: Int = 15
    @Published var numberOfCycles: Int = 8
    
    // General
    @Published var warmupDuration: Int = 5
    @Published var cooldownDuration: Int = 5
    
    // MARK: - Computed Properties
    var durationOptions: [Int] {
        [10, 15, 20, 25, 30, 45, 60]
    }
    
    var estimatedDuration: Int {
        return selectedDuration
    }
    
    var estimatedCalories: Int {
        let baseCaloriesPerMinute = 8.0
        let intensityMultiplier: Double = {
            switch selectedIntensity {
            case .low: return 0.7
            case .moderate: return 1.0
            case .high: return 1.4
            case .veryHigh: return 1.8
            case .maximum: return 2.2
            }
        }()
        
        return Int(Double(estimatedDuration) * baseCaloriesPerMinute * intensityMultiplier)
    }
    
    // MARK: - Configuration Methods
    func configure(for workoutType: WorkoutType) {
        switch workoutType {
        case .shuttleRun:
            configureShuttleRun()
        case .hiit:
            configureHIIT()
        case .intervals:
            configureIntervals()
        case .custom:
            configureCustom()
        }
    }
    
    private func configureShuttleRun() {
        selectedDuration = 20
        selectedIntensity = .high
        selectedDifficulty = .intermediate
        shuttleDistance = 20
        numberOfRounds = 10
        restBetweenRounds = 60
    }
    
    private func configureHIIT() {
        selectedDuration = 15
        selectedIntensity = .veryHigh
        selectedDifficulty = .intermediate
        workDuration = 45
        restDuration = 15
        numberOfCycles = 8
    }
    
    private func configureIntervals() {
        selectedDuration = 25
        selectedIntensity = .high
        selectedDifficulty = .intermediate
        workDuration = 60
        restDuration = 30
        numberOfCycles = 6
    }
    
    private func configureCustom() {
        selectedDuration = 20
        selectedIntensity = .moderate
        selectedDifficulty = .beginner
    }
    
    // MARK: - Workout Generation
    func generateWorkout(for type: WorkoutType) -> CustomWorkout {
        switch type {
        case .shuttleRun:
            return generateShuttleRunWorkout()
        case .hiit:
            return generateHIITWorkout()
        case .intervals:
            return generateIntervalsWorkout()
        case .custom:
            return generateCustomWorkout()
        }
    }
    
    private func generateShuttleRunWorkout() -> CustomWorkout {
        var intervals: [WorkoutInterval] = []
        
        // Warmup
        if warmupDuration > 0 {
            intervals.append(WorkoutInterval(
                type: .warmup,
                duration: TimeInterval(warmupDuration * 60),
                intensity: .low,
                distance: nil,
                notes: "Dynamic warmup and movement preparation"
            ))
        }
        
        // Main workout
        for i in 0..<numberOfRounds {
            // Work interval
            intervals.append(WorkoutInterval(
                type: .work,
                duration: TimeInterval(shuttleDistance), // Simplified duration calculation
                intensity: selectedIntensity,
                distance: Double(shuttleDistance),
                notes: "\(shuttleDistance)m shuttle run - Round \(i + 1)"
            ))
            
            // Rest interval (except after last round)
            if i < numberOfRounds - 1 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: TimeInterval(restBetweenRounds),
                    intensity: .low,
                    distance: nil,
                    notes: "Active recovery - prepare for next round"
                ))
            }
        }
        
        // Cooldown
        if cooldownDuration > 0 {
            intervals.append(WorkoutInterval(
                type: .cooldown,
                duration: TimeInterval(cooldownDuration * 60),
                intensity: .low,
                distance: nil,
                notes: "Cool down and stretching"
            ))
        }
        
        return CustomWorkout(
            name: "Shuttle Run Training",
            type: .shuttleRun,
            difficulty: selectedDifficulty,
            intervals: intervals,
            estimatedDuration: TimeInterval(estimatedDuration * 60),
            estimatedCalories: estimatedCalories,
            notes: "Generated \(shuttleDistance)m shuttle run workout with \(numberOfRounds) rounds",
            tags: ["shuttle", "speed", "agility"]
        )
    }
    
    private func generateHIITWorkout() -> CustomWorkout {
        var intervals: [WorkoutInterval] = []
        
        // Warmup
        if warmupDuration > 0 {
            intervals.append(WorkoutInterval(
                type: .warmup,
                duration: TimeInterval(warmupDuration * 60),
                intensity: .moderate,
                distance: nil,
                notes: "HIIT warmup - prepare for high intensity"
            ))
        }
        
        // Main workout
        for i in 0..<numberOfCycles {
            // Work interval
            intervals.append(WorkoutInterval(
                type: .work,
                duration: TimeInterval(workDuration),
                intensity: selectedIntensity,
                distance: nil,
                notes: "High intensity interval \(i + 1) - give it your all!"
            ))
            
            // Rest interval (except after last cycle)
            if i < numberOfCycles - 1 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: TimeInterval(restDuration),
                    intensity: .low,
                    distance: nil,
                    notes: "Active recovery - stay moving"
                ))
            }
        }
        
        // Cooldown
        if cooldownDuration > 0 {
            intervals.append(WorkoutInterval(
                type: .cooldown,
                duration: TimeInterval(cooldownDuration * 60),
                intensity: .low,
                distance: nil,
                notes: "HIIT cooldown and recovery"
            ))
        }
        
        return CustomWorkout(
            name: "HIIT Training",
            type: .hiit,
            difficulty: selectedDifficulty,
            intervals: intervals,
            estimatedDuration: TimeInterval(estimatedDuration * 60),
            estimatedCalories: estimatedCalories,
            notes: "Generated HIIT workout with \(numberOfCycles) cycles of \(workDuration)s work / \(restDuration)s rest",
            tags: ["hiit", "cardio", "intensity"]
        )
    }
    
    private func generateIntervalsWorkout() -> CustomWorkout {
        var intervals: [WorkoutInterval] = []
        
        // Warmup
        if warmupDuration > 0 {
            intervals.append(WorkoutInterval(
                type: .warmup,
                duration: TimeInterval(warmupDuration * 60),
                intensity: .low,
                distance: nil,
                notes: "Interval training warmup"
            ))
        }
        
        // Main workout
        for i in 0..<numberOfCycles {
            // Work interval
            intervals.append(WorkoutInterval(
                type: .work,
                duration: TimeInterval(workDuration),
                intensity: selectedIntensity,
                distance: nil,
                notes: "Interval \(i + 1) - maintain steady effort"
            ))
            
            // Rest interval (except after last cycle)
            if i < numberOfCycles - 1 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: TimeInterval(restDuration),
                    intensity: .moderate,
                    distance: nil,
                    notes: "Recovery interval - keep moving"
                ))
            }
        }
        
        // Cooldown
        if cooldownDuration > 0 {
            intervals.append(WorkoutInterval(
                type: .cooldown,
                duration: TimeInterval(cooldownDuration * 60),
                intensity: .low,
                distance: nil,
                notes: "Interval training cooldown"
            ))
        }
        
        return CustomWorkout(
            name: "Interval Training",
            type: .intervals,
            difficulty: selectedDifficulty,
            intervals: intervals,
            estimatedDuration: TimeInterval(estimatedDuration * 60),
            estimatedCalories: estimatedCalories,
            notes: "Generated interval workout with \(numberOfCycles) intervals",
            tags: ["intervals", "endurance", "cardio"]
        )
    }
    
    private func generateCustomWorkout() -> CustomWorkout {
        var intervals: [WorkoutInterval] = []
        
        // Basic structure for custom workout
        if warmupDuration > 0 {
            intervals.append(WorkoutInterval(
                type: .warmup,
                duration: TimeInterval(warmupDuration * 60),
                intensity: .low,
                distance: nil,
                notes: "Custom workout warmup"
            ))
        }
        
        // Main work block
        let mainDuration = selectedDuration - warmupDuration - cooldownDuration
        intervals.append(WorkoutInterval(
            type: .work,
            duration: TimeInterval(mainDuration * 60),
            intensity: selectedIntensity,
            distance: nil,
            notes: "Custom workout main session"
        ))
        
        if cooldownDuration > 0 {
            intervals.append(WorkoutInterval(
                type: .cooldown,
                duration: TimeInterval(cooldownDuration * 60),
                intensity: .low,
                distance: nil,
                notes: "Custom workout cooldown"
            ))
        }
        
        return CustomWorkout(
            name: "Custom Workout",
            type: .custom,
            difficulty: selectedDifficulty,
            intervals: intervals,
            estimatedDuration: TimeInterval(estimatedDuration * 60),
            estimatedCalories: estimatedCalories,
            notes: "Custom generated workout",
            tags: ["custom"]
        )
    }
    
    // MARK: - Actions
    func startWorkout() {
        // This would typically trigger navigation to the workout view
        print("Starting configured workout...")
        // Implementation would involve:
        // 1. Generate the workout based on current settings
        // 2. Navigate to WorkoutView with the generated workout
        // 3. Start the workout session
    }
    
    func resetToDefaults() {
        selectedDuration = 15
        selectedIntensity = .moderate
        selectedDifficulty = .beginner
        showDetailedConfig = false
        
        // Reset specific settings
        shuttleDistance = 20
        numberOfRounds = 8
        restBetweenRounds = 60
        workDuration = 45
        restDuration = 15
        numberOfCycles = 8
        warmupDuration = 5
        cooldownDuration = 5
    }
    
    func validateConfiguration() -> Bool {
        // Basic validation
        guard selectedDuration > 0 else { return false }
        guard numberOfRounds > 0 || numberOfCycles > 0 else { return false }
        guard workDuration > 0 else { return false }
        
        return true
    }
}

#Preview {
    ContentView()
}
