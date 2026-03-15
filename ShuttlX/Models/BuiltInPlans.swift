import Foundation

enum BuiltInPlans {
    // Stable UUIDs for built-in plans — never change these
    private static let couchTo5KID = UUID(uuidString: "B1000001-0000-0000-0000-000000000001") ?? UUID()
    private static let hiitStarterID = UUID(uuidString: "B1000001-0000-0000-0000-000000000002") ?? UUID()
    private static let fiveKImprovementID = UUID(uuidString: "B1000001-0000-0000-0000-000000000003") ?? UUID()

    static let all: [TrainingPlan] = [couchTo5K, hiitStarter, fiveKImprovement]

    // MARK: - Couch to 5K (8 weeks)

    static let couchTo5K: TrainingPlan = {
        let id = couchTo5KID

        func week(_ num: Int, label: String, workouts: [(day: Int, name: String)]) -> PlanWeek {
            var days: [PlanDay] = []
            for d in 1...7 {
                if let w = workouts.first(where: { $0.day == d }) {
                    days.append(PlanDay(dayNumber: d, templateName: w.name))
                } else {
                    days.append(PlanDay(dayNumber: d)) // rest day
                }
            }
            return PlanWeek(weekNumber: num, days: days, label: label)
        }

        return TrainingPlan(
            id: id,
            name: "Couch to 5K",
            planDescription: "Go from zero to running 5K in 8 weeks. Three workouts per week with gradual progression.",
            sportType: .running,
            weeks: [
                week(1, label: "Getting Started", workouts: [(2, "Walk 5min, Run 1min \u{00D7} 3"), (4, "Walk 5min, Run 1min \u{00D7} 3"), (6, "Walk 5min, Run 1min \u{00D7} 3")]),
                week(2, label: "Building Base", workouts: [(2, "Walk 4min, Run 2min \u{00D7} 3"), (4, "Walk 4min, Run 2min \u{00D7} 3"), (6, "Walk 4min, Run 2min \u{00D7} 3")]),
                week(3, label: "Progression", workouts: [(2, "Walk 3min, Run 3min \u{00D7} 3"), (4, "Walk 3min, Run 3min \u{00D7} 3"), (6, "Walk 3min, Run 3min \u{00D7} 4")]),
                week(4, label: "Gaining Confidence", workouts: [(2, "Walk 2min, Run 4min \u{00D7} 4"), (4, "Walk 2min, Run 5min \u{00D7} 3"), (6, "Walk 2min, Run 5min \u{00D7} 3")]),
                week(5, label: "Halfway There", workouts: [(2, "Run 5min, Walk 2min \u{00D7} 3"), (4, "Run 8min, Walk 3min \u{00D7} 2"), (6, "Run 10min, Walk 3min, Run 10min")]),
                week(6, label: "Running Longer", workouts: [(2, "Run 12min, Walk 2min, Run 8min"), (4, "Run 15min, Walk 2min, Run 5min"), (6, "Run 20min continuous")]),
                week(7, label: "Almost There", workouts: [(2, "Run 22min continuous"), (4, "Run 25min continuous"), (6, "Run 25min continuous")]),
                week(8, label: "Race Ready", workouts: [(2, "Run 25min continuous"), (4, "Run 28min continuous"), (6, "Run 30min \u{2014} You did it!")]),
            ],
            isBuiltIn: true
        )
    }()

    // MARK: - HIIT Starter (4 weeks)

    static let hiitStarter: TrainingPlan = {
        let id = hiitStarterID

        func week(_ num: Int, label: String, workouts: [(day: Int, name: String)]) -> PlanWeek {
            var days: [PlanDay] = []
            for d in 1...7 {
                if let w = workouts.first(where: { $0.day == d }) {
                    days.append(PlanDay(dayNumber: d, templateName: w.name))
                } else {
                    days.append(PlanDay(dayNumber: d))
                }
            }
            return PlanWeek(weekNumber: num, days: days, label: label)
        }

        return TrainingPlan(
            id: id,
            name: "HIIT Starter",
            planDescription: "4-week high-intensity interval program. Three sessions per week building from 20s to 40s work intervals.",
            sportType: .running,
            weeks: [
                week(1, label: "Introduction", workouts: [(1, "20s Work / 40s Rest \u{00D7} 6"), (3, "20s Work / 40s Rest \u{00D7} 8"), (5, "20s Work / 40s Rest \u{00D7} 8")]),
                week(2, label: "Building Up", workouts: [(1, "25s Work / 35s Rest \u{00D7} 8"), (3, "25s Work / 35s Rest \u{00D7} 10"), (5, "30s Work / 30s Rest \u{00D7} 8")]),
                week(3, label: "Pushing Limits", workouts: [(1, "30s Work / 30s Rest \u{00D7} 10"), (3, "35s Work / 25s Rest \u{00D7} 8"), (5, "35s Work / 25s Rest \u{00D7} 10")]),
                week(4, label: "Peak Performance", workouts: [(1, "40s Work / 20s Rest \u{00D7} 8"), (3, "40s Work / 20s Rest \u{00D7} 10"), (5, "40s Work / 20s Rest \u{00D7} 12")]),
            ],
            isBuiltIn: true
        )
    }()

    // MARK: - 5K Improvement (6 weeks)

    static let fiveKImprovement: TrainingPlan = {
        let id = fiveKImprovementID

        func week(_ num: Int, label: String, workouts: [(day: Int, name: String)]) -> PlanWeek {
            var days: [PlanDay] = []
            for d in 1...7 {
                if let w = workouts.first(where: { $0.day == d }) {
                    days.append(PlanDay(dayNumber: d, templateName: w.name))
                } else {
                    days.append(PlanDay(dayNumber: d))
                }
            }
            return PlanWeek(weekNumber: num, days: days, label: label)
        }

        return TrainingPlan(
            id: id,
            name: "5K Improvement",
            planDescription: "6-week plan to improve your 5K time. Mix of tempo runs, intervals, and easy runs with 4 sessions per week.",
            sportType: .running,
            weeks: [
                week(1, label: "Base Building", workouts: [(1, "Easy Run 25min"), (3, "Tempo Run 20min"), (5, "Intervals: 4\u{00D7}400m"), (7, "Long Run 30min")]),
                week(2, label: "Base Building", workouts: [(1, "Easy Run 25min"), (3, "Tempo Run 22min"), (5, "Intervals: 5\u{00D7}400m"), (7, "Long Run 35min")]),
                week(3, label: "Speed Work", workouts: [(1, "Easy Run 30min"), (3, "Tempo Run 25min"), (5, "Intervals: 6\u{00D7}400m"), (7, "Long Run 35min")]),
                week(4, label: "Speed Work", workouts: [(1, "Easy Run 30min"), (3, "Tempo Run 25min"), (5, "Intervals: 4\u{00D7}800m"), (7, "Long Run 40min")]),
                week(5, label: "Sharpening", workouts: [(1, "Easy Run 25min"), (3, "Tempo Run 20min"), (5, "Intervals: 5\u{00D7}800m"), (7, "Long Run 35min")]),
                week(6, label: "Race Week", workouts: [(1, "Easy Run 20min"), (3, "Short Tempo 15min"), (5, "Easy Jog 15min"), (7, "5K Race Day!")]),
            ],
            isBuiltIn: true
        )
    }()
}
