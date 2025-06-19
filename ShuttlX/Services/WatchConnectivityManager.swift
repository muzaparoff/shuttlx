import Foundation
#if os(iOS)
import WatchConnectivity
#endif

class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var isWatchConnected = false
    @Published var isWatchAppInstalled = false
    @Published var lastSyncTime: Date?
    @Published var syncStatus: String = "Not Connected"
    
    // MARK: - Singleton
    static let shared = WatchConnectivityManager()
    
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
    
    // MARK: - Custom Workout Sync Methods
    
    func sendCustomWorkoutCreated(_ workout: TrainingProgram) {
        #if os(iOS)
        guard WCSession.default.isReachable else {
            print("⌚ Watch not reachable, queuing custom workout creation")
            queueCustomWorkoutOperation(.create(workout))
            scheduleRetrySync()
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let workoutData = try encoder.encode(workout)
            
            let message = [
                "action": "custom_workout_created",
                "workout_data": workoutData,
                "workout_id": workout.id.uuidString,
                "timestamp": Date().timeIntervalSince1970
            ] as [String : Any]
            
            WCSession.default.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    print("✅ Custom workout creation sent to watch successfully")
                    self.lastSyncTime = Date()
                    self.syncStatus = "Synced"
                    
                    // Send notification for UI updates
                    NotificationCenter.default.post(name: NSNotification.Name("customWorkoutSyncedToWatch"), object: workout)
                }
            }) { error in
                DispatchQueue.main.async {
                    print("❌ Failed to send custom workout creation: \(error.localizedDescription)")
                    self.syncStatus = "Sync Failed"
                    self.queueCustomWorkoutOperation(.create(workout))
                    self.scheduleRetrySync()
                }
            }
            
            // ALSO update application context as backup sync method
            Task { [weak self] in
                do {
                    try await self?.updateApplicationContextWithWorkout(workout)
                } catch {
                    print("❌ Failed to update application context: \(error)")
                }
            }
            
        } catch {
            print("❌ Failed to encode custom workout: \(error)")
        }
        #endif
    }
    
    private func updateApplicationContextWithWorkout(_ workout: TrainingProgram) async throws {
        #if os(iOS)
        await MainActor.run {
            do {
                let allPrograms = TrainingProgramManager.shared.allPrograms
                let encoder = JSONEncoder()
                let programsData = try encoder.encode(allPrograms)
                
                let contextData = [
                    "training_programs": programsData,
                    "timestamp": Date().timeIntervalSince1970,
                    "sync_type": "custom_workout_update",
                    "latest_workout_id": workout.id.uuidString
                ] as [String : Any]
                
                try WCSession.default.updateApplicationContext(contextData)
                print("📱 ✅ Updated application context with new custom workout as backup")
            } catch {
                print("❌ Failed to update application context: \(error)")
            }
        }
        #endif
    }
    
    func sendCustomWorkoutUpdated(_ workout: TrainingProgram) {
        #if os(iOS)
        guard WCSession.default.isReachable else {
            print("⌚ Watch not reachable, queuing custom workout update")
            queueCustomWorkoutOperation(.update(workout))
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let workoutData = try encoder.encode(workout)
            
            let message = [
                "action": "custom_workout_updated",
                "workout_data": workoutData,
                "workout_id": workout.id.uuidString,
                "timestamp": Date().timeIntervalSince1970
            ] as [String : Any]
            
            WCSession.default.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    print("✅ Custom workout update sent to watch successfully")
                    self.lastSyncTime = Date()
                    self.syncStatus = "Synced"
                }
            }) { error in
                DispatchQueue.main.async {
                    print("❌ Failed to send custom workout update: \(error.localizedDescription)")
                    self.syncStatus = "Sync Failed"
                    self.queueCustomWorkoutOperation(.update(workout))
                }
            }
        } catch {
            print("❌ Failed to encode custom workout update: \(error)")
        }
        #endif
    }
    
    func sendCustomWorkoutDeleted(_ workoutId: String) {
        #if os(iOS)
        guard WCSession.default.isReachable else {
            print("⌚ Watch not reachable, queuing custom workout deletion")
            queueCustomWorkoutOperation(.delete(workoutId))
            return
        }
        
        let message = [
            "action": "custom_workout_deleted",
            "workout_id": workoutId,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        WCSession.default.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                print("✅ Custom workout deletion sent to watch successfully")
                self.lastSyncTime = Date()
                self.syncStatus = "Synced"
            }
        }) { error in
            DispatchQueue.main.async {
                print("❌ Failed to send custom workout deletion: \(error.localizedDescription)")
                self.syncStatus = "Sync Failed"
                self.queueCustomWorkoutOperation(.delete(workoutId))
            }
        }
        #endif
    }
    
    func sendAllCustomWorkouts(_ workouts: [TrainingProgram]) {
        #if os(iOS)
        guard WCSession.default.isReachable else {
            print("⌚ Watch not reachable, queuing custom workouts for later sync")
            queueCustomWorkoutsForSync(workouts)
            scheduleRetrySync()
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let workoutsData = try encoder.encode(workouts)
            
            // First try immediate message
            let message = [
                "action": "sync_all_custom_workouts",
                "workouts_data": workoutsData,
                "count": workouts.count,
                "timestamp": Date().timeIntervalSince1970
            ] as [String : Any]
            
            WCSession.default.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    print("✅ All custom workouts sent to watch successfully")
                    self.lastSyncTime = Date()
                    self.syncStatus = "Synced"
                    
                    // Also update application context as backup
                    self.updateApplicationContextWithAllPrograms()
                }
            }) { error in
                DispatchQueue.main.async {
                    print("❌ Failed to send all custom workouts: \(error.localizedDescription)")
                    self.syncStatus = "Sync Failed"
                    
                    // Queue for retry
                    self.queueCustomWorkoutsForSync(workouts)
                    self.scheduleRetrySync()
                }
            }
        } catch {
            print("❌ Failed to encode all custom workouts: \(error)")
        }
        #endif
    }
    
    private func queueCustomWorkoutsForSync(_ workouts: [TrainingProgram]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(workouts)
            UserDefaults.standard.set(data, forKey: "queued_custom_workouts")
            UserDefaults.standard.synchronize()
            print("💾 Queued \(workouts.count) custom workouts for later sync")
        } catch {
            print("❌ Failed to queue custom workouts for sync: \(error.localizedDescription)")
        }
    }
    
    private func processQueuedCustomWorkouts() {
        guard WCSession.default.isReachable else { return }
        
        if let data = UserDefaults.standard.data(forKey: "queued_custom_workouts") {
            do {
                let decoder = JSONDecoder()
                let workouts = try decoder.decode([TrainingProgram].self, from: data)
                
                // Send queued workouts
                sendAllCustomWorkouts(workouts)
                
                // Clear queue after successful send
                UserDefaults.standard.removeObject(forKey: "queued_custom_workouts")
            } catch {
                print("❌ Failed to process queued custom workouts: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Workout Results Sync
    
    func handleWorkoutResultsFromWatch(_ workoutResults: WorkoutResults) {
        #if os(iOS)
        print("📱 Received workout results from watch")
        
        // Save to iOS workout history
        var allWorkouts: [WorkoutResults] = []
        
        // Load existing workouts
        if let existingData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS"),
           let existing = try? JSONDecoder().decode([WorkoutResults].self, from: existingData) {
            allWorkouts = existing
        }
        
        // Check if this workout already exists (avoid duplicates)
        if !allWorkouts.contains(where: { $0.workoutId == workoutResults.workoutId }) {
            allWorkouts.append(workoutResults)
            
            // Keep only last 100 workouts
            if allWorkouts.count > 100 {
                allWorkouts = Array(allWorkouts.suffix(100))
            }
            
            do {
                let encoder = JSONEncoder()
                let allWorkoutsData = try encoder.encode(allWorkouts)
                UserDefaults.standard.set(allWorkoutsData, forKey: "completedWorkouts_iOS")
                
                print("✅ Workout results from watch saved to iOS")
                print("   - Duration: \(Int(workoutResults.totalDuration))s")
                print("   - Calories: \(Int(workoutResults.activeCalories))")
                print("   - Distance: \(Int(workoutResults.distance))m")
                print("   - Intervals: \(workoutResults.completedIntervals)")
                
                // Notify stats manager to refresh
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("workoutCompleted"), object: workoutResults)
                    self.lastSyncTime = Date()
                    self.syncStatus = "Synced"
                }
                
            } catch {
                print("❌ Failed to save workout results from watch: \(error)")
            }
        } else {
            print("ℹ️ Workout already exists in iOS data, skipping duplicate")
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
        guard WCSession.default.activationState == .activated else { 
            print("WCSession not activated, state: \(WCSession.default.activationState.rawValue)")
            return 
        }

        print("Sending workout data to watch: \(data.keys)")

        do {
            try WCSession.default.updateApplicationContext(data)
            print("Successfully updated application context")
            self.lastSyncTime = Date()
            self.syncStatus = "Synced"
        } catch {
            print("Error updating application context: \(error.localizedDescription)")
            self.syncStatus = "Sync Failed"
        }
        #endif
    }
    
    // MARK: - Queue Management
    
    private func queueCustomWorkoutOperation(_ operation: CustomWorkoutOperation) {
        #if os(iOS)
        var queuedOperations: [CustomWorkoutOperation] = []
        
        if let queueData = UserDefaults.standard.data(forKey: "queuedCustomWorkoutOperations"),
           let operations = try? JSONDecoder().decode([CustomWorkoutOperation].self, from: queueData) {
            queuedOperations = operations
        }
        
        queuedOperations.append(operation)
        
        do {
            let encoder = JSONEncoder()
            let queueData = try encoder.encode(queuedOperations)
            UserDefaults.standard.set(queueData, forKey: "queuedCustomWorkoutOperations")
            print("📝 Queued custom workout operation for later sync")
        } catch {
            print("❌ Failed to queue custom workout operation: \(error)")
        }
        #endif
    }
    
    func processQueuedOperations() {
        #if os(iOS)
        guard WCSession.default.isReachable else { return }
        
        guard let queueData = UserDefaults.standard.data(forKey: "queuedCustomWorkoutOperations"),
              let operations = try? JSONDecoder().decode([CustomWorkoutOperation].self, from: queueData),
              !operations.isEmpty else { return }
        
        print("🔄 Processing \(operations.count) queued custom workout operations")
        
        for operation in operations {
            switch operation {
            case .create(let workout):
                sendCustomWorkoutCreated(workout)
            case .update(let workout):
                sendCustomWorkoutUpdated(workout)
            case .delete(let workoutId):
                sendCustomWorkoutDeleted(workoutId)
            }
        }
        
        // Clear the queue after processing
        UserDefaults.standard.removeObject(forKey: "queuedCustomWorkoutOperations")
        #endif
    }
    
    // MARK: - Sync Retry Management
    
    private func scheduleRetrySync() {
        #if os(iOS)
        // Retry sync after 30 seconds if connection becomes available
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            if WCSession.default.isReachable {
                print("📱 ⏰ Retry sync triggered - processing queued operations")
                self.processQueuedOperations()
            } else {
                print("📱 ⏰ Retry sync - watch still not reachable, will try again")
                // Try again in another 30 seconds if still not reachable
                self.scheduleRetrySync()
            }
        }
        #endif
    }
    
    func forceSyncAllCustomWorkouts() {
        #if os(iOS)
        Task { @MainActor in
            let customWorkouts = TrainingProgramManager.shared.customPrograms
            self.sendAllCustomWorkouts(customWorkouts)
            
            // Also update application context
            self.updateApplicationContextWithAllPrograms()
        }
        #endif
    }
    
    private func updateApplicationContextWithAllPrograms() {
        #if os(iOS)
        Task { @MainActor in
            do {
                let allPrograms = TrainingProgramManager.shared.allPrograms
                let encoder = JSONEncoder()
                let programsData = try encoder.encode(allPrograms)
                
                let contextData = [
                    "training_programs": programsData,
                    "timestamp": Date().timeIntervalSince1970,
                    "sync_type": "full_sync"
                ] as [String : Any]
                
                try WCSession.default.updateApplicationContext(contextData)
                print("📱 ✅ Updated application context with all programs")
            } catch {
                print("❌ Failed to update application context: \(error)")
            }
        }
        #endif
    }
}

// MARK: - WCSessionDelegate Implementation

#if os(iOS)
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = activationState == .activated
            self.isWatchAppInstalled = session.isWatchAppInstalled
            
            if activationState == .activated {
                self.syncStatus = "Connected"
                // Process any queued operations
                self.processQueuedOperations()
                
                // Automatically sync all custom workouts when connection is established
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.forceSyncAllCustomWorkouts()
                }
            } else {
                self.syncStatus = "Not Connected"
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
            self.syncStatus = "Inactive"
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
            self.syncStatus = "Deactivated"
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📱 Received message from watch: \(message.keys)")
        
        DispatchQueue.main.async {
            if let action = message["action"] as? String {
                switch action {
                case "workout_results":
                    self.handleWorkoutResultsMessage(message)
                case "create_custom_workout", "custom_workout_creation_request":
                    self.handleCustomWorkoutCreationRequest(message)
                case "delete_custom_workout", "custom_workout_deletion_request":
                    self.handleCustomWorkoutDeletionRequest(message)
                case "sync_programs":
                    self.handleProgramSyncRequest(message)
                default:
                    print("📱 Unknown action received from watch: \(action)")
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("📱 Received message with reply handler from watch: \(message.keys)")
        
        if let action = message["action"] as? String {
            switch action {
            case "request_custom_workouts":
                handleCustomWorkoutSyncRequest(replyHandler: replyHandler)
            case "ping":
                replyHandler(["status": "pong", "timestamp": Date().timeIntervalSince1970])
            default:
                replyHandler(["status": "unknown_action", "action": action])
            }
        } else {
            replyHandler(["status": "no_action"])
        }
    }
    
    // MARK: - Message Handlers
    
    private func handleWorkoutResultsMessage(_ message: [String: Any]) {
        guard let workoutData = message["workout_data"] as? Data else {
            print("❌ No workout data in results message")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let workoutResults = try decoder.decode(WorkoutResults.self, from: workoutData)
            handleWorkoutResultsFromWatch(workoutResults)
        } catch {
            print("❌ Failed to decode workout results: \(error)")
        }
    }
    
    private func handleCustomWorkoutCreationRequest(_ message: [String: Any]) {
        // Send notification to show custom workout creation UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("customWorkoutCreationRequested"), object: nil)
            print("📱 Custom workout creation requested from watch")
        }
    }
    
    private func handleCustomWorkoutDeletionRequest(_ message: [String: Any]) {
        guard let workoutId = message["workout_id"] as? String else {
            print("❌ No workout ID in deletion request")
            return
        }
        
        // Delete the custom workout from iOS
        Task { @MainActor in
            TrainingProgramManager.shared.deleteCustomProgramById(workoutId)
            print("📱 Custom workout deleted via watch request: \(workoutId)")
        }
    }
    
    private func handleCustomWorkoutSyncRequest(replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            let customWorkouts = TrainingProgramManager.shared.customPrograms
            
            do {
                let encoder = JSONEncoder()
                let workoutsData = try encoder.encode(customWorkouts)
                
                replyHandler([
                    "status": "success",
                    "custom_workouts": workoutsData,
                    "count": customWorkouts.count,
                    "timestamp": Date().timeIntervalSince1970
                ])
                
                print("📱 Sent \(customWorkouts.count) custom workouts to watch via reply")
                
                // Also trigger full sync
                self.sendAllCustomWorkouts(customWorkouts)
            } catch {
                replyHandler([
                    "status": "error",
                    "error": error.localizedDescription
                ])
                print("❌ Failed to send custom workouts to watch: \(error)")
            }
        }
    }
    
    private func handleProgramSyncRequest(_ message: [String: Any]) {
        // Send all training programs (including custom workouts) to watch
        Task { @MainActor in
            let allPrograms = TrainingProgramManager.shared.allPrograms
            let customWorkouts = TrainingProgramManager.shared.customPrograms
            
            print("📱 Sending \(allPrograms.count) total programs (\(customWorkouts.count) custom) to watch")
            
            // Send both default and custom programs to watch
            self.sendAllCustomWorkouts(customWorkouts)
            
            // Also update application context with all programs
            do {
                let encoder = JSONEncoder()
                let programsData = try encoder.encode(allPrograms)
                
                let contextData = [
                    "training_programs": programsData,
                    "timestamp": Date().timeIntervalSince1970,
                    "sync_type": "full_sync"
                ] as [String : Any]
                
                try WCSession.default.updateApplicationContext(contextData)
                print("📱 ✅ Updated application context with all programs")
            } catch {
                print("❌ Failed to update application context: \(error)")
            }
        }
    }
}
#endif

// MARK: - Supporting Models

enum CustomWorkoutOperation: Codable {
    case create(TrainingProgram)
    case update(TrainingProgram)
    case delete(String)
}

// MARK: - Notification Extensions

extension NSNotification.Name {
    static let customWorkoutSyncedToWatch = NSNotification.Name("customWorkoutSyncedToWatch")
    static let customWorkoutCreationRequested = NSNotification.Name("customWorkoutCreationRequested")
    static let workoutCompleted = NSNotification.Name("workoutCompleted")
    static let customWorkoutCreated = NSNotification.Name("customWorkoutCreated")
}