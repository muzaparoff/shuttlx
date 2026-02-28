import Foundation
import Combine
import HealthKit

@MainActor
class DataManager: ObservableObject {
    @Published var sessions: [TrainingSession] = []
    @Published var healthKitAuthorized = false

    private var processedSessionIds = Set<UUID>()
    private var cancellables = Set<AnyCancellable>()
    private let healthStore = HKHealthStore()

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

            guard sessions.count < 500 else { continue }

            if !sessions.contains(where: { $0.id == session.id }) {
                sessions.append(session)
                hasChanges = true
            }
        }
        if hasChanges {
            saveSessionsToAppGroup()
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

        let typesToRead: Set<HKQuantityType> = [heartRateType, activeEnergyType, distanceType]
        let typesToWrite: Set<HKSampleType> = [HKWorkoutType.workoutType(), activeEnergyType, distanceType]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            await MainActor.run {
                self.healthKitAuthorized = true
            }
        } catch {
            print("HealthKit permission request failed: \(error)")
        }
    }

    // MARK: - App Group Storage
    private func saveSessionsToAppGroup() {
        guard let containerURL = getWorkingContainer() else { return }

        let url = containerURL.appendingPathComponent(sessionsKey)
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url)
        } catch {
            print("Failed to save sessions: \(error)")
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
                print("Loaded \(sessions.count - existingIds.count) new session(s) from disk")
            }
        } catch {
            print("Failed to load sessions: \(error)")
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
