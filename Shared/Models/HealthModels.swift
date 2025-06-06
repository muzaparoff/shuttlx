//
//  HealthModels.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import HealthKit

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
    let zone: HeartRateZone
    let quality: HeartRateQuality
    
    enum HeartRateQuality {
        case excellent, good, fair, poor
        
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

// MARK: - Heart Rate Zone Analysis
extension HeartRateZone {
    static func zone(for heartRate: Double, maxHeartRate: Double) -> HeartRateZone {
        let percentage = (heartRate / maxHeartRate) * 100
        
        switch percentage {
        case 0...60: return .zone1
        case 60...70: return .zone2
        case 70...80: return .zone3
        case 80...90: return .zone4
        default: return .zone5
        }
    }
    
    var targetHeartRate: ClosedRange<Double> {
        return heartRatePercentage
    }
    
    var description: String {
        switch self {
        case .zone1: return "Active recovery and warm-up"
        case .zone2: return "Base endurance training"
        case .zone3: return "Aerobic fitness development"
        case .zone4: return "Lactate threshold training"
        case .zone5: return "Anaerobic power development"
        }
    }
    
    var benefits: [String] {
        switch self {
        case .zone1:
            return ["Recovery", "Blood flow", "Mobility"]
        case .zone2:
            return ["Fat burning", "Endurance", "Aerobic base"]
        case .zone3:
            return ["Cardiovascular fitness", "Efficiency", "Endurance"]
        case .zone4:
            return ["Performance", "Speed", "Lactate threshold"]
        case .zone5:
            return ["Power", "Speed", "Anaerobic capacity"]
        }
    }
}

// MARK: - Workout Session Extensions
struct TrainingSession: Codable {
    let id: UUID
    let workoutConfiguration: WorkoutConfiguration
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let healthMetrics: HealthMetrics?
    let caloriesBurned: Double?
    let totalDistance: Double?
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let locationData: [CLLocationCoordinate2D]
    let notes: String
    let weather: WeatherCondition?
    let achievements: [Achievement]
    
    init(
        workoutConfiguration: WorkoutConfiguration,
        startTime: Date,
        endTime: Date = Date(),
        healthMetrics: HealthMetrics? = nil,
        locationData: [CLLocationCoordinate2D] = [],
        notes: String = "",
        weather: WeatherCondition? = nil,
        achievements: [Achievement] = []
    ) {
        self.id = UUID()
        self.workoutConfiguration = workoutConfiguration
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.healthMetrics = healthMetrics
        self.caloriesBurned = healthMetrics?.activeEnergyBurned
        self.totalDistance = healthMetrics?.distanceCovered
        self.averageHeartRate = healthMetrics?.averageHeartRate
        self.maxHeartRate = healthMetrics?.maxHeartRate
        self.locationData = locationData
        self.notes = notes
        self.weather = weather
        self.achievements = achievements
    }
}

// MARK: - Weather Condition
struct WeatherCondition: Codable {
    let temperature: Double
    let humidity: Double
    let windSpeed: Double
    let condition: String
    let uvIndex: Int
}

// MARK: - Achievement System
struct Achievement: Codable, Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let earnedDate: Date
    let type: AchievementType
    let value: Double?
    
    enum AchievementType: String, Codable {
        case firstWorkout = "first_workout"
        case streakWeek = "streak_week"
        case streakMonth = "streak_month"
        case distanceMilestone = "distance_milestone"
        case durationMilestone = "duration_milestone"
        case heartRateZone = "heart_rate_zone"
        case personalBest = "personal_best"
        case consistency = "consistency"
        case formImprovement = "form_improvement"
        case weatherWarrior = "weather_warrior"
    }
}

// MARK: - Simple Workout Types for CloudKit
enum SimpleWorkoutType: String, Codable, CaseIterable {
    case shuttleRun = "shuttle_run"
    case hiit = "hiit"
    case running = "running"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .shuttleRun: return "Shuttle Run"
        case .hiit: return "HIIT"
        case .running: return "Running"
        case .custom: return "Custom"
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

// MARK: - Recovery Metrics
struct RecoveryMetrics {
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
    }
    
    enum StressLevel: String, CaseIterable {
        case low, moderate, high, extreme
        
        var color: String {
            switch self {
            case .low: return "green"
            case .moderate: return "yellow"
            case .high: return "orange"
            case .extreme: return "red"
            }
        }
    }
    
    enum RecoveryRecommendation {
        case fullWorkout
        case moderateWorkout
        case lightWorkout
        case restDay
        
        var message: String {
            switch self {
            case .fullWorkout: return "You're ready for a full intensity workout!"
            case .moderateWorkout: return "Moderate intensity recommended today"
            case .lightWorkout: return "Keep it light today - focus on movement"
            case .restDay: return "Your body needs rest today"
            }
        }
        
        var icon: String {
            switch self {
            case .fullWorkout: return "bolt.fill"
            case .moderateWorkout: return "bolt"
            case .lightWorkout: return "leaf.fill"
            case .restDay: return "bed.double.fill"
            }
        }
    }
}

// MARK: - Workout Statistics
struct WorkoutStatistics {
    let totalWorkouts: Int
    let totalDuration: TimeInterval
    let totalDistance: Double
    let totalCalories: Double
    let averageHeartRate: Double?
    let bestWorkout: TrainingSession?
    let currentStreak: Int
    let longestStreak: Int
    let weeklyProgress: [Double] // Last 7 days
    let monthlyProgress: [Double] // Last 30 days
    let improvements: [ImprovementArea]
    
    struct ImprovementArea {
        let name: String
        let percentageChange: Double
        let isImprovement: Bool
        
        var icon: String {
            return isImprovement ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        }
        
        var color: String {
            return isImprovement ? "green" : "red"
        }
    }
}

// MARK: - Injury Prevention
struct InjuryRiskAssessment {
    let overallRisk: RiskLevel
    let specificRisks: [SpecificRisk]
    let recommendations: [String]
    let lastAssessment: Date
    
    enum RiskLevel: String, CaseIterable {
        case low, moderate, high, critical
        
        var color: String {
            switch self {
            case .low: return "green"
            case .moderate: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
        
        var message: String {
            switch self {
            case .low: return "Low injury risk - keep up the good work!"
            case .moderate: return "Moderate risk - pay attention to form and recovery"
            case .high: return "High risk - consider reducing intensity"
            case .critical: return "Critical risk - rest and consult a professional"
            }
        }
    }
    
    struct SpecificRisk {
        let area: String // e.g., "Knees", "Lower back"
        let risk: RiskLevel
        let factors: [String]
        let prevention: [String]
    }
}
