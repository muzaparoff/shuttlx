@preconcurrency import WatchConnectivity
import Foundation
import Combine

@MainActor
class SharedDataManager: NSObject, ObservableObject, @preconcurrency WCSessionDelegate {
    static let shared = SharedDataManager()
    
    @Published var syncedSessions: [TrainingSession] = []
    @Published var syncLog: [String] = []
    @Published var connectivityHealth: Double = 1.0 // 0.0-1.0 health score
    @Published var lastSyncTime: Date?

    private let programsKey = "programs.json"
    private let sessionsKey = "sessions.json"
    private let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")
    
    // Fallback container for when App Groups is not available (e.g., in simulator without provisioning)
    private var fallbackContainer: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SharedData")
    }
    
    // Enhanced sync management
    private var lastPingTime: Date?
    private var consecutiveFailures = 0
    private var backgroundSyncTimer: Timer?
    private var pendingOperations = [UUID: Date]()
    
    // Weak reference to DataManager to avoid retain cycles
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
    }
    
    deinit {
        backgroundSyncTimer?.invalidate()
    }
    
    // MARK: - Background Tasks
    
    private func setupBackgroundTasks() {
        // Check for new sessions and connectivity health periodically
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.performBackgroundSync()
            }
        }
    }
    
    private func performBackgroundSync() {
        // Check for new sessions in shared storage
        checkForNewSessions()
        
        // Ping watch if we haven't done so recently
        pingWatchIfNeeded()
        
        // Update connectivity health
        updateConnectivityHealth()
        
        // Clean up old pending operations
        cleanupPendingOperations()
    }
    
    private func checkForNewSessions() {
        let newSessions = loadSessionsFromAppGroup()
        
        // Find sessions that aren't in our current array
        let newSessionsToAdd = newSessions.filter { newSession in
            !self.syncedSessions.contains { $0.id == newSession.id }
        }
        
        if !newSessionsToAdd.isEmpty {
            log("📱 Found \(newSessionsToAdd.count) new session(s) in shared storage")
            for session in newSessionsToAdd {
                syncedSessions.append(session)
                
                // Notify DataManager
                if let dataManager = getDataManager() {
                    Task { @MainActor in
                        dataManager.handleReceivedSessions([session])
                    }
                }
            }
        }
    }
    
    private func pingWatchIfNeeded() {
        // If we haven't pinged in the last 5 minutes and watch is reachable, ping it
        if let lastPing = lastPingTime, Date().timeIntervalSince(lastPing) < 300 {
            return // Skip if we recently pinged
        }
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                ["action": "ping", "timestamp": Date().timeIntervalSince1970],
                replyHandler: { [weak self] reply in
                    Task { @MainActor in
                        guard let self = self else { return }
                        if let status = reply["status"] as? String, status == "alive" {
                            self.log("✅ Watch connectivity verified")
                            self.lastPingTime = Date()
                            self.consecutiveFailures = 0
                            self.updateConnectivityHealth()
                        }
                    }
                },
                errorHandler: { [weak self] error in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.log("⚠️ Watch ping failed: \(error.localizedDescription)")
                        self.consecutiveFailures += 1
                        self.updateConnectivityHealth()
                    }
                }
            )
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
        
        if !WCSession.default.isPaired {
            healthScore -= 0.7
        }
        
        if !WCSession.default.isWatchAppInstalled {
            healthScore -= 0.6
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
            log("📊 Connectivity health updated: \(Int(healthScore * 100))%")
        }
    }
    
    private func cleanupPendingOperations() {
        let now = Date()
        let expiredKeys = pendingOperations.filter { now.timeIntervalSince($0.value) > 300 }.keys
        
        for key in expiredKeys {
            pendingOperations.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
            log("🧹 Cleaned up \(expiredKeys.count) expired pending operations")
        }
    }
    
    // MARK: - DataManager Integration
    func setDataManager(_ dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    private func getDataManager() -> DataManager? {
        return dataManager
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "\(timestamp): \(message)"
        print(logMessage)
        syncLog.insert(logMessage, at: 0)
        if syncLog.count > 100 {
            syncLog.removeLast()
        }
    }
    
    // MARK: - Program Sync
    func syncProgramsToWatch(_ programs: [TrainingProgram]) {
        log("📱➡️⌚ Syncing \(programs.count) programs to watch.")
        
        // Enhanced WatchConnectivity session diagnostics
        let sessionStatus = getSessionStatus()
        log("📱 Session Status: \(sessionStatus)")
        
        // Save to App Groups first (always works)
        saveProgramsToSharedStorage(programs)
        
        // Also save to fallback location
        saveProgramsToFallback(programs)
        
        // Enhanced session activation check
        if !ensureSessionActivated() {
            log("❌ Session activation failed, sync may not work optimally")
            consecutiveFailures += 1
            // Still continue with the other methods
        }
        
        // Try WatchConnectivity with enhanced reliability
        sendProgramsToWatchWithRetry(programs)
        
        // Update connectivity health
        updateConnectivityHealth()
        
        // Track this sync operation
        let operationID = UUID()
        pendingOperations[operationID] = Date()
        
        // Debug: Print program details
        for (index, program) in programs.enumerated() {
            log("📱 Program \(index + 1): \(program.name) - \(program.intervals.count) intervals")
        }
        
        // Set last sync time
        lastSyncTime = Date()
    }
    
    private func getSessionStatus() -> String {
        let session = WCSession.default
        return """
        Activation: \(session.activationState.rawValue)
        Reachable: \(session.isReachable)
        Paired: \(session.isPaired)
        AppInstalled: \(session.isWatchAppInstalled)
        Health: \(Int(connectivityHealth * 100))%
        """
    }
    
    private func ensureSessionActivated() -> Bool {
        let session = WCSession.default
        
        if session.activationState == .activated {
            return true
        }
        
        if session.activationState == .notActivated {
            log("🔄 Activating WatchConnectivity session...")
            session.activate()
            
            // Wait briefly for activation (blocking approach for critical sync)
            let semaphore = DispatchSemaphore(value: 0)
            var activated = false
            
            // Set up a timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                semaphore.signal()
            }
            
            // Monitor activation state
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if session.activationState == .activated {
                    activated = true
                    timer.invalidate()
                    semaphore.signal()
                }
            }
            
            semaphore.wait()
            timer.invalidate()
            
            if activated {
                log("✅ Session activated successfully")
                consecutiveFailures = 0
                return true
            } else {
                log("⚠️ Session activation timeout")
                consecutiveFailures += 1
                return false
            }
        }
        
        return false
    }
    
    private func sendProgramsToWatchWithRetry(_ programs: [TrainingProgram], attempt: Int = 1) {
        guard session.activationState == .activated else {
            log("❌ WC Session not activated. State: \(session.activationState.rawValue)")
            return
        }
        
        // Use multiple methods to maximize reliability
        do {
            let encodedData = try JSONEncoder().encode(programs)
            let encodedString = encodedData.base64EncodedString()
            
            let userInfo: [String: Any] = [
                "action": "syncPrograms",
                "programs": encodedString,
                "timestamp": Date().timeIntervalSince1970,
                "count": programs.count,
                "attempt": attempt
            ]
            
            // Method 1: transferUserInfo (reliable, works when watch is locked)
            session.transferUserInfo(userInfo)
            log("✅ Sent programs via transferUserInfo (attempt \(attempt))")
            
            // Method 2: updateApplicationContext (overwrites previous context but ensures latest data)
            do {
                try session.updateApplicationContext([
                    "action": "syncPrograms",
                    "programs": encodedString,
                    "timestamp": Date().timeIntervalSince1970,
                    "count": programs.count
                ])
                log("✅ Updated application context with latest programs")
            } catch {
                log("⚠️ Failed to update application context: \(error.localizedDescription)")
            }
            
            // Method 3: immediate message if watch is reachable
            if session.isReachable {
                session.sendMessage(userInfo, replyHandler: { reply in
                    Task { @MainActor in
                        self.log("✅ Immediate message sent successfully")
                        self.consecutiveFailures = 0
                        
                        // Success - remove from pending operations
                        if let operationID = reply["operationID"] as? UUID {
                            self.pendingOperations.removeValue(forKey: operationID)
                        }
                    }
                }, errorHandler: { error in
                    Task { @MainActor in
                        self.log("⚠️ Immediate message failed: \(error.localizedDescription)")
                        self.consecutiveFailures += 1
                        
                        // Retry with exponential backoff if this is not the final attempt
                        if attempt < 5 { // Increased from 3 to 5 max retries
                            let delay = min(pow(2.0, Double(attempt)), 30.0) // Exponential backoff: 2, 4, 8, 16, 30 seconds max
                            self.log("🔄 Will retry in \(Int(delay))s (attempt \(attempt)/5)")
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                self.sendProgramsToWatchWithRetry(programs, attempt: attempt + 1)
                            }
                        } else {
                            self.log("⚠️ Failed after 5 attempts, but programs are saved to App Group")
                            // Even if immediate sync fails, watch will pick up from App Group eventually
                        }
                    }
                })
            } else {
                log("⚠️ Watch not reachable for immediate message, using transferUserInfo only")
                // Not an error, just informational. Watch will get updates when it becomes available
            }
        } catch {
            log("❌ Failed to encode programs for transfer: \(error)")
            consecutiveFailures += 1
        }
    }

    private func saveProgramsToSharedStorage(_ programs: [TrainingProgram]) {
        guard let containerURL = getWorkingContainer() else {
            log("❌ No valid container URL available.")
            return
        }
        
        let url = containerURL.appendingPathComponent(programsKey)
        do {
            let encodedData = try JSONEncoder().encode(programs)
            try encodedData.write(to: url)
            log("✅ Saved \(programs.count) programs to shared storage.")
        } catch {
            log("❌ Failed to save programs to shared storage: \(error)")
        }
    }

    private func saveProgramsToFallback(_ programs: [TrainingProgram]) {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fallbackURL = docsURL.appendingPathComponent("backup_programs.json")
        
        do {
            let data = try JSONEncoder().encode(programs)
            try data.write(to: fallbackURL)
            log("✅ Programs backed up to fallback location")
        } catch {
            log("❌ Failed to save programs to fallback: \(error)")
        }
    }

    // MARK: - Session Sync
    func handleReceivedSession(_ session: TrainingSession) {
        if !syncedSessions.contains(where: { $0.id == session.id }) {
            syncedSessions.append(session)
            saveSessionsToSharedStorage(syncedSessions)
            
            // Also save to fallback location
            saveSessionsToFallback(syncedSessions)
            
            log("✅ New session received and saved.")
            
            // Reset failures since we successfully received data
            consecutiveFailures = 0
            lastSyncTime = Date()
            updateConnectivityHealth()
        } else {
            log("ℹ️ Received duplicate session, ignoring.")
        }
    }
    
    private func saveSessionsToSharedStorage(_ sessions: [TrainingSession]) {
        guard let containerURL = getWorkingContainer() else {
            log("❌ No valid container URL available.")
            return
        }
        
        let url = containerURL.appendingPathComponent(sessionsKey)
        do {
            let encodedData = try JSONEncoder().encode(sessions)
            try encodedData.write(to: url)
            log("✅ Saved \(sessions.count) sessions to shared storage.")
        } catch {
            log("❌ Failed to save sessions to shared storage: \(error)")
        }
    }
    
    private func saveSessionsToFallback(_ sessions: [TrainingSession]) {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fallbackURL = docsURL.appendingPathComponent("backup_sessions.json")
        
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fallbackURL)
            log("✅ Sessions backed up to fallback location")
        } catch {
            log("❌ Failed to save sessions to fallback: \(error)")
        }
    }

    private func loadSessionsFromSharedStorage() {
        // Try App Group first
        let appGroupSessions = loadSessionsFromAppGroup()
        if !appGroupSessions.isEmpty {
            self.syncedSessions = appGroupSessions
            log("✅ Loaded \(appGroupSessions.count) sessions from App Group.")
            return
        }
        
        // Fall back to fallback location if App Group fails
        let fallbackSessions = loadSessionsFromFallback()
        if !fallbackSessions.isEmpty {
            self.syncedSessions = fallbackSessions
            log("⚠️ Using fallback sessions: \(fallbackSessions.count) sessions loaded.")
            // Copy to App Group for future access
            saveSessionsToSharedStorage(fallbackSessions)
            return
        }
        
        log("ℹ️ No saved sessions found in any location.")
    }
    
    private func loadSessionsFromAppGroup() -> [TrainingSession] {
        guard let containerURL = getWorkingContainer() else {
            log("⚠️ No valid container URL available for loading sessions")
            return []
        }
        
        let url = containerURL.appendingPathComponent(sessionsKey)
        do {
            let data = try Data(contentsOf: url)
            let sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            log("✅ Loaded \(sessions.count) sessions from App Group.")
            return sessions
        } catch {
            log("⚠️ Failed to load sessions from App Group: \(error)")
            return []
        }
    }
    
    private func loadSessionsFromFallback() -> [TrainingSession] {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fallbackURL = docsURL.appendingPathComponent("backup_sessions.json")
        
        do {
            let data = try Data(contentsOf: fallbackURL)
            let sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            log("✅ Loaded \(sessions.count) sessions from fallback location")
            return sessions
        } catch {
            log("⚠️ Failed to load sessions from fallback: \(error)")
            return []
        }
    }

    // MARK: - Public accessors for Debugging
    func loadProgramsFromAppGroup() -> [TrainingProgram] {
        guard let containerURL = getWorkingContainer() else {
            log("⚠️ [Debug] No valid container URL available")
            return []
        }
        
        let url = containerURL.appendingPathComponent(programsKey)
        do {
            let data = try Data(contentsOf: url)
            let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            log("✅ [Debug] Loaded \(programs.count) programs from storage")
            return programs
        } catch {
            log("⚠️ [Debug] Failed to load programs from storage: \(error)")
            return []
        }
    }

    // MARK: - Public Debug/Diagnostic Methods
    
    func checkConnectivity() -> String {
        let session = WCSession.default
        return """
        Activation State: \(session.activationState.rawValue)
        Reachable: \(session.isReachable)
        Paired: \(session.isPaired)
        App Installed: \(session.isWatchAppInstalled)
        Connectivity Health: \(Int(connectivityHealth * 100))%
        App Group Access: \(getWorkingContainer() != nil)
        Sessions Synced: \(syncedSessions.count)
        Last Sync: \(lastSyncTime?.description ?? "Never")
        Consecutive Failures: \(consecutiveFailures)
        Pending Operations: \(pendingOperations.count)
        """
    }
    
    func forceSyncNow(_ programs: [TrainingProgram]? = nil) {
        // Reset counters
        consecutiveFailures = 0
        
        // Force activation if needed
        _ = ensureSessionActivated()
        
        // Get programs to sync
        let programsToSync: [TrainingProgram]
        if let programs = programs {
            programsToSync = programs
        } else if let dataManager = getDataManager() {
            programsToSync = dataManager.programs
        } else {
            log("⚠️ No programs available to sync")
            return
        }
        
        // Perform sync with fresh attempt counter
        syncProgramsToWatch(programsToSync)
        
        // Update status
        log("🔄 Force sync initiated with \(programsToSync.count) programs")
    }
    
    func clearAndReloadSessions() {
        // Load from all possible sources and combine
        var allSessions = Set<TrainingSession>()
        
        // From App Group
        loadSessionsFromAppGroup().forEach { allSessions.insert($0) }
        
        // From fallback
        loadSessionsFromFallback().forEach { allSessions.insert($0) }
        
        // Update syncedSessions with all unique sessions
        syncedSessions = Array(allSessions)
        
        // Save combined list to both storage locations
        saveSessionsToSharedStorage(syncedSessions)
        saveSessionsToFallback(syncedSessions)
        
        log("🔄 Reloaded \(syncedSessions.count) unique sessions from all sources")
    }
}

// MARK: - WCSessionDelegate
extension SharedDataManager {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                log("❌ WC Session activation failed: \(activationState.rawValue), error: \(error.localizedDescription)")
                consecutiveFailures += 1
            } else {
                log("✅ WC Session activated with state: \(activationState.rawValue)")
                consecutiveFailures = 0
                
                // Try to resync immediately after successful activation
                if let dataManager = getDataManager(), activationState == .activated {
                    syncProgramsToWatch(dataManager.programs)
                }
            }
            
            updateConnectivityHealth()
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            log("📱 WC Session became inactive.")
            updateConnectivityHealth()
        }
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            log("📱 WC Session deactivated, reactivating...")
            session.activate()
            updateConnectivityHealth()
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        Task { @MainActor in
            log("📦 Received userInfo from watch: \(userInfo.keys.joined(separator: ", "))")
            
            if let action = userInfo["action"] as? String,
               action == "saveSession",
               let sessionDataString = userInfo["sessionData"] as? String,
               let sessionData = Data(base64Encoded: sessionDataString) {
                do {
                    let trainingSession = try JSONDecoder().decode(TrainingSession.self, from: sessionData)
                    handleReceivedSession(trainingSession)
                    log("✅ Received and processed training session from watch via userInfo")
                } catch {
                    log("❌ Failed to decode training session from userInfo: \(error.localizedDescription)")
                    consecutiveFailures += 1
                }
            }
            
            updateConnectivityHealth()
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            log("📥 Received message on iOS: \(message.keys.joined(separator: ", "))")
            
            if let action = message["action"] as? String {
                switch action {
                case "saveSession":
                    if let sessionDataString = message["sessionData"] as? String,
                       let sessionData = Data(base64Encoded: sessionDataString) {
                        do {
                            let trainingSession = try JSONDecoder().decode(TrainingSession.self, from: sessionData)
                            handleReceivedSession(trainingSession)
                            log("✅ Received and processed training session from watch")
                            consecutiveFailures = 0
                        } catch {
                            log("❌ Failed to decode training session: \(error.localizedDescription)")
                            consecutiveFailures += 1
                        }
                    }
                case "requestPrograms":
                    // Handle watch requesting programs
                    log("⌚️ Received request for programs from watch")
                    if let dataManager = getDataManager() {
                        syncProgramsToWatch(dataManager.programs)
                    }
                case "ping":
                    log("📍 Ping received from watch")
                    consecutiveFailures = 0
                default:
                    log("ℹ️ Received unknown action: \(action)")
                }
            }
            
            updateConnectivityHealth()
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            log("📥 Received message with reply handler: \(message.keys.joined(separator: ", "))")
            
            if let action = message["action"] as? String {
                switch action {
                case "requestPrograms":
                    // Handle watch requesting programs with reply
                    if let dataManager = getDataManager() {
                        do {
                            let programs = dataManager.programs
                            let encodedData = try JSONEncoder().encode(programs)
                            let reply = [
                                "programs": encodedData.base64EncodedString(),
                                "count": programs.count,
                                "timestamp": Date().timeIntervalSince1970
                            ] as [String : Any]
                            
                            // Record this successful interaction
                            lastSyncTime = Date()
                            consecutiveFailures = 0
                            replyHandler(reply)
                            
                            log("✅ Sent \(programs.count) programs to watch via reply")
                        } catch {
                            log("❌ Failed to encode programs for reply: \(error)")
                            consecutiveFailures += 1
                            replyHandler(["error": error.localizedDescription])
                        }
                    } else {
                        log("❌ No DataManager available")
                        consecutiveFailures += 1
                        replyHandler(["error": "No DataManager available"])
                    }
                case "ping":
                    // Simple connectivity verification
                    replyHandler([
                        "status": "alive",
                        "timestamp": Date().timeIntervalSince1970,
                        "appState": "foreground"
                    ])
                    log("📍 Responded to watch ping")
                    consecutiveFailures = 0
                default:
                    replyHandler(["error": "Unknown action: \(action)"])
                }
            } else {
                replyHandler(["error": "No action specified"])
            }
            
            updateConnectivityHealth()
        }
    }
    
    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                log("❌ UserInfo transfer failed: \(error.localizedDescription)")
                consecutiveFailures += 1
            } else {
                log("✅ UserInfo transfer completed successfully")
                consecutiveFailures = 0
            }
            updateConnectivityHealth()
        }
    }
}

// MARK: - Container Management
extension SharedDataManager {
    private func getWorkingContainer() -> URL? {
        // First try the App Group container
        if let appGroupContainer = sharedContainer {
            // Check if the directory exists or can be created
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            
            if fileManager.fileExists(atPath: appGroupContainer.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                return appGroupContainer
            } else {
                // Try to create the App Group directory
                do {
                    try fileManager.createDirectory(at: appGroupContainer, withIntermediateDirectories: true, attributes: nil)
                    log("✅ Created App Group container directory")
                    return appGroupContainer
                } catch {
                    log("⚠️ Failed to create App Group container, using fallback: \(error.localizedDescription)")
                }
            }
        }
        
        // Fallback to Documents directory
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: fallbackContainer, withIntermediateDirectories: true, attributes: nil)
            log("ℹ️ Using fallback container: \(fallbackContainer.path)")
            return fallbackContainer
        } catch {
            log("❌ Failed to create fallback container: \(error.localizedDescription)")
            return nil
        }
    }
}
