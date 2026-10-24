import Foundation

/// The few `TrainingSession` fields the widgets show. Decoding it from `sessions.json` skips every other
/// key (the route, splits, interval results), so a widget timeline build does not materialize them.
/// Decode with `LenientJSON.decodeArray` so one bad record does not empty the widget.
public struct SessionHeadline: Identifiable, Decodable, Sendable {
    public let id: UUID
    public var startDate: Date
    public var duration: TimeInterval
    public var averageHeartRate: Double?
    public var caloriesBurned: Double?
    public var distance: Double?
    public var sportType: WorkoutSport?
    public var programName: String?
    public var sessionMode: SessionMode?
    /// For "Fix a part" (`SegmentEdits.effective`).
    public var segments: [ActivitySegment]

    public var displayName: String {
        sessionDisplayName(programName: programName, sessionMode: sessionMode, sportType: sportType)
    }
}

/// One rule for `TrainingSession.displayName` and `SessionHeadline.displayName`.
func sessionDisplayName(programName: String?, sessionMode: SessionMode?, sportType: WorkoutSport?) -> String {
    if let name = programName { return name }
    if sessionMode == .gymRecovery { return "Gym Recovery" }
    return sportType?.displayName ?? "Run+Walk"
}
