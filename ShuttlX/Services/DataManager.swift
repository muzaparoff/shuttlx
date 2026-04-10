import Foundation
import Combine
import HealthKit
import StoreKit
import WidgetKit
import os.log

@MainActor
class DataManager: ObservableObject {
    @Published var sessions: [TrainingSession] = []
    @Published var healthKitAuthorized = false

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "DataManager")

    private var processedSessionIds = Set<UUID>()
    private var cancellables = Set<AnyCancellable>()
    private let healthStore = HKHealthStore()
    private var cloudSyncDebounceTask: Task<Void, Never>?

    // MARK: - App Group Properties
    private let sessionsKey = "sessions.json"
    private let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")

    private var fallbackContainer: URL? {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docsURL.appendingPathComponent("SharedData")
    }

    init() {
        loadSessionsFromAppGroup()
        checkHealthKitAuthorizationStatus()
        SharedDataManager.shared.setDataManager(self)
        setupBindings()
    }

    private func setupBindings() {
        SharedDataManager.shared.$syncedSessions
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

            guard sessions.count < 500 else {
                logger.warning("Session cap reached (500). Dropping session \(session.id)")
                continue
            }

            if !sessions.contains(where: { $0.id == session.id }) {
                sessions.append(session)
                hasChanges = true
            }
        }
        if hasChanges {
            saveSessionsToAppGroup()
            requestAppReviewIfEligible()
        }
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
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url, options: .atomic)
            WidgetCenter.shared.reloadAllTimelines()
            debouncedCloudSync()
        } catch {
            logger.error("Failed to save sessions: \(error.localizedDescription)")
        }
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
        do {
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([TrainingSession].self, from: data)

            // Merge: add sessions from disk that aren't already in memory
            let existingIds = Set(sessions.map { $0.id })
            var hasNew = false
            for session in loaded {
                processedSessionIds.insert(session.id)
                if !existingIds.contains(session.id) {
                    sessions.append(session)
                    hasNew = true
                }
            }

            // If first load (empty), just replace
            if existingIds.isEmpty {
                sessions = loaded
                processedSessionIds = Set(loaded.map { $0.id })
            } else if hasNew {
                logger.info("Loaded \(self.sessions.count - existingIds.count) new session(s) from disk")
            }
        } catch {
            logger.error("Failed to load sessions: \(error.localizedDescription)")
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
