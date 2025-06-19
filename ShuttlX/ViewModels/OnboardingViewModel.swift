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
    @Published var isCreatingProfile: Bool = false
    @Published var profileCreationError: String?
    
    private let userProfileService = UserProfileService.shared
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
        isCreatingProfile = true
        profileCreationError = nil
        
        // Create user profile with collected information
        var userProfile = UserProfile()
        userProfile.name = "\(firstName) \(lastName)"
        userProfile.email = email
        userProfile.age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 25
        userProfile.height = height * 100 // Convert meters to centimeters
        userProfile.weight = weight
        userProfile.fitnessLevel = fitnessLevel
        userProfile.goals = selectedGoals
        
        // Add assessment results if available
        if let assessment = assessmentResults {
            userProfile.restingHeartRate = Int(assessment.restingHeartRate)
            userProfile.estimatedVO2Max = assessment.estimatedVO2Max
        }
        
        // Save the profile using UserProfileService
        userProfileService.saveProfile(userProfile)
        
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        print("User profile created successfully: \(userProfile.name)")
        
        isCreatingProfile = false
    }
    
    func skipAssessment() {
        hasCompletedAssessment = false
        assessmentResults = nil
    }
    
    func completeAssessment() {
        hasCompletedAssessment = true
        assessmentResults = generateMockAssessmentResults()
        
        // Update profile with assessment data if user already created profile
        Task {
            await updateProfileWithAssessment()
        }
    }
    
    // MARK: - Private Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func createDefaultPreferences() -> UserPreferences {
        return UserPreferences()
    }
    
    func updateProfileWithAssessment() async {
        guard let assessment = assessmentResults else { return }
        
        do {
            var currentProfile = try await userProfileService.getCurrentProfile()
            currentProfile.restingHeartRate = Int(assessment.restingHeartRate)
            currentProfile.estimatedVO2Max = assessment.estimatedVO2Max
            currentProfile.fitnessLevel = assessment.recommendedStartingLevel
            
            userProfileService.saveProfile(currentProfile)
            print("Profile updated with assessment results")
        } catch {
            print("Error updating profile with assessment: \(error)")
        }
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
        let _ = (75 - restingHeartRate) / 5 // Adjust based on resting HR
        
        return max(18, min(65, baseAge - Int(vo2Factor)))
    }
}
