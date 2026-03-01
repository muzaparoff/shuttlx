import Foundation

// MARK: - Plan Day

struct PlanDay: Identifiable, Codable, Hashable {
    let id: UUID
    var dayNumber: Int
    var templateID: UUID?
    var templateName: String?
    var notes: String?

    var isRestDay: Bool { templateID == nil && templateName == nil }

    init(id: UUID = UUID(), dayNumber: Int, templateID: UUID? = nil, templateName: String? = nil, notes: String? = nil) {
        self.id = id
        self.dayNumber = dayNumber
        self.templateID = templateID
        self.templateName = templateName
        self.notes = notes
    }
}

// MARK: - Plan Week

struct PlanWeek: Identifiable, Codable, Hashable {
    let id: UUID
    var weekNumber: Int
    var days: [PlanDay]
    var label: String?

    init(id: UUID = UUID(), weekNumber: Int, days: [PlanDay] = [], label: String? = nil) {
        self.id = id
        self.weekNumber = weekNumber
        self.days = days
        self.label = label
    }
}

// MARK: - Training Plan

struct TrainingPlan: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var planDescription: String?
    var sportType: WorkoutSport?
    var weeks: [PlanWeek]
    var isBuiltIn: Bool
    var createdDate: Date
    var modifiedDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        planDescription: String? = nil,
        sportType: WorkoutSport? = nil,
        weeks: [PlanWeek] = [],
        isBuiltIn: Bool = false,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.planDescription = planDescription
        self.sportType = sportType
        self.weeks = weeks
        self.isBuiltIn = isBuiltIn
        self.createdDate = createdDate
    }

    var totalWeeks: Int { weeks.count }

    var totalWorkoutDays: Int {
        weeks.flatMap(\.days).filter { !$0.isRestDay }.count
    }

    var summaryText: String {
        "\(totalWeeks) week\(totalWeeks == 1 ? "" : "s") · \(totalWorkoutDays) workouts"
    }
}

// MARK: - Plan Progress

struct PlanProgress: Identifiable, Codable, Hashable {
    let id: UUID
    var planID: UUID
    var startDate: Date
    var completedDays: [CompletedPlanDay]
    var isActive: Bool

    init(id: UUID = UUID(), planID: UUID, startDate: Date = Date(), completedDays: [CompletedPlanDay] = [], isActive: Bool = true) {
        self.id = id
        self.planID = planID
        self.startDate = startDate
        self.completedDays = completedDays
        self.isActive = isActive
    }
}

struct CompletedPlanDay: Identifiable, Codable, Hashable {
    let id: UUID
    var weekNumber: Int
    var dayNumber: Int
    var sessionID: UUID?
    var completedDate: Date
    var skipped: Bool

    init(id: UUID = UUID(), weekNumber: Int, dayNumber: Int, sessionID: UUID? = nil, completedDate: Date = Date(), skipped: Bool = false) {
        self.id = id
        self.weekNumber = weekNumber
        self.dayNumber = dayNumber
        self.sessionID = sessionID
        self.completedDate = completedDate
        self.skipped = skipped
    }
}
