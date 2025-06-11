//
//  UserModels.swift
//  ShuttlX MVP
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation

// MARK: - User Profile for MVP

struct UserProfile: Codable {
    var id: UUID = UUID()
    var name: String = ""
    var email: String = ""
    var age: Int?
    var height: Double? // in centimeters
    var weight: Double? // in kilograms  
    var fitnessLevel: FitnessLevel = .beginner
    var goals: Set<FitnessGoal> = []
    var joinDate: Date = Date()
    var restingHeartRate: Int?
    var estimatedVO2Max: Double?
    
    static let `default` = UserProfile()
}

// Fitness levels for user onboarding
enum FitnessLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case sedentary = "sedentary"
    case lightlyActive = "lightly_active"
    case moderatelyActive = "moderately_active"
    case veryActive = "very_active"
    case extraActive = "extra_active"
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        case .extraActive: return "Extra Active"
        }
    }
    
    var description: String {
        switch self {
        case .beginner: return "Just starting your fitness journey"
        case .sedentary: return "Little to no exercise"
        case .lightlyActive: return "Light exercise 1-3 days/week"
        case .moderatelyActive: return "Moderate exercise 3-5 days/week"
        case .veryActive: return "Heavy exercise 6-7 days/week"
        case .extraActive: return "Very heavy exercise, physical job"
        }
    }
}

// Fitness goals for user motivation
enum FitnessGoal: String, CaseIterable, Codable {
    case weightLoss = "weight_loss"
    case endurance = "endurance"
    case strength = "strength"
    case generalHealth = "general_health"
    case stressRelief = "stress_relief"
    case strengthBuilding = "strength_building"
    case enduranceImprovement = "endurance_improvement"
    case flexibilityMobility = "flexibility_mobility"
    case generalFitness = "general_fitness"
    
    var displayName: String {
        switch self {
        case .weightLoss: return "Weight Loss"
        case .endurance: return "Build Endurance"
        case .strength: return "Build Strength"
        case .generalHealth: return "General Health"
        case .stressRelief: return "Stress Relief"
        case .strengthBuilding: return "Strength Building"
        case .enduranceImprovement: return "Endurance Improvement"
        case .flexibilityMobility: return "Flexibility & Mobility"
        case .generalFitness: return "General Fitness"
        }
    }
    
    var icon: String {
        switch self {
        case .weightLoss: return "figure.walk"
        case .endurance: return "figure.run"
        case .strength: return "dumbbell.fill"
        case .generalHealth: return "heart.fill"
        case .stressRelief: return "leaf.fill"
        case .strengthBuilding: return "dumbbell"
        case .enduranceImprovement: return "figure.run.circle"
        case .flexibilityMobility: return "figure.flexibility"
        case .generalFitness: return "figure.mixed.cardio"
        }
    }
}

// User preferences for app behavior
struct UserPreferences: Codable {
    var units: UnitSystem = .metric
    var notifications: Bool = true
    var privacy: PrivacyLevel = .standard
    
    static let `default` = UserPreferences()
}

enum UnitSystem: String, Codable {
    case metric = "metric"
    case imperial = "imperial"
}

enum PrivacyLevel: String, Codable {
    case minimal = "minimal"
    case standard = "standard"
    case maximum = "maximum"
}

// Workout command for user interactions
struct WorkoutCommand: Codable {
    let action: WorkoutAction
    var timestamp: Date = Date()
}

enum WorkoutAction: String, Codable {
    case start = "start"
    case pause = "pause"
    case resume = "resume"
    case stop = "stop"
    case skip = "skip"
}