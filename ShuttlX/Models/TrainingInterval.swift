import Foundation

struct TrainingInterval: Identifiable, Codable {
    let id: UUID
    var phase: IntervalPhase
    var duration: TimeInterval // in seconds
    var intensity: TrainingIntensity
    
    init(phase: IntervalPhase, duration: TimeInterval, intensity: TrainingIntensity) {
        self.id = UUID()
        self.phase = phase
        self.duration = duration
        self.intensity = intensity
    }
}

enum IntervalPhase: String, CaseIterable, Codable {
    case work = "Work"
    case rest = "Rest"
    
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .rest: return "Rest"
        }
    }
    
    var systemImage: String {
        switch self {
        case .work: return "bolt.fill"
        case .rest: return "pause.circle.fill"
        }
    }
}

enum TrainingIntensity: String, CaseIterable, Codable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    
    var description: String {
        switch self {
        case .low: return "Easy pace, conversational"
        case .moderate: return "Moderate effort, slightly breathless"
        case .high: return "High intensity, maximum effort"
        }
    }
    
    var heartRateZone: String {
        switch self {
        case .low: return "Zone 1-2 (60-70% max HR)"
        case .moderate: return "Zone 3-4 (70-85% max HR)"
        case .high: return "Zone 4-5 (85-95% max HR)"
        }
    }
}
