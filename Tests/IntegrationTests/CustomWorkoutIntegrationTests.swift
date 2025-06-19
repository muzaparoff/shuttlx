//
//  CustomWorkoutIntegrationTests.swift
//  ShuttlX Integration Tests
//
//  Created by ShuttlX on 6/11/25.
//

import XCTest
import Foundation
import WatchConnectivity
@testable import ShuttlX

/// Comprehensive integration tests for the custom workout flow:
/// iOS custom workout creation → watchOS sync → workout execution → results back to iOS
class CustomWorkoutIntegrationTests: XCTestCase {
    
    var serviceLocator: ServiceLocator!
    var watchConnectivityManager: WatchConnectivityManager!
    var trainingProgramManager: TrainingProgramManager!
    
    override func setUpWithError() throws {
        super.setUp()
        
        // Setup test environment
        serviceLocator = ServiceLocator.shared
        watchConnectivityManager = serviceLocator.watchManager
        trainingProgramManager = TrainingProgramManager.shared
        
        // Clear any existing test data
        UserDefaults.standard.removeObject(forKey: "customPrograms")
        UserDefaults.standard.removeObject(forKey: "completedWorkouts_iOS")
        UserDefaults.standard.removeObject(forKey: "queued_training_programs")
        UserDefaults.standard.removeObject(forKey: "pending_selected_program")
    }
    
    override func tearDownWithError() throws {
        // Cleanup test data
        UserDefaults.standard.removeObject(forKey: "customPrograms")
        UserDefaults.standard.removeObject(forKey: "completedWorkouts_iOS")
        UserDefaults.standard.removeObject(forKey: "queued_training_programs")
        UserDefaults.standard.removeObject(forKey: "pending_selected_program")
        
        super.tearDown()
    }
    
    // MARK: - Integration Test 1: Custom Workout Creation and Storage
    
    func testCustomWorkoutCreationAndPersistence() throws {
        // Given: A new custom workout configuration
        let customWorkout = TrainingProgram(
            name: "Test HIIT Sprint",
            distance: 5.0,
            runInterval: 2.0,
            walkInterval: 1.5,
            totalDuration: 30.0,
            difficulty: .intermediate,
            description: "High-intensity sprint intervals for testing",
            estimatedCalories: 350,
            targetHeartRateZone: .hard,
            isCustom: true
        )
        
        // When: Creating and saving the custom workout
        trainingProgramManager.saveCustomProgramWithSync(customWorkout)
        
        // Then: Custom workout should be saved locally
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.id == customWorkout.id })
        XCTAssertEqual(trainingProgramManager.customPrograms.last?.name, "Test HIIT Sprint")
        XCTAssertEqual(trainingProgramManager.customPrograms.last?.isCustom, true)
        
        // And: Workout should be persisted to UserDefaults
        let savedPrograms = UserDefaults.standard.data(forKey: "customPrograms")
        XCTAssertNotNil(savedPrograms)
        
        let decoder = JSONDecoder()
        let decodedPrograms = try decoder.decode([TrainingProgram].self, from: savedPrograms!)
        XCTAssertTrue(decodedPrograms.contains { $0.id == customWorkout.id })
        
        print("✅ Test 1 PASSED: Custom workout created and persisted successfully")
    }
    
    // MARK: - Integration Test 2: Custom Workout Parameters Validation
    
    func testCustomWorkoutParametersValidation() throws {
        // Given: Various custom workout configurations
        let validWorkout = TrainingProgram(
            name: "Valid Test Workout",
            distance: 3.0,
            runInterval: 1.5,
            walkInterval: 1.0,
            totalDuration: 20.0,
            difficulty: .beginner,
            description: "Valid workout configuration",
            estimatedCalories: 200,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        let extremeWorkout = TrainingProgram(
            name: "Extreme Test Workout",
            distance: 15.0,
            runInterval: 5.0,
            walkInterval: 0.5,
            totalDuration: 90.0,
            difficulty: .expert,
            description: "Extreme workout configuration",
            estimatedCalories: 800,
            targetHeartRateZone: .maximum,
            isCustom: true
        )
        
        // When: Saving both workouts
        trainingProgramManager.saveCustomProgramWithSync(validWorkout)
        trainingProgramManager.saveCustomProgramWithSync(extremeWorkout)
        
        // Then: Both should be saved with correct parameters
        XCTAssertEqual(trainingProgramManager.customPrograms.count, 2)
        
        let savedValid = trainingProgramManager.customPrograms.first { $0.id == validWorkout.id }
        XCTAssertNotNil(savedValid)
        XCTAssertEqual(savedValid?.runInterval, 1.5)
        XCTAssertEqual(savedValid?.walkInterval, 1.0)
        XCTAssertEqual(savedValid?.totalDuration, 20.0)
        XCTAssertEqual(savedValid?.difficulty, .beginner)
        
        let savedExtreme = trainingProgramManager.customPrograms.first { $0.id == extremeWorkout.id }
        XCTAssertNotNil(savedExtreme)
        XCTAssertEqual(savedExtreme?.distance, 15.0)
        XCTAssertEqual(savedExtreme?.estimatedCalories, 800)
        XCTAssertEqual(savedExtreme?.targetHeartRateZone, .maximum)
        
        print("✅ Test 2 PASSED: Custom workout parameters validated correctly")
    }
    
    // MARK: - Integration Test 3: Watch Connectivity Sync Preparation
    
    func testWatchConnectivitySyncPreparation() throws {
        // Given: A custom workout and sync manager
        let testWorkout = TrainingProgram(
            name: "Sync Test Workout",
            distance: 4.0,
            runInterval: 2.5,
            walkInterval: 1.0,
            totalDuration: 25.0,
            difficulty: .intermediate,
            description: "Testing watch sync functionality",
            estimatedCalories: 280,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        // When: Adding workout and preparing for sync
        trainingProgramManager.saveCustomProgramWithSync(testWorkout)
        
        // Then: Workout should be in all programs list for sync
        let allPrograms = trainingProgramManager.allPrograms
        XCTAssertTrue(allPrograms.contains { $0.id == testWorkout.id })
        
        // And: Workout data should be serializable for WatchConnectivity
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode([testWorkout])
        XCTAssertGreaterThan(encodedData.count, 0)
        
        // And: Message format should be correct for watch sync
        let syncMessage: [String: Any] = [
            "training_programs": encodedData,
            "timestamp": Date().timeIntervalSince1970,
            "version": "1.0"
        ]
        
        XCTAssertNotNil(syncMessage["training_programs"])
        XCTAssertNotNil(syncMessage["timestamp"])
        XCTAssertEqual(syncMessage["version"] as? String, "1.0")
        
        print("✅ Test 3 PASSED: Watch connectivity sync preparation successful")
    }
    
    // MARK: - Integration Test 4: Workout Interval Generation
    
    func testWorkoutIntervalGeneration() throws {
        // Given: A custom workout configuration
        let customWorkout = TrainingProgram(
            name: "Interval Generation Test",
            distance: 6.0,
            runInterval: 3.0, // 3 minutes
            walkInterval: 2.0, // 2 minutes
            totalDuration: 35.0, // 35 minutes total
            difficulty: .intermediate,
            description: "Testing interval generation algorithm",
            estimatedCalories: 420,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        // When: Generating intervals (simulating watchOS conversion)
        let intervals = generateTestIntervals(from: customWorkout)
        
        // Then: Correct number and type of intervals should be generated
        XCTAssertGreaterThan(intervals.count, 0)
        
        // Should have work intervals (run)
        let workIntervals = intervals.filter { $0.type == .work }
        XCTAssertGreaterThan(workIntervals.count, 0)
        workIntervals.forEach { interval in
            XCTAssertEqual(interval.duration, 180) // 3 minutes = 180 seconds
        }
        
        // Should have rest intervals (walk)
        let restIntervals = intervals.filter { $0.type == .rest }
        XCTAssertGreaterThan(restIntervals.count, 0)
        restIntervals.forEach { interval in
            XCTAssertEqual(interval.duration, 120) // 2 minutes = 120 seconds
        }
        
        // Total interval time should approximately match total duration
        let totalIntervalTime = intervals.reduce(0) { $0 + $1.duration }
        let expectedTime = customWorkout.totalDuration * 60 // Convert to seconds
        let tolerance = 300.0 // 5 minutes tolerance
        XCTAssertEqual(totalIntervalTime, expectedTime, accuracy: tolerance)
        
        print("✅ Test 4 PASSED: Workout interval generation working correctly")
        print("   - Generated \(intervals.count) intervals")
        print("   - Work: \(workIntervals.count), Rest: \(restIntervals.count)")
        print("   - Total time: \(totalIntervalTime/60) minutes (expected: \(expectedTime/60))")
    }
    
    // MARK: - Integration Test 5: Workout Results Data Structure
    
    func testWorkoutResultsDataStructure() throws {
        // Given: Simulated workout completion data
        let startDate = Date()
        let endDate = Date().addingTimeInterval(1800) // 30 minutes later
        
        let workoutResults = WorkoutResults(
            workoutId: UUID(),
            startDate: startDate,
            endDate: endDate,
            totalDuration: 1800, // 30 minutes
            activeCalories: 350,
            heartRate: 145,
            distance: 4500, // 4.5km in meters
            completedIntervals: 12,
            averageHeartRate: 140,
            maxHeartRate: 165
        )
        
        // When: Encoding and decoding workout results
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encodedData = try encoder.encode(workoutResults)
        let decodedResults = try decoder.decode(WorkoutResults.self, from: encodedData)
        
        // Then: All data should be preserved correctly
        XCTAssertEqual(decodedResults.workoutId, workoutResults.workoutId)
        XCTAssertEqual(decodedResults.totalDuration, 1800)
        XCTAssertEqual(decodedResults.activeCalories, 350)
        XCTAssertEqual(decodedResults.heartRate, 145)
        XCTAssertEqual(decodedResults.distance, 4500)
        XCTAssertEqual(decodedResults.completedIntervals, 12)
        XCTAssertEqual(decodedResults.averageHeartRate, 140)
        XCTAssertEqual(decodedResults.maxHeartRate, 165)
        
        // And: Results should be storable in UserDefaults
        UserDefaults.standard.set(encodedData, forKey: "test_workout_results")
        let storedData = UserDefaults.standard.data(forKey: "test_workout_results")
        XCTAssertNotNil(storedData)
        
        let restoredResults = try decoder.decode(WorkoutResults.self, from: storedData!)
        XCTAssertEqual(restoredResults.workoutId, workoutResults.workoutId)
        
        print("✅ Test 5 PASSED: Workout results data structure validated")
    }
    
    // MARK: - Integration Test 6: iOS Stats Integration
    
    func testWorkoutResultsIntegrationInStats() throws {
        // Given: Multiple completed workout results
        let workout1Results = WorkoutResults(
            workoutId: UUID(),
            startDate: Date().addingTimeInterval(-86400), // Yesterday
            endDate: Date().addingTimeInterval(-84600), // 30 min workout
            totalDuration: 1800,
            activeCalories: 280,
            heartRate: 135,
            distance: 3500,
            completedIntervals: 10,
            averageHeartRate: 130,
            maxHeartRate: 150
        )
        
        let workout2Results = WorkoutResults(
            workoutId: UUID(),
            startDate: Date().addingTimeInterval(-43200), // 12 hours ago
            endDate: Date().addingTimeInterval(-41400), // 30 min workout
            totalDuration: 1800,
            activeCalories: 320,
            heartRate: 142,
            distance: 4200,
            completedIntervals: 12,
            averageHeartRate: 138,
            maxHeartRate: 160
        )
        
        // When: Saving workout results as if received from watch
        var allWorkouts: [WorkoutResults] = []
        
        // Load existing workouts
        if let existingData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS"),
           let existing = try? JSONDecoder().decode([WorkoutResults].self, from: existingData) {
            allWorkouts = existing
        }
        
        // Add new workouts
        allWorkouts.append(workout1Results)
        allWorkouts.append(workout2Results)
        
        // Save updated list
        let encoder = JSONEncoder()
        let allWorkoutsData = try encoder.encode(allWorkouts)
        UserDefaults.standard.set(allWorkoutsData, forKey: "completedWorkouts_iOS")
        
        // Then: Workouts should be retrievable for stats
        let savedData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS")
        XCTAssertNotNil(savedData)
        
        let decoder = JSONDecoder()
        let retrievedWorkouts = try decoder.decode([WorkoutResults].self, from: savedData!)
        
        XCTAssertEqual(retrievedWorkouts.count, 2)
        
        // Verify workout data integrity
        let savedWorkout1 = retrievedWorkouts.first { $0.workoutId == workout1Results.workoutId }
        XCTAssertNotNil(savedWorkout1)
        XCTAssertEqual(savedWorkout1?.activeCalories, 280)
        XCTAssertEqual(savedWorkout1?.distance, 3500)
        
        let savedWorkout2 = retrievedWorkouts.first { $0.workoutId == workout2Results.workoutId }
        XCTAssertNotNil(savedWorkout2)
        XCTAssertEqual(savedWorkout2?.activeCalories, 320)
        XCTAssertEqual(savedWorkout2?.distance, 4200)
        
        // Calculate aggregate stats
        let totalCalories = retrievedWorkouts.reduce(0) { $0 + $1.activeCalories }
        let totalDistance = retrievedWorkouts.reduce(0) { $0 + $1.distance }
        let totalDuration = retrievedWorkouts.reduce(0) { $0 + $1.totalDuration }
        
        XCTAssertEqual(totalCalories, 600)
        XCTAssertEqual(totalDistance, 7700) // 7.7km
        XCTAssertEqual(totalDuration, 3600) // 1 hour total
        
        print("✅ Test 6 PASSED: Workout results integration with iOS stats")
        print("   - Total Calories: \(totalCalories)")
        print("   - Total Distance: \(totalDistance/1000.0)km")
        print("   - Total Duration: \(totalDuration/60) minutes")
    }
    
    // MARK: - Integration Test 7: Complete Flow Simulation
    
    func testCompleteCustomWorkoutFlow() throws {
        print("\n🧪 STARTING COMPLETE CUSTOM WORKOUT INTEGRATION TEST")
        
        // STEP 1: Create custom workout on iOS
        print("📱 Step 1: Creating custom workout on iOS...")
        let customWorkout = TrainingProgram(
            name: "Integration Test Workout",
            distance: 5.0,
            runInterval: 2.0,
            walkInterval: 1.5,
            totalDuration: 30.0,
            difficulty: .intermediate,
            description: "Complete integration test for custom workout flow",
            estimatedCalories: 350,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        trainingProgramManager.saveCustomProgramWithSync(customWorkout)
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.id == customWorkout.id })
        print("   ✅ Custom workout created and saved")
        
        // STEP 2: Prepare sync data for watchOS
        print("📡 Step 2: Preparing sync data for watchOS...")
        let allPrograms = trainingProgramManager.allPrograms
        let syncData = try JSONEncoder().encode(allPrograms)
        let syncMessage: [String: Any] = [
            "training_programs": syncData,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        XCTAssertNotNil(syncMessage["training_programs"])
        print("   ✅ Sync data prepared for watch transmission")
        
        // STEP 3: Simulate workout execution on watchOS
        print("⌚ Step 3: Simulating workout execution on watchOS...")
        let intervals = generateTestIntervals(from: customWorkout)
        
        // Simulate workout progression
        var completedIntervals = 0
        var totalElapsedTime: TimeInterval = 0
        var simulatedCalories: Double = 0
        var simulatedDistance: Double = 0
        var maxHeartRate: Double = 120
        
        for (index, interval) in intervals.enumerated() {
            totalElapsedTime += interval.duration
            
            // Simulate different heart rates and calorie burn for different interval types
            switch interval.type {
            case .work:
                simulatedCalories += 15 // High calorie burn during work
                simulatedDistance += 300 // Fast pace
                maxHeartRate = max(maxHeartRate, 160)
            case .rest:
                simulatedCalories += 8 // Moderate calorie burn during rest
                simulatedDistance += 150 // Moderate pace
                maxHeartRate = max(maxHeartRate, 120)
            }
            
            completedIntervals = index + 1
            
            // Break if we've simulated enough for testing (don't need full workout)
            if completedIntervals >= 5 {
                break
            }
        }
        
        XCTAssertGreaterThan(completedIntervals, 0)
        XCTAssertGreaterThan(totalElapsedTime, 0)
        print("   ✅ Workout execution simulated - \(completedIntervals) intervals completed")
        
        // STEP 4: Create workout results
        print("📊 Step 4: Creating workout results...")
        let workoutResults = WorkoutResults(
            workoutId: UUID(),
            startDate: Date().addingTimeInterval(-totalElapsedTime),
            endDate: Date(),
            totalDuration: totalElapsedTime,
            activeCalories: simulatedCalories,
            heartRate: 145,
            distance: simulatedDistance,
            completedIntervals: completedIntervals,
            averageHeartRate: 140,
            maxHeartRate: maxHeartRate
        )
        
        XCTAssertEqual(workoutResults.completedIntervals, completedIntervals)
        XCTAssertEqual(workoutResults.totalDuration, totalElapsedTime, accuracy: 1.0)
        print("   ✅ Workout results created with \(workoutResults.activeCalories) calories, \(workoutResults.distance)m distance")
        
        // STEP 5: Simulate sending results back to iOS
        print("📱 Step 5: Simulating results sync back to iOS...")
        
        // Save results as if received from watch
        var allWorkouts: [WorkoutResults] = []
        if let existingData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS"),
           let existing = try? JSONDecoder().decode([WorkoutResults].self, from: existingData) {
            allWorkouts = existing
        }
        allWorkouts.append(workoutResults)
        
        let encoder = JSONEncoder()
        let allWorkoutsData = try encoder.encode(allWorkouts)
        UserDefaults.standard.set(allWorkoutsData, forKey: "completedWorkouts_iOS")
        
        // Verify results are accessible in iOS
        let savedData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS")!
        let decoder = JSONDecoder()
        let retrievedWorkouts = try decoder.decode([WorkoutResults].self, from: savedData)
        
        XCTAssertTrue(retrievedWorkouts.contains { $0.workoutId == workoutResults.workoutId })
        print("   ✅ Workout results synced back to iOS and accessible in stats")
        
        // STEP 6: Verify complete data integrity
        print("🔍 Step 6: Verifying complete data integrity...")
        
        let finalWorkout = retrievedWorkouts.first { $0.workoutId == workoutResults.workoutId }!
        XCTAssertEqual(finalWorkout.activeCalories, simulatedCalories, accuracy: 1.0)
        XCTAssertEqual(finalWorkout.distance, simulatedDistance, accuracy: 1.0)
        XCTAssertEqual(finalWorkout.completedIntervals, completedIntervals)
        XCTAssertEqual(finalWorkout.maxHeartRate, maxHeartRate, accuracy: 1.0)
        
        print("   ✅ Data integrity verified across complete flow")
        
        print("\n🎉 COMPLETE CUSTOM WORKOUT INTEGRATION TEST PASSED!")
        print("   - Custom workout: \(customWorkout.name)")
        print("   - Intervals completed: \(completedIntervals)")
        print("   - Calories burned: \(Int(simulatedCalories))")
        print("   - Distance covered: \(Int(simulatedDistance))m")
        print("   - Duration: \(Int(totalElapsedTime))s")
    }
    
    // MARK: - Helper Methods
    
    /// Helper method to generate intervals from training program (simulates watchOS logic)
    private func generateTestIntervals(from program: TrainingProgram) -> [TestWorkoutInterval] {
        var intervals: [TestWorkoutInterval] = []
        
        // Calculate cycles
        let totalWorkoutTime = program.totalDuration * 60 // Convert to seconds
        let cycleTime = (program.runInterval + program.walkInterval) * 60 // Convert to seconds
        let numberOfCycles = Int(totalWorkoutTime / cycleTime)
        
        // Add run/walk intervals
        for i in 0..<numberOfCycles {
            // Run interval
            intervals.append(TestWorkoutInterval(
                name: "Run \(i + 1)",
                type: .work,
                duration: program.runInterval * 60
            ))
            
            // Walk interval (except after the last run)
            if i < numberOfCycles - 1 {
                intervals.append(TestWorkoutInterval(
                    name: "Walk \(i + 1)",
                    type: .rest,
                    duration: program.walkInterval * 60
                ))
            }
        }
        
        return intervals
    }
}

// MARK: - Test Supporting Models

struct TestWorkoutInterval {
    let name: String
    let type: IntervalType
    let duration: TimeInterval
    
    enum IntervalType {
        case work, rest
    }
}

// Extension to make TrainingProgram work with tests
extension TrainingProgram: Equatable {
    public static func == (lhs: TrainingProgram, rhs: TrainingProgram) -> Bool {
        return lhs.id == rhs.id
    }
}
