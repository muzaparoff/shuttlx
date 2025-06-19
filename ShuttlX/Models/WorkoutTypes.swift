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
    case work, rest
    
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .rest: return "Rest"
        }
    }
    
    var iconName: String {
        switch self {
        case .work: return "bolt.fill"
        case .rest: return "pause.fill"
        }
    }
}

// MARK: - Simple Workout Types
enum SimpleWorkoutType: String, CaseIterable {
    case intervalRunning = "interval_running"
    
    var displayName: String {
        switch self {
        case .intervalRunning: return "Interval Running"
        }
    }
    
    var usesGPS: Bool {
        switch self {
        case .intervalRunning: return true
        }
    }
}

// MARK: - Simple Workout Interval
struct SimpleWorkoutInterval: Identifiable, Codable {
    var id = UUID()
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

// MARK: - LocationDataPoint Codable Extension
extension LocationDataPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, coordinate, altitude, speed
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(speed, forKey: .speed)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        coordinate = try container.decode(CLLocationCoordinate2D.self, forKey: .coordinate)
        altitude = try container.decode(Double.self, forKey: .altitude)
        speed = try container.decode(Double.self, forKey: .speed)
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension
extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
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
