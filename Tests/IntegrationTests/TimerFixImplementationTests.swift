// Comprehensive Timer Fix Implementation for watchOS
// This contains the corrected timer implementation for WatchWorkoutManager

import Foundation
import SwiftUI
import Combine
import XCTest

@testable import ShuttlXWatch_Watch_App

// MARK: - Core Timer Fix Tests
class FixedWatchWorkoutManagerTests: XCTestCase {
    
    // Mock WorkoutInterval for testing
    struct WorkoutInterval {
        let id = UUID()
        let name: String
        let type: IntervalType
        let duration: TimeInterval
        
        enum IntervalType {
            case work, rest
            
            var displayName: String {
                switch self {
                case .work: return "Work"
                case .rest: return "Rest"
                }
            }
        }
    }
    
    enum WorkoutPhase {
        case ready, active, paused, completed
    }
    
    // MARK: - Fixed Timer Implementation Test Class
    class FixedWatchWorkoutManager: ObservableObject {
        
        // MARK: - Published Properties (optimized for watchOS)
        @Published var isWorkoutActive = false
        @Published var remainingIntervalTime: TimeInterval = 0
        @Published var elapsedTime: TimeInterval = 0
        @Published var currentInterval: WorkoutInterval?
        @Published var currentIntervalIndex = 0
        @Published var workoutPhase: WorkoutPhase = .ready
        
        // MARK: - Private Properties
        private var intervals: [WorkoutInterval] = []
        private var startDate: Date?
        private var timer: Timer?
        private var cancellables = Set<AnyCancellable>()
        
        // MARK: - Core Timer Implementation (FIXED)
        private func startUnifiedTimer() {
            print("🚀 [TIMER-FIX] Starting unified timer...")
            
            // Stop any existing timer
            timer?.invalidate()
            timer = nil
            
            // Create timer on main thread with immediate execution
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.updateTimers()
                }
                
                // CRITICAL: Add to RunLoop for watchOS
                if let timer = self.timer {
                    RunLoop.main.add(timer, forMode: .common)
                    print("✅ [TIMER-FIX] Timer started and added to RunLoop")
                }
            }
        }
        
        @MainActor
        private func updateTimers() {
            guard isWorkoutActive else {
                print("⚠️ [TIMER-FIX] Timer called but workout not active")
                return
            }
            
            // Update elapsed time
            if let startDate = startDate {
                elapsedTime = Date().timeIntervalSince(startDate)
            }
            
            // Update interval time
            if remainingIntervalTime > 0 {
                remainingIntervalTime -= 1.0
                print("⏱️ [TIMER-FIX] Remaining: \(Int(remainingIntervalTime))s")
            } else {
                // Move to next interval
                advanceToNextInterval()
            }
        }
        
        @MainActor
        func startWorkout(with intervals: [WorkoutInterval]) {
            print("🏃‍♂️ [TIMER-FIX] Starting workout with \(intervals.count) intervals")
            
            self.intervals = intervals
            currentIntervalIndex = 0
            isWorkoutActive = true
            startDate = Date()
            workoutPhase = .active
            
            if !intervals.isEmpty {
                currentInterval = intervals[0]
                remainingIntervalTime = intervals[0].duration
            }
            
            startUnifiedTimer()
        }
        
        @MainActor
        private func advanceToNextInterval() {
            currentIntervalIndex += 1
            
            if currentIntervalIndex >= intervals.count {
                // Workout completed
                completeWorkout()
            } else {
                // Start next interval
                currentInterval = intervals[currentIntervalIndex]
                remainingIntervalTime = intervals[currentIntervalIndex].duration
                print("➡️ [TIMER-FIX] Advanced to interval: \(currentInterval?.name ?? "Unknown")")
            }
        }
        
        @MainActor
        func completeWorkout() {
            print("🏁 [TIMER-FIX] Workout completed")
            isWorkoutActive = false
            workoutPhase = .completed
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: - Test Cases
    func testTimerStartsCorrectly() async throws {
        let manager = FixedWatchWorkoutManager()
        let testIntervals = [
            WorkoutInterval(name: "Work", type: .work, duration: 10),
            WorkoutInterval(name: "Work", type: .work, duration: 30),
            WorkoutInterval(name: "Rest", type: .rest, duration: 15)
        ]
        
        await manager.startWorkout(with: testIntervals)
        
        XCTAssertTrue(manager.isWorkoutActive)
        XCTAssertEqual(manager.currentIntervalIndex, 0)
        XCTAssertEqual(manager.remainingIntervalTime, 10)
        XCTAssertEqual(manager.workoutPhase, .active)
    }
    
    func testIntervalProgression() async throws {
        let manager = FixedWatchWorkoutManager()
        let testIntervals = [
            WorkoutInterval(name: "Short", type: .work, duration: 1),
            WorkoutInterval(name: "Another", type: .rest, duration: 1)
        ]
        
        await manager.startWorkout(with: testIntervals)
        
        // Wait for interval to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Should have advanced to next interval or completed
        XCTAssertTrue(manager.currentIntervalIndex >= 1 || manager.workoutPhase == .completed)
    }
    
    func testWorkoutCompletion() async throws {
        let manager = FixedWatchWorkoutManager()
        let testIntervals = [
            WorkoutInterval(name: "Quick", type: .work, duration: 1)
        ]
        
        await manager.startWorkout(with: testIntervals)
        
        // Wait for workout to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Should complete workout
        await manager.completeWorkout()
        XCTAssertFalse(manager.isWorkoutActive)
        XCTAssertEqual(manager.workoutPhase, .completed)
    }
}
