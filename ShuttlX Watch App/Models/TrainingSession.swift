import Foundation

struct TrainingSession: Identifiable, Codable, Hashable {
    let id: UUID
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var caloriesBurned: Double?
    var distance: Double?
    var totalSteps: Int?
    var segments: [ActivitySegment]
    var route: [RoutePoint]?
    var kmSplits: [KmSplitData]?

    // Interval workout fields
    var templateID: UUID?
    var completedIntervalResults: [CompletedInterval]?

    // CloudKit sync
    var modifiedDate: Date?

    // Legacy fields for backward compatibility with old data
    var programID: UUID?
    var programName: String?
    var completedIntervals: [LegacyCompletedInterval]?

    var displayName: String {
        programName ?? "Run+Walk"
    }

    var totalRunningDuration: TimeInterval {
        segments.filter { $0.activityType == .running }.reduce(0) { $0 + $1.duration }
    }

    var totalWalkingDuration: TimeInterval {
        segments.filter { $0.activityType == .walking }.reduce(0) { $0 + $1.duration }
    }

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        duration: TimeInterval,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        caloriesBurned: Double? = nil,
        distance: Double? = nil,
        totalSteps: Int? = nil,
        segments: [ActivitySegment] = [],
        route: [RoutePoint]? = nil,
        kmSplits: [KmSplitData]? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.caloriesBurned = caloriesBurned
        self.distance = distance
        self.totalSteps = totalSteps
        self.segments = segments
        self.route = route
        self.kmSplits = kmSplits
        self.templateID = nil
        self.completedIntervalResults = nil
        self.programID = nil
        self.programName = nil
        self.completedIntervals = nil
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(startDate)
    }

    static func == (lhs: TrainingSession, rhs: TrainingSession) -> Bool {
        lhs.id == rhs.id && lhs.startDate == rhs.startDate
    }
}

// Keep for backward compatibility with old session data
struct LegacyCompletedInterval: Identifiable, Codable, Hashable {
    let id: UUID
    var intervalID: UUID
    var actualDuration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?

    init(intervalID: UUID, actualDuration: TimeInterval, averageHeartRate: Double? = nil, maxHeartRate: Double? = nil) {
        self.id = UUID()
        self.intervalID = intervalID
        self.actualDuration = actualDuration
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
    }
}

// Per-interval result from an interval workout
struct CompletedInterval: Identifiable, Codable, Hashable {
    let id: UUID
    var intervalType: IntervalType
    var label: String?
    var targetDuration: TimeInterval
    var actualDuration: TimeInterval
    var averageHeartRate: Double?
    var distance: Double?

    init(
        intervalType: IntervalType,
        label: String? = nil,
        targetDuration: TimeInterval,
        actualDuration: TimeInterval,
        averageHeartRate: Double? = nil,
        distance: Double? = nil
    ) {
        self.id = UUID()
        self.intervalType = intervalType
        self.label = label
        self.targetDuration = targetDuration
        self.actualDuration = actualDuration
        self.averageHeartRate = averageHeartRate
        self.distance = distance
    }
}

struct KmSplitData: Identifiable, Codable, Hashable {
    let id: UUID
    let kmNumber: Int
    let splitTime: TimeInterval
    let cumulativeTime: TimeInterval

    init(kmNumber: Int, splitTime: TimeInterval, cumulativeTime: TimeInterval) {
        self.id = UUID()
        self.kmNumber = kmNumber
        self.splitTime = splitTime
        self.cumulativeTime = cumulativeTime
    }
}
