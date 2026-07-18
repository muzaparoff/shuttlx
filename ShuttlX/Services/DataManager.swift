import Foundation
import Combine
import HealthKit
import StoreKit
import WidgetKit
import TelemetryDeck
import os.log
import ShuttlXShared

@MainActor
class DataManager: ObservableObject {
    @Published var sessions: [TrainingSession] = []
    @Published var healthKitAuthorized = false

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "DataManager")

    private var processedSessionIds = Set<UUID>()
    private var cancellables = Set<AnyCancellable>()
    /// Serial queue for sessions.json reads — decode cost grows with history
    /// size and the load runs on every app resume, so it must stay off-main.
    private nonisolated static let storeQueue = DispatchQueue(label: "com.shuttlx.datamanager-store", qos: .utility)
    private let healthStore = HKHealthStore()
    private var cloudSyncDebounceTask: Task<Void, Never>?

    // MARK: - App Group Properties
    private let sessionsKey = "sessions.json"
    private let archiveKey = "sessions_archive.json"
    /// Active-history cap. Overflow is archived oldest-first — newest workouts are never dropped.
    private let sessionCap = 500
    private let appGroupIdentifier = "group.com.shuttlx.shared"
    private var sharedContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private var fallbackContainer: URL? {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docsURL.appendingPathComponent("SharedData")
    }

    init() {
        loadSessionsFromAppGroup()
        checkHealthKitAuthorizationStatus()
        PhoneSyncCoordinator.shared.setDataManager(self)
        setupBindings()
    }

    private func setupBindings() {
        PhoneSyncCoordinator.shared.$syncedSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] receivedSessions in
                self?.handleReceivedSessions(receivedSessions)
            }
            .store(in: &cancellables)
    }

    func handleReceivedSessions(_ receivedSessions: [TrainingSession]) {
        var hasChanges = false
        for session in receivedSessions {
            guard !processedSessionIds.contains(session.id) else { continue }
            processedSessionIds.insert(session.id)

            if !sessions.contains(where: { $0.id == session.id }) {
                sessions.append(session)
                hasChanges = true
                trackWorkoutCompleted(session)
            }
        }
        if hasChanges {
            archiveOldestBeyondCap()
            saveSessionsToAppGroup()
            requestAppReviewIfEligible()
        }
    }

    /// Keeps the active list at `sessionCap` by moving the OLDEST overflow
    /// sessions into `sessions_archive.json`. Archived ids stay in
    /// `processedSessionIds`, so watch re-sends of archived sessions are still
    /// deduplicated and cannot re-enter the active list.
    private func archiveOldestBeyondCap() {
        guard sessions.count > sessionCap else { return }
        let overflow = sessions.count - sessionCap
        let evicted = Array(sessions.sorted { $0.startDate < $1.startDate }.prefix(overflow))
        let evictedIds = Set(evicted.map { $0.id })
        sessions.removeAll { evictedIds.contains($0.id) }
        appendToArchive(evicted)
        logger.warning("Session cap \(self.sessionCap) exceeded — archived \(evicted.count) oldest session(s)")
    }

    private func appendToArchive(_ evicted: [TrainingSession]) {
        guard !evicted.isEmpty, let containerURL = getWorkingContainer() else { return }

        let url = containerURL.appendingPathComponent(archiveKey)
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &coordinatorError) { writeURL in
            do {
                var archived: [TrainingSession] = []
                if FileManager.default.fileExists(atPath: writeURL.path) {
                    let data = try Data(contentsOf: writeURL)
                    do {
                        archived = try JSONDecoder().decode([TrainingSession].self, from: data)
                    } catch {
                        // Corrupt archive: preserve the bytes, then start a fresh archive.
                        let backupURL = writeURL.deletingLastPathComponent()
                            .appendingPathComponent("sessions_archive_corrupt_\(Int(Date().timeIntervalSince1970)).json")
                        try? FileManager.default.copyItem(at: writeURL, to: backupURL)
                        self.logger.error("Corrupt sessions_archive.json backed up to \(backupURL.lastPathComponent): \(error.localizedDescription)")
                    }
                }
                archived.append(contentsOf: evicted)
                let data = try JSONEncoder().encode(archived)
                try data.write(to: writeURL, options: [.atomic, .completeFileProtection])
            } catch {
                self.logger.error("Failed to archive \(evicted.count) session(s): \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            logger.error("File coordination error archiving sessions: \(coordinatorError.localizedDescription)")
        }
    }

    // MARK: - Analytics

    /// Sends a privacy-safe workout completion event to TelemetryDeck.
    /// No PII is included — only aggregate-safe metadata.
    private func trackWorkoutCompleted(_ session: TrainingSession) {
        TelemetryDeck.signal("workoutCompleted", parameters: [
            "sport": session.sportType?.rawValue ?? "unknown",
            "durationMinutes": String(Int(session.duration / 60)),
            "isInterval": String(session.completedIntervals?.isEmpty == false)
        ])
    }

    // MARK: - App Review

    private func requestAppReviewIfEligible() {
        let key = "com.shuttlx.reviewRequestedForSessionCount"
        let lastPromptCount = UserDefaults.standard.integer(forKey: key)
        let totalSessions = sessions.count

        // Prompt after 3rd workout, then again at 10, 25, etc.
        let milestones = [3, 10, 25, 50, 100]
        guard let milestone = milestones.first(where: { totalSessions >= $0 && lastPromptCount < $0 }) else { return }

        UserDefaults.standard.set(milestone, forKey: key)

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    // MARK: - HealthKit
    private func checkHealthKitAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // Check a write type — HealthKit reports accurate status for share types
        let workoutType = HKWorkoutType.workoutType()
        healthKitAuthorized = healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized
    }

    func requestHealthKitPermissions() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return
        }

        // Include date of birth so we can compute personalised HR zones via the Tanaka formula.
        let dateOfBirthType = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)
        var typesToRead: Set<HKObjectType> = [heartRateType, activeEnergyType, distanceType]
        if let dob = dateOfBirthType { typesToRead.insert(dob) }

        let typesToWrite: Set<HKSampleType> = [HKWorkoutType.workoutType(), activeEnergyType, distanceType]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            await MainActor.run {
                self.checkHealthKitAuthorizationStatus()
            }
            updateMaxHRFromHealthKit()
        } catch {
            logger.error("HealthKit permission request failed: \(error.localizedDescription)")
        }
    }

    /// Reads date of birth from HealthKit and persists the Tanaka-derived max HR
    /// to the App Group UserDefaults. Skips the update when a manual override already exists.
    private func updateMaxHRFromHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // Only update from HealthKit when no manual override exists
        guard HeartRateZoneCalculator.loadSavedMaxHR() == nil else {
            logger.info("Manual max HR override present — skipping HealthKit age lookup")
            return
        }
        do {
            let components = try healthStore.dateOfBirthComponents()
            let calendar = Calendar.current
            let now = calendar.dateComponents([.year], from: Date())
            guard let birthYear = components.year, let currentYear = now.year else { return }
            let age = currentYear - birthYear
            guard age > 0, age < 120 else { return }

            let calculator = HeartRateZoneCalculator(age: age, manualMaxHR: nil)
            HeartRateZoneCalculator.saveMaxHR(calculator.estimatedMaxHR)
            logger.info("Max HR updated from HealthKit age \(age): \(calculator.estimatedMaxHR) BPM")
        } catch {
            logger.info("Date of birth not available in HealthKit: \(error.localizedDescription)")
        }
    }

    // MARK: - App Group Storage
    func saveSessionsToAppGroup() {
        guard let containerURL = getWorkingContainer() else { return }

        let url = containerURL.appendingPathComponent(sessionsKey)
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { writeURL in
            do {
                let data = try JSONEncoder().encode(self.sessions)
                try data.write(to: writeURL, options: [.atomic, .completeFileProtection])
            } catch {
                self.logger.error("Failed to save sessions: \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            logger.error("File coordination error saving sessions: \(coordinatorError.localizedDescription)")
        }
        WidgetCenter.shared.reloadAllTimelines()
        debouncedCloudSync()
    }

    /// Debounce CloudKit sync to avoid firing on every rapid save (e.g. batch imports)
    private func debouncedCloudSync() {
        guard AuthenticationManager.shared.isSignedIn else { return }
        cloudSyncDebounceTask?.cancel()
        cloudSyncDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            guard !Task.isCancelled, let self = self else { return }
            CloudKitSyncManager.shared.performFullSync(dataManager: self)
        }
    }

    func loadSessionsFromAppGroup() {
        guard let containerURL = getWorkingContainer() else { return }

        let url = containerURL.appendingPathComponent(sessionsKey)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        Self.storeQueue.async { [logger, weak self] in
            var loaded: [TrainingSession] = []
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    loaded = try JSONDecoder().decode([TrainingSession].self, from: data)
                } catch {
                    logger.error("CRITICAL: Failed to decode sessions.json: \(error.localizedDescription)")
                    // Preserve corrupt file for potential recovery — don't overwrite history
                    let backupURL = url.deletingLastPathComponent()
                        .appendingPathComponent("sessions_corrupt_\(Int(Date().timeIntervalSince1970)).json")
                    try? FileManager.default.copyItem(at: readURL, to: backupURL)
                    logger.error("Backed up corrupt sessions.json to \(backupURL.lastPathComponent)")
                }
            }
            if let coordinatorError {
                logger.error("File coordination error loading sessions: \(coordinatorError.localizedDescription)")
                return
            }
            Task { @MainActor [weak self] in
                self?.mergeLoadedSessions(loaded)
            }
        }
    }

    private func mergeLoadedSessions(_ loaded: [TrainingSession]) {
        guard !loaded.isEmpty else { return }

        // Fast path: first load (empty in-memory list) — skip the per-session
        // merge loop and just replace wholesale. For users with 500+ sessions
        // this saved a noticeable startup pause from O(n) insert + duplicate-build.
        // Safe against a session received while the disk read was in flight:
        // a receive appends to `sessions`, which forces the merge path below.
        let existingIds = Set(sessions.map { $0.id })
        if existingIds.isEmpty {
            sessions = loaded
            processedSessionIds = Set(loaded.map { $0.id })
            return
        }

        // Subsequent loads: merge new sessions only.
        var hasNew = false
        for session in loaded {
            processedSessionIds.insert(session.id)
            if !existingIds.contains(session.id) {
                sessions.append(session)
                hasNew = true
            }
        }
        if hasNew {
            logger.info("Loaded \(self.sessions.count - existingIds.count) new session(s) from disk")
        }
    }

    // MARK: - Container Management
    private func getWorkingContainer() -> URL? {
        if let container = sharedContainer {
            return container
        }

        guard let fallback = fallbackContainer else { return nil }
        do {
            try FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true, attributes: nil)
            return fallback
        } catch {
            return nil
        }
    }
}
