//
//  EnhancedSyncTests.swift
//  Tests
//
//  Tests for enhanced custom workout sync functionality
//

import XCTest
@testable import ShuttlX

final class EnhancedSyncTests: XCTestCase {
    
    var trainingProgramManager: TrainingProgramManager!
    var watchConnectivityManager: WatchConnectivityManager!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        trainingProgramManager = TrainingProgramManager.shared
        watchConnectivityManager = WatchConnectivityManager.shared
        
        // Clear any existing custom programs for clean testing
        trainingProgramManager.customPrograms.removeAll()
    }
    
    override func tearDownWithError() throws {
        trainingProgramManager = nil
        watchConnectivityManager = nil
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "customPrograms")
        UserDefaults.standard.removeObject(forKey: "queuedCustomWorkoutOperations")
    }
    
    // MARK: - Enhanced Sync Tests
    
    func testEnhancedCustomWorkoutCreationSync() throws {
        print("\n🧪 Testing enhanced custom workout creation and sync...")
        
        // Given: A new custom workout
        let customWorkout = TrainingProgram(
            name: "Enhanced Sync Test Workout",
            distance: 3.5,
            runInterval: 1.5,
            walkInterval: 1.0,
            totalDuration: 20.0,
            difficulty: .intermediate,
            description: "Testing enhanced sync functionality",
            estimatedCalories: 200,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        // When: Saving with enhanced sync
        trainingProgramManager.saveCustomProgramWithSync(customWorkout)
        
        // Then: Should be in custom programs
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.id == customWorkout.id })
        XCTAssertEqual(trainingProgramManager.customPrograms.count, 1)
        
        print("   ✅ Custom workout saved successfully")
        
        // And: Should be in all programs for sync
        let allPrograms = trainingProgramManager.allPrograms
        XCTAssertTrue(allPrograms.contains { $0.id == customWorkout.id && $0.isCustom })
        
        print("   ✅ Custom workout included in all programs")
        
        // And: Should be serializable for watch sync
        let encoder = JSONEncoder()
        let syncData = try encoder.encode(allPrograms)
        XCTAssertGreaterThan(syncData.count, 0)
        
        // Verify it can be decoded back
        let decoder = JSONDecoder()
        let decodedPrograms = try decoder.decode([TrainingProgram].self, from: syncData)
        let syncedCustomWorkout = decodedPrograms.first { $0.id == customWorkout.id }
        
        XCTAssertNotNil(syncedCustomWorkout)
        XCTAssertEqual(syncedCustomWorkout?.name, customWorkout.name)
        XCTAssertTrue(syncedCustomWorkout?.isCustom ?? false)
        
        print("   ✅ Enhanced sync serialization verified")
        print("✅ Enhanced custom workout creation sync test PASSED")
    }
    
    func testMultipleCustomWorkoutSync() throws {
        print("\n🧪 Testing multiple custom workout sync...")
        
        // Given: Multiple custom workouts
        let customWorkouts = [
            TrainingProgram(
                name: "Multi Sync Test 1",
                distance: 2.0,
                runInterval: 1.0,
                walkInterval: 0.5,
                totalDuration: 15.0,
                difficulty: .beginner,
                description: "First workout for multi-sync test",
                estimatedCalories: 120,
                targetHeartRateZone: .easy,
                isCustom: true
            ),
            TrainingProgram(
                name: "Multi Sync Test 2",
                distance: 4.0,
                runInterval: 2.0,
                walkInterval: 1.0,
                totalDuration: 25.0,
                difficulty: .intermediate,
                description: "Second workout for multi-sync test",
                estimatedCalories: 220,
                targetHeartRateZone: .moderate,
                isCustom: true
            ),
            TrainingProgram(
                name: "Multi Sync Test 3",
                distance: 6.0,
                runInterval: 3.0,
                walkInterval: 1.5,
                totalDuration: 35.0,
                difficulty: .advanced,
                description: "Third workout for multi-sync test",
                estimatedCalories: 350,
                targetHeartRateZone: .hard,
                isCustom: true
            )
        ]
        
        // When: Adding all custom workouts
        for workout in customWorkouts {
            trainingProgramManager.saveCustomProgramWithSync(workout)
        }
        
        // Then: All should be saved
        XCTAssertEqual(trainingProgramManager.customPrograms.count, 3)
        
        for workout in customWorkouts {
            XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.id == workout.id })
        }
        
        print("   ✅ All custom workouts saved")
        
        // And: All should be in sync data
        let allPrograms = trainingProgramManager.allPrograms
        let customProgramsInAll = allPrograms.filter { $0.isCustom }
        XCTAssertEqual(customProgramsInAll.count, 3)
        
        print("   ✅ All custom workouts included in sync data")
        print("✅ Multiple custom workout sync test PASSED")
    }
    
    func testCustomWorkoutUpdateSync() throws {
        print("\n🧪 Testing custom workout update sync...")
        
        // Given: An existing custom workout
        let originalWorkout = TrainingProgram(
            name: "Update Test Original",
            distance: 3.0,
            runInterval: 1.5,
            walkInterval: 1.0,
            totalDuration: 20.0,
            difficulty: .beginner,
            description: "Original description",
            estimatedCalories: 180,
            targetHeartRateZone: .easy,
            isCustom: true
        )
        
        trainingProgramManager.saveCustomProgramWithSync(originalWorkout)
        XCTAssertEqual(trainingProgramManager.customPrograms.count, 1)
        
        // When: Updating the workout
        var updatedWorkout = originalWorkout
        updatedWorkout.name = "Update Test Modified"
        updatedWorkout.description = "Updated description"
        updatedWorkout.difficulty = .intermediate
        updatedWorkout.estimatedCalories = 220
        
        trainingProgramManager.updateCustomProgram(updatedWorkout)
        
        // Then: Should be updated in custom programs
        XCTAssertEqual(trainingProgramManager.customPrograms.count, 1)
        let savedWorkout = trainingProgramManager.customPrograms.first { $0.id == originalWorkout.id }
        
        XCTAssertNotNil(savedWorkout)
        XCTAssertEqual(savedWorkout?.name, "Update Test Modified")
        XCTAssertEqual(savedWorkout?.description, "Updated description")
        XCTAssertEqual(savedWorkout?.difficulty, .intermediate)
        XCTAssertEqual(savedWorkout?.estimatedCalories, 220)
        
        print("   ✅ Custom workout update verified")
        print("✅ Custom workout update sync test PASSED")
    }
    
    func testCustomWorkoutDeletionSync() throws {
        print("\n🧪 Testing custom workout deletion sync...")
        
        // Given: Multiple custom workouts
        let workout1 = TrainingProgram(
            name: "Delete Test 1",
            distance: 2.0,
            runInterval: 1.0,
            walkInterval: 0.5,
            totalDuration: 15.0,
            difficulty: .beginner,
            description: "First workout for deletion test",
            estimatedCalories: 120,
            targetHeartRateZone: .easy,
            isCustom: true
        )
        
        let workout2 = TrainingProgram(
            name: "Delete Test 2",
            distance: 3.0,
            runInterval: 1.5,
            walkInterval: 1.0,
            totalDuration: 20.0,
            difficulty: .intermediate,
            description: "Second workout for deletion test",
            estimatedCalories: 180,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        trainingProgramManager.saveCustomProgramWithSync(workout1)
        trainingProgramManager.saveCustomProgramWithSync(workout2)
        
        XCTAssertEqual(trainingProgramManager.customPrograms.count, 2)
        
        // When: Deleting one workout
        trainingProgramManager.deleteCustomProgramById(workout1.id.uuidString)
        
        // Then: Should only have one workout left
        XCTAssertEqual(trainingProgramManager.customPrograms.count, 1)
        XCTAssertFalse(trainingProgramManager.customPrograms.contains { $0.id == workout1.id })
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.id == workout2.id })
        
        print("   ✅ Custom workout deletion verified")
        print("✅ Custom workout deletion sync test PASSED")
    }
    
    // MARK: - Performance and Stress Tests
    
    func testSyncPerformanceWithManyWorkouts() throws {
        print("\n🧪 Testing sync performance with many custom workouts...")
        
        // Given: Many custom workouts
        var manyWorkouts: [TrainingProgram] = []
        for i in 0..<50 {
            let workout = TrainingProgram(
                name: "Performance Test \(i)",
                distance: Double(i % 10 + 1),
                runInterval: Double(i % 3 + 1),
                walkInterval: Double(i % 2 + 1),
                totalDuration: Double(i % 20 + 10),
                difficulty: TrainingDifficulty.allCases[i % 3],
                description: "Performance test workout \(i)",
                estimatedCalories: (i % 10 + 1) * 50,
                targetHeartRateZone: HeartRateZone.allCases[i % 5],
                isCustom: true
            )
            manyWorkouts.append(workout)
        }
        
        // When: Measuring sync performance
        measure {
            for workout in manyWorkouts {
                trainingProgramManager.customPrograms.append(workout)
            }
            
            // Simulate sync encoding
            let encoder = JSONEncoder()
            let allPrograms = trainingProgramManager.allPrograms
            _ = try? encoder.encode(allPrograms)
            
            // Clean up for next iteration
            trainingProgramManager.customPrograms.removeAll()
        }
        
        print("   ✅ Sync performance test completed")
        print("✅ Sync performance test PASSED")
    }
    
    func testConcurrentSyncOperations() throws {
        print("\n🧪 Testing concurrent sync operations...")
        
        let expectation = XCTestExpectation(description: "Concurrent operations completed")
        expectation.expectedFulfillmentCount = 3
        
        // When: Performing concurrent operations
        DispatchQueue.global(qos: .userInitiated).async {
            let workout1 = TrainingProgram(
                name: "Concurrent Test 1",
                distance: 2.0,
                runInterval: 1.0,
                walkInterval: 0.5,
                totalDuration: 15.0,
                difficulty: .beginner,
                description: "First concurrent workout",
                estimatedCalories: 120,
                targetHeartRateZone: .easy,
                isCustom: true
            )
            self.trainingProgramManager.saveCustomProgramWithSync(workout1)
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let workout2 = TrainingProgram(
                name: "Concurrent Test 2",
                distance: 3.0,
                runInterval: 1.5,
                walkInterval: 1.0,
                totalDuration: 20.0,
                difficulty: .intermediate,
                description: "Second concurrent workout",
                estimatedCalories: 180,
                targetHeartRateZone: .moderate,
                isCustom: true
            )
            self.trainingProgramManager.saveCustomProgramWithSync(workout2)
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let workout3 = TrainingProgram(
                name: "Concurrent Test 3",
                distance: 4.0,
                runInterval: 2.0,
                walkInterval: 1.5,
                totalDuration: 25.0,
                difficulty: .advanced,
                description: "Third concurrent workout",
                estimatedCalories: 250,
                targetHeartRateZone: .hard,
                isCustom: true
            )
            self.trainingProgramManager.saveCustomProgramWithSync(workout3)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then: All workouts should be saved without corruption
        XCTAssertEqual(trainingProgramManager.customPrograms.count, 3)
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.name == "Concurrent Test 1" })
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.name == "Concurrent Test 2" })
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.name == "Concurrent Test 3" })
        
        print("   ✅ Concurrent operations completed without data corruption")
        print("✅ Concurrent sync operations test PASSED")
    }
}
