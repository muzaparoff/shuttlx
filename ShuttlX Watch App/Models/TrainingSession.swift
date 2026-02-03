import Foundation

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
    
    init(programID: UUID, programName: String, startDate: Date, endDate: Date? = nil, duration: TimeInterval, averageHeartRate: Double? = nil, maxHeartRate: Double? = nil, caloriesBurned: Double? = nil, distance: Double? = nil, completedIntervals: [CompletedInterval] = []) {
        self.id = UUID()
        self.programID = programID
        self.programName = programName
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.caloriesBurned = caloriesBurned
        self.distance = distance
        self.completedIntervals = completedIntervals
    }
}

struct CompletedInterval: Identifiable, Codable {
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
