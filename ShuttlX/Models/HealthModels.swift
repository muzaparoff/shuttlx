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
    case fatBurn = 1
    case aerobic = 2
    case anaerobic = 3
    case maxEffort = 4
    
    var name: String {
        switch self {
        case .resting: return "Resting"
        case .fatBurn: return "Fat Burn"
        case .aerobic: return "Aerobic"
        case .anaerobic: return "Anaerobic"
        case .maxEffort: return "Max Effort"
        }
    }
    
    var color: String {
        switch self {
        case .resting: return "gray"
        case .fatBurn: return "green"
        case .aerobic: return "orange"
        case .anaerobic: return "red"
        case .maxEffort: return "purple"
        }
    }
    
    var description: String {
        switch self {
        case .resting: return "Below 60% max HR"
        case .fatBurn: return "60-80% max HR"
        case .aerobic: return "80-90% max HR"
        case .anaerobic: return "90-95% max HR"
        case .maxEffort: return "95%+ max HR"
        }
    }
    
    func heartRateRange(for maxHR: Double) -> ClosedRange<Double> {
        switch self {
        case .resting: return 0...(maxHR * 0.6)
        case .fatBurn: return (maxHR * 0.6)...(maxHR * 0.8)
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

// MARK: - Training Session
struct TrainingSession: Codable, Identifiable {
    var id = UUID()
    let startTime: Date
    let endTime: Date
    let workoutType: String
    let duration: TimeInterval
    let distance: Double
    let calories: Double
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let steps: Int?
    let notes: String?
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        return formatter.string(from: duration) ?? "0:00"
    }
    
    static let sample = TrainingSession(
        startTime: Date().addingTimeInterval(-3600),
        endTime: Date(),
        workoutType: "Run-Walk Interval",
        duration: 3600,
        distance: 5.0,
        calories: 350,
        averageHeartRate: 140,
        maxHeartRate: 165,
        steps: 6500,
        notes: "Great workout!"
    )
}

// MARK: - Achievement System
struct Achievement: Codable, Identifiable {
    var id = UUID()
    let title: String
    let description: String
    let iconName: String
    let unlockedDate: Date?
    let isUnlocked: Bool
    let category: AchievementCategory
    
    enum AchievementCategory: String, Codable, CaseIterable {
        case distance = "distance"
        case duration = "duration"
        case frequency = "frequency"
        case streak = "streak"
        case heartRate = "heart_rate"
        case improvement = "improvement"
        
        var displayName: String {
            switch self {
            case .distance: return "Distance"
            case .duration: return "Duration"
            case .frequency: return "Frequency"
            case .streak: return "Streak"
            case .heartRate: return "Heart Rate"
            case .improvement: return "Improvement"
            }
        }
    }
    
    static let sampleAchievements: [Achievement] = [
        Achievement(
            title: "First Steps",
            description: "Complete your first workout",
            iconName: "figure.walk",
            unlockedDate: Date(),
            isUnlocked: true,
            category: .frequency
        ),
        Achievement(
            title: "5K Runner",
            description: "Complete a 5 kilometer workout",
            iconName: "figure.run",
            unlockedDate: nil,
            isUnlocked: false,
            category: .distance
        )
    ]
}

// MARK: - Workout Statistics
struct WorkoutStatistics: Codable {
    let totalWorkouts: Int
    let totalDuration: TimeInterval
    let totalDistance: Double
    let totalCalories: Double
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let workoutFrequency: Double // workouts per week
    let favoriteWorkoutType: String?
    let personalBests: [String: Double] // key: metric name, value: best value
    let progressTrend: ProgressTrend
    let bestWorkout: TrainingSession?
    let currentStreak: Int
    let longestStreak: Int
    let weeklyProgress: [Double]
    let monthlyProgress: [Double]
    let improvements: [ImprovementArea]
    
    enum ProgressTrend: String, CaseIterable, Codable {
        case improving, stable, declining
        
        var description: String {
            switch self {
            case .improving: return "Improving"
            case .stable: return "Stable"
            case .declining: return "Declining"
            }
        }
        
        var color: String {
            switch self {
            case .improving: return "green"
            case .stable: return "blue"
            case .declining: return "orange"
            }
        }
    }
    
    enum ImprovementArea: String, CaseIterable, Codable {
        case endurance, strength, speed, flexibility, recovery
        
        var description: String {
            switch self {
            case .endurance: return "Endurance"
            case .strength: return "Strength"  
            case .speed: return "Speed"
            case .flexibility: return "Flexibility"
            case .recovery: return "Recovery"
            }
        }
        
        var recommendation: String {
            switch self {
            case .endurance: return "Focus on longer duration workouts"
            case .strength: return "Incorporate resistance training"
            case .speed: return "Add interval training sessions"
            case .flexibility: return "Include stretching and yoga"
            case .recovery: return "Prioritize rest and sleep"
            }
        }
    }
    
    // Improvement data structure for UI display
    struct ImprovementData: Codable {
        let name: String
        let percentageChange: Double
        let isImprovement: Bool
        
        var icon: String {
            switch name.lowercased() {
            case "endurance": return "lungs"
            case "strength": return "dumbbell"
            case "speed": return "bolt"
            case "flexibility": return "figure.flexibility"
            case "recovery": return "heart.circle"
            case "consistency": return "calendar"
            default: return "chart.line.uptrend.xyaxis"
            }
        }
        
        var color: String {
            return isImprovement ? "green" : "red"
        }
    }
    
    static let empty = WorkoutStatistics(
        totalWorkouts: 0,
        totalDuration: 0,
        totalDistance: 0,
        totalCalories: 0,
        averageHeartRate: nil,
        maxHeartRate: nil,
        workoutFrequency: 0,
        favoriteWorkoutType: nil,
        personalBests: [:],
        progressTrend: .stable,
        bestWorkout: nil,
        currentStreak: 0,
        longestStreak: 0,
        weeklyProgress: [],
        monthlyProgress: [],
        improvements: []
    )
}

// MARK: - Injury Risk Assessment
struct InjuryRiskAssessment: Codable {
    let riskLevel: RiskLevel
    let riskFactors: [RiskFactor]
    let recommendations: [String]
    let assessmentDate: Date
    let nextAssessmentDate: Date
    
    enum RiskLevel: String, CaseIterable, Codable {
        case low, moderate, high, critical
        
        var description: String {
            switch self {
            case .low: return "Low Risk"
            case .moderate: return "Moderate Risk"  
            case .high: return "High Risk"
            case .critical: return "Critical Risk"
            }
        }
        
        var color: String {
            switch self {
            case .low: return "green"
            case .moderate: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
        
        var percentage: Double {
            switch self {
            case .low: return 0.15
            case .moderate: return 0.35
            case .high: return 0.65
            case .critical: return 0.85
            }
        }
    }
    
    enum RiskFactor: String, CaseIterable, Codable {
        case overtraining, insufficientRecovery, rapidProgressionIncrease
        case previousInjury, muscleImbalance, poorForm
        case dehydration, fatigue
        
        var description: String {
            switch self {
            case .overtraining: return "Overtraining detected"
            case .insufficientRecovery: return "Insufficient recovery time"
            case .rapidProgressionIncrease: return "Too rapid progression increase"
            case .previousInjury: return "Previous injury concerns"
            case .muscleImbalance: return "Muscle imbalance detected"
            case .poorForm: return "Poor exercise form"
            case .dehydration: return "Dehydration risk"
            case .fatigue: return "High fatigue levels"
            }
        }
        
        var severity: Double {
            switch self {
            case .overtraining, .previousInjury: return 0.8
            case .insufficientRecovery, .rapidProgressionIncrease: return 0.7
            case .muscleImbalance, .poorForm: return 0.6
            case .dehydration, .fatigue: return 0.4
            }
        }
    }
    
    static let empty = InjuryRiskAssessment(
        riskLevel: .low,
        riskFactors: [],
        recommendations: [],
        assessmentDate: Date(),
        nextAssessmentDate: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
    )
}