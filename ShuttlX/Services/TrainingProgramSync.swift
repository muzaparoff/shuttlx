//
//  TrainingProgramSync.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import WatchConnectivity

extension WatchConnectivityManager {
    
    // MARK: - Training Program Sync
    
    func sendTrainingPrograms(_ programs: [TrainingProgram]) {
        guard WCSession.default.isReachable else {
            print("⌚ Watch not reachable, queuing programs for later sync")
            queueProgramsForSync(programs)
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(programs)
            let message = ["training_programs": data]
            
            WCSession.default.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    print("✅ Training programs sent to watch successfully")
                    if let status = reply["status"] as? String {
                        print("⌚ Watch response: \(status)")
                    }
                }
            }, errorHandler: { error in
                DispatchQueue.main.async {
                    print("❌ Failed to send training programs to watch: \(error.localizedDescription)")
                    self.queueProgramsForSync(programs)
                }
            })
        } catch {
            print("❌ Failed to encode training programs: \(error.localizedDescription)")
        }
    }
    
    func sendSelectedProgram(_ program: TrainingProgram) {
        guard WCSession.default.isReachable else {
            print("⌚ Watch not reachable, storing selected program for later sync")
            UserDefaults.standard.set(program.id.uuidString, forKey: "pending_selected_program")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(program)
            let message = [
                "selected_program": data,
                "action": "start_workout"
            ]
            
            WCSession.default.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    print("✅ Selected program sent to watch successfully")
                }
            }, errorHandler: { error in
                DispatchQueue.main.async {
                    print("❌ Failed to send selected program to watch: \(error.localizedDescription)")
                }
            })
        } catch {
            print("❌ Failed to encode selected program: \(error.localizedDescription)")
        }
    }
    
    private func queueProgramsForSync(_ programs: [TrainingProgram]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(programs)
            UserDefaults.standard.set(data, forKey: "queued_training_programs")
        } catch {
            print("❌ Failed to queue training programs: \(error.localizedDescription)")
        }
    }
    
    func syncQueuedPrograms() {
        guard WCSession.default.isReachable else { return }
        
        // Sync queued programs
        if let data = UserDefaults.standard.data(forKey: "queued_training_programs") {
            do {
                let decoder = JSONDecoder()
                let programs = try decoder.decode([TrainingProgram].self, from: data)
                sendTrainingPrograms(programs)
                UserDefaults.standard.removeObject(forKey: "queued_training_programs")
            } catch {
                print("❌ Failed to decode queued programs: \(error.localizedDescription)")
            }
        }
        
        // Sync pending selected program
        if let programId = UserDefaults.standard.string(forKey: "pending_selected_program"),
           let uuid = UUID(uuidString: programId) {
            let allPrograms = TrainingProgramManager.shared.allPrograms
            if let program = allPrograms.first(where: { $0.id == uuid }) {
                sendSelectedProgram(program)
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
            handleTrainingAction(action, message: message)
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
