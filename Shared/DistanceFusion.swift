import Foundation

/// iPhone workout distance, fused incrementally. Each update adds the increment of the source trusted right
/// now: GPS while it is usable and its last fix is younger than `freshSec`, else the pedometer. Switching
/// sources never jumps, the total never goes down, and the two are never summed. Recomputed on EVERY update
/// of either source (GPS with no pedometer data still counts). Start a workout with a fresh value.
public struct DistanceFusion: Sendable, Equatable {
    public static let freshSec: TimeInterval = 10

    public private(set) var totalKm: Double = 0
    private var lastGpsKm: Double = 0
    private var lastPedKm: Double = 0

    public init() {}

    /// `gpsKm` / `pedometerKm` are the sources' running totals; `gpsFixAge` is seconds since the last good fix.
    @discardableResult
    public mutating func update(gpsKm: Double, pedometerKm: Double, gpsUsable: Bool, gpsFixAge: TimeInterval?) -> Double {
        let dGps = max(0, gpsKm - lastGpsKm)
        let dPed = max(0, pedometerKm - lastPedKm)
        lastGpsKm = gpsKm
        lastPedKm = pedometerKm
        let fresh = gpsUsable && (gpsFixAge.map { $0 <= Self.freshSec } ?? false)
        totalKm += fresh ? dGps : dPed
        return totalKm
    }
}
