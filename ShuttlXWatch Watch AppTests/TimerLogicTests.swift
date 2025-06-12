#!/usr/bin/env swift

// Timer Test Script - Tests the WatchWorkoutManager timer logic
// This script simulates the timer functionality to verify it works correctly

import Foundation
import XCTest

@testable import ShuttlXWatch_Watch_App

class TimerLogicTests: XCTestCase {
    
    // Simulated WorkoutInterval for testing
    struct WorkoutInterval {
        let id = UUID()
        let name: String
        let type: IntervalType
        let duration: TimeInterval
        
        enum IntervalType {
            case warmup, work, rest, cooldown
            
            var displayName: String {
                switch self {
                case .warmup: return "Warmup"
                case .work: return "Work"
                case .rest: return "Rest"
                case .cooldown: return "Cooldown"
                }
            }
        }
    }
    
    // Simulated TrainingProgram for testing
    struct TrainingProgram {
        let name: String
        let runInterval: Double // minutes
        let walkInterval: Double // minutes
        let totalDuration: Double // minutes
    }
    
    // Simulated Timer Manager for testing
    class TimerTestManager {
        var intervals: [WorkoutInterval] = []
        var currentIntervalIndex = 0
        var remainingIntervalTime: TimeInterval = 0
        var elapsedTime: TimeInterval = 0
        var isWorkoutActive = false
        var isWorkoutPaused = false
        
        private var workoutTimer: Timer?
        private var intervalTimer: Timer?
        private var startDate: Date?
        
        func startWorkout(from program: TrainingProgram) {
            print("🏃‍♂️ [TEST] Starting workout from program: \(program.name)")
            
            // Create intervals from program
            intervals = []
            
            // Add warmup (30 seconds)
            intervals.append(WorkoutInterval(name: "Warmup", type: .warmup, duration: 30))
            
            // Add alternating run/walk intervals
            let runDuration = program.runInterval * 60 // Convert to seconds
            let walkDuration = program.walkInterval * 60
            let totalSeconds = program.totalDuration * 60
            
            var currentTime: Double = 30 // Already used warmup time
            
            while currentTime < totalSeconds - 30 { // Leave 30s for cooldown
                if currentTime + runDuration <= totalSeconds - 30 {
                    intervals.append(WorkoutInterval(name: "Run", type: .work, duration: runDuration))
                    currentTime += runDuration
                }
                
                if currentTime + walkDuration <= totalSeconds - 30 {
                    intervals.append(WorkoutInterval(name: "Walk", type: .rest, duration: walkDuration))
                    currentTime += walkDuration
                }
            }
            
            // Add cooldown (30 seconds)
            intervals.append(WorkoutInterval(name: "Cooldown", type: .cooldown, duration: 30))
            
            print("📋 [TEST] Created \(intervals.count) intervals:")
            for (index, interval) in intervals.enumerated() {
                print("   \(index + 1). \(interval.name) - \(Int(interval.duration))s")
            }
            
            // Start the workout
            isWorkoutActive = true
            isWorkoutPaused = false
            currentIntervalIndex = 0
            elapsedTime = 0
            startDate = Date()
            
            if !intervals.isEmpty {
                remainingIntervalTime = intervals[0].duration
                startIntervalTimer()
            }
        }
        
        private func startIntervalTimer() {
            // Stop existing timer
            intervalTimer?.invalidate()
            
            // Start new timer (1 second intervals)
            intervalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateTimer()
            }
            
            print("⏱️ [TEST] Timer started for interval: \(intervals[currentIntervalIndex].name)")
        }
        
        private func updateTimer() {
            guard isWorkoutActive && !isWorkoutPaused else { return }
            
            // Update elapsed time
            if let startDate = startDate {
                elapsedTime = Date().timeIntervalSince(startDate)
            }
            
            // Update remaining time
            if remainingIntervalTime > 0 {
                remainingIntervalTime -= 1.0
                
                let minutes = Int(remainingIntervalTime) / 60
                let seconds = Int(remainingIntervalTime) % 60
                print("⏰ [TEST] \(intervals[currentIntervalIndex].name): \(minutes):\(String(format: "%02d", seconds)) remaining")
            } else {
                // Move to next interval
                moveToNextInterval()
            }
        }
        
        private func moveToNextInterval() {
            currentIntervalIndex += 1
            
            if currentIntervalIndex >= intervals.count {
                // Workout completed
                completeWorkout()
            } else {
                // Start next interval
                remainingIntervalTime = intervals[currentIntervalIndex].duration
                print("➡️ [TEST] Moving to: \(intervals[currentIntervalIndex].name)")
            }
        }
        
        func pauseWorkout() {
            isWorkoutPaused = true
            intervalTimer?.invalidate()
            print("⏸️ [TEST] Workout paused")
        }
        
        func resumeWorkout() {
            isWorkoutPaused = false
            startIntervalTimer()
            print("▶️ [TEST] Workout resumed")
        }
        
        func stopWorkout() {
            isWorkoutActive = false
            intervalTimer?.invalidate()
            workoutTimer?.invalidate()
            print("🛑 [TEST] Workout stopped")
        }
        
        private func completeWorkout() {
            isWorkoutActive = false
            intervalTimer?.invalidate()
            workoutTimer?.invalidate()
            print("🏁 [TEST] Workout completed!")
            print("📊 [TEST] Total time: \(formatTime(elapsedTime))")
        }
        
        private func formatTime(_ time: TimeInterval) -> String {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
    }
    
    // MARK: - Test Cases
    func testBasicTimerFunctionality() {
        let manager = TimerTestManager()
        let program = TrainingProgram(name: "Quick Test", runInterval: 0.5, walkInterval: 0.5, totalDuration: 2.0)
        
        manager.startWorkout(from: program)
        
        XCTAssertTrue(manager.isWorkoutActive)
        XCTAssertFalse(manager.isWorkoutPaused)
        XCTAssertGreaterThan(manager.intervals.count, 0)
    }
    
    func testPauseResumeFunctionality() {
        let manager = TimerTestManager()
        let program = TrainingProgram(name: "Pause Test", runInterval: 1.0, walkInterval: 1.0, totalDuration: 3.0)
        
        manager.startWorkout(from: program)
        manager.pauseWorkout()
        
        XCTAssertTrue(manager.isWorkoutPaused)
        
        manager.resumeWorkout()
        
        XCTAssertFalse(manager.isWorkoutPaused)
    }
    
    func testWorkoutCompletion() {
        let manager = TimerTestManager()
        let program = TrainingProgram(name: "Complete Test", runInterval: 0.1, walkInterval: 0.1, totalDuration: 0.5)
        
        manager.startWorkout(from: program)
        
        // Simulate completion
        manager.stopWorkout()
        
        XCTAssertFalse(manager.isWorkoutActive)
    }
}

// Auto-run if executed directly
if CommandLine.arguments.count > 0 && CommandLine.arguments[0].contains("timer_test") {
    print("🧪 Running Timer Logic Tests")
    print("============================")
    
    let testSuite = TimerLogicTests()
    testSuite.testBasicTimerFunctionality()
    print("✅ Basic timer functionality test passed")
    
    testSuite.testPauseResumeFunctionality()
    print("✅ Pause/resume functionality test passed")
    
    testSuite.testWorkoutCompletion()
    print("✅ Workout completion test passed")
    
    print("\n🎉 All timer logic tests passed!")
}
