import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // MARK: - Send Data to Watch
    func sendProgramsToWatch(_ programs: [TrainingProgram]) {
        guard WCSession.default.isReachable else {
            print("Watch is not reachable")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(programs)
            let message = ["programs": data]
            
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("Error sending programs to watch: \(error.localizedDescription)")
            }
        } catch {
            print("Error encoding programs: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Receive Session Data from Watch
    func handleSessionFromWatch(_ session: TrainingSession) {
        // This would be called when the watch sends a completed session
        // Forward to DataManager
        NotificationCenter.default.post(
            name: .sessionReceivedFromWatch,
            object: session
        )
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WC Session activation failed with error: \(error.localizedDescription)")
            return
        }
        
        print("WC Session activated with state: \(activationState.rawValue)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WC Session did become inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WC Session did deactivate")
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from watch
        if let sessionData = message["session"] as? Data {
            do {
                let session = try JSONDecoder().decode(TrainingSession.self, from: sessionData)
                DispatchQueue.main.async {
                    self.handleSessionFromWatch(session)
                }
            } catch {
                print("Error decoding session from watch: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let sessionReceivedFromWatch = Notification.Name("sessionReceivedFromWatch")
}
