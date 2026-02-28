import WatchConnectivity
import Foundation
import Combine
import os.log

@MainActor
class SharedDataManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = SharedDataManager()

    @Published var syncedSessions: [TrainingSession] = []
    @Published var syncLog: [String] = []
    @Published var connectivityHealth: Double = 1.0
    @Published var lastSyncTime: Date?

    // Live workout state from Watch
    @Published var isWorkoutActiveOnWatch = false
    @Published var liveElapsedTime: TimeInterval = 0
    @Published var liveHeartRate: Int = 0
    @Published var liveDistance: Double = 0
    @Published var liveCalories: Int = 0
    @Published var liveSteps: Int = 0
    @Published var liveCurrentActivity: String = "unknown"
    @Published var liveIsPaused: Bool = false
    @Published var livePace: TimeInterval = 0

    private var liveMetricsTimeoutTimer: Timer?
    private var consecutiveFailures: Int = 0
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "SharedDataManager")

    private let sessionsKey = "sessions.json"
    private let appGroupIdentifier = "group.com.shuttlx.shared"
    private let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")

    private var fallbackContainer: URL? {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docsURL.appendingPathComponent("SharedData")
    }

    private var lastPingTime: Date?
    private var backgroundSyncTimer: Timer?
    private weak var dataManager: DataManager?

    private var session: WCSession {
        return WCSession.default
    }

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        loadSessionsFromSharedStorage()
        setupBackgroundTasks()
        LiveActivityManager.shared.cleanupStaleActivities()
    }

    deinit {
        backgroundSyncTimer?.invalidate()
    }

    // MARK: - Background Tasks

    private func setupBackgroundTasks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task.detached {
                    await MainActor.run {
                        self.performBackgroundSync()
                    }
                }
            }
        }
    }

    private func performBackgroundSync() {
        checkForNewSessions()
        pingWatchIfNeeded()
        updateConnectivityHealth()
    }

    private func checkForNewSessions() {
        let newSessions = loadSessionsFromAppGroup()
        let newSessionsToAdd = newSessions.filter { newSession in
            !self.syncedSessions.contains { $0.id == newSession.id }
        }

        if !newSessionsToAdd.isEmpty {
            log("Found \(newSessionsToAdd.count) new session(s) in shared storage")
            for session in newSessionsToAdd {
                syncedSessions.append(session)
                if let dataManager = dataManager {
                    dataManager.handleReceivedSessions([session])
                }
            }
        }
    }

    private func pingWatchIfNeeded() {
        if let lastPing = lastPingTime, Date().timeIntervalSince(lastPing) < 300 {
            return
        }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                ["action": "ping", "timestamp": Date().timeIntervalSince1970],
                replyHandler: { [weak self] reply in
                    Task { @MainActor in
                        guard let self = self else { return }
                        if let status = reply["status"] as? String, status == "alive" {
                            self.lastPingTime = Date()
                            self.consecutiveFailures = 0
                            self.updateConnectivityHealth()
                        }
                    }
                },
                errorHandler: { [weak self] error in
                    Task { @MainActor in
                        self?.consecutiveFailures += 1
                        self?.updateConnectivityHealth()
                    }
                }
            )
        }
    }

    private func updateConnectivityHealth() {
        var healthScore = 1.0

        if WCSession.default.activationState != .activated { healthScore -= 0.5 }
        if !WCSession.default.isReachable { healthScore -= 0.3 }
        if !WCSession.default.isPaired { healthScore -= 0.7 }
        if !WCSession.default.isWatchAppInstalled { healthScore -= 0.6 }
        healthScore -= min(0.5, Double(consecutiveFailures) * 0.1)

        if let lastSync = lastSyncTime {
            if Date().timeIntervalSince(lastSync) > 300 { healthScore -= 0.2 }
        } else {
            healthScore -= 0.2
        }

        healthScore = max(0, min(1, healthScore))

        if healthScore != connectivityHealth {
            connectivityHealth = healthScore
        }
    }

    // MARK: - DataManager Integration

    func setDataManager(_ dataManager: DataManager) {
        self.dataManager = dataManager
    }

    // MARK: - Session Handling

    func handleReceivedSession(_ session: TrainingSession) {
        if !syncedSessions.contains(where: { $0.id == session.id }) {
            syncedSessions.append(session)
            saveSessionsToSharedStorage(syncedSessions)
            log("New session received and saved.")
            consecutiveFailures = 0
            lastSyncTime = Date()
            updateConnectivityHealth()
        }
    }

    // MARK: - Live Workout Metrics

    func handleLiveMetrics(_ message: [String: Any]) {
        isWorkoutActiveOnWatch = true
        liveElapsedTime = message["elapsedTime"] as? TimeInterval ?? 0
        liveHeartRate = message["heartRate"] as? Int ?? 0
        liveDistance = message["distance"] as? Double ?? 0
        liveCalories = message["calories"] as? Int ?? 0
        liveSteps = message["steps"] as? Int ?? 0
        liveCurrentActivity = message["currentActivity"] as? String ?? "unknown"
        liveIsPaused = message["isPaused"] as? Bool ?? false
        livePace = message["pace"] as? TimeInterval ?? 0

        LiveActivityManager.shared.updateActivity(
            elapsedTime: liveElapsedTime,
            heartRate: liveHeartRate,
            distance: liveDistance,
            calories: liveCalories,
            currentActivity: liveCurrentActivity,
            isPaused: liveIsPaused,
            pace: livePace
        )

        // Reset timeout — if no update in 10 seconds, clear live state
        liveMetricsTimeoutTimer?.invalidate()
        liveMetricsTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.clearLiveWorkoutState()
            }
        }
    }

    func clearLiveWorkoutState() {
        LiveActivityManager.shared.endActivity()
        isWorkoutActiveOnWatch = false
        liveElapsedTime = 0
        liveHeartRate = 0
        liveDistance = 0
        liveCalories = 0
        liveSteps = 0
        liveCurrentActivity = "unknown"
        liveIsPaused = false
        livePace = 0
        liveMetricsTimeoutTimer?.invalidate()
        liveMetricsTimeoutTimer = nil
    }

    // MARK: - Session Storage

    private func saveSessionsToSharedStorage(_ sessions: [TrainingSession]) {
        guard let containerURL = getWorkingContainer() else { return }

        let url = containerURL.appendingPathComponent(sessionsKey)
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url)
        } catch {
            log("Failed to save sessions: \(error)")
        }
    }

    private func loadSessionsFromSharedStorage() {
        let appGroupSessions = loadSessionsFromAppGroup()
        if !appGroupSessions.isEmpty {
            self.syncedSessions = appGroupSessions
        }
    }

    func loadSessionsFromAppGroup() -> [TrainingSession] {
        guard let containerURL = getWorkingContainer() else { return [] }

        do {
            let url = containerURL.appendingPathComponent(sessionsKey)
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([TrainingSession].self, from: data)
        } catch {
            return []
        }
    }

    // MARK: - Public Debug

    func purgeAllSessionsFromStorage() {
        syncedSessions = []

        if let containerURL = getWorkingContainer() {
            let sessionsURL = containerURL.appendingPathComponent(sessionsKey)
            try? JSONEncoder().encode([TrainingSession]()).write(to: sessionsURL)
        }
    }

    func checkConnectivity() -> String {
        let session = WCSession.default
        return """
        Activation State: \(session.activationState.rawValue)
        Reachable: \(session.isReachable)
        Paired: \(session.isPaired)
        App Installed: \(session.isWatchAppInstalled)
        Connectivity Health: \(Int(connectivityHealth * 100))%
        Sessions Synced: \(syncedSessions.count)
        Last Sync: \(lastSyncTime?.description ?? "Never")
        Consecutive Failures: \(consecutiveFailures)
        """
    }

    func clearAndReloadSessions() {
        let allSessions = Set(loadSessionsFromAppGroup())
        syncedSessions = Array(allSessions)
        saveSessionsToSharedStorage(syncedSessions)
    }

    // MARK: - Helpers

    private func log(_ message: String) {
        logger.info("\(message)")
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        syncLog.append("[\(formatter.string(from: Date()))] \(message)")
        if syncLog.count > 100 {
            syncLog.removeFirst()
        }
    }

    private func getWorkingContainer() -> URL? {
        if let container = sharedContainer {
            return container
        }

        guard let fallback = fallbackContainer else { return nil }
        do {
            try FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback
        } catch {
            return nil
        }
    }
}

// MARK: - WCSessionDelegate
extension SharedDataManager {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.log("WC Session activation failed: \(error.localizedDescription)")
                self.consecutiveFailures += 1
            } else {
                self.log("WC Session activated: \(activationState.rawValue)")
                self.consecutiveFailures = 0
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.log("Watch reachability changed: \(session.isReachable)")
            self.updateConnectivityHealth()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.updateConnectivityHealth()
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            session.activate()
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            if let action = userInfo["action"] as? String,
               action == "saveSession",
               let sessionDataString = userInfo["sessionData"] as? String,
               let sessionData = Data(base64Encoded: sessionDataString) {
                do {
                    let trainingSession = try JSONDecoder().decode(TrainingSession.self, from: sessionData)
                    self.handleReceivedSession(trainingSession)
                    self.log("Session received from watch via userInfo")
                } catch {
                    self.log("Failed to decode session: \(error.localizedDescription)")
                    self.consecutiveFailures += 1
                }
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let action = message["action"] as? String {
                switch action {
                case "saveSession":
                    if let sessionDataString = message["sessionData"] as? String,
                       let sessionData = Data(base64Encoded: sessionDataString) {
                        do {
                            let trainingSession = try JSONDecoder().decode(TrainingSession.self, from: sessionData)
                            self.handleReceivedSession(trainingSession)
                            self.consecutiveFailures = 0
                        } catch {
                            self.consecutiveFailures += 1
                        }
                    }
                case "liveMetrics":
                    self.handleLiveMetrics(message)
                case "workoutStopped":
                    self.clearLiveWorkoutState()
                case "ping":
                    self.consecutiveFailures = 0
                default:
                    break
                }
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            if let action = message["action"] as? String {
                switch action {
                case "saveSession":
                    if let sessionDataString = message["sessionData"] as? String,
                       let sessionData = Data(base64Encoded: sessionDataString) {
                        do {
                            let trainingSession = try JSONDecoder().decode(TrainingSession.self, from: sessionData)
                            self.handleReceivedSession(trainingSession)
                            self.consecutiveFailures = 0
                            replyHandler(["status": "saved", "timestamp": Date().timeIntervalSince1970])
                        } catch {
                            self.consecutiveFailures += 1
                            replyHandler(["error": "Failed to decode session"])
                        }
                    } else {
                        replyHandler(["error": "Missing sessionData"])
                    }
                case "liveMetrics":
                    self.handleLiveMetrics(message)
                    replyHandler(["status": "received"])
                case "workoutStopped":
                    self.clearLiveWorkoutState()
                    replyHandler(["status": "received"])
                case "ping":
                    replyHandler(["status": "alive", "timestamp": Date().timeIntervalSince1970])
                    self.consecutiveFailures = 0
                default:
                    replyHandler(["error": "Unknown action"])
                }
            } else {
                replyHandler(["error": "No action"])
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.consecutiveFailures += 1
                self.log("UserInfo transfer failed: \(error.localizedDescription)")
            } else {
                self.consecutiveFailures = 0
            }
            self.updateConnectivityHealth()
        }
    }
}
