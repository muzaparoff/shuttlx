import Foundation

struct TrainingProgram: Identifiable, Codable {
    let id: UUID
    var name: String
    var intervals: [TrainingInterval]
    var maxPulse: Int
    var createdDate: Date
    var lastModified: Date
    
    init(name: String, intervals: [TrainingInterval] = [], maxPulse: Int = 180) {
        self.id = UUID()
        self.name = name
        self.intervals = intervals
        self.maxPulse = maxPulse
        self.createdDate = Date()
        self.lastModified = Date()
    }
    
    // Computed properties for convenience
    var totalDuration: TimeInterval {
        intervals.reduce(0) { $0 + $1.duration }
    }
    
    var intervalCount: Int {
        intervals.count
    }
    
    var walkIntervalCount: Int {
        intervals.filter { $0.type == .walk }.count
    }
    
    var runIntervalCount: Int {
        intervals.filter { $0.type == .run }.count
    }
    
    var formattedTotalDuration: String {
        let minutes = Int(totalDuration / 60)
        let seconds = Int(totalDuration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}
