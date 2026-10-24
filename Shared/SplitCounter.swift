import Foundation

/// Whole-unit (km or mile) splits from a growing distance stream. Pure value type.
///
/// Feed every distance update with the active (pause-free) workout time it was read at.
/// A crossing's time is interpolated between the previous and the current update, so a
/// split does not snap to the moment the update arrived. Several crossings in one update
/// (a late batch, or the pedometer -> builder source switch) are all recorded, marked
/// `estimated`, and still ask for ONE alert. After `silenceNextUpdate()` (crash resume)
/// the next update records its splits without an alert.
public struct SplitCounter: Equatable, Sendable {
    public struct Split: Equatable, Sendable {
        /// 1-based unit number ("KM 3").
        public let number: Int
        /// Active seconds for this unit.
        public let splitTime: TimeInterval
        /// Active seconds from the workout start to this crossing.
        public let cumulativeTime: TimeInterval
        /// Crossed together with another unit in one update: the time is a straight-line guess.
        public let estimated: Bool
    }

    public struct Update: Equatable, Sendable {
        public let splits: [Split]
        /// True when this update crossed at least one unit and is not silenced.
        public let alert: Bool
    }

    public static let kmMetres: Double = 1000
    public static let mileMetres: Double = 1609.344

    public let unitMetres: Double
    public private(set) var splits: [Split] = []
    private var lastMetres: Double = 0
    private var lastTime: TimeInterval = 0
    private var silent = false

    public init(unitMetres: Double) {
        self.unitMetres = unitMetres
    }

    public var lastSplit: Split? { splits.last }

    /// The next `update` records splits but does not alert (first update after a crash resume).
    public mutating func silenceNextUpdate() { silent = true }

    public mutating func update(metres: Double, activeTime: TimeInterval) -> Update {
        let wasSilent = silent
        silent = false
        guard metres.isFinite, activeTime.isFinite, unitMetres > 0 else {
            return Update(splits: [], alert: false)
        }
        defer { lastMetres = metres; lastTime = max(lastTime, activeTime) }
        let crossed = Int(floor(metres / unitMetres)) - splits.count
        guard crossed > 0, metres > lastMetres else { return Update(splits: [], alert: false) }

        var new: [Split] = []
        for _ in 0..<crossed {
            let mark = Double(splits.count + 1) * unitMetres
            let fraction = min(1, max(0, (mark - lastMetres) / (metres - lastMetres)))
            let t = lastTime + fraction * max(0, activeTime - lastTime)
            let split = Split(number: splits.count + 1,
                              splitTime: max(0, t - (splits.last?.cumulativeTime ?? 0)),
                              cumulativeTime: t,
                              estimated: crossed > 1)
            splits.append(split)
            new.append(split)
        }
        return Update(splits: new, alert: !wasSilent)
    }
}
