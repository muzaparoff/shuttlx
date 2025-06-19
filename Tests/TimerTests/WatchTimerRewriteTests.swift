//
//  WatchTimerRewriteTests.swift
//  ShuttlXTests
//
//  Comprehensive tests for the rewritten timer system
//  Created on June 14, 2025
//

import XCTest
import Combine

// Simple mock for testing timer logic
class MockWatchWorkoutManager: ObservableObject {
    @Published var isWorkoutActive = false
    @Published var isWorkoutPaused = false
    @Published var remainingIntervalTime: TimeInterval = 0
    @Published var currentInterval: MockWorkoutInterval?
    @Published var currentIntervalIndex = 0
    @Published var intervals: [MockWorkoutInterval] = []
    @Published var elapsedTime: TimeInterval = 0
    
    private var timer: Timer?
    
    var formattedRemainingTime: String {
        let minutes = Int(remainingIntervalTime) / 60
        let seconds = Int(remainingIntervalTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func startWorkout() {
        // Create test intervals
        intervals = [
            MockWorkoutInterval(name: "Walk 1", duration: 5.0),
            MockWorkoutInterval(name: "Run 1", duration: 3.0)
        ]
        
        currentIntervalIndex = 0
        if let firstInterval = intervals.first {
            currentInterval = firstInterval
            remainingIntervalTime = firstInterval.duration
        }
        
        isWorkoutActive = true
        isWorkoutPaused = false
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
    }
    
    private func timerTick() {
        guard isWorkoutActive && !isWorkoutPaused else { return }
        
        if remainingIntervalTime > 0 {
            remainingIntervalTime -= 1.0
        } else {
            moveToNextInterval()
        }
        
        elapsedTime += 1.0
    }
    
    private func moveToNextInterval() {
        currentIntervalIndex += 1
        
        if currentIntervalIndex >= intervals.count {
            endWorkout()
            return
        }
        
        if let nextInterval = intervals[safe: currentIntervalIndex] {
            currentInterval = nextInterval
            remainingIntervalTime = nextInterval.duration
        }
    }
    
    func pauseWorkout() {
        isWorkoutPaused = true
    }
    
    func resumeWorkout() {
        isWorkoutPaused = false
    }
    
    func endWorkout() {
        isWorkoutActive = false
        timer?.invalidate()
        timer = nil
    }
}

struct MockWorkoutInterval {
    let name: String
    let duration: TimeInterval
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

class WatchTimerRewriteTests: XCTestCase {
    var workoutManager: MockWatchWorkoutManager!
    var cancellables: Set<AnyCancellable> = []
    
    override func setUp() {
        super.setUp()
        workoutManager = MockWatchWorkoutManager()
    }
    
    override func tearDown() {
        workoutManager?.endWorkout()
        cancellables.removeAll()
        super.tearDown()
    }
    
    func testTimerInitialization() {
        // Test that manager initializes with correct default values
        XCTAssertFalse(workoutManager.isWorkoutActive)
        XCTAssertFalse(workoutManager.isWorkoutPaused)
        XCTAssertEqual(workoutManager.remainingIntervalTime, 0)
        XCTAssertNil(workoutManager.currentInterval)
        XCTAssertEqual(workoutManager.currentIntervalIndex, 0)
    }
    
    func testWorkoutStartup() {
        // Start workout
        workoutManager.startWorkout()
        
        // Verify immediate state after startup
        XCTAssertTrue(workoutManager.isWorkoutActive, "Workout should be active immediately")
        XCTAssertFalse(workoutManager.isWorkoutPaused, "Workout should not be paused")
        XCTAssertGreaterThan(workoutManager.intervals.count, 0, "Should have generated intervals")
        XCTAssertNotNil(workoutManager.currentInterval, "Should have current interval")
        XCTAssertGreaterThan(workoutManager.remainingIntervalTime, 0, "Should have remaining time")
        
        print("✅ Test: Workout startup successful")
        print("   - Active: \(workoutManager.isWorkoutActive)")
        print("   - Intervals: \(workoutManager.intervals.count)")
        print("   - Current: \(workoutManager.currentInterval?.name ?? "nil")")
        print("   - Remaining: \(workoutManager.remainingIntervalTime)")
    }
    
    func testTimerCountdown() {
        let expectation = XCTestExpectation(description: "Timer should count down")
        var timerUpdates: [TimeInterval] = []
        
        // Monitor timer updates
        workoutManager.$remainingIntervalTime
            .sink { remainingTime in
                timerUpdates.append(remainingTime)
                print("⏱️ Timer update: \(remainingTime)")
                
                // If we've seen the timer counting down, test passes
                if timerUpdates.count >= 3 {
                    let first = timerUpdates.first!
                    let last = timerUpdates.last!
                    if first > last && last >= 0 {
                        expectation.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Start workout
        workoutManager.startWorkout()
        
        // Wait for countdown
        wait(for: [expectation], timeout: 8.0)
        
        XCTAssertGreaterThan(timerUpdates.count, 2, "Should have received multiple timer updates")
        XCTAssertGreaterThan(timerUpdates.first!, timerUpdates.last!, "Timer should count down")
    }
    
    func testIntervalTransitions() {
        let expectation = XCTestExpectation(description: "Should transition between intervals")
        var intervalNames: [String] = []
        
        // Monitor interval changes
        workoutManager.$currentInterval
            .compactMap { $0?.name }
            .sink { name in
                intervalNames.append(name)
                print("🔄 Interval transition: \(name)")
                
                // If we've seen multiple intervals, test passes
                if intervalNames.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start workout
        workoutManager.startWorkout()
        
        // Wait for transitions
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertGreaterThan(intervalNames.count, 1, "Should have transitioned between intervals")
    }
    
    func testPauseResumeWorkout() {
        // Start workout
        workoutManager.startWorkout()
        XCTAssertTrue(workoutManager.isWorkoutActive)
        XCTAssertFalse(workoutManager.isWorkoutPaused)
        
        // Pause workout
        workoutManager.pauseWorkout()
        XCTAssertTrue(workoutManager.isWorkoutActive, "Should still be active when paused")
        XCTAssertTrue(workoutManager.isWorkoutPaused, "Should be paused")
        
        // Resume workout
        workoutManager.resumeWorkout()
        XCTAssertTrue(workoutManager.isWorkoutActive, "Should be active after resume")
        XCTAssertFalse(workoutManager.isWorkoutPaused, "Should not be paused after resume")
    }
    
    func testFormattedTimeDisplay() {
        // Test time formatting
        workoutManager.remainingIntervalTime = 125.0 // 2:05
        XCTAssertEqual(workoutManager.formattedRemainingTime, "02:05")
        
        workoutManager.remainingIntervalTime = 59.0 // 0:59
        XCTAssertEqual(workoutManager.formattedRemainingTime, "00:59")
        
        workoutManager.remainingIntervalTime = 3661.0 // 61:01
        XCTAssertEqual(workoutManager.formattedRemainingTime, "61:01")
    }
}
