//
//  WorkoutModels.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CoreLocation
import HealthKit

// MARK: - Workout Types
enum WorkoutType: String, CaseIterable, Codable {
    case shuttleRun = "shuttle_run"
    case hiit = "hiit"
    case tabata = "tabata"
    case pyramid = "pyramid"
    case runWalk = "run_walk"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .shuttleRun: return "Shuttle Run"
        case .hiit: return "HIIT"
        case .tabata: return "Tabata"
        case .pyramid: return "Pyramid"
        case .runWalk: return "Run/Walk"
        case .custom: return "Custom"
        }
    }
    
    var description: String {
        switch self {
        case .shuttleRun: return "Classic shuttle runs with customizable distances"
        case .hiit: return "High-intensity interval training"
        case .tabata: return "20s work, 10s rest intervals"
        case .pyramid: return "Increasing then decreasing intensity"
        case .runWalk: return "Alternating run and walk intervals"
        case .custom: return "Build your own workout"
        }
    }
    
    var icon: String {
        switch self {
        case .shuttleRun: return "arrow.left.arrow.right"
        case .hiit: return "bolt.fill"
        case .tabata: return "timer"
        case .pyramid: return "triangle.fill"
        case .runWalk: return "figure.walk"
        case .custom: return "slider.horizontal.3"
        }
    }
    
    var usesGPS: Bool {
        switch self {
        case .shuttleRun: return true
        case .hiit: return false
        case .tabata: return false
        case .pyramid: return true
        case .runWalk: return true
        case .custom: return true
        }
    }
}

// MARK: - Workout Configuration
struct WorkoutConfiguration: Codable, Identifiable {
    let id = UUID()
    let type: WorkoutType
    let name: String
    let description: String
    let duration: TimeInterval
    let intervals: [WorkoutInterval]
    let restPeriods: [RestPeriod]
    let difficulty: Difficulty
    let targetHeartRateZone: HeartRateZone?
    let audioCoaching: AudioCoachingSettings
    let hapticFeedback: HapticFeedbackSettings
    
    var estimatedCalories: Int {
        // Simple estimation based on duration and intensity
        let baseCaloriesPerMinute = 10.0
        let difficultyMultiplier = difficulty.calorieMultiplier
        return Int((duration / 60.0) * baseCaloriesPerMinute * difficultyMultiplier)
    }
}

// MARK: - Workout Interval
struct WorkoutInterval: Codable, Identifiable {
    let id = UUID()
    let type: IntervalType
    let duration: TimeInterval
    let intensity: Intensity
    let distance: Double? // in meters
    let targetPace: Double? // seconds per meter
    let instructions: String?
    
    enum IntervalType: String, Codable {
        case work, rest, warmup, cooldown
    }
}

// MARK: - Rest Period
struct RestPeriod: Codable {
    let duration: TimeInterval
    let type: RestType
    let adaptiveRest: Bool // Adjust based on heart rate recovery
    
    enum RestType: String, Codable {
        case active, passive, complete
    }
}

// MARK: - Difficulty Levels
enum Difficulty: String, CaseIterable, Codable {
    case beginner, intermediate, advanced, elite
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .elite: return "Elite"
        }
    }
    
    var calorieMultiplier: Double {
        switch self {
        case .beginner: return 0.8
        case .intermediate: return 1.0
        case .advanced: return 1.3
        case .elite: return 1.6
        }
    }
    
    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "blue"
        case .advanced: return "orange"
        case .elite: return "red"
        }
    }
}

// MARK: - Intensity Levels
enum Intensity: String, CaseIterable, Codable {
    case veryLight, light, moderate, vigorous, maximal
    
    var displayName: String {
        switch self {
        case .veryLight: return "Very Light"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .vigorous: return "Vigorous"
        case .maximal: return "Maximal"
        }
    }
    
    var heartRatePercentage: ClosedRange<Double> {
        switch self {
        case .veryLight: return 50...60
        case .light: return 60...70
        case .moderate: return 70...80
        case .vigorous: return 80...90
        case .maximal: return 90...100
        }
    }
}

// MARK: - Heart Rate Zone
enum HeartRateZone: String, CaseIterable, Codable {
    case zone1, zone2, zone3, zone4, zone5
    
    var displayName: String {
        switch self {
        case .zone1: return "Zone 1 - Recovery"
        case .zone2: return "Zone 2 - Aerobic Base"
        case .zone3: return "Zone 3 - Aerobic"
        case .zone4: return "Zone 4 - Threshold"
        case .zone5: return "Zone 5 - Neuromuscular"
        }
    }
    
    var heartRatePercentage: ClosedRange<Double> {
        switch self {
        case .zone1: return 50...60
        case .zone2: return 60...70
        case .zone3: return 70...80
        case .zone4: return 80...90
        case .zone5: return 90...100
        }
    }
    
    var color: String {
        switch self {
        case .zone1: return "gray"
        case .zone2: return "blue"
        case .zone3: return "green"
        case .zone4: return "yellow"
        case .zone5: return "red"
        }
    }
}

// MARK: - Audio Coaching Settings
// Note: AudioCoachingSettings is defined in AudioCoachingManager.swift

// MARK: - Haptic Feedback Settings
struct HapticFeedbackSettings: Codable {
    let enabled: Bool
    let intervalTransitions: Bool
    let heartRateAlerts: Bool
    let paceAlerts: Bool
    let motivationalTaps: Bool
    let intensity: HapticIntensity
    
    enum HapticIntensity: String, CaseIterable, Codable {
        case light, medium, strong
    }
}
