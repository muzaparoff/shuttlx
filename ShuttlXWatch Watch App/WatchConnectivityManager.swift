//
//  WatchConnectivityManager.swift
//  ShuttlXWatch Watch App
//
//  Created by sergey on 09/06/2025.
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
    @Published var receivedPrograms: [TrainingProgram] = []
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
    func sendWorkoutResults(_ results: WorkoutResults) {
        guard session.isReachable else { 
            print("⌚ Phone not reachable, cannot send workout results")
            return 
        }
        
        do {
            let data = try JSONEncoder().encode(results)
            let message = ["workoutResults": data]
            
            session.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    print("⌚ Workout results sent successfully: \(reply)")
                }
            }) { error in
                DispatchQueue.main.async {
                    print("❌ Failed to send workout results: \(error)")
                }
            }
        } catch {
            print("❌ Failed to encode workout results: \(error)")
        }
    }
    
    func requestPrograms() {
        guard session.isReachable else { 
            print("⌚ Phone not reachable, cannot request programs")
            return 
        }
        
        let message = ["requestPrograms": true]
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleProgramsResponse(reply)
            }
        }) { error in
            DispatchQueue.main.async {
                print("❌ Failed to request programs: \(error)")
            }
        }
    }
    
    func syncData() {
        requestPrograms()
        updateSyncStatus()
    }
    
    // MARK: - Private Methods
    private func handleProgramsResponse(_ response: [String: Any]) {
        guard let programsData = response["programs"] as? Data else { 
            print("⌚ No programs data in response")
            return 
        }
        
        do {
            let programs = try JSONDecoder().decode([TrainingProgram].self, from: programsData)
            receivedPrograms = programs
            print("⌚ Received \(programs.count) training programs from iPhone")
        } catch {
            print("❌ Failed to decode programs: \(error)")
        }
    }
    
    private func updateSyncStatus() {
        if !isReachable {
            syncStatus = .unreachable
        } else {
            syncStatus = .connected
        }
    }
    
    private func updateConnectionStatus() {
        // watchOS doesn't have isPaired and isWatchAppInstalled properties
        isReachable = session.isReachable
        updateSyncStatus()
        
        print("⌚ Connection status - Reachable: \(isReachable)")
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
            
            if let error = error {
                print("❌ WCSession activation failed: \(error)")
            } else {
                print("⌚ WCSession activated with state: \(activationState.rawValue)")
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleReceivedMessageWithReply(message, replyHandler: replyHandler)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.handleApplicationContext(applicationContext)
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        // Handle one-way messages from iPhone
        if let programData = message["training_programs"] as? Data {
            do {
                let programs = try JSONDecoder().decode([TrainingProgram].self, from: programData)
                receivedPrograms = programs
                print("⌚ Received \(programs.count) training programs via message")
            } catch {
                print("❌ Failed to decode received programs: \(error)")
            }
        }
        
        if let programData = message["selected_program"] as? Data {
            do {
                let program = try JSONDecoder().decode(TrainingProgram.self, from: programData)
                print("⌚ Received selected program: \(program.name)")
                // Handle the selected program if needed
            } catch {
                print("❌ Failed to decode selected program: \(error)")
            }
        }
    }
    
    private func handleReceivedMessageWithReply(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Handle requests from iPhone that need a reply
        if message["requestPrograms"] as? Bool == true {
            do {
                let data = try JSONEncoder().encode(receivedPrograms)
                replyHandler(["programs": data])
            } catch {
                replyHandler(["error": "Failed to encode programs"])
            }
        }
        
        if message["requestStatus"] as? Bool == true {
            let status: [String: Any] = [
                "isReachable": isReachable,
                "syncStatus": syncStatus.rawValue
            ]
            replyHandler(status)
        }
    }
    
    private func handleApplicationContext(_ context: [String: Any]) {
        // Handle application context updates
        if let programsData = context["training_programs"] as? Data {
            do {
                let programs = try JSONDecoder().decode([TrainingProgram].self, from: programsData)
                receivedPrograms = programs
                print("⌚ Received \(programs.count) training programs via context")
            } catch {
                print("❌ Failed to decode context programs: \(error)")
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


