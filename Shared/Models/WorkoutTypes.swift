//
//  WorkoutTypes.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - Workout State
enum WorkoutState: String, CaseIterable {
    case preparing, active, paused, completed
    
    var displayName: String {
        switch self {
        case .preparing: return "Preparing"
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Exercise Intensity
enum ExerciseIntensity: String, CaseIterable, Codable {
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
    
    var level: Int {
        switch self {
        case .veryLight: return 1
        case .light: return 2
        case .moderate: return 3
        case .vigorous: return 4
        case .maximal: return 5
        }
    }
    
    var color: Color {
        switch self {
        case .veryLight: return .blue
        case .light: return .green
        case .moderate: return .yellow
        case .vigorous: return .orange
        case .maximal: return .red
        }
    }
}

// MARK: - Interval Type
enum IntervalType: String, CaseIterable, Codable {
    case warmup, work, rest, cooldown
    
    var displayName: String {
        switch self {
        case .warmup: return "Warm Up"
        case .work: return "Work"
        case .rest: return "Rest"
        case .cooldown: return "Cool Down"
        }
    }
    
    var iconName: String {
        switch self {
        case .warmup: return "flame"
        case .work: return "bolt.fill"
        case .rest: return "pause.fill"
        case .cooldown: return "leaf.fill"
        }
    }
}

// MARK: - Simple Workout Types
enum SimpleWorkoutType: String, CaseIterable {
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
}

// MARK: - Simple Workout Interval
struct SimpleWorkoutInterval: Identifiable, Codable {
    let id = UUID()
    let type: IntervalType
    let duration: TimeInterval
    let intensity: ExerciseIntensity
    let instructions: String?
    
    init(type: IntervalType, duration: TimeInterval, intensity: ExerciseIntensity, instructions: String? = nil) {
        self.type = type
        self.duration = duration
        self.intensity = intensity
        self.instructions = instructions
    }
}

// MARK: - Supporting Data Models
struct HeartRateDataPoint: Codable {
    let timestamp: Date
    let heartRate: Double
}

struct LocationDataPoint {
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let speed: Double
}

// MARK: - Route Point Model
struct RoutePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
}

// MARK: - Workout Session for real-time tracking
struct WorkoutSession: Identifiable {
    let id = UUID()
    let workoutType: SimpleWorkoutType
    let startTime: Date
    var endTime: Date?
    var actualDuration: TimeInterval = 0
    var intervals: [SimpleWorkoutInterval] = []
    var heartRateData: [HeartRateDataPoint] = []
    var locationData: [LocationDataPoint] = []
    var caloriesBurned: Double = 0
    var totalDistance: Double = 0
    var averageHeartRate: Double = 0
    var maxHeartRate: Double = 0
    var notes: String = ""
    
    init(workoutType: SimpleWorkoutType, startTime: Date, intervals: [SimpleWorkoutInterval] = []) {
        self.workoutType = workoutType
        self.startTime = startTime
        self.intervals = intervals
    }
    
    var duration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        } else {
            return Date().timeIntervalSince(startTime)
        }
    }
}
