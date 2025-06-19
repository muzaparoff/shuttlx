//
//  WorkoutModels.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CoreLocation
import HealthKit
import SwiftUI

// MARK: - Workout Types
enum WorkoutType: String, CaseIterable, Codable {
    case intervalRunning = "interval_running"
    
    var displayName: String {
        switch self {
        case .intervalRunning: return "Interval Running"
        }
    }
    
    var description: String {
        switch self {
        case .intervalRunning: return "Alternating run and walk intervals"
        }
    }
    
    var icon: String {
        switch self {
        case .intervalRunning: return "figure.run"
        }
    }
    
    var usesGPS: Bool {
        switch self {
        case .intervalRunning: return true
        }
    }
}

// MARK: - Workout Configuration
struct WorkoutConfiguration: Codable, Identifiable {
    var id = UUID()
    let type: WorkoutType
    let name: String
    let description: String
    let duration: TimeInterval
    let intervals: [WorkoutInterval]
    let restPeriods: [RestPeriod]
    let difficulty: Difficulty
    let targetHeartRateZone: HeartRateZone?
    let audioCoachingEnabled: Bool
    let hapticFeedbackEnabled: Bool
    
    var estimatedCalories: Int {
        // Simple estimation based on duration and intensity
        let baseCaloriesPerMinute = 10.0
        let difficultyMultiplier = difficulty.calorieMultiplier
        return Int((duration / 60.0) * baseCaloriesPerMinute * difficultyMultiplier)
    }
}

// MARK: - Workout Interval
struct WorkoutInterval: Codable, Identifiable {
    var id = UUID()
    let type: IntervalType
    let duration: TimeInterval
    let intensity: Intensity
    let distance: Double? // in meters
    let targetPace: Double? // seconds per meter
    let instructions: String?
    
    enum IntervalType: String, Codable {
        case work, rest
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

// MARK: - Audio Coaching Settings
// Note: AudioCoachingSettings is defined in AudioCoachingManager.swift

// MARK: - Workout Results for Data Sync
struct WorkoutResults: Codable {
    let workoutId: UUID
    let startDate: Date
    let endDate: Date
    let totalDuration: TimeInterval
    let activeCalories: Double
    let heartRate: Double
    let distance: Double
    let completedIntervals: Int
    let averageHeartRate: Double
    let maxHeartRate: Double
}

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
