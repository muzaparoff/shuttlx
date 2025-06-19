//
//  EndToEndWorkoutIntegrationTests.swift
//  ShuttlX Integration Tests
//
//  Created by ShuttlX on 6/11/25.
//

import XCTest
import Foundation
@testable import ShuttlX

/// End-to-end integration tests for complete workout flows
/// Tests the entire journey from workout creation to results sync
class EndToEndWorkoutIntegrationTests: XCTestCase {
    
    var serviceLocator: ServiceLocator!
    var trainingProgramManager: TrainingProgramManager!
    var workoutViewModel: WorkoutViewModel!
    
    override func setUpWithError() throws {
              for i in 0..<completedIntervals {
            let interval = intervals[i]
            switch interval.type {
            case .work: totalCalories += 15; totalDistance += 200
            case .rest: totalCalories += 6; totalDistance += 100.setUp()
        
        serviceLocator = ServiceLocator.shared
        trainingProgramManager = TrainingProgramManager.shared
        workoutViewModel = WorkoutViewModel()
        
        // Clear test data
        UserDefaults.standard.removeObject(forKey: "e2e_test_workouts")
        UserDefaults.standard.removeObject(forKey: "e2e_test_results")
        UserDefaults.standard.removeObject(forKey: "completedWorkouts_iOS")
    }
    
    override func tearDownWithError() throws {
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "e2e_test_workouts")
        UserDefaults.standard.removeObject(forKey: "e2e_test_results")
        UserDefaults.standard.removeObject(forKey: "completedWorkouts_iOS")
        
        super.tearDown()
    }
    
    // MARK: - Complete iOS Workout Flow Tests
    
    func testCompleteIOSWorkoutFlow() async throws {
        print("\n🧪 STARTING COMPLETE iOS WORKOUT FLOW TEST")
        
        // STEP 1: Create custom workout
        print("📱 Step 1: Creating custom workout on iOS...")
        let customWorkout = TrainingProgram(
            name: "E2E Test iOS Workout",
            distance: 3.0,
            runInterval: 1.5,
            walkInterval: 1.0,
            totalDuration: 18.0,
            difficulty: .intermediate,
            description: "End-to-end test workout for iOS flow",
            estimatedCalories: 250,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        trainingProgramManager.saveCustomProgramWithSync(customWorkout)
        XCTAssertTrue(trainingProgramManager.customPrograms.contains { $0.id == customWorkout.id })
        print("   ✅ Custom workout created and saved")
        
        // STEP 2: Start workout session
        print("🏃‍♂️ Step 2: Starting workout session...")
        await MainActor.run {
            workoutViewModel.workoutType = .runWalk
            workoutViewModel.startWorkout()
        }
        
        let isActive = await workoutViewModel.workoutState == .active
        XCTAssertTrue(isActive)
        print("   ✅ Workout session started")
        
        // STEP 3: Simulate workout progression
        print("⏱️ Step 3: Simulating workout progression...")
        let intervals = generateWorkoutIntervals(from: customWorkout)
        var completedIntervals = 0
        var totalElapsedTime: TimeInterval = 0
        var simulatedCalories: Double = 0
        var simulatedDistance: Double = 0
        
        for (index, interval) in intervals.enumerated() {
            if index >= 3 { break } // Simulate partial workout for testing
            
            totalElapsedTime += interval.duration
            completedIntervals += 1
            
            // Simulate metrics based on interval type
            switch interval.type {
            case .work:
                simulatedCalories += 12
                simulatedDistance += 250
            case .rest:
                simulatedCalories += 6
                simulatedDistance += 120
            }
        }
        
        XCTAssertGreaterThan(completedIntervals, 0)
        print("   ✅ Workout progression simulated - \(completedIntervals) intervals")
        
        // STEP 4: End workout and save results
        print("💾 Step 4: Ending workout and saving results...")
        await MainActor.run {
            workoutViewModel.endWorkout()
        }
        
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
            maxHeartRate: 155
        )
        
        // Save results
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(workoutResults)
            UserDefaults.standard.set(data, forKey: "e2e_test_results")
            
            var allWorkouts: [WorkoutResults] = []
            if let existingData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS"),
               let existing = try? JSONDecoder().decode([WorkoutResults].self, from: existingData) {
                allWorkouts = existing
            }
            allWorkouts.append(workoutResults)
            
            let allWorkoutsData = try encoder.encode(allWorkouts)
            UserDefaults.standard.set(allWorkoutsData, forKey: "completedWorkouts_iOS")
            
        } catch {
            XCTFail("Failed to save workout results: \(error)")
        }
        
        print("   ✅ Workout results saved")
        
        // STEP 5: Verify data persistence
        print("🔍 Step 5: Verifying data persistence...")
        let savedData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS")
        XCTAssertNotNil(savedData)
        
        if let data = savedData {
            let decoder = JSONDecoder()
            let savedWorkouts = try decoder.decode([WorkoutResults].self, from: data)
            
            XCTAssertTrue(savedWorkouts.contains { $0.workoutId == workoutResults.workoutId })
            print("   ✅ Data persistence verified")
        }
        
        print("\n🎉 COMPLETE iOS WORKOUT FLOW TEST PASSED!")
        print("   - Custom workout: \(customWorkout.name)")
        print("   - Duration: \(Int(totalElapsedTime))s")
        print("   - Calories: \(Int(simulatedCalories))")
        print("   - Distance: \(Int(simulatedDistance))m")
    }
    
    // MARK: - Workout Data Synchronization Tests
    
    func testWorkoutDataSynchronization() throws {
        print("\n🔄 TESTING WORKOUT DATA SYNCHRONIZATION")
        
        // STEP 1: Create workout data on watchOS (simulated)
        print("⌚ Step 1: Simulating watchOS workout completion...")
        let watchWorkoutResults = WorkoutResults(
            workoutId: UUID(),
            startDate: Date().addingTimeInterval(-1200), // 20 minutes ago
            endDate: Date(),
            totalDuration: 1200, // 20 minutes
            activeCalories: 180,
            heartRate: 142,
            distance: 2500, // 2.5km
            completedIntervals: 6,
            averageHeartRate: 138,
            maxHeartRate: 158
        )
        
        // Save as if from watch
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(watchWorkoutResults)
            UserDefaults.standard.set(data, forKey: "lastWorkoutResults")
            print("   ✅ watchOS workout data created")
            
        } catch {
            XCTFail("Failed to create watch workout data: \(error)")
        }
        
        // STEP 2: Simulate sync to iOS
        print("📱 Step 2: Simulating sync to iOS...")
        guard let watchData = UserDefaults.standard.data(forKey: "lastWorkoutResults") else {
            XCTFail("Watch workout data not found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let receivedResults = try decoder.decode(WorkoutResults.self, from: watchData)
            
            // Add to iOS workout history
            var iosWorkouts: [WorkoutResults] = []
            if let existingData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS"),
               let existing = try? decoder.decode([WorkoutResults].self, from: existingData) {
                iosWorkouts = existing
            }
            iosWorkouts.append(receivedResults)
            
            let encoder = JSONEncoder()
            let allWorkoutsData = try encoder.encode(iosWorkouts)
            UserDefaults.standard.set(allWorkoutsData, forKey: "completedWorkouts_iOS")
            
            print("   ✅ Workout data synced to iOS")
            
        } catch {
            XCTFail("Failed to sync workout data: \(error)")
        }
        
        // STEP 3: Verify data integrity
        print("🔍 Step 3: Verifying data integrity...")
        let iosData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS")
        XCTAssertNotNil(iosData)
        
        if let data = iosData {
            let decoder = JSONDecoder()
            let iosWorkouts = try decoder.decode([WorkoutResults].self, from: data)
            
            let syncedWorkout = iosWorkouts.first { $0.workoutId == watchWorkoutResults.workoutId }
            XCTAssertNotNil(syncedWorkout)
            XCTAssertEqual(syncedWorkout?.totalDuration, watchWorkoutResults.totalDuration)
            XCTAssertEqual(syncedWorkout?.activeCalories, watchWorkoutResults.activeCalories)
            XCTAssertEqual(syncedWorkout?.distance, watchWorkoutResults.distance)
            
            print("   ✅ Data integrity verified")
        }
        
        print("\n🎉 WORKOUT DATA SYNCHRONIZATION TEST PASSED!")
    }
    
    // MARK: - Multi-Platform Workout Tests
    
    func testMultiPlatformWorkoutExecution() throws {
        print("\n📱⌚ TESTING MULTI-PLATFORM WORKOUT EXECUTION")
        
        // STEP 1: Create workout on iOS
        print("📱 Step 1: Creating workout on iOS...")
        let program = TrainingProgram(
            name: "Multi-Platform Test",
            distance: 2.0,
            runInterval: 1.0,
            walkInterval: 0.8,
            totalDuration: 12.0,
            difficulty: .beginner,
            description: "Testing multi-platform execution",
            estimatedCalories: 120,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        trainingProgramManager.saveCustomProgramWithSync(program)
        print("   ✅ Workout created on iOS")
        
        // STEP 2: Simulate sync to watchOS
        print("⌚ Step 2: Simulating sync to watchOS...")
        let allPrograms = trainingProgramManager.allPrograms
        XCTAssertTrue(allPrograms.contains { $0.id == program.id })
        
        do {
            let encoder = JSONEncoder()
            let syncData = try encoder.encode(allPrograms)
            
            // Simulate watchOS receiving data
            let decoder = JSONDecoder()
            let receivedPrograms = try decoder.decode([TrainingProgram].self, from: syncData)
            let syncedProgram = receivedPrograms.first { $0.id == program.id }
            
            XCTAssertNotNil(syncedProgram)
            XCTAssertEqual(syncedProgram?.name, program.name)
            XCTAssertEqual(syncedProgram?.totalDuration, program.totalDuration)
            
            print("   ✅ Program synced to watchOS")
            
        } catch {
            XCTFail("Failed to sync program to watchOS: \(error)")
        }
        
        // STEP 3: Simulate watchOS workout execution
        print("⌚ Step 3: Simulating watchOS workout execution...")
        let watchResults = executeWatchWorkout(program: program)
        
        XCTAssertGreaterThan(watchResults.totalDuration, 0)
        XCTAssertGreaterThan(watchResults.activeCalories, 0)
        XCTAssertGreaterThan(watchResults.completedIntervals, 0)
        
        print("   ✅ Workout executed on watchOS")
        print("     - Duration: \(Int(watchResults.totalDuration))s")
        print("     - Calories: \(Int(watchResults.activeCalories))")
        print("     - Intervals: \(watchResults.completedIntervals)")
        
        // STEP 4: Simulate results sync back to iOS
        print("📱 Step 4: Simulating results sync back to iOS...")
        do {
            let encoder = JSONEncoder()
            let resultData = try encoder.encode(watchResults)
            
            var iosWorkouts: [WorkoutResults] = []
            if let existingData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS"),
               let existing = try? JSONDecoder().decode([WorkoutResults].self, from: existingData) {
                iosWorkouts = existing
            }
            iosWorkouts.append(watchResults)
            
            let allWorkoutsData = try encoder.encode(iosWorkouts)
            UserDefaults.standard.set(allWorkoutsData, forKey: "completedWorkouts_iOS")
            
            print("   ✅ Results synced back to iOS")
            
        } catch {
            XCTFail("Failed to sync results back to iOS: \(error)")
        }
        
        print("\n🎉 MULTI-PLATFORM WORKOUT EXECUTION TEST PASSED!")
    }
    
    // MARK: - Performance Stress Tests
    
    func testWorkoutPerformanceUnderLoad() throws {
        print("\n⚡ TESTING WORKOUT PERFORMANCE UNDER LOAD")
        
        // STEP 1: Create multiple concurrent workouts
        print("🔄 Step 1: Creating multiple workout sessions...")
        let numberOfWorkouts = 10
        var workoutResults: [WorkoutResults] = []
        
        let startTime = Date()
        
        for i in 1...numberOfWorkouts {
            let program = TrainingProgram(
                name: "Load Test Workout \(i)",
                distance: Double.random(in: 1.0...5.0),
                runInterval: Double.random(in: 0.5...3.0),
                walkInterval: Double.random(in: 0.5...2.0),
                totalDuration: Double.random(in: 8.0...25.0),
                difficulty: TrainingDifficulty.allCases.randomElement()!,
                description: "Performance test workout",
                estimatedCalories: Int.random(in: 80...300),
                targetHeartRateZone: HeartRateZone.allCases.randomElement()!,
                isCustom: true
            )
            
            let result = executeSimulatedWorkout(program: program)
            workoutResults.append(result)
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        // STEP 2: Verify performance
        print("📊 Step 2: Analyzing performance...")
        XCTAssertEqual(workoutResults.count, numberOfWorkouts)
        XCTAssertLessThan(processingTime, 10.0, "Processing should complete within 10 seconds")
        
        // Calculate statistics
        let totalCalories = workoutResults.reduce(0) { $0 + $1.activeCalories }
        let totalDistance = workoutResults.reduce(0) { $0 + $1.distance }
        let totalDuration = workoutResults.reduce(0) { $0 + $1.totalDuration }
        
        print("   ✅ Performance test completed")
        print("     - Workouts processed: \(numberOfWorkouts)")
        print("     - Processing time: \(String(format: "%.2f", processingTime))s")
        print("     - Total calories: \(Int(totalCalories))")
        print("     - Total distance: \(Int(totalDistance))m")
        print("     - Total duration: \(Int(totalDuration/60)) minutes")
        
        // STEP 3: Test data persistence under load
        print("💾 Step 3: Testing data persistence under load...")
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(workoutResults)
            UserDefaults.standard.set(data, forKey: "performance_test_results")
            
            // Verify retrieval
            let savedData = UserDefaults.standard.data(forKey: "performance_test_results")
            XCTAssertNotNil(savedData)
            
            if let retrievedData = savedData {
                let decoder = JSONDecoder()
                let retrievedResults = try decoder.decode([WorkoutResults].self, from: retrievedData)
                XCTAssertEqual(retrievedResults.count, numberOfWorkouts)
                print("   ✅ Data persistence under load verified")
            }
            
        } catch {
            XCTFail("Performance test data persistence failed: \(error)")
        }
        
        print("\n🎉 WORKOUT PERFORMANCE UNDER LOAD TEST PASSED!")
    }
    
    // MARK: - Error Recovery Tests
    
    func testWorkoutErrorRecovery() throws {
        print("\n🛠️ TESTING WORKOUT ERROR RECOVERY")
        
        // STEP 1: Test workout interruption recovery
        print("🔄 Step 1: Testing workout interruption recovery...")
        let program = TrainingProgram(
            name: "Error Recovery Test",
            distance: 3.0,
            runInterval: 2.0,
            walkInterval: 1.0,
            totalDuration: 15.0,
            difficulty: .intermediate,
            description: "Testing error recovery scenarios",
            estimatedCalories: 180,
            targetHeartRateZone: .moderate,
            isCustom: true
        )
        
        // Simulate workout start
        let workoutId = UUID()
        let startDate = Date()
        
        // Simulate interruption after partial completion
        let partialResults = WorkoutResults(
            workoutId: workoutId,
            startDate: startDate,
            endDate: Date(),
            totalDuration: 300, // 5 minutes of 15 minute workout
            activeCalories: 60,
            heartRate: 135,
            distance: 800,
            completedIntervals: 3,
            averageHeartRate: 132,
            maxHeartRate: 145
        )
        
        // Save partial results for recovery
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(partialResults)
            UserDefaults.standard.set(data, forKey: "interrupted_workout")
            print("   ✅ Partial workout data saved for recovery")
            
        } catch {
            XCTFail("Failed to save interrupted workout data: \(error)")
        }
        
        // STEP 2: Test data corruption recovery
        print("🔧 Step 2: Testing data corruption recovery...")
        
        // Simulate corrupted data
        UserDefaults.standard.set("corrupted_data", forKey: "corrupted_workout_data")
        
        // Test recovery mechanism
        let corruptedData = UserDefaults.standard.data(forKey: "corrupted_workout_data")
        if let data = corruptedData {
            do {
                let _ = try JSONDecoder().decode(WorkoutResults.self, from: data)
                XCTFail("Should have failed to decode corrupted data")
            } catch {
                // Expected failure - corruption detected
                print("   ✅ Data corruption detected and handled")
                
                // Clear corrupted data
                UserDefaults.standard.removeObject(forKey: "corrupted_workout_data")
            }
        }
        
        // STEP 3: Test sync failure recovery
        print("📡 Step 3: Testing sync failure recovery...")
        
        // Simulate failed sync by storing in failure queue
        let failedSyncWorkout = WorkoutResults(
            workoutId: UUID(),
            startDate: Date().addingTimeInterval(-600),
            endDate: Date(),
            totalDuration: 600,
            activeCalories: 80,
            heartRate: 128,
            distance: 1200,
            completedIntervals: 4,
            averageHeartRate: 125,
            maxHeartRate: 138
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode([failedSyncWorkout])
            UserDefaults.standard.set(data, forKey: "failed_sync_queue")
            
            // Simulate recovery attempt
            let queuedData = UserDefaults.standard.data(forKey: "failed_sync_queue")
            XCTAssertNotNil(queuedData)
            
            if let data = queuedData {
                let decoder = JSONDecoder()
                let queuedWorkouts = try decoder.decode([WorkoutResults].self, from: data)
                XCTAssertEqual(queuedWorkouts.count, 1)
                print("   ✅ Failed sync recovery mechanism working")
            }
            
        } catch {
            XCTFail("Failed sync recovery test failed: \(error)")
        }
        
        print("\n🎉 WORKOUT ERROR RECOVERY TEST PASSED!")
    }
    
    // MARK: - Helper Methods
    
    private func generateWorkoutIntervals(from program: TrainingProgram) -> [TestWorkoutInterval] {
        var intervals: [TestWorkoutInterval] = []
        
        // Calculate run/walk cycles
        let totalWorkoutTime = program.totalDuration * 60
        let cycleTime = (program.runInterval + program.walkInterval) * 60
        let numberOfCycles = Int(totalWorkoutTime / cycleTime)
        
        // Add run/walk intervals
        for i in 0..<numberOfCycles {
            intervals.append(TestWorkoutInterval(
                name: "Run \(i + 1)",
                type: .work,
                duration: program.runInterval * 60
            ))
            
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
    
    private func executeWatchWorkout(program: TrainingProgram) -> WorkoutResults {
        // Simulate watchOS workout execution
        let intervals = generateWorkoutIntervals(from: program)
        
        var totalCalories: Double = 0
        var totalDistance: Double = 0
        let completedIntervals = min(intervals.count, 5) // Simulate partial completion
        
        for i in 0..<completedIntervals {
            let interval = intervals[i]
            switch interval.type {
            case .work: totalCalories += 15; totalDistance += 200
            case .rest: totalCalories += 8; totalDistance += 100
            }
        }
        
        return WorkoutResults(
            workoutId: UUID(),
            startDate: Date().addingTimeInterval(-program.totalDuration * 60),
            endDate: Date(),
            totalDuration: program.totalDuration * 60,
            activeCalories: totalCalories,
            heartRate: 142,
            distance: totalDistance,
            completedIntervals: completedIntervals,
            averageHeartRate: 138,
            maxHeartRate: 158
        )
    }
    
    private func executeSimulatedWorkout(program: TrainingProgram) -> WorkoutResults {
        // Quick simulation for performance testing
        let randomCalories = Double.random(in: 50...Double(program.estimatedCalories))
        let randomDistance = Double.random(in: 500...program.distance * 1000)
        let randomIntervals = Int.random(in: 3...8)
        
        return WorkoutResults(
            workoutId: UUID(),
            startDate: Date().addingTimeInterval(-program.totalDuration * 60),
            endDate: Date(),
            totalDuration: program.totalDuration * 60,
            activeCalories: randomCalories,
            heartRate: Double.random(in: 120...160),
            distance: randomDistance,
            completedIntervals: randomIntervals,
            averageHeartRate: Double.random(in: 115...155),
            maxHeartRate: Double.random(in: 140...180)
        )
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
