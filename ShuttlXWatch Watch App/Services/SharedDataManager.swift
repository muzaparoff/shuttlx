import Foundation
import WatchConnectivity
import Combine

/// Enhanced data synchronization manager for watchOS with dual-sync architecture
/// Uses both WatchConnectivity (primary) and App Groups (fallback) for maximum reliability
@MainActor
class SharedDataManager: NSObject, ObservableObject {
    static let shared = SharedDataManager()
    
    @Published var syncedPrograms: [TrainingProgram] = []
    @Published var syncLog: [String] = []

    // App Groups shared container for reliable persistence
    private let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")
    private let programsKey = "programs.json"
    private let sessionsKey = "sessions.json"
    
    // Session management for WatchConnectivity
    private var sessionActivated = false
    private var pendingSessionUpdates: [TrainingSession] = []
    private var retryAttempts = 0
    private let maxRetryAttempts = 3
    
    private override init() {
        super.init()
        setupWatchConnectivity()
        loadProgramsFromSharedStorage()
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
        guard let containerURL = sharedContainer else {
            log("❌ Failed to access shared container, requesting from iOS")
            requestProgramsFromiOS() // Request from phone if container is missing
            return
        }
        
        let programsURL = containerURL.appendingPathComponent(programsKey)
        
        do {
            guard FileManager.default.fileExists(atPath: programsURL.path) else {
                log("ℹ️ No program file in App Group, requesting from iOS.")
                requestProgramsFromiOS()
                return
            }
            let data = try Data(contentsOf: programsURL)
            let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            syncedPrograms = programs
            log("✅ Loaded \(programs.count) programs from shared storage")
        } catch {
            log("⚠️ Failed to load from shared storage, requesting from iOS. Error: \(error)")
            requestProgramsFromiOS()
        }
    }
    
    private func requestProgramsFromiOS() {
        guard sessionActivated && WCSession.default.activationState == .activated else {
            log("⏳ WatchConnectivity not ready for program request")
            return
        }
        
        let message = [
            "requestPrograms": true,
            "timestamp": Date().timeIntervalSince1970,
            "source": "watchOS"
        ] as [String: Any]
        
        // Use transferUserInfo for reliable delivery
        WCSession.default.transferUserInfo(message)
        log("📱 Requested programs from iOS via transferUserInfo")
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
        guard let containerURL = sharedContainer else {
            log("❌ Failed to access shared container for session")
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
        guard let containerURL = sharedContainer else {
            log("❌ Failed to access shared container")
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
        guard let containerURL = sharedContainer else {
            log("❌ Failed to access shared container")
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
        guard let containerURL = sharedContainer else {
            log("❌ Failed to access shared container")
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
}
