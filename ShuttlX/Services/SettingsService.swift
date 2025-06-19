//
//  SettingsService.swift
//  ShuttlX MVP
//
//  Simplified settings management for run-walk interval training
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import Combine
import UIKit
import HealthKit

@MainActor
class SettingsService: ObservableObject {
    static let shared = SettingsService()
    
    @Published var settings: AppSettings = .default
    @Published var dailyGoals: DailyGoal = .default
    @Published var workoutSettings: WorkoutSettings = .default
    @Published var healthSettings: HealthSettings = .default
    @Published var privacySettings: PrivacySettings = .default
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    private let settingsKey = "app_settings_mvp"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        loadSettings()
        setupSettingsObserver()
    }
    
    // MARK: - Settings Loading & Saving
    
    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decodedSettings = try? decoder.decode(AppSettings.self, from: data) else {
            settings = .default
            return
        }
        settings = decodedSettings
    }
    
    private func saveSettings() {
        guard let data = try? encoder.encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }
    
    private func setupSettingsObserver() {
        $settings
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - MVP Settings Methods
    
    func toggleDarkMode() {
        settings.darkMode.toggle()
        applyTheme()
    }
    
    func toggleHapticFeedback() {
        settings.hapticFeedback.toggle()
    }
    
    func toggleWorkoutReminders() {
        settings.workoutReminders.toggle()
    }
    
    func togglePrivacyMode() {
        settings.privacyMode.toggle()
    }
    
    private func applyTheme() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        window.overrideUserInterfaceStyle = settings.darkMode ? .dark : .light
    }
    
    // MARK: - Update Methods
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        if settings.darkMode != newSettings.darkMode {
            applyTheme()
        }
    }
    
    func updateWorkoutSettings(_ newSettings: WorkoutSettings) {
        workoutSettings = newSettings
    }
    
    func updateDailyGoals(_ newGoals: DailyGoal) {
        dailyGoals = newGoals
    }
    
    func updateHealthSettings(_ newSettings: HealthSettings) {
        healthSettings = newSettings
    }
    
    func updatePrivacySettings(_ newSettings: PrivacySettings) {
        privacySettings = newSettings
    }
    
    // MARK: - Reset Settings
    
    func resetToDefaults() {
        settings = .default
    }
    
    // MARK: - Cloud Sync (Placeholder)
    
    private func syncSettingsToCloud() async {
        // TODO: Implement cloud sync functionality
        print("Cloud sync not implemented yet")
    }
}

