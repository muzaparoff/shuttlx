import Foundation
import SwiftUI

// Simple embedded types for the DataManager to avoid external dependencies
struct TrainingInterval_Simple: Identifiable {
    let id = UUID()
    var type: IntervalType_Simple
    var duration: TimeInterval
    
    init(type: IntervalType_Simple, duration: TimeInterval) {
        self.type = type
        self.duration = duration
    }
}

enum IntervalType_Simple: String, CaseIterable {
    case walk = "Walk"
    case run = "Run"
    case rest = "Rest"
}

struct TrainingProgram_Simple: Identifiable {
    let id = UUID()
    var name: String
    var intervals: [TrainingInterval_Simple]
    var maxPulse: Int
    var createdDate: Date
    
    init(name: String, intervals: [TrainingInterval_Simple] = [], maxPulse: Int = 180) {
        self.name = name
        self.intervals = intervals
        self.maxPulse = maxPulse
        self.createdDate = Date()
    }
}

class DataManager: ObservableObject {
    @Published var programs: [TrainingProgram_Simple] = []
    
    init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        // Create sample intervals for testing
        let walkInterval = TrainingInterval_Simple(type: .walk, duration: 30)
        let runInterval = TrainingInterval_Simple(type: .run, duration: 60)
        let restInterval = TrainingInterval_Simple(type: .rest, duration: 15)
        
        let sampleProgram = TrainingProgram_Simple(
            name: "Sample Shuttle Program",
            intervals: [walkInterval, runInterval, restInterval],
            maxPulse: 180
        )
        
        programs = [sampleProgram]
    }
    
    func addProgram(_ program: TrainingProgram_Simple) {
        programs.append(program)
    }
    
    func removeProgram(_ program: TrainingProgram_Simple) {
        programs.removeAll { $0.id == program.id }
    }
}