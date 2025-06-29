import Foundation
import WatchConnectivity
import Combine

@MainActor
class SharedDataManager: NSObject, ObservableObject {
    static let shared = SharedDataManager()
    
    @Published var syncedSessions: [TrainingSession] = []
    @Published var syncLog: [String] = []

    private let programsKey = "programs.json"
    private let sessionsKey = "sessions.json"
    private let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")
    
    // Fallback container for when App Groups is not available (e.g., in simulator without provisioning)
    private var fallbackContainer: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SharedData")
    }
    
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
        print("📱 WatchConnectivity session state: \(session.activationState.rawValue)")
        print("📱 Session reachable: \(session.isReachable)")
        print("📱 Session paired: \(session.isPaired)")
        print("📱 Session installed: \(session.isWatchAppInstalled)")
        
        // Save to App Groups first (always works)
        saveProgramsToSharedStorage(programs)
        
        // Then try WatchConnectivity with enhanced reliability
        sendProgramsToWatch(programs)
        
        // Force immediate session activation check
        if session.activationState != .activated {
            print("🔄 Session not activated, attempting to activate...")
            session.activate()
        }
        
        // Debug: Print program details
        for (index, program) in programs.enumerated() {
            print("📱 Program \(index + 1): \(program.name) - \(program.intervals.count) intervals - \(program.totalDuration/60) min")
        }
    }
    
    private func sendProgramsToWatch(_ programs: [TrainingProgram]) {
        guard session.activationState == .activated else {
            log("❌ WC Session not activated. State: \(session.activationState.rawValue)")
            return
        }
        
        // Use both transferUserInfo (reliable) and sendMessage (immediate) for maximum success
        do {
            let encodedData = try JSONEncoder().encode(programs)
            let userInfo: [String: Any] = ["programs": encodedData, "timestamp": Date().timeIntervalSince1970]
            
            // Primary method: transferUserInfo (reliable, works when watch is locked)
            session.transferUserInfo(userInfo)
            log("✅ Sent programs via transferUserInfo (reliable delivery).")
            
            // Secondary method: immediate message if watch is reachable
            if session.isReachable {
                session.sendMessage(userInfo, replyHandler: { reply in
                    Task { @MainActor in
                        self.log("✅ Immediate message sent successfully")
                    }
                }, errorHandler: { error in
                    Task { @MainActor in
                        self.log("⚠️ Immediate message failed: \(error.localizedDescription)")
                    }
                })
            }
        } catch {
            log("❌ Failed to encode programs for transfer: \(error)")
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
            log("✅ Saved programs to shared storage.")
        } catch {
            log("❌ Failed to save programs to shared storage: \(error)")
        }
    }

    // MARK: - Session Sync
    private func handleReceivedSession(_ session: TrainingSession) {
        if !syncedSessions.contains(where: { $0.id == session.id }) {
            syncedSessions.append(session)
            saveSessionsToSharedStorage(syncedSessions)
            log("✅ New session received and saved.")
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
            log("✅ Saved sessions to shared storage.")
        } catch {
            log("❌ Failed to save sessions to shared storage: \(error)")
        }
    }

    private func loadSessionsFromSharedStorage() {
        guard let containerURL = getWorkingContainer() else {
            log("⚠️ No valid container URL available for loading sessions")
            return
        }
        
        let url = containerURL.appendingPathComponent(sessionsKey)
        do {
            let data = try Data(contentsOf: url)
            self.syncedSessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            log("✅ Loaded \(self.syncedSessions.count) sessions from shared storage.")
        } catch {
            log("⚠️ Failed to load sessions from shared storage: \(error)")
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

    func loadSessionsFromAppGroup() -> [TrainingSession] {
        guard let containerURL = getWorkingContainer() else {
            log("⚠️ [Debug] No valid container URL available")
            return []
        }
        
        let url = containerURL.appendingPathComponent(sessionsKey)
        do {
            let data = try Data(contentsOf: url)
            let sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            log("✅ [Debug] Loaded \(sessions.count) sessions from storage")
            return sessions
        } catch {
            log("⚠️ [Debug] Failed to load sessions from storage: \(error)")
            return []
        }
    }
}

// MARK: - WCSessionDelegate
extension SharedDataManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            log("📱 WC Session activated with state: \(activationState.rawValue)")
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            log("📱 WC Session became inactive.")
        }
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            log("📱 WC Session deactivated, reactivating...")
            session.activate()
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        Task { @MainActor in
            log("📦 Received userInfo on iOS: \(userInfo.keys)")
            if let sessionData = userInfo["session"] as? Data {
                do {
                    let session = try JSONDecoder().decode(TrainingSession.self, from: sessionData)
                    self.handleReceivedSession(session)
                } catch {
                    log("❌ Failed to decode session from userInfo: \(error)")
                }
            }

            if let _ = userInfo["requestPrograms"] as? Bool {
                log("⌚️ Received request for programs from watch.")
                // Send current programs from DataManager
                if let dataManager = getDataManager() {
                    sendProgramsToWatch(dataManager.programs)
                }
            }
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
