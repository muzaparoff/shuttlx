import Foundation

/// Which distance the iPhone workout shows. GPS once its fix is usable (outdoors), else the pedometer
/// (treadmill, poor signal). Never the sum of the two. It is recomputed on EVERY update of either source:
/// the old code only recomputed it when the pedometer reported, so a run with GPS but no pedometer data
/// (Motion access denied, simulator) showed 0 m while the route was recorded.
public enum DistanceFusion {
    public static func totalKm(gpsKm: Double, gpsUsable: Bool, pedometerKm: Double) -> Double {
        gpsUsable ? gpsKm : pedometerKm
    }
}
