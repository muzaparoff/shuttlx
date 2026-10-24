import Foundation

// MARK: - Heart-Rate Recovery Capture (one rest period in a gym recovery session)

public struct HRRCapture: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var setNumber: Int
    public var peakHR: Int            // highest HR recorded during the preceding work set
    public var hrAt60s: Int?          // HR at +60s after rest entry (used to compute HRR-1)
    public var hrAt120s: Int?         // HR at +120s after rest entry (used to compute HRR-2)
    public var restDuration: TimeInterval
    public var restEntryTime: Date

    /// HRR-1: drop from peak to HR at 1 minute into rest. Higher = better fitness.
    public var hrr1: Int? { hrAt60s.map { max(0, peakHR - $0) } }
    /// HRR-2: drop from peak to HR at 2 minutes into rest.
    public var hrr2: Int? { hrAt120s.map { max(0, peakHR - $0) } }

    public init(setNumber: Int, peakHR: Int, restEntryTime: Date) {
        self.id = UUID()
        self.setNumber = setNumber
        self.peakHR = peakHR
        self.restEntryTime = restEntryTime
        self.restDuration = 0
    }
}

// MARK: - Recovery Report (attached to a completed gym recovery session)

public struct RecoveryReport: Codable, Hashable, Sendable {
    public var sets: Int
    public var captures: [HRRCapture]
    public var avgWorkHR: Double?
    public var avgRestHR: Double?

    public init(sets: Int, captures: [HRRCapture], avgWorkHR: Double? = nil, avgRestHR: Double? = nil) {
        self.sets = sets
        self.captures = captures
        self.avgWorkHR = avgWorkHR
        self.avgRestHR = avgRestHR
    }

    public var averageHRR1: Double? {
        let values = captures.compactMap { $0.hrr1 }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    public var averageHRR2: Double? {
        let values = captures.compactMap { $0.hrr2 }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

// MARK: - Training Session

public struct TrainingSession: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var startDate: Date
    public var endDate: Date?
    public var duration: TimeInterval
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?
    public var caloriesBurned: Double?
    public var distance: Double?
    public var totalSteps: Int?
    public var segments: [ActivitySegment]
    /// The route when it travels inside this value (WatchConnectivity, CloudKit, inbox, checkpoints, the
    /// watch store). JSON key stays "route". On the iPhone, stored sessions will drop it once routes live
    /// in `routes/<id>.json` (plan 2026-10 part B); read stored routes through DataManager, not this.
    public var inlineRoute: [RoutePoint]?
    public var kmSplits: [KmSplitData]?

    // Interval workout fields
    public var templateID: UUID?
    public var completedIntervalResults: [CompletedInterval]?

    // CloudKit sync
    public var modifiedDate: Date?

    // Multi-sport & training plan
    public var sportType: WorkoutSport?
    public var planID: UUID?
    public var planDayIndex: Int?

    // Exercise device & calorie estimation
    public var deviceID: UUID?
    public var deviceName: String?
    public var estimatedCalories: Double?

    // Cadence (steps per minute); paused time excluded from average. Nil for legacy sessions.
    public var averageCadence: Double?
    public var maxCadence: Int?

    // Gym heart-recovery monitoring
    public var sessionMode: SessionMode?
    public var recoveryReport: RecoveryReport?

    // True when the watch ended the workout because the long-workout safety
    // prompt went unanswered. Nil for every user-ended and legacy session.
    public var autoEnded: Bool?

    // Post-workout effort 0-10 (watch summary prompt). Nil = skipped / legacy.
    // App-only: never written to Health metadata.
    public var effortRPE: Int?

    // Highest heart rate read while the workout was paused. Kept apart from
    // maxHeartRate (which, like the average, counts active time only). Nil = legacy.
    public var pausedPeakHeartRate: Double?

    // True when the iPhone built this session from an Apple Health workout
    // (it never arrived over WatchConnectivity). Nil for everything else.
    public var importedFromHealth: Bool?

    // Point count, start point and elevation of the route (plan 2026-10 part B). Nil = legacy or not computed
    // yet; nil is not encoded, so the JSON of a session without it is unchanged.
    public var routeSummary: RouteSummary?

    // Legacy fields for backward compatibility with old data
    public var programID: UUID?
    public var programName: String?
    public var completedIntervals: [LegacyCompletedInterval]?

    // Every stored property, by its JSON key (pinned by ModelWireCompatibilityTests). A new property must be
    // added here too, or it is silently not stored.
    private enum CodingKeys: String, CodingKey {
        case id
        case startDate
        case endDate
        case duration
        case averageHeartRate
        case maxHeartRate
        case caloriesBurned
        case distance
        case totalSteps
        case segments
        case inlineRoute = "route"
        case kmSplits
        case templateID
        case completedIntervalResults
        case modifiedDate
        case sportType
        case planID
        case planDayIndex
        case deviceID
        case deviceName
        case estimatedCalories
        case averageCadence
        case maxCadence
        case sessionMode
        case recoveryReport
        case autoEnded
        case effortRPE
        case pausedPeakHeartRate
        case importedFromHealth
        case routeSummary
        case programID
        case programName
        case completedIntervals
    }

    public var displayName: String {
        sessionDisplayName(programName: programName, sessionMode: sessionMode, sportType: sportType)
    }

    public var totalRunningDuration: TimeInterval {
        segments.filter { $0.activityType == .running }.reduce(0) { $0 + $1.duration }
    }

    public var totalWalkingDuration: TimeInterval {
        segments.filter { $0.activityType == .walking }.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Per-phase calorie rollups (Phase 2, 2026-08 run+walk plan)
    // Computed, not stored: the numbers live on the segments, so old sessions
    // (and any session recorded without a body mass) simply return nil.

    private func segmentCalories(_ activity: DetectedActivity,
                                 _ pick: (ActivitySegment) -> Double?) -> Double? {
        let values = segments.filter { $0.activityType == activity }.compactMap(pick)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    /// ShuttlX's MET estimate for the run phases.
    public var totalRunningCalories: Double? { segmentCalories(.running) { $0.estimatedCalories } }
    /// ShuttlX's MET estimate for the walk phases.
    public var totalWalkingCalories: Double? { segmentCalories(.walking) { $0.estimatedCalories } }
    /// Apple's `activeEnergyBurned` attributed to the run phases.
    public var totalRunningActiveEnergy: Double? { segmentCalories(.running) { $0.activeEnergyCalories } }
    /// Apple's `activeEnergyBurned` attributed to the walk phases.
    public var totalWalkingActiveEnergy: Double? { segmentCalories(.walking) { $0.activeEnergyCalories } }

    public init(
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
        inlineRoute: [RoutePoint]? = nil,
        kmSplits: [KmSplitData]? = nil,
        averageCadence: Double? = nil,
        maxCadence: Int? = nil
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
        self.inlineRoute = inlineRoute
        self.kmSplits = kmSplits
        self.averageCadence = averageCadence
        self.maxCadence = maxCadence
        self.templateID = nil
        self.completedIntervalResults = nil
        self.programID = nil
        self.programName = nil
        self.completedIntervals = nil
    }

    // Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(startDate)
    }

    // Identity plus the fields "Fix a part" can change. SwiftUI skips re-rendering a view whose Equatable
    // input compares equal, so an id-only `==` froze every card after an edit. Hash stays id+start (still consistent).
    public static func == (lhs: TrainingSession, rhs: TrainingSession) -> Bool {
        lhs.id == rhs.id && lhs.startDate == rhs.startDate
            && lhs.segments == rhs.segments && lhs.caloriesBurned == rhs.caloriesBurned
    }
}

// Keep for backward compatibility with old session data
public struct LegacyCompletedInterval: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var intervalID: UUID
    public var actualDuration: TimeInterval
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?

    public init(intervalID: UUID, actualDuration: TimeInterval, averageHeartRate: Double? = nil, maxHeartRate: Double? = nil) {
        self.id = UUID()
        self.intervalID = intervalID
        self.actualDuration = actualDuration
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
    }
}

// Per-interval result from an interval workout
public struct CompletedInterval: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var intervalType: IntervalType
    public var label: String?
    public var targetDuration: TimeInterval
    public var actualDuration: TimeInterval
    public var averageHeartRate: Double?
    public var distance: Double?

    public init(
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

public struct KmSplitData: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let kmNumber: Int
    public let splitTime: TimeInterval
    public let cumulativeTime: TimeInterval

    public init(kmNumber: Int, splitTime: TimeInterval, cumulativeTime: TimeInterval) {
        self.id = UUID()
        self.kmNumber = kmNumber
        self.splitTime = splitTime
        self.cumulativeTime = cumulativeTime
    }
}
