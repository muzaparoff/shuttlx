//
//  TimerTests.swift
//  ShuttlXTests
//
//  Timer functionality tests for watchOS
//  Created on June 14, 2025
//

import XCTest
import Combine
@testable import ShuttlX

class TimerTests: XCTestCase {
    var workoutManager: WatchWorkoutManager!
    var cancellables: Set<AnyCancellable> = []
    
    override func setUp() {
        super.setUp()
        workoutManager = WatchWorkoutManager()
    }
    
    override func tearDown() {
        workoutManager?.endWorkout()
        cancellables.removeAll()
        super.tearDown()
    }
    
    func testTimerCountdown() {
        // Create a simple test program
        let testProgram = TrainingProgram(
            name: "Timer Test",
            distance: 1.0,
            runInterval: 0.1, // 6 seconds (0.1 * 60)
            walkInterval: 0.05, // 3 seconds
            difficulty: .beginner
        )
        
        let expectation = XCTestExpectation(description: "Timer should count down")
        var timerUpdates: [TimeInterval] = []
        
        // Monitor timer updates
        workoutManager.$remainingIntervalTime
            .sink { remainingTime in
                timerUpdates.append(remainingTime)
                print("Timer update: \(remainingTime)")
                
                // If we've seen the timer counting down, test passes
                if timerUpdates.count >= 3 && remainingTime < timerUpdates.first! {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start the workout
        workoutManager.startWorkout(from: testProgram)
        
        // Wait for timer to count down
        wait(for: [expectation], timeout: 10.0)
        
        // Verify timer actually counted down
        XCTAssertTrue(timerUpdates.count >= 2, "Timer should have produced multiple updates")
        if timerUpdates.count >= 2 {
            XCTAssertGreaterThan(timerUpdates.first!, timerUpdates.last!, "Timer should count down")
        }
    }
    
    func testWorkoutStateTransitions() {
        let testProgram = TrainingProgram(
            name: "State Test",
            distance: 1.0,
            runInterval: 0.05, // 3 seconds
            walkInterval: 0.05, // 3 seconds
            difficulty: .beginner
        )
        
        // Initial state
        XCTAssertFalse(workoutManager.isWorkoutActive)
        XCTAssertEqual(workoutManager.remainingIntervalTime, 0)
        
        // Start workout
        workoutManager.startWorkout(from: testProgram)
        
        // Give it a moment to initialize
        let expectation = XCTestExpectation(description: "Workout should start")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertTrue(self.workoutManager.isWorkoutActive)
            XCTAssertGreaterThan(self.workoutManager.remainingIntervalTime, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}
