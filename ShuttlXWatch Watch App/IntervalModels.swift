//
//  IntervalModels.swift  
//  ShuttlX
//
//  Created by ShuttlX MVP on 6/9/25.
//

import Foundation
import HealthKit

// MARK: - Interval Workout Configuration
struct IntervalWorkout: Codable, Identifiable {
    let id = UUID()
    var name: String
    var runDuration: TimeInterval      // seconds to run
    var walkDuration: TimeInterval     // seconds to walk  
    var totalDuration: TimeInterval    // total workout time
    var isActive: Bool = false
    
    // Preset configurations
    static let beginner = IntervalWorkout(
        name: "Beginner",
        runDuration: 60,    // 1 minute run
        walkDuration: 120,  // 2 minute walk
        totalDuration: 1800 // 30 minutes total
    )
    
    static let intermediate = IntervalWorkout(
        name: "Intermediate", 
        runDuration: 120,   // 2 minute run
        walkDuration: 60,   // 1 minute walk
        totalDuration: 1800 // 30 minutes total
    )
    
    static let advanced = IntervalWorkout(
        name: "Advanced",
        runDuration: 180,   // 3 minute run
        walkDuration: 30,   // 30 second walk
        totalDuration: 1800 // 30 minutes total
    )
    
    // Current state during workout
    var currentPhase: IntervalPhase = .running
    var remainingTime: TimeInterval = 0
    var completedIntervals: Int = 0
    
    var totalIntervals: Int {
        let intervalDuration = runDuration + walkDuration
        return Int(totalDuration / intervalDuration)
    }
}

// MARK: - Interval Phase
enum IntervalPhase: String, Codable, CaseIterable {
    case running = "running"
    case walking = "walking"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .running: return "RUN"
        case .walking: return "Walk"
        case .completed: return "Complete"
        }
    }
    
    var color: String {
        switch self {
        case .running: return "red"
        case .walking: return "blue"
        case .completed: return "purple"
        }
    }
}

// MARK: - Workout Session
struct WorkoutSession: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let workoutType: String
    let duration: TimeInterval
    let intervalsCompleted: Int
    let totalIntervals: Int
    
    // Basic metrics
    let steps: Int
    let distance: Double      // meters
    let calories: Double     // kcal
    let averageHeartRate: Double
    let maxHeartRate: Double
    
    init(workout: IntervalWorkout, steps: Int = 0, distance: Double = 0, calories: Double = 0, avgHR: Double = 0, maxHR: Double = 0) {
        self.date = Date()
        self.workoutType = workout.name
        self.duration = workout.totalDuration
        self.intervalsCompleted = workout.completedIntervals
        self.totalIntervals = workout.totalIntervals
        self.steps = steps
        self.distance = distance
        self.calories = calories
        self.averageHeartRate = avgHR
        self.maxHeartRate = maxHR
    }
}

// MARK: - Health Metrics
struct HealthMetrics: Codable {
    let steps: Int
    let distance: Double        // meters
    let calories: Double       // kcal
    let heartRate: Double      // bpm
    let timestamp: Date
    
    init(steps: Int = 0, distance: Double = 0, calories: Double = 0, heartRate: Double = 0) {
        self.steps = steps
        self.distance = distance
        self.calories = calories
        self.heartRate = heartRate
        self.timestamp = Date()
    }
}
