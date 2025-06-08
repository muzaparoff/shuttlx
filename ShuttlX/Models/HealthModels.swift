//
//  HealthModels.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import HealthKit
import CoreLocation

// MARK: - Health Data Models
struct HealthMetrics {
    let heartRate: HeartRateData?
    let activeEnergyBurned: Double
    let totalEnergyBurned: Double
    let distanceCovered: Double
    let stepCount: Int
    let workoutDuration: TimeInterval
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let minHeartRate: Double?
    let heartRateVariability: Double?
    let vo2Max: Double?
    let restingHeartRate: Double?
    
    static let empty = HealthMetrics(
        heartRate: nil,
        activeEnergyBurned: 0,
        totalEnergyBurned: 0,
        distanceCovered: 0,
        stepCount: 0,
        workoutDuration: 0,
        averageHeartRate: nil,
        maxHeartRate: nil,
        minHeartRate: nil,
        heartRateVariability: nil,
        vo2Max: nil,
        restingHeartRate: nil
    )
}

// MARK: - Heart Rate Data
struct HeartRateData {
    let current: Double
    let timestamp: Date
    let zone: HealthHeartRateZone
    let quality: HeartRateQuality
    
    enum HeartRateQuality {
        case excellent, good, fair, poor
        
        var description: String {
            switch self {
            case .excellent: return "Excellent signal"
            case .good: return "Good signal"
            case .fair: return "Fair signal"
            case .poor: return "Poor signal"
            }
        }
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "yellow"
            case .poor: return "red"
            }
        }
    }
}

// MARK: - General Heart Rate Zones (for health monitoring)
enum HealthHeartRateZone: Int, CaseIterable {
    case resting = 0
    case warmUp = 1
    case fatBurn = 2
    case aerobic = 3
    case anaerobic = 4
    case maxEffort = 5
    
    var name: String {
        switch self {
        case .resting: return "Resting"
        case .warmUp: return "Warm Up"
        case .fatBurn: return "Fat Burn"
        case .aerobic: return "Aerobic"
        case .anaerobic: return "Anaerobic"
        case .maxEffort: return "Max Effort"
        }
    }
    
    var color: String {
        switch self {
        case .resting: return "gray"
        case .warmUp: return "blue"
        case .fatBurn: return "green"
        case .aerobic: return "orange"
        case .anaerobic: return "red"
        case .maxEffort: return "purple"
        }
    }
    
    var description: String {
        switch self {
        case .resting: return "Below 60% max HR"
        case .warmUp: return "60-70% max HR"
        case .fatBurn: return "70-80% max HR"
        case .aerobic: return "80-90% max HR"
        case .anaerobic: return "90-95% max HR"
        case .maxEffort: return "95%+ max HR"
        }
    }
    
    func heartRateRange(for maxHR: Double) -> ClosedRange<Double> {
        switch self {
        case .resting: return 0...(maxHR * 0.6)
        case .warmUp: return (maxHR * 0.6)...(maxHR * 0.7)
        case .fatBurn: return (maxHR * 0.7)...(maxHR * 0.8)
        case .aerobic: return (maxHR * 0.8)...(maxHR * 0.9)
        case .anaerobic: return (maxHR * 0.9)...(maxHR * 0.95)
        case .maxEffort: return (maxHR * 0.95)...300
        }
    }
}

// MARK: - Health Permission Status
enum HealthPermissionStatus {
    case notDetermined
    case denied
    case authorized
    case restricted
    
    var message: String {
        switch self {
        case .notDetermined:
            return "Health permissions not requested"
        case .denied:
            return "Health access denied"
        case .authorized:
            return "Health access granted"
        case .restricted:
            return "Health access restricted"
        }
    }
    
    var icon: String {
        switch self {
        case .notDetermined: return "questionmark.circle"
        case .denied: return "xmark.circle"
        case .authorized: return "checkmark.circle"
        case .restricted: return "exclamationmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .notDetermined: return "gray"
        case .denied: return "red"
        case .authorized: return "green"
        case .restricted: return "orange"
        }
    }
}

// MARK: - Health Recovery Metrics (renamed to avoid conflicts)
struct HealthRecoveryMetrics {
    let readinessScore: Double // 0-100
    let sleepQuality: SleepQuality?
    let stressLevel: StressLevel
    let heartRateVariability: Double?
    let restingHeartRate: Double?
    let recommendation: RecoveryRecommendation
    
    enum SleepQuality: String, CaseIterable {
        case excellent, good, fair, poor
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "yellow"
            case .poor: return "red"
            }
        }
        
        var score: Double {
            switch self {
            case .excellent: return 90
            case .good: return 75
            case .fair: return 60
            case .poor: return 40
            }
        }
    }
    
    enum StressLevel: String, CaseIterable {
        case low, moderate, high, critical
        
        var color: String {
            switch self {
            case .low: return "green"
            case .moderate: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
        
        var impact: Double {
            switch self {
            case .low: return 1.0
            case .moderate: return 0.85
            case .high: return 0.7
            case .critical: return 0.5
            }
        }
    }
    
    enum RecoveryRecommendation: String, CaseIterable {
        case fullTraining, lightTraining, recovery, rest
        
        var message: String {
            switch self {
            case .fullTraining: return "Ready for intense training"
            case .lightTraining: return "Light training recommended"
            case .recovery: return "Focus on recovery activities"
            case .rest: return "Complete rest recommended"
            }
        }
        
        var color: String {
            switch self {
            case .fullTraining: return "green"
            case .lightTraining: return "yellow"
            case .recovery: return "orange"
            case .rest: return "red"
            }
        }
    }
}

// MARK: - Workout Location Data
struct WorkoutLocationData {
    let coordinates: [CLLocationCoordinate2D]
    let totalDistance: Double
    let averageSpeed: Double
    let maxSpeed: Double
    let elevationGain: Double
    let elevationLoss: Double
    
    static let empty = WorkoutLocationData(
        coordinates: [],
        totalDistance: 0,
        averageSpeed: 0,
        maxSpeed: 0,
        elevationGain: 0,
        elevationLoss: 0
    )
}

// MARK: - Health Export Data
struct HealthExportData: Codable {
    let exportDate: Date
    let workouts: [WorkoutExport]
    let healthMetrics: [HealthMetricExport]
    let heartRateData: [HeartRateExport]
    
    struct WorkoutExport: Codable {
        let date: Date
        let type: String
        let duration: TimeInterval
        let distance: Double
        let calories: Double
        let averageHeartRate: Double?
        let maxHeartRate: Double?
    }
    
    struct HealthMetricExport: Codable {
        let date: Date
        let stepCount: Int
        let activeCalories: Double
        let totalCalories: Double
        let restingHeartRate: Double?
        let heartRateVariability: Double?
    }
    
    struct HeartRateExport: Codable {
        let timestamp: Date
        let value: Double
        let context: String // workout, rest, etc.
    }
}