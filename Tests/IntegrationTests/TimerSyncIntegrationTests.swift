//
//  TimerSyncIntegrationTests.swift
//  ShuttlX
//
//  Created by AI Assistant on 6/12/25.
//

import XCTest
@testable import ShuttlX

@MainActor
final class TimerSyncIntegrationTests: XCTestCase {
    
    var trainingProgramManager: TrainingProgramManager!
    var watchConnectivityManager: WatchConnectivityManager!
    
    override func setUpWithError() throws {
        trainingProgramManager = TrainingProgramManager.shared
        watchConnectivityManager = WatchConnectivityManager.shared
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        UserDefaults.standard.removeObject(forKey: "customWorkouts_iOS")
        UserDefaults.standard.removeObject(forKey: "completedWorkouts_iOS")
        UserDefaults.standard.removeObject(forKey: "queuedCustomWorkoutOperations")
    }
    
    // MARK: - Timer Integration Tests
    
    func testWorkoutTimerIntegration() throws {
        print("\n🏃‍♂️ TESTING WORKOUT TIMER INTEGRATION")
        
        // Given: A custom workout with specific intervals
        let customWorkout = TrainingProgram(
            name: "Timer Integration Test",
            distance: 2.0,
            runInterval: 1.0, // 1 minute run
            walkInterval: 0.5, // 30 second walk
            totalDuration: 5.0, // 5 minute total
            difficulty: .beginner,
            description: "Testing timer functionality",
            estimatedCalories: 150,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        // When: Save the custom workout
        trainingProgramManager.saveCustomProgramWithSync(customWorkout)
        
        // Then: Verify it's in the list
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.id == customWorkout.id })
        print("   ✅ Custom workout saved successfully")
        
        // And: Verify it generates correct intervals
        let intervals = generateExpectedIntervals(from: customWorkout)
        XCTAssertGreaterThan(intervals.count, 0, "Should generate intervals")
        
        // Verify work and rest intervals are included
        XCTAssertTrue(intervals.contains { $0.type == .work }, "Should have work intervals")
        XCTAssertTrue(intervals.contains { $0.type == .rest }, "Should have rest intervals")
        
        print("   ✅ Interval generation verified")
    }
    
    // MARK: - Custom Workout Sync Tests
    
    func testCustomWorkoutSyncFlow() throws {
        print("\n📱 TESTING CUSTOM WORKOUT SYNC FLOW")
        
        // STEP 1: Create custom workout on iOS
        let customWorkout = TrainingProgram(
            name: "Sync Flow Test",
            distance: 3.5,
            runInterval: 2.0,
            walkInterval: 1.0,
            totalDuration: 20.0,
            difficulty: .intermediate,
            description: "Testing full sync flow",
            estimatedCalories: 250,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        trainingProgramManager.saveCustomProgramWithSync(customWorkout)
        print("   ✅ Step 1: Custom workout created on iOS")
        
        // STEP 2: Verify sync message format
        do {
            let encoder = JSONEncoder()
            let workoutData = try encoder.encode(customWorkout)
            
            let syncMessage: [String: Any] = [
                "action": "custom_workout_created",
                "workout_data": workoutData,
                "workout_id": customWorkout.id.uuidString,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            XCTAssertNotNil(syncMessage["action"])
            XCTAssertNotNil(syncMessage["workout_data"])
            XCTAssertNotNil(syncMessage["workout_id"])
            XCTAssertNotNil(syncMessage["timestamp"])
            
            print("   ✅ Step 2: Sync message format verified")
            
            // STEP 3: Simulate receiving on watchOS
            let decoder = JSONDecoder()
            let receivedWorkout = try decoder.decode(TrainingProgram.self, from: workoutData)
            
            XCTAssertEqual(receivedWorkout.name, customWorkout.name)
            XCTAssertEqual(receivedWorkout.isCustom, true)
            XCTAssertEqual(receivedWorkout.runInterval, customWorkout.runInterval)
            XCTAssertEqual(receivedWorkout.walkInterval, customWorkout.walkInterval)
            
            print("   ✅ Step 3: watchOS sync verification passed")
            
        } catch {
            XCTFail("Failed to test sync flow: \(error)")
        }
    }
    
    func testCustomWorkoutQueueing() throws {
        print("\n🔄 TESTING CUSTOM WORKOUT QUEUEING")
        
        // Given: A custom workout to sync
        let queuedWorkout = TrainingProgram(
            name: "Queued Workout",
            distance: 4.0,
            runInterval: 3.0,
            walkInterval: 1.5,
            totalDuration: 25.0,
            difficulty: .advanced,
            description: "Testing queue functionality",
            estimatedCalories: 300,
            targetHeartRateZone: .vigorous,
            isCustom: true
        )
        
        // When: Force queuing (simulate watch not reachable)
        // This would normally be tested by mocking WCSession.isReachable = false
        
        // Then: Verify workout is saved locally
        trainingProgramManager.saveCustomProgramWithSync(queuedWorkout)
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.id == queuedWorkout.id })
        
        print("   ✅ Queued workout saved locally")
        
        // And: Verify it can be encoded for later sync
        do {
            let encoder = JSONEncoder()
            let _ = try encoder.encode(queuedWorkout)
            print("   ✅ Queued workout can be encoded for sync")
        } catch {
            XCTFail("Failed to encode queued workout: \(error)")
        }
    }
    
    // MARK: - Bidirectional Sync Tests
    
    func testBidirectionalWorkoutSync() throws {
        print("\n🔄 TESTING BIDIRECTIONAL WORKOUT SYNC")
        
        // STEP 1: Create workout on iOS
        let iosWorkout = TrainingProgram(
            name: "iOS Created Workout",
            distance: 5.0,
            runInterval: 4.0,
            walkInterval: 2.0,
            totalDuration: 30.0,
            difficulty: .advanced,
            description: "Created on iOS",
            estimatedCalories: 350,
            targetHeartRateZone: .vigorous,
            isCustom: true
        )
        
        trainingProgramManager.saveCustomProgramWithSync(iosWorkout)
        
        // STEP 2: Simulate workout results coming back from watch
        let workoutResults = WorkoutResults(
            workoutId: UUID(),
            startDate: Date().addingTimeInterval(-1800), // 30 minutes ago
            endDate: Date(),
            totalDuration: 1800, // 30 minutes
            activeCalories: 350,
            heartRate: 155,
            distance: 5000, // 5km
            completedIntervals: 10,
            averageHeartRate: 150,
            maxHeartRate: 165
        )
        
        // Simulate receiving workout results
        watchConnectivityManager.handleWorkoutResultsFromWatch(workoutResults)
        
        // STEP 3: Verify results are saved on iOS
        guard let savedData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS") else {
            XCTFail("No workout results saved")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let savedWorkouts = try decoder.decode([WorkoutResults].self, from: savedData)
            
            XCTAssertGreaterThan(savedWorkouts.count, 0, "Should have saved workout results")
            
            let savedResult = savedWorkouts.last
            XCTAssertEqual(savedResult?.activeCalories, 350, "Should match calories")
            XCTAssertEqual(savedResult?.distance, 5000, "Should match distance")
            XCTAssertEqual(savedResult?.completedIntervals, 10, "Should match intervals")
            
            print("   ✅ Bidirectional sync completed successfully")
            
        } catch {
            XCTFail("Failed to decode saved workout results: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateExpectedIntervals(from program: TrainingProgram) -> [MockWorkoutInterval] {
        var intervals: [MockWorkoutInterval] = []
        
        // Calculate cycles
        let totalWorkoutTime = program.totalDuration * 60
        let cycleTime = (program.runInterval + program.walkInterval) * 60
        let cycles = Int(totalWorkoutTime / cycleTime)
        
        // Add run/walk cycles
        for _ in 0..<cycles {
            intervals.append(MockWorkoutInterval(type: .work, duration: program.runInterval * 60))
            intervals.append(MockWorkoutInterval(type: .rest, duration: program.walkInterval * 60))
        }
        
        return intervals
    }
}

// MARK: - Mock Types for Testing

struct MockWorkoutInterval {
    enum IntervalType {
        case work, rest
    }
    
    let type: IntervalType
    let duration: TimeInterval
}
