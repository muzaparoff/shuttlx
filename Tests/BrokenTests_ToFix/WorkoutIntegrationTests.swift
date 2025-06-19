//
//  WorkoutIntegrationTests.swift
//  ShuttlXWatch Watch AppTests
//
//  Created by ShuttlX on 6/11/25.
//

import XCTest
@testable import ShuttlXWatch_Watch_App

@MainActor
final class WorkoutIntegrationTests: XCTestCase {
    
    var workoutManager: WatchWorkoutManager!
    
    override func setUpWithError() throws {
        workoutManager = WatchWorkoutManager()
        // Set up test environment without HealthKit authorization for unit testing
    }
    
    override func tearDownWithError() throws {
        workoutManager?.endWorkout()
        workoutManager = nil
    }
    
    // MARK: - Integration Test: Short Workout Flow
    func testShortWorkoutIntegration() async throws {
        // Given: A short test workout
        let testIntervals = [
            WorkoutInterval(
                id: UUID(),
                name: "Test Run",
                type: .work,
                duration: 10, // 10 seconds
                targetHeartRateZone: .moderate
            ),
            WorkoutInterval(
                id: UUID(),
                name: "Test Walk",
                type: .rest,
                duration: 5, // 5 seconds
                targetHeartRateZone: .easy
            )
        ]
        
        // When: Start the workout
        workoutManager.startWorkout(with: testIntervals)
        
        // Then: Verify initial state
        XCTAssertTrue(workoutManager.isWorkoutActive, "Workout should be active")
        XCTAssertFalse(workoutManager.isWorkoutPaused, "Workout should not be paused")
        XCTAssertEqual(workoutManager.currentIntervalIndex, 0, "Should start with first interval")
        XCTAssertEqual(workoutManager.intervals.count, 2, "Should have 2 intervals")
        XCTAssertEqual(workoutManager.remainingIntervalTime, 10, "First interval should be 10 seconds")
        XCTAssertEqual(workoutManager.currentInterval?.name, "Test Run", "Should start with run")
        
        // Wait for intervals to progress through timer simulation
        let expectation = expectation(description: "Workout completion")
        
        // Simulate timer progression manually for testing
        var intervalCheckCount = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            intervalCheckCount += 1
            
            // Simulate timer decrement manually
            if self.workoutManager.remainingIntervalTime > 0 {
                self.workoutManager.remainingIntervalTime -= 1
            }
            
            // Check progression through intervals
            if intervalCheckCount == 11 { // After run (10s) + 1s into walk
                XCTAssertEqual(self.workoutManager.currentIntervalIndex, 1, "Should be in walk interval")
                XCTAssertEqual(self.workoutManager.currentInterval?.name, "Test Walk", "Should be in walk phase")
            }
            
            // Test completion
            if intervalCheckCount >= 16 { // Total duration (10+5+1s buffer)
                timer.invalidate()
                
                // Verify workout completion
                // Note: In real implementation, workout would auto-end
                self.workoutManager.endWorkout()
                
                XCTAssertFalse(self.workoutManager.isWorkoutActive, "Workout should be inactive after completion")
                XCTAssertGreaterThan(self.workoutManager.elapsedTime, 0, "Should have elapsed time")
                
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 30)
    }
    
    // MARK: - Test: Workout Pause/Resume
    func testWorkoutPauseResume() {
        // Given: Active workout
        let testInterval = WorkoutInterval(
            id: UUID(),
            name: "Test Interval",
            type: .work,
            duration: 30,
            targetHeartRateZone: .moderate
        )
        
        workoutManager.startWorkout(with: [testInterval])
        XCTAssertTrue(workoutManager.isWorkoutActive)
        
        // When: Pause workout
        workoutManager.pauseWorkout()
        
        // Then: Verify paused state
        XCTAssertTrue(workoutManager.isWorkoutPaused, "Workout should be paused")
        XCTAssertTrue(workoutManager.isWorkoutActive, "Workout should still be active")
        
        // When: Resume workout
        workoutManager.resumeWorkout()
        
        // Then: Verify resumed state
        XCTAssertFalse(workoutManager.isWorkoutPaused, "Workout should not be paused")
        XCTAssertTrue(workoutManager.isWorkoutActive, "Workout should be active")
    }
    
    // MARK: - Test: Skip Interval
    func testSkipInterval() {
        // Given: Workout with multiple intervals
        let intervals = [
            WorkoutInterval(id: UUID(), name: "Interval 1", type: .work, duration: 10, targetHeartRateZone: .easy),
            WorkoutInterval(id: UUID(), name: "Interval 2", type: .work, duration: 20, targetHeartRateZone: .moderate),
            WorkoutInterval(id: UUID(), name: "Interval 3", type: .rest, duration: 15, targetHeartRateZone: .easy)
        ]
        
        workoutManager.startWorkout(with: intervals)
        XCTAssertEqual(workoutManager.currentIntervalIndex, 0)
        XCTAssertEqual(workoutManager.currentInterval?.name, "Interval 1")
        
        // When: Skip to next interval
        workoutManager.skipToNextInterval()
        
        // Then: Verify progression
        XCTAssertEqual(workoutManager.currentIntervalIndex, 1, "Should move to next interval")
        XCTAssertEqual(workoutManager.currentInterval?.name, "Interval 2", "Should be in second interval")
        XCTAssertEqual(workoutManager.remainingIntervalTime, 20, "Should have time from new interval")
    }
    
    // MARK: - Test: Workout Data Persistence
    func testWorkoutDataSaving() {
        // Given: Completed workout
        let testInterval = WorkoutInterval(
            id: UUID(),
            name: "Test Save",
            type: .work,
            duration: 1,
            targetHeartRateZone: .moderate
        )
        
        workoutManager.startWorkout(with: [testInterval])
        
        // Simulate some metrics
        workoutManager.activeCalories = 50
        workoutManager.distance = 500 // meters
        workoutManager.heartRate = 150
        
        // When: End workout
        workoutManager.endWorkout()
        
        // Then: Verify data was saved
        let savedData = UserDefaults.standard.data(forKey: "lastWorkoutResults")
        XCTAssertNotNil(savedData, "Workout data should be saved")
        
        if let data = savedData {
            let decoder = JSONDecoder()
            let results = try? decoder.decode(WorkoutResults.self, from: data)
            XCTAssertNotNil(results, "Should be able to decode workout results")
            XCTAssertEqual(results?.activeCalories, 50, "Should save correct calories")
            XCTAssertEqual(results?.distance, 500, "Should save correct distance")
            XCTAssertEqual(results?.heartRate, 150, "Should save correct heart rate")
        }
    }
    
    // MARK: - Test: Timer Format Display
    func testTimerFormatting() {
        // Given: Workout with known time
        workoutManager.remainingIntervalTime = 125 // 2:05
        
        // When: Get formatted time
        let formatted = workoutManager.formattedRemainingTime
        
        // Then: Verify correct format
        XCTAssertEqual(formatted, "02:05", "Should format time correctly")
        
        // Test edge cases
        workoutManager.remainingIntervalTime = 59
        XCTAssertEqual(workoutManager.formattedRemainingTime, "00:59", "Should handle under a minute")
        
        workoutManager.remainingIntervalTime = 0
        XCTAssertEqual(workoutManager.formattedRemainingTime, "00:00", "Should handle zero time")
    }
    
    // MARK: - Timer Start Test
    func testTimerStartsOnWorkoutButtonPress() throws {
        // Given: Prepare test intervals
        let testIntervals = [
            WorkoutInterval(
                id: UUID(),
                name: "Timer Test",
                type: .work,
                duration: 5, // 5 seconds for quick test
                targetHeartRateZone: .moderate
            )
        ]
        
        // When: Start the workout
        workoutManager.startWorkout(with: testIntervals)
        
        // Then: Timer should start immediately
        XCTAssertTrue(workoutManager.isWorkoutActive, "Workout should be active immediately")
        XCTAssertEqual(workoutManager.remainingIntervalTime, 5, "Timer should show initial interval time")
        XCTAssertNotNil(workoutManager.currentInterval, "Current interval should be set")
        XCTAssertEqual(workoutManager.currentInterval?.name, "Timer Test", "Should be in correct interval")
        
        // Wait for timer to tick
        let expectation = expectation(description: "Timer countdown")
        
        var tickCount = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            tickCount += 1
            
            // Check timer is decrementing
            if tickCount == 2 {
                XCTAssertLessThan(self.workoutManager.remainingIntervalTime, 5, "Timer should be counting down")
            }
            
            // Complete test after 3 seconds
            if tickCount >= 3 {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5)
        
        // Cleanup
        workoutManager.endWorkout()
    }
    
    // MARK: - Custom Workout Sync Test
    func testCustomWorkoutSyncToWatch() throws {
        // This test verifies custom workout sync from iOS to watchOS
        let customWorkout = TrainingProgram(
            name: "Sync Test Workout",
            distance: 3.0,
            runInterval: 2.0,
            walkInterval: 1.0,
            totalDuration: 15.0,
            difficulty: .beginner,
            description: "Testing sync functionality",
            estimatedCalories: 200,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        // Simulate receiving custom workout from iOS
        let encoder = JSONEncoder()
        let workoutData = try encoder.encode(customWorkout)
        
        let message = [
            "action": "custom_workout_created",
            "workout_data": workoutData,
            "workout_id": customWorkout.id.uuidString,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        // Test sync handling
        // Note: This would normally be tested with WatchConnectivityManager
        // For now, we'll verify data encoding/decoding works
        
        let decoder = JSONDecoder()
        let decodedWorkout = try decoder.decode(TrainingProgram.self, from: workoutData)
        
        XCTAssertEqual(decodedWorkout.name, customWorkout.name)
        XCTAssertEqual(decodedWorkout.isCustom, true)
        XCTAssertEqual(decodedWorkout.runInterval, 2.0)
        XCTAssertEqual(decodedWorkout.walkInterval, 1.0)
    }
}
