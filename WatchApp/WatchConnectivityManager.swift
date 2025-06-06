//
//  WatchConnectivityManager.swift
//  ShuttlX Watch App
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import WatchConnectivity
import SwiftUI

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isReachable = false
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false
    @Published var receivedWorkouts: [CustomWorkout] = []
    @Published var receivedTemplates: [WorkoutTemplate] = []
    @Published var syncStatus: SyncStatus = .disconnected
    
    // MARK: - Private Properties
    private let session: WCSession
    
    // MARK: - Initialization
    override init() {
        session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - Public Methods
    func sendWorkoutData(_ workout: CustomWorkout) {
        guard session.isReachable else { return }
        
        do {
            let data = try JSONEncoder().encode(workout)
            let message = ["workout": data]
            
            session.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    print("Workout sent successfully: \(reply)")
                }
            }) { error in
                DispatchQueue.main.async {
                    print("Failed to send workout: \(error)")
                }
            }
        } catch {
            print("Failed to encode workout: \(error)")
        }
    }
    
    func sendWorkoutResults(_ results: WorkoutResults) {
        guard session.isReachable else { return }
        
        do {
            let data = try JSONEncoder().encode(results)
            let message = ["workoutResults": data]
            
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                DispatchQueue.main.async {
                    print("Failed to send workout results: \(error)")
                }
            })
        } catch {
            print("Failed to encode workout results: \(error)")
        }
    }
    
    func requestWorkouts() {
        guard session.isReachable else { return }
        
        let message = ["requestWorkouts": true]
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleWorkoutsResponse(reply)
            }
        }) { error in
            DispatchQueue.main.async {
                print("Failed to request workouts: \(error)")
            }
        }
    }
    
    func requestTemplates() {
        guard session.isReachable else { return }
        
        let message = ["requestTemplates": true]
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleTemplatesResponse(reply)
            }
        }) { error in
            DispatchQueue.main.async {
                print("Failed to request templates: \(error)")
            }
        }
    }
    
    func syncData() {
        requestWorkouts()
        requestTemplates()
        updateSyncStatus()
    }
    
    // MARK: - Private Methods
    private func handleWorkoutsResponse(_ response: [String: Any]) {
        guard let workoutsData = response["workouts"] as? Data else { return }
        
        do {
            let workouts = try JSONDecoder().decode([CustomWorkout].self, from: workoutsData)
            receivedWorkouts = workouts
        } catch {
            print("Failed to decode workouts: \(error)")
        }
    }
    
    private func handleTemplatesResponse(_ response: [String: Any]) {
        guard let templatesData = response["templates"] as? Data else { return }
        
        do {
            let templates = try JSONDecoder().decode([WorkoutTemplate].self, from: templatesData)
            receivedTemplates = templates
        } catch {
            print("Failed to decode templates: \(error)")
        }
    }
    
    private func updateSyncStatus() {
        if !isPaired {
            syncStatus = .disconnected
        } else if !isWatchAppInstalled {
            syncStatus = .appNotInstalled
        } else if !isReachable {
            syncStatus = .unreachable
        } else {
            syncStatus = .connected
        }
    }
    
    private func updateConnectionStatus() {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
        updateSyncStatus()
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
            
            if let error = error {
                print("WCSession activation failed: \(error)")
            } else {
                print("WCSession activated with state: \(activationState.rawValue)")
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
        }
    }
    #endif
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleReceivedMessageWithReply(message, replyHandler: replyHandler)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.handleApplicationContext(applicationContext)
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        // Handle one-way messages from iPhone
        if let workoutData = message["workout"] as? Data {
            do {
                let workout = try JSONDecoder().decode(CustomWorkout.self, from: workoutData)
                if !receivedWorkouts.contains(where: { $0.id == workout.id }) {
                    receivedWorkouts.append(workout)
                }
            } catch {
                print("Failed to decode received workout: \(error)")
            }
        }
        
        if let templateData = message["template"] as? Data {
            do {
                let template = try JSONDecoder().decode(WorkoutTemplate.self, from: templateData)
                if !receivedTemplates.contains(where: { $0.id == template.id }) {
                    receivedTemplates.append(template)
                }
            } catch {
                print("Failed to decode received template: \(error)")
            }
        }
    }
    
    private func handleReceivedMessageWithReply(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Handle requests from iPhone that need a reply
        if message["requestWorkouts"] as? Bool == true {
            do {
                let data = try JSONEncoder().encode(receivedWorkouts)
                replyHandler(["workouts": data])
            } catch {
                replyHandler(["error": "Failed to encode workouts"])
            }
        }
        
        if message["requestTemplates"] as? Bool == true {
            do {
                let data = try JSONEncoder().encode(receivedTemplates)
                replyHandler(["templates": data])
            } catch {
                replyHandler(["error": "Failed to encode templates"])
            }
        }
        
        if message["requestStatus"] as? Bool == true {
            let status: [String: Any] = [
                "isReachable": isReachable,
                "isPaired": isPaired,
                "isWatchAppInstalled": isWatchAppInstalled,
                "syncStatus": syncStatus.rawValue
            ]
            replyHandler(status)
        }
    }
    
    private func handleApplicationContext(_ context: [String: Any]) {
        // Handle application context updates
        if let workoutsData = context["recentWorkouts"] as? Data {
            do {
                let workouts = try JSONDecoder().decode([CustomWorkout].self, from: workoutsData)
                receivedWorkouts = workouts
            } catch {
                print("Failed to decode context workouts: \(error)")
            }
        }
        
        if let templatesData = context["favoriteTemplates"] as? Data {
            do {
                let templates = try JSONDecoder().decode([WorkoutTemplate].self, from: templatesData)
                receivedTemplates = templates
            } catch {
                print("Failed to decode context templates: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types
enum SyncStatus: String {
    case connected = "connected"
    case disconnected = "disconnected"
    case unreachable = "unreachable"
    case appNotInstalled = "appNotInstalled"
    case syncing = "syncing"
    
    var displayName: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .unreachable: return "Unreachable"
        case .appNotInstalled: return "App Not Installed"
        case .syncing: return "Syncing"
        }
    }
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .disconnected: return .red
        case .unreachable: return .orange
        case .appNotInstalled: return .yellow
        case .syncing: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .connected: return "checkmark.circle.fill"
        case .disconnected: return "xmark.circle.fill"
        case .unreachable: return "exclamationmark.triangle.fill"
        case .appNotInstalled: return "app.badge"
        case .syncing: return "arrow.clockwise.circle.fill"
        }
    }
}

struct WorkoutResults: Codable {
    let workoutId: UUID
    let startDate: Date
    let endDate: Date
    let totalDuration: TimeInterval
    let activeCalories: Double
    let heartRate: Double
    let distance: Double
    let completedIntervals: Int
    let averageHeartRate: Double
    let maxHeartRate: Double
}
