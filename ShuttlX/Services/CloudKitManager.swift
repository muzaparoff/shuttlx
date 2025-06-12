//
//  CloudKitManager.swift
//  ShuttlX
//
//  Created by ShuttlX on 12/13/24.
//

import Foundation
import CloudKit
import SwiftUI

// MARK: - CloudKit Manager for Custom Workout Backup

@MainActor
class CloudKitManager: ObservableObject {
    // MARK: - Properties
    private let container = CKContainer.default()
    private let database: CKDatabase
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    // CloudKit Configuration
    private let customWorkoutRecordType = "CustomWorkout"
    private let workoutResultRecordType = "WorkoutResult"
    
    // MARK: - Initialization
    init() {
        self.database = container.privateCloudDatabase
        print("☁️ CloudKitManager initialized")
    }
    
    // MARK: - Account Status
    func checkAccountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }
    
    // MARK: - Custom Workout CRUD Operations
    
    /// Save custom workout to CloudKit
    func saveCustomWorkout(_ workout: TrainingProgram) async throws {
        guard !workout.name.isEmpty else {
            throw CloudKitError.invalidData("Workout name cannot be empty")
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let record = try createWorkoutRecord(from: workout)
            let savedRecord = try await database.save(record)
            
            print("☁️ ✅ Custom workout saved to CloudKit: \(workout.name)")
            lastSyncDate = Date()
            syncError = nil
            
            // Update local record with CloudKit ID if needed
            await updateLocalWorkoutWithCloudKitID(workout: workout, record: savedRecord)
            
        } catch {
            syncError = "Failed to save workout: \(error.localizedDescription)"
            print("☁️ ❌ Failed to save custom workout to CloudKit: \(error)")
            throw error
        }
    }
    
    /// Fetch all custom workouts from CloudKit
    func fetchCustomWorkouts() async throws -> [TrainingProgram] {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let query = CKQuery(recordType: customWorkoutRecordType, predicate: NSPredicate(format: "isDeleted == %@", NSNumber(value: false)))
            query.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]
            
            let (records, _) = try await database.records(matching: query)
            
            var workouts: [TrainingProgram] = []
            
            for (_, result) in records {
                switch result {
                case .success(let record):
                    if let workout = createWorkoutFromRecord(record) {
                        workouts.append(workout)
                    }
                case .failure(let error):
                    print("☁️ ❌ Failed to fetch workout record: \(error)")
                }
            }
            
            print("☁️ ✅ Fetched \(workouts.count) custom workouts from CloudKit")
            lastSyncDate = Date()
            syncError = nil
            
            return workouts
            
        } catch {
            syncError = "Failed to fetch workouts: \(error.localizedDescription)"
            print("☁️ ❌ Failed to fetch custom workouts from CloudKit: \(error)")
            throw error
        }
    }
    
    /// Delete custom workout from CloudKit
    func deleteCustomWorkout(workoutID: String) async throws {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // Soft delete by marking as deleted
            let recordID = CKRecord.ID(recordName: workoutID)
            
            // Fetch the record first
            let record = try await database.record(for: recordID)
            
            // Mark as deleted
            record["isDeleted"] = true
            record["modifiedDate"] = Date()
            
            // Save the updated record
            _ = try await database.save(record)
            
            print("☁️ ✅ Custom workout marked as deleted in CloudKit: \(workoutID)")
            lastSyncDate = Date()
            syncError = nil
            
        } catch {
            syncError = "Failed to delete workout: \(error.localizedDescription)"
            print("☁️ ❌ Failed to delete custom workout from CloudKit: \(error)")
            throw error
        }
    }
    
    /// Sync pending changes when coming back online
    func syncPendingChanges() async throws {
        guard let queuedChanges = getQueuedChanges() else {
            print("☁️ No pending changes to sync")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // Process create operations
            for workout in queuedChanges.creates {
                try await saveCustomWorkout(workout)
            }
            
            // Process update operations
            for workout in queuedChanges.updates {
                try await saveCustomWorkout(workout)
            }
            
            // Process delete operations  
            for workoutID in queuedChanges.deletes {
                try await deleteCustomWorkout(workoutID: workoutID)
            }
            
            // Clear the queue after successful sync
            clearQueuedChanges()
            
            print("☁️ ✅ Successfully synced \(queuedChanges.totalOperations) pending changes")
            
        } catch {
            print("☁️ ❌ Failed to sync pending changes: \(error)")
            throw error
        }
    }
    
    // MARK: - Workout Results Backup
    
    /// Save workout results to CloudKit
    func saveWorkoutResults(_ results: [WorkoutResults]) async throws {
        guard !results.isEmpty else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            var recordsToSave: [CKRecord] = []
            
            for result in results {
                let record = createResultRecord(from: result)
                recordsToSave.append(record)
            }
            
            // Batch save for efficiency
            let saveOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            saveOperation.savePolicy = .changedKeys
            saveOperation.qualityOfService = .utility
            
            try await database.add(saveOperation)
            
            print("☁️ ✅ Saved \(results.count) workout results to CloudKit")
            lastSyncDate = Date()
            syncError = nil
            
        } catch {
            syncError = "Failed to save workout results: \(error.localizedDescription)"
            print("☁️ ❌ Failed to save workout results to CloudKit: \(error)")
            throw error
        }
    }
    
    /// Fetch workout results from CloudKit
    func fetchWorkoutResults(since date: Date? = nil) async throws -> [WorkoutResults] {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let predicate: NSPredicate
            if let date = date {
                predicate = NSPredicate(format: "startDate >= %@", date as NSDate)
            } else {
                predicate = NSPredicate(value: true)
            }
            
            let query = CKQuery(recordType: workoutResultRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
            
            let (records, _) = try await database.records(matching: query)
            
            var results: [WorkoutResults] = []
            
            for (_, result) in records {
                switch result {
                case .success(let record):
                    if let workoutResult = createWorkoutResultFromRecord(record) {
                        results.append(workoutResult)
                    }
                case .failure(let error):
                    print("☁️ ❌ Failed to fetch workout result record: \(error)")
                }
            }
            
            print("☁️ ✅ Fetched \(results.count) workout results from CloudKit")
            lastSyncDate = Date()
            syncError = nil
            
            return results
            
        } catch {
            syncError = "Failed to fetch workout results: \(error.localizedDescription)"
            print("☁️ ❌ Failed to fetch workout results from CloudKit: \(error)")
            throw error
        }
    }
    
    // MARK: - Automatic Sync
    
    /// Start automatic background sync
    func startAutomaticSync() {
        Task {
            await setupCloudKitSubscriptions()
            await performInitialSync()
        }
    }
    
    /// Setup CloudKit subscriptions for real-time updates
    private func setupCloudKitSubscriptions() async {
        do {
            // Custom Workout subscription
            let workoutPredicate = NSPredicate(format: "TRUEPREDICATE")
            let workoutSubscription = CKQuerySubscription(
                recordType: customWorkoutRecordType,
                predicate: workoutPredicate,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            workoutSubscription.notificationInfo = CKSubscription.NotificationInfo()
            workoutSubscription.notificationInfo?.shouldSendContentAvailable = true
            
            _ = try await database.save(workoutSubscription)
            
            print("☁️ ✅ CloudKit subscription setup complete")
            
        } catch {
            print("☁️ ❌ Failed to setup CloudKit subscriptions: \(error)")
        }
    }
    
    /// Perform initial sync when app launches
    private func performInitialSync() async {
        do {
            // Check if user is logged into iCloud
            let accountStatus = try await checkAccountStatus()
            
            guard accountStatus == .available else {
                print("☁️ ⚠️ iCloud account not available, skipping sync")
                return
            }
            
            // Sync any pending changes first
            try await syncPendingChanges()
            
            // Then fetch latest from CloudKit
            let cloudWorkouts = try await fetchCustomWorkouts()
            let cloudResults = try await fetchWorkoutResults()
            
            // Merge with local data
            await mergeCloudDataWithLocal(workouts: cloudWorkouts, results: cloudResults)
            
            print("☁️ ✅ Initial sync completed successfully")
            
        } catch {
            print("☁️ ❌ Initial sync failed: \(error)")
            syncError = "Sync failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func createWorkoutRecord(from workout: TrainingProgram) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: workout.id.uuidString)
        let record = CKRecord(recordType: customWorkoutRecordType, recordID: recordID)
        
        record["name"] = workout.name
        record["distance"] = workout.distance
        record["runInterval"] = workout.runInterval
        record["walkInterval"] = workout.walkInterval
        record["totalDuration"] = workout.totalDuration
        record["difficulty"] = workout.difficulty.rawValue
        record["workoutDescription"] = workout.description
        record["estimatedCalories"] = workout.estimatedCalories
        record["targetHeartRateZone"] = workout.targetHeartRateZone.rawValue
        record["createdDate"] = workout.createdDate
        record["modifiedDate"] = Date()
        record["isDeleted"] = false
        record["deviceID"] = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        record["syncVersion"] = 1
        
        return record
    }
    
    private func createWorkoutFromRecord(_ record: CKRecord) -> TrainingProgram? {
        guard let name = record["name"] as? String,
              let distance = record["distance"] as? Double,
              let runInterval = record["runInterval"] as? Double,
              let walkInterval = record["walkInterval"] as? Double,
              let totalDuration = record["totalDuration"] as? Double,
              let difficultyString = record["difficulty"] as? String,
              let difficulty = TrainingDifficulty(rawValue: difficultyString),
              let workoutDescription = record["workoutDescription"] as? String,
              let estimatedCalories = record["estimatedCalories"] as? Int,
              let heartRateZoneString = record["targetHeartRateZone"] as? String,
              let heartRateZone = HeartRateZone(rawValue: heartRateZoneString),
              let createdDate = record["createdDate"] as? Date else {
            
            print("☁️ ❌ Failed to parse workout record: \(record.recordID.recordName)")
            return nil
        }
        
        return TrainingProgram(
            name: name,
            distance: distance,
            runInterval: runInterval,
            walkInterval: walkInterval,
            totalDuration: totalDuration,
            difficulty: difficulty,
            description: workoutDescription,
            estimatedCalories: estimatedCalories,
            targetHeartRateZone: heartRateZone,
            isCustom: true
        )
    }
    
    private func createResultRecord(from result: WorkoutResults) -> CKRecord {
        let recordID = CKRecord.ID(recordName: result.workoutId.uuidString)
        let record = CKRecord(recordType: workoutResultRecordType, recordID: recordID)
        
        record["workoutID"] = result.workoutId.uuidString
        record["startDate"] = result.startDate
        record["endDate"] = result.endDate
        record["totalDuration"] = result.totalDuration
        record["activeCalories"] = result.activeCalories
        record["heartRate"] = result.heartRate
        record["distance"] = result.distance
        record["completedIntervals"] = result.completedIntervals
        record["averageHeartRate"] = result.averageHeartRate
        record["maxHeartRate"] = result.maxHeartRate
        record["deviceID"] = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        record["syncVersion"] = 1
        
        return record
    }
    
    private func createWorkoutResultFromRecord(_ record: CKRecord) -> WorkoutResults? {
        guard let workoutIDString = record["workoutID"] as? String,
              let workoutID = UUID(uuidString: workoutIDString),
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let totalDuration = record["totalDuration"] as? Double,
              let activeCalories = record["activeCalories"] as? Double,
              let heartRate = record["heartRate"] as? Double,
              let distance = record["distance"] as? Double,
              let completedIntervals = record["completedIntervals"] as? Int,
              let averageHeartRate = record["averageHeartRate"] as? Double,
              let maxHeartRate = record["maxHeartRate"] as? Double else {
            
            print("☁️ ❌ Failed to parse workout result record: \(record.recordID.recordName)")
            return nil
        }
        
        return WorkoutResults(
            workoutId: workoutID,
            startDate: startDate,
            endDate: endDate,
            totalDuration: totalDuration,
            activeCalories: activeCalories,
            heartRate: heartRate,
            distance: distance,
            completedIntervals: completedIntervals,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate
        )
    }
    
    private func updateLocalWorkoutWithCloudKitID(workout: TrainingProgram, record: CKRecord) async {
        // Update local storage with CloudKit record ID for future operations
        // This would integrate with your existing TrainingProgramManager
        print("☁️ Updated local workout with CloudKit ID: \(record.recordID.recordName)")
    }
    
    private func mergeCloudDataWithLocal(workouts: [TrainingProgram], results: [WorkoutResults]) async {
        // Merge cloud data with local data, handling conflicts appropriately
        // This would integrate with your existing data managers
        print("☁️ Merging \(workouts.count) workouts and \(results.count) results with local data")
        
        // Notify other parts of the app about updated data
        NotificationCenter.default.post(name: .cloudKitDataSynced, object: nil)
    }
    
    // MARK: - Offline Queue Management
    
    private func getQueuedChanges() -> QueuedChanges? {
        guard let data = UserDefaults.standard.data(forKey: "cloudkit_queued_changes"),
              let changes = try? JSONDecoder().decode(QueuedChanges.self, from: data) else {
            return nil
        }
        return changes
    }
    
    private func clearQueuedChanges() {
        UserDefaults.standard.removeObject(forKey: "cloudkit_queued_changes")
    }
    
    /// Queue changes for later sync when offline
    func queueChange(_ change: QueuedChange) {
        var queuedChanges = getQueuedChanges() ?? QueuedChanges()
        
        switch change {
        case .create(let workout):
            queuedChanges.creates.append(workout)
        case .update(let workout):
            queuedChanges.updates.append(workout)
        case .delete(let workoutID):
            queuedChanges.deletes.append(workoutID)
        }
        
        do {
            let data = try JSONEncoder().encode(queuedChanges)
            UserDefaults.standard.set(data, forKey: "cloudkit_queued_changes")
            print("☁️ Queued change for later sync: \(change)")
        } catch {
            print("☁️ ❌ Failed to queue change: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct QueuedChanges: Codable {
    var creates: [TrainingProgram] = []
    var updates: [TrainingProgram] = []
    var deletes: [String] = []
    
    var totalOperations: Int {
        creates.count + updates.count + deletes.count
    }
}

enum QueuedChange {
    case create(TrainingProgram)
    case update(TrainingProgram)
    case delete(String)
}

enum CloudKitError: Error, LocalizedError {
    case invalidData(String)
    case syncFailed(String)
    case accountUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .accountUnavailable:
            return "iCloud account is not available"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudKitDataSynced = Notification.Name("cloudKitDataSynced")
    static let cloudKitSyncStarted = Notification.Name("cloudKitSyncStarted")
    static let cloudKitSyncCompleted = Notification.Name("cloudKitSyncCompleted")
    static let cloudKitSyncFailed = Notification.Name("cloudKitSyncFailed")
}
