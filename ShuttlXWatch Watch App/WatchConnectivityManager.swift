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
        // More comprehensive connection status update
        let session = WCSession.default
        isReachable = session.isReachable
        
        // On watchOS, we don't have access to isPaired and isWatchAppInstalled
        // We can only check reachability and activation state
        
        // Update sync status based on overall connectivity health
        if session.activationState != .activated {
            syncStatus = .disconnected
        } else if !isReachable {
            // Don't immediately mark as unreachable - iOS app might be backgrounded
            // Keep previous status unless it was already unreachable
            if syncStatus != .unreachable {
                syncStatus = .connected // Maintain optimistic connection status
            }
        } else {
            syncStatus = .connected
        }
        
        print("⌚ Connection status updated - Reachable: \(isReachable), ActivationState: \(session.activationState.rawValue), Status: \(syncStatus.displayName)")
    }
    
    // MARK: - Custom Workout Handling
    
    private func handleCustomWorkoutCreated(_ message: [String: Any]) {
        guard let workoutData = message["workout_data"] as? Data else {
            print("❌ No workout data in custom workout creation message")
            return
        }
        
        do {
            let workout = try JSONDecoder().decode(TrainingProgram.self, from: workoutData)
            
            // Add to received programs if not already present - CRITICAL SYNC FIX
            if !receivedPrograms.contains(where: { $0.id == workout.id }) {
                receivedPrograms.append(workout)
                print("⌚ ✅ Added new custom workout: \(workout.name)")
                
                // Save to local storage immediately - CRITICAL FOR PERSISTENCE
                saveWorkoutToLocalStorage(workout)
                
                // Notify ContentView with proper main thread dispatch - CRITICAL FIX
                DispatchQueue.main.async {
                    // Send individual workout notification
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CustomWorkoutAdded"),
                        object: workout
                    )
                    
                    // Send full programs update notification
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TrainingProgramsUpdated"),
                        object: self.receivedPrograms
                    )
                    
                    // Send specific custom workout sync notification  
                    let customWorkouts = self.receivedPrograms.filter { $0.isCustom }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AllCustomWorkoutsSynced"),
                        object: customWorkouts
                    )
                    
                    print("⌚ ✅ All custom workout creation notifications sent")
                }
            } else {
                print("⌚ ⚠️ Custom workout already exists, updating existing...")
                
                // Update existing workout instead of skipping
                if let index = receivedPrograms.firstIndex(where: { $0.id == workout.id }) {
                    receivedPrograms[index] = workout
                    saveWorkoutToLocalStorage(workout)
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("CustomWorkoutUpdated"),
                            object: workout
                        )
                    }
                }
            }
        } catch {
            print("❌ Failed to decode custom workout: \(error)")
        }
    }
    
    private func handleCustomWorkoutUpdated(_ message: [String: Any]) {
        guard let workoutData = message["workout_data"] as? Data,
              let workoutId = message["workout_id"] as? String else {
            print("❌ Missing workout data or ID in update message")
            return
        }
        
        do {
            let updatedWorkout = try JSONDecoder().decode(TrainingProgram.self, from: workoutData)
            
            // Update existing workout in received programs
            if let index = receivedPrograms.firstIndex(where: { $0.id.uuidString == workoutId }) {
                receivedPrograms[index] = updatedWorkout
                print("⌚ Updated custom workout: \(updatedWorkout.name)")
                
                // Notify ContentView
                NotificationCenter.default.post(
                    name: NSNotification.Name("CustomWorkoutUpdated"),
                    object: updatedWorkout
                )
            }
        } catch {
            print("❌ Failed to decode updated custom workout: \(error)")
        }
    }
    
    private func handleCustomWorkoutDeleted(_ message: [String: Any]) {
        guard let workoutId = message["workout_id"] as? String else {
            print("❌ No workout ID in deletion message")
            return
        }
        
        // Remove from received programs
        if let index = receivedPrograms.firstIndex(where: { $0.id.uuidString == workoutId }) {
            let deletedWorkout = receivedPrograms.remove(at: index)
            print("⌚ Deleted custom workout: \(deletedWorkout.name)")
            
            // Notify ContentView
            NotificationCenter.default.post(
                name: NSNotification.Name("CustomWorkoutDeleted"),
                object: workoutId
            )
        }
    }
    
    private func handleSyncAllCustomWorkouts(_ message: [String: Any]) {
        guard let workoutsData = message["workouts_data"] as? Data else {
            print("❌ No workouts data in sync all message")
            return
        }
        
        do {
            let customWorkouts = try JSONDecoder().decode([TrainingProgram].self, from: workoutsData)
            
            // Update custom workouts in received programs - FIXED sync logic
            receivedPrograms.removeAll { $0.isCustom }
            receivedPrograms.append(contentsOf: customWorkouts)
            
            print("⌚ ✅ Synced \(customWorkouts.count) custom workouts successfully")
            
            // Notify ContentView with immediate update
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("AllCustomWorkoutsSynced"),
                    object: customWorkouts
                )
                
                // Also send general program update notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("TrainingProgramsUpdated"),
                    object: self.receivedPrograms
                )
                
                print("⌚ ✅ Custom workout notifications sent to ContentView")
            }
            
        } catch {
            print("❌ Failed to decode custom workouts: \(error)")
        }
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
                
                // Notify ContentView about updated programs
                NotificationCenter.default.post(
                    name: NSNotification.Name("TrainingProgramsUpdated"),
                    object: programs
                )
            } catch {
                print("❌ Failed to decode received programs: \(error)")
            }
        }
        
        // Handle custom workout operations
        if let action = message["action"] as? String {
            switch action {
            case "custom_workout_created":
                handleCustomWorkoutCreated(message)
            case "custom_workout_updated":
                handleCustomWorkoutUpdated(message)
            case "custom_workout_deleted":
                handleCustomWorkoutDeleted(message)
            case "sync_all_custom_workouts":
                handleSyncAllCustomWorkouts(message)
            default:
                print("⌚ Unknown action: \(action)")
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
        print("⌚ Received application context: \(context.keys)")
        
        if let programsData = context["training_programs"] as? Data {
            do {
                let programs = try JSONDecoder().decode([TrainingProgram].self, from: programsData)
                
                // Separate custom and default programs
                let customPrograms = programs.filter { $0.isCustom }
                let defaultPrograms = programs.filter { !$0.isCustom }
                
                receivedPrograms = programs
                print("⌚ ✅ Synced \(programs.count) programs via application context (\(customPrograms.count) custom, \(defaultPrograms.count) default)")
                
                // Notify ContentView about updated programs
                NotificationCenter.default.post(
                    name: NSNotification.Name("TrainingProgramsUpdated"),
                    object: programs
                )
                
                // Specifically notify about custom workouts if any
                if !customPrograms.isEmpty {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AllCustomWorkoutsSynced"),
                        object: customPrograms
                    )
                    print("⌚ ✅ Custom workouts synced successfully")
                }
                
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

// MARK: - Local Storage Management
    
extension WatchConnectivityManager {
    private func saveWorkoutToLocalStorage(_ workout: TrainingProgram) {
        do {
            var customWorkouts: [TrainingProgram] = []
            
            // Load existing custom workouts
            if let data = UserDefaults.standard.data(forKey: "customWorkouts_watch"),
               let existing = try? JSONDecoder().decode([TrainingProgram].self, from: data) {
                customWorkouts = existing
            }
            
            // Add new workout if not already present, or update existing
            if let existingIndex = customWorkouts.firstIndex(where: { $0.id == workout.id }) {
                customWorkouts[existingIndex] = workout
                print("⌚ ✅ Updated existing custom workout in local storage: \(workout.name)")
            } else {
                customWorkouts.append(workout)
                print("⌚ ✅ Added new custom workout to local storage: \(workout.name)")
            }
            
            // Save back to UserDefaults with error handling
            let encoder = JSONEncoder()
            let data = try encoder.encode(customWorkouts)
            UserDefaults.standard.set(data, forKey: "customWorkouts_watch")
            UserDefaults.standard.synchronize() // Force immediate save
            
            print("⌚ ✅ Successfully saved \(customWorkouts.count) custom workouts to local storage")
            
        } catch {
            print("❌ Failed to save custom workout to local storage: \(error)")
            
            // Fallback: try to save just this workout with unique key
            do {
                let encoder = JSONEncoder()
                let workoutData = try encoder.encode(workout)
                UserDefaults.standard.set(workoutData, forKey: "custom_workout_\(workout.id.uuidString)")
                UserDefaults.standard.synchronize()
                print("⌚ ✅ Fallback save successful for workout: \(workout.name)")
            } catch {
                print("❌ Fallback save also failed: \(error)")
            }
        }
    }
    
    private func loadCustomWorkoutsFromLocalStorage() -> [TrainingProgram] {
        guard let data = UserDefaults.standard.data(forKey: "customWorkouts_watch"),
              let workouts = try? JSONDecoder().decode([TrainingProgram].self, from: data) else {
            return []
        }
        return workouts
    }
}


