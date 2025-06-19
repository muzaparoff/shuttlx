//
//  SettingsView.swift
//  ShuttlX MVP
//
//  Simplified settings interface for MVP
//  Created by ShuttlX on 6/9/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    @Environment(\.presentationMode) var presentationMode
    @State private var settings = SettingsService.shared.settings
    
    var body: some View {
        NavigationView {
            Form {
                // General Settings
                Section("General") {
                    Toggle("Dark Mode", isOn: $settings.darkMode)
                    Toggle("Haptic Feedback", isOn: $settings.hapticFeedback)
                    Toggle("Workout Reminders", isOn: $settings.workoutReminders)
                    Toggle("Privacy Mode", isOn: $settings.privacyMode)
                }
                
                // Daily Goals
                Section("Daily Goals") {
                    HStack {
                        Text("Step Count")
                        Spacer()
                        Text("\(SettingsService.shared.dailyGoals.stepCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Workout Minutes")
                        Spacer()
                        Text("\(SettingsService.shared.dailyGoals.workoutMinutes)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Active Calories")
                        Spacer()
                        Text("\(SettingsService.shared.dailyGoals.activeCalories)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Workout Settings
                Section("Workout") {
                    Toggle("Auto Start", isOn: Binding(
                        get: { SettingsService.shared.workoutSettings.autoStart },
                        set: { newValue in
                            var workoutSettings = SettingsService.shared.workoutSettings
                            workoutSettings.autoStart = newValue
                            SettingsService.shared.updateWorkoutSettings(workoutSettings)
                        }
                    ))
                    
                    Toggle("Auto Pause", isOn: Binding(
                        get: { SettingsService.shared.workoutSettings.autoPause },
                        set: { newValue in
                            var workoutSettings = SettingsService.shared.workoutSettings
                            workoutSettings.autoPause = newValue
                            SettingsService.shared.updateWorkoutSettings(workoutSettings)
                        }
                    ))
                    
                    Toggle("Interval Audio", isOn: Binding(
                        get: { SettingsService.shared.workoutSettings.intervalAudio },
                        set: { newValue in
                            var workoutSettings = SettingsService.shared.workoutSettings
                            workoutSettings.intervalAudio = newValue
                            SettingsService.shared.updateWorkoutSettings(workoutSettings)
                        }
                    ))
                    
                    Toggle("Screen Always On", isOn: Binding(
                        get: { SettingsService.shared.workoutSettings.screenAlwaysOn },
                        set: { newValue in
                            var workoutSettings = SettingsService.shared.workoutSettings
                            workoutSettings.screenAlwaysOn = newValue
                            SettingsService.shared.updateWorkoutSettings(workoutSettings)
                        }
                    ))
                }
                
                // Health Settings
                Section("Health") {
                    Toggle("Sync to HealthKit", isOn: Binding(
                        get: { SettingsService.shared.healthSettings.syncToHealthKit },
                        set: { newValue in
                            var healthSettings = SettingsService.shared.healthSettings
                            healthSettings.syncToHealthKit = newValue
                            SettingsService.shared.updateHealthSettings(healthSettings)
                        }
                    ))
                    
                    Toggle("Track Heart Rate", isOn: Binding(
                        get: { SettingsService.shared.healthSettings.trackHeartRate },
                        set: { newValue in
                            var healthSettings = SettingsService.shared.healthSettings
                            healthSettings.trackHeartRate = newValue
                            SettingsService.shared.updateHealthSettings(healthSettings)
                        }
                    ))
                    
                    Toggle("Track Steps", isOn: Binding(
                        get: { SettingsService.shared.healthSettings.trackSteps },
                        set: { newValue in
                            var healthSettings = SettingsService.shared.healthSettings
                            healthSettings.trackSteps = newValue
                            SettingsService.shared.updateHealthSettings(healthSettings)
                        }
                    ))
                }
                
                // Privacy Settings
                Section("Privacy") {
                    Toggle("Share Health Data", isOn: Binding(
                        get: { SettingsService.shared.privacySettings.shareHealthData },
                        set: { newValue in
                            var privacySettings = SettingsService.shared.privacySettings
                            privacySettings.shareHealthData = newValue
                            SettingsService.shared.updatePrivacySettings(privacySettings)
                        }
                    ))
                    
                    Toggle("Allow Analytics", isOn: Binding(
                        get: { SettingsService.shared.privacySettings.allowAnalytics },
                        set: { newValue in
                            var privacySettings = SettingsService.shared.privacySettings
                            privacySettings.allowAnalytics = newValue
                            SettingsService.shared.updatePrivacySettings(privacySettings)
                        }
                    ))
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("MVP.1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onChange(of: settings) { _, newSettings in
            SettingsService.shared.updateSettings(newSettings)
        }
    }
}
