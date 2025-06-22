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
        saveProgramsToSharedStorage(programs)
        sendProgramsToWatch(programs)
    }
    
    private func sendProgramsToWatch(_ programs: [TrainingProgram]) {
        guard session.activationState == .activated else {
            log("❌ WC Session not activated.")
            return
        }
        
        do {
            let encodedData = try JSONEncoder().encode(programs)
            let userInfo = ["programs": encodedData, "timestamp": Date().timeIntervalSince1970]
            session.transferUserInfo(userInfo)
            log("✅ Sent programs via transferUserInfo.")
        } catch {
            log("❌ Failed to encode programs for transfer: \(error)")
        }
    }

    private func saveProgramsToSharedStorage(_ programs: [TrainingProgram]) {
        guard let url = sharedContainer?.appendingPathComponent(programsKey) else {
            log("❌ Invalid shared container URL.")
            return
        }
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
        guard let url = sharedContainer?.appendingPathComponent(sessionsKey) else {
            log("❌ Invalid shared container URL for sessions.")
            return
        }
        do {
            let encodedData = try JSONEncoder().encode(sessions)
            try encodedData.write(to: url)
            log("✅ Saved sessions to shared storage.")
        } catch {
            log("❌ Failed to save sessions to shared storage: \(error)")
        }
    }

    private func loadSessionsFromSharedStorage() {
        guard let url = sharedContainer?.appendingPathComponent(sessionsKey) else { return }
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
        guard let url = sharedContainer?.appendingPathComponent(programsKey) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            log("✅ [Debug] Loaded \(programs.count) programs from App Group")
            return programs
        } catch {
            log("⚠️ [Debug] Failed to load programs from App Group: \(error)")
            return []
        }
    }

    func loadSessionsFromAppGroup() -> [TrainingSession] {
        guard let url = sharedContainer?.appendingPathComponent(sessionsKey) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            log("✅ [Debug] Loaded \(sessions.count) sessions from App Group")
            return sessions
        } catch {
            log("⚠️ [Debug] Failed to load sessions from App Group: \(error)")
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
                // This should be handled by the DataManager to provide the current programs
                // NotificationCenter.default.post(name: .requestPrograms, object: nil)
            }
        }
    }
}
