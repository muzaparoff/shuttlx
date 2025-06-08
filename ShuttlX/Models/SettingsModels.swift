//
//  SettingsModels.swift
//  ShuttlX
//
//  Comprehensive settings and preferences models
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import HealthKit

// MARK: - Main Settings Container

struct AppSettings: Codable {
    var user: UserSettings
    var workout: WorkoutSettings
    var audio: AudioSettings
    var health: HealthSettings
    var social: SocialSettings
    var notifications: NotificationSettings
    var privacy: PrivacySettings
    var accessibility: AccessibilitySettings
    var ai: AISettings
    var watch: WatchSettings
    var sync: SyncSettings
    
    static let `default` = AppSettings(
        user: .default,
        workout: .default,
        audio: .default,
        health: .default,
        social: .default,
        notifications: .default,
        privacy: .default,
        accessibility: .default,
        ai: .default,
        watch: .default,
        sync: .default
    )
}

// MARK: - User Settings

struct UserSettings: Codable {
    var preferredName: String
    var units: UnitSystem
    var language: String
    var timeZone: String
    var dateFormat: DateFormat
    var timeFormat: TimeFormat
    var theme: AppTheme
    var accentColor: String
    var profileVisibility: ProfileVisibility
    
    static let `default` = UserSettings(
        preferredName: "",
        units: .metric,
        language: "en",
        timeZone: TimeZone.current.identifier,
        dateFormat: .standard,
        timeFormat: .twelveHour,
        theme: .system,
        accentColor: "blue",
        profileVisibility: .public
    )
}

enum UnitSystem: String, CaseIterable, Codable {
    case metric = "metric"
    case imperial = "imperial"
    
    var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }
    
    var distanceUnit: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }
    
    var speedUnit: String {
        switch self {
        case .metric: return "km/h"
        case .imperial: return "mph"
        }
    }
    
    var weightUnit: String {
        switch self {
        case .metric: return "kg"
        case .imperial: return "lbs"
        }
    }
    
    var heightUnit: String {
        switch self {
        case .metric: return "cm"
        case .imperial: return "ft/in"
        }
    }
}

enum DateFormat: String, CaseIterable, Codable {
    case standard = "standard"
    case iso = "iso"
    case european = "european"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .standard: return "MM/dd/yyyy"
        case .iso: return "yyyy-MM-dd"
        case .european: return "dd/MM/yyyy"
        case .custom: return "Custom"
        }
    }
}

enum TimeFormat: String, CaseIterable, Codable {
    case twelveHour = "12"
    case twentyFourHour = "24"
    
    var displayName: String {
        switch self {
        case .twelveHour: return "12-hour"
        case .twentyFourHour: return "24-hour"
        }
    }
}

enum AppTheme: String, CaseIterable, Codable {
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

enum ProfileVisibility: String, CaseIterable, Codable {
    case `public` = "public"
    case friends = "friends"
    case `private` = "private"
    
    var displayName: String {
        switch self {
        case .public: return "Public"
        case .friends: return "Friends Only"
        case .private: return "Private"
        }
    }
}

// MARK: - Workout Settings

struct WorkoutSettings: Codable {
    var defaultWorkoutType: WorkoutType
    var autoStartWorkout: Bool
    var autoPauseWorkout: Bool
    var countdownTimer: Int // seconds
    var restTimerDuration: TimeInterval
    var targetHeartRateZone: HeartRateZone
    var gpsAccuracy: GPSAccuracy
    var screenTimeoutDisabled: Bool
    var hapticFeedback: Bool
    var workoutReminders: Bool
    var reminderTime: Date
    var weeklyGoal: WeeklyGoal
    var dailyGoal: DailyGoal
    
    static let `default` = WorkoutSettings(
        defaultWorkoutType: .shuttleRun,
        autoStartWorkout: false,
        autoPauseWorkout: true,
        countdownTimer: 3,
        restTimerDuration: 60,
        targetHeartRateZone: .moderate,
        gpsAccuracy: .high,
        screenTimeoutDisabled: true,
        hapticFeedback: true,
        workoutReminders: true,
        reminderTime: Calendar.current.date(from: DateComponents(hour: 18)) ?? Date(),
        weeklyGoal: WeeklyGoal(workouts: 5, duration: 300, distance: 25),
        dailyGoal: DailyGoal(steps: 10000, activeMinutes: 60, caloriesBurned: 500)
    )
}

enum GPSAccuracy: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case best = "best"
    
    var displayName: String {
        switch self {
        case .low: return "Low (Battery Saver)"
        case .medium: return "Medium"
        case .high: return "High"
        case .best: return "Best (Most Accurate)"
        }
    }
}

struct WeeklyGoal: Codable {
    var workouts: Int
    var duration: TimeInterval // minutes
    var distance: Double // km
    var isActive: Bool
    
    init(workouts: Int, duration: TimeInterval, distance: Double, isActive: Bool = true) {
        self.workouts = workouts
        self.duration = duration
        self.distance = distance
        self.isActive = isActive
    }
}

struct DailyGoal: Codable {
    var steps: Int
    var activeMinutes: Int
    var caloriesBurned: Double
    var isActive: Bool
    
    init(steps: Int, activeMinutes: Int, caloriesBurned: Double, isActive: Bool = true) {
        self.steps = steps
        self.activeMinutes = activeMinutes
        self.caloriesBurned = caloriesBurned
        self.isActive = isActive
    }
}

// MARK: - Audio Settings

struct AudioSettings: Codable {
    var voiceCoaching: Bool
    var coachingLanguage: String
    var coachingVoice: VoiceType
    var musicDuringWorkout: Bool
    var audioFeedbackFrequency: AudioFeedbackFrequency
    var volumeLevel: Double
    var motivationalMessages: Bool
    var countdownAudio: Bool
    var splitAnnouncements: Bool
    var heartRateAnnouncements: Bool
    var intervalTimerSounds: Bool
    var customSoundPack: String?
    
    static let `default` = AudioSettings(
        voiceCoaching: true,
        coachingLanguage: "en",
        coachingVoice: .female1,
        musicDuringWorkout: true,
        audioFeedbackFrequency: .every1000m,
        volumeLevel: 0.8,
        motivationalMessages: true,
        countdownAudio: true,
        splitAnnouncements: true,
        heartRateAnnouncements: false,
        intervalTimerSounds: true,
        customSoundPack: nil
    )
}

enum VoiceType: String, CaseIterable, Codable {
    case male1 = "male1"
    case male2 = "male2"
    case female1 = "female1"
    case female2 = "female2"
    case robot = "robot"
    
    var displayName: String {
        switch self {
        case .male1: return "Male 1"
        case .male2: return "Male 2"
        case .female1: return "Female 1"
        case .female2: return "Female 2"
        case .robot: return "Robot"
        }
    }
}

enum AudioFeedbackFrequency: String, CaseIterable, Codable {
    case never = "never"
    case every500m = "500m"
    case every1000m = "1000m"
    case every1mile = "1mile"
    case every5min = "5min"
    case every10min = "10min"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .never: return "Never"
        case .every500m: return "Every 500m"
        case .every1000m: return "Every 1km"
        case .every1mile: return "Every 1 mile"
        case .every5min: return "Every 5 minutes"
        case .every10min: return "Every 10 minutes"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Health Settings

struct HealthSettings: Codable {
    var healthKitEnabled: Bool
    var trackHeartRate: Bool
    var trackSteps: Bool
    var trackCalories: Bool
    var trackSleep: Bool
    var trackRecovery: Bool
    var dataSharing: HealthDataSharing
    var exportFormat: HealthExportFormat
    var autoSync: Bool
    var backgroundSync: Bool
    var alertThresholds: HealthAlertThresholds
    
    static let `default` = HealthSettings(
        healthKitEnabled: true,
        trackHeartRate: true,
        trackSteps: true,
        trackCalories: true,
        trackSleep: true,
        trackRecovery: true,
        dataSharing: .anonymized,
        exportFormat: .standard,
        autoSync: true,
        backgroundSync: true,
        alertThresholds: .default
    )
}

enum HealthDataSharing: String, CaseIterable, Codable {
    case none = "none"
    case anonymized = "anonymized"
    case full = "full"
    
    var displayName: String {
        switch self {
        case .none: return "No Sharing"
        case .anonymized: return "Anonymized Data"
        case .full: return "Full Data Sharing"
        }
    }
}

enum HealthExportFormat: String, CaseIterable, Codable {
    case standard = "standard"
    case csv = "csv"
    case json = "json"
    case tcx = "tcx"
    case gpx = "gpx"
    
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .csv: return "CSV"
        case .json: return "JSON"
        case .tcx: return "TCX"
        case .gpx: return "GPX"
        }
    }
}

struct HealthAlertThresholds: Codable {
    var maxHeartRate: Int
    var minHeartRate: Int
    var restingHeartRateChange: Int
    var recoveryScoreThreshold: Int
    var sleepQualityThreshold: Int
    var stressLevelThreshold: Int
    
    static let `default` = HealthAlertThresholds(
        maxHeartRate: 190,
        minHeartRate: 50,
        restingHeartRateChange: 10,
        recoveryScoreThreshold: 30,
        sleepQualityThreshold: 60,
        stressLevelThreshold: 80
    )
}

// MARK: - Social Settings

struct SocialSettings: Codable {
    var profilePublic: Bool
    var allowFollowRequests: Bool
    var showWorkoutStats: Bool
    var shareAchievements: Bool
    var allowChallengeInvites: Bool
    var allowTeamInvites: Bool
    var showOnlineStatus: Bool
    var allowDirectMessages: Bool
    var autoJoinChallenges: Bool
    var contentModeration: ContentModerationLevel
    var blockedUsers: [String]
    var mutedKeywords: [String]
    
    static let `default` = SocialSettings(
        profilePublic: true,
        allowFollowRequests: true,
        showWorkoutStats: true,
        shareAchievements: true,
        allowChallengeInvites: true,
        allowTeamInvites: true,
        showOnlineStatus: true,
        allowDirectMessages: true,
        autoJoinChallenges: false,
        contentModeration: .standard,
        blockedUsers: [],
        mutedKeywords: []
    )
}

enum ContentModerationLevel: String, CaseIterable, Codable {
    case strict = "strict"
    case standard = "standard"
    case minimal = "minimal"
    
    var displayName: String {
        switch self {
        case .strict: return "Strict"
        case .standard: return "Standard"
        case .minimal: return "Minimal"
        }
    }
}

// MARK: - Privacy Settings

struct PrivacySettings: Codable {
    var dataCollection: DataCollectionLevel
    var analyticsSharing: Bool
    var crashReporting: Bool
    var locationSharing: LocationSharingLevel
    var workoutDataSharing: Bool
    var personalDataEncryption: Bool
    var twoFactorAuth: Bool
    var biometricLock: Bool
    var autoLockTimeout: AutoLockTimeout
    var dataRetentionPeriod: DataRetentionPeriod
    
    static let `default` = PrivacySettings(
        dataCollection: .standard,
        analyticsSharing: true,
        crashReporting: true,
        locationSharing: .workoutsOnly,
        workoutDataSharing: true,
        personalDataEncryption: true,
        twoFactorAuth: false,
        biometricLock: false,
        autoLockTimeout: .fiveMinutes,
        dataRetentionPeriod: .twoYears
    )
}

enum DataCollectionLevel: String, CaseIterable, Codable {
    case minimal = "minimal"
    case standard = "standard"
    case enhanced = "enhanced"
    
    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .standard: return "Standard"
        case .enhanced: return "Enhanced"
        }
    }
}

enum LocationSharingLevel: String, CaseIterable, Codable {
    case never = "never"
    case workoutsOnly = "workouts"
    case friends = "friends"
    case always = "always"
    
    var displayName: String {
        switch self {
        case .never: return "Never"
        case .workoutsOnly: return "Workouts Only"
        case .friends: return "Friends Only"
        case .always: return "Always"
        }
    }
}

enum AutoLockTimeout: String, CaseIterable, Codable {
    case immediately = "0"
    case oneMinute = "60"
    case fiveMinutes = "300"
    case fifteenMinutes = "900"
    case never = "never"
    
    var displayName: String {
        switch self {
        case .immediately: return "Immediately"
        case .oneMinute: return "1 Minute"
        case .fiveMinutes: return "5 Minutes"
        case .fifteenMinutes: return "15 Minutes"
        case .never: return "Never"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .never: return nil
        default: return TimeInterval(rawValue) ?? 300
        }
    }
}

enum DataRetentionPeriod: String, CaseIterable, Codable {
    case oneYear = "1"
    case twoYears = "2"
    case fiveYears = "5"
    case indefinitely = "indefinite"
    
    var displayName: String {
        switch self {
        case .oneYear: return "1 Year"
        case .twoYears: return "2 Years"
        case .fiveYears: return "5 Years"
        case .indefinitely: return "Indefinitely"
        }
    }
}

// MARK: - Accessibility Settings

struct AccessibilitySettings: Codable {
    var voiceOverEnabled: Bool
    var largeText: Bool
    var highContrast: Bool
    var reduceMotion: Bool
    var buttonShapes: Bool
    var hapticFeedback: HapticFeedbackLevel
    var audioDescriptions: Bool
    var screenReaderSupport: Bool
    var colorBlindnessSupport: ColorBlindnessType
    var gestureAssistance: Bool
    
    static let `default` = AccessibilitySettings(
        voiceOverEnabled: false,
        largeText: false,
        highContrast: false,
        reduceMotion: false,
        buttonShapes: false,
        hapticFeedback: .standard,
        audioDescriptions: false,
        screenReaderSupport: false,
        colorBlindnessSupport: .none,
        gestureAssistance: false
    )
}

enum HapticFeedbackLevel: String, CaseIterable, Codable {
    case none = "none"
    case light = "light"
    case standard = "standard"
    case strong = "strong"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .light: return "Light"
        case .standard: return "Standard"
        case .strong: return "Strong"
        }
    }
}

enum ColorBlindnessType: String, CaseIterable, Codable {
    case none = "none"
    case protanopia = "protanopia"
    case deuteranopia = "deuteranopia"
    case tritanopia = "tritanopia"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .protanopia: return "Protanopia"
        case .deuteranopia: return "Deuteranopia"
        case .tritanopia: return "Tritanopia"
        }
    }
}

// MARK: - AI Settings

struct AISettings: Codable {
    var formAnalysisEnabled: Bool
    var realTimeCoaching: Bool
    var performancePrediction: Bool
    var injuryPrevention: Bool
    var personalizedRecommendations: Bool
    var aiCoachPersonality: AICoachPersonality
    var analysisFrequency: AIAnalysisFrequency
    var dataProcessingLevel: AIDataProcessingLevel
    var modelUpdateFrequency: AIModelUpdateFrequency
    var privacyMode: AIPrivacyMode
    
    static let `default` = AISettings(
        formAnalysisEnabled: true,
        realTimeCoaching: true,
        performancePrediction: true,
        injuryPrevention: true,
        personalizedRecommendations: true,
        aiCoachPersonality: .motivational,
        analysisFrequency: .realTime,
        dataProcessingLevel: .standard,
        modelUpdateFrequency: .weekly,
        privacyMode: .anonymized
    )
}

enum AICoachPersonality: String, CaseIterable, Codable {
    case encouraging = "encouraging"
    case motivational = "motivational"
    case technical = "technical"
    case friendly = "friendly"
    case professional = "professional"
    
    var displayName: String {
        switch self {
        case .encouraging: return "Encouraging"
        case .motivational: return "Motivational"
        case .technical: return "Technical"
        case .friendly: return "Friendly"
        case .professional: return "Professional"
        }
    }
}

enum AIAnalysisFrequency: String, CaseIterable, Codable {
    case realTime = "realtime"
    case everyMinute = "minute"
    case every5Minutes = "5minutes"
    case postWorkout = "post"
    
    var displayName: String {
        switch self {
        case .realTime: return "Real-time"
        case .everyMinute: return "Every Minute"
        case .every5Minutes: return "Every 5 Minutes"
        case .postWorkout: return "Post-workout"
        }
    }
}

enum AIDataProcessingLevel: String, CaseIterable, Codable {
    case minimal = "minimal"
    case standard = "standard"
    case comprehensive = "comprehensive"
    
    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .standard: return "Standard"
        case .comprehensive: return "Comprehensive"
        }
    }
}

enum AIModelUpdateFrequency: String, CaseIterable, Codable {
    case never = "never"
    case weekly = "weekly"
    case monthly = "monthly"
    case automatic = "automatic"
    
    var displayName: String {
        switch self {
        case .never: return "Never"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .automatic: return "Automatic"
        }
    }
}

enum AIPrivacyMode: String, CaseIterable, Codable {
    case onDevice = "device"
    case anonymized = "anonymized"
    case cloudBased = "cloud"
    
    var displayName: String {
        switch self {
        case .onDevice: return "On-device Only"
        case .anonymized: return "Anonymized Cloud"
        case .cloudBased: return "Cloud-based"
        }
    }
}

// MARK: - Watch Settings

struct WatchSettings: Codable {
    var enableWatchApp: Bool
    var autoLaunchWorkouts: Bool
    var hapticFeedback: Bool
    var crownSensitivity: CrownSensitivity
    var workoutComplications: Bool
    var heartRateComplications: Bool
    var achievementNotifications: Bool
    var standaloneMode: Bool
    var batteryOptimization: Bool
    var watchFaceColor: String
    
    static let `default` = WatchSettings(
        enableWatchApp: true,
        autoLaunchWorkouts: true,
        hapticFeedback: true,
        crownSensitivity: .medium,
        workoutComplications: true,
        heartRateComplications: true,
        achievementNotifications: true,
        standaloneMode: false,
        batteryOptimization: true,
        watchFaceColor: "blue"
    )
}

enum CrownSensitivity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Sync Settings

struct SyncSettings: Codable {
    var cloudSyncEnabled: Bool
    var autoSync: Bool
    var syncFrequency: SyncFrequency
    var syncOnWiFiOnly: Bool
    var syncInBackground: Bool
    var conflictResolution: ConflictResolution
    var dataCompression: Bool
    var syncEncryption: Bool
    var lastSyncDate: Date?
    var syncStatus: SyncStatus
    
    static let `default` = SyncSettings(
        cloudSyncEnabled: true,
        autoSync: true,
        syncFrequency: .automatic,
        syncOnWiFiOnly: false,
        syncInBackground: true,
        conflictResolution: .latest,
        dataCompression: true,
        syncEncryption: true,
        lastSyncDate: nil,
        syncStatus: .idle
    )
}

enum SyncFrequency: String, CaseIterable, Codable {
    case manual = "manual"
    case every15Minutes = "15min"
    case hourly = "hourly"
    case daily = "daily"
    case automatic = "auto"
    
    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .every15Minutes: return "Every 15 minutes"
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .automatic: return "Automatic"
        }
    }
}

enum ConflictResolution: String, CaseIterable, Codable {
    case latest = "latest"
    case merge = "merge"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .latest: return "Use Latest"
        case .merge: return "Merge Data"
        case .manual: return "Manual Resolution"
        }
    }
}

enum SyncStatus: String, CaseIterable, Codable {
    case idle = "idle"
    case syncing = "syncing"
    case success = "success"
    case failed = "failed"
    case conflict = "conflict"
    
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .syncing: return "Syncing..."
        case .success: return "Up to date"
        case .failed: return "Sync failed"
        case .conflict: return "Conflict"
        }
    }
    
    var iconName: String {
        switch self {
        case .idle: return "icloud"
        case .syncing: return "icloud.and.arrow.up"
        case .success: return "icloud.and.arrow.up"
        case .failed: return "icloud.slash"
        case .conflict: return "exclamationmark.icloud"
        }
    }
}

// MARK: - Extensions

extension AppSettings {
    mutating func resetToDefaults() {
        self = .default
    }
    
    func validate() -> [String] {
        var errors: [String] = []
        
        if user.preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Preferred name cannot be empty")
        }
        
        if workout.weeklyGoal.workouts < 0 || workout.weeklyGoal.workouts > 14 {
            errors.append("Weekly workout goal must be between 0 and 14")
        }
        
        if health.alertThresholds.maxHeartRate <= health.alertThresholds.minHeartRate {
            errors.append("Maximum heart rate must be greater than minimum heart rate")
        }
        
        return errors
    }
}
