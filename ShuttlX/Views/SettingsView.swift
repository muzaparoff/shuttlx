//
//  SettingsView.swift
//  ShuttlX
//
//  Comprehensive settings interface with all app configuration options
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingHealthKitPermissions = false
    @State private var showingDataExport = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Section
                ProfileSection()
                
                // Workout Settings
                WorkoutSettingsSection()
                
                // Health & Fitness
                HealthSettingsSection(showingHealthKitPermissions: $showingHealthKitPermissions)
                
                // Audio & Coaching
                AudioSettingsSection()
                
                // Social & Privacy
                SocialSettingsSection()
                
                // Notifications
                NotificationSettingsSection()
                
                // Accessibility
                AccessibilitySettingsSection()
                
                // AI & Machine Learning
                AISettingsSection()
                
                // Apple Watch
                WatchSettingsSection()
                
                // Data & Storage
                DataSettingsSection(showingDataExport: $showingDataExport)
                
                // About & Support
                AboutSection(showingAbout: $showingAbout)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingHealthKitPermissions) {
                HealthKitPermissionsView()
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
}

// MARK: - Profile Section

struct ProfileSection: View {
    @StateObject private var settingsService = SettingsService.shared
    @EnvironmentObject var socialService: SocialService
    
    var body: some View {
        Section("Profile") {
            HStack {
                AsyncImage(url: URL(string: socialService.currentUserProfile?.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(socialService.currentUserProfile?.displayName ?? "User")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("@\(socialService.currentUserProfile?.username ?? "username")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Navigate to profile editing
            }
        }
    }
}

// MARK: - Workout Settings Section

struct WorkoutSettingsSection: View {
    @StateObject private var settingsService = SettingsService.shared
    @State private var workoutSettings: WorkoutSettings
    
    init() {
        _workoutSettings = State(initialValue: SettingsService.shared.settings.workout)
    }
    
    var body: some View {
        Section("Workout Settings") {
            // Units
            Picker("Distance Unit", selection: $workoutSettings.units.distanceUnit) {
                Text("Kilometers").tag("km")
                Text("Miles").tag("mi")
            }
            
            Picker("Weight Unit", selection: $workoutSettings.units.weightUnit) {
                Text("Kilograms").tag("kg")
                Text("Pounds").tag("lbs")
            }
            
            // Auto-pause
            Toggle("Auto-pause Workouts", isOn: $workoutSettings.autoPause)
            
            // GPS accuracy
            Picker("GPS Accuracy", selection: $workoutSettings.gpsAccuracy) {
                Text("Best").tag(GPSAccuracy.best)
                Text("High").tag(GPSAccuracy.high)
                Text("Balanced").tag(GPSAccuracy.balanced)
                Text("Low").tag(GPSAccuracy.low)
            }
            
            // Daily goals
            NavigationLink("Daily Goals") {
                DailyGoalsView(goals: $workoutSettings.dailyGoal)
            }
            
            // Workout types
            NavigationLink("Workout Types") {
                WorkoutTypesSettingsView(workoutTypes: $workoutSettings.enabledWorkoutTypes)
            }
        }
        .onChange(of: workoutSettings) { newSettings in
            var settings = settingsService.settings
            settings.workout = newSettings
            Task {
                await settingsService.updateSettings(settings)
            }
        }
    }
}

// MARK: - Health Settings Section

struct HealthSettingsSection: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    @Binding var showingHealthKitPermissions: Bool
    @State private var healthSettings: HealthSettings
    
    init(showingHealthKitPermissions: Binding<Bool>) {
        self._showingHealthKitPermissions = showingHealthKitPermissions
        _healthSettings = State(initialValue: SettingsService.shared.settings.health)
    }
    
    var body: some View {
        Section("Health & Fitness") {
            Toggle("HealthKit Integration", isOn: $healthSettings.healthKitEnabled)
                .onChange(of: healthSettings.healthKitEnabled) { enabled in
                    if enabled {
                        Task {
                            await serviceLocator.healthManager.requestHealthPermissions()
                        }
                    }
                }
            
            if healthSettings.healthKitEnabled {
                Button("Manage HealthKit Permissions") {
                    showingHealthKitPermissions = true
                }
                
                Toggle("Heart Rate Monitoring", isOn: $healthSettings.heartRateMonitoring)
                Toggle("Background Heart Rate", isOn: $healthSettings.backgroundHeartRate)
                Toggle("Recovery Tracking", isOn: $healthSettings.recoveryTracking)
                Toggle("Sleep Analysis", isOn: $healthSettings.sleepTracking)
                
                Picker("Heart Rate Zones", selection: $healthSettings.heartRateZoneCalculation) {
                    Text("Automatic").tag(HeartRateZoneCalculation.automatic)
                    Text("Age-based").tag(HeartRateZoneCalculation.ageBased)
                    Text("Custom").tag(HeartRateZoneCalculation.custom)
                }
                
                if healthSettings.heartRateZoneCalculation == .custom {
                    NavigationLink("Custom Heart Rate Zones") {
                        HeartRateZonesView(zones: $healthSettings.customHeartRateZones)
                    }
                }
            }
        }
        .onChange(of: healthSettings) { newSettings in
            var settings = settingsService.settings
            settings.health = newSettings
            Task {
                await settingsService.updateSettings(settings)
            }
        }
    }
}

// MARK: - Audio Settings Section

struct AudioSettingsSection: View {
    @StateObject private var settingsService = SettingsService.shared
    @State private var audioSettings: AudioSettings
    
    init() {
        _audioSettings = State(initialValue: SettingsService.shared.settings.audio)
    }
    
    var body: some View {
        Section("Audio & Coaching") {
            Toggle("Audio Coaching", isOn: $audioSettings.coachingEnabled)
            
            if audioSettings.coachingEnabled {
                Picker("Voice Type", selection: $audioSettings.voiceType) {
                    ForEach(VoiceType.allCases, id: \.self) { voice in
                        Text(voice.displayName).tag(voice)
                    }
                }
                
                VStack {
                    HStack {
                        Text("Volume Level")
                        Spacer()
                        Text("\(Int(audioSettings.volumeLevel * 100))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $audioSettings.volumeLevel, in: 0...1, step: 0.1)
                }
                
                Picker("Feedback Frequency", selection: $audioSettings.audioFeedbackFrequency) {
                    ForEach(AudioFeedbackFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                
                Toggle("Motivational Messages", isOn: $audioSettings.motivationalMessages)
                Toggle("Countdown Audio", isOn: $audioSettings.countdownAudio)
                Toggle("Split Announcements", isOn: $audioSettings.splitAnnouncements)
                Toggle("Heart Rate Announcements", isOn: $audioSettings.heartRateAnnouncements)
                Toggle("Interval Timer Sounds", isOn: $audioSettings.intervalTimerSounds)
            }
        }
        .onChange(of: audioSettings) { newSettings in
            var settings = settingsService.settings
            settings.audio = newSettings
            Task {
                await settingsService.updateSettings(settings)
            }
        }
    }
}

// MARK: - Social Settings Section

struct SocialSettingsSection: View {
    @StateObject private var settingsService = SettingsService.shared
    @State private var socialSettings: SocialSettings
    @State private var privacySettings: PrivacySettings
    
    init() {
        _socialSettings = State(initialValue: SettingsService.shared.settings.social)
        _privacySettings = State(initialValue: SettingsService.shared.settings.privacy)
    }
    
    var body: some View {
        Section("Social & Privacy") {
            Toggle("Social Features", isOn: $socialSettings.socialFeaturesEnabled)
            
            if socialSettings.socialFeaturesEnabled {
                Toggle("Activity Sharing", isOn: $socialSettings.activitySharing)
                Toggle("Achievement Sharing", isOn: $socialSettings.achievementSharing)
                Toggle("Location Sharing", isOn: $socialSettings.locationSharing)
                Toggle("Workout Sharing", isOn: $socialSettings.workoutSharing)
                
                Picker("Profile Visibility", selection: $privacySettings.profileVisibility) {
                    Text("Public").tag(ProfileVisibility.public)
                    Text("Friends Only").tag(ProfileVisibility.friendsOnly)
                    Text("Private").tag(ProfileVisibility.private)
                }
                
                Picker("Activity Visibility", selection: $privacySettings.activityVisibility) {
                    Text("Public").tag(ActivityVisibility.public)
                    Text("Friends Only").tag(ActivityVisibility.friendsOnly)
                    Text("Private").tag(ActivityVisibility.private)
                }
                
                Toggle("Allow Messages from Strangers", isOn: $privacySettings.allowMessagesFromStrangers)
                Toggle("Show Online Status", isOn: $privacySettings.showOnlineStatus)
            }
        }
        .onChange(of: socialSettings) { newSettings in
            var settings = settingsService.settings
            settings.social = newSettings
            Task {
                await settingsService.updateSettings(settings)
            }
        }
        .onChange(of: privacySettings) { newSettings in
            var settings = settingsService.settings
            settings.privacy = newSettings
            Task {
                await settingsService.updateSettings(settings)
            }
        }
    }
}

// MARK: - Notification Settings Section

struct NotificationSettingsSection: View {
    var body: some View {
        Section("Notifications") {
            NavigationLink("Notification Settings") {
                NotificationSettingsView()
            }
        }
    }
}

// MARK: - Accessibility Settings Section

struct AccessibilitySettingsSection: View {
    @StateObject private var settingsService = SettingsService.shared
    @State private var accessibilitySettings: AccessibilitySettings
    
    init() {
        _accessibilitySettings = State(initialValue: SettingsService.shared.settings.accessibility)
    }
    
    var body: some View {
        Section("Accessibility") {
            Toggle("VoiceOver Support", isOn: $accessibilitySettings.voiceOverEnabled)
            Toggle("Reduce Motion", isOn: $accessibilitySettings.reduceMotionEnabled)
            Toggle("High Contrast", isOn: $accessibilitySettings.highContrastEnabled)
            Toggle("Large Text", isOn: $accessibilitySettings.largeTextEnabled)
            
            Picker("Font Size", selection: $accessibilitySettings.fontSize) {
                Text("Small").tag(FontSize.small)
                Text("Medium").tag(FontSize.medium)
                Text("Large").tag(FontSize.large)
                Text("Extra Large").tag(FontSize.extraLarge)
            }
            
            Toggle("Haptic Feedback", isOn: $accessibilitySettings.hapticFeedbackEnabled)
            Toggle("Audio Descriptions", isOn: $accessibilitySettings.audioDescriptionsEnabled)
            Toggle("Guided Access Mode", isOn: $accessibilitySettings.guidedAccessMode)
        }
        .onChange(of: accessibilitySettings) { newSettings in
            var settings = settingsService.settings
            settings.accessibility = newSettings
            Task {
                await settingsService.updateSettings(settings)
            }
        }
    }
}

// MARK: - AI Settings Section

struct AISettingsSection: View {
    @StateObject private var settingsService = SettingsService.shared
    @State private var aiSettings: AISettings
    
    init() {
        _aiSettings = State(initialValue: SettingsService.shared.settings.ai)
    }
    
    var body: some View {
        Section("AI & Machine Learning") {
            Toggle("AI Form Analysis", isOn: $aiSettings.formAnalysisEnabled)
            Toggle("Performance Predictions", isOn: $aiSettings.performancePredictionEnabled)
            Toggle("Injury Risk Assessment", isOn: $aiSettings.injuryRiskAssessmentEnabled)
            Toggle("Personalized Coaching", isOn: $aiSettings.personalizedCoachingEnabled)
            
            if aiSettings.formAnalysisEnabled {
                Picker("Analysis Sensitivity", selection: $aiSettings.formAnalysisSensitivity) {
                    Text("Low").tag(FormAnalysisSensitivity.low)
                    Text("Medium").tag(FormAnalysisSensitivity.medium)
                    Text("High").tag(FormAnalysisSensitivity.high)
                }
                
                Toggle("Real-time Feedback", isOn: $aiSettings.realTimeFeedback)
                Toggle("Camera Usage", isOn: $aiSettings.cameraUsageEnabled)
            }
            
            Toggle("Data Collection for AI", isOn: $aiSettings.dataCollectionEnabled)
                .foregroundColor(aiSettings.dataCollectionEnabled ? .primary : .secondary)
            
            if aiSettings.dataCollectionEnabled {
                Text("Anonymous data is used to improve AI models")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: aiSettings) { newSettings in
            var settings = settingsService.settings
            settings.ai = newSettings
            Task {
                await settingsService.updateSettings(settings)
            }
        }
    }
}

// MARK: - Watch Settings Section

struct WatchSettingsSection: View {
    @StateObject private var settingsService = SettingsService.shared
    @State private var watchSettings: WatchSettings
    
    init() {
        _watchSettings = State(initialValue: SettingsService.shared.settings.watch)
    }
    
    var body: some View {
        Section("Apple Watch") {
            Toggle("Watch App Enabled", isOn: $watchSettings.watchAppEnabled)
            
            if watchSettings.watchAppEnabled {
                Toggle("Auto-sync Workouts", isOn: $watchSettings.autoSyncWorkouts)
                Toggle("Heart Rate Sync", isOn: $watchSettings.heartRateSync)
                Toggle("Notification Mirror", isOn: $watchSettings.notificationMirror)
                Toggle("Haptic Feedback", isOn: $watchSettings.hapticFeedback)
                
                Picker("Watch Face Complication", selection: $watchSettings.complicationStyle) {
                    Text("None").tag(ComplicationStyle.none)
                    Text("Simple").tag(ComplicationStyle.simple)
                    Text("Detailed").tag(ComplicationStyle.detailed)
                }
                
                Toggle("Standalone Mode", isOn: $watchSettings.standaloneMode)
                
                if watchSettings.standaloneMode {
                    Text("Watch can function independently from iPhone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: watchSettings) { newSettings in
            var settings = settingsService.settings
            settings.watch = newSettings
            Task {
                await settingsService.updateSettings(settings)
            }
        }
    }
}

// MARK: - Data Settings Section

struct DataSettingsSection: View {
    @StateObject private var settingsService = SettingsService.shared
    @Binding var showingDataExport: Bool
    @State private var syncSettings: SyncSettings
    
    init(showingDataExport: Binding<Bool>) {
        self._showingDataExport = showingDataExport
        _syncSettings = State(initialValue: SettingsService.shared.settings.sync)
    }
    
    var body: some View {
        Section("Data & Storage") {
            Toggle("iCloud Sync", isOn: $syncSettings.iCloudSyncEnabled)
            
            if syncSettings.iCloudSyncEnabled {
                Toggle("Sync Workouts", isOn: $syncSettings.syncWorkouts)
                Toggle("Sync Health Data", isOn: $syncSettings.syncHealthData)
                Toggle("Sync Settings", isOn: $syncSettings.syncSettings)
                Toggle("Sync Social Data", isOn: $syncSettings.syncSocialData)
                
                HStack {
                    Text("Last Sync")
                    Spacer()
                    Text(syncSettings.lastSyncDate?.formatted() ?? "Never")
                        .foregroundColor(.secondary)
                }
                
                Button("Sync Now") {
                    Task {
                        await settingsService.forceSyncAllData()
                    }
                }
            }
            
            Button("Export Data") {
                showingDataExport = true
            }
            
            Button("Clear Cache") {
                Task {
                    await settingsService.clearCache()
                }
            }
            .foregroundColor(.orange)
            
            Button("Reset All Settings") {
                Task {
                    await settingsService.resetAllSettings()
                }
            }
            .foregroundColor(.red)
        }
        .onChange(of: syncSettings) { newSettings in
            var settings = settingsService.settings
            settings.sync = newSettings
            Task {
                await settingsService.updateSettings(settings)
            }
        }
    }
}

// MARK: - About Section

struct AboutSection: View {
    @Binding var showingAbout: Bool
    
    var body: some View {
        Section("About & Support") {
            Button("About ShuttlX") {
                showingAbout = true
            }
            
            Button("Privacy Policy") {
                // Open privacy policy
            }
            
            Button("Terms of Service") {
                // Open terms of service
            }
            
            Button("Contact Support") {
                // Open support contact
            }
            
            Button("Rate App") {
                // Open App Store rating
            }
            
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0 (1)")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Supporting Views

struct DailyGoalsView: View {
    @Binding var goals: DailyGoal
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section("Activity Goals") {
                VStack {
                    HStack {
                        Text("Steps")
                        Spacer()
                        Text("\(goals.steps)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(goals.steps) },
                        set: { goals.steps = Int($0) }
                    ), in: 1000...30000, step: 500)
                }
                
                VStack {
                    HStack {
                        Text("Active Minutes")
                        Spacer()
                        Text("\(goals.activeMinutes)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(goals.activeMinutes) },
                        set: { goals.activeMinutes = Int($0) }
                    ), in: 15...120, step: 5)
                }
                
                VStack {
                    HStack {
                        Text("Calories")
                        Spacer()
                        Text("\(goals.calories)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(goals.calories) },
                        set: { goals.calories = Int($0) }
                    ), in: 200...1500, step: 50)
                }
            }
            
            Section("Distance Goals") {
                VStack {
                    HStack {
                        Text("Running Distance (km)")
                        Spacer()
                        Text(String(format: "%.1f", goals.runningDistance))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $goals.runningDistance, in: 1...20, step: 0.5)
                }
                
                VStack {
                    HStack {
                        Text("Workout Frequency (per week)")
                        Spacer()
                        Text("\(goals.workoutFrequency)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(goals.workoutFrequency) },
                        set: { goals.workoutFrequency = Int($0) }
                    ), in: 1...7, step: 1)
                }
            }
        }
        .navigationTitle("Daily Goals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkoutTypesSettingsView: View {
    @Binding var workoutTypes: [String]
    @Environment(\.presentationMode) var presentationMode
    
    private let availableWorkoutTypes = [
        "Shuttle Run", "Interval Training", "Distance Running", "Sprint Training",
        "Endurance Running", "Hill Training", "Fartlek", "Tempo Running"
    ]
    
    var body: some View {
        Form {
            Section("Available Workout Types") {
                ForEach(availableWorkoutTypes, id: \.self) { type in
                    HStack {
                        Text(type)
                        Spacer()
                        if workoutTypes.contains(type) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if workoutTypes.contains(type) {
                            workoutTypes.removeAll { $0 == type }
                        } else {
                            workoutTypes.append(type)
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout Types")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HeartRateZonesView: View {
    @Binding var zones: [HeartRateZone]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section("Custom Heart Rate Zones") {
                ForEach($zones, id: \.id) { $zone in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(zone.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(zone.minHeartRate) - \(zone.maxHeartRate) BPM")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Min")
                            Slider(value: Binding(
                                get: { Double(zone.minHeartRate) },
                                set: { zone.minHeartRate = Int($0) }
                            ), in: 60...200, step: 1)
                        }
                        
                        HStack {
                            Text("Max")
                            Slider(value: Binding(
                                get: { Double(zone.maxHeartRate) },
                                set: { zone.maxHeartRate = Int($0) }
                            ), in: 60...200, step: 1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Heart Rate Zones")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HealthKitPermissionsView: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                
                Text("HealthKit Permissions")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Grant permissions to sync your health data with HealthKit for a more comprehensive fitness experience.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    PermissionRow(title: "Heart Rate", description: "Monitor heart rate during workouts")
                    PermissionRow(title: "Active Energy", description: "Track calories burned")
                    PermissionRow(title: "Distance", description: "Record workout distances")
                    PermissionRow(title: "Steps", description: "Count daily steps")
                    PermissionRow(title: "Workouts", description: "Save and sync workout sessions")
                }
                .padding()
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Grant Permissions") {
                        Task {
                            await serviceLocator.healthManager.requestHealthPermissions()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Not Now") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct DataExportView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedDataTypes: Set<DataExportType> = []
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section("Select Data to Export") {
                        ForEach(DataExportType.allCases, id: \.self) { dataType in
                            HStack {
                                Text(dataType.displayName)
                                Spacer()
                                if selectedDataTypes.contains(dataType) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedDataTypes.contains(dataType) {
                                    selectedDataTypes.remove(dataType)
                                } else {
                                    selectedDataTypes.insert(dataType)
                                }
                            }
                        }
                    }
                    
                    Section {
                        Text("Exported data will be saved as JSON files that you can import into other fitness apps or keep as a backup.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isExporting {
                    ProgressView("Exporting data...")
                        .padding()
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportData()
                    }
                    .disabled(selectedDataTypes.isEmpty || isExporting)
                }
            }
        }
    }
    
    private func exportData() {
        isExporting = true
        
        Task {
            // Simulate export process
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                isExporting = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

enum DataExportType: CaseIterable {
    case workouts
    case healthData
    case socialData
    case achievements
    case settings
    
    var displayName: String {
        switch self {
        case .workouts: return "Workout History"
        case .healthData: return "Health & Fitness Data"
        case .socialData: return "Social Activity"
        case .achievements: return "Achievements & Badges"
        case .settings: return "App Settings"
        }
    }
}

struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Name
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.accentColor)
                        
                        Text("ShuttlX")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About ShuttlX")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("ShuttlX is the ultimate shuttle run and interval training app, featuring AI-powered form analysis, comprehensive health monitoring, and social features to help you achieve your fitness goals.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key Features")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        FeatureRow(icon: "brain.head.profile", title: "AI Form Analysis", description: "Real-time coaching and form feedback")
                        FeatureRow(icon: "heart.fill", title: "Health Monitoring", description: "Comprehensive fitness and recovery tracking")
                        FeatureRow(icon: "person.3.fill", title: "Social Features", description: "Connect with training partners and compete")
                        FeatureRow(icon: "applewatch", title: "Apple Watch", description: "Full integration with Apple Watch")
                        FeatureRow(icon: "speaker.wave.3.fill", title: "Audio Coaching", description: "Personalized voice guidance")
                        FeatureRow(icon: "accessibility", title: "Accessibility", description: "Designed for everyone")
                    }
                    
                    // Credits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Credits")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        Text("Developed with ❤️ by the ShuttlX Team\n\nSpecial thanks to the fitness community for their feedback and support.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}
