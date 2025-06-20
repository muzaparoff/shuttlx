import Foundation
import HealthKit

struct TrainingSession: Identifiable, Codable {
    let id: UUID
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
    
    init(programID: UUID, programName: String, startDate: Date = Date()) {
        self.id = UUID()
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
    let id: UUID
    var intervalID: UUID
    var intervalType: IntervalType
    var plannedDuration: TimeInterval
    var actualDuration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var distance: Double?
    var startTime: TimeInterval // seconds from session start
    
    init(intervalID: UUID, intervalType: IntervalType, plannedDuration: TimeInterval, startTime: TimeInterval) {
        self.id = UUID()
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
