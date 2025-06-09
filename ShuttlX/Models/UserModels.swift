//
//  UserModels.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import HealthKit
import CoreLocation

// MARK: - User Profile
struct UserProfile: Codable {
    let id = UUID()
    var firstName: String
    var lastName: String
    var email: String
    var dateOfBirth: Date
    var height: Double // in meters
    var weight: Double // in kg
    var fitnessLevel: FitnessLevel
    var goals: [FitnessGoal]
    var preferences: UserPreferences
    var achievements: [Achievement]
    var createdAt: Date
    var lastActiveAt: Date
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
    
    var maxHeartRate: Double {
        // Using age-based formula: 220 - age
        return 220.0 - Double(age)
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}

// MARK: - Fitness Level
enum FitnessLevel: String, CaseIterable, Codable {
    case sedentary, lightlyActive, moderatelyActive, veryActive, extremelyActive
    
    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        case .extremelyActive: return "Extremely Active"
        }
    }
    
    var description: String {
        switch self {
        case .sedentary: return "Little to no exercise"
        case .lightlyActive: return "Light exercise 1-3 days/week"
        case .moderatelyActive: return "Moderate exercise 3-5 days/week"
        case .veryActive: return "Hard exercise 6-7 days/week"
        case .extremelyActive: return "Very hard exercise, physical job"
        }
    }
    
    var calorieMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extremelyActive: return 1.9
        }
    }
}

// MARK: - Fitness Goals
struct FitnessGoal: Codable, Identifiable {
    let id = UUID()
    let type: GoalType
    let title: String
    let description: String
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let targetDate: Date
    let isActive: Bool
    let createdAt: Date
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }
    
    var isCompleted: Bool {
        return progress >= 1.0
    }
    
    enum GoalType: String, CaseIterable, Codable {
        case weightLoss = "weight_loss"
        case endurance = "endurance"
        case speed = "speed"
        case strength = "strength"
        case consistency = "consistency"
        case distance = "distance"
        case time = "time"
        
        var icon: String {
            switch self {
            case .weightLoss: return "scalemass"
            case .endurance: return "heart.fill"
            case .speed: return "speedometer"
            case .strength: return "dumbbell.fill"
            case .consistency: return "calendar"
            case .distance: return "location.fill"
            case .time: return "clock.fill"
            }
        }
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    var units: UnitSystem
    var notifications: NotificationSettings
    var privacy: PrivacySettings
    var accessibility: AccessibilitySettings
    var appearance: AppearanceSettings
    var workout: WorkoutPreferences
    
    enum UnitSystem: String, CaseIterable, Codable {
        case metric, imperial
        
        var distanceUnit: String {
            switch self {
            case .metric: return "m"
            case .imperial: return "ft"
            }
        }
        
        var weightUnit: String {
            switch self {
            case .metric: return "kg"
            case .imperial: return "lbs"
            }
        }
    }
}

// MARK: - Workout Preferences
struct WorkoutPreferences: Codable {
    var defaultWorkoutType: WorkoutType
    var autoStartWorkouts: Bool
    var pauseOnPhoneCall: Bool
    var keepScreenOn: Bool
    var audioCoaching: AudioCoachingSettings
    var hapticFeedback: HapticFeedbackSettings
    var weatherIntegration: Bool
    var smartRestPeriods: Bool
}

// MARK: - Achievement System
struct Achievement: Codable, Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let pointValue: Int
    let requirement: AchievementRequirement
    let unlockedAt: Date?
    let isHidden: Bool
    
    var isUnlocked: Bool {
        return unlockedAt != nil
    }
    
    enum AchievementCategory: String, CaseIterable, Codable {
        case distance, speed, endurance, consistency, social, special
        
        var displayName: String {
            switch self {
            case .distance: return "Distance"
            case .speed: return "Speed"
            case .endurance: return "Endurance"
            case .consistency: return "Consistency"
            case .social: return "Social"
            case .special: return "Special"
            }
        }
    }
    
    struct AchievementRequirement: Codable {
        let type: RequirementType
        let value: Double
        let timeframe: Timeframe?
        
        enum RequirementType: String, Codable {
            case totalDistance, maxSpeed, workoutCount, streakDays, socialInteraction
        }
        
        enum Timeframe: String, Codable {
            case day, week, month, year, allTime
        }
    }
}

// MARK: - Training History
struct TrainingSession: Codable, Identifiable {
    let id = UUID()
    let workoutConfiguration: WorkoutConfiguration
    let startTime: Date
    let endTime: Date
    let actualDuration: TimeInterval
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let caloriesBurned: Double?
    let totalDistance: Double?
    let averagePace: Double?
    let intervals: [CompletedInterval]
    let location: CLLocation?
    let weatherConditions: WeatherConditions?
    let notes: String?
    let effort: PerceivedEffort?
    let recoveryMetrics: RecoveryMetrics?
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    enum PerceivedEffort: Int, CaseIterable, Codable {
        case veryEasy = 1, easy, moderate, hard, veryHard
        
        var description: String {
            switch self {
            case .veryEasy: return "Very Easy"
            case .easy: return "Easy"
            case .moderate: return "Moderate"
            case .hard: return "Hard"
            case .veryHard: return "Very Hard"
            }
        }
    }
}

// MARK: - Completed Interval
struct CompletedInterval: Codable, Identifiable {
    let id = UUID()
    let plannedInterval: WorkoutInterval
    let actualDuration: TimeInterval
    let actualDistance: Double?
    let averageHeartRate: Double?
    let averagePace: Double?
    let completed: Bool
    let skipped: Bool
    let notes: String?
}

// MARK: - Recovery Metrics
struct RecoveryMetrics: Codable {
    let heartRateRecovery: Double? // BPM drop in first minute
    let restingHeartRate: Double?
    let heartRateVariability: Double?
    let sleepQuality: Double? // 0-10 scale
    let muscleReadiness: Double? // 0-10 scale
    let overallReadiness: Double? // 0-10 scale
    let stressLevel: Double? // 0-10 scale
}

// MARK: - Weather Conditions
struct WeatherConditions: Codable {
    let temperature: Double // Celsius
    let humidity: Double // Percentage
    let windSpeed: Double // m/s
    let condition: String
    let visibility: Double? // km
    let uvIndex: Int?
    let airQuality: AirQuality?
    
    enum AirQuality: String, CaseIterable, Codable {
        case good, moderate, unhealthyForSensitive, unhealthy, veryUnhealthy, hazardous
        
        var color: String {
            switch self {
            case .good: return "green"
            case .moderate: return "yellow"
            case .unhealthyForSensitive: return "orange"
            case .unhealthy: return "red"
            case .veryUnhealthy: return "purple"
            case .hazardous: return "maroon"
            }
        }
    }
}

// MARK: - Social Features

struct FeedPost: Identifiable, Codable {
    let id: UUID
    let userName: String
    let userAvatarURL: String
    let content: String
    let timestamp: Date
    var likesCount: Int
    let commentsCount: Int
    var isLiked: Bool
    let workoutSummary: WorkoutSummary?
    let imageURL: String?
}

struct WorkoutSummary: Codable {
    let workoutType: WorkoutType
    let duration: TimeInterval
    let caloriesBurned: Double
    let distance: Double? // in kilometers
}

struct Challenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let iconName: String
    let startDate: Date
    let endDate: Date
    var participantCount: Int
    var progress: Double // 0.0 to 1.0
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }
}

struct LeaderboardEntry: Identifiable, Codable {
    let id: UUID
    let userName: String
    let userLocation: String
    let userAvatarURL: String
    let score: Double
    let scoreType: String
    let formattedScore: String
}

struct Team: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let iconName: String
    var memberCount: Int
    let activityLevel: ActivityLevel
    let averageWorkoutsPerWeek: Double
    
    var isPublic: Bool = true
    var tags: [String] = []
}
