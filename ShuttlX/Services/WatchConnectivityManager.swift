import Foundation
#if os(iOS)
import WatchConnectivity
#endif

class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var isWatchConnected = false
    @Published var isWatchAppInstalled = false
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        #if os(iOS)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
    }
    
    func sendWorkoutCommand(_ command: String) {
        #if os(iOS)
        guard WCSession.default.isReachable else { return }
        
        let message = ["command": command]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message: \(error.localizedDescription)")
        }
        #endif
    }
    
    func sendWorkoutData(_ data: [String: Any]) {
        #if os(iOS)
        guard WCSession.default.activationState == .activated else { return }
        
        do {
            try WCSession.default.updateApplicationContext(data)
        } catch {
            print("Error updating application context: \(error.localizedDescription)")
        }
        #endif
    }
}

#if os(iOS)
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = activationState == .activated
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message from watch: \(message)")
    }
}
#endif