import Foundation
import CloudKit

struct TrainingProgram: Identifiable, Codable {
    let id = UUID()
    var name: String
    var intervals: [TrainingInterval]
    var maxPulse: Int
    var createdDate: Date
    var lastModified: Date
    
    // CloudKit integration
    var recordID: CKRecord.ID?
    
    init(name: String, intervals: [TrainingInterval] = [], maxPulse: Int = 180) {
        self.name = name
        self.intervals = intervals
        self.maxPulse = maxPulse
        self.createdDate = Date()
        self.lastModified = Date()
        self.recordID = nil
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
}

// MARK: - CloudKit Support
extension TrainingProgram {
    init?(from record: CKRecord) {
        guard let name = record["name"] as? String,
              let maxPulse = record["maxPulse"] as? Int,
              let createdDate = record["createdDate"] as? Date,
              let lastModified = record["lastModified"] as? Date,
              let intervalsData = record["intervals"] as? Data else {
            return nil
        }
        
        self.name = name
        self.maxPulse = maxPulse
        self.createdDate = createdDate
        self.lastModified = lastModified
        self.recordID = record.recordID
        
        // Decode intervals from data
        do {
            self.intervals = try JSONDecoder().decode([TrainingInterval].self, from: intervalsData)
        } catch {
            self.intervals = []
        }
    }
    
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: "TrainingProgram", recordID: recordID ?? CKRecord.ID())
        record["name"] = name
        record["maxPulse"] = maxPulse
        record["createdDate"] = createdDate
        record["lastModified"] = lastModified
        
        // Encode intervals to data
        do {
            let intervalsData = try JSONEncoder().encode(intervals)
            record["intervals"] = intervalsData
        } catch {
            record["intervals"] = Data()
        }
        
        return record
    }
}
