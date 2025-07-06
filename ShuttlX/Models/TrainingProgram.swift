import Foundation
import CloudKit

struct TrainingProgram: Identifiable, Codable {
    let id = UUID()
    var name: String
    var type: ProgramType
    var intervals: [TrainingInterval]
    var maxPulse: Int
    var createdDate: Date
    var lastModified: Date
    
    // CloudKit integration (excluded from Codable)
    var recordID: CKRecord.ID?
    
    // Custom Codable implementation to exclude recordID
    enum CodingKeys: String, CodingKey {
        case id, name, type, intervals, maxPulse, createdDate, lastModified
    }
    
    // Computed properties
    var totalDuration: TimeInterval {
        intervals.reduce(0) { $0 + $1.duration }
    }
    
    var workIntervals: [TrainingInterval] {
        intervals.filter { $0.phase == .work }
    }
    
    var restIntervals: [TrainingInterval] {
        intervals.filter { $0.phase == .rest }
    }
}

enum ProgramType: String, CaseIterable, Codable {
    case walkRun = "walkRun"
    case hiit = "hiit" // Future expansion
    case tabata = "tabata" // Future expansion
    case custom = "custom" // Future expansion
    
    var displayName: String {
        switch self {
        case .walkRun: 
            return "Walk-Run"
        case .hiit: 
            return "HIIT"
        case .tabata: 
            return "Tabata"
        case .custom: 
            return "Custom"
        }
    }
    
    var description: String {
        switch self {
        case .walkRun: 
            return "Alternating walking and running intervals for endurance building"
        case .hiit: 
            return "High-Intensity Interval Training for maximum calorie burn"
        case .tabata: 
            return "20 seconds work, 10 seconds rest protocol"
        case .custom: 
            return "Fully customizable interval training"
        }
    }
    
    var defaultIntervals: [TrainingInterval] {
        switch self {
        case .walkRun:
            return [
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),   // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),   // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),   // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)    // 5min cooldown walk
            ]
        case .hiit:
            return [] // Future implementation
        case .tabata:
            return [] // Future implementation
        case .custom:
            return []
        }
    }
    
    var workPhaseLabel: String {
        switch self {
        case .walkRun: return "Run"
        case .hiit: return "High Intensity"
        case .tabata: return "Work"
        case .custom: return "Work"
        }
    }
    
    var restPhaseLabel: String {
        switch self {
        case .walkRun: return "Walk"
        case .hiit: return "Rest"
        case .tabata: return "Rest"
        case .custom: return "Rest"
        }
    }
}
