import Foundation
import HealthKit
import CloudKit

struct TrainingSession: Identifiable, Codable, Hashable {
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
    
    // CloudKit integration (excluded from Codable)
    var recordID: CKRecord.ID?
    
    // Custom Codable implementation to exclude recordID
    enum CodingKeys: String, CodingKey {
        case id, programID, programName, startDate, endDate, duration, averageHeartRate, maxHeartRate, caloriesBurned, distance, completedIntervals
    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(programID)
        hasher.combine(startDate)
    }
    
    static func == (lhs: TrainingSession, rhs: TrainingSession) -> Bool {
        return lhs.id == rhs.id && lhs.programID == rhs.programID && lhs.startDate == rhs.startDate
    }
}

struct CompletedInterval: Identifiable, Codable, Hashable {
    let id: UUID
    var intervalID: UUID
    var actualDuration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    
    init(intervalID: UUID, actualDuration: TimeInterval, averageHeartRate: Double? = nil, maxHeartRate: Double? = nil) {
        self.id = UUID()
        self.intervalID = intervalID
        self.actualDuration = actualDuration
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
    }
}
