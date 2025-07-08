import WatchConnectivity
import Foundation
import Combine
import os.log

@MainActor
class SharedDataManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = SharedDataManager()
    
    @Published var syncedSessions: [TrainingSession] = []
    @Published var syncLog: [String] = []
    @Published var connectivityHealth: Double = 1.0 // 0.0-1.0 health score
    @Published var lastSyncTime: Date?
    
    private var consecutiveFailures: Int = 0
    private var pendingOperations: [String: Any] = [:]
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "SharedDataManager")

    private let programsKey = "programs.json"
    private let sessionsKey = "sessions.json"
    private let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.ShuttlX")
    
    // Fallback container for when App Groups is not available (e.g., in simulator without provisioning)
    private var fallbackContainer: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SharedData")
    }
    
    // Enhanced sync management
    private var lastPingTime: Date?
    private var backgroundSyncTimer: Timer?
    
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
        // FIXED: Delay timer setup to avoid startup contention which could cause UI freezes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            print("⏱️ Setting up background sync timer (delayed start)")
            self.backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                // Use detached task to prevent MainActor contention
                Task.detached {
                    await MainActor.run {
                        self.performBackgroundSync()
                    }
                }
            }
        }
    }
    
    private func performBackgroundSync() {
        // FIXED: Add safety check for Main Thread to prevent potential deadlocks
        if !Thread.isMainThread {
            // We're supposed to be on the main thread since this is a @MainActor method
            // Schedule work properly on main thread to avoid deadlocks
            DispatchQueue.main.async { [weak self] in
                self?.performBackgroundSync()
            }
            return
        }
        
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
        let expiredKeys = pendingOperations.filter { 
            if let date = $0.value as? Date {
                return now.timeIntervalSince(date) > 300
            }
            return true // Remove any non-Date values
        }.keys
        
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

    // MARK: - Helper Functions
    
    private func log(_ message: String) {
        logger.info("\(message)")
        syncLog.append("[\(dateFormatter.string(from: Date()))] \(message)")
        if syncLog.count > 100 {
            syncLog.removeFirst()
        }
        
        // Print to console for debugging
        print("📱 \(message)")
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }
    
    private func getWorkingContainer() -> URL? {
        // Try shared container first
        if let container = sharedContainer {
            return container
        }
        
        // Fallback to local documents directory
        do {
            try FileManager.default.createDirectory(at: fallbackContainer, withIntermediateDirectories: true)
            return fallbackContainer
        } catch {
            log("❌ Failed to create fallback container: \(error)")
            return nil
        }
    }
    
    // Secondary updateConnectivityHealth implementation removed
    
    // MARK: - Program Sync
    func syncProgramsToWatch(_ programs: [TrainingProgram]) {
        log("📱➡️⌚ Syncing \(programs.count) programs to watch.")
        
        // Always check pairing and show user feedback if needed
        if !checkWatchAppAvailability() {
            log("⚠️ Watch app not installed or paired - sync will use App Groups only")
            NotificationCenter.default.post(name: NSNotification.Name("WatchSyncStatus"), 
                                            object: nil, 
                                            userInfo: ["status": "watchNotAvailable"])
            // Still save to App Groups as fallback
            saveProgramsToSharedStorage(programs)
            saveProgramsToFallback(programs)
            return
        }
        
        // Enhanced WatchConnectivity session diagnostics
        let sessionStatus = getSessionStatus()
        log("📱 Session Status: \(sessionStatus)")
        
        // Save to App Groups first (always works)
        saveProgramsToSharedStorage(programs)
        
        // Also save to fallback location
        saveProgramsToFallback(programs)
        
        // Enhanced session activation check with improved waiting logic
        let activated = waitForSessionActivation(timeout: 5.0)
        if !activated {
            log("❌ Session activation failed or timed out - using App Groups only")
            NotificationCenter.default.post(name: NSNotification.Name("WatchSyncStatus"), 
                                           object: nil, 
                                           userInfo: ["status": "activationFailed"])
            consecutiveFailures += 1
            return
        }
        
        // Try WatchConnectivity with enhanced reliability only if session is activated
        sendProgramsToWatchWithRetry(programs)
        
        // Update connectivity health
        updateConnectivityHealth()
        
        // Track this sync operation
        let operationID = UUID()
        let operationKey = operationID.uuidString
        pendingOperations[operationKey] = Date()
        
        // Debug: Print program details
        for (index, program) in programs.enumerated() {
            log("📱 Program \(index + 1): \(program.name) - \(program.intervals.count) intervals")
        }
        
        // Set last sync time
        lastSyncTime = Date()
        
        // Notify UI of successful sync attempt
        NotificationCenter.default.post(name: NSNotification.Name("WatchSyncStatus"), 
                                       object: nil, 
                                       userInfo: ["status": "syncAttempted"])
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
    
    // Check if the watch app is available and paired
    private func checkWatchAppAvailability() -> Bool {
        let session = WCSession.default
        
        // Check if watch app is installed
        guard session.isWatchAppInstalled else {
            log("❌ Watch app is not installed")
            return false
        }
        
        // Check if watch is paired
        guard session.isPaired else {
            log("❌ Watch is not paired with this iPhone")
            return false
        }
        
        log("✅ Watch app is installed and paired")
        return true
    }
    
    // New implementation with better waiting logic
    private func waitForSessionActivation(timeout: TimeInterval) -> Bool {
        let session = WCSession.default
        
        // Already activated
        if session.activationState == .activated {
            log("✅ Session already activated")
            return true
        }
        
        // Activate if not activated yet
        if session.activationState == .notActivated {
            log("🔄 Activating WatchConnectivity session...")
            session.activate()
        } else if session.activationState == .inactive {
            log("⚠️ Session inactive - possibly Apple Watch is not reachable")
        }
        
        // Create a more robust waiting mechanism
        let startTime = Date()
        
        // Use a dispatch group for cleaner waiting
        let waitGroup = DispatchGroup()
        waitGroup.enter()
        
        // Flag for activation success
        var activationSuccess = false
        
        // Check activation periodically
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if session.activationState == .activated {
                activationSuccess = true
                timer.invalidate()
                waitGroup.leave()
            } else if Date().timeIntervalSince(startTime) > timeout {
                // Timeout reached
                timer.invalidate()
                waitGroup.leave()
            }
        }
        
        // Wait with timeout
        let result = waitGroup.wait(timeout: .now() + timeout)
        
        if activationSuccess {
            log("✅ Session successfully activated")
            consecutiveFailures = 0
            return true
        } else {
            if result == .timedOut {
                log("⚠️ Session activation timed out after \(timeout) seconds")
            } else {
                log("⚠️ Session activation failed with state: \(session.activationState.rawValue)")
            }
            consecutiveFailures += 1
            return false
        }
        
        return false
    }
    
    private func sendProgramsToWatchWithRetry(_ programs: [TrainingProgram], attempt: Int = 1) {
        guard session.activationState == .activated else {
            log("❌ WC Session not activated. State: \(session.activationState.rawValue)")
            NotificationCenter.default.post(name: NSNotification.Name("WatchSyncStatus"), 
                                           object: nil, 
                                           userInfo: ["status": "notActivated"])
            return
        }
        
        // Verify watch reachability
        if !session.isReachable && attempt == 1 {
            log("⚠️ Watch is currently not reachable - will use reliable methods and retry")
            NotificationCenter.default.post(name: NSNotification.Name("WatchSyncStatus"), 
                                           object: nil, 
                                           userInfo: ["status": "watchNotReachable"])
            // Continue anyway since transferUserInfo works even when watch is not reachable
        }
        
        // Create a unique operation ID for tracking
        let operationID = UUID()
        
        // Use multiple methods to maximize reliability
        do {
            let encodedData = try JSONEncoder().encode(programs)
            let encodedString = encodedData.base64EncodedString()
            
            let userInfo: [String: Any] = [
                "action": "syncPrograms",
                "programs": encodedString,
                "timestamp": Date().timeIntervalSince1970,
                "count": programs.count,
                "attempt": attempt,
                "operationID": operationID.uuidString,
                "checksum": calculateChecksum(for: encodedData) // Add checksum for verification
            ]
            
            // Track this sync operation
            let operationKey = operationID.uuidString
            pendingOperations[operationKey] = Date()
            
            // Method 1: transferUserInfo (reliable, works when watch is locked)
            session.transferUserInfo(userInfo)
            log("✅ Sent programs via transferUserInfo (attempt \(attempt), ID: \(operationID.uuidString))")
            
            // Method 2: updateApplicationContext (overwrites previous context but ensures latest data)
            do {
                try session.updateApplicationContext([
                    "action": "syncPrograms",
                    "programs": encodedString,
                    "timestamp": Date().timeIntervalSince1970,
                    "count": programs.count,
                    "operationID": operationID.uuidString,
                    "checksum": calculateChecksum(for: encodedData)
                ])
                log("✅ Updated application context with latest programs (ID: \(operationID.uuidString))")
            } catch {
                log("⚠️ Failed to update application context: \(error.localizedDescription)")
            }
            
            // Method 3: immediate message if watch is reachable
            if session.isReachable {
                session.sendMessage(userInfo, replyHandler: { reply in
                    Task { @MainActor in
                        self.log("✅ Immediate message sent successfully with reply: \(reply)")
                        self.consecutiveFailures = 0
                        
                        // Success notification
                        NotificationCenter.default.post(name: NSNotification.Name("WatchSyncStatus"), 
                                                      object: nil, 
                                                      userInfo: ["status": "syncSuccessful"])
                        
                        // Remove from pending operations
                        let operationKey = operationID.uuidString
                        self.pendingOperations.removeValue(forKey: operationKey)
                    }
                }, errorHandler: { error in
                    Task { @MainActor in
                        self.log("⚠️ Immediate message failed: \(error.localizedDescription)")
                        self.consecutiveFailures += 1
                        
                        // Retry with exponential backoff if this is not the final attempt
                        if attempt < 5 { // Maximum 5 retries
                            let delay = min(pow(2.0, Double(attempt)), 30.0) // Exponential backoff: 2, 4, 8, 16, 30 seconds max
                            self.log("🔄 Will retry in \(Int(delay))s (attempt \(attempt)/5)")
                            
                            NotificationCenter.default.post(name: NSNotification.Name("WatchSyncStatus"), 
                                                          object: nil, 
                                                          userInfo: ["status": "retrying", 
                                                                    "attempt": attempt,
                                                                    "nextAttemptIn": delay])
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                self.sendProgramsToWatchWithRetry(programs, attempt: attempt + 1)
                            }
                        } else {
                            self.log("⚠️ Failed after 5 attempts, but programs are saved to App Group")
                            NotificationCenter.default.post(name: NSNotification.Name("WatchSyncStatus"), 
                                                          object: nil, 
                                                          userInfo: ["status": "retriesExhausted"])
                            // Even if immediate sync fails, watch will pick up from App Group eventually
                        }
                    }
                })
            } else {
                log("⚠️ Watch not reachable for immediate message, using transferUserInfo only")
                
                // Schedule a sync check
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    let operationKey = operationID.uuidString
                    if self.pendingOperations[operationKey] != nil {
                        self.log("🔍 Checking if sync operation \(operationID.uuidString) completed...")
                        // Still pending after 10s, might need retry
                        if attempt < 3 {
                            self.log("🔄 Auto-retrying sync operation")
                            self.sendProgramsToWatchWithRetry(programs, attempt: attempt + 1)
                        }
                    }
                }
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
    
    func loadSessionsFromAppGroup() -> [TrainingSession] {
        guard let containerURL = getWorkingContainer() else {
            log("⚠️ [Debug] No valid container URL available")
            return []
        }
        
        do {
            let url = containerURL.appendingPathComponent(sessionsKey)
            let data = try Data(contentsOf: url)
            let sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            log("✅ [Debug] Loaded \(sessions.count) sessions from storage")
            return sessions
        } catch {
            log("⚠️ [Debug] Failed to load sessions from storage: \(error)")
            return []
        }
    }

    // Load sessions from fallback storage (if App Group container is not available)
    private func loadSessionsFromFallback() -> [TrainingSession] {
        var fallbackSessions: [TrainingSession] = []
        
        do {
            let fallbackURL = fallbackContainer.appendingPathComponent(sessionsKey)
            if FileManager.default.fileExists(atPath: fallbackURL.path) {
                let data = try Data(contentsOf: fallbackURL)
                fallbackSessions = try JSONDecoder().decode([TrainingSession].self, from: data)
                log("📥 Loaded \(fallbackSessions.count) sessions from fallback storage")
            }
        } catch {
            log("⚠️ Failed to load sessions from fallback: \(error.localizedDescription)")
        }
        
        return fallbackSessions
    }
    
    // MARK: - Public accessors for Debugging
    func loadProgramsFromAppGroup() -> [TrainingProgram] {
        guard let containerURL = getWorkingContainer() else {
            log("⚠️ [Debug] No valid container URL available")
            return []
        }
        
        do {
            let url = containerURL.appendingPathComponent(programsKey)
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
        allSessions.formUnion(Set(loadSessionsFromFallback()))
        
        // Update syncedSessions with all unique sessions
        syncedSessions = Array(allSessions)
        
        // Save combined list to both storage locations
        saveSessionsToSharedStorage(syncedSessions)
        saveSessionsToFallback(syncedSessions)
        
        log("🔄 Reloaded \(syncedSessions.count) unique sessions from all sources")
    }
    
    // Ensure the WCSession is activated and ready
    private func ensureSessionActivated() -> Bool {
        if WCSession.isSupported() {
            let session = WCSession.default
            if session.activationState != .activated {
                session.delegate = self
                session.activate()
                log("🔄 WCSession activation requested")
                return false
            }
            return session.activationState == .activated
        }
        return false
    }
}

// MARK: - WCSessionDelegate
extension SharedDataManager {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                log("❌ WC Session activation failed: \(activationState.rawValue), error: \(error.localizedDescription)")
                consecutiveFailures += 1
                
                // Notify UI of activation failure
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchSessionStatus"),
                    object: nil,
                    userInfo: [
                        "status": "activationFailed",
                        "error": error.localizedDescription,
                        "activationState": activationState.rawValue
                    ]
                )
            } else {
                log("✅ WC Session activated with state: \(activationState.rawValue)")
                consecutiveFailures = 0
                
                // Notify UI of successful activation
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchSessionStatus"),
                    object: nil,
                    userInfo: [
                        "status": "activated",
                        "activationState": activationState.rawValue
                    ]
                )
                
                // Try to resync immediately after successful activation
                if let dataManager = getDataManager(), activationState == .activated {
                    // Small delay to ensure session is fully ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.syncProgramsToWatch(dataManager.programs)
                    }
                }
            }
            
            updateConnectivityHealth()
        }
    }
    
    // Handle session reachability changes
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            log("📱 Watch reachability changed: \(session.isReachable)")
            
            // Notify UI of reachability change
            NotificationCenter.default.post(
                name: NSNotification.Name("WatchSessionStatus"),
                object: nil,
                userInfo: [
                    "status": "reachabilityChanged",
                    "isReachable": session.isReachable
                ]
            )
            
            // If watch becomes reachable, try to sync
            if session.isReachable {
                log("📱 Watch became reachable - attempting sync")
                if let dataManager = getDataManager() {
                    // Small delay to ensure reachability is stable
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.syncProgramsToWatch(dataManager.programs)
                    }
                }
            }
            
            updateConnectivityHealth()
        }
    }
    
    // Handle watch state changes
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            log("📱 Watch state changed - isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled)")
            
            // Notify UI of watch state change
            NotificationCenter.default.post(
                name: NSNotification.Name("WatchSessionStatus"),
                object: nil,
                userInfo: [
                    "status": "watchStateChanged",
                    "isPaired": session.isPaired,
                    "isWatchAppInstalled": session.isWatchAppInstalled
                ]
            )
            
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
    // Second implementation of getWorkingContainer removed - using the one at line 216
}

// Calculate checksum for data verification
private func calculateChecksum(for data: Data) -> String {
    // Simple XOR-based checksum for verification
    var checksum: UInt32 = 0
    let buffer = [UInt8](data)
    
    for byte in buffer {
        checksum ^= UInt32(byte)
    }
    
    return String(format: "%08x", checksum)
}
