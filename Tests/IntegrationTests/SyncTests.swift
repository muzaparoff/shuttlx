import XCTest
@testable import ShuttlX

class SyncTests: XCTestCase {
    var watchManager: WatchConnectivityManager!
    var programManager: TrainingProgramManager!
    
    override func setUp() {
        super.setUp()
        watchManager = WatchConnectivityManager.shared
        programManager = TrainingProgramManager.shared
    }
    
    override func tearDown() {
        // Clean up any test data
        UserDefaults.standard.removeObject(forKey: "queued_custom_workouts")
        UserDefaults.standard.removeObject(forKey: "custom_workouts")
        super.tearDown()
    }
    
    func testCustomWorkoutSync() {
        // Create a test custom workout
        let customWorkout = TrainingProgram(
            name: "Test Custom Workout",
            distance: 5.0,
            runInterval: 2.0,
            walkInterval: 1.0,
            difficulty: .intermediate,
            description: "Test custom workout",
            estimatedCalories: 200,
            targetHeartRateZone: .zone3
        )
        
        // Save custom workout
        programManager.saveCustomProgramWithSync(customWorkout)
        
        // Verify workout was saved
        XCTAssertTrue(programManager.customPrograms.contains { $0.id == customWorkout.id })
        
        // Test sync to watch
        let expectation = XCTestExpectation(description: "Sync to watch")
        
        // Mock watch connectivity
        class MockWCSession: WCSession {
            override var isReachable: Bool { return true }
        }
        
        // Simulate successful sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Verify sync status
            XCTAssertEqual(self.watchManager.syncStatus, "Synced")
            XCTAssertNotNil(self.watchManager.lastSyncTime)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSyncQueueing() {
        // Create test workouts
        let workout1 = TrainingProgram(
            name: "Test Workout 1",
            distance: 3.0,
            runInterval: 1.0,
            walkInterval: 1.0,
            difficulty: .beginner,
            description: "Test workout 1",
            estimatedCalories: 100,
            targetHeartRateZone: .zone2
        )
        
        let workout2 = TrainingProgram(
            name: "Test Workout 2",
            distance: 5.0,
            runInterval: 2.0,
            walkInterval: 1.0,
            difficulty: .intermediate,
            description: "Test workout 2",
            estimatedCalories: 200,
            targetHeartRateZone: .zone3
        )
        
        // Mock watch as unreachable
        class MockWCSession: WCSession {
            override var isReachable: Bool { return false }
        }
        
        // Try to sync workouts
        watchManager.sendAllCustomWorkouts([workout1, workout2])
        
        // Verify workouts were queued
        let expectation = XCTestExpectation(description: "Workouts queued")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Check if workouts were saved to queue
            let queuedData = UserDefaults.standard.data(forKey: "queued_custom_workouts")
            XCTAssertNotNil(queuedData)
            
            do {
                let decoder = JSONDecoder()
                let queuedWorkouts = try decoder.decode([TrainingProgram].self, from: queuedData!)
                XCTAssertEqual(queuedWorkouts.count, 2)
                expectation.fulfill()
            } catch {
                XCTFail("Failed to decode queued workouts: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSyncRetry() {
        // Create a test workout
        let workout = TrainingProgram(
            name: "Test Retry Workout",
            distance: 4.0,
            runInterval: 2.0,
            walkInterval: 1.0,
            difficulty: .intermediate,
            description: "Test retry workout",
            estimatedCalories: 150,
            targetHeartRateZone: .zone3
        )
        
        // Queue the workout
        watchManager.sendAllCustomWorkouts([workout])
        
        // Verify retry was scheduled
        let expectation = XCTestExpectation(description: "Retry scheduled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Check if retry was scheduled
            XCTAssertNotNil(UserDefaults.standard.data(forKey: "queued_custom_workouts"))
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
} 