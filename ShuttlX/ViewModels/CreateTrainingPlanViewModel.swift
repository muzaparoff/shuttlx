//
//  CreateTrainingPlanViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import SwiftUI

enum PlanTemplate: CaseIterable {
    case basic
    case hiit
    case endurance
    case mixed
    
    var displayName: String {
        switch self {
        case .basic: return "Basic Structure"
        case .hiit: return "HIIT Focus"
        case .endurance: return "Endurance Build"
        case .mixed: return "Mixed Training"
        }
    }
}

@MainActor
class CreateTrainingPlanViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var planName: String = ""
    @Published var planDescription: String = ""
    @Published var tagsText: String = "" {
        didSet {
            updateTagsFromText()
        }
    }
    @Published var tags: [String] = []
    
    // Configuration
    @Published var selectedPlanType: TrainingPlanType = .mixed
    @Published var selectedDifficulty: DifficultyLevel = .beginner
    @Published var totalWeeks: Int = 6
    @Published var workoutsPerWeek: Int = 3
    @Published var isProgressive: Bool = true
    @Published var minDuration: Int = 20
    @Published var maxDuration: Int = 45
    
    // Template
    @Published var selectedTemplate: PlanTemplate = .basic
    @Published var showingCustomTemplates: Bool = false
    
    // MARK: - Computed Properties
    var hasValidConfiguration: Bool {
        !planName.isEmpty && totalWeeks > 0 && workoutsPerWeek > 0
    }
    
    var isValidPlan: Bool {
        hasValidConfiguration && minDuration <= maxDuration
    }
    
    var totalWorkouts: Int {
        totalWeeks * workoutsPerWeek
    }
    
    // MARK: - Methods
    func updateTagsFromText() {
        tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        tagsText = tags.joined(separator: ", ")
    }
    
    func createTrainingPlan() -> TrainingPlan {
        let workouts = generateWorkouts()
        
        return TrainingPlan(
            name: planName.isEmpty ? "Custom Training Plan" : planName,
            description: planDescription.isEmpty ? "Custom training plan created by user" : planDescription,
            type: selectedPlanType,
            difficulty: selectedDifficulty,
            totalWeeks: totalWeeks,
            completedWeeks: 0,
            workouts: workouts,
            tags: tags + ["custom"],
            isActive: false,
            createdAt: Date()
        )
    }
    
    // MARK: - Private Methods
    private func generateWorkouts() -> [PlannedWorkout] {
        var workouts: [PlannedWorkout] = []
        
        for week in 1...totalWeeks {
            for day in 1...workoutsPerWeek {
                let workout = generateWorkoutForWeekAndDay(week: week, day: day)
                workouts.append(workout)
            }
        }
        
        return workouts
    }
    
    private func generateWorkoutForWeekAndDay(week: Int, day: Int) -> PlannedWorkout {
        let progressionFactor = isProgressive ? Double(week) / Double(totalWeeks) : 0.5
        let baseDuration = minDuration + Int((Double(maxDuration - minDuration) * progressionFactor))
        
        let customWorkout = generateCustomWorkout(
            week: week,
            day: day,
            duration: baseDuration,
            progression: progressionFactor
        )
        
        return PlannedWorkout(
            name: "\(selectedPlanType.displayName) - Week \(week), Day \(day)",
            description: getWorkoutDescription(week: week, day: day),
            week: week,
            day: day,
            workout: customWorkout,
            isCompleted: false
        )
    }
    
    private func generateCustomWorkout(week: Int, day: Int, duration: Int, progression: Double) -> CustomWorkout {
        let intervals = generateIntervalsForTemplate(
            template: selectedTemplate,
            duration: duration,
            progression: progression,
            week: week
        )
        
        let estimatedCalories = calculateEstimatedCalories(duration: duration, intensity: selectedDifficulty)
        
        return CustomWorkout(
            name: "\(selectedTemplate.displayName) Workout",
            type: getWorkoutTypeForTemplate(selectedTemplate),
            difficulty: selectedDifficulty,
            intervals: intervals,
            estimatedDuration: TimeInterval(duration * 60),
            estimatedCalories: estimatedCalories,
            notes: "Week \(week) - \(selectedTemplate.displayName) focused session",
            tags: tags + [selectedTemplate.displayName.lowercased()]
        )
    }
    
    private func generateIntervalsForTemplate(template: PlanTemplate, duration: Int, progression: Double, week: Int) -> [WorkoutInterval] {
        switch template {
        case .basic:
            return generateBasicIntervals(duration: duration, progression: progression)
        case .hiit:
            return generateHIITIntervals(duration: duration, progression: progression)
        case .endurance:
            return generateEnduranceIntervals(duration: duration, progression: progression)
        case .mixed:
            return generateMixedIntervals(duration: duration, progression: progression, week: week)
        }
    }
    
    private func generateBasicIntervals(duration: Int, progression: Double) -> [WorkoutInterval] {
        let warmupDuration = max(Int(Double(duration) * 0.15), 3) * 60
        let cooldownDuration = max(Int(Double(duration) * 0.15), 3) * 60
        let workDuration = duration * 60 - warmupDuration - cooldownDuration
        
        let intensity: ExerciseIntensity = progression < 0.33 ? .moderate : progression < 0.66 ? .high : .veryHigh
        
        return [
            WorkoutInterval(type: .warmup, duration: TimeInterval(warmupDuration), intensity: .low, distance: nil, notes: "Gradual warmup"),
            WorkoutInterval(type: .work, duration: TimeInterval(workDuration), intensity: intensity, distance: nil, notes: "Main workout session"),
            WorkoutInterval(type: .cooldown, duration: TimeInterval(cooldownDuration), intensity: .low, distance: nil, notes: "Recovery cooldown")
        ]
    }
    
    private func generateHIITIntervals(duration: Int, progression: Double) -> [WorkoutInterval] {
        let warmupDuration = 4 * 60
        let cooldownDuration = 4 * 60
        let availableTime = duration * 60 - warmupDuration - cooldownDuration
        
        let workDuration = max(20, 30 + Int(progression * 30)) // 20-60 seconds
        let restDuration = max(10, 30 - Int(progression * 20)) // 10-30 seconds
        let cycleTime = workDuration + restDuration
        let cycles = max(1, availableTime / cycleTime)
        
        var intervals: [WorkoutInterval] = [
            WorkoutInterval(type: .warmup, duration: TimeInterval(warmupDuration), intensity: .moderate, distance: nil, notes: "HIIT preparation")
        ]
        
        for cycle in 1...cycles {
            intervals.append(WorkoutInterval(type: .work, duration: TimeInterval(workDuration), intensity: .veryHigh, distance: nil, notes: "High intensity interval \(cycle)"))
            if cycle < cycles {
                intervals.append(WorkoutInterval(type: .rest, duration: TimeInterval(restDuration), intensity: .low, distance: nil, notes: "Active recovery"))
            }
        }
        
        intervals.append(WorkoutInterval(type: .cooldown, duration: TimeInterval(cooldownDuration), intensity: .low, distance: nil, notes: "HIIT recovery"))
        
        return intervals
    }
    
    private func generateEnduranceIntervals(duration: Int, progression: Double) -> [WorkoutInterval] {
        let warmupDuration = max(5, Int(Double(duration) * 0.2)) * 60
        let cooldownDuration = max(5, Int(Double(duration) * 0.2)) * 60
        let workDuration = duration * 60 - warmupDuration - cooldownDuration
        
        let intensity: ExerciseIntensity = progression < 0.5 ? .moderate : .high
        
        return [
            WorkoutInterval(type: .warmup, duration: TimeInterval(warmupDuration), intensity: .low, distance: nil, notes: "Extended warmup for endurance"),
            WorkoutInterval(type: .work, duration: TimeInterval(workDuration), intensity: intensity, distance: nil, notes: "Steady state endurance work"),
            WorkoutInterval(type: .cooldown, duration: TimeInterval(cooldownDuration), intensity: .low, distance: nil, notes: "Extended cooldown")
        ]
    }
    
    private func generateMixedIntervals(duration: Int, progression: Double, week: Int) -> [WorkoutInterval] {
        let warmupDuration = 3 * 60
        let cooldownDuration = 3 * 60
        let availableTime = duration * 60 - warmupDuration - cooldownDuration
        
        // Rotate between different training focuses
        let focus = week % 3
        
        var intervals: [WorkoutInterval] = [
            WorkoutInterval(type: .warmup, duration: TimeInterval(warmupDuration), intensity: .moderate, distance: nil, notes: "Mixed training warmup")
        ]
        
        switch focus {
        case 0: // Endurance focus
            intervals.append(WorkoutInterval(type: .work, duration: TimeInterval(availableTime), intensity: .moderate, distance: nil, notes: "Endurance focused session"))
        case 1: // Strength focus
            let sets = max(2, availableTime / (2 * 60))
            let workTime = availableTime / (sets * 2)
            let restTime = workTime / 2
            
            for set in 1...sets {
                intervals.append(WorkoutInterval(type: .work, duration: TimeInterval(workTime), intensity: .high, distance: nil, notes: "Strength interval \(set)"))
                if set < sets {
                    intervals.append(WorkoutInterval(type: .rest, duration: TimeInterval(restTime), intensity: .low, distance: nil, notes: "Recovery between sets"))
                }
            }
        default: // HIIT focus
            let cycles = max(3, availableTime / 90)
            let workTime = 45
            let restTime = (availableTime - (cycles * workTime)) / (cycles - 1)
            
            for cycle in 1...cycles {
                intervals.append(WorkoutInterval(type: .work, duration: TimeInterval(workTime), intensity: .veryHigh, distance: nil, notes: "HIIT interval \(cycle)"))
                if cycle < cycles {
                    intervals.append(WorkoutInterval(type: .rest, duration: TimeInterval(restTime), intensity: .low, distance: nil, notes: "Recovery"))
                }
            }
        }
        
        intervals.append(WorkoutInterval(type: .cooldown, duration: TimeInterval(cooldownDuration), intensity: .low, distance: nil, notes: "Mixed training cooldown"))
        
        return intervals
    }
    
    private func getWorkoutTypeForTemplate(_ template: PlanTemplate) -> WorkoutType {
        switch template {
        case .basic: return selectedPlanType == .shuttleRun ? .shuttleRun : .intervals
        case .hiit: return .hiit
        case .endurance: return .intervals
        case .mixed: return .mixed
        }
    }
    
    private func getWorkoutDescription(week: Int, day: Int) -> String {
        switch selectedTemplate {
        case .basic:
            return "Progressive \(selectedPlanType.displayName.lowercased()) session"
        case .hiit:
            return "High-intensity interval training session"
        case .endurance:
            return "Endurance building session"
        case .mixed:
            let focus = week % 3
            switch focus {
            case 0: return "Endurance focused mixed training"
            case 1: return "Strength focused mixed training"
            default: return "HIIT focused mixed training"
            }
        }
    }
    
    private func calculateEstimatedCalories(duration: Int, intensity: DifficultyLevel) -> Int {
        let baseCaloriesPerMinute: Double
        
        switch intensity {
        case .beginner: baseCaloriesPerMinute = 6.0
        case .intermediate: baseCaloriesPerMinute = 8.0
        case .advanced: baseCaloriesPerMinute = 10.0
        case .expert: baseCaloriesPerMinute = 12.0
        }
        
        return Int(baseCaloriesPerMinute * Double(duration))
    }
}

#Preview {
    CreateTrainingPlanView { plan in
        print("Created: \(plan.name)")
    }
}
