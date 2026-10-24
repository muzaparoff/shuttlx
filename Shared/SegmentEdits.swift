import Foundation

/// A user-defined part of a session ("Fix a part" Split / Merge). Times only; the metrics are
/// re-derived from the recorded segments by `SegmentEdits.apply`.
public struct PartSpec: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var start: Date
    public var end: Date
    public var activity: DetectedActivity

    public init(id: UUID = UUID(), start: Date, end: Date, activity: DetectedActivity) {
        self.id = id
        self.start = start
        self.end = end
        self.activity = activity
    }
}

/// Everything the user changed about how a session is cut into parts. Lives beside the
/// recorded data (`segment_overrides.json`); `sessions.json` is never touched.
///
/// - `types`: type corrections keyed by recorded segment id (the original v1 file format).
/// - `partitions`: per session, a full replacement list of parts, written the first time the
///   user splits or merges. It wins over `types` for that session.
///
/// Keys are UUID strings so the JSON stays an object (Codable encodes `[UUID: _]` as an array).
public struct SegmentEdits: Codable, Equatable, Sendable {
    public var version: Int = 2
    public var types: [String: DetectedActivity] = [:]
    public var partitions: [String: [PartSpec]] = [:]

    public init(types: [String: DetectedActivity] = [:], partitions: [String: [PartSpec]] = [:]) {
        self.types = types
        self.partitions = partitions
    }

    private enum CodingKeys: String, CodingKey { case version, types, partitions }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `version` is required so a legacy flat `{segmentId: activity}` file never decodes as v2.
        version = try c.decode(Int.self, forKey: .version)
        types = try c.decodeIfPresent([String: DetectedActivity].self, forKey: .types) ?? [:]
        partitions = try c.decodeIfPresent([String: [PartSpec]].self, forKey: .partitions) ?? [:]
    }

    /// Shortest part a split may leave on either side.
    public static let minPart: TimeInterval = 30

    // MARK: Decoding (v1 = flat `{segmentId: activity}` object)

    public static func decode(_ data: Data) throws -> SegmentEdits {
        if let v2 = try? JSONDecoder().decode(SegmentEdits.self, from: data) { return v2 }
        return SegmentEdits(types: try JSONDecoder().decode([String: DetectedActivity].self, from: data))
    }

    // MARK: Effective segments (pure)

    /// Recorded segments with the edits applied. Rest parts burn nothing: their calories are zeroed
    /// at display time (the stored data keeps the original numbers).
    public func apply(to segments: [ActivitySegment], sessionID: UUID) -> [ActivitySegment] {
        if let specs = partitions[sessionID.uuidString], !specs.isEmpty {
            return Self.slice(segments, into: specs)
        }
        return segments.map { seg in
            guard let o = types[seg.id.uuidString], o != seg.activityType else { return seg }
            return Self.retyped(seg, to: o, zeroing: seg.activityType != .stationary)
        }
    }

    /// The one rule for an "effective" session (DataManager and the widgets share it): edited parts, and the
    /// stored total minus the energy of parts turned into Rest. nil when no edit touches this session.
    public func effective(segments: [ActivitySegment], calories: Double?, sessionID: UUID)
        -> (segments: [ActivitySegment], calories: Double?)? {
        guard !segments.isEmpty,
              partitions[sessionID.uuidString] != nil || segments.contains(where: { types[$0.id.uuidString] != nil })
        else { return nil }
        let edited = apply(to: segments, sessionID: sessionID)
        let kcal = calories.map { max(0, $0 - Self.caloriesRemoved(raw: segments, effective: edited)) }
        return (edited, kcal)
    }

    /// Energy the edits removed from the session (rest parts). Subtract it from stored totals.
    public static func caloriesRemoved(raw: [ActivitySegment], effective: [ActivitySegment]) -> Double {
        max(0, raw.reduce(0) { $0 + calories($1) } - effective.reduce(0) { $0 + calories($1) })
    }

    /// Primary display calories of a part (Apple's active energy, else ShuttlX's estimate).
    public static func calories(_ s: ActivitySegment) -> Double { s.activeEnergyCalories ?? s.estimatedCalories ?? 0 }

    // MARK: Edits (pure; `parts` = the CURRENT effective parts of the session, in order)

    public func settingType(_ activity: DetectedActivity, partID: UUID, parts: [ActivitySegment], sessionID: UUID) -> SegmentEdits {
        var out = self
        let key = sessionID.uuidString
        if var specs = partitions[key], let i = specs.firstIndex(where: { $0.id == partID }) {
            specs[i].activity = activity
            out.partitions[key] = specs
        } else {
            out.types[partID.uuidString] = activity
        }
        return out
    }

    /// Cuts the part at `date`. Nil when either side would be shorter than `minPart`.
    public func splitting(partID: UUID, at date: Date, parts: [ActivitySegment], sessionID: UUID,
                          newID: UUID = UUID()) -> SegmentEdits? {
        var specs = Self.specs(from: parts)
        guard let i = specs.firstIndex(where: { $0.id == partID }) else { return nil }
        let p = specs[i]
        guard date.timeIntervalSince(p.start) >= Self.minPart, p.end.timeIntervalSince(date) >= Self.minPart else { return nil }
        specs[i].end = date
        specs.insert(PartSpec(id: newID, start: date, end: p.end, activity: p.activity), at: i + 1)
        return replacing(specs, sessionID: sessionID)
    }

    /// Joins the part with the one after it (keeps the first part's type). Nil for the last part.
    public func merging(partID: UUID, parts: [ActivitySegment], sessionID: UUID) -> SegmentEdits? {
        var specs = Self.specs(from: parts)
        guard let i = specs.firstIndex(where: { $0.id == partID }), i + 1 < specs.count else { return nil }
        specs[i].end = specs[i + 1].end
        specs.remove(at: i + 1)
        return replacing(specs, sessionID: sessionID)
    }

    /// True when any edit touches this session (type overrides are keyed by RECORDED segment id, so the raw ids are needed).
    public func hasEdits(sessionID: UUID, rawSegmentIDs: [UUID]) -> Bool {
        partitions[sessionID.uuidString] != nil || rawSegmentIDs.contains { types[$0.uuidString] != nil }
    }

    /// "Reset to detected": drops this session's partition and the type overrides of its recorded segments. Other sessions are untouched.
    public func resetting(sessionID: UUID, rawSegmentIDs: [UUID]) -> SegmentEdits {
        var out = self
        out.partitions[sessionID.uuidString] = nil
        for id in rawSegmentIDs { out.types[id.uuidString] = nil }
        return out
    }

    private func replacing(_ specs: [PartSpec], sessionID: UUID) -> SegmentEdits {
        var out = self
        out.partitions[sessionID.uuidString] = specs
        return out
    }

    private static func specs(from parts: [ActivitySegment]) -> [PartSpec] {
        parts.map { PartSpec(id: $0.id, start: $0.startDate, end: $0.endDate ?? $0.startDate.addingTimeInterval($0.duration), activity: $0.activityType) }
    }

    // MARK: Slicing

    private static func retyped(_ seg: ActivitySegment, to activity: DetectedActivity, zeroing: Bool) -> ActivitySegment {
        var s = seg
        s.activityType = activity
        if zeroing && activity == .stationary {
            if s.estimatedCalories != nil { s.estimatedCalories = 0 }
            if s.activeEnergyCalories != nil { s.activeEnergyCalories = 0 }
        }
        return s
    }

    /// Builds each part from the recorded segments it overlaps; distance, steps and calories are
    /// apportioned by time overlap, heart rate is the overlap-weighted mean.
    // ponytail: even spread inside a recorded segment; real per-sample splits would need stored samples.
    private static func slice(_ raw: [ActivitySegment], into specs: [PartSpec]) -> [ActivitySegment] {
        specs.map { spec in
            var seg = ActivitySegment(id: spec.id, activityType: spec.activity, startDate: spec.start, endDate: spec.end)
            var dist: Double?, steps: Double?, est: Double?, act: Double?
            var hrSum = 0.0, hrTime = 0.0
            var allRest = true
            func add(_ acc: inout Double?, _ v: Double?, _ f: Double) { if let v { acc = (acc ?? 0) + v * f } }
            for r in raw {
                guard let re = r.endDate else { continue }
                let span = re.timeIntervalSince(r.startDate)
                let overlap = min(re, spec.end).timeIntervalSince(max(r.startDate, spec.start))
                guard span > 0, overlap > 0 else { continue }
                let f = overlap / span
                add(&dist, r.distance, f); add(&steps, r.steps.map(Double.init), f)
                add(&est, r.estimatedCalories, f); add(&act, r.activeEnergyCalories, f)
                if let hr = r.averageHeartRate { hrSum += hr * overlap; hrTime += overlap }
                if r.activityType != .stationary { allRest = false }
            }
            let zero = spec.activity == .stationary && !allRest
            seg.distance = dist
            seg.steps = steps.map { Int($0.rounded()) }
            seg.estimatedCalories = zero ? est.map { _ in 0 } : est
            seg.activeEnergyCalories = zero ? act.map { _ in 0 } : act
            seg.averageHeartRate = hrTime > 0 ? hrSum / hrTime : nil
            return seg
        }
    }
}
