//
//  DistanceBasedTrainingTests.swift
//  ShuttlXTests
//
//  Created by ShuttlX on 6/15/25.
//

import XCTest
@testable import ShuttlX

final class DistanceBasedTrainingTests: XCTestCase {
    
    var mockWorkoutManager: MockWatchWorkoutManager!
    
    override func setUpWithError() throws {
        mockWorkoutManager = MockWatchWorkoutManager()
    }
    
    override func tearDownWithError() throws {
        mockWorkoutManager = nil
    }
    
    // MARK: - Distance-Based Training Tests
    
    func testDistanceBasedIntervalGeneration() throws {
        // Given
        let program = TrainingProgram(
            name: "5K Test",
            distance: 5.0, // 5 kilometers
            runInterval: 1.0, // 1 minute run
            walkInterval: 2.0, // 2 minutes walk
            difficulty: .beginner
        )
        
        // When
        let intervals = mockWorkoutManager.generateTestIntervals(from: program)
        
        // Then
        XCTAssertFalse(intervals.isEmpty, "Should generate intervals")
        XCTAssertTrue(intervals.count >= 10, "Should generate enough intervals for 5K")
        
        // Check interval pattern (walk first, then run)
        XCTAssertEqual(intervals[0].type, .rest, "First interval should be walk/rest")
        XCTAssertEqual(intervals[1].type, .work, "Second interval should be run/work")
        
        // Check durations
        XCTAssertEqual(intervals[0].duration, 120, "Walk interval should be 2 minutes (120s)")
        XCTAssertEqual(intervals[1].duration, 60, "Run interval should be 1 minute (60s)")
    }
    
    func testDistanceGoalTracking() throws {
        // Given
        let program = TrainingProgram(name: "Test", distance: 2.0, runInterval: 1.0, walkInterval: 1.0, difficulty: .beginner)
        
        // When
        mockWorkoutManager.startMockWorkout(from: program)
        
        // Then
        XCTAssertEqual(mockWorkoutManager.targetDistance, 2.0, "Target distance should be set")
        XCTAssertEqual(mockWorkoutManager.distanceProgress, 0.0, "Progress should start at 0")
        XCTAssertFalse(mockWorkoutManager.isDistanceGoalReached, "Goal should not be reached initially")
    }
    
    func testDistanceProgressCalculation() throws {
        // Given
        let program = TrainingProgram(name: "Test", distance: 5.0, runInterval: 1.0, walkInterval: 1.0, difficulty: .beginner)
        mockWorkoutManager.startMockWorkout(from: program)
        
        // When - simulate 2.5km progress
        mockWorkoutManager.updateMockDistance(2500) // 2.5km in meters
        
        // Then
        XCTAssertEqual(mockWorkoutManager.distanceProgress, 0.5, accuracy: 0.01, "Progress should be 50%")
        XCTAssertFalse(mockWorkoutManager.isDistanceGoalReached, "Goal should not be reached yet")
        
        // When - reach goal
        mockWorkoutManager.updateMockDistance(5000) // 5km in meters
        
        // Then
        XCTAssertEqual(mockWorkoutManager.distanceProgress, 1.0, accuracy: 0.01, "Progress should be 100%")
        XCTAssertTrue(mockWorkoutManager.isDistanceGoalReached, "Goal should be reached")
    }
    
    func testTimerInitialization() throws {
        // Given
        let program = TrainingProgram(name: "Test", distance: 1.0, runInterval: 3.0, walkInterval: 2.0, difficulty: .beginner)
        
        // When
        mockWorkoutManager.startMockWorkout(from: program)
        
        // Then
        XCTAssertTrue(mockWorkoutManager.isWorkoutActive, "Workout should be active")
        XCTAssertFalse(mockWorkoutManager.isWorkoutPaused, "Workout should not be paused")
        XCTAssertNotNil(mockWorkoutManager.currentInterval, "Current interval should be set")
        XCTAssertEqual(mockWorkoutManager.remainingIntervalTime, 120, "Timer should be set to walk duration (2min = 120s)")
        XCTAssertEqual(mockWorkoutManager.currentInterval?.type, .rest, "First interval should be walk/rest")
    }
    
    func testIntervalProgression() throws {
        // Given
        let program = TrainingProgram(name: "Test", distance: 1.0, runInterval: 1.0, walkInterval: 1.0, difficulty: .beginner)
        mockWorkoutManager.startMockWorkout(from: program)
        
        // When - complete first interval (walk)
        XCTAssertEqual(mockWorkoutManager.currentInterval?.type, .rest, "Should start with walk")
        mockWorkoutManager.simulateIntervalCompletion()
        
        // Then - should move to run
        XCTAssertEqual(mockWorkoutManager.currentInterval?.type, .work, "Should move to run interval")
        XCTAssertEqual(mockWorkoutManager.remainingIntervalTime, 60, "Run interval should be 1 minute")
        
        // When - complete run interval
        mockWorkoutManager.simulateIntervalCompletion()
        
        // Then - should move to next walk
        XCTAssertEqual(mockWorkoutManager.currentInterval?.type, .rest, "Should move to next walk interval")
    }
    
    func testWorkoutCompletionOnDistanceGoal() throws {
        // Given
        let program = TrainingProgram(name: "Test", distance: 1.0, runInterval: 1.0, walkInterval: 1.0, difficulty: .beginner)
        mockWorkoutManager.startMockWorkout(from: program)
        
        // When - reach distance goal
        mockWorkoutManager.updateMockDistance(1000) // 1km
        mockWorkoutManager.simulateTimerTick() // This should trigger goal check
        
        // Then
        XCTAssertTrue(mockWorkoutManager.isDistanceGoalReached, "Distance goal should be reached")
    }
    
    func testFormattedDistanceProgress() throws {
        // Given
        let program = TrainingProgram(name: "Test", distance: 5.0, runInterval: 1.0, walkInterval: 1.0, difficulty: .beginner)
        mockWorkoutManager.startMockWorkout(from: program)
        
        // When
        mockWorkoutManager.updateMockDistance(2500) // 2.5km
        let formatted = mockWorkoutManager.formattedDistanceProgress
        
        // Then
        XCTAssertTrue(formatted.contains("2.50"), "Should show current distance")
        XCTAssertTrue(formatted.contains("5.0"), "Should show target distance")
        XCTAssertTrue(formatted.contains("km"), "Should include km unit")
    }
}

// MARK: - Mock Classes

class MockWatchWorkoutManager: ObservableObject {
    @Published var isWorkoutActive = false
    @Published var isWorkoutPaused = false
    @Published var remainingIntervalTime: TimeInterval = 0
    @Published var currentInterval: WorkoutInterval?
    @Published var intervals: [WorkoutInterval] = []
    @Published var currentIntervalIndex = 0
    @Published var totalDistance: Double = 0
    @Published var targetDistance: Double = 0
    @Published var distanceProgress: Double = 0
    @Published var isDistanceGoalReached = false
    
    var formattedDistanceProgress: String {
        let current = totalDistance / 1000.0
        return String(format: "%.2f / %.1f km", current, targetDistance)
    }
    
    func generateTestIntervals(from program: TrainingProgram) -> [WorkoutInterval] {
        // Simulate distance-based interval generation
        var intervals: [WorkoutInterval] = []
        
        let avgWalkSpeed = 5.0 // km/h
        let avgRunSpeed = 8.5 // km/h
        let walkIntervalHours = program.walkInterval / 60.0
        let runIntervalHours = program.runInterval / 60.0
        let distancePerCycle = (avgWalkSpeed * walkIntervalHours) + (avgRunSpeed * runIntervalHours)
        let estimatedCycles = max(Int(ceil(program.distance / distancePerCycle)), 5)
        
        for i in 0..<estimatedCycles {
            // Walk first
            intervals.append(WorkoutInterval(
                id: UUID(),
                name: "Walk \(i + 1)",
                type: .rest,
                duration: program.walkInterval * 60,
                targetHeartRateZone: .easy
            ))
            
            // Then run
            intervals.append(WorkoutInterval(
                id: UUID(),
                name: "Run \(i + 1)",
                type: .work,
                duration: program.runInterval * 60,
                targetHeartRateZone: .moderate
            ))
        }
        
        return intervals
    }
    
    func startMockWorkout(from program: TrainingProgram) {
        self.targetDistance = program.distance
        self.intervals = generateTestIntervals(from: program)
        self.currentIntervalIndex = 0
        self.isWorkoutActive = true
        self.isWorkoutPaused = false
        self.totalDistance = 0
        self.distanceProgress = 0
        self.isDistanceGoalReached = false
        
        if let firstInterval = intervals.first {
            self.currentInterval = firstInterval
            self.remainingIntervalTime = firstInterval.duration
        }
    }
    
    func updateMockDistance(_ meters: Double) {
        self.totalDistance = meters
        let currentDistanceKm = meters / 1000.0
        self.distanceProgress = min(currentDistanceKm / targetDistance, 1.0)
        
        if currentDistanceKm >= targetDistance {
            self.isDistanceGoalReached = true
        }
    }
    
    func simulateIntervalCompletion() {
        currentIntervalIndex += 1
        if currentIntervalIndex < intervals.count {
            currentInterval = intervals[currentIntervalIndex]
            remainingIntervalTime = currentInterval?.duration ?? 0
        }
    }
    
    func simulateTimerTick() {
        let currentDistanceKm = totalDistance / 1000.0
        if currentDistanceKm >= targetDistance && !isDistanceGoalReached {
            isDistanceGoalReached = true
        }
    }
}
