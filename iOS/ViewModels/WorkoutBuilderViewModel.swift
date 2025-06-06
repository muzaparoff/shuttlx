//
//  WorkoutBuilderViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import SwiftUI

@MainActor
class WorkoutBuilderViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var workoutName: String = ""
    @Published var selectedWorkoutType: WorkoutType = .shuttleRun
    @Published var selectedDifficulty: DifficultyLevel = .beginner
    @Published var intervals: [WorkoutInterval] = []
    @Published var workoutNotes: String = ""
    @Published var workoutTags: [String] = []
    
    // MARK: - Computed Properties
    var isValidWorkout: Bool {
        !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !intervals.isEmpty
    }
    
    var totalDuration: TimeInterval {
        intervals.reduce(0) { $0 + $1.duration }
    }
    
    var estimatedCalories: Int {
        // Basic calorie estimation based on duration and intensity
        let baseCaloriesPerMinute = 10.0
        let totalMinutes = totalDuration / 60.0
        
        let intensityMultiplier = intervals.reduce(0.0) { total, interval in
            let multiplier: Double
            switch interval.intensity {
            case .low: multiplier = 0.8
            case .moderate: multiplier = 1.0
            case .high: multiplier = 1.3
            case .veryHigh: multiplier = 1.6
            case .maximum: multiplier = 2.0
            }
            return total + (interval.duration / totalDuration) * multiplier
        }
        
        return Int(totalMinutes * baseCaloriesPerMinute * intensityMultiplier)
    }
    
    // MARK: - Interval Management
    func addInterval() {
        let newInterval = WorkoutInterval(
            type: .work,
            duration: 30,
            intensity: .moderate,
            distance: nil,
            notes: ""
        )
        intervals.append(newInterval)
    }
    
    func addInterval(_ interval: WorkoutInterval) {
        intervals.append(interval)
    }
    
    func updateInterval(at index: Int, with interval: WorkoutInterval) {
        guard index < intervals.count else { return }
        intervals[index] = interval
    }
    
    func removeInterval(at index: Int) {
        guard index < intervals.count else { return }
        intervals.remove(at: index)
    }
    
    func moveInterval(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex < intervals.count && destinationIndex < intervals.count else { return }
        let interval = intervals.remove(at: sourceIndex)
        intervals.insert(interval, at: destinationIndex)
    }
    
    // MARK: - Template Management
    func loadTemplate(_ template: WorkoutTemplate) {
        workoutName = template.name
        selectedWorkoutType = template.type
        selectedDifficulty = template.difficulty
        intervals = template.intervals
        workoutNotes = template.notes
        workoutTags = template.tags
    }
    
    func saveAsTemplate() {
        let template = WorkoutTemplate(
            name: workoutName,
            type: selectedWorkoutType,
            difficulty: selectedDifficulty,
            intervals: intervals,
            notes: workoutNotes,
            tags: workoutTags
        )
        
        // Save to local storage or cloud
        saveTemplate(template)
    }
    
    // MARK: - Workout Operations
    func buildWorkout() -> CustomWorkout {
        return CustomWorkout(
            name: workoutName,
            type: selectedWorkoutType,
            difficulty: selectedDifficulty,
            intervals: intervals,
            estimatedDuration: totalDuration,
            estimatedCalories: estimatedCalories,
            notes: workoutNotes,
            tags: workoutTags
        )
    }
    
    func saveWorkout() {
        let workout = buildWorkout()
        // Save to local storage or cloud
        saveCustomWorkout(workout)
    }
    
    func startWorkout() {
        let workout = buildWorkout()
        // Navigate to workout view with this workout
        // This would typically involve navigation or app state management
        print("Starting workout: \(workout.name)")
    }
    
    // MARK: - Quick Templates
    func loadShuttleRunTemplate() {
        workoutName = "Shuttle Run Training"
        selectedWorkoutType = .shuttleRun
        selectedDifficulty = .intermediate
        intervals = [
            WorkoutInterval(type: .warmup, duration: 300, intensity: .low, distance: nil, notes: "Light jogging and dynamic stretching"),
            WorkoutInterval(type: .work, duration: 20, intensity: .veryHigh, distance: 20, notes: "20m shuttle run"),
            WorkoutInterval(type: .rest, duration: 40, intensity: .low, distance: nil, notes: "Active recovery"),
            WorkoutInterval(type: .work, duration: 20, intensity: .veryHigh, distance: 20, notes: "20m shuttle run"),
            WorkoutInterval(type: .rest, duration: 40, intensity: .low, distance: nil, notes: "Active recovery"),
            WorkoutInterval(type: .work, duration: 20, intensity: .veryHigh, distance: 20, notes: "20m shuttle run"),
            WorkoutInterval(type: .rest, duration: 40, intensity: .low, distance: nil, notes: "Active recovery"),
            WorkoutInterval(type: .work, duration: 20, intensity: .veryHigh, distance: 20, notes: "20m shuttle run"),
            WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Walking and static stretching")
        ]
    }
    
    func loadHIITTemplate() {
        workoutName = "HIIT Training"
        selectedWorkoutType = .hiit
        selectedDifficulty = .intermediate
        intervals = [
            WorkoutInterval(type: .warmup, duration: 300, intensity: .low, distance: nil, notes: "Light cardio warmup"),
            WorkoutInterval(type: .work, duration: 45, intensity: .veryHigh, distance: nil, notes: "High intensity work"),
            WorkoutInterval(type: .rest, duration: 15, intensity: .low, distance: nil, notes: "Active rest"),
            WorkoutInterval(type: .work, duration: 45, intensity: .veryHigh, distance: nil, notes: "High intensity work"),
            WorkoutInterval(type: .rest, duration: 15, intensity: .low, distance: nil, notes: "Active rest"),
            WorkoutInterval(type: .work, duration: 45, intensity: .veryHigh, distance: nil, notes: "High intensity work"),
            WorkoutInterval(type: .rest, duration: 15, intensity: .low, distance: nil, notes: "Active rest"),
            WorkoutInterval(type: .work, duration: 45, intensity: .veryHigh, distance: nil, notes: "High intensity work"),
            WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Cool down and stretching")
        ]
    }
    
    func loadTabataTemplate() {
        workoutName = "Tabata Protocol"
        selectedWorkoutType = .hiit
        selectedDifficulty = .advanced
        intervals = [
            WorkoutInterval(type: .warmup, duration: 300, intensity: .moderate, distance: nil, notes: "Thorough warmup"),
            WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: nil, notes: "All-out effort"),
            WorkoutInterval(type: .rest, duration: 10, intensity: .low, distance: nil, notes: "Complete rest"),
            WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: nil, notes: "All-out effort"),
            WorkoutInterval(type: .rest, duration: 10, intensity: .low, distance: nil, notes: "Complete rest"),
            WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: nil, notes: "All-out effort"),
            WorkoutInterval(type: .rest, duration: 10, intensity: .low, distance: nil, notes: "Complete rest"),
            WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: nil, notes: "All-out effort"),
            WorkoutInterval(type: .rest, duration: 10, intensity: .low, distance: nil, notes: "Complete rest"),
            WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: nil, notes: "All-out effort"),
            WorkoutInterval(type: .rest, duration: 10, intensity: .low, distance: nil, notes: "Complete rest"),
            WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: nil, notes: "All-out effort"),
            WorkoutInterval(type: .rest, duration: 10, intensity: .low, distance: nil, notes: "Complete rest"),
            WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: nil, notes: "All-out effort"),
            WorkoutInterval(type: .rest, duration: 10, intensity: .low, distance: nil, notes: "Complete rest"),
            WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: nil, notes: "All-out effort"),
            WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Extended cool down")
        ]
    }
    
    // MARK: - Private Methods
    private func saveTemplate(_ template: WorkoutTemplate) {
        // Implementation would save to UserDefaults, Core Data, or CloudKit
        print("Saving template: \(template.name)")
    }
    
    private func saveCustomWorkout(_ workout: CustomWorkout) {
        // Implementation would save to UserDefaults, Core Data, or CloudKit
        print("Saving workout: \(workout.name)")
    }
}

// MARK: - Supporting Models

struct WorkoutTemplate {
    let id = UUID()
    let name: String
    let type: WorkoutType
    let difficulty: DifficultyLevel
    let intervals: [WorkoutInterval]
    let notes: String
    let tags: [String]
    let createdAt = Date()
    
    // Predefined templates
    static let shuttleRunBasic = WorkoutTemplate(
        name: "Basic Shuttle Run",
        type: .shuttleRun,
        difficulty: .beginner,
        intervals: [
            WorkoutInterval(type: .warmup, duration: 300, intensity: .low, distance: nil, notes: "Light jogging"),
            WorkoutInterval(type: .work, duration: 15, intensity: .high, distance: 20, notes: "20m shuttle"),
            WorkoutInterval(type: .rest, duration: 45, intensity: .low, distance: nil, notes: "Walk back"),
            WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Stretching")
        ],
        notes: "Perfect for beginners starting shuttle run training",
        tags: ["beginner", "shuttle", "cardio"]
    )
    
    static let hiitBasic = WorkoutTemplate(
        name: "Basic HIIT",
        type: .hiit,
        difficulty: .beginner,
        intervals: [
            WorkoutInterval(type: .warmup, duration: 300, intensity: .low, distance: nil, notes: "Light cardio"),
            WorkoutInterval(type: .work, duration: 30, intensity: .high, distance: nil, notes: "High intensity"),
            WorkoutInterval(type: .rest, duration: 30, intensity: .low, distance: nil, notes: "Active rest"),
            WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Cool down")
        ],
        notes: "Basic high-intensity interval training",
        tags: ["beginner", "hiit", "cardio"]
    )
    
    static let all: [WorkoutTemplate] = [shuttleRunBasic, hiitBasic]
}

#Preview {
    ContentView()
}
