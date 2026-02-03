import Foundation
import WatchConnectivity
import os.log

@MainActor
class SharedDataManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = SharedDataManager()
    @Published var syncedPrograms: [TrainingProgram] = []
    @Published var syncStatus: String = "Not synced"
    @Published var isConnected: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncLog: [String] = []

    // Enhanced with fallback mechanisms and health monitoring
    @Published var connectivityHealth: Double = 1.0 // 0.0-1.0 scale
    @Published var backgroundSyncEnabled: Bool = true

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "SharedDataManager")
    private let appGroupIdentifier = "group.com.shuttlx.shared"
    private var retryCount = 0
    private let maxRetries = 5

    // Enhanced sync management
    private var backgroundSyncTimer: Timer?
    private var pendingSessions: [TrainingSession] = []
    private var lastSyncAttempt: Date?
    private var consecutiveFailures = 0

    /// Flag to prevent multiple concurrent retry/sync chains from stacking
    private var isSyncInProgress = false

    /// Queued program sync requests to be sent when session becomes reachable
    private var pendingProgramSyncRequest = false

    /// Timeout duration for sync operations (seconds)
    private let syncTimeoutInterval: TimeInterval = 10.0

    // MARK: - Initialization

    override init() {
        super.init()

        // Set up WatchConnectivity session
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            logger.info("WCSession activated")
        } else {
            logger.warning("WCSession not supported on this device")
        }

        // Load programs from App Group container
        loadPrograms()

        // Setup periodic background tasks
        setupBackgroundTasks()
    }

    deinit {
        backgroundSyncTimer?.invalidate()
    }

    // MARK: - Background Tasks

    private func setupBackgroundTasks() {
        // Periodic sync check (every 15 seconds)
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                if self.backgroundSyncEnabled {
                    self.performBackgroundSync()
                }
            }
        }

        // Initial sync after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            Task { @MainActor in
                self?.syncFromiPhone()
            }
        }
    }

    private func performBackgroundSync() {
        // Check for updated programs
        checkForUpdatedPrograms()

        // Retry sending any pending sessions
        retryPendingSessions()

        // Retry pending program sync requests
        retryPendingProgramSyncRequest()

        // Update connectivity health score
        updateConnectivityHealth()
    }

    private func checkForUpdatedPrograms() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return
        }

        let programsURL = containerURL.appendingPathComponent("programs.json")

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: programsURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date,
               let lastSync = lastSyncTime,
               modificationDate > lastSync {
                logger.info("New program data detected in App Group, reloading...")
                loadPrograms()
            }
        } catch {
            // File might not exist yet, which is normal
            logger.debug("No programs file found in background check")
        }
    }

    private func retryPendingSessions() {
        guard !pendingSessions.isEmpty else { return }

        logger.info("Attempting to sync \(self.pendingSessions.count) pending sessions")

        if WCSession.default.isReachable {
            let sessionsToSync = pendingSessions
            pendingSessions = [] // Clear before attempting sync to avoid duplicates

            for session in sessionsToSync {
                sendSessionToiOS(session)
            }
        } else if let lastAttempt = lastSyncAttempt,
                  Date().timeIntervalSince(lastAttempt) > 300 { // 5 minutes
            // If iPhone has been unreachable for 5+ minutes, save sessions to App Group anyway
            logger.warning("iPhone unreachable for 5+ minutes, saving sessions to App Group only")
            for session in pendingSessions {
                saveSessionToAppGroup(session)
            }
            pendingSessions = []
            updateSyncStatus("Sessions saved locally only")
        }
    }

    /// Retries pending program sync requests when the session becomes reachable
    private func retryPendingProgramSyncRequest() {
        guard pendingProgramSyncRequest else { return }
        guard WCSession.default.isReachable else { return }

        logger.info("Retrying pending program sync request now that session is reachable")
        pendingProgramSyncRequest = false
        syncFromiPhone()
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
            let timeSinceLastSync = Date().timeIntervalSince(lastSync)
            if timeSinceLastSync > 300 { // 5 minutes
                healthScore -= 0.2
            }
        } else {
            healthScore -= 0.2
        }

        // Clamp between 0 and 1
        healthScore = max(0, min(1, healthScore))

        if healthScore != connectivityHealth {
            connectivityHealth = healthScore
            logger.info("Connectivity health updated: \(Int(healthScore * 100))%")
        }
    }

    // MARK: - Program Management

    func loadPrograms() {
        logger.info("Loading programs from App Group container...")

        // Try App Group first
        if let programs = loadProgramsFromAppGroup() {
            self.syncedPrograms = programs
            self.lastSyncTime = Date()
            updateSyncStatus("Loaded \(programs.count) programs")
            logger.info("Successfully loaded \(programs.count) programs from App Group")

            // Clear consecutive failures since we succeeded
            consecutiveFailures = 0
        } else {
            // Try to load from fallback location if App Group fails
            if let programs = loadProgramsFromFallbackLocation() {
                self.syncedPrograms = programs
                self.lastSyncTime = Date()
                updateSyncStatus("Loaded \(programs.count) programs from fallback")
                logger.warning("Using fallback programs storage")
            } else {
                // As a last resort, create sample programs
                let samplePrograms = createSamplePrograms()
                self.syncedPrograms = samplePrograms
                updateSyncStatus("Using sample programs")
                logger.warning("No programs available, using samples")

                // Increment failure count
                consecutiveFailures += 1
            }
        }

        // Update UI immediately
        self.objectWillChange.send()
    }

    private func loadProgramsFromAppGroup() -> [TrainingProgram]? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.error("Failed to get App Group container URL")
            return nil
        }

        let programsURL = containerURL.appendingPathComponent("programs.json")

        do {
            let data = try Data(contentsOf: programsURL)
            return try JSONDecoder().decode([TrainingProgram].self, from: data)
        } catch {
            logger.error("Failed to load programs from App Group: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadProgramsFromFallbackLocation() -> [TrainingProgram]? {
        let fileManager = FileManager.default
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get documents directory for fallback programs")
            return nil
        }
        let fallbackURL = docsURL.appendingPathComponent("backup_programs.json")

        do {
            let data = try Data(contentsOf: fallbackURL)
            return try JSONDecoder().decode([TrainingProgram].self, from: data)
        } catch {
            logger.error("Failed to load programs from fallback: \(error.localizedDescription)")
            return nil
        }
    }

    private func createSamplePrograms() -> [TrainingProgram] {
        return [
            TrainingProgram(
                name: "Beginner Walk-Run",
                type: .walkRun,
                intervals: [
                    TrainingInterval(phase: .rest, duration: 300, intensity: .low),
                    TrainingInterval(phase: .work, duration: 60, intensity: .moderate),
                    TrainingInterval(phase: .rest, duration: 120, intensity: .low),
                    TrainingInterval(phase: .work, duration: 60, intensity: .moderate),
                    TrainingInterval(phase: .rest, duration: 120, intensity: .low),
                    TrainingInterval(phase: .work, duration: 60, intensity: .moderate),
                    TrainingInterval(phase: .rest, duration: 300, intensity: .low)
                ],
                maxPulse: 180,
                createdDate: Date(),
                lastModified: Date()
            ),
            TrainingProgram(
                name: "Quick Test",
                type: .walkRun,
                intervals: [
                    TrainingInterval(phase: .rest, duration: 10, intensity: .low),
                    TrainingInterval(phase: .work, duration: 10, intensity: .moderate)
                ],
                maxPulse: 180,
                createdDate: Date(),
                lastModified: Date()
            )
        ]
    }

    func syncFromiPhone() {
        // Prevent multiple concurrent sync chains from stacking
        guard !isSyncInProgress else {
            logger.info("Sync already in progress, skipping duplicate request")
            return
        }

        logger.info("Starting sync from iPhone...")
        updateSyncStatus("Requesting sync from iPhone...")
        lastSyncAttempt = Date()
        isSyncInProgress = true

        // Always try App Group first - this is reliable and doesn't require connectivity
        let programsBefore = syncedPrograms.count
        loadPrograms()
        let programsAfter = syncedPrograms.count

        if programsAfter > programsBefore {
            logger.info("Loaded \(programsAfter - programsBefore) new programs from App Group")
            updateSyncStatus("Loaded new programs from App Group")
        }

        // Then try WatchConnectivity for real-time sync
        if !verifySessionActive() {
            logger.warning("WatchConnectivity session not active")
            updateSyncStatus("Using App Group data only - session not active")
            isSyncInProgress = false
            return
        }

        guard WCSession.default.isReachable else {
            logger.warning("iPhone not reachable for direct sync")
            updateSyncStatus("Using App Group data - iPhone not reachable")
            // Queue the request for when reachability is restored
            pendingProgramSyncRequest = true
            isSyncInProgress = false
            return
        }

        // Request fresh data from iPhone
        let requestID = UUID().uuidString
        let message: [String: Any] = [
            "action": "requestPrograms",
            "timestamp": Date().timeIntervalSince1970,
            "requestID": requestID
        ]

        logger.info("Sending sync request to iPhone with ID: \(requestID)")
        updateSyncStatus("Requesting latest data from iPhone...")

        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.info("Received sync response for request \(requestID)")
                self.handleSyncResponse(reply)
                self.isSyncInProgress = false
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.error("Sync request failed: \(error.localizedDescription)")
                self.handleSyncError(error)
                // isSyncInProgress is cleared inside handleSyncError after retry scheduling
            }
        })

        // Set a timeout to ensure isSyncInProgress is eventually cleared
        DispatchQueue.main.asyncAfter(deadline: .now() + syncTimeoutInterval) { [weak self] in
            guard let self = self else { return }

            if self.isSyncInProgress {
                self.logger.warning("Sync request timed out after \(self.syncTimeoutInterval)s")
                self.isSyncInProgress = false
                self.updateSyncStatus("Sync timed out - using locally cached data")

                // Load from App Group again as fallback
                self.loadPrograms()
            }
        }
    }

    // Verify session is active and handle activation if needed
    private func verifySessionActive() -> Bool {
        let session = WCSession.default

        if session.activationState == .activated {
            return true
        }

        if session.activationState == .notActivated {
            logger.info("Activating WatchConnectivity session...")
            session.activate()
            return false
        }

        logger.warning("Session in invalid state: \(session.activationState.rawValue)")
        return false
    }

    // MARK: - Session Management

    func sendSessionToiOS(_ session: TrainingSession) {
        logger.info("Sending training session to iOS...")

        // First, save to App Group for reliability
        saveSessionToAppGroup(session)

        // Also save to fallback location
        saveSessionToFallback(session)

        do {
            let sessionData = try JSONEncoder().encode(session)

            // 1. Try sending via WCSession if available
            if WCSession.default.isReachable {
                let message: [String: Any] = [
                    "action": "saveSession",
                    "sessionData": sessionData.base64EncodedString(),
                    "timestamp": Date().timeIntervalSince1970
                ]

                WCSession.default.sendMessage(message, replyHandler: { [weak self] response in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.logger.info("Session sent successfully to iOS")
                        self.updateSyncStatus("Session saved to iPhone")

                        // Update health metrics
                        self.consecutiveFailures = 0
                        self.updateConnectivityHealth()
                    }
                }, errorHandler: { [weak self] error in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.logger.error("Message failed, falling back to transferUserInfo: \(error.localizedDescription)")

                        // Fall back to transferUserInfo (more reliable, but may be delayed)
                        self.sendSessionViaUserInfo(session, sessionData: sessionData)

                        // Update metrics
                        self.consecutiveFailures += 1
                        self.updateConnectivityHealth()
                    }
                })
            } else {
                // If not reachable, store in pending sessions
                if !pendingSessions.contains(where: { $0.id == session.id }) {
                    pendingSessions.append(session)
                    logger.warning("iPhone not reachable, session queued for later sync")
                    updateSyncStatus("Session queued for sync")
                }

                // Also try transferUserInfo which works even when not immediately reachable
                sendSessionViaUserInfo(session, sessionData: sessionData)
            }
        } catch {
            logger.error("Failed to encode session: \(error.localizedDescription)")
            updateSyncStatus("Failed to encode session")

            // Still add to pending for later retry
            if !pendingSessions.contains(where: { $0.id == session.id }) {
                pendingSessions.append(session)
            }
        }
    }

    private func sendSessionViaUserInfo(_ session: TrainingSession, sessionData: Data, transferID: String = UUID().uuidString) {
        let userInfo = [
            "action": "saveSession",
            "sessionData": sessionData.base64EncodedString(),
            "timestamp": Date().timeIntervalSince1970,
            "sessionID": session.id.uuidString,
            "transferID": transferID
        ] as [String : Any]

        WCSession.default.transferUserInfo(userInfo)
        logger.info("Session queued via transferUserInfo (ID: \(transferID))")
        updateSyncStatus("Session queued for background sync")
    }

    private func saveSessionToFallback(_ session: TrainingSession) {
        let fileManager = FileManager.default
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get documents directory for session fallback")
            return
        }
        let fallbackURL = docsURL.appendingPathComponent("fallback_sessions.json")

        do {
            var sessions: [TrainingSession] = []

            // Load existing if available
            if fileManager.fileExists(atPath: fallbackURL.path) {
                let data = try Data(contentsOf: fallbackURL)
                sessions = (try? JSONDecoder().decode([TrainingSession].self, from: data)) ?? []
            }

            // Add if not already there
            if !sessions.contains(where: { $0.id == session.id }) {
                sessions.append(session)
                let data = try JSONEncoder().encode(sessions)
                try data.write(to: fallbackURL)
                logger.info("Session backed up to fallback location")
            }
        } catch {
            logger.error("Failed to save session to fallback: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate Methods

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isConnected = (activationState == .activated)

            if let error = error {
                self.logger.error("WCSession activation failed: \(error.localizedDescription)")
                self.updateSyncStatus("Connection failed: \(error.localizedDescription)")
                self.consecutiveFailures += 1

                // Still try to load from App Group as fallback
                self.loadPrograms()
            } else {
                if activationState == .activated {
                    self.logger.info("WCSession activated successfully")
                    self.updateSyncStatus("Connected to iPhone")
                    self.consecutiveFailures = 0

                    // Always load from App Group first (reliable)
                    self.loadPrograms()

                    // Then attempt to get fresh data after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        Task { @MainActor in
                            self?.syncFromiPhone()
                        }
                    }
                } else if activationState == .inactive {
                    self.logger.warning("WCSession inactive - possibly companion app not running")
                    self.updateSyncStatus("iPhone app may not be running")

                    // Load from App Group as fallback
                    self.loadPrograms()
                } else {
                    self.logger.warning("WCSession in unknown state: \(activationState.rawValue)")
                    self.updateSyncStatus("Connection in unknown state")

                    // Load from App Group as fallback
                    self.loadPrograms()
                }

                // Try to sync any pending sessions after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    Task { @MainActor in
                        self?.retryPendingSessions()
                    }
                }
            }

            self.updateConnectivityHealth()
        }
    }

    /// Handle reachability changes -- retry pending messages/requests when iPhone becomes reachable
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.logger.info("WCSession reachability changed: \(session.isReachable)")
            self.isConnected = session.isReachable

            if session.isReachable {
                self.updateSyncStatus("iPhone became reachable")
                // Retry any queued operations
                self.retryPendingSessions()
                self.retryPendingProgramSyncRequest()
            } else {
                self.updateSyncStatus("iPhone not reachable")
            }

            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.logger.info("Received message from iPhone")

            if let action = message["action"] as? String {
                switch action {
                case "programsUpdated":
                    self.loadPrograms()
                    self.consecutiveFailures = 0
                case "syncPrograms":
                    if let programsData = message["programs"] as? Data {
                        self.handleProgramsData(programsData)
                    } else if let programsString = message["programs"] as? String,
                              let programsData = Data(base64Encoded: programsString) {
                        self.handleProgramsData(programsData)
                    }
                case "ping":
                    self.logger.info("Ping received from iPhone")
                    self.updateSyncStatus("Connection verified")
                    self.consecutiveFailures = 0
                default:
                    self.logger.info("Unknown action: \(action)")
                }
            }

            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            self.logger.info("Received message with reply handler")

            if let action = message["action"] as? String {
                switch action {
                case "requestPrograms":
                    // Send back current programs
                    do {
                        let programsData = try JSONEncoder().encode(self.syncedPrograms)
                        replyHandler([
                            "programs": programsData.base64EncodedString(),
                            "count": self.syncedPrograms.count,
                            "timestamp": Date().timeIntervalSince1970
                        ])
                        self.consecutiveFailures = 0
                    } catch {
                        replyHandler(["error": "Failed to encode programs: \(error.localizedDescription)"])
                        self.logger.error("Failed to encode programs: \(error.localizedDescription)")
                    }
                case "ping":
                    // Simple connectivity check
                    replyHandler(["status": "alive", "timestamp": Date().timeIntervalSince1970])
                    self.updateSyncStatus("Connection verified")
                    self.consecutiveFailures = 0
                default:
                    replyHandler(["error": "Unknown action: \(action)"])
                }
            } else {
                replyHandler(["error": "No action specified"])
            }

            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        Task { @MainActor in
            self.logger.info("Received userInfo from iPhone")

            if let action = userInfo["action"] as? String {
                switch action {
                case "syncPrograms":
                    if let programsString = userInfo["programs"] as? String,
                       let programsData = Data(base64Encoded: programsString) {
                        self.handleProgramsData(programsData)
                    }
                default:
                    self.logger.info("Unknown userInfo action: \(action)")
                }
            }
        }
    }

    /// Handle application context updates (always contains latest data from iOS)
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            self.logger.info("Received application context update from iPhone")

            if let action = applicationContext["action"] as? String,
               action == "syncPrograms",
               let programsString = applicationContext["programs"] as? String,
               let programsData = Data(base64Encoded: programsString) {
                self.handleProgramsData(programsData)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.logger.error("UserInfo transfer failed: \(error.localizedDescription)")
            } else {
                self.logger.info("UserInfo transfer completed successfully")
                self.consecutiveFailures = 0
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.isConnected = false
            self.logger.warning("WCSession became inactive")
            self.updateSyncStatus("Connection inactive")
            self.updateConnectivityHealth()
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.isConnected = false
            self.logger.warning("WCSession deactivated, reactivating...")
            self.updateSyncStatus("Reconnecting...")

            // Always try to reactivate
            WCSession.default.activate()
            self.updateConnectivityHealth()
        }
    }
    #endif

    // MARK: - Private Helper Methods

    private func handleSyncResponse(_ reply: [String: Any]) {
        logger.info("Received sync response")

        if let programsDataString = reply["programs"] as? String,
           let programsData = Data(base64Encoded: programsDataString) {
            handleProgramsData(programsData)
        } else if let programsData = reply["programs"] as? Data {
            handleProgramsData(programsData)
        } else if let error = reply["error"] as? String {
            logger.error("Sync response error: \(error)")
            updateSyncStatus("Sync failed: \(error)")
            consecutiveFailures += 1
            updateConnectivityHealth()
        }
    }

    private func handleSyncError(_ error: Error) {
        logger.error("Sync error: \(error.localizedDescription)")
        consecutiveFailures += 1

        retryCount += 1
        if retryCount < maxRetries {
            // Exponential backoff: 2, 4, 8, 16, 30 seconds max
            let delay = min(pow(2.0, Double(retryCount)), 30.0)
            logger.info("Retrying sync in \(Int(delay))s... (\(self.retryCount)/\(self.maxRetries))")
            updateSyncStatus("Retrying in \(Int(delay))s... (\(self.retryCount)/\(self.maxRetries))")

            // Clear isSyncInProgress before scheduling retry so the retry can proceed
            isSyncInProgress = false

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                Task { @MainActor in
                    self?.syncFromiPhone()
                }
            }
        } else {
            updateSyncStatus("Sync failed after \(maxRetries) attempts")
            retryCount = 0
            isSyncInProgress = false

            // Fall back to loading from App Group
            loadPrograms()
        }

        updateConnectivityHealth()
    }

    private func handleProgramsData(_ data: Data) {
        do {
            let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)

            self.syncedPrograms = programs
            self.lastSyncTime = Date()
            self.retryCount = 0
            self.consecutiveFailures = 0

            updateSyncStatus("Synced \(programs.count) programs")
            logger.info("Successfully synced \(programs.count) programs")

            // Save to both App Group and fallback locations
            savePrograms(programs)
            saveProgramsToFallback(programs)

            // Update UI immediately
            self.objectWillChange.send()

        } catch {
            logger.error("Failed to decode programs: \(error.localizedDescription)")
            updateSyncStatus("Decode failed: \(error.localizedDescription)")
            consecutiveFailures += 1
        }

        updateConnectivityHealth()
    }

    private func savePrograms(_ programs: [TrainingProgram]) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.error("Failed to get App Group container URL for saving")
            return
        }

        let programsURL = containerURL.appendingPathComponent("programs.json")

        do {
            let data = try JSONEncoder().encode(programs)
            try data.write(to: programsURL)
            logger.info("Programs saved to App Group container")
        } catch {
            logger.error("Failed to save programs to App Group: \(error.localizedDescription)")
        }
    }

    private func saveProgramsToFallback(_ programs: [TrainingProgram]) {
        let fileManager = FileManager.default
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get documents directory for programs fallback")
            return
        }
        let fallbackURL = docsURL.appendingPathComponent("backup_programs.json")

        do {
            let data = try JSONEncoder().encode(programs)
            try data.write(to: fallbackURL)
            logger.info("Programs backed up to fallback location")
        } catch {
            logger.error("Failed to save programs to fallback: \(error.localizedDescription)")
        }
    }

    private func updateSyncStatus(_ status: String) {
        syncStatus = status

        // Add to sync log
        let timestamp = DateFormatter.shortDateTime.string(from: Date())
        syncLog.insert("[\(timestamp)] \(status)", at: 0)

        // Keep only last 20 entries
        if syncLog.count > 20 {
            syncLog = Array(syncLog.prefix(20))
        }

        logger.info("Sync status: \(status)")
    }

    private func saveSessionToAppGroup(_ session: TrainingSession) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.error("Failed to get App Group container URL for session save")
            return
        }

        let sessionsURL = containerURL.appendingPathComponent("sessions.json")

        do {
            var sessions: [TrainingSession] = []

            // Load existing sessions if they exist
            if FileManager.default.fileExists(atPath: sessionsURL.path) {
                do {
                    let data = try Data(contentsOf: sessionsURL)
                    sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
                } catch {
                    logger.warning("Couldn't read existing sessions, starting fresh: \(error.localizedDescription)")
                }
            }

            // Check if this session is already saved
            if !sessions.contains(where: { $0.id == session.id }) {
                // Add new session
                sessions.append(session)

                // Save updated sessions
                let data = try JSONEncoder().encode(sessions)
                try data.write(to: sessionsURL)

                logger.info("Session saved to App Group")
            } else {
                logger.info("Session already exists in App Group storage")
            }
        } catch {
            logger.error("Failed to save session to App Group: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Debug/Diagnostic Methods

    func checkConnectivity() -> String {
        let session = WCSession.default
        return """
        Activation State: \(session.activationState.rawValue)
        Reachable: \(session.isReachable)
        Connectivity Health: \(Int(connectivityHealth * 100))%
        App Group Access: \(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil)
        Programs Synced: \(syncedPrograms.count)
        Last Sync: \(lastSyncTime?.description ?? "Never")
        Pending Sessions: \(pendingSessions.count)
        Pending Program Request: \(pendingProgramSyncRequest)
        Sync In Progress: \(isSyncInProgress)
        Consecutive Failures: \(consecutiveFailures)
        """
    }

    func forceSyncNow() {
        // Reset counters to allow a fresh sync
        retryCount = 0
        lastSyncAttempt = nil
        isSyncInProgress = false

        // Attempt immediate sync
        syncFromiPhone()

        // Ping iPhone
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                ["action": "ping", "timestamp": Date().timeIntervalSince1970],
                replyHandler: { [weak self] reply in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.logger.info("Ping reply received")
                        self.updateSyncStatus("Connection verified")
                        self.consecutiveFailures = 0
                        self.updateConnectivityHealth()
                    }
                },
                errorHandler: { [weak self] error in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.logger.error("Ping failed: \(error.localizedDescription)")
                        self.consecutiveFailures += 1
                        self.updateConnectivityHealth()
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
