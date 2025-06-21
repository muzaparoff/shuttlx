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
}

struct CompletedInterval: Identifiable, Codable {
    let id = UUID()
    var intervalID: UUID
    var actualDuration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?
}
