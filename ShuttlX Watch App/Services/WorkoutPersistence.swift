import Foundation
import os.log
import ShuttlXShared

/// Crash-recovery backup store for the active workout — extracted from
/// WatchWorkoutManager (refactor plan Phase 3).
///
/// JSON encoding and disk I/O run on a serial utility queue, NOT the main
/// actor, so the 15-second checkpoint and pause-time backups never stall the
/// tick path or the UI (freeze root-cause H2). The recovery read stays
/// synchronous — it runs once at launch before any writes are queued.
final class WorkoutPersistence: Sendable {

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "WorkoutPersistence")
    /// Serializes checkpoint/clear so a clear can never interleave mid-write.
    private let queue = DispatchQueue(label: "com.shuttlx.workout-persistence", qos: .utility)

    /// The GPS route lives in its own file so the 15 s checkpoint does not re-encode
    /// up to 2000 points every time; tagged with the session id so a leftover file
    /// can never join another workout.
    private struct RouteBackup: Codable {
        let sessionID: UUID
        let points: [RoutePoint]
    }

    /// Encode + write the backup off the calling actor. Safe to call every tick;
    /// the caller throttles cadence. `route` is written only when non-nil (the
    /// caller passes it at most every 60 s and on pause); otherwise the last
    /// written route file stays.
    func checkpoint(_ session: TrainingSession, route: [RoutePoint]?, autoPauseReason: String? = nil, phoneSessionID: String? = nil) {
        var session = session
        session.route = nil
        queue.async { [logger] in
            // Sidecars (not TrainingSession fields): the model is duplicated per
            // target and these only matter for resuming after a crash.
            UserDefaults.standard.set(autoPauseReason, forKey: Self.autoPauseReasonKey)
            // Tagged with the session id so a leftover value never joins another workout.
            UserDefaults.standard.set(phoneSessionID.map { [session.id.uuidString: $0] }, forKey: Self.phoneSessionIDKey)
            do {
                guard let backupURL = Self.backupURL(), let routeURL = Self.routeURL() else {
                    logger.error("Could not resolve backup URL for workout backup")
                    return
                }
                if let route {
                    let data = try JSONEncoder().encode(RouteBackup(sessionID: session.id, points: route))
                    try data.write(to: routeURL, options: [.atomic, .completeFileProtection])
                }
                let data = try JSONEncoder().encode(session)
                try data.write(to: backupURL, options: [.atomic, .completeFileProtection])
                logger.info("Workout data backed up\(route != nil ? " (with route)" : "")")
            } catch {
                logger.error("Failed to backup workout data: \(error.localizedDescription)")
            }
        }
    }

    /// Check for a crashed workout backup and return the recovered session.
    func recoverCrashedWorkout() -> TrainingSession? {
        guard let backupURL = Self.backupURL() else { return nil }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: backupURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: backupURL)
            var session = try JSONDecoder().decode(TrainingSession.self, from: data)
            // Backups from older builds carry the route inline.
            if session.route == nil, let routeURL = Self.routeURL(),
               let routeData = try? Data(contentsOf: routeURL),
               let route = try? JSONDecoder().decode(RouteBackup.self, from: routeData),
               route.sessionID == session.id, !route.points.isEmpty {
                session.route = route.points
            }
            logger.info("Recovered crashed workout backup: \(Int(session.duration))s")
            return session
        } catch {
            logger.error("Failed to read workout backup: \(error.localizedDescription)")
            try? fileManager.removeItem(at: backupURL)
            return nil
        }
    }

    /// `autoPauseReason` of the last checkpoint ("noMotion"), nil if none.
    func recoveredAutoPauseReason() -> String? {
        UserDefaults.standard.string(forKey: Self.autoPauseReasonKey)
    }

    /// Phone session id checkpointed for the workout `sessionID`, nil if none
    /// (watch-started, older build, or a different workout).
    func recoveredPhoneSessionID(for sessionID: UUID) -> String? {
        (UserDefaults.standard.dictionary(forKey: Self.phoneSessionIDKey) as? [String: String])?[sessionID.uuidString]
    }

    private static let autoPauseReasonKey = "activeWorkoutAutoPauseReason"
    private static let phoneSessionIDKey = "activeWorkoutPhoneSessionID"

    func clearBackup() {
        queue.async {
            UserDefaults.standard.removeObject(forKey: Self.autoPauseReasonKey)
            UserDefaults.standard.removeObject(forKey: Self.phoneSessionIDKey)
            for url in [Self.backupURL(), Self.routeURL()].compactMap({ $0 }) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private static func backupURL() -> URL? { fileURL("active_workout_backup.json") }
    private static func routeURL() -> URL? { fileURL("active_workout_route.json") }

    /// File in the App Group container (preferred) or Documents dir (fallback)
    private static func fileURL(_ name: String) -> URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared") {
            return container.appendingPathComponent(name)
        }
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docsURL.appendingPathComponent(name)
    }
}
