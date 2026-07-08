import Foundation
import os.log

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

    /// Encode + write the backup off the calling actor. Safe to call every tick;
    /// the caller throttles cadence.
    func checkpoint(_ session: TrainingSession) {
        queue.async { [logger] in
            do {
                let data = try JSONEncoder().encode(session)
                guard let backupURL = Self.backupURL() else {
                    logger.error("Could not resolve backup URL for workout backup")
                    return
                }
                try data.write(to: backupURL, options: [.atomic, .completeFileProtection])
                logger.info("Workout data backed up")
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
            let session = try JSONDecoder().decode(TrainingSession.self, from: data)
            logger.info("Recovered crashed workout backup: \(Int(session.duration))s")
            return session
        } catch {
            logger.error("Failed to read workout backup: \(error.localizedDescription)")
            try? fileManager.removeItem(at: backupURL)
            return nil
        }
    }

    func clearBackup() {
        queue.async {
            guard let backupURL = Self.backupURL() else { return }
            try? FileManager.default.removeItem(at: backupURL)
        }
    }

    /// Returns backup URL in App Group container (preferred) or Documents dir (fallback)
    private static func backupURL() -> URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared") {
            return container.appendingPathComponent("active_workout_backup.json")
        }
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docsURL.appendingPathComponent("active_workout_backup.json")
    }
}
