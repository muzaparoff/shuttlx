//
//  CalorieCalculationService.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation

class CalorieCalculationService {
    static let shared = CalorieCalculationService()
    
    private init() {}
    
    // MARK: - Main Calorie Calculation
    
    func calculateCalories(for program: TrainingProgram, userProfile: UserProfile?) -> Int {
        guard let userProfile = userProfile,
              let weight = userProfile.weight,
              let age = userProfile.age else {
            // Fallback to basic calculation if no user data
            return calculateBasicCalories(for: program)
        }
        
        // Use more accurate calculation with user data
        return calculatePersonalizedCalories(
            for: program,
            weight: weight,
            age: age,
            fitnessLevel: userProfile.fitnessLevel
        )
    }
    
    // MARK: - Personalized Calculation
    
    private func calculatePersonalizedCalories(
        for program: TrainingProgram,
        weight: Double,
        age: Int,
        fitnessLevel: FitnessLevel
    ) -> Int {
        // Calculate total active time (running intervals only)
        let totalCycles = Int(program.totalDuration / (program.runInterval + program.walkInterval))
        let totalRunTime = Double(totalCycles) * program.runInterval // in minutes
        
        // MET values based on activity intensity
        let runningMET = getRunningMET(for: program.difficulty)
        let walkingMET = 3.5 // Standard walking MET
        
        // Calculate calories for running intervals
        let runningCalories = calculateMETCalories(
            met: runningMET,
            weightKg: weight,
            durationMinutes: totalRunTime
        )
        
        // Calculate calories for walking intervals  
        let totalWalkTime = Double(totalCycles) * program.walkInterval
        let walkingCalories = calculateMETCalories(
            met: walkingMET,
            weightKg: weight,
            durationMinutes: totalWalkTime
        )
        
        let totalCalories = runningCalories + walkingCalories
        
        // Apply fitness level adjustment
        let fitnessAdjustment = getFitnessLevelMultiplier(fitnessLevel)
        let adjustedCalories = totalCalories * fitnessAdjustment
        
        // Apply age adjustment (metabolism slows with age)
        let ageAdjustment = getAgeAdjustment(age)
        
        return Int(adjustedCalories * ageAdjustment)
    }
    
    // MARK: - MET-based Calculation
    
    private func calculateMETCalories(met: Double, weightKg: Double, durationMinutes: Double) -> Double {
        // Calorie formula: METs × weight (kg) × time (hours)
        let durationHours = durationMinutes / 60.0
        return met * weightKg * durationHours
    }
    
    private func getRunningMET(for difficulty: TrainingDifficulty) -> Double {
        switch difficulty {
        case .beginner:
            return 6.0 // Light jogging
        case .intermediate:
            return 8.3 // Moderate running
        case .advanced:
            return 11.0 // Fast running
        case .expert:
            return 14.0 // Very fast running
        }
    }
    
    // MARK: - Adjustment Factors
    
    private func getFitnessLevelMultiplier(_ fitnessLevel: FitnessLevel) -> Double {
        switch fitnessLevel {
        case .beginner, .sedentary:
            return 1.1 // Beginners burn more calories due to inefficiency
        case .lightlyActive:
            return 1.05
        case .moderatelyActive:
            return 1.0 // Baseline
        case .veryActive:
            return 0.95 // More efficient metabolism
        case .extraActive:
            return 0.9 // Very efficient metabolism
        }
    }
    
    private func getAgeAdjustment(_ age: Int) -> Double {
        switch age {
        case 18...25:
            return 1.05 // Higher metabolism
        case 26...35:
            return 1.0 // Baseline
        case 36...45:
            return 0.95
        case 46...55:
            return 0.9
        case 56...65:
            return 0.85
        default:
            return 0.8 // 65+
        }
    }
    
    // MARK: - Fallback Calculation
    
    private func calculateBasicCalories(for program: TrainingProgram) -> Int {
        // Fallback calculation when user data is not available
        let baseCaloriesPerKm = 60.0
        let difficultyMultiplier = program.difficulty.calorieMultiplier
        return Int(program.distance * baseCaloriesPerKm * difficultyMultiplier)
    }
    
    // MARK: - Real-time Workout Calculation
    
    func getTrainingDifficultyMultiplier(_ difficulty: TrainingDifficulty) -> Double {
        return difficulty.calorieMultiplier
    }
    
    func calculateWorkoutCalories(
        elapsedTime: TimeInterval,
        averageHeartRate: Double?,
        userProfile: UserProfile?
    ) -> Double {
        guard let userProfile = userProfile,
              let weight = userProfile.weight,
              let age = userProfile.age else {
            // Fallback calculation
            return (elapsedTime / 60.0) * 8.0 // 8 calories per minute average
        }
        
        // Heart rate-based calculation if available
        if let heartRate = averageHeartRate {
            return calculateHeartRateBasedCalories(
                heartRate: heartRate,
                elapsedTime: elapsedTime,
                weight: weight,
                age: age
            )
        }
        
        // Time-based calculation with user profile
        let met = 8.5 // Average interval training MET
        let durationHours = elapsedTime / 3600.0
        return met * weight * durationHours
    }
    
    private func calculateHeartRateBasedCalories(
        heartRate: Double,
        elapsedTime: TimeInterval,
        weight: Double,
        age: Int
    ) -> Double {
        // Simplified heart rate-based formula
        let maxHeartRate = 220.0 - Double(age)
        let heartRateReserve = heartRate - 60.0 // Assuming 60 bpm resting HR
        let intensity = heartRateReserve / (maxHeartRate - 60.0)
        
        let baseCaloriesPerMinute = (weight * 0.75) / 60.0
        let intensityMultiplier = 1.0 + (intensity * 2.0)
        
        return baseCaloriesPerMinute * intensityMultiplier * (elapsedTime / 60.0)
    }
}

// MARK: - Extensions

extension TrainingDifficulty {
    var calorieMultiplier: Double {
        switch self {
        case .beginner: return 0.8
        case .intermediate: return 1.0
        case .advanced: return 1.3
        case .expert: return 1.5
        }
    }
}
