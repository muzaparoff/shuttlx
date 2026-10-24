import Foundation
import HealthKit
import CoreLocation
import ShuttlXShared

// MARK: - CLLocationManagerDelegate
extension WatchWorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let filtered = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 50 }
        guard !filtered.isEmpty else { return }

        let points = filtered.map {
            RoutePoint(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                altitude: $0.altitude,
                timestamp: $0.timestamp,
                speed: $0.speed >= 0 ? $0.speed : nil,
                horizontalAccuracy: $0.horizontalAccuracy
            )
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Cap in-memory route points (memory, checkpoints, the session sent to the phone). Thinned
            // evenly over the whole route once over the cap, so hour 1 of a long ride keeps its shape.
            // HealthKit gets every fix through HKWorkoutRouteBuilder below.
            self.routePoints.append(contentsOf: points)
            let before = self.routePoints.count
            self.routePoints.thinEvenlyIfOver(self.maxRoutePoints, to: self.maxRoutePoints * 3 / 4)
            if self.routePoints.count < before {
                self.logger.info("Route points thinned from \(before) to \(self.routePoints.count)")
            }

            // Feed HKWorkoutRouteBuilder for official HealthKit route
            self.routeBuilder?.insertRouteData(filtered) { success, error in
                if let error = error {
                    Task { @MainActor in
                        self.logger.debug("RouteBuilder insert error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let status = manager.authorizationStatus
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && self.isWorkoutActive && !self.isPaused {
                self.startLocationUpdates()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.logger.error("Location error: \(error.localizedDescription)")
        }
    }
}
