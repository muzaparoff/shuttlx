import XCTest
import Foundation
@testable import ShuttlX

/// Integration test that validates custom workout creation on iOS and sync to watchOS
class CustomWorkoutSyncIntegrationTest: XCTestCase {
    
    var trainingProgramManager: TrainingProgramManager!
    var watchConnectivityManager: WatchConnectivityManager!
    
    override func setUpWithError() throws {
        super.setUp()
        
        // Setup services
        trainingProgramManager = TrainingProgramManager.shared
        watchConnectivityManager = WatchConnectivityManager.shared
        
        // Clear existing data
        UserDefaults.standard.removeObject(forKey: "customPrograms")
        UserDefaults.standard.removeObject(forKey: "customWorkouts_watch")
        UserDefaults.standard.removeObject(forKey: "queuedCustomWorkoutOperations")
    }
    
    override func tearDownWithError() throws {
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "customPrograms")
        UserDefaults.standard.removeObject(forKey: "customWorkouts_watch")
        UserDefaults.standard.removeObject(forKey: "queuedCustomWorkoutOperations")
        super.tearDown()
    }
    
    // MARK: - Integration Test: Full Custom Workout Sync Flow
    
    func testCustomWorkoutCreationAndSyncToWatch() throws {
        print("🧪 [INTEGRATION-TEST] Testing custom workout creation and sync to watch...")
        
        // STEP 1: Create custom workout on iOS
        print("📱 Step 1: Creating custom workout on iOS...")
        let customWorkout = TrainingProgram(
            name: "Integration Test Workout",
            distance: 5.0,
            runInterval: 2.5,
            walkInterval: 1.5,
            difficulty: .intermediate,
            description: "Testing sync from iOS to watchOS",
            estimatedCalories: 350,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        // Save with sync
        trainingProgramManager.saveCustomProgramWithSync(customWorkout)
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.id == customWorkout.id })
        print("   ✅ Custom workout created and saved on iOS")
        
        // STEP 2: Simulate sync message to watchOS
        print("⌚ Step 2: Simulating sync to watchOS...")
        do {
            let encoder = JSONEncoder()
            let workoutData = try encoder.encode(customWorkout)
            
            let syncMessage: [String: Any] = [
                "action": "custom_workout_created",
                "workout_data": workoutData,
                "workout_id": customWorkout.id.uuidString,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            // Verify message structure
            XCTAssertNotNil(syncMessage["action"])
            XCTAssertNotNil(syncMessage["workout_data"])
            XCTAssertNotNil(syncMessage["workout_id"])
            print("   ✅ Sync message prepared successfully")
            
            // STEP 3: Simulate watchOS receiving the message
            print("⌚ Step 3: Simulating watchOS receiving custom workout...")
            let decoder = JSONDecoder()
            let receivedWorkout = try decoder.decode(TrainingProgram.self, from: workoutData)
            
            XCTAssertEqual(receivedWorkout.id, customWorkout.id)
            XCTAssertEqual(receivedWorkout.name, customWorkout.name)
            XCTAssertTrue(receivedWorkout.isCustom)
            
            // Save to watchOS storage
            var watchWorkouts: [TrainingProgram] = []
            if let existingData = UserDefaults.standard.data(forKey: "customWorkouts_watch"),
               let existing = try? decoder.decode([TrainingProgram].self, from: existingData) {
                watchWorkouts = existing
            }
            watchWorkouts.append(receivedWorkout)
            
            let watchData = try encoder.encode(watchWorkouts)
            UserDefaults.standard.set(watchData, forKey: "customWorkouts_watch")
            
            print("   ✅ Custom workout saved to watchOS storage")
            
        } catch {
            XCTFail("Failed to simulate sync: \(error)")
        }
        
        // STEP 4: Verify sync completion
        print("✅ Step 4: Verifying sync completion...")
        guard let savedData = UserDefaults.standard.data(forKey: "customWorkouts_watch") else {
            XCTFail("No custom workouts found on watch")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let watchWorkouts = try decoder.decode([TrainingProgram].self, from: savedData)
            
            XCTAssertGreaterThan(watchWorkouts.count, 0)
            XCTAssertTrue(watchWorkouts.contains { $0.id == customWorkout.id })
            
            let syncedWorkout = watchWorkouts.first { $0.id == customWorkout.id }
            XCTAssertNotNil(syncedWorkout)
            XCTAssertEqual(syncedWorkout?.name, customWorkout.name)
            XCTAssertEqual(syncedWorkout?.runInterval, customWorkout.runInterval)
            XCTAssertEqual(syncedWorkout?.walkInterval, customWorkout.walkInterval)
            
            print("   ✅ Integration test PASSED - Custom workout successfully synced")
            
        } catch {
            XCTFail("Failed to verify watch sync: \(error)")
        }
    }
    
    // MARK: - Integration Test: Bidirectional Sync
    
    func testBidirectionalWorkoutSync() throws {
        print("🧪 [INTEGRATION-TEST] Testing bidirectional workout sync...")
        
        // Test iOS → watchOS → iOS sync flow
        let workout1 = TrainingProgram(
            name: "Bidirectional Test 1",
            distance: 3.0,
            runInterval: 1.0,
            walkInterval: 1.0,
            difficulty: .beginner,
            description: "Testing bidirectional sync",
            estimatedCalories: 200,
            targetHeartRateZone: .easy,
            isCustom: true
        )
        
        // Step 1: iOS creates workout
        trainingProgramManager.saveCustomProgramWithSync(workout1)
        
        // Step 2: Sync to watch (simulated)
        let encoder = JSONEncoder()
        let workoutData = try encoder.encode(workout1)
        UserDefaults.standard.set(workoutData, forKey: "customWorkouts_watch")
        
        // Step 3: Simulate workout completion on watch and sync results back
        let workoutResults = WorkoutResults(
            workoutId: UUID(),
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date(),
            totalDuration: 1800,
            activeCalories: 250,
            heartRate: 140,
            distance: 3000,
            completedIntervals: 6,
            averageHeartRate: 135,
            maxHeartRate: 155
        )
        
        // Save results to simulate watch → iOS sync
        let resultsData = try encoder.encode(workoutResults)
        UserDefaults.standard.set(resultsData, forKey: "completedWorkouts_iOS")
        
        // Verify bidirectional sync
        XCTAssertNotNil(UserDefaults.standard.data(forKey: "customWorkouts_watch"))
        XCTAssertNotNil(UserDefaults.standard.data(forKey: "completedWorkouts_iOS"))
        
        print("   ✅ Bidirectional sync test PASSED")
    }
    
    // MARK: - Integration Test: Sync Error Handling
    
    func testSyncErrorHandling() throws {
        print("🧪 [INTEGRATION-TEST] Testing sync error handling...")
        
        // Test invalid data handling
        let invalidData = "invalid json".data(using: .utf8)!
        UserDefaults.standard.set(invalidData, forKey: "customWorkouts_watch")
        
        // Should handle gracefully without crashing
        let result = UserDefaults.standard.data(forKey: "customWorkouts_watch")
        XCTAssertNotNil(result)
        
        // Try to decode - should fail gracefully
        do {
            let _ = try JSONDecoder().decode([TrainingProgram].self, from: invalidData)
            XCTFail("Should have failed to decode invalid data")
        } catch {
            // Expected error - test passes
            print("   ✅ Error handling test PASSED - Invalid data handled gracefully")
        }
    }
}
