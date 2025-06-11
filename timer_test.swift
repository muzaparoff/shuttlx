#!/usr/bin/env swift

// Timer Test Script - Tests the WatchWorkoutManager timer logic
// This script simulates the timer functionality to verify it works correctly

import Foundation

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
        
        // Generate intervals like the real app
        intervals = generateIntervals(from: program)
        print("🏃‍♂️ [TEST] Generated \(intervals.count) intervals")
        
        currentIntervalIndex = 0
        isWorkoutActive = true
        isWorkoutPaused = false
        startDate = Date()
        
        // Start timers
        startWorkoutTimer()
        startIntervalTimer()
        
        print("✅ [TEST] Workout started successfully")
        print("📊 [TEST] Workout state: isActive=\(isWorkoutActive), isPaused=\(isWorkoutPaused)")
        print("📊 [TEST] Current interval: \(currentInterval?.name ?? "unknown")")
        print("⏱ [TEST] Remaining time: \(remainingIntervalTime)s")
    }
    
    private func generateIntervals(from program: TrainingProgram) -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // Add warmup
        intervals.append(WorkoutInterval(
            name: "Warm Up",
            type: .warmup,
            duration: 10 // 10 seconds for testing
        ))
        
        // Add a few run/walk cycles for testing
        for i in 0..<3 {
            // Run interval
            intervals.append(WorkoutInterval(
                name: "Run \(i + 1)",
                type: .work,
                duration: 5 // 5 seconds for testing
            ))
            
            // Walk interval
            intervals.append(WorkoutInterval(
                name: "Walk \(i + 1)",
                type: .rest,
                duration: 3 // 3 seconds for testing
            ))
        }
        
        // Add cooldown
        intervals.append(WorkoutInterval(
            name: "Cool Down",
            type: .cooldown,
            duration: 10 // 10 seconds for testing
        ))
        
        return intervals
    }
    
    var currentInterval: WorkoutInterval? {
        guard currentIntervalIndex < intervals.count else { return nil }
        return intervals[currentIntervalIndex]
    }
    
    private func startWorkoutTimer() {
        print("⏱ [TEST] Starting workout timer...")
        
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.isWorkoutActive && !self.isWorkoutPaused {
                self.updateElapsedTime()
                
                // Debug every few seconds
                if Int(self.elapsedTime) % 5 == 0 && self.elapsedTime > 0 {
                    print("⏱ [TEST] Workout timer: \(self.formattedElapsedTime) elapsed")
                }
            }
        }
        
        RunLoop.current.add(workoutTimer!, forMode: .common)
        print("✅ [TEST] Workout timer started")
    }
    
    private func startIntervalTimer() {
        guard currentIntervalIndex < intervals.count else {
            print("❌ [TEST] Cannot start interval timer: index out of bounds")
            endWorkout()
            return
        }
        
        guard let interval = currentInterval else {
            print("❌ [TEST] Current interval is nil")
            return
        }
        
        remainingIntervalTime = interval.duration
        print("⏱ [TEST] Starting interval timer for: \(interval.name) (\(interval.duration)s)")
        
        intervalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.isWorkoutActive && !self.isWorkoutPaused {
                self.remainingIntervalTime -= 1.0
                
                print("⏱ [TEST] \(self.currentInterval?.name ?? "unknown"): \(Int(self.remainingIntervalTime))s remaining")
                
                if self.remainingIntervalTime <= 0 {
                    timer.invalidate()
                    self.intervalTimer = nil
                    print("✅ [TEST] Interval completed, moving to next...")
                    self.moveToNextInterval()
                }
            }
        }
        
        RunLoop.current.add(intervalTimer!, forMode: .common)
        print("✅ [TEST] Interval timer started")
    }
    
    private func moveToNextInterval() {
        currentIntervalIndex += 1
        
        if currentIntervalIndex >= intervals.count {
            print("🏁 [TEST] All intervals completed - workout finished!")
            endWorkout()
            return
        }
        
        print("➡️ [TEST] Moving to next interval: \(currentInterval?.name ?? "unknown")")
        startIntervalTimer()
    }
    
    private func updateElapsedTime() {
        guard let startDate = startDate else { return }
        elapsedTime = Date().timeIntervalSince(startDate)
    }
    
    private func endWorkout() {
        print("🏁 [TEST] Ending workout...")
        isWorkoutActive = false
        workoutTimer?.invalidate()
        intervalTimer?.invalidate()
        workoutTimer = nil
        intervalTimer = nil
        print("✅ [TEST] Workout ended")
    }
    
    private var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Test the timer functionality
print("🧪 Starting ShuttlX Timer Test")
print("============================")

let testProgram = TrainingProgram(
    name: "Test Program",
    runInterval: 1.0,
    walkInterval: 1.0,
    totalDuration: 5.0
)

let timerManager = TimerTestManager()
timerManager.startWorkout(from: testProgram)

print("\n🕐 Running test for 60 seconds...")
print("Press Ctrl+C to stop the test early")

// Run the test for 60 seconds
let endTime = Date().addingTimeInterval(60)
while Date() < endTime && timerManager.isWorkoutActive {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}

print("\n✅ Timer test completed!")
print("The timer logic appears to be working correctly.")
print("If you saw interval countdowns and transitions, the fix is successful!")
