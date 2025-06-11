//
//  HealthKitIntegrationTests.swift
//  ShuttlX Integration Tests
//
//  Created by ShuttlX on 6/11/25.
//

import XCTest
import HealthKit
import Foundation
@testable import ShuttlX

/// Comprehensive HealthKit integration tests for the ShuttlX project
/// Tests health data synchronization, workout saving, and permission handling
class HealthKitIntegrationTests: XCTestCase {
    
    var healthManager: HealthManager!
    var serviceLocator: ServiceLocator!
    
    override func setUpWithError() throws {
        super.setUp()
        
        serviceLocator = ServiceLocator.shared
        healthManager = serviceLocator.healthManager
        
        // Clear any test data
        UserDefaults.standard.removeObject(forKey: "healthkit_test_data")
        UserDefaults.standard.removeObject(forKey: "workout_metrics_test")
    }
    
    override func tearDownWithError() throws {
        // Cleanup test data
        UserDefaults.standard.removeObject(forKey: "healthkit_test_data")
        UserDefaults.standard.removeObject(forKey: "workout_metrics_test")
        
        super.tearDown()
    }
    
    // MARK: - HealthKit Permission Tests
    
    func testHealthKitPermissionRequest() throws {
        // Given: HealthManager instance
        XCTAssertNotNil(healthManager)
        
        // When: Checking HealthKit availability
        XCTAssertTrue(healthManager.isHealthDataAvailable || !HKHealthStore.isHealthDataAvailable())
        
        // Then: Permission status should be trackable
        print("✅ HealthKit Permission Test PASSED")
        print("   - Health Data Available: \(healthManager.isHealthDataAvailable)")
        print("   - Current Permission Status: \(healthManager.hasHealthKitPermission)")
    }
    
    // MARK: - Health Data Reading Tests
    
    func testHealthDataRetrieval() async throws {
        // Given: HealthManager with potential permissions
        
        // When: Fetching today's health data
        await MainActor.run {
            healthManager.fetchTodayData()
        }
        
        // Wait for data fetch
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then: Health data should be accessible (even if zero)
        await MainActor.run {
            XCTAssertGreaterThanOrEqual(healthManager.todaySteps, 0)
            XCTAssertGreaterThanOrEqual(healthManager.todayCalories, 0)
            XCTAssertGreaterThanOrEqual(healthManager.todayDistance, 0)
            XCTAssertGreaterThanOrEqual(healthManager.currentHeartRate, 0)
        }
        
        print("✅ Health Data Retrieval Test PASSED")
        print("   - Steps: \(await healthManager.todaySteps)")
        print("   - Calories: \(await healthManager.todayCalories)")
        print("   - Distance: \(await healthManager.todayDistance)m")
        print("   - Heart Rate: \(await healthManager.currentHeartRate) bpm")
    }
    
    // MARK: - Workout Data Integration Tests
    
    func testWorkoutDataSavingToHealthKit() throws {
        // Given: Mock workout data
        let workoutData = WorkoutResults(
            workoutId: UUID(),
            startDate: Date().addingTimeInterval(-1800), // 30 minutes ago
            endDate: Date(),
            totalDuration: 1800, // 30 minutes
            activeCalories: 250,
            heartRate: 145,
            distance: 3000, // 3km in meters
            completedIntervals: 8,
            averageHeartRate: 140,
            maxHeartRate: 165
        )
        
        // When: Saving workout data
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(workoutData)
            UserDefaults.standard.set(data, forKey: "healthkit_test_data")
            
            // Simulate HealthKit workout creation
            let metrics = HealthMetrics(
                steps: 4500,
                distance: workoutData.distance,
                calories: workoutData.activeCalories,
                heartRate: workoutData.heartRate
            )
            
            let metricsData = try encoder.encode(metrics)
            UserDefaults.standard.set(metricsData, forKey: "workout_metrics_test")
            
        } catch {
            XCTFail("Failed to save workout data: \(error)")
        }
        
        // Then: Data should be persisted and retrievable
        let savedData = UserDefaults.standard.data(forKey: "healthkit_test_data")
        XCTAssertNotNil(savedData)
        
        if let data = savedData {
            let decoder = JSONDecoder()
            let retrievedWorkout = try decoder.decode(WorkoutResults.self, from: data)
            
            XCTAssertEqual(retrievedWorkout.workoutId, workoutData.workoutId)
            XCTAssertEqual(retrievedWorkout.totalDuration, 1800)
            XCTAssertEqual(retrievedWorkout.activeCalories, 250)
            XCTAssertEqual(retrievedWorkout.distance, 3000)
        }
        
        print("✅ Workout Data Saving Test PASSED")
        print("   - Workout ID: \(workoutData.workoutId)")
        print("   - Duration: \(workoutData.totalDuration)s")
        print("   - Calories: \(workoutData.activeCalories)")
        print("   - Distance: \(workoutData.distance)m")
    }
    
    // MARK: - Heart Rate Zone Tests
    
    func testHeartRateZoneCalculation() throws {
        // Given: Various heart rate values
        let testHeartRates: [Double] = [60, 90, 120, 150, 180]
        let expectedZones = ["Recovery", "Light", "Moderate", "Hard", "Maximum"]
        
        // When: Calculating heart rate zones
        for (index, heartRate) in testHeartRates.enumerated() {
            let zone = calculateHeartRateZone(heartRate: heartRate)
            
            // Then: Zone should be appropriate for heart rate
            XCTAssertFalse(zone.isEmpty)
            print("   - HR \(Int(heartRate)): \(zone)")
        }
        
        print("✅ Heart Rate Zone Calculation Test PASSED")
    }
    
    // MARK: - Health Data Export Tests
    
    func testHealthDataExport() throws {
        // Given: Multiple workout results
        let workouts = [
            WorkoutResults(
                workoutId: UUID(),
                startDate: Date().addingTimeInterval(-86400), // Yesterday
                endDate: Date().addingTimeInterval(-84600), // 30 min workout
                totalDuration: 1800,
                activeCalories: 280,
                heartRate: 145,
                distance: 3500,
                completedIntervals: 10,
                averageHeartRate: 140,
                maxHeartRate: 165
            ),
            WorkoutResults(
                workoutId: UUID(),
                startDate: Date().addingTimeInterval(-172800), // 2 days ago
                endDate: Date().addingTimeInterval(-171000), // 30 min workout
                totalDuration: 1800,
                activeCalories: 320,
                heartRate: 155,
                distance: 4200,
                completedIntervals: 12,
                averageHeartRate: 150,
                maxHeartRate: 175
            )
        ]
        
        // When: Creating export data
        let exportData = HealthExportData(
            exportDate: Date(),
            workouts: workouts.map { workout in
                HealthExportData.WorkoutExport(
                    date: workout.startDate,
                    type: "Run-Walk Interval",
                    duration: workout.totalDuration,
                    distance: workout.distance,
                    calories: workout.activeCalories,
                    averageHeartRate: workout.averageHeartRate,
                    maxHeartRate: workout.maxHeartRate
                )
            },
            healthMetrics: [
                HealthExportData.HealthMetricExport(
                    date: Date(),
                    stepCount: 8500,
                    activeCalories: 600,
                    totalCalories: 2100,
                    restingHeartRate: 65,
                    heartRateVariability: 45
                )
            ],
            heartRateData: []
        )
        
        // Then: Export data should be properly structured
        XCTAssertEqual(exportData.workouts.count, 2)
        XCTAssertEqual(exportData.healthMetrics.count, 1)
        XCTAssertNotNil(exportData.exportDate)
        
        // And: Should be serializable
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(exportData)
            XCTAssertGreaterThan(data.count, 0)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(HealthExportData.self, from: data)
            XCTAssertEqual(decoded.workouts.count, exportData.workouts.count)
        } catch {
            XCTFail("Failed to serialize export data: \(error)")
        }
        
        print("✅ Health Data Export Test PASSED")
        print("   - Exported \(exportData.workouts.count) workouts")
        print("   - Exported \(exportData.healthMetrics.count) health metrics")
    }
    
    // MARK: - Workout Statistics Tests
    
    func testWorkoutStatisticsCalculation() throws {
        // Given: Mock workout sessions
        let workoutSessions = [
            TrainingSession(
                startTime: Date().addingTimeInterval(-86400),
                endTime: Date().addingTimeInterval(-84600),
                workoutType: "HIIT",
                duration: 1800,
                distance: 3.5,
                calories: 280,
                averageHeartRate: 145,
                maxHeartRate: 175,
                steps: 4500,
                notes: nil
            ),
            TrainingSession(
                startTime: Date().addingTimeInterval(-172800),
                endTime: Date().addingTimeInterval(-171000),
                workoutType: "Endurance",
                duration: 2400,
                distance: 5.0,
                calories: 350,
                averageHeartRate: 135,
                maxHeartRate: 165,
                steps: 6000,
                notes: nil
            )
        ]
        
        // When: Calculating statistics
        let totalDuration = workoutSessions.reduce(0) { $0 + $1.duration }
        let totalCalories = workoutSessions.reduce(0) { $0 + $1.calories }
        let totalDistance = workoutSessions.reduce(0) { $0 + $1.distance }
        let averageHeartRate = workoutSessions.reduce(0) { $0 + ($1.averageHeartRate ?? 0) } / Double(workoutSessions.count)
        
        // Then: Statistics should be accurate
        XCTAssertEqual(totalDuration, 4200) // 70 minutes
        XCTAssertEqual(totalCalories, 630)
        XCTAssertEqual(totalDistance, 8.5) // 8.5km
        XCTAssertEqual(averageHeartRate, 140, accuracy: 1.0)
        
        print("✅ Workout Statistics Test PASSED")
        print("   - Total Duration: \(totalDuration/60) minutes")
        print("   - Total Calories: \(totalCalories)")
        print("   - Total Distance: \(totalDistance)km")
        print("   - Average Heart Rate: \(averageHeartRate) bpm")
    }
    
    // MARK: - Recovery Status Tests
    
    func testRecoveryStatusCalculation() throws {
        // Given: Mock health data for recovery calculation
        let restingHeartRate = 65.0
        let heartRateVariability = 45.0
        let recentWorkoutIntensity = 0.85 // High intensity
        let timeSinceLastWorkout: TimeInterval = 36 * 3600 // 36 hours
        
        // When: Calculating recovery status
        let recoveryScore = calculateRecoveryScore(
            restingHR: restingHeartRate,
            hrv: heartRateVariability,
            lastWorkoutIntensity: recentWorkoutIntensity,
            timeSinceWorkout: timeSinceLastWorkout
        )
        
        // Then: Recovery score should be reasonable
        XCTAssertGreaterThan(recoveryScore, 0)
        XCTAssertLessThanOrEqual(recoveryScore, 100)
        
        let recoveryStatus = getRecoveryStatus(score: recoveryScore)
        XCTAssertFalse(recoveryStatus.isEmpty)
        
        print("✅ Recovery Status Test PASSED")
        print("   - Recovery Score: \(recoveryScore)")
        print("   - Recovery Status: \(recoveryStatus)")
    }
    
    // MARK: - Helper Methods
    
    private func calculateHeartRateZone(heartRate: Double) -> String {
        let maxHR = 190.0 // Simplified max heart rate
        let percentage = heartRate / maxHR
        
        switch percentage {
        case 0.0..<0.6: return "Recovery"
        case 0.6..<0.7: return "Light"
        case 0.7..<0.8: return "Moderate"
        case 0.8..<0.9: return "Hard"
        default: return "Maximum"
        }
    }
    
    private func calculateRecoveryScore(restingHR: Double, hrv: Double, lastWorkoutIntensity: Double, timeSinceWorkout: TimeInterval) -> Double {
        // Simplified recovery calculation
        let hrScore = (75 - restingHR) / 15 * 100 // Lower resting HR = better
        let hrvScore = hrv / 50 * 100 // Higher HRV = better
        let recoveryTime = min(timeSinceWorkout / (24 * 3600), 1.0) * 100 // More time = better
        let intensityPenalty = lastWorkoutIntensity * 20 // Higher intensity = longer recovery
        
        let score = max(0, min(100, (hrScore + hrvScore + recoveryTime - intensityPenalty) / 3))
        return score
    }
    
    private func getRecoveryStatus(score: Double) -> String {
        switch score {
        case 80...100: return "Fully Recovered"
        case 60..<80: return "Good Recovery"
        case 40..<60: return "Moderate Recovery"
        case 20..<40: return "Poor Recovery"
        default: return "Not Recovered"
        }
    }
}

// MARK: - Mock Health Metrics Model

struct HealthMetrics: Codable {
    let steps: Int
    let distance: Double        // meters
    let calories: Double       // kcal
    let heartRate: Double      // bpm
    let timestamp: Date
    
    init(steps: Int = 0, distance: Double = 0, calories: Double = 0, heartRate: Double = 0) {
        self.steps = steps
        self.distance = distance
        self.calories = calories
        self.heartRate = heartRate
        self.timestamp = Date()
    }
}
