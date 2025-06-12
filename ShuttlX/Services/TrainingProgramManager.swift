//
//  TrainingProgramManager.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import SwiftUI

@MainActor
class TrainingProgramManager: ObservableObject {
    static let shared = TrainingProgramManager()
    
    // MARK: - Published Properties
    @Published var customPrograms: [TrainingProgram] = []
    @Published var isSyncingToCloud = false
    @Published var cloudSyncEnabled = true
    @Published var lastCloudSync: Date?
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let customProgramsKey = "customPrograms"
    private let cloudKitManager = CloudKitManager()
    
    // MARK: - Default Programs
    let defaultPrograms = TrainingModels.defaultPrograms
    
    // MARK: - Initialization
    private init() {
        loadCustomPrograms()
        setupCloudKitIntegration()
    }
    
    // MARK: - All Programs
    var allPrograms: [TrainingProgram] {
        return defaultPrograms + customPrograms
    }
    
    // MARK: - Custom Program Management with CloudKit Integration
    
    func saveCustomProgram(_ program: TrainingProgram) {
        customPrograms.append(program)
        saveToUserDefaults()
        
        // Sync to CloudKit if enabled
        if cloudSyncEnabled {
            Task {
                await syncToCloudKit(program)
            }
        }
    }
    
    func deleteCustomProgram(_ program: TrainingProgram) {
        customPrograms.removeAll { $0.id == program.id }
        saveToUserDefaults()
        
        // Delete from CloudKit if enabled
        if cloudSyncEnabled {
            Task {
                await deleteFromCloudKit(program.id.uuidString)
            }
        }
    }
    
    func updateCustomProgram(_ program: TrainingProgram) {
        if let index = customPrograms.firstIndex(where: { $0.id == program.id }) {
            customPrograms[index] = program
            saveToUserDefaults()
            
            // Update in CloudKit if enabled
            if cloudSyncEnabled {
                Task {
                    await syncToCloudKit(program)
                }
            }
        }
    }
    
    // MARK: - CloudKit Integration
    
    private func setupCloudKitIntegration() {
        // Setup automatic sync when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.syncFromCloudKit()
            }
        }
        
        // Listen for CloudKit sync notifications
        NotificationCenter.default.addObserver(
            forName: .cloudKitDataSynced,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lastCloudSync = Date()
        }
        
        // Start automatic sync
        cloudKitManager.startAutomaticSync()
    }
    
    /// Sync custom program to CloudKit
    private func syncToCloudKit(_ program: TrainingProgram) async {
        do {
            isSyncingToCloud = true
            try await cloudKitManager.saveCustomWorkout(program)
            print("✅ Synced custom program to CloudKit: \(program.name)")
        } catch {
            print("❌ Failed to sync custom program to CloudKit: \(error)")
            // Queue for later sync if offline
            cloudKitManager.queueChange(.update(program))
        }
        isSyncingToCloud = false
    }
    
    /// Delete custom program from CloudKit
    private func deleteFromCloudKit(_ workoutID: String) async {
        do {
            isSyncingToCloud = true
            try await cloudKitManager.deleteCustomWorkout(workoutID: workoutID)
            print("✅ Deleted custom program from CloudKit: \(workoutID)")
        } catch {
            print("❌ Failed to delete custom program from CloudKit: \(error)")
            // Queue for later sync if offline
            cloudKitManager.queueChange(.delete(workoutID))
        }
        isSyncingToCloud = false
    }
    
    /// Sync all custom programs from CloudKit
    func syncFromCloudKit() async {
        do {
            isSyncingToCloud = true
            let cloudPrograms = try await cloudKitManager.fetchCustomWorkouts()
            
            // Merge cloud programs with local programs
            await mergeCloudPrograms(cloudPrograms)
            
            print("✅ Synced \(cloudPrograms.count) custom programs from CloudKit")
            lastCloudSync = Date()
            
        } catch {
            print("❌ Failed to sync from CloudKit: \(error)")
        }
        isSyncingToCloud = false
    }
    
    /// Merge cloud programs with local programs, handling conflicts
    private func mergeCloudPrograms(_ cloudPrograms: [TrainingProgram]) async {
        var mergedPrograms = customPrograms
        var hasChanges = false
        
        // Add or update programs from cloud
        for cloudProgram in cloudPrograms {
            if let existingIndex = mergedPrograms.firstIndex(where: { $0.id == cloudProgram.id }) {
                // Update existing program if cloud version is newer
                if cloudProgram.createdDate > mergedPrograms[existingIndex].createdDate {
                    mergedPrograms[existingIndex] = cloudProgram
                    hasChanges = true
                    print("📝 Updated local program from cloud: \(cloudProgram.name)")
                }
            } else {
                // Add new program from cloud
                mergedPrograms.append(cloudProgram)
                hasChanges = true
                print("➕ Added new program from cloud: \(cloudProgram.name)")
            }
        }
        
        // Update local storage if there were changes
        if hasChanges {
            customPrograms = mergedPrograms
            saveToUserDefaults()
        }
    }
    
    /// Force full sync - useful for troubleshooting
    func forcefulSync() async {
        print("🔄 Starting forceful CloudKit sync...")
        
        // First, sync any pending changes
        do {
            try await cloudKitManager.syncPendingChanges()
        } catch {
            print("❌ Failed to sync pending changes: \(error)")
        }
        
        // Then sync from CloudKit
        await syncFromCloudKit()
        
        // Finally, sync all local programs to CloudKit
        for program in customPrograms {
            await syncToCloudKit(program)
        }
        
        print("✅ Forceful sync completed")
    }
    
    // MARK: - Persistence
    private func saveToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(customPrograms)
            userDefaults.set(data, forKey: customProgramsKey)
        } catch {
            print("Failed to save custom programs: \(error)")
        }
    }
    
    private func loadCustomPrograms() {
        guard let data = userDefaults.data(forKey: customProgramsKey) else { return }
        
        do {
            customPrograms = try JSONDecoder().decode([TrainingProgram].self, from: data)
        } catch {
            print("Failed to load custom programs: \(error)")
            customPrograms = []
        }
    }
    
    // MARK: - Watch Connectivity Integration
    func saveCustomProgramWithSync(_ program: TrainingProgram) {
        customPrograms.append(program)
        saveToUserDefaults()
        
        // Sync to CloudKit
        if cloudSyncEnabled {
            Task {
                await syncToCloudKit(program)
            }
        }
        
        // ENHANCED: Auto-sync to watch when new program is created with multiple sync methods
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.syncToWatch()
            // Send specific custom workout creation notification to watch
            WatchConnectivityManager.shared.sendCustomWorkoutCreated(program)
            
            // Also send all custom workouts to ensure full sync
            WatchConnectivityManager.shared.sendAllCustomWorkouts(self.customPrograms)
            
            print("📡 ✅ Enhanced custom workout sync initiated for: \(program.name)")
        }
        
        // Send notification for stats refresh
        NotificationCenter.default.post(name: .customWorkoutCreated, object: program)
    }
    
    func updateCustomProgram(_ program: TrainingProgram) {
        if let index = customPrograms.firstIndex(where: { $0.id == program.id }) {
            customPrograms[index] = program
            saveToUserDefaults()
            
            // Sync to CloudKit
            if cloudSyncEnabled {
                Task {
                    await syncToCloudKit(program)
                }
            }
            
            // Sync to watch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.syncToWatch()
                WatchConnectivityManager.shared.sendCustomWorkoutUpdated(program)
            }
            
            print("✅ Custom program updated: \(program.name)")
        }
    }
    
    func deleteCustomProgramById(_ id: String) {
        customPrograms.removeAll { $0.id.uuidString == id }
        saveToUserDefaults()
        
        // Sync deletion to CloudKit
        if cloudSyncEnabled {
            Task {
                await deleteFromCloudKit(id)
            }
        }
        
        // Sync deletion to watch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.syncToWatch()
            WatchConnectivityManager.shared.sendCustomWorkoutDeleted(id)
        }
        
        print("✅ Custom program deleted: \(id)")
    }
    
    func syncToWatch() {
        let watchManager = ServiceLocator.shared.watchManager
        
        // Send all programs via standard method
        watchManager.sendTrainingPrograms(allPrograms)
        
        // Send custom workouts via enhanced method for better handling
        WatchConnectivityManager.shared.sendAllCustomWorkouts(customPrograms)
        
        print("📡 Synced \(allPrograms.count) total programs to watch (\(customPrograms.count) custom)")
    }
    
    func sendSelectedProgramToWatch(_ program: TrainingProgram) {
        let watchManager = ServiceLocator.shared.watchManager
        watchManager.sendSelectedProgram(program)
    }
}
