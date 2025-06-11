// COMPREHENSIVE TIMER FIX FOR WATCHOS
// This file contains the corrected timer implementation that addresses all identified issues

import Foundation
import SwiftUI
import Combine

// MARK: - Core Timer Fix
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
            print("⚠️ [TIMER-FIX] Timer running but workout not active")
            stopTimer()
            return
        }
        
        // Update elapsed time
        if let startDate = startDate {
            elapsedTime = Date().timeIntervalSince(startDate)
        }
        
        // Update interval time
        if remainingIntervalTime > 0 {
            remainingIntervalTime = max(0, remainingIntervalTime - 1.0)
            
            // Debug output every 5 seconds
            let remaining = Int(remainingIntervalTime)
            if remaining % 5 == 0 || remaining <= 5 {
                print("⏱️ [TIMER-FIX] \(remaining)s remaining")
                
                // FORCE UI UPDATE
                objectWillChange.send()
            }
            
            // Check if interval complete
            if remainingIntervalTime <= 0 {
                moveToNextInterval()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        print("🛑 [TIMER-FIX] Timer stopped")
    }
    
    @MainActor
    private func moveToNextInterval() {
        currentIntervalIndex += 1
        
        if currentIntervalIndex >= intervals.count {
            print("🏁 [TIMER-FIX] All intervals completed!")
            endWorkout()
            return
        }
        
        // Setup next interval
        if let nextInterval = intervals[currentIntervalIndex] {
            currentInterval = nextInterval
            remainingIntervalTime = nextInterval.duration
            
            print("📋 [TIMER-FIX] Next interval: \(nextInterval.name) for \(nextInterval.duration)s")
            
            // Update phase
            switch nextInterval.type {
            case .warmup: workoutPhase = .warming
            case .work: workoutPhase = .working
            case .rest: workoutPhase = .resting
            case .cooldown: workoutPhase = .cooling
            }
            
            // Force UI update
            objectWillChange.send()
        }
    }
    
    // MARK: - Public Methods
    func startWorkout(with intervals: [WorkoutInterval]) {
        print("🏃‍♂️ [TIMER-FIX] Starting workout with \(intervals.count) intervals")
        
        self.intervals = intervals
        self.currentIntervalIndex = 0
        self.startDate = Date()
        self.isWorkoutActive = true
        self.elapsedTime = 0
        
        // Setup first interval
        if let firstInterval = intervals.first {
            self.currentInterval = firstInterval
            self.remainingIntervalTime = firstInterval.duration
            self.workoutPhase = .warming
            
            print("🚀 [TIMER-FIX] First interval: \(firstInterval.name) for \(firstInterval.duration)s")
        }
        
        // Start the unified timer
        startUnifiedTimer()
        
        // Force immediate UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func endWorkout() {
        print("🛑 [TIMER-FIX] Ending workout")
        
        stopTimer()
        isWorkoutActive = false
        workoutPhase = .completed
        currentInterval = nil
        currentIntervalIndex = 0
        remainingIntervalTime = 0
        elapsedTime = 0
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Computed Properties
    var formattedRemainingTime: String {
        let minutes = Int(remainingIntervalTime) / 60
        let seconds = Int(remainingIntervalTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - UI Component for Testing
struct FixedTimerDisplay: View {
    @ObservedObject var manager: FixedWatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 8) {
            // Main Timer Display
            VStack {
                Text(manager.formattedRemainingTime)
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                
                Text("remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Status Info
            VStack(spacing: 4) {
                Text("Interval: \(manager.currentInterval?.name ?? "None")")
                    .font(.caption2)
                
                Text("Phase: \(manager.workoutPhase.rawValue)")
                    .font(.caption2)
                
                Text("Elapsed: \(manager.formattedElapsedTime)")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            
            // Control Buttons
            HStack {
                if manager.isWorkoutActive {
                    Button("End Workout") {
                        manager.endWorkout()
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Start Test") {
                        startTestWorkout()
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .padding()
    }
    
    private func startTestWorkout() {
        let testIntervals = [
            WorkoutInterval(
                id: UUID(),
                name: "Warm Up",
                type: .warmup,
                duration: 10, // 10 seconds for testing
                targetHeartRateZone: .easy
            ),
            WorkoutInterval(
                id: UUID(),
                name: "Run 1",
                type: .work,
                duration: 15, // 15 seconds for testing
                targetHeartRateZone: .moderate
            ),
            WorkoutInterval(
                id: UUID(),
                name: "Walk 1",
                type: .rest,
                duration: 10, // 10 seconds for testing
                targetHeartRateZone: .easy
            )
        ]
        
        manager.startWorkout(with: testIntervals)
    }
}

// MARK: - Test Implementation Notes
/*
KEY FIXES IMPLEMENTED:

1. **Unified Timer**: Single timer instead of separate workout/interval timers
2. **Proper MainActor**: All UI updates wrapped in @MainActor
3. **RunLoop Integration**: Timer explicitly added to .common mode
4. **Forced UI Updates**: Explicit objectWillChange.send() calls
5. **Simplified State**: Reduced complexity in timer management
6. **Immediate Feedback**: Timer starts immediately with proper initialization

TESTING INSTRUCTIONS:
1. Replace the timer logic in WatchWorkoutManager with this implementation
2. Test with short intervals (10-15 seconds) to verify timer countdown
3. Monitor console output for debug messages
4. Verify UI updates every second

EXPECTED BEHAVIOR:
- Timer should immediately show countdown from initial interval duration
- UI should update every second showing decreasing time
- Console should show debug messages every 5 seconds
- Intervals should automatically advance when time reaches 0
*/
