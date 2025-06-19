//
//  TrainingModels.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import SwiftUI

// MARK: - Training Program Models

struct TrainingProgram: Identifiable, Codable {
    let id = UUID()
    var name: String
    var distance: Double // in kilometers
    var runInterval: Double // in minutes
    var walkInterval: Double // in minutes
    var difficulty: TrainingDifficulty
    var description: String
    var estimatedCalories: Int
    var targetHeartRateZone: HeartRateZone
    var createdDate: Date
    var isCustom: Bool
    
    // REMOVED: totalDuration - now calculated automatically
    
    init(
        name: String,
        distance: Double,
        runInterval: Double,
        walkInterval: Double,
        difficulty: TrainingDifficulty,
        description: String = "",
        estimatedCalories: Int = 0,
        targetHeartRateZone: HeartRateZone = .moderate,
        isCustom: Bool = false
    ) {
        self.name = name
        self.distance = distance
        self.runInterval = runInterval
        self.walkInterval = walkInterval
        self.difficulty = difficulty
        self.description = description
        self.estimatedCalories = estimatedCalories
        self.targetHeartRateZone = targetHeartRateZone
        self.createdDate = Date()
        self.isCustom = isCustom
    }
    
    // CALCULATED: Total duration based on intervals only
    var totalDuration: Double {
        // Simple calculation: 10 cycles of run + walk intervals
        let cycleTime = runInterval + walkInterval
        return cycleTime * 10 // 10 cycles as default
    }
    
    var formattedDistance: String {
        String(format: "%.1f km", distance)
    }
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 60
        let minutes = Int(totalDuration) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    var intervalPattern: String {
        "Run \(Int(runInterval))m • Walk \(Int(walkInterval))m"
    }
}

enum TrainingDifficulty: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced: return "bolt.fill"
        }
    }
}

enum HeartRateZone: String, CaseIterable, Codable {
    case recovery = "recovery"
    case easy = "easy"
    case moderate = "moderate"
    case hard = "hard"
    case maximum = "maximum"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .recovery: return .blue
        case .easy: return .green
        case .moderate: return .yellow
        case .hard: return .orange
        case .maximum: return .red
        }
    }
    
    var percentage: String {
        switch self {
        case .recovery: return "50-60%"
        case .easy: return "60-70%"
        case .moderate: return "70-80%"
        case .hard: return "80-90%"
        case .maximum: return "90-100%"
        }
    }
}

enum WorkoutPhase: String, CaseIterable {
    case running = "running"
    case walking = "walking"
    case rest = "rest"
    
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .rest: return "Rest"
        }
    }
    
    var color: Color {
        switch self {
        case .running: return .red
        case .walking: return .blue
        case .rest: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .rest: return "pause.fill"
        }
    }
}

// MARK: - Predefined Training Programs

extension TrainingProgram {
    static let defaultPrograms: [TrainingProgram] = [
        TrainingProgram(
            name: "Beginner 5K Builder",
            distance: 5.0,
            runInterval: 1.0,
            walkInterval: 2.0,
            difficulty: .beginner,
            description: "Perfect for starting your running journey. Gentle intervals to build endurance.",
            estimatedCalories: 250,
            targetHeartRateZone: .easy
        ),
        
        TrainingProgram(
            name: "HIIT Power Blast",
            distance: 3.0,
            runInterval: 1.0,
            walkInterval: 1.0,
            difficulty: .intermediate,
            description: "High-intensity interval training for maximum calorie burn and fitness gains.",
            estimatedCalories: 300,
            targetHeartRateZone: .hard
        ),
        
        TrainingProgram(
            name: "Endurance Challenge",
            distance: 10.0,
            runInterval: 3.0,
            walkInterval: 1.0,
            difficulty: .advanced,
            description: "Build serious endurance with longer running intervals and minimal rest.",
            estimatedCalories: 500,
            targetHeartRateZone: .moderate
        ),
        
        TrainingProgram(
            name: "Recovery Run",
            distance: 3.0,
            runInterval: 2.0,
            walkInterval: 2.0,
            difficulty: .beginner,
            description: "Light recovery session to maintain fitness while allowing muscle recovery.",
            estimatedCalories: 200,
            targetHeartRateZone: .recovery
        ),
        
        TrainingProgram(
            name: "Sprint Intervals",
            distance: 2.0,
            runInterval: 0.5,
            walkInterval: 1.5,
            difficulty: .advanced,
            description: "Short, intense sprints to improve speed and anaerobic capacity.",
            estimatedCalories: 250,
            targetHeartRateZone: .maximum
        ),
        
        TrainingProgram(
            name: "Quick Test Workout",
            distance: 0.1,
            runInterval: 0.17, // 10 seconds
            walkInterval: 0.17, // 10 seconds  
            difficulty: .beginner,
            description: "Short test workout for integration testing and quick verification.",
            estimatedCalories: 10,
            targetHeartRateZone: .easy,
            isCustom: false
        )
    ]
}
