//
//  WorkoutsViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine

@MainActor
class WorkoutsViewModel: ObservableObject {
    @Published var featuredWorkouts: [WorkoutConfiguration] = []
    @Published var customWorkouts: [WorkoutConfiguration] = []
    @Published var trainingPlans: [TrainingPlan] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadWorkouts()
    }
    
    func loadWorkouts() {
        isLoading = true
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadFeaturedWorkouts() }
                group.addTask { await self.loadCustomWorkouts() }
                group.addTask { await self.loadTrainingPlans() }
            }
            
            isLoading = false
        }
    }
    
    func startWorkout(_ workout: WorkoutConfiguration) {
        NotificationCenter.default.post(
            name: .startWorkout,
            object: workout
        )
    }
    
    func startTrainingPlan(_ plan: TrainingPlan) {
        // Implementation for starting a training plan
        NotificationCenter.default.post(
            name: .startTrainingPlan,
            object: plan
        )
    }
    
    private func loadFeaturedWorkouts() async {
        featuredWorkouts = [
            WorkoutConfiguration(
                type: .shuttleRun,
                name: "Beginner Shuttle",
                description: "Perfect introduction to shuttle runs with 10m intervals",
                duration: 900, // 15 minutes
                intervals: createBeginnerShuttleIntervals(),
                restPeriods: [RestPeriod(duration: 45, type: .active, adaptiveRest: true)],
                difficulty: .beginner,
                targetHeartRateZone: .zone2,
                audioCoaching: createDefaultAudioSettings(),
                hapticFeedback: createDefaultHapticSettings()
            ),
            
            WorkoutConfiguration(
                type: .hiit,
                name: "Power HIIT",
                description: "High-intensity intervals for maximum calorie burn",
                duration: 1200, // 20 minutes
                intervals: createPowerHIITIntervals(),
                restPeriods: [RestPeriod(duration: 60, type: .active, adaptiveRest: true)],
                difficulty: .advanced,
                targetHeartRateZone: .zone4,
                audioCoaching: createDefaultAudioSettings(),
                hapticFeedback: createDefaultHapticSettings()
            ),
            
            WorkoutConfiguration(
                type: .tabata,
                name: "Ultimate Tabata",
                description: "4-minute intense Tabata protocol for conditioning",
                duration: 240, // 4 minutes
                intervals: createUltimateTabataIntervals(),
                restPeriods: [RestPeriod(duration: 10, type: .complete, adaptiveRest: false)],
                difficulty: .elite,
                targetHeartRateZone: .zone5,
                audioCoaching: createDefaultAudioSettings(),
                hapticFeedback: createDefaultHapticSettings()
            ),
            
            WorkoutConfiguration(
                type: .pyramid,
                name: "Endurance Pyramid",
                description: "Build endurance with progressive interval lengths",
                duration: 1800, // 30 minutes
                intervals: createEndurancePyramidIntervals(),
                restPeriods: [RestPeriod(duration: 60, type: .active, adaptiveRest: true)],
                difficulty: .intermediate,
                targetHeartRateZone: .zone3,
                audioCoaching: createDefaultAudioSettings(),
                hapticFeedback: createDefaultHapticSettings()
            )
        ]
    }
    
    private func loadCustomWorkouts() async {
        // Load user's custom workouts from storage
        if let data = UserDefaults.standard.data(forKey: "customWorkouts"),
           let workouts = try? JSONDecoder().decode([WorkoutConfiguration].self, from: data) {
            customWorkouts = workouts
        } else {
            customWorkouts = []
        }
    }
    
    private func loadTrainingPlans() async {
        trainingPlans = [
            TrainingPlan(
                name: "Beginner Shuttle Program",
                description: "4-week program to master basic shuttle runs",
                difficulty: .beginner,
                totalWeeks: 4,
                totalWorkouts: 12,
                completedWorkouts: 3,
                icon: "figure.run"
            ),
            
            TrainingPlan(
                name: "HIIT Conditioning",
                description: "6-week high-intensity interval training program",
                difficulty: .intermediate,
                totalWeeks: 6,
                totalWorkouts: 18,
                completedWorkouts: 8,
                icon: "bolt.fill"
            ),
            
            TrainingPlan(
                name: "Elite Performance",
                description: "8-week advanced training for peak performance",
                difficulty: .elite,
                totalWeeks: 8,
                totalWorkouts: 24,
                completedWorkouts: 0,
                icon: "crown.fill"
            ),
            
            TrainingPlan(
                name: "Endurance Builder",
                description: "10-week program to build cardiovascular endurance",
                difficulty: .intermediate,
                totalWeeks: 10,
                totalWorkouts: 30,
                completedWorkouts: 12,
                icon: "heart.fill"
            )
        ]
    }
    
    func saveCustomWorkout(_ workout: WorkoutConfiguration) {
        customWorkouts.append(workout)
        
        if let data = try? JSONEncoder().encode(customWorkouts) {
            UserDefaults.standard.set(data, forKey: "customWorkouts")
        }
    }
    
    func deleteCustomWorkout(_ workout: WorkoutConfiguration) {
        customWorkouts.removeAll { $0.id == workout.id }
        
        if let data = try? JSONEncoder().encode(customWorkouts) {
            UserDefaults.standard.set(data, forKey: "customWorkouts")
        }
    }
    
    // MARK: - Interval Creation Methods
    private func createBeginnerShuttleIntervals() -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // Warm-up
        intervals.append(WorkoutInterval(
            type: .warmup,
            duration: 180,
            intensity: .light,
            distance: nil,
            targetPace: nil,
            instructions: "Light jogging and dynamic stretches"
        ))
        
        // Main shuttle runs - 6 sets
        for i in 1...6 {
            intervals.append(WorkoutInterval(
                type: .work,
                duration: 45,
                intensity: .moderate,
                distance: 10, // 10 meters
                targetPace: 2.5,
                instructions: "Run 10m, turn, run back. Focus on form."
            ))
            
            if i < 6 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: 45,
                    intensity: .light,
                    distance: nil,
                    targetPace: nil,
                    instructions: "Walk and prepare for next shuttle"
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
            instructions: "Cool down with walking and stretching"
        ))
        
        return intervals
    }
    
    private func createPowerHIITIntervals() -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // Warm-up
        intervals.append(WorkoutInterval(
            type: .warmup,
            duration: 300,
            intensity: .light,
            distance: nil,
            targetPace: nil,
            instructions: "Progressive warm-up with dynamic movements"
        ))
        
        // Main HIIT - 8 rounds
        for i in 1...8 {
            intervals.append(WorkoutInterval(
                type: .work,
                duration: 60,
                intensity: .vigorous,
                distance: nil,
                targetPace: nil,
                instructions: "Maximum sustainable effort for 60 seconds"
            ))
            
            if i < 8 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: 60,
                    intensity: .light,
                    distance: nil,
                    targetPace: nil,
                    instructions: "Active recovery - light movement"
                ))
            }
        }
        
        // Cool-down
        intervals.append(WorkoutInterval(
            type: .cooldown,
            duration: 300,
            intensity: .veryLight,
            distance: nil,
            targetPace: nil,
            instructions: "Cool down with gentle movement and stretching"
        ))
        
        return intervals
    }
    
    private func createUltimateTabataIntervals() -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // 8 rounds of 20s work, 10s rest
        for i in 1...8 {
            intervals.append(WorkoutInterval(
                type: .work,
                duration: 20,
                intensity: .maximal,
                distance: nil,
                targetPace: nil,
                instructions: "All-out maximum effort!"
            ))
            
            if i < 8 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: 10,
                    intensity: .veryLight,
                    distance: nil,
                    targetPace: nil,
                    instructions: "Complete rest - prepare for next round"
                ))
            }
        }
        
        return intervals
    }
    
    private func createEndurancePyramidIntervals() -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // Warm-up
        intervals.append(WorkoutInterval(
            type: .warmup,
            duration: 360,
            intensity: .light,
            distance: nil,
            targetPace: nil,
            instructions: "Extended warm-up for endurance training"
        ))
        
        // Pyramid pattern: 1-2-3-4-3-2-1 minutes
        let durations = [60, 120, 180, 240, 180, 120, 60]
        
        for (index, duration) in durations.enumerated() {
            intervals.append(WorkoutInterval(
                type: .work,
                duration: TimeInterval(duration),
                intensity: .moderate,
                distance: nil,
                targetPace: nil,
                instructions: "Maintain steady effort throughout interval"
            ))
            
            if index < durations.count - 1 {
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: TimeInterval(duration / 2),
                    intensity: .light,
                    distance: nil,
                    targetPace: nil,
                    instructions: "Active recovery between intervals"
                ))
            }
        }
        
        // Cool-down
        intervals.append(WorkoutInterval(
            type: .cooldown,
            duration: 360,
            intensity: .veryLight,
            distance: nil,
            targetPace: nil,
            instructions: "Extended cool-down and stretching"
        ))
        
        return intervals
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
}

// MARK: - Notification Names
extension Notification.Name {
    static let startWorkout = Notification.Name("startWorkout")
    static let startTrainingPlan = Notification.Name("startTrainingPlan")
}
