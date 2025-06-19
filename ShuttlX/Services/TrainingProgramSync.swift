//
//  TrainingProgramSync.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import SwiftUI
import WatchConnectivity

extension WatchConnectivityManager {
    
    // MARK: - Training Program Sync
    
    func sendTrainingPrograms(_ programs: [TrainingProgram]) {
        guard WCSession.default.isReachable else {
            print("⌚ Watch not reachable, queuing programs for later sync")
            queueProgramsForSync(programs)
            scheduleRetrySync()
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(programs)
            let message = [
                "training_programs": data,
                "timestamp": Date().timeIntervalSince1970,
                "version": "1.0",
                "sync_type": "custom_workouts"
            ] as [String : Any]
            
            // Add retry mechanism
            var retryCount = 0
            let maxRetries = 3
            
            func attemptSync() {
                WCSession.default.sendMessage(message, replyHandler: { reply in
                    DispatchQueue.main.async {
                        print("✅ Training programs sent to watch successfully")
                        if let status = reply["status"] as? String {
                            print("⌚ Watch response: \(status)")
                        }
                        // Clear any queued programs on successful sync
                        UserDefaults.standard.removeObject(forKey: "queued_training_programs")
                        NotificationCenter.default.post(name: .trainingProgramsSynced, object: programs)
                    }
                }, errorHandler: { error in
                    DispatchQueue.main.async {
                        print("❌ Failed to send training programs to watch: \(error.localizedDescription)")
                        
                        if retryCount < maxRetries {
                            retryCount += 1
                            print("🔄 Retrying sync (attempt \(retryCount) of \(maxRetries))...")
                            // Exponential backoff
                            let delay = pow(2.0, Double(retryCount))
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attemptSync()
                            }
                        } else {
                            print("❌ Max retries reached, queuing for later sync")
                            self.queueProgramsForSync(programs)
                            self.scheduleRetrySync()
                            NotificationCenter.default.post(name: .trainingProgramsSyncFailed, object: error)
                        }
                    }
                })
            }
            
            // Start first sync attempt
            attemptSync()
            
        } catch {
            print("❌ Failed to encode training programs: \(error.localizedDescription)")
            NotificationCenter.default.post(name: .trainingProgramsSyncFailed, object: error)
        }
    }
    
    func sendSelectedProgram(_ program: TrainingProgram) {
        guard WCSession.default.isReachable else {
            print("⌚ Watch not reachable, storing selected program for later sync")
            UserDefaults.standard.set(program.id.uuidString, forKey: "pending_selected_program")
            scheduleRetrySync()
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(program)
            let message = [
                "selected_program": data,
                "action": "start_workout",
                "timestamp": Date().timeIntervalSince1970
            ] as [String : Any]
            
            WCSession.default.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    print("✅ Selected program sent to watch successfully")
                    UserDefaults.standard.removeObject(forKey: "pending_selected_program")
                    NotificationCenter.default.post(name: .selectedProgramSynced, object: program)
                }
            }, errorHandler: { error in
                DispatchQueue.main.async {
                    print("❌ Failed to send selected program to watch: \(error.localizedDescription)")
                    UserDefaults.standard.set(program.id.uuidString, forKey: "pending_selected_program")
                    self.scheduleRetrySync()
                    NotificationCenter.default.post(name: .selectedProgramSyncFailed, object: error)
                }
            })
        } catch {
            print("❌ Failed to encode selected program: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sync Management
    
    private func scheduleRetrySync() {
        // Cancel any existing retry timer
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(retrySync), object: nil)
        
        // Schedule new retry
        perform(#selector(retrySync), with: nil, afterDelay: 30.0)
        print("⏰ Scheduled retry sync in 30 seconds")
    }
    
    @objc private func retrySync() {
        guard WCSession.default.isReachable else {
            print("⌚ Watch still not reachable, rescheduling retry...")
            scheduleRetrySync()
            return
        }
        
        guard let data = UserDefaults.standard.data(forKey: "queued_training_programs"),
              let programs = try? JSONDecoder().decode([TrainingProgram].self, from: data) else {
            print("❌ No queued programs found or failed to decode")
            return
        }
        
        print("🔄 Attempting to sync \(programs.count) queued programs...")
        sendTrainingPrograms(programs)
    }
    
    private func validateSyncData(_ programs: [TrainingProgram]) -> Bool {
        // Validate program data before syncing
        for program in programs {
            if program.name.isEmpty || program.distance <= 0 || program.runInterval <= 0 || program.walkInterval <= 0 {
                print("❌ Invalid program data detected: \(program.name)")
                return false
            }
        }
        return true
    }
    
    private func queueProgramsForSync(_ programs: [TrainingProgram]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(programs)
            UserDefaults.standard.set(data, forKey: "queued_training_programs")
            UserDefaults.standard.synchronize()
            print("💾 Queued \(programs.count) programs for later sync")
        } catch {
            print("❌ Failed to queue programs for sync: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func syncQueuedPrograms() {
        guard WCSession.default.isReachable else { 
            print("⌚ Watch not reachable, skipping queued sync")
            return 
        }
        
        // Sync queued programs
        if let data = UserDefaults.standard.data(forKey: "queued_training_programs") {
            do {
                let decoder = JSONDecoder()
                let programs = try decoder.decode([TrainingProgram].self, from: data)
                
                // Validate data before sending
                if validateSyncData(programs) {
                    sendTrainingPrograms(programs)
                } else {
                    print("❌ Invalid queued program data, clearing queue")
                    UserDefaults.standard.removeObject(forKey: "queued_training_programs")
                }
            } catch {
                print("❌ Failed to decode queued programs: \(error.localizedDescription)")
                UserDefaults.standard.removeObject(forKey: "queued_training_programs")
            }
        }
        
        // Sync pending selected program
        if let programId = UserDefaults.standard.string(forKey: "pending_selected_program"),
           let uuid = UUID(uuidString: programId) {
            let allPrograms = TrainingProgramManager.shared.allPrograms
            if let program = allPrograms.first(where: { $0.id == uuid }) {
                sendSelectedProgram(program)
            } else {
                print("❌ Pending selected program not found, clearing")
                UserDefaults.standard.removeObject(forKey: "pending_selected_program")
            }
        }
    }
    
    // MARK: - Message Handling for Training Programs
    
    func handleTrainingProgramMessage(_ message: [String: Any]) {
        if let data = message["training_programs"] as? Data {
            handleReceivedTrainingPrograms(data)
        }
        
        if let data = message["selected_program"] as? Data {
            handleReceivedSelectedProgram(data)
        }
        
        if let action = message["action"] as? String {
            Task { @MainActor in
                handleTrainingAction(action, message: message)
            }
        }
    }
    
    private func handleReceivedTrainingPrograms(_ data: Data) {
        do {
            let decoder = JSONDecoder()
            let programs = try decoder.decode([TrainingProgram].self, from: data)
            
            DispatchQueue.main.async {
                print("📱 Received \(programs.count) training programs from watch")
                // Update local programs if needed
                NotificationCenter.default.post(
                    name: .trainingProgramsReceived,
                    object: programs
                )
            }
        } catch {
            print("❌ Failed to decode received training programs: \(error.localizedDescription)")
        }
    }
    
    private func handleReceivedSelectedProgram(_ data: Data) {
        do {
            let decoder = JSONDecoder()
            let program = try decoder.decode(TrainingProgram.self, from: data)
            
            DispatchQueue.main.async {
                print("📱 Received selected program from watch: \(program.name)")
                TrainingProgramManager.shared.selectProgram(program)
                NotificationCenter.default.post(
                    name: .selectedProgramReceived,
                    object: program
                )
            }
        } catch {
            print("❌ Failed to decode received selected program: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func handleTrainingAction(_ action: String, message: [String: Any]) {
        switch action {
        case "start_workout":
            print("⌚ Watch requested to start workout")
            // Handle workout start on phone if needed
            
        case "end_workout":
            print("⌚ Watch ended workout")
            // Handle workout end on phone if needed
            
        case "sync_programs":
            print("⌚ Watch requested program sync")
            let allPrograms = TrainingProgramManager.shared.allPrograms
            sendTrainingPrograms(allPrograms)
            
        default:
            print("❓ Unknown training action: \(action)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let trainingProgramsReceived = Notification.Name("trainingProgramsReceived")
    static let selectedProgramReceived = Notification.Name("selectedProgramReceived")
    static let watchWorkoutStarted = Notification.Name("watchWorkoutStarted")
    static let watchWorkoutEnded = Notification.Name("watchWorkoutEnded")
    static let trainingProgramsSynced = Notification.Name("trainingProgramsSynced")
    static let trainingProgramsSyncFailed = Notification.Name("trainingProgramsSyncFailed")
    static let selectedProgramSynced = Notification.Name("selectedProgramSynced")
    static let selectedProgramSyncFailed = Notification.Name("selectedProgramSyncFailed")
}

// MARK: - TrainingProgramManager Watch Integration

extension TrainingProgramManager {
    
    func syncToWatch() {
        let watchManager = ServiceLocator.shared.watchManager
        watchManager.sendTrainingPrograms(allPrograms)
    }
    
    func sendSelectedProgramToWatch(_ program: TrainingProgram) {
        let watchManager = ServiceLocator.shared.watchManager
        watchManager.sendSelectedProgram(program)
    }
    
    func saveCustomProgramWithSync(_ program: TrainingProgram) {
        customPrograms.append(program)
        saveToUserDefaults()
        
        // Auto-sync to watch when new program is created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.syncToWatch()
        }
    }
}
