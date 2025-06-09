//
//  WatchConnectivityManager.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var isWatchAppInstalled = false
    @Published var isWatchReachable = false
    @Published var watchSession: WCSession?
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            watchSession = WCSession.default
            watchSession?.delegate = self
        }
    }
    
    func startSession() {
        guard let session = watchSession else {
            print("WatchConnectivity is not supported")
            return
        }
        
        session.activate()
    }
    
    // MARK: - Send Data to Watch
    func sendWorkoutConfiguration(_ config: WorkoutConfiguration) {
        guard let session = watchSession,
              session.isPaired && session.isWatchAppInstalled else {
            print("Watch is not available or app not installed")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(config)
            let message = ["workoutConfiguration": data]
            
            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { error in
                    print("Failed to send workout configuration: \(error.localizedDescription)")
                }
            } else {
                try session.updateApplicationContext(message)
            }
        } catch {
            print("Failed to encode workout configuration: \(error.localizedDescription)")
        }
    }
    
    func sendWorkoutUpdate(_ update: WorkoutUpdate) {
        guard let session = watchSession,
              session.isPaired && session.isWatchAppInstalled && session.isReachable else {
            return
        }
        
        do {
            let data = try JSONEncoder().encode(update)
            let message = ["workoutUpdate": data]
            
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send workout update: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to encode workout update: \(error.localizedDescription)")
        }
    }
    
    func sendUserPreferences(_ preferences: UserPreferences) {
        guard let session = watchSession,
              session.isPaired && session.isWatchAppInstalled else {
            return
        }
        
        do {
            let data = try JSONEncoder().encode(preferences)
            let message = ["userPreferences": data]
            
            try session.updateApplicationContext(message)
        } catch {
            print("Failed to send user preferences: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Transfer Files
    func transferWorkoutData(_ trainingSession: TrainingSession) {
        guard let session = watchSession,
              session.isPaired && session.isWatchAppInstalled else {
            return
        }
        
        do {
            let data = try JSONEncoder().encode(trainingSession)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("workout_\(trainingSession.id.uuidString).json")
            
            try data.write(to: tempURL)
            
            session.transferFile(tempURL, metadata: [
                "type": "trainingSession",
                "workoutId": trainingSession.id.uuidString
            ])
        } catch {
            print("Failed to transfer workout data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Request Data from Watch
    func requestWatchStatus() {
        guard let session = watchSession,
              session.isPaired && session.isWatchAppInstalled && session.isReachable else {
            return
        }
        
        session.sendMessage(["requestStatus": true], replyHandler: { response in
            // Handle watch status response
            DispatchQueue.main.async {
                if let statusData = response["status"] as? Data {
                    // Process watch status
                }
            }
        }) { error in
            print("Failed to request watch status: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
            
            if let error = error {
                print("WCSession activation failed: \(error.localizedDescription)")
            } else {
                print("WCSession activated with state: \(activationState.rawValue)")
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // Reactivate the session for iOS
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }
    
    // MARK: - Receive Messages from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            if let workoutCommandData = message["workoutCommand"] as? Data {
                self.handleWorkoutCommand(data: workoutCommandData)
                replyHandler(["status": "received"])
            } else if let heartRateData = message["heartRate"] as? Double {
                self.handleHeartRateUpdate(heartRate: heartRateData)
                replyHandler(["status": "received"])
            } else {
                replyHandler(["status": "unknown_message"])
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            // Handle messages without reply handler
            if let workoutStateData = message["workoutState"] as? Data {
                self.handleWorkoutStateUpdate(data: workoutStateData)
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            // Handle application context updates
            if let preferencesData = applicationContext["watchPreferences"] as? Data {
                self.handleWatchPreferencesUpdate(data: preferencesData)
            }
        }
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        DispatchQueue.main.async {
            // Handle file transfers from watch
            if let metadata = file.metadata,
               let type = metadata["type"] as? String {
                switch type {
                case "workoutData":
                    self.handleWorkoutDataFile(file: file)
                case "healthData":
                    self.handleHealthDataFile(file: file)
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Message Handlers
    private func handleWorkoutCommand(data: Data) {
        do {
            let command = try JSONDecoder().decode(WorkoutCommand.self, from: data)
            // Handle workout command from watch
            NotificationCenter.default.post(
                name: .workoutCommandReceived,
                object: command
            )
        } catch {
            print("Failed to decode workout command: \(error.localizedDescription)")
        }
    }
    
    private func handleHeartRateUpdate(heartRate: Double) {
        NotificationCenter.default.post(
            name: .heartRateUpdated,
            object: heartRate
        )
    }
    
    private func handleWorkoutStateUpdate(data: Data) {
        do {
            let state = try JSONDecoder().decode(WatchWorkoutState.self, from: data)
            NotificationCenter.default.post(
                name: .workoutStateUpdated,
                object: state
            )
        } catch {
            print("Failed to decode workout state: \(error.localizedDescription)")
        }
    }
    
    private func handleWatchPreferencesUpdate(data: Data) {
        do {
            let preferences = try JSONDecoder().decode(WatchPreferences.self, from: data)
            NotificationCenter.default.post(
                name: .watchPreferencesUpdated,
                object: preferences
            )
        } catch {
            print("Failed to decode watch preferences: \(error.localizedDescription)")
        }
    }
    
    private func handleWorkoutDataFile(file: WCSessionFile) {
        do {
            let data = try Data(contentsOf: file.fileURL)
            let workoutData = try JSONDecoder().decode(WatchWorkoutData.self, from: data)
            
            NotificationCenter.default.post(
                name: .watchWorkoutDataReceived,
                object: workoutData
            )
        } catch {
            print("Failed to process workout data file: \(error.localizedDescription)")
        }
    }
    
    private func handleHealthDataFile(file: WCSessionFile) {
        do {
            let data = try Data(contentsOf: file.fileURL)
            let healthData = try JSONDecoder().decode(WatchHealthData.self, from: data)
            
            NotificationCenter.default.post(
                name: .watchHealthDataReceived,
                object: healthData
            )
        } catch {
            print("Failed to process health data file: \(error.localizedDescription)")
        }
    }
}

// MARK: - Watch Communication Models
struct WorkoutUpdate: Codable {
    let currentInterval: Int
    let timeRemaining: TimeInterval
    let heartRateZone: HeartRateZone?
    let pace: Double?
    let distance: Double?
}

struct WatchWorkoutCommand: Codable {
    let type: CommandType
    let timestamp: Date
    
    enum CommandType: String, Codable {
        case start, pause, resume, stop, nextInterval, skipRest
    }
}

struct WatchWorkoutState: Codable {
    let isActive: Bool
    let isPaused: Bool
    let currentInterval: Int
    let elapsedTime: TimeInterval
    let heartRate: Double?
}

struct WatchPreferences: Codable {
    let hapticFeedback: Bool
    let audioAnnouncements: Bool
    let complicationStyle: String
    let displayMetrics: [String]
}

struct WatchWorkoutData: Codable {
    let workoutId: UUID
    let heartRateData: [WatchHeartRateDataPoint]
    let workoutMetrics: WorkoutMetrics
}

struct WatchHealthData: Codable {
    let timestamp: Date
    let heartRate: Double?
    let activeEnergyBurned: Double?
    let steps: Int?
}

struct WatchHeartRateDataPoint: Codable {
    let timestamp: Date
    let heartRate: Double
}

struct WorkoutMetrics: Codable {
    let averageHeartRate: Double
    let maxHeartRate: Double
    let activeEnergyBurned: Double
    let totalTime: TimeInterval
}

// MARK: - Notification Names
extension Notification.Name {
    static let workoutCommandReceived = Notification.Name("workoutCommandReceived")
    static let heartRateUpdated = Notification.Name("heartRateUpdated")
    static let workoutStateUpdated = Notification.Name("workoutStateUpdated")
    static let watchPreferencesUpdated = Notification.Name("watchPreferencesUpdated")
    static let watchWorkoutDataReceived = Notification.Name("watchWorkoutDataReceived")
    static let watchHealthDataReceived = Notification.Name("watchHealthDataReceived")
}
