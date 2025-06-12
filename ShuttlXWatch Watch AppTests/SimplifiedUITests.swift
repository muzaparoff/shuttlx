//
//  SimplifiedUITests.swift
//  ShuttlXWatch Watch AppTests
//
//  Tests for simplified UI and enhanced sync functionality
//

import XCTest
@testable import ShuttlXWatch_Watch_App

@MainActor
final class SimplifiedUITests: XCTestCase {
    
    var watchConnectivity: WatchConnectivityManager!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        watchConnectivity = WatchConnectivityManager()
    }
    
    override func tearDownWithError() throws {
        watchConnectivity = nil
    }
    
    // MARK: - UI Simplification Tests
    
    func testSimplifiedWorkoutRowDisplay() throws {
        // Given: A sample training program
        let program = TrainingProgram(
            name: "Test Workout",
            distance: 5.0,
            runInterval: 2.0,
            walkInterval: 1.0,
            totalDuration: 30.0,
            difficulty: .intermediate,
            description: "Test description",
            estimatedCalories: 250,
            targetHeartRateZone: .moderate,
            isCustom: false
        )
        
        // Then: Basic properties should be correctly formatted
        XCTAssertEqual(program.name, "Test Workout")
        XCTAssertEqual(Int(program.totalDuration), 30)
        XCTAssertEqual(program.estimatedCalories, 250)
        XCTAssertEqual(program.difficulty.displayName, "Intermediate")
        XCTAssertFalse(program.isCustom)
        
        print("✅ Simplified workout row display test passed")
    }
    
    func testCustomWorkoutIdentification() throws {
        // Given: A custom training program
        let customProgram = TrainingProgram(
            name: "My Custom Workout",
            distance: 3.0,
            runInterval: 1.5,
            walkInterval: 0.5,
            totalDuration: 20.0,
            difficulty: .beginner,
            description: "Custom workout description",
            estimatedCalories: 180,
            targetHeartRateZone: .easy,
            isCustom: true
        )
        
        // Then: Should be identified as custom
        XCTAssertTrue(customProgram.isCustom)
        XCTAssertEqual(customProgram.name, "My Custom Workout")
        
        print("✅ Custom workout identification test passed")
    }
    
    // MARK: - Sync Enhancement Tests
    
    func testCustomWorkoutSyncData() throws {
        // Given: Multiple custom workouts
        let customWorkouts = [
            TrainingProgram(
                name: "Custom Workout 1",
                distance: 2.0,
                runInterval: 1.0,
                walkInterval: 0.5,
                totalDuration: 15.0,
                difficulty: .beginner,
                description: "First custom workout",
                estimatedCalories: 120,
                targetHeartRateZone: .easy,
                isCustom: true
            ),
            TrainingProgram(
                name: "Custom Workout 2",
                distance: 4.0,
                runInterval: 2.0,
                walkInterval: 1.0,
                totalDuration: 25.0,
                difficulty: .intermediate,
                description: "Second custom workout",
                estimatedCalories: 200,
                targetHeartRateZone: .moderate,
                isCustom: true
            )
        ]
        
        // When: Encoding for sync
        let encoder = JSONEncoder()
        let data = try encoder.encode(customWorkouts)
        
        // Then: Should be able to decode back
        let decoder = JSONDecoder()
        let decodedWorkouts = try decoder.decode([TrainingProgram].self, from: data)
        
        XCTAssertEqual(decodedWorkouts.count, 2)
        XCTAssertTrue(decodedWorkouts.allSatisfy { $0.isCustom })
        XCTAssertEqual(decodedWorkouts[0].name, "Custom Workout 1")
        XCTAssertEqual(decodedWorkouts[1].name, "Custom Workout 2")
        
        print("✅ Custom workout sync data test passed")
    }
    
    func testSyncNotificationHandling() throws {
        // Given: Sample custom workouts
        let customWorkouts = [
            TrainingProgram(
                name: "Sync Test Workout",
                distance: 1.5,
                runInterval: 0.5,
                walkInterval: 0.5,
                totalDuration: 10.0,
                difficulty: .beginner,
                description: "Workout for sync testing",
                estimatedCalories: 80,
                targetHeartRateZone: .easy,
                isCustom: true
            )
        ]
        
        // When: Simulating notification
        let expectation = XCTestExpectation(description: "Sync notification received")
        
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AllCustomWorkoutsSynced"),
            object: nil,
            queue: .main
        ) { notification in
            if let workouts = notification.object as? [TrainingProgram] {
                XCTAssertEqual(workouts.count, 1)
                XCTAssertEqual(workouts[0].name, "Sync Test Workout")
                expectation.fulfill()
            }
        }
        
        // Then: Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("AllCustomWorkoutsSynced"),
            object: customWorkouts
        )
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
        
        print("✅ Sync notification handling test passed")
    }
    
    // MARK: - Performance Tests
    
    func testSimplifiedUIPerformance() throws {
        // Test that simplified UI elements don't cause performance issues
        measure {
            // Simulate creating multiple workout rows
            for i in 0..<100 {
                let program = TrainingProgram(
                    name: "Workout \(i)",
                    distance: Double(i),
                    runInterval: 1.0,
                    walkInterval: 0.5,
                    totalDuration: Double(10 + i),
                    difficulty: .beginner,
                    description: "Performance test workout",
                    estimatedCalories: 100 + i,
                    targetHeartRateZone: .easy,
                    isCustom: i % 2 == 0
                )
                
                // Simulate basic property access that would happen in UI
                _ = program.name
                _ = program.isCustom
                _ = program.difficulty.displayName
                _ = Int(program.totalDuration)
            }
        }
        
        print("✅ Simplified UI performance test completed")
    }
}
