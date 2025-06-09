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
    @Published var distance: Double = 5.0
    @Published var runInterval: Double = 2.0
    @Published var walkInterval: Double = 1.0
    @Published var difficulty: TrainingDifficulty = .moderate
    @Published var targetHeartRateZone: HeartRateZone = .moderate
    
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
        // Basic calorie estimation (can be improved with user weight, etc.)
        let baseCaloriesPerKm = 60
        let difficultyMultiplier = difficulty.calorieMultiplier
        return Int(distance * Double(baseCaloriesPerKm) * difficultyMultiplier)
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
        let program = buildProgram()
        trainingProgramManager.saveCustomProgram(program)
    }
}

// MARK: - Extensions for UI Support

extension TrainingDifficulty {
    var icon: String {
        switch self {
        case .easy: return "leaf.fill"
        case .moderate: return "flame.fill"
        case .hard: return "bolt.fill"
        case .extreme: return "hurricane"
        }
    }
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .moderate: return .orange
        case .hard: return .red
        case .extreme: return .purple
        }
    }
    
    var calorieMultiplier: Double {
        switch self {
        case .easy: return 0.8
        case .moderate: return 1.0
        case .hard: return 1.3
        case .extreme: return 1.6
        }
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
