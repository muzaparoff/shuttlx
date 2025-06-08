//
//  HealthManager.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import HealthKit
import Combine
import CoreLocation

class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var isHealthDataAvailable: Bool = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var permissionStatus: HealthPermissionStatus = .notDetermined
    @Published var currentHeartRate: Double?
    @Published var currentWorkout: HKWorkout?
    @Published var activeEnergyBurned: Double = 0
    @Published var distanceCovered: Double = 0
    @Published var currentHealthMetrics: HealthMetrics = .empty
    @Published var recoveryMetrics: HealthRecoveryMetrics?
    @Published var workoutStatistics: WorkoutStatistics?
    @Published var injuryRiskAssessment: InjuryRiskAssessment?
    
    // Real-time workout data
    @Published var currentHeartRateZone: HeartRateZone = .zone1
    @Published var timeInZones: [HeartRateZone: TimeInterval] = [:]
    @Published var isInTargetZone: Bool = false
    @Published var targetZone: HeartRateZone?
    
    // Health data types we need
    private let healthTypesToRead: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .vo2Max)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.workoutType()
    ]
    
    private let healthTypesToWrite: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.workoutType()
    ]
    
    private var heartRateQuery: HKQuery?
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var zoneTimer: Timer?
    private var workoutStartTime: Date?
    private var userMaxHeartRate: Double = 190 // Default, should be calculated based on age
    
    // Health data cache
    private var heartRateHistory: [HeartRateData] = []
    private var workoutHistory: [TrainingSession] = []
    
    init() {
        isHealthDataAvailable = HKHealthStore.isHealthDataAvailable()
        updatePermissionStatus()
        calculateMaxHeartRate()
        initializeTimeInZones()
    }
    
    // MARK: - Initialization Helpers
    
    private func updatePermissionStatus() {
        switch authorizationStatus {
        case .notDetermined:
            permissionStatus = .notDetermined
        case .sharingDenied:
            permissionStatus = .denied
        case .sharingAuthorized:
            permissionStatus = .authorized
        @unknown default:
            permissionStatus = .restricted
        }
    }
    
    private func calculateMaxHeartRate() {
        // Default calculation: 220 - age (will be updated with user's actual age if available)
        userMaxHeartRate = 190 // Default for now
    }
    
    private func initializeTimeInZones() {
        for zone in HeartRateZone.allCases {
            timeInZones[zone] = 0
        }
    }
    
    // MARK: - Authorization
    func requestPermissions() async {
        guard isHealthDataAvailable else {
            print("HealthKit is not available on this device")
            return
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: healthTypesToWrite, read: healthTypesToRead)
            
            await MainActor.run {
                self.authorizationStatus = .sharingAuthorized
                self.updatePermissionStatus()
                Task {
                    await self.startHealthDataMonitoring()
                    await self.loadInitialHealthData()
                }
            }
        } catch {
            await MainActor.run {
                self.authorizationStatus = .sharingDenied
                self.updatePermissionStatus()
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Health Data Monitoring
    
    private func startHealthDataMonitoring() async {
        await startHeartRateMonitoring()
        await loadRecoveryMetrics()
        await loadWorkoutStatistics()
    }
    
    private func loadInitialHealthData() async {
        await loadRestingHeartRate()
        await loadHeartRateVariability()
        await loadVO2Max()
    }
    
    // MARK: - Heart Rate Monitoring
    private func startHeartRateMonitoring() async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            if let error = error {
                print("Heart rate query failed: \(error.localizedDescription)")
                return
            }
            
            if let samples = samples as? [HKQuantitySample], let latestSample = samples.last {
                let heartRate = latestSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                Task { @MainActor in
                    self?.updateHeartRateData(heartRate, timestamp: latestSample.startDate)
                }
            }
        }
        
        query.updateHandler = { [weak self] _, samples, _, _, error in
            if let error = error {
                print("Heart rate update failed: \(error.localizedDescription)")
                return
            }
            
            if let samples = samples as? [HKQuantitySample], let latestSample = samples.last {
                let heartRate = latestSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                Task { @MainActor in
                    self?.updateHeartRateData(heartRate, timestamp: latestSample.startDate)
                }
            }
        }
        
        healthStore.execute(query)
        heartRateQuery = query
    }
    
    @MainActor
    private func updateHeartRateData(_ heartRate: Double, timestamp: Date) {
        currentHeartRate = heartRate
        currentHeartRateZone = HeartRateZone.zone(for: heartRate, maxHeartRate: userMaxHeartRate)
        
        // Check if in target zone
        if let target = targetZone {
            isInTargetZone = currentHeartRateZone == target
        }
        
        // Create heart rate data object
        let quality = determineHeartRateQuality(heartRate)
        let heartRateData = HeartRateData(
            current: heartRate,
            timestamp: timestamp,
            zone: currentHeartRateZone,
            quality: quality
        )
        
        // Add to history
        heartRateHistory.append(heartRateData)
        
        // Keep only last 1000 readings
        if heartRateHistory.count > 1000 {
            heartRateHistory.removeFirst()
        }
        
        // Update current health metrics
        updateCurrentHealthMetrics()
    }
    
    private func determineHeartRateQuality(_ heartRate: Double) -> HeartRateData.HeartRateQuality {
        let percentage = (heartRate / userMaxHeartRate) * 100
        
        switch percentage {
        case 40...100: return .excellent
        case 30...40: return .good
        case 20...30: return .fair
        default: return .poor
        }
    }
    
    @MainActor
    private func updateCurrentHealthMetrics() {
        let heartRateData = heartRateHistory.last
        
        let avgHeartRate = heartRateHistory.suffix(10).reduce(0) { $0 + $1.current } / Double(min(heartRateHistory.count, 10))
        let maxHeartRate = heartRateHistory.suffix(100).map { $0.current }.max()
        let minHeartRate = heartRateHistory.suffix(100).map { $0.current }.min()
        
        currentHealthMetrics = HealthMetrics(
            heartRate: heartRateData,
            activeEnergyBurned: activeEnergyBurned,
            totalEnergyBurned: activeEnergyBurned, // Simplified
            distanceCovered: distanceCovered,
            stepCount: 0, // Would need separate query
            workoutDuration: workoutStartTime?.timeIntervalSinceNow.magnitude ?? 0,
            averageHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            minHeartRate: minHeartRate,
            heartRateVariability: nil, // Would need separate query
            vo2Max: nil, // Would need separate query
            restingHeartRate: nil // Would need separate query
        )
    }
    
    func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        zoneTimer?.invalidate()
        zoneTimer = nil
    }
    
    // MARK: - Heart Rate Zone Tracking
    
    func setTargetHeartRateZone(_ zone: HeartRateZone) {
        targetZone = zone
    }
    
    private func startZoneTracking() {
        zoneTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let currentZone = self.currentHeartRateZone as HeartRateZone? {
                    self.timeInZones[currentZone, default: 0] += 1.0
                }
            }
        }
    }
    
    private func stopZoneTracking() {
        zoneTimer?.invalidate()
        zoneTimer = nil
    }
    
    // MARK: - Workout Management
    func startWorkout(configuration: WorkoutConfiguration) {
        workoutStartTime = Date()
        initializeTimeInZones()
        startZoneTracking()
        
        guard let workoutType = mapWorkoutType(configuration.type) else {
            print("Invalid workout type")
            return
        }
        
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = workoutType
        workoutConfiguration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: workoutConfiguration
            )
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    print("Failed to begin workout collection: \(error.localizedDescription)")
                }
            }
            
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
        }
    }
    
    func pauseWorkout() {
        workoutSession?.pause()
    }
    
    func resumeWorkout() {
        workoutSession?.resume()
    }
    
    func endWorkout() {
        stopZoneTracking()
        workoutSession?.end()
        workoutStartTime = nil
    }
    
    func finishWorkout() async -> TrainingSession? {
        guard let builder = workoutBuilder,
              let startTime = workoutStartTime else { return nil }
        
        do {
            let workout = try await builder.finishWorkout()
            
            // Create training session from workout data
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // Create a basic workout configuration for this session
            let basicConfig = createBasicWorkoutConfiguration(from: workout)
            
            let session = TrainingSession(
                workoutConfiguration: basicConfig,
                startTime: startTime,
                endTime: endTime,
                healthMetrics: currentHealthMetrics,
                locationData: [],
                notes: "",
                weather: nil,
                achievements: []
            )
            
            workoutHistory.append(session)
            
            return session
            
        } catch {
            print("Failed to finish workout: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func createBasicWorkoutConfiguration(from workout: HKWorkout) -> WorkoutConfiguration {
        // Create a basic configuration from the completed workout
        let workoutType = mapHKWorkoutType(workout.workoutActivityType)
        
        return WorkoutConfiguration(
            type: workoutType,
            name: workoutType.displayName,
            description: "Completed workout",
            duration: workout.duration,
            intervals: [],
            restPeriods: [],
            difficulty: .intermediate,
            targetHeartRateZone: nil,
            audioCoaching: AudioCoachingSettings(),
            hapticFeedback: HapticFeedbackSettings()
        )
    }
    
    private func mapHKWorkoutType(_ hkType: HKWorkoutActivityType) -> WorkoutType {
        switch hkType {
        case .functionalStrengthTraining:
            return .hiit
        case .running:
            return .runWalk
        default:
            return .custom
        }
    }
    
    private func mapWorkoutType(_ type: WorkoutType) -> HKWorkoutActivityType? {
        switch type {
        case .shuttleRun, .hiit, .tabata, .pyramid:
            return .functionalStrengthTraining
        case .runWalk:
            return .running
        case .custom:
            return .other
        }
    }
    
    // MARK: - Health Data Queries
    func getRecentWorkouts(completion: @escaping ([HKWorkout]) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: nil,
            limit: 10,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            DispatchQueue.main.async {
                if let workouts = samples as? [HKWorkout] {
                    completion(workouts)
                } else {
                    completion([])
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func loadRestingHeartRate() async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let sample = samples?.first as? HKQuantitySample {
                let restingHeartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                print("Resting heart rate: \(restingHeartRate)")
                // Update health metrics here
            }
        }
        
        healthStore.execute(query)
    }
    
    private func loadHeartRateVariability() async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let sample = samples?.first as? HKQuantitySample {
                let hrv = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                print("Heart rate variability: \(hrv)")
                // Update health metrics here
            }
        }
        
        healthStore.execute(query)
    }
    
    private func loadVO2Max() async {
        guard let vo2MaxType = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: vo2MaxType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let sample = samples?.first as? HKQuantitySample {
                let vo2Max = sample.quantity.doubleValue(for: HKUnit(from: "ml/kg*min"))
                print("VO2 Max: \(vo2Max)")
                // Update health metrics here
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Recovery and Analytics
    
    private func loadRecoveryMetrics() async {
        // Mock implementation - in real app would analyze sleep, HRV, etc.
        await MainActor.run {
            self.recoveryMetrics = HealthRecoveryMetrics(
                readinessScore: Double.random(in: 60...95),
                sleepQuality: .good,
                stressLevel: .moderate,
                heartRateVariability: Double.random(in: 25...45),
                restingHeartRate: Double.random(in: 55...75),
                recommendation: .moderateWorkout
            )
        }
    }
    
    private func loadWorkoutStatistics() async {
        // Mock implementation - in real app would aggregate historical data
        await MainActor.run {
            self.workoutStatistics = WorkoutStatistics(
                totalWorkouts: workoutHistory.count,
                totalDuration: workoutHistory.reduce(0) { $0 + $1.duration },
                totalDistance: workoutHistory.reduce(0) { $0 + ($1.totalDistance ?? 0) },
                totalCalories: workoutHistory.reduce(0) { $0 + ($1.caloriesBurned ?? 0) },
                averageHeartRate: currentHealthMetrics.averageHeartRate,
                bestWorkout: workoutHistory.max { $0.duration < $1.duration },
                currentStreak: calculateCurrentStreak(),
                longestStreak: calculateLongestStreak(),
                weeklyProgress: generateWeeklyProgress(),
                monthlyProgress: generateMonthlyProgress(),
                improvements: generateImprovements()
            )
        }
    }
    
    private func calculateCurrentStreak() -> Int {
        // Mock implementation
        return Int.random(in: 1...14)
    }
    
    private func calculateLongestStreak() -> Int {
        // Mock implementation
        return Int.random(in: 5...30)
    }
    
    private func generateWeeklyProgress() -> [Double] {
        return (0..<7).map { _ in Double.random(in: 0...100) }
    }
    
    private func generateMonthlyProgress() -> [Double] {
        return (0..<30).map { _ in Double.random(in: 0...100) }
    }
    
    private func generateImprovements() -> [WorkoutStatistics.ImprovementArea] {
        return [
            WorkoutStatistics.ImprovementArea(name: "Endurance", percentageChange: 12.5, isImprovement: true),
            WorkoutStatistics.ImprovementArea(name: "Recovery", percentageChange: 8.3, isImprovement: true),
            WorkoutStatistics.ImprovementArea(name: "Consistency", percentageChange: -2.1, isImprovement: false)
        ]
    }
    
    // MARK: - Injury Prevention
    
    func assessInjuryRisk() async {
        // Mock implementation - in real app would analyze workout patterns, recovery, etc.
        await MainActor.run {
            self.injuryRiskAssessment = InjuryRiskAssessment(
                overallRisk: .low,
                specificRisks: [
                    InjuryRiskAssessment.SpecificRisk(
                        area: "Knees",
                        risk: .low,
                        factors: ["Good running form", "Adequate recovery"],
                        prevention: ["Continue current routine", "Monitor for changes"]
                    )
                ],
                recommendations: [
                    "Maintain current training load",
                    "Focus on proper warm-up",
                    "Monitor fatigue levels"
                ],
                lastAssessment: Date()
            )
        }
    }
    
    // MARK: - Public Helper Methods
    
    func getHeartRateZoneTime(_ zone: HeartRateZone) -> TimeInterval {
        return timeInZones[zone] ?? 0
    }
    
    func getHeartRateZonePercentage(_ zone: HeartRateZone) -> Double {
        let totalTime = timeInZones.values.reduce(0, +)
        guard totalTime > 0 else { return 0 }
        return (timeInZones[zone] ?? 0) / totalTime * 100
    }
    
    func getCurrentHeartRateZoneColor() -> String {
        return currentHeartRateZone.color
    }
    
    func isHeartRateInZone(_ zone: HeartRateZone) -> Bool {
        return currentHeartRateZone == zone
    }
    
    // MARK: - Save Workout Data
    func saveWorkout(_ trainingSession: TrainingSession) async {
        let workoutType = mapWorkoutType(trainingSession.workoutConfiguration.type) ?? .other
        
        let workout = HKWorkout(
            activityType: workoutType,
            start: trainingSession.startTime,
            end: trainingSession.endTime,
            duration: trainingSession.duration,
            totalEnergyBurned: trainingSession.caloriesBurned.map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) },
            totalDistance: trainingSession.totalDistance.map { HKQuantity(unit: .meter(), doubleValue: $0) },
            metadata: [
                HKMetadataKeyWorkoutBrandName: "ShuttlX",
                HKMetadataKeyExternalUUID: trainingSession.id.uuidString
            ]
        )
        
        do {
            try await healthStore.save(workout)
            print("✅ Workout saved to HealthKit successfully")
        } catch {
            print("❌ Failed to save workout to HealthKit: \(error.localizedDescription)")
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension HealthManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                print("✅ Workout started")
                self.startZoneTracking()
            case .paused:
                print("⏸️ Workout paused")
                self.stopZoneTracking()
            case .ended:
                print("🏁 Workout ended")
                self.stopZoneTracking()
                self.workoutSession = nil
                self.workoutBuilder = nil
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ Workout session failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.stopZoneTracking()
            self.workoutSession = nil
            self.workoutBuilder = nil
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension HealthManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    if let heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) {
                        self.currentHeartRate = heartRate
                    }
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    if let energy = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.activeEnergyBurned = energy
                    }
                case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                    if let distance = statistics?.sumQuantity()?.doubleValue(for: .meter()) {
                        self.distanceCovered = distance
                    }
                default:
                    break
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}
