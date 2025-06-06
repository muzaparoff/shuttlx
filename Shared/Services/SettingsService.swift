//
//  SettingsService.swift
//  ShuttlX
//
//  Comprehensive settings management service
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine
import CloudKit

@MainActor
class SettingsService: ObservableObject {
    static let shared = SettingsService()
    
    @Published var settings: AppSettings = .default
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var lastError: SettingsError?
    
    private let cloudKitService = CloudKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let settingsKey = "app_settings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        loadSettings()
        setupSettingsObserver()
    }
    
    // MARK: - Settings Management
    
    func loadSettings() {
        isLoading = true
        
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let loadedSettings = try? decoder.decode(AppSettings.self, from: data) {
            settings = loadedSettings
        } else {
            settings = .default
            saveSettings()
        }
        
        isLoading = false
    }
    
    func saveSettings() {
        do {
            let data = try encoder.encode(settings)
            UserDefaults.standard.set(data, forKey: settingsKey)
            
            // Sync to CloudKit if enabled
            if settings.sync.cloudSyncEnabled {
                Task {
                    await syncSettingsToCloud()
                }
            }
        } catch {
            lastError = .saveFailed(error.localizedDescription)
        }
    }
    
    func resetToDefaults() {
        settings = .default
        saveSettings()
    }
    
    func exportSettings() -> Data? {
        do {
            return try encoder.encode(settings)
        } catch {
            lastError = .exportFailed(error.localizedDescription)
            return nil
        }
    }
    
    func importSettings(from data: Data) -> Bool {
        do {
            let importedSettings = try decoder.decode(AppSettings.self, from: data)
            let errors = importedSettings.validate()
            
            if errors.isEmpty {
                settings = importedSettings
                saveSettings()
                return true
            } else {
                lastError = .validationFailed(errors.joined(separator: ", "))
                return false
            }
        } catch {
            lastError = .importFailed(error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Individual Setting Updates
    
    func updateUserSettings(_ userSettings: UserSettings) {
        settings.user = userSettings
        saveSettings()
    }
    
    func updateWorkoutSettings(_ workoutSettings: WorkoutSettings) {
        settings.workout = workoutSettings
        saveSettings()
        
        // Apply workout-specific configurations
        applyWorkoutSettings(workoutSettings)
    }
    
    func updateAudioSettings(_ audioSettings: AudioSettings) {
        settings.audio = audioSettings
        saveSettings()
        
        // Notify audio coaching manager
        NotificationCenter.default.post(
            name: .audioSettingsChanged,
            object: audioSettings
        )
    }
    
    func updateHealthSettings(_ healthSettings: HealthSettings) {
        settings.health = healthSettings
        saveSettings()
        
        // Update HealthKit permissions if needed
        if healthSettings.healthKitEnabled {
            Task {
                await requestHealthPermissions(healthSettings)
            }
        }
    }
    
    func updateSocialSettings(_ socialSettings: SocialSettings) {
        settings.social = socialSettings
        saveSettings()
        
        // Update social service configuration
        NotificationCenter.default.post(
            name: .socialSettingsChanged,
            object: socialSettings
        )
    }
    
    func updateNotificationSettings(_ notificationSettings: NotificationSettings) {
        settings.notifications = notificationSettings
        saveSettings()
        
        // Update notification service
        Task {
            await NotificationService.shared.updateSettings(notificationSettings)
        }
    }
    
    func updatePrivacySettings(_ privacySettings: PrivacySettings) {
        settings.privacy = privacySettings
        saveSettings()
        
        // Apply privacy configurations
        applyPrivacySettings(privacySettings)
    }
    
    func updateAccessibilitySettings(_ accessibilitySettings: AccessibilitySettings) {
        settings.accessibility = accessibilitySettings
        saveSettings()
        
        // Apply accessibility configurations
        applyAccessibilitySettings(accessibilitySettings)
    }
    
    func updateAISettings(_ aiSettings: AISettings) {
        settings.ai = aiSettings
        saveSettings()
        
        // Update AI services
        NotificationCenter.default.post(
            name: .aiSettingsChanged,
            object: aiSettings
        )
    }
    
    func updateWatchSettings(_ watchSettings: WatchSettings) {
        settings.watch = watchSettings
        saveSettings()
        
        // Sync to Watch if connected
        Task {
            await syncSettingsToWatch()
        }
    }
    
    func updateSyncSettings(_ syncSettings: SyncSettings) {
        settings.sync = syncSettings
        saveSettings()
        
        // Update sync behavior
        configureSyncBehavior(syncSettings)
    }
    
    // MARK: - Theme and Appearance
    
    func updateTheme(_ theme: AppTheme) {
        settings.user.theme = theme
        saveSettings()
        applyTheme(theme)
    }
    
    func updateAccentColor(_ color: String) {
        settings.user.accentColor = color
        saveSettings()
    }
    
    private func applyTheme(_ theme: AppTheme) {
        // Apply theme to the app's appearance
        switch theme {
        case .light:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .light
        case .dark:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .dark
        case .system:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .unspecified
        }
    }
    
    // MARK: - Units and Localization
    
    func updateUnits(_ units: UnitSystem) {
        settings.user.units = units
        saveSettings()
        
        // Notify other services about unit change
        NotificationCenter.default.post(
            name: .unitsChanged,
            object: units
        )
    }
    
    func updateLanguage(_ language: String) {
        settings.user.language = language
        saveSettings()
        
        // Apply language change (requires app restart in most cases)
        NotificationCenter.default.post(
            name: .languageChanged,
            object: language
        )
    }
    
    // MARK: - Goals and Targets
    
    func updateWeeklyGoal(_ goal: WeeklyGoal) {
        settings.workout.weeklyGoal = goal
        saveSettings()
    }
    
    func updateDailyGoal(_ goal: DailyGoal) {
        settings.workout.dailyGoal = goal
        saveSettings()
    }
    
    func updateHeartRateZone(_ zone: HeartRateZone) {
        settings.workout.targetHeartRateZone = zone
        saveSettings()
    }
    
    // MARK: - Cloud Sync
    
    func syncSettingsToCloud() async {
        guard settings.sync.cloudSyncEnabled else { return }
        
        isSyncing = true
        settings.sync.syncStatus = .syncing
        
        do {
            // Create CloudKit record
            let record = CKRecord(recordType: "UserSettings")
            record["userId"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: "current_user"), action: .none)
            record["settingsData"] = try encoder.encode(settings)
            record["lastModified"] = Date()
            
            _ = try await cloudKitService.save(record: record)
            
            settings.sync.syncStatus = .success
            settings.sync.lastSyncDate = Date()
            
        } catch {
            settings.sync.syncStatus = .failed
            lastError = .syncFailed(error.localizedDescription)
        }
        
        isSyncing = false
        saveSettings()
    }
    
    func syncSettingsFromCloud() async {
        guard settings.sync.cloudSyncEnabled else { return }
        
        isSyncing = true
        settings.sync.syncStatus = .syncing
        
        do {
            // Fetch settings from CloudKit
            let predicate = NSPredicate(format: "userId == %@", CKRecord.Reference(recordID: CKRecord.ID(recordName: "current_user"), action: .none))
            let query = CKQuery(recordType: "UserSettings", predicate: predicate)
            
            let (matchResults, _) = try await cloudKitService.database.records(matching: query)
            
            if let record = matchResults.first?.1 {
                if let settingsData = record["settingsData"] as? Data {
                    let cloudSettings = try decoder.decode(AppSettings.self, from: settingsData)
                    
                    // Handle conflict resolution
                    let mergedSettings = await resolveSettingsConflict(local: settings, cloud: cloudSettings)
                    settings = mergedSettings
                    
                    settings.sync.syncStatus = .success
                    settings.sync.lastSyncDate = Date()
                }
            }
            
        } catch {
            settings.sync.syncStatus = .failed
            lastError = .syncFailed(error.localizedDescription)
        }
        
        isSyncing = false
        saveSettings()
    }
    
    private func resolveSettingsConflict(local: AppSettings, cloud: AppSettings) async -> AppSettings {
        switch settings.sync.conflictResolution {
        case .latest:
            // Use cloud settings (assuming they're newer)
            return cloud
        case .merge:
            // Merge settings intelligently
            return mergeSettings(local: local, cloud: cloud)
        case .manual:
            // Present conflict resolution UI to user
            settings.sync.syncStatus = .conflict
            return local
        }
    }
    
    private func mergeSettings(local: AppSettings, cloud: AppSettings) -> AppSettings {
        var merged = local
        
        // Merge user preferences (prefer cloud for profile data)
        merged.user.preferredName = cloud.user.preferredName.isEmpty ? local.user.preferredName : cloud.user.preferredName
        merged.user.units = cloud.user.units
        merged.user.language = cloud.user.language
        merged.user.theme = cloud.user.theme
        
        // Merge workout settings (prefer local for device-specific settings)
        merged.workout.defaultWorkoutType = cloud.workout.defaultWorkoutType
        merged.workout.weeklyGoal = cloud.workout.weeklyGoal
        merged.workout.dailyGoal = cloud.workout.dailyGoal
        
        // Merge notification settings (prefer local for device-specific)
        merged.notifications = local.notifications
        
        // Merge privacy settings (prefer most restrictive)
        merged.privacy.dataCollection = [local.privacy.dataCollection, cloud.privacy.dataCollection].min() ?? .minimal
        merged.privacy.locationSharing = [local.privacy.locationSharing, cloud.privacy.locationSharing].min() ?? .never
        
        return merged
    }
    
    // MARK: - Watch Connectivity
    
    func syncSettingsToWatch() async {
        #if os(iOS)
        guard settings.watch.enableWatchApp else { return }
        
        // Create watch-specific settings subset
        let watchSettings = WatchSettingsSync(
            workoutSettings: settings.workout,
            audioSettings: settings.audio,
            healthSettings: settings.health,
            watchSettings: settings.watch
        )
        
        do {
            let data = try encoder.encode(watchSettings)
            // Send to watch via WatchConnectivity
            // Implementation would use WCSession
            print("Settings synced to Watch")
        } catch {
            lastError = .watchSyncFailed(error.localizedDescription)
        }
        #endif
    }
    
    // MARK: - Settings Application
    
    private func applyWorkoutSettings(_ workoutSettings: WorkoutSettings) {
        // Configure GPS accuracy
        LocationManager.shared.updateAccuracy(workoutSettings.gpsAccuracy)
        
        // Configure screen timeout
        UIApplication.shared.isIdleTimerDisabled = workoutSettings.screenTimeoutDisabled
        
        // Configure haptic feedback
        if workoutSettings.hapticFeedback {
            UIImpactFeedbackGenerator().prepare()
        }
    }
    
    private func applyPrivacySettings(_ privacySettings: PrivacySettings) {
        // Configure analytics
        // Analytics.shared.setEnabled(privacySettings.analyticsSharing)
        
        // Configure crash reporting
        // CrashReporter.shared.setEnabled(privacySettings.crashReporting)
        
        // Configure data encryption
        if privacySettings.personalDataEncryption {
            // Enable encryption for sensitive data storage
        }
    }
    
    private func applyAccessibilitySettings(_ accessibilitySettings: AccessibilitySettings) {
        // Configure haptic feedback level
        switch accessibilitySettings.hapticFeedback {
        case .none:
            break // Disable haptics
        case .light:
            UIImpactFeedbackGenerator.FeedbackStyle.light
        case .standard:
            UIImpactFeedbackGenerator.FeedbackStyle.medium
        case .strong:
            UIImpactFeedbackGenerator.FeedbackStyle.heavy
        }
        
        // Configure motion reduction
        if accessibilitySettings.reduceMotion {
            // Reduce animations and transitions
        }
        
        // Configure high contrast
        if accessibilitySettings.highContrast {
            // Apply high contrast theme
        }
    }
    
    private func configureSyncBehavior(_ syncSettings: SyncSettings) {
        // Configure automatic sync timer
        if syncSettings.autoSync && syncSettings.syncFrequency != .manual {
            let interval: TimeInterval
            switch syncSettings.syncFrequency {
            case .every15Minutes:
                interval = 15 * 60
            case .hourly:
                interval = 60 * 60
            case .daily:
                interval = 24 * 60 * 60
            default:
                interval = 15 * 60 // Default to 15 minutes
            }
            
            // Set up sync timer
            setupSyncTimer(interval: interval)
        }
    }
    
    private func setupSyncTimer(interval: TimeInterval) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.syncSettingsToCloud()
            }
        }
    }
    
    // MARK: - Health Permissions
    
    private func requestHealthPermissions(_ healthSettings: HealthSettings) async {
        let healthManager = HealthManager.shared
        
        var typesToRead: Set<HKSampleType> = []
        
        if healthSettings.trackHeartRate {
            typesToRead.insert(HKQuantityType.quantityType(forIdentifier: .heartRate)!)
        }
        
        if healthSettings.trackSteps {
            typesToRead.insert(HKQuantityType.quantityType(forIdentifier: .stepCount)!)
        }
        
        if healthSettings.trackCalories {
            typesToRead.insert(HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)
        }
        
        if healthSettings.trackSleep {
            if #available(iOS 16.0, *) {
                typesToRead.insert(HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!)
            }
        }
        
        await healthManager.requestAuthorization(toRead: typesToRead, toWrite: typesToRead)
    }
    
    // MARK: - Settings Observer
    
    private func setupSettingsObserver() {
        // Auto-save when settings change
        $settings
            .dropFirst() // Skip initial value
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Validation
    
    func validateSettings() -> [String] {
        return settings.validate()
    }
    
    // MARK: - Migration
    
    func migrateSettingsIfNeeded() {
        // Check for settings version and migrate if necessary
        let currentVersion = "1.0"
        let storedVersion = UserDefaults.standard.string(forKey: "settings_version") ?? "0.0"
        
        if storedVersion != currentVersion {
            performSettingsMigration(from: storedVersion, to: currentVersion)
            UserDefaults.standard.set(currentVersion, forKey: "settings_version")
        }
    }
    
    private func performSettingsMigration(from oldVersion: String, to newVersion: String) {
        // Implement migration logic based on version differences
        print("Migrating settings from \(oldVersion) to \(newVersion)")
        
        // Example migration logic
        if oldVersion == "0.0" {
            // First time setup - use defaults
            settings = .default
        }
        
        saveSettings()
    }
}

// MARK: - Supporting Types

enum SettingsError: LocalizedError {
    case saveFailed(String)
    case loadFailed(String)
    case syncFailed(String)
    case watchSyncFailed(String)
    case exportFailed(String)
    case importFailed(String)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save settings: \(message)"
        case .loadFailed(let message):
            return "Failed to load settings: \(message)"
        case .syncFailed(let message):
            return "Failed to sync settings: \(message)"
        case .watchSyncFailed(let message):
            return "Failed to sync settings to Watch: \(message)"
        case .exportFailed(let message):
            return "Failed to export settings: \(message)"
        case .importFailed(let message):
            return "Failed to import settings: \(message)"
        case .validationFailed(let message):
            return "Settings validation failed: \(message)"
        }
    }
}

struct WatchSettingsSync: Codable {
    let workoutSettings: WorkoutSettings
    let audioSettings: AudioSettings
    let healthSettings: HealthSettings
    let watchSettings: WatchSettings
}

// MARK: - Notification Names

extension Notification.Name {
    static let audioSettingsChanged = Notification.Name("audioSettingsChanged")
    static let socialSettingsChanged = Notification.Name("socialSettingsChanged")
    static let aiSettingsChanged = Notification.Name("aiSettingsChanged")
    static let unitsChanged = Notification.Name("unitsChanged")
    static let languageChanged = Notification.Name("languageChanged")
}
