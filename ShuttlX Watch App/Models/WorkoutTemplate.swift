import Foundation

// MARK: - Interval Types

enum IntervalType: String, Codable, CaseIterable {
    case warmup
    case work
    case rest
    case cooldown

    var displayName: String {
        switch self {
        case .warmup: return "Warm Up"
        case .work: return "Work"
        case .rest: return "Rest"
        case .cooldown: return "Cool Down"
        }
    }
}

// MARK: - Interval Step

struct IntervalStep: Identifiable, Codable, Hashable {
    let id: UUID
    var type: IntervalType
    var duration: TimeInterval
    var label: String?

    init(id: UUID = UUID(), type: IntervalType, duration: TimeInterval, label: String? = nil) {
        self.id = id
        self.type = type
        self.duration = duration
        self.label = label
    }
}

// MARK: - Workout Template

struct WorkoutTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var intervals: [IntervalStep]
    var repeatCount: Int
    var warmup: IntervalStep?
    var cooldown: IntervalStep?
    var createdDate: Date
    var modifiedDate: Date?
    var sportType: WorkoutSport?
    var deviceID: UUID?
    var deviceName: String?

    init(
        id: UUID = UUID(),
        name: String,
        intervals: [IntervalStep],
        repeatCount: Int = 1,
        warmup: IntervalStep? = nil,
        cooldown: IntervalStep? = nil,
        createdDate: Date = Date(),
        sportType: WorkoutSport? = nil
    ) {
        self.id = id
        self.name = name
        self.intervals = intervals
        self.repeatCount = repeatCount
        self.warmup = warmup
        self.cooldown = cooldown
        self.createdDate = createdDate
        self.sportType = sportType
    }

    /// Flattened list of all steps in execution order
    var allSteps: [IntervalStep] {
        var steps: [IntervalStep] = []
        if let w = warmup { steps.append(w) }
        for _ in 0..<repeatCount {
            steps.append(contentsOf: intervals)
        }
        if let c = cooldown { steps.append(c) }
        return steps
    }

    /// Total workout duration in seconds
    var totalDuration: TimeInterval {
        allSteps.reduce(0) { $0 + $1.duration }
    }

    /// Summary text like "8× Work/Rest · 12m"
    var summaryText: String {
        let minutes = Int(totalDuration) / 60
        let workCount = intervals.filter { $0.type == .work }.count * repeatCount
        if workCount > 0 {
            return "\(workCount)× · \(minutes)m total"
        }
        return "\(minutes)m total"
    }
}
