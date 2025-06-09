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
        var user = UserProfile()
        user.name = "John Doe"
        user.age = 28
        user.height = 178.0 // in centimeters
        user.weight = 75.0  // in kilograms
        user.fitnessLevel = .moderatelyActive
        user.goals = [.generalFitness, .enduranceImprovement]
        return user
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
            
            // For MVP, we'll use system appearance preference
            colorScheme = nil
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
        switch command.action {
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
    static let workoutCommandReceived = Notification.Name("workoutCommandReceived")
    static let workoutCommandForwarded = Notification.Name("workoutCommandForwarded")
}
