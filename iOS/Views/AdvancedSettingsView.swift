//
//  AdvancedSettingsView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @StateObject private var audioCoachingManager = AudioCoachingManager()
    @StateObject private var accessibilityManager = AccessibilityManager()
    @StateObject private var weatherManager = WeatherManager()
    @StateObject private var cloudKitManager = CloudKitManager()
    
    @State private var showingAudioSettings = false
    @State private var showingAccessibilitySettings = false
    @State private var showingCloudSyncSettings = false
    @State private var showingWeatherSettings = false
    
    var body: some View {
        NavigationView {
            List {
                // Audio Coaching Section
                Section("Audio Coaching") {
                    SettingsRow(
                        icon: "speaker.wave.3.fill",
                        title: "Audio Coaching",
                        subtitle: audioCoachingManager.isEnabled ? "Enabled" : "Disabled",
                        color: .blue
                    ) {
                        showingAudioSettings = true
                    }
                    
                    Toggle("Enable Coaching", isOn: $audioCoachingManager.isEnabled)
                    
                    if audioCoachingManager.isEnabled {
                        HStack {
                            Text("Voice")
                            Spacer()
                            Text(audioCoachingManager.settings.voice.displayName)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Language")
                            Spacer()
                            Text(audioCoachingManager.settings.language.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Accessibility Section
                Section("Accessibility") {
                    SettingsRow(
                        icon: "accessibility",
                        title: "Accessibility",
                        subtitle: accessibilityManager.isVoiceOverActive ? "VoiceOver Active" : "Standard",
                        color: .green
                    ) {
                        showingAccessibilitySettings = true
                    }
                    
                    if accessibilityManager.isVoiceOverActive {
                        Label("VoiceOver is active", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Toggle("Audio Descriptions", isOn: $accessibilityManager.settings.enableAudioDescriptions)
                    Toggle("Haptic Navigation", isOn: $accessibilityManager.settings.enableHapticNavigation)
                    Toggle("Simplified Interface", isOn: $accessibilityManager.settings.enableSimplifiedInterface)
                }
                
                // Weather Integration Section
                Section("Weather Integration") {
                    SettingsRow(
                        icon: "cloud.sun.fill",
                        title: "Weather",
                        subtitle: weatherManager.currentWeather?.condition.displayName ?? "Not loaded",
                        color: .orange
                    ) {
                        showingWeatherSettings = true
                    }
                    
                    if let weather = weatherManager.currentWeather {
                        HStack {
                            Image(systemName: weather.condition.iconName)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(weather.condition.displayName)
                                    .font(.subheadline)
                                
                                Text(weather.temperatureString())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            WorkoutRecommendationBadge(
                                recommendation: weatherManager.recommendation
                            )
                        }
                    } else {
                        Button("Load Weather") {
                            Task {
                                await weatherManager.fetchWeatherForCurrentLocation()
                            }
                        }
                    }
                }
                
                // CloudKit Sync Section
                Section("iCloud Sync") {
                    SettingsRow(
                        icon: "icloud.fill",
                        title: "iCloud Sync",
                        subtitle: cloudKitManager.isCloudKitEnabled ? "Enabled" : "Disabled",
                        color: .blue
                    ) {
                        showingCloudSyncSettings = true
                    }
                    
                    HStack {
                        Text("Account Status")
                        Spacer()
                        CloudKitStatusBadge(status: cloudKitManager.accountStatus)
                    }
                    
                    if let lastSync = cloudKitManager.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(formatLastSyncDate(lastSync))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if cloudKitManager.isCloudKitEnabled {
                        Button("Sync Now") {
                            Task {
                                await cloudKitManager.syncAllData()
                            }
                        }
                        .disabled(cloudKitManager.syncStatus.isLoading)
                    }
                }
                
                // Health Integration Section
                Section("Health Integration") {
                    SettingsRow(
                        icon: "heart.fill",
                        title: "HealthKit",
                        subtitle: "Manage health data sharing",
                        color: .red
                    ) {
                        // Navigate to health settings
                    }
                    
                    Label("Workout data automatically saved to Health app", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Form Analysis Section
                Section("AI Form Analysis") {
                    SettingsRow(
                        icon: "figure.run",
                        title: "Form Analysis",
                        subtitle: "AI-powered movement analysis",
                        color: .purple
                    ) {
                        // Navigate to form analysis settings
                    }
                    
                    NavigationLink("View Analysis History") {
                        FormAnalysisView()
                    }
                }
                
                // Developer Section
                Section("Developer") {
                    Button("Generate Mock Data") {
                        generateMockData()
                    }
                    
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Advanced Settings")
            .sheet(isPresented: $showingAudioSettings) {
                AudioCoachingSettingsView(manager: audioCoachingManager)
            }
            .sheet(isPresented: $showingAccessibilitySettings) {
                AccessibilitySettingsView(manager: accessibilityManager)
            }
            .sheet(isPresented: $showingCloudSyncSettings) {
                CloudSyncSettingsView(manager: cloudKitManager)
            }
            .sheet(isPresented: $showingWeatherSettings) {
                WeatherSettingsView(manager: weatherManager)
            }
        }
    }
    
    private func generateMockData() {
        weatherManager.generateMockWeatherData()
        
        // Generate mock workout data
        // This would typically populate the local database with sample workouts
        print("🎭 Generated mock data")
    }
    
    private func clearAllData() {
        cloudKitManager.clearSyncData()
        
        // Clear all local data
        // This would typically clear Core Data or local storage
        print("🗑️ Cleared all data")
    }
    
    private func formatLastSyncDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WorkoutRecommendationBadge: View {
    let recommendation: WorkoutRecommendation?
    
    var body: some View {
        if let recommendation = recommendation {
            Text(recommendation.intensity.rawValue.capitalized)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(backgroundColorForIntensity(recommendation.intensity))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
    
    private func backgroundColorForIntensity(_ intensity: WorkoutRecommendation.RecommendationIntensity) -> Color {
        switch intensity {
        case .ideal: return .green
        case .good: return .blue
        case .caution: return .orange
        case .avoid: return .red
        }
    }
}

struct CloudKitStatusBadge: View {
    let status: CKAccountStatus
    
    var body: some View {
        Group {
            switch status {
            case .available:
                Label("Available", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .noAccount:
                Label("No Account", systemImage: "xmark.circle.fill")
                    .foregroundColor(.orange)
            case .restricted:
                Label("Restricted", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            case .couldNotDetermine:
                Label("Unknown", systemImage: "questionmark.circle.fill")
                    .foregroundColor(.gray)
            @unknown default:
                Label("Unknown", systemImage: "questionmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .font(.caption)
    }
}

// MARK: - Detailed Settings Views

struct AudioCoachingSettingsView: View {
    @ObservedObject var manager: AudioCoachingManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Voice Settings") {
                    Toggle("Enable Audio Coaching", isOn: $manager.settings.isEnabled)
                    
                    Picker("Voice Type", selection: $manager.settings.voice) {
                        ForEach(AudioCoachingSettings.VoiceType.allCases, id: \\.self) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    
                    Picker("Language", selection: $manager.settings.language) {
                        ForEach(AudioCoachingSettings.AudioLanguage.allCases, id: \\.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Volume")
                        Slider(value: $manager.settings.volume, in: 0...1, step: 0.1)
                    }
                }
                
                Section("Coaching Options") {
                    Toggle("Interval Announcements", isOn: $manager.settings.intervalAnnouncements)
                    Toggle("Progress Updates", isOn: $manager.settings.progressUpdates)
                    Toggle("Motivational Coaching", isOn: $manager.settings.motivationalCoaching)
                    Toggle("Heart Rate Alerts", isOn: $manager.settings.heartRateAlerts)
                    Toggle("Pace Guidance", isOn: $manager.settings.paceGuidance)
                    Toggle("Form Tips", isOn: $manager.settings.formTips)
                }
                
                Section("Test") {
                    Button("Test Voice") {
                        manager.speakCustomMessage("This is a test of the audio coaching system.")
                    }
                }
            }
            .navigationTitle("Audio Coaching")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        manager.configure(with: manager.settings)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AccessibilitySettingsView: View {
    @ObservedObject var manager: AccessibilityManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Announcements") {
                    Toggle("Audio Descriptions", isOn: $manager.settings.enableAudioDescriptions)
                    
                    Picker("Announcement Frequency", selection: $manager.settings.workoutAnnouncementFrequency) {
                        ForEach(AccessibilitySettings.AnnouncementFrequency.allCases, id: \\.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                }
                
                Section("Interface") {
                    Toggle("Simplified Interface", isOn: $manager.settings.enableSimplifiedInterface)
                    Toggle("Large Text Mode", isOn: $manager.settings.enableLargeTextMode)
                    Toggle("High Contrast Mode", isOn: $manager.settings.enableHighContrastMode)
                }
                
                Section("Feedback") {
                    Toggle("Haptic Navigation", isOn: $manager.settings.enableHapticNavigation)
                }
                
                Section("System Settings") {
                    if manager.settings.isVoiceOverEnabled {
                        Label("VoiceOver is enabled", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    if manager.settings.isReduceMotionEnabled {
                        Label("Reduce Motion is enabled", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    if manager.settings.isIncreaseContrastEnabled {
                        Label("Increase Contrast is enabled", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Accessibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        manager.updateSettings(manager.settings)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CloudSyncSettingsView: View {
    @ObservedObject var manager: CloudKitManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Account Status") {
                    HStack {
                        Text("iCloud Account")
                        Spacer()
                        CloudKitStatusBadge(status: manager.accountStatus)
                    }
                }
                
                Section("Sync Status") {
                    if let lastSync = manager.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Never synced")
                            .foregroundColor(.secondary)
                    }
                    
                    if manager.syncStatus.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing...")
                        }
                    }
                    
                    if let errorMessage = manager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section("Actions") {
                    Button("Sync Now") {
                        Task {
                            await manager.syncAllData()
                        }
                    }
                    .disabled(!manager.isCloudKitEnabled || manager.syncStatus.isLoading)
                    
                    Button("Clear Sync Data") {
                        manager.clearSyncData()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("iCloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WeatherSettingsView: View {
    @ObservedObject var manager: WeatherManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Current Weather") {
                    if let weather = manager.currentWeather {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: weather.condition.iconName)
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading) {
                                    Text(weather.condition.displayName)
                                        .font(.headline)
                                    
                                    Text(weather.temperatureString())
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            if let recommendation = manager.recommendation {
                                Text(recommendation.message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("No weather data available")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Refresh Weather") {
                        Task {
                            await manager.fetchWeatherForCurrentLocation()
                        }
                    }
                    .disabled(manager.isLoading)
                    
                    if manager.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading weather...")
                        }
                    }
                }
                
                Section("Workout Recommendations") {
                    if let recommendation = manager.recommendation {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Recommendation")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                WorkoutRecommendationBadge(recommendation: recommendation)
                            }
                            
                            Text(recommendation.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if !recommendation.suggestions.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Suggestions:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    ForEach(recommendation.suggestions, id: \\.self) { suggestion in
                                        Text("• \\(suggestion)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Testing") {
                    Button("Generate Mock Weather") {
                        manager.generateMockWeatherData()
                    }
                }
            }
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AdvancedSettingsView()
}

import CloudKit
