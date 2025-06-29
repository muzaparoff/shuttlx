import Foundation
import WatchConnectivity
import Combine
import os.log

/// Enhanced data synchronization manager for watchOS with dual-sync architecture
/// Uses both WatchConnectivity (primary) and App Groups (fallback) for maximum reliability
@MainActor
class SharedDataManager: NSObject, ObservableObject {
    @Published var syncedPrograms: [TrainingProgram] = []
    @Published var syncLog: [String] = []

    // App Groups shared container for reliable persistence
    private let appGroupIdentifier = "group.com.shuttlx.shared"
    private let programsKey = "programs.json"
    private let sessionsKey = "sessions.json"
    
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "SharedDataManager")
    
    private var sharedContainer: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    // Fallback container for when App Groups is not available (e.g., in simulator without provisioning)
    private var fallbackContainer: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SharedData")
    }
    
    // Session management for WatchConnectivity
    private var sessionActivated = false
    private var pendingSessionUpdates: [TrainingSession] = []
    private var retryAttempts = 0
    private let maxRetryAttempts = 3
    
    override init() {
        logger.info("🔄 SharedDataManager init() called...")
        super.init()
        logger.info("✅ super.init() completed successfully")
        log("🔄 SharedDataManager initializing safely...")
        
        // Delay complex initialization to avoid crashes
        Task {
            logger.info("🚀 Starting async initialization...")
            await initializeSafely()
            logger.info("✅ Async initialization completed successfully")
        }
    }
    
    private func initializeSafely() async {
        await MainActor.run {
            log("🔄 Starting safe initialization sequence...")
            logger.info("🔄 Safe initialization sequence starting...")
        }
        
        // Step 1: Setup WatchConnectivity first (less likely to crash)
        logger.info("📡 Setting up WatchConnectivity...")
        setupWatchConnectivity()
        logger.info("✅ WatchConnectivity setup completed")
        
        // Step 2: Try to load from shared storage with error handling
        logger.info("💾 Loading programs from shared storage...")
        loadProgramsFromSharedStorageSafely()
        logger.info("✅ Programs loaded from shared storage")
    }
    
    private func loadFallbackPrograms() {
        logger.info("📋 Loading fallback programs...")
        // Provide basic fallback programs if all else fails
        let fallbackProgram = TrainingProgram(
            name: "Basic Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate),
                TrainingInterval(phase: .rest, duration: 120, intensity: .low)
            ],
            maxPulse: 180,
            createdDate: Date(),
            lastModified: Date()
        )
        syncedPrograms = [fallbackProgram]
        log("✅ Fallback programs loaded successfully")
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

    // MARK: - Robust WatchConnectivity Setup
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            log("⚠️ WatchConnectivity not supported on this device")
            return
        }
        
        log("🔄 Setting up WatchConnectivity session on watch...")
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    
    // MARK: - Load Programs with Dual Sources
    func loadPrograms() {
        log("📲 Loading programs on watch...")
        
        // First, load from shared storage (reliable fallback)
        loadProgramsFromSharedStorage()
        
        // Then, request latest from iOS if connectivity is available
        requestProgramsFromiOS()
    }
    
    private func loadProgramsFromSharedStorage() {
        guard let containerURL = getWorkingContainer() else {
            log("❌ Failed to access container for shared storage")
            log("⚠️ Check entitlements and provisioning profile, using defaults")
            // Provide default programs as fallback
            provideDefaultPrograms()
            return
        }
        
        let programsURL = containerURL.appendingPathComponent(programsKey)
        
        do {
            guard FileManager.default.fileExists(atPath: programsURL.path) else {
                log("ℹ️ No program file in App Group, providing defaults and requesting from iOS.")
                provideDefaultPrograms()
                requestProgramsFromiOS()
                return
            }
            let data = try Data(contentsOf: programsURL)
            let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            syncedPrograms = programs
            log("✅ Loaded \(programs.count) programs from shared storage")
        } catch {
            log("⚠️ Failed to load from shared storage, providing defaults. Error: \(error)")
            provideDefaultPrograms()
            requestProgramsFromiOS()
        }
    }
    
    private func loadProgramsFromSharedStorageSafely() {
        do {
            guard let containerURL = getWorkingContainer() else {
                log("❌ Failed to access container for shared storage")
                log("⚠️ Using defaults due to container access issue")
                // Provide default programs as fallback
                provideDefaultPrograms()
                return
            }
            
            let programsURL = containerURL.appendingPathComponent(programsKey)
            
            guard FileManager.default.fileExists(atPath: programsURL.path) else {
                log("ℹ️ No program file in App Group, providing defaults and requesting from iOS.")
                provideDefaultPrograms()
                requestProgramsFromiOS()
                return
            }
            let data = try Data(contentsOf: programsURL)
            let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            syncedPrograms = programs
            log("✅ Loaded \(programs.count) programs from shared storage")
        } catch {
            log("⚠️ Failed to load from shared storage safely, providing defaults. Error: \(error)")
            provideDefaultPrograms()
            // Don't request from iOS in safe mode to avoid additional crashes
        }
    }
    
    private func provideDefaultPrograms() {
        let defaultProgram = TrainingProgram(
            name: "Beginner Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),     // 5min warmup walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),     // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),     // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)      // 5min cooldown walk
            ],
            maxPulse: 180,
            createdDate: Date(),
            lastModified: Date()
        )
        
        syncedPrograms = [defaultProgram]
        log("✅ Provided default training program as fallback")
    }
    
    private func requestProgramsFromiOS() {
        guard WCSession.default.activationState == .activated else {
            log("⏳ WatchConnectivity not ready for program request, state: \(WCSession.default.activationState.rawValue)")
            return
        }
        
        if !WCSession.default.isReachable {
            log("📱💤 iPhone not reachable, but still trying transferUserInfo")
        }
        
        let message = [
            "requestPrograms": true,
            "timestamp": Date().timeIntervalSince1970,
            "source": "watchOS",
            "currentProgramCount": syncedPrograms.count,
            "sessionState": WCSession.default.activationState.rawValue
        ] as [String: Any]
        
        // Use transferUserInfo for reliable delivery (works even when iPhone is locked/backgrounded)
        WCSession.default.transferUserInfo(message)
        log("📱 Requested programs from iOS via transferUserInfo (reliable delivery)")
        
        // Also try immediate message if iPhone is reachable for faster response
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { reply in
                Task { @MainActor in
                    self.log("✅ Immediate program request sent successfully")
                    if reply["programs"] is Data {
                        self.log("📦 Received immediate reply with program data")
                    }
                }
            }, errorHandler: { error in
                Task { @MainActor in
                    self.log("⚠️ Immediate program request failed: \(error.localizedDescription)")
                }
            })
        }
    }
    
    // MARK: - Manual Refresh for User Triggering
    func refreshProgramsFromiOS() {
        log("🔄 Manual refresh triggered by user")
        loadProgramsFromSharedStorage() // Reload from App Group first
        requestProgramsFromiOS()        // Then request fresh data from iOS
    }
    
    // MARK: - Enhanced Session Sync to iOS
    func syncSessionToiOS(_ session: TrainingSession) {
        log("⌚➡️📱 Syncing training session to iOS...")
        
        // Always save to shared storage first (fallback)
        saveSessionToSharedStorage(session)
        
        // Attempt WatchConnectivity sync if session is ready
        if sessionActivated && WCSession.default.activationState == .activated {
            sendSessionViaWatchConnectivity(session)
        } else {
            log("⏳ WatchConnectivity not ready, queuing session for sync...")
            pendingSessionUpdates.append(session)
        }
    }
    
    // MARK: - Enhanced Session Sync to iOS with Dual Fallback
    func sendSessionToiOS(_ session: TrainingSession) {
        log("⌚➡️📱 Sending training session to iOS: \(session.programName)")
        
        // Always save to shared storage first (fallback)
        saveSessionToSharedStorage(session)
        
        // Attempt WatchConnectivity sync if session is ready
        if sessionActivated && WCSession.default.activationState == .activated {
            sendSessionViaWatchConnectivity(session)
        } else {
            log("⏳ WatchConnectivity not ready, queuing session for sync...")
            pendingSessionUpdates.append(session)
        }
    }
    
    private func sendSessionViaWatchConnectivity(_ session: TrainingSession) {
        guard WCSession.default.activationState == .activated else {
            log("❌ WatchConnectivity session not activated")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(session)
            let message = [
                "session": data,
                "timestamp": Date().timeIntervalSince1970,
                "source": "watchOS",
                "method": "WatchConnectivity"
            ] as [String: Any]
            
            // Use transferUserInfo for reliable delivery
            WCSession.default.transferUserInfo(message)
            log("✅ Session sent via WatchConnectivity transferUserInfo")
            
        } catch {
            log("❌ Failed to encode session for WatchConnectivity: \(error)")
        }
    }
    
    // MARK: - App Groups Shared Storage (Reliable Fallback)
    private func saveSessionToSharedStorage(_ session: TrainingSession) {
        guard let containerURL = getWorkingContainer() else {
            log("❌ Failed to access container for session storage")
            return
        }
        
        let sessionsURL = containerURL.appendingPathComponent(sessionsKey)
        
        do {
            // Load existing sessions
            var sessions: [TrainingSession] = []
            if let existingData = try? Data(contentsOf: sessionsURL) {
                sessions = try JSONDecoder().decode([TrainingSession].self, from: existingData)
            }
            
            // Add new session
            sessions.append(session)
            
            // Save updated sessions
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsURL)
            log("✅ Session saved to shared storage on watch")
            
        } catch {
            log("❌ Failed to save session to shared storage: \(error)")
        }
    }
    
    // MARK: - Public accessors for Debugging
    func loadProgramsFromAppGroup() -> [TrainingProgram] {
        guard let containerURL = getWorkingContainer() else {
            log("❌ Failed to access container")
            return []
        }
        let programsURL = containerURL.appendingPathComponent(programsKey)
        do {
            let data = try Data(contentsOf: programsURL)
            let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            log("✅ [Debug] Loaded \(programs.count) programs from App Group")
            return programs
        } catch {
            log("⚠️ [Debug] Failed to load programs from App Group: \(error)")
            return []
        }
    }

    func loadSessionsFromAppGroup() -> [TrainingSession] {
        guard let containerURL = getWorkingContainer() else {
            log("❌ Failed to access container")
            return []
        }
        let sessionsURL = containerURL.appendingPathComponent(sessionsKey)
        do {
            let data = try Data(contentsOf: sessionsURL)
            let sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            log("✅ [Debug] Loaded \(sessions.count) sessions from App Group")
            return sessions
        } catch {
            log("⚠️ [Debug] Failed to load sessions from App Group: \(error)")
            return []
        }
    }

    // MARK: - Error Recovery and Retry Logic
    private func retryPendingSync() {
        guard !pendingSessionUpdates.isEmpty, retryAttempts < maxRetryAttempts else {
            return
        }
        
        retryAttempts += 1
        log("🔄 Retry attempt \(retryAttempts)/\(maxRetryAttempts) for pending session sync")
        
        for session in pendingSessionUpdates {
            sendSessionViaWatchConnectivity(session)
        }
        
        // Schedule next retry if needed
        if retryAttempts < maxRetryAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(retryAttempts * 2)) {
                self.retryPendingSync()
            }
        } else {
            pendingSessionUpdates.removeAll()
        }
    }
}

// MARK: - WCSessionDelegate
extension SharedDataManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                log("❌ WatchConnectivity activation failed: \(error.localizedDescription)")
                return
            }
            
            sessionActivated = true
            retryAttempts = 0
            
            log("✅ WatchConnectivity activated on watch with state: \(activationState.rawValue)")
            
            // Request programs when session becomes active
            requestProgramsFromiOS()
            
            // Send any pending session updates
            if !pendingSessionUpdates.isEmpty {
                log("📤 Sending queued session updates...")
                for session in pendingSessionUpdates {
                    sendSessionViaWatchConnectivity(session)
                }
                pendingSessionUpdates.removeAll()
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        Task { @MainActor in
            log("📦 Received userInfo on watch")
            
            // Handle programs from iOS
            if let programsData = userInfo["programs"] as? Data {
                do {
                    let programs = try JSONDecoder().decode([TrainingProgram].self, from: programsData)
                    syncedPrograms = programs
                    log("✅ Received \(programs.count) programs from iOS")
                    
                    // Save to shared storage for future use
                    saveReceivedProgramsToSharedStorage(programs)
                    
                } catch {
                    log("❌ Failed to decode programs from iOS: \(error)")
                }
            }
        }
    }
    
    private func saveReceivedProgramsToSharedStorage(_ programs: [TrainingProgram]) {
        guard let containerURL = getWorkingContainer() else {
            log("❌ Failed to access container")
            return
        }
        
        let programsURL = containerURL.appendingPathComponent(programsKey)
        
        do {
            let data = try JSONEncoder().encode(programs)
            try data.write(to: programsURL)
            log("✅ Programs saved to shared storage on watch")
        } catch {
            log("❌ Failed to save programs to shared storage: \(error)")
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            log("📥 Received message on watch")
            
            // Handle program updates from iOS
            if let programsData = message["programs"] as? Data {
                do {
                    let programs = try JSONDecoder().decode([TrainingProgram].self, from: programsData)
                    syncedPrograms = programs
                    saveReceivedProgramsToSharedStorage(programs)
                    log("✅ Received \(programs.count) programs via message")
                } catch {
                    log("❌ Failed to decode programs from message: \(error)")
                }
            }
        }
    }
    
    // These methods are deprecated in newer iOS/watchOS versions but required for iOS compatibility
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Handle session deactivation
    }
    #endif
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
                    logger.info("✅ Created App Group container directory")
                    return appGroupContainer
                } catch {
                    logger.warning("⚠️ Failed to create App Group container, using fallback: \(error.localizedDescription)")
                }
            }
        }
        
        // Fallback to Documents directory
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: fallbackContainer, withIntermediateDirectories: true, attributes: nil)
            logger.info("ℹ️ Using fallback container: \(self.fallbackContainer.path)")
            return fallbackContainer
        } catch {
            logger.error("❌ Failed to create fallback container: \(error.localizedDescription)")
            return nil
        }
    }
}
