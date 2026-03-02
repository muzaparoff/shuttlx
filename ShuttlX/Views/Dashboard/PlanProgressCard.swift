import SwiftUI

struct PlanProgressCard: View {
    let plan: TrainingPlan
    let progress: PlanProgress
    let completion: Double
    let nextWorkout: (week: Int, day: Int, templateName: String?)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let sport = plan.sportType {
                    Image(systemName: sport.systemImage)
                        .foregroundStyle(sport.themeColor)
                }
                Text(plan.name)
                    .font(ShuttlXFont.cardTitle)
                Spacer()
                Text("\(Int(completion * 100))%")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(ShuttlXColor.ctaPrimary)
            }

            ProgressView(value: completion)
                .tint(ShuttlXColor.ctaPrimary)

            if let next = nextWorkout {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(ShuttlXColor.ctaPrimary)
                    Text("Next: \(next.templateName ?? "Workout")")
                        .font(.caption)
                    Spacer()
                    Text("Week \(next.week), Day \(next.day)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(ShuttlXColor.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.name), \(Int(completion * 100)) percent complete")
    }
}

#Preview {
    PlanProgressCard(
        plan: TrainingPlan(
            name: "Couch to 5K",
            sportType: .running,
            weeks: [
                PlanWeek(weekNumber: 1, days: [
                    PlanDay(dayNumber: 1, templateName: "Easy Run"),
                    PlanDay(dayNumber: 2),
                    PlanDay(dayNumber: 3, templateName: "Walk/Run"),
                ])
            ]
        ),
        progress: PlanProgress(planID: UUID()),
        completion: 0.35,
        nextWorkout: (week: 1, day: 3, templateName: "Walk/Run")
    )
    .padding()
}
