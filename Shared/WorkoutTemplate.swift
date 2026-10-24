import Foundation
// MARK: - Interval Step

public struct IntervalStep: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var type: IntervalType
    public var duration: TimeInterval
    public var label: String?

    public init(id: UUID = UUID(), type: IntervalType, duration: TimeInterval, label: String? = nil) {
        self.id = id
        self.type = type
        self.duration = duration
        self.label = label
    }
}

// MARK: - Workout Template

public struct WorkoutTemplate: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var intervals: [IntervalStep]
    public var repeatCount: Int
    public var warmup: IntervalStep?
    public var cooldown: IntervalStep?
    public var createdDate: Date
    public var modifiedDate: Date?
    public var sportType: WorkoutSport?
    public var deviceID: UUID?
    public var deviceName: String?

    public init(
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
    public var allSteps: [IntervalStep] {
        var steps: [IntervalStep] = []
        if let w = warmup { steps.append(w) }
        for _ in 0..<repeatCount {
            steps.append(contentsOf: intervals)
        }
        if let c = cooldown { steps.append(c) }
        return steps
    }

    /// Total workout duration in seconds
    public var totalDuration: TimeInterval {
        allSteps.reduce(0) { $0 + $1.duration }
    }

    /// Summary text like "8× Work/Rest · 12m"
    public var summaryText: String {
        let minutes = Int(totalDuration) / 60
        let workCount = intervals.filter { $0.type == .work }.count * repeatCount
        if workCount > 0 {
            return "\(workCount)× · \(minutes)m total"
        }
        return "\(minutes)m total"
    }
}
