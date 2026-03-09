import Foundation
import WatchConnectivity
import WidgetKit
import os.log

@MainActor
class SharedDataManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = SharedDataManager()
    @Published var syncStatus: String = "Not synced"
    @Published var isConnected: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncLog: [String] = []
    @Published var connectivityHealth: Double = 1.0
    @Published var workoutTemplates: [WorkoutTemplate] = []

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "SharedDataManager")
    private let appGroupIdentifier = "group.com.shuttlx.shared"

    private var pendingSessions: [TrainingSession] = []
    private var consecutiveFailures = 0
    private var backgroundSyncTimer: Timer?
    private let pendingSessionsFileName = "pending_sync_sessions.json"

    // MARK: - Initialization

    override init() {
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            logger.info("WCSession activated")
        }

        loadPendingSessionsFromDisk()
        loadTemplatesFromDisk()
        setupBackgroundTasks()
    }

    deinit {
        backgroundSyncTimer?.invalidate()
    }

    // MARK: - Background Tasks

    private func setupBackgroundTasks() {
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.retryPendingSessions()
                self.updateConnectivityHealth()
            }
        }
    }

    private func retryPendingSessions() {
        guard !pendingSessions.isEmpty else { return }

        logger.info("Retrying \(self.pendingSessions.count) pending sessions")

        let sessionsToSync = pendingSessions
        pendingSessions = []
        savePendingSessionsToDisk()

        for session in sessionsToSync {
            sendSessionToiOS(session)
        }
    }

    private func updateConnectivityHealth() {
        var healthScore = 1.0

        if WCSession.default.activationState != .activated {
            healthScore -= 0.5
        }
        if !WCSession.default.isReachable {
            healthScore -= 0.3
        }
        healthScore -= min(0.5, Double(consecutiveFailures) * 0.1)

        if let lastSync = lastSyncTime {
            if Date().timeIntervalSince(lastSync) > 300 {
                healthScore -= 0.2
            }
        } else {
            healthScore -= 0.2
        }

        healthScore = max(0, min(1, healthScore))

        if healthScore != connectivityHealth {
            connectivityHealth = healthScore
        }
    }

    // MARK: - Session Sending

    func sendSessionToiOS(_ session: TrainingSession) {
        logger.info("Sending training session to iOS...")

        // Save to App Group for reliability
        saveSessionToAppGroup(session)

        do {
            let sessionData = try JSONEncoder().encode(session)
            let base64 = sessionData.base64EncodedString()
            let payloadSize = base64.utf8.count
            logger.info("Session payload: \(payloadSize) bytes (\(session.route?.count ?? 0) route points)")

            if payloadSize > 200_000 {
                // Large session — use file transfer (unlimited size)
                sendSessionViaFileTransfer(session, sessionData: sessionData)
            } else if payloadSize > 50_000 {
                // Medium session — transferUserInfo only (sendMessage would fail at ~65 KB)
                sendSessionViaUserInfo(session, sessionData: sessionData)
            } else {
                // Small session — transferUserInfo + sendMessage for immediate delivery
                sendSessionViaUserInfo(session, sessionData: sessionData)
                sendSessionViaMessage(session, base64: base64)
            }
        } catch {
            logger.error("Failed to encode session: \(error.localizedDescription)")
            queuePendingSession(session)
        }
    }

    private func sendSessionViaFileTransfer(_ session: TrainingSession, sessionData: Data) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "session_\(session.id.uuidString).json"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try sessionData.write(to: fileURL)
            let metadata: [String: Any] = [
                "action": "saveSession",
                "sessionID": session.id.uuidString,
                "timestamp": Date().timeIntervalSince1970
            ]
            WCSession.default.transferFile(fileURL, metadata: metadata)
            logger.info("Session queued via transferFile (\(sessionData.count) bytes)")
            updateSyncStatus("Large session queued for file transfer")
        } catch {
            logger.error("Failed to write temp file for transfer: \(error.localizedDescription)")
            queuePendingSession(session)
        }
    }

    private func sendSessionViaUserInfo(_ session: TrainingSession, sessionData: Data) {
        let userInfo: [String: Any] = [
            "action": "saveSession",
            "sessionData": sessionData.base64EncodedString(),
            "timestamp": Date().timeIntervalSince1970,
            "sessionID": session.id.uuidString
        ]

        WCSession.default.transferUserInfo(userInfo)
        logger.info("Session queued via transferUserInfo")
        updateSyncStatus("Session queued for background sync")
    }

    private func sendSessionViaMessage(_ session: TrainingSession, base64: String) {
        guard WCSession.default.isReachable else {
            queuePendingSession(session)
            return
        }
        let message: [String: Any] = [
            "action": "saveSession",
            "sessionData": base64,
            "timestamp": Date().timeIntervalSince1970
        ]
        WCSession.default.sendMessage(message, replyHandler: { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.info("Session sent via sendMessage")
                self.updateSyncStatus("Session saved to iPhone")
                self.consecutiveFailures = 0
                self.lastSyncTime = Date()
                self.removePendingSession(session.id)
                self.updateConnectivityHealth()
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.error("sendMessage failed: \(error.localizedDescription)")
                self.consecutiveFailures += 1
                self.updateConnectivityHealth()
            }
        })
    }

    private func queuePendingSession(_ session: TrainingSession) {
        if !pendingSessions.contains(where: { $0.id == session.id }) {
            pendingSessions.append(session)
            savePendingSessionsToDisk()
            logger.warning("Session queued to disk for retry")
            updateSyncStatus("Session queued for sync")
        }
    }

    // MARK: - Pending Sessions Persistence

    private func removePendingSession(_ id: UUID) {
        pendingSessions.removeAll { $0.id == id }
        savePendingSessionsToDisk()
    }

    private func savePendingSessionsToDisk() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return
        }
        let url = containerURL.appendingPathComponent(pendingSessionsFileName)
        do {
            if pendingSessions.isEmpty {
                try? FileManager.default.removeItem(at: url)
            } else {
                let data = try JSONEncoder().encode(pendingSessions)
                try data.write(to: url)
            }
        } catch {
            logger.error("Failed to save pending sessions: \(error.localizedDescription)")
        }
    }

    private func loadPendingSessionsFromDisk() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return
        }
        let url = containerURL.appendingPathComponent(pendingSessionsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([TrainingSession].self, from: data)
            if !loaded.isEmpty {
                pendingSessions = loaded
                logger.info("Loaded \(loaded.count) pending session(s) from disk")
            }
        } catch {
            logger.error("Failed to load pending sessions: \(error.localizedDescription)")
        }
    }

    // MARK: - App Group Storage

    private func saveSessionToAppGroup(_ session: TrainingSession) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.error("Failed to get App Group container URL")
            return
        }

        let sessionsURL = containerURL.appendingPathComponent("sessions.json")

        do {
            var sessions: [TrainingSession] = []

            if FileManager.default.fileExists(atPath: sessionsURL.path) {
                let data = try Data(contentsOf: sessionsURL)
                sessions = (try? JSONDecoder().decode([TrainingSession].self, from: data)) ?? []
            }

            if !sessions.contains(where: { $0.id == session.id }) {
                sessions.append(session)
                let data = try JSONEncoder().encode(sessions)
                try data.write(to: sessionsURL)
                logger.info("Session saved to App Group")
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            logger.error("Failed to save session to App Group: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isConnected = (activationState == .activated)

            if let error = error {
                self.logger.error("WCSession activation failed: \(error.localizedDescription)")
                self.updateSyncStatus("Connection failed")
                self.consecutiveFailures += 1
            } else if activationState == .activated {
                self.logger.info("WCSession activated")
                self.updateSyncStatus("Connected to iPhone")
                self.consecutiveFailures = 0

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    Task { @MainActor in
                        self?.retryPendingSessions()
                        self?.sendAllStoredSessions()
                    }
                }
            }

            self.updateConnectivityHealth()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isConnected = session.isReachable || session.activationState == .activated
            if session.isReachable {
                self.updateSyncStatus("iPhone became reachable")
                self.retryPendingSessions()
                self.sendAllStoredSessions()
            } else {
                self.updateSyncStatus("iPhone not reachable")
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let action = message["action"] as? String, action == "ping" {
                self.logger.info("Ping received from iPhone")
                self.updateSyncStatus("Connection verified")
                self.consecutiveFailures = 0
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            if let action = message["action"] as? String {
                switch action {
                case "ping":
                    replyHandler(["status": "alive", "timestamp": Date().timeIntervalSince1970])
                    self.updateSyncStatus("Connection verified")
                    self.consecutiveFailures = 0
                case "requestAllSessions":
                    let sessions = self.loadAllLocalSessions()
                    if sessions.isEmpty {
                        replyHandler(["status": "empty", "count": 0])
                    } else {
                        // Send each session individually via size-aware routing
                        for session in sessions {
                            self.sendSessionToiOS(session)
                        }
                        replyHandler(["status": "ok", "count": sessions.count])
                        self.updateSyncStatus("Sent \(sessions.count) session(s) to iPhone (requested)")
                    }
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
                self.logger.error("UserInfo transfer failed: \(error.localizedDescription)")
                self.consecutiveFailures += 1
            } else {
                self.logger.info("UserInfo transfer completed")
                self.consecutiveFailures = 0
                self.lastSyncTime = Date()

                // Remove from pending if it was a session transfer
                if let sessionID = userInfoTransfer.userInfo["sessionID"] as? String,
                   let uuid = UUID(uuidString: sessionID) {
                    self.removePendingSession(uuid)
                }
            }
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.logger.error("File transfer failed: \(error.localizedDescription)")
                self.consecutiveFailures += 1
                if let sessionID = fileTransfer.file.metadata?["sessionID"] as? String {
                    self.logger.info("Will retry session \(sessionID) on next cycle")
                }
            } else {
                self.logger.info("File transfer completed successfully")
                self.consecutiveFailures = 0
                self.lastSyncTime = Date()
                if let sessionID = fileTransfer.file.metadata?["sessionID"] as? String,
                   let uuid = UUID(uuidString: sessionID) {
                    self.removePendingSession(uuid)
                }
            }
            // Clean up temp file
            try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.handleIncomingPayload(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handleIncomingPayload(applicationContext)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.isConnected = false
            self.updateConnectivityHealth()
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.isConnected = false
            WCSession.default.activate()
            self.updateConnectivityHealth()
        }
    }
    #endif

    // MARK: - Bulk Session Sync

    /// Send all locally stored sessions to iPhone via size-aware routing
    func sendAllStoredSessions() {
        let sessions = loadAllLocalSessions()
        guard !sessions.isEmpty else { return }

        logger.info("Sending all \(sessions.count) stored session(s) to iPhone")

        for session in sessions {
            sendSessionToiOS(session)
        }
        updateSyncStatus("Sent \(sessions.count) session(s) to iPhone")
    }

    private func loadAllLocalSessions() -> [TrainingSession] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return []
        }
        let url = containerURL.appendingPathComponent("sessions.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([TrainingSession].self, from: data)
        } catch {
            logger.error("Failed to load local sessions: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Template Sync

    private func handleIncomingPayload(_ payload: [String: Any]) {
        guard let action = payload["action"] as? String else { return }

        switch action {
        case "syncTemplates":
            guard let base64 = payload["templatesData"] as? String,
                  let data = Data(base64Encoded: base64) else {
                logger.error("Failed to decode templates payload")
                return
            }
            do {
                let templates = try JSONDecoder().decode([WorkoutTemplate].self, from: data)
                workoutTemplates = templates
                saveTemplatesToDisk(templates)
                logger.info("Received \(templates.count) template(s) from iPhone")
                updateSyncStatus("Synced \(templates.count) program(s)")
            } catch {
                logger.error("Failed to decode templates: \(error.localizedDescription)")
            }

        case "syncTheme":
            if let themeID = payload["themeID"] as? String {
                ThemeManager.shared.selectTheme(themeID)
                logger.info("Theme synced from iPhone: \(themeID)")
            }

        default:
            break
        }
    }

    private func saveTemplatesToDisk(_ templates: [WorkoutTemplate]) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return }
        let url = containerURL.appendingPathComponent("workout_templates.json")
        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: url)
        } catch {
            logger.error("Failed to save templates to disk: \(error.localizedDescription)")
        }
    }

    private func loadTemplatesFromDisk() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return }
        let url = containerURL.appendingPathComponent("workout_templates.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            workoutTemplates = try JSONDecoder().decode([WorkoutTemplate].self, from: data)
            logger.info("Loaded \(self.workoutTemplates.count) template(s) from disk")
        } catch {
            logger.error("Failed to load templates from disk: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func updateSyncStatus(_ status: String) {
        syncStatus = status
        let timestamp = DateFormatter.shortDateTime.string(from: Date())
        syncLog.insert("[\(timestamp)] \(status)", at: 0)
        if syncLog.count > 20 {
            syncLog = Array(syncLog.prefix(20))
        }
        logger.info("Sync status: \(status)")
    }

    // MARK: - Debug

    func checkConnectivity() -> String {
        let session = WCSession.default
        return """
        Activation State: \(session.activationState.rawValue)
        Reachable: \(session.isReachable)
        Connectivity Health: \(Int(connectivityHealth * 100))%
        Pending Sessions: \(pendingSessions.count)
        Consecutive Failures: \(consecutiveFailures)
        """
    }

    func forceSyncNow() {
        retryPendingSessions()

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                ["action": "ping", "timestamp": Date().timeIntervalSince1970],
                replyHandler: { [weak self] _ in
                    Task { @MainActor in
                        self?.updateSyncStatus("Connection verified")
                        self?.consecutiveFailures = 0
                        self?.updateConnectivityHealth()
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
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}
