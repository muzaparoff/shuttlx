//
//  TrainingProgramBuilderViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import SwiftUI

@MainActor
class TrainingProgramBuilderViewModel: ObservableObject {
    @Published var programName: String = ""
    @Published var description: String = ""
    @Published var distance: Double = 5.0 {
        didSet { updateEstimatedCalories() }
    }
    @Published var runInterval: Double = 2.0 {
        didSet { updateEstimatedCalories() }
    }
    @Published var walkInterval: Double = 1.0 {
        didSet { updateEstimatedCalories() }
    }
    @Published var difficulty: TrainingDifficulty = .intermediate {
        didSet { updateEstimatedCalories() }
    }
    @Published var targetHeartRateZone: HeartRateZone = .moderate {
        didSet { updateEstimatedCalories() }
    }
    
    private let trainingProgramManager = TrainingProgramManager.shared
    
    var estimatedDuration: Double {
        // Calculate based on intervals and distance
        let totalIntervalTime = runInterval + walkInterval
        let estimatedPace = 6.0 // minutes per km average
        let baseDuration = distance * estimatedPace
        
        // Adjust based on interval structure
        let intervalAdjustment = totalIntervalTime / 3.0
        return baseDuration + intervalAdjustment
    }
    
    var estimatedCalories: Int {
        // Get current user profile from UserDefaults or AppViewModel
        let userProfile = getCurrentUserProfile()
        return CalorieCalculationService.shared.calculateCalories(
            for: buildProgram(),
            userProfile: userProfile
        )
    }
    
    func updateEstimatedCalories() {
        // Force UI update when calories need to be recalculated
        objectWillChange.send()
    }
    
    private func getCurrentUserProfile() -> UserProfile? {
        guard let userData = UserDefaults.standard.data(forKey: "userProfile"),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: userData) else {
            return nil
        }
        return profile
    }
    
    var isFormValid: Bool {
        !programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        distance > 0 &&
        runInterval > 0 &&
        walkInterval > 0
    }
    
    func buildProgram() -> TrainingProgram {
        return TrainingProgram(
            name: programName.trimmingCharacters(in: .whitespacesAndNewlines),
            distance: distance,
            runInterval: runInterval,
            walkInterval: walkInterval,
            totalDuration: estimatedDuration,
            difficulty: difficulty,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedCalories: estimatedCalories,
            targetHeartRateZone: targetHeartRateZone,
            isCustom: true
        )
    }
    
    func saveProgram() {
        // Update calories one final time before saving
        updateEstimatedCalories()
        
        let program = buildProgram()
        trainingProgramManager.saveCustomProgram(program)
        
        print("✅ Saved custom training program: \(program.name) with \(program.estimatedCalories) estimated calories")
    }
}

// MARK: - Extensions for UI Support

extension TrainingDifficulty {
    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced: return "bolt.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
    
    var calorieMultiplier: Double {
        return CalorieCalculationService.shared.getTrainingDifficultyMultiplier(self)
    }
}

extension HeartRateZone {
    var color: Color {
        switch self {
        case .recovery: return .blue
        case .aerobic: return .green
        case .moderate: return .orange
        case .hard: return .red
        case .maximum: return .purple
        }
    }
    
    var description: String {
        switch self {
        case .recovery: return "50-60% HRmax"
        case .aerobic: return "60-70% HRmax"
        case .moderate: return "70-80% HRmax"
        case .hard: return "80-90% HRmax"
        case .maximum: return "90-100% HRmax"
        }
    }
}

extension TrainingDifficulty: CaseIterable {}
extension HeartRateZone: CaseIterable {}
