//
//  AppViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import Combine
import Foundation

class AppViewModel: ObservableObject {
    @Published var showOnboarding = false
    @Published var isWorkoutActive = false
    @Published var currentUser: UserProfile?
    @Published var colorScheme: ColorScheme? = nil
    @Published var isLoading = false
    
    // Computed property for onboarding status
    var hasCompletedOnboarding: Bool {
        return userDefaults.bool(forKey: "hasCompletedOnboarding") && currentUser != nil
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    init() {
        setupNotificationObservers()
        checkOnboardingStatus()
        loadCurrentUser()
    }
    
    // MARK: - Onboarding
    
    func completeOnboarding() {
        userDefaults.set(true, forKey: "hasCompletedOnboarding")
        showOnboarding = false
        objectWillChange.send()
    }
    
    func resetOnboarding() {
        userDefaults.set(false, forKey: "hasCompletedOnboarding")
        currentUser = nil
        showOnboarding = true
        objectWillChange.send()
    }
    
    private func loadCurrentUser() {
        // In a real app, this would load from Core Data or API
        // For now, create a sample user if onboarding is complete
        if hasCompletedOnboarding && currentUser == nil {
            currentUser = createSampleUser()
        }
    }
    
    private func createSampleUser() -> UserProfile {
        return UserProfile(
            firstName: "John",
            lastName: "Doe",
            email: "john.doe@example.com",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -28, to: Date()) ?? Date(),
            height: 1.78,
            weight: 75.0,
            fitnessLevel: .moderatelyActive,
            goals: [.generalFitness, .enduranceImprovement],
            preferences: UserPreferences(
                units: .metric,
                voiceCoaching: true,
                autoStartWorkouts: false,
                privacySettings: PrivacySettings(
                    shareWorkouts: false,
                    shareAchievements: true,
                    shareProgress: false
                ),
                notificationSettings: NotificationSettings(
                    workoutReminders: true,
                    achievementAlerts: true,
                    socialUpdates: true,
                    weeklyReports: true
                ),
                workoutSettings: WorkoutSettings(
                    defaultRestBetweenSets: 60,
                    autoExtendWorkouts: false,
                    countdownDuration: 3,
                    hapticFeedback: true
                )
            ),
            achievements: [],
            createdAt: Date().addingTimeInterval(-2592000), // 30 days ago
            lastActiveAt: Date()
        )
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .workoutCommandReceived)
            .sink { [weak self] notification in
                if let command = notification.object as? WorkoutCommand {
                    self?.handleWorkoutCommand(command)
                }
            }
            .store(in: &cancellables)
    }
    
    func checkOnboardingStatus() {
        let hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        showOnboarding = !hasCompletedOnboarding
    }
    
    func loadUserPreferences() {
        if let userData = userDefaults.data(forKey: "userProfile"),
           let user = try? JSONDecoder().decode(UserProfile.self, from: userData) {
            currentUser = user
            
            // Apply appearance preferences
            switch user.preferences.appearance.colorScheme {
            case .light:
                colorScheme = .light
            case .dark:
                colorScheme = .dark
            case .automatic:
                colorScheme = nil
            }
        }
    }
    
    func saveUserProfile(_ profile: UserProfile) {
        currentUser = profile
        
        if let userData = try? JSONEncoder().encode(profile) {
            userDefaults.set(userData, forKey: "userProfile")
        }
    }
    
    func startWorkout() {
        isWorkoutActive = true
    }
    
    func endWorkout() {
        isWorkoutActive = false
    }
    
    private func handleWorkoutCommand(_ command: WorkoutCommand) {
        switch command.type {
        case .start:
            startWorkout()
        case .stop:
            endWorkout()
        default:
            // Forward to workout view model
            NotificationCenter.default.post(
                name: .workoutCommandForwarded,
                object: command
            )
        }
    }
}

// MARK: - Additional Notification Names
extension Notification.Name {
    static let workoutCommandForwarded = Notification.Name("workoutCommandForwarded")
}
