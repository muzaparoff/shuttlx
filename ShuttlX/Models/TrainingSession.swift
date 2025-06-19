import Foundation
import HealthKit
import CloudKit

struct TrainingSession: Identifiable, Codable {
    let id = UUID()
    var programID: UUID
    var programName: String
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var caloriesBurned: Double?
    var distance: Double?
    var completedIntervals: [CompletedInterval]
    
    // CloudKit integration
    var recordID: CKRecord.ID?
    
    init(programID: UUID, programName: String, startDate: Date = Date()) {
        self.programID = programID
        self.programName = programName
        self.startDate = startDate
        self.endDate = nil
        self.duration = 0
        self.averageHeartRate = nil
        self.maxHeartRate = nil
        self.caloriesBurned = nil
        self.distance = nil
        self.completedIntervals = []
        self.recordID = nil
    }
    
    // Computed properties for convenience
    var isCompleted: Bool {
        endDate != nil
    }
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
    
    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
    
    var formattedDistance: String {
        guard let distance = distance else { return "N/A" }
        
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    var formattedCalories: String {
        guard let calories = caloriesBurned else { return "N/A" }
        return String(format: "%.0f cal", calories)
    }
    
    var formattedAverageHeartRate: String {
        guard let avgHR = averageHeartRate else { return "N/A" }
        return String(format: "%.0f bpm", avgHR)
    }
    
    var formattedMaxHeartRate: String {
        guard let maxHR = maxHeartRate else { return "N/A" }
        return String(format: "%.0f bpm", maxHR)
    }
    
    // Methods
    mutating func complete(endDate: Date = Date()) {
        self.endDate = endDate
        self.duration = endDate.timeIntervalSince(startDate)
    }
    
    mutating func addCompletedInterval(_ interval: CompletedInterval) {
        completedIntervals.append(interval)
    }
}

struct CompletedInterval: Identifiable, Codable {
    let id = UUID()
    var intervalID: UUID
    var intervalType: IntervalType
    var plannedDuration: TimeInterval
    var actualDuration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var distance: Double?
    var startTime: TimeInterval // seconds from session start
    
    init(intervalID: UUID, intervalType: IntervalType, plannedDuration: TimeInterval, startTime: TimeInterval) {
        self.intervalID = intervalID
        self.intervalType = intervalType
        self.plannedDuration = plannedDuration
        self.actualDuration = 0
        self.averageHeartRate = nil
        self.maxHeartRate = nil
        self.distance = nil
        self.startTime = startTime
    }
    
    // Computed properties
    var isCompleted: Bool {
        actualDuration > 0
    }
    
    var durationDifference: TimeInterval {
        actualDuration - plannedDuration
    }
    
    var formattedActualDuration: String {
        let minutes = Int(actualDuration / 60)
        let seconds = Int(actualDuration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
    
    var formattedPlannedDuration: String {
        let minutes = Int(plannedDuration / 60)
        let seconds = Int(plannedDuration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
    
    mutating func complete(actualDuration: TimeInterval) {
        self.actualDuration = actualDuration
    }
}

// MARK: - CloudKit Support
extension TrainingSession {
    init?(from record: CKRecord) {
        guard let programIDString = record["programID"] as? String,
              let programID = UUID(uuidString: programIDString),
              let programName = record["programName"] as? String,
              let startDate = record["startDate"] as? Date,
              let duration = record["duration"] as? Double else {
            return nil
        }
        
        self.programID = programID
        self.programName = programName
        self.startDate = startDate
        self.endDate = record["endDate"] as? Date
        self.duration = duration
        self.averageHeartRate = record["averageHeartRate"] as? Double
        self.maxHeartRate = record["maxHeartRate"] as? Double
        self.caloriesBurned = record["caloriesBurned"] as? Double
        self.distance = record["distance"] as? Double
        self.recordID = record.recordID
        
        // Decode completed intervals from data
        if let intervalsData = record["completedIntervals"] as? Data {
            do {
                self.completedIntervals = try JSONDecoder().decode([CompletedInterval].self, from: intervalsData)
            } catch {
                self.completedIntervals = []
            }
        } else {
            self.completedIntervals = []
        }
    }
    
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: "TrainingSession", recordID: recordID ?? CKRecord.ID())
        record["programID"] = programID.uuidString
        record["programName"] = programName
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["duration"] = duration
        record["averageHeartRate"] = averageHeartRate
        record["maxHeartRate"] = maxHeartRate
        record["caloriesBurned"] = caloriesBurned
        record["distance"] = distance
        
        // Encode completed intervals to data
        do {
            let intervalsData = try JSONEncoder().encode(completedIntervals)
            record["completedIntervals"] = intervalsData
        } catch {
            record["completedIntervals"] = Data()
        }
        
        return record
    }
}

// MARK: - HealthKit Integration
extension TrainingSession {
    func toHealthKitWorkout() -> HKWorkout? {
        guard let endDate = endDate else { return nil }
        
        let workoutActivityType: HKWorkoutActivityType = .mixed
        let totalEnergyBurned = caloriesBurned.map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) }
        let totalDistance = distance.map { HKQuantity(unit: .meter(), doubleValue: $0) }
        
        return HKWorkout(
            activityType: workoutActivityType,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: totalEnergyBurned,
            totalDistance: totalDistance,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "ShuttlX",
                "programName": programName,
                "programID": programID.uuidString
            ]
        )
    }
}
