import Foundation
import WatchConnectivity

// Protocol to abstract connectivity functionality
protocol WatchConnectivityProtocol {
    var receivedPrograms: [TrainingProgram] { get }
    var receivedProgramsPublisher: Published<[TrainingProgram]>.Publisher { get }
    func sendSessionToPhone(_ session: TrainingSession)
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var receivedPrograms: [TrainingProgram] = []
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // MARK: - Send Session Data to iPhone
    func sendSessionToPhone(_ session: TrainingSession) {
        guard WCSession.default.isReachable else {
            print("iPhone is not reachable")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(session)
            let message = ["session": data]
            
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("Error sending session to iPhone: \(error.localizedDescription)")
            }
        } catch {
            print("Error encoding session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Request Programs from iPhone
    func requestProgramsFromPhone() {
        guard WCSession.default.isReachable else {
            print("iPhone is not reachable")
            return
        }
        
        let message = ["requestPrograms": true]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error requesting programs: \(error.localizedDescription)")
        }
    }
}

// MARK: - WatchConnectivityProtocol
extension WatchConnectivityManager: WatchConnectivityProtocol {
    var receivedProgramsPublisher: Published<[TrainingProgram]>.Publisher {
        $receivedPrograms
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
        
        // Request programs when session becomes active
        if activationState == .activated {
            requestProgramsFromPhone()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from iPhone
        if let programsData = message["programs"] as? Data {
            do {
                let programs = try JSONDecoder().decode([TrainingProgram].self, from: programsData)
                DispatchQueue.main.async {
                    self.receivedPrograms = programs
                }
            } catch {
                print("Error decoding programs from iPhone: \(error.localizedDescription)")
            }
        }
    }
}
