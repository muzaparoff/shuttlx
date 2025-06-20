import Foundation

struct TrainingInterval: Identifiable, Codable {
    let id: UUID
    var type: IntervalType
    var duration: TimeInterval // in seconds
    var targetPace: TrainingPace?
    
    init(type: IntervalType, duration: TimeInterval, targetPace: TrainingPace? = nil) {
        self.id = UUID()
        self.type = type
        self.duration = duration
        self.targetPace = targetPace
    }
    
    // Computed properties for convenience
    var durationMinutes: Int {
        Int(duration / 60)
    }
    
    var durationSeconds: Int {
        Int(duration.truncatingRemainder(dividingBy: 60))
    }
    
    var formattedDuration: String {
        let minutes = durationMinutes
        let seconds = durationSeconds
        
        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
    
    var displayName: String {
        return "\(type.rawValue) - \(formattedDuration)"
    }
}

enum IntervalType: String, CaseIterable, Codable {
    case walk = "Walk"
    case run = "Run"
    case rest = "Rest"
    
    var systemImageName: String {
        switch self {
        case .walk:
            return "figure.walk"
        case .run:
            return "figure.run"
        case .rest:
            return "pause.circle"
        }
    }
    
    var color: String {
        switch self {
        case .walk:
            return "blue"
        case .run:
            return "red"
        case .rest:
            return "gray"
        }
    }
}

enum TrainingPace: String, CaseIterable, Codable {
    case easy = "Easy"
    case moderate = "Moderate"
    case intense = "Intense"
    
    var description: String {
        switch self {
        case .easy:
            return "Comfortable, conversational pace"
        case .moderate:
            return "Somewhat hard, focused effort"
        case .intense:
            return "Hard, maximum sustainable effort"
        }
    }
    
    var heartRateZone: String {
        switch self {
        case .easy:
            return "Zone 1-2 (60-70% max HR)"
        case .moderate:
            return "Zone 3-4 (70-85% max HR)"
        case .intense:
            return "Zone 4-5 (85-95% max HR)"
        }
    }
}

// MARK: - Helper Extensions
extension Array where Element == TrainingInterval {
    var totalDuration: TimeInterval {
        reduce(0) { $0 + $1.duration }
    }
    
    var walkDuration: TimeInterval {
        filter { $0.type == .walk }.reduce(0) { $0 + $1.duration }
    }
    
    var runDuration: TimeInterval {
        filter { $0.type == .run }.reduce(0) { $0 + $1.duration }
    }
    
    var restDuration: TimeInterval {
        filter { $0.type == .rest }.reduce(0) { $0 + $1.duration }
    }
}
