//
//  SettingsModels.swift
//  ShuttlX MVP
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation

// MARK: - Simplified Settings Models for MVP

struct AppSettings: Codable, Equatable {
    var darkMode: Bool = false
    var hapticFeedback: Bool = true
    var workoutReminders: Bool = true
    var privacyMode: Bool = false
    
    static let `default` = AppSettings()
}

// Basic daily goal tracking
struct DailyGoal: Codable {
    var stepCount: Int = 10000
    var workoutMinutes: Int = 30
    var activeCalories: Int = 300
    
    static let `default` = DailyGoal()
}

// Simplified workout settings
struct WorkoutSettings: Codable {
    var autoStart: Bool = false
    var autoPause: Bool = true
    var intervalAudio: Bool = true
    var screenAlwaysOn: Bool = true
    
    static let `default` = WorkoutSettings()
}

// Basic privacy settings
struct PrivacySettings: Codable {
    var shareHealthData: Bool = false
    var allowAnalytics: Bool = false
    
    static let `default` = PrivacySettings()
}

// Health integration settings
struct HealthSettings: Codable {
    var syncToHealthKit: Bool = true
    var trackHeartRate: Bool = true
    var trackSteps: Bool = true
    
    static let `default` = HealthSettings()
}

// Audio settings for MVP
struct AudioSettings: Codable {
    var enableCoaching: Bool = true
    var volume: Float = 0.8
    var intervalChimes: Bool = true
    
    static let `default` = AudioSettings()
}

// Watch integration settings
struct WatchSettings: Codable {
    var syncWorkouts: Bool = true
    var showComplications: Bool = true
    var mirrorPhoneSettings: Bool = true
    
    static let `default` = WatchSettings()
}

// Sync settings for cloud data
struct SyncSettings: Codable {
    var enableCloudSync: Bool = false
    var autoBackup: Bool = false
    
    static let `default` = SyncSettings()
}

// Social settings (minimal for MVP)
struct SocialSettings: Codable {
    var shareWorkouts: Bool = false
    var allowFriends: Bool = false
    
    static let `default` = SocialSettings()
}

// AI settings (minimal for MVP)
struct AISettings: Codable {
    var enableRecommendations: Bool = false
    var adaptiveCoaching: Bool = false
    
    static let `default` = AISettings()
}

// User-specific settings
struct UserSettings: Codable {
    var userName: String = ""
    var age: Int = 25
    var weight: Double = 70.0 // kg
    var height: Double = 170.0 // cm
    var fitnessLevel: FitnessLevel = .beginner
    var weeklyGoal: WeeklyGoal = .moderate
    var preferredTheme: AppTheme = .system
    
    static let `default` = UserSettings()
}

// App theme options
enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

// Weekly fitness goals
enum WeeklyGoal: String, Codable, CaseIterable {
    case light = "light"
    case moderate = "moderate"
    case intense = "intense"
    
    var displayName: String {
        switch self {
        case .light: return "Light (1-2 workouts)"
        case .moderate: return "Moderate (3-4 workouts)"
        case .intense: return "Intense (5+ workouts)"
        }
    }
    
    var workoutCount: Int {
        switch self {
        case .light: return 2
        case .moderate: return 4
        case .intense: return 6
        }
    }
}