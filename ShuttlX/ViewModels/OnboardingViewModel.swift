//
//  OnboardingViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @Published var height: Double = 1.70 // meters
    @Published var weight: Double = 70.0 // kg
    @Published var fitnessLevel: FitnessLevel = .moderatelyActive
    @Published var selectedGoals: Set<FitnessGoal> = []
    @Published var hasCompletedAssessment: Bool = false
    @Published var assessmentResults: AssessmentResults?
    
    private var cancellables = Set<AnyCancellable>()
    
    func canProceedFromStep(_ step: Int) -> Bool {
        switch step {
        case 0: return true // Welcome step
        case 1: return !firstName.isEmpty && !lastName.isEmpty && isValidEmail(email)
        case 2: return height > 0 && weight > 0
        case 3: return !selectedGoals.isEmpty
        case 4: return true // Health permissions are optional
        case 5: return true // Fitness assessment is optional
        default: return false
        }
    }
    
    func canCompleteOnboarding() -> Bool {
        return canProceedFromStep(1) && canProceedFromStep(2) && canProceedFromStep(3)
    }
    
    func createUserProfile() async {
        // Create user profile with collected information
        let userProfile = UserProfile(
            firstName: firstName,
            lastName: lastName,
            email: email,
            dateOfBirth: dateOfBirth,
            height: height,
            weight: weight,
            fitnessLevel: fitnessLevel,
            goals: Array(selectedGoals),
            preferences: createDefaultPreferences(),
            achievements: [],
            createdAt: Date(),
            lastActiveAt: Date()
        )
        
        // In a real app, save this to Core Data or send to backend
        // For now, we'll just simulate the creation
        await simulateProfileCreation(userProfile)
    }
    
    func skipAssessment() {
        hasCompletedAssessment = false
        assessmentResults = nil
    }
    
    func completeAssessment() {
        hasCompletedAssessment = true
        assessmentResults = generateMockAssessmentResults()
    }
    
    // MARK: - Private Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func createDefaultPreferences() -> UserPreferences {
        return UserPreferences(
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
        )
    }
    
    private func simulateProfileCreation(_ profile: UserProfile) async {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // In a real app, this would:
        // 1. Save to Core Data
        // 2. Send to backend API
        // 3. Set up HealthKit integration
        // 4. Initialize user session
        
        print("User profile created: \(profile.fullName)")
    }
    
    private func generateMockAssessmentResults() -> AssessmentResults {
        return AssessmentResults(
            beepTestLevel: Double.random(in: 6.0...12.0),
            estimatedVO2Max: Double.random(in: 35.0...55.0),
            restingHeartRate: Double.random(in: 60.0...80.0),
            recoveryHeartRate: Double.random(in: 100.0...140.0),
            flexibilityScore: Double.random(in: 60.0...90.0),
            balanceScore: Double.random(in: 70.0...95.0),
            assessmentDate: Date(),
            recommendedStartingLevel: fitnessLevel
        )
    }
}

// MARK: - Assessment Results Model

struct AssessmentResults: Codable {
    let beepTestLevel: Double
    let estimatedVO2Max: Double
    let restingHeartRate: Double
    let recoveryHeartRate: Double
    let flexibilityScore: Double // 0-100
    let balanceScore: Double // 0-100
    let assessmentDate: Date
    let recommendedStartingLevel: FitnessLevel
    
    var fitnessAge: Int {
        // Calculate fitness age based on assessment results
        // This is a simplified calculation
        let baseAge = 25
        let vo2Factor = (estimatedVO2Max - 40) / 2 // Adjust based on VO2 max
        let heartRateFactor = (75 - restingHeartRate) / 5 // Adjust based on resting HR
        
        return max(18, min(65, baseAge - Int(vo2Factor) - Int(heartRateFactory)))
    }
    
    private var heartRateFactory: Double {
        return (75 - restingHeartRate) / 5
    }
}
