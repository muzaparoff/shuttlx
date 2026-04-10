import Foundation
import os.log

@MainActor
class PlanManager: ObservableObject {
    @Published var plans: [TrainingPlan] = []
    @Published var progresses: [PlanProgress] = []

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "PlanManager")
    private let appGroupIdentifier = "group.com.shuttlx.shared"
    private let plansFileName = "training_plans.json"
    private let progressFileName = "plan_progress.json"

    init() {
        loadPlans()
        loadProgress()
        seedBuiltInPlansIfNeeded()
    }

    // MARK: - CRUD

    func save(_ plan: TrainingPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
        persistPlans()
    }

    func delete(_ plan: TrainingPlan) {
        guard !plan.isBuiltIn else { return }
        plans.removeAll { $0.id == plan.id }
        progresses.removeAll { $0.planID == plan.id }
        persistPlans()
        persistProgress()
    }

    // MARK: - Progress

    func startPlan(_ plan: TrainingPlan) {
        // Deactivate any currently active progress
        for i in progresses.indices {
            progresses[i].isActive = false
        }
        let progress = PlanProgress(planID: plan.id)
        progresses.append(progress)
        persistProgress()
    }

    func markDayCompleted(progressID: UUID, weekNumber: Int, dayNumber: Int, sessionID: UUID? = nil, skipped: Bool = false) {
        guard let index = progresses.firstIndex(where: { $0.id == progressID }) else { return }
        let completed = CompletedPlanDay(weekNumber: weekNumber, dayNumber: dayNumber, sessionID: sessionID, skipped: skipped)
        progresses[index].completedDays.append(completed)
        persistProgress()
    }

    func activePlan() -> (plan: TrainingPlan, progress: PlanProgress)? {
        guard let progress = progresses.first(where: { $0.isActive }) else { return nil }
        guard let plan = plans.first(where: { $0.id == progress.planID }) else { return nil }
        return (plan, progress)
    }

    func completionPercentage(for progress: PlanProgress) -> Double {
        guard let plan = plans.first(where: { $0.id == progress.planID }) else { return 0 }
        let totalWorkouts = plan.totalWorkoutDays
        guard totalWorkouts > 0 else { return 0 }
        let completed = progress.completedDays.filter { !$0.skipped }.count
        return Double(completed) / Double(totalWorkouts)
    }

    func nextWorkout(for progress: PlanProgress) -> (week: Int, day: Int, templateName: String?)? {
        guard let plan = plans.first(where: { $0.id == progress.planID }) else { return nil }
        let completedSet = Set(progress.completedDays.map { "\($0.weekNumber)-\($0.dayNumber)" })

        for week in plan.weeks.sorted(by: { $0.weekNumber < $1.weekNumber }) {
            for day in week.days.sorted(by: { $0.dayNumber < $1.dayNumber }) where !day.isRestDay {
                let key = "\(week.weekNumber)-\(day.dayNumber)"
                if !completedSet.contains(key) {
                    return (week.weekNumber, day.dayNumber, day.templateName)
                }
            }
        }
        return nil
    }

    // MARK: - Persistence

    private func loadPlans() {
        guard let url = fileURL(plansFileName) else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            plans = try JSONDecoder().decode([TrainingPlan].self, from: data)
            logger.info("Loaded \(self.plans.count) plan(s)")
        } catch {
            logger.error("Failed to load plans: \(error.localizedDescription)")
        }
    }

    private func persistPlans() {
        guard let url = fileURL(plansFileName) else { return }
        do {
            let data = try JSONEncoder().encode(plans)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            logger.info("Saved \(self.plans.count) plan(s)")
        } catch {
            logger.error("Failed to save plans: \(error.localizedDescription)")
        }
    }

    private func loadProgress() {
        guard let url = fileURL(progressFileName) else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            progresses = try JSONDecoder().decode([PlanProgress].self, from: data)
        } catch {
            logger.error("Failed to load progress: \(error.localizedDescription)")
        }
    }

    private func persistProgress() {
        guard let url = fileURL(progressFileName) else { return }
        do {
            let data = try JSONEncoder().encode(progresses)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            logger.error("Failed to save progress: \(error.localizedDescription)")
        }
    }

    private func fileURL(_ name: String) -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.error("Failed to get App Group container URL")
            return nil
        }
        return container.appendingPathComponent(name)
    }

    // MARK: - Built-in Plans

    private func seedBuiltInPlansIfNeeded() {
        guard !plans.contains(where: { $0.isBuiltIn }) else { return }
        plans.append(contentsOf: BuiltInPlans.all)
        persistPlans()
    }
}
