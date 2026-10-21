import Foundation
import os.log
import ShuttlXShared

/// Crash/kill recovery for an iPhone-driven workout (the counterpart of the watch's WorkoutPersistence).
/// While a workout runs the controller writes the session recorded so far every `interval` seconds, on pause
/// and when the app goes to the background. The next launch offers to save or discard it.
/// Files are removed on finish, cancel and wipe. All disk work runs on one serial utility queue.
struct PhoneWorkoutCheckpoint: Codable {
    static let fileName = "iphone_workout_checkpoint.json"
    static let interval: TimeInterval = 15

    /// The session as recorded so far: id, start, duration, HR, distance, steps and route up to `savedAt`.
    var session: TrainingSession
    /// The watch was asked to record the same workout (its session replaces this one when it arrives).
    var watchLinked: Bool
    var savedAt: Date

    private static let queue = DispatchQueue(label: "com.shuttlx.iphone-checkpoint", qos: .utility)
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "PhoneWorkoutCheckpoint")

    private static var url: URL? { DataManager.workingContainer()?.appendingPathComponent(fileName) }

    /// Encodes and writes off the main thread (a long GPS route is a large payload).
    func writeAsync() {
        guard let url = Self.url else { return }
        let copy = self
        Self.queue.async {
            do {
                try JSONEncoder().encode(copy).write(to: url, options: StoreFile.writeOptions)
            } catch {
                Self.logger.error("Checkpoint write failed: \(error.localizedDescription)")
            }
        }
    }

    static func removeAsync() {
        guard let url else { return }
        queue.async {
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            do { try FileManager.default.removeItem(at: url) } catch {
                logger.error("Checkpoint remove failed: \(error.localizedDescription)")
            }
        }
    }

    /// Reads the file left by an interrupted workout. An unreadable file is kept as a `_corrupt_` copy and removed.
    static func load() -> PhoneWorkoutCheckpoint? {
        guard let url else { return nil }
        return queue.sync {
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            do {
                return try JSONDecoder().decode(PhoneWorkoutCheckpoint.self, from: Data(contentsOf: url))
            } catch {
                logger.error("Checkpoint unreadable, set aside: \(error.localizedDescription)")
                _ = try? StoreFile.backupCorrupt(url)
                try? FileManager.default.removeItem(at: url)
                return nil
            }
        }
    }
}
