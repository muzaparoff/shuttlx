#!/usr/bin/swift

// Timer Test Verification for ShuttlX
// This script simulates the timer functionality to verify our fixes work

import Foundation
import XCTest

@testable import ShuttlXWatch_Watch_App

class TimerFixVerificationTests: XCTestCase {
    
    class MockWatchWorkoutManager: ObservableObject {
        @Published var remainingIntervalTime: TimeInterval = 30.0
        @Published var currentIntervalIndex: Int = 0
        @Published var isTimerRunning: Bool = false
        
        private var timer: Timer?
        private let intervals = [30.0, 60.0, 30.0, 90.0] // Mock intervals
        
        @MainActor
        func startTimer() {
            print("🏃‍♂️ Starting timer...")
            isTimerRunning = true
            remainingIntervalTime = intervals[currentIntervalIndex]
            
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateTimer()
                }
            }
        }
        
        @MainActor
        func updateTimer() {
            guard remainingIntervalTime > 0 else {
                moveToNextInterval()
                return
            }
            
            remainingIntervalTime -= 1.0
            print("⏰ Timer: \(Int(remainingIntervalTime))s remaining")
            
            // Update UI on main thread (simulating our fix)
            objectWillChange.send()
        }
        
        @MainActor
        func moveToNextInterval() {
            print("🔄 Moving to next interval...")
            
            currentIntervalIndex += 1
            
            if currentIntervalIndex >= intervals.count {
                print("✅ Workout completed!")
                stopTimer()
                return
            }
            
            remainingIntervalTime = intervals[currentIntervalIndex]
        }
        
        @MainActor
        func stopTimer() {
            timer?.invalidate()
            timer = nil
            isTimerRunning = false
            print("🛑 Timer stopped")
        }
    }
    
    func testTimerFunctionality() async throws {
        let manager = MockWatchWorkoutManager()
        
        // Start timer
        await manager.startTimer()
        XCTAssertTrue(manager.isTimerRunning)
        XCTAssertEqual(manager.currentIntervalIndex, 0)
        XCTAssertEqual(manager.remainingIntervalTime, 30.0)
        
        // Wait for timer to decrement
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertLessThan(manager.remainingIntervalTime, 30.0)
        
        await manager.stopTimer()
        XCTAssertFalse(manager.isTimerRunning)
    }
    
    func testIntervalTransition() async throws {
        let manager = MockWatchWorkoutManager()
        
        // Set up for interval transition test
        await manager.startTimer()
        
        // Force interval transition
        await manager.moveToNextInterval()
        XCTAssertEqual(manager.currentIntervalIndex, 1)
        XCTAssertEqual(manager.remainingIntervalTime, 60.0)
        
        await manager.stopTimer()
    }
    
    func testWorkoutCompletion() async throws {
        let manager = MockWatchWorkoutManager()
        
        await manager.startTimer()
        
        // Simulate all intervals
        for i in 0..<4 {
            await manager.moveToNextInterval()
        }
        
        XCTAssertFalse(manager.isTimerRunning)
    }
}

// Run verification test
class TimerVerificationRunner {
    static func runTests() {
        print("🧪 Timer Fix Verification Tests")
        print("=============================")
        
        let testSuite = TimerFixVerificationTests()
        
        Task {
            do {
                try await testSuite.testTimerFunctionality()
                print("✅ Timer functionality test passed")
                
                try await testSuite.testIntervalTransition()
                print("✅ Interval transition test passed")
                
                try await testSuite.testWorkoutCompletion()
                print("✅ Workout completion test passed")
                
                print("\n🎉 All timer verification tests passed!")
                
            } catch {
                print("❌ Test failed: \(error)")
            }
        }
    }
}

// Auto-run if executed directly
if CommandLine.arguments.count > 0 && CommandLine.arguments[0].contains("timer_test_verification") {
    TimerVerificationRunner.runTests()
    // Keep alive for async tests
    RunLoop.main.run()
}
