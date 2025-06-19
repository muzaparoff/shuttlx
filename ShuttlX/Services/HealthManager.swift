import Foundation
import HealthKit
import SwiftUI

class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var isHealthDataAvailable = false
    @Published var hasHealthKitPermission = false
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Double = 0
    @Published var todayDistance: Double = 0
    @Published var currentHeartRate: Double = 0
    @Published var recentWorkouts: [HKWorkout] = []
    
    init() {
        isHealthDataAvailable = HKHealthStore.isHealthDataAvailable()
        requestHealthKitPermissions()
    }
    
    func requestHealthKitPermissions() {
        guard isHealthDataAvailable else { return }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.hasHealthKitPermission = success
                if success {
                    self?.fetchTodayData()
                }
            }
        }
    }
    
    func fetchTodayData() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        fetchSteps(from: startOfDay, to: endOfDay)
        fetchCalories(from: startOfDay, to: endOfDay)
        fetchDistance(from: startOfDay, to: endOfDay)
        fetchHeartRate()
    }
    
    private func fetchSteps(from startDate: Date, to endDate: Date) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            DispatchQueue.main.async {
                self?.todaySteps = Int(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchCalories(from startDate: Date, to endDate: Date) {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            DispatchQueue.main.async {
                self?.todayCalories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchDistance(from startDate: Date, to endDate: Date) {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            DispatchQueue.main.async {
                self?.todayDistance = result?.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            DispatchQueue.main.async {
                if let latestSample = samples?.first as? HKQuantitySample {
                    self?.currentHeartRate = latestSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func startWorkout(type: HKWorkoutActivityType) {
        // Basic workout start - simplified for MVP
        print("Starting workout: \(type)")
    }
    
    func stopWorkout() {
        // Basic workout stop - simplified for MVP
        print("Stopping workout")
    }
    
    func requestHealthPermissions() async {
        guard isHealthDataAvailable else { return }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            await MainActor.run {
                self.hasHealthKitPermission = true
                self.fetchTodayData()
            }
        } catch {
            print("Error requesting health permissions: \(error)")
            await MainActor.run {
                self.hasHealthKitPermission = false
            }
        }
    }
}
