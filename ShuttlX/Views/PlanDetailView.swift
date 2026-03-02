import SwiftUI

struct PlanDetailView: View {
    let plan: TrainingPlan
    @EnvironmentObject var planManager: PlanManager

    private var activeProgress: PlanProgress? {
        planManager.progresses.first(where: { $0.planID == plan.id && $0.isActive })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                planHeader

                // Start / Continue button
                actionButton

                // Weeks
                ForEach(plan.weeks.sorted(by: { $0.weekNumber < $1.weekNumber })) { week in
                    weekCard(week)
                }
            }
            .padding()
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var planHeader: some View {
        VStack(spacing: 8) {
            if let sport = plan.sportType {
                Image(systemName: sport.systemImage)
                    .font(.title)
                    .foregroundStyle(sport.themeColor)
            }

            Text(plan.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let desc = plan.planDescription {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let progress = activeProgress {
                let pct = planManager.completionPercentage(for: progress)
                VStack(spacing: 4) {
                    ProgressView(value: pct)
                        .tint(ShuttlXColor.ctaPrimary)
                    Text("\(Int(pct * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
                .accessibilityLabel("\(Int(pct * 100)) percent complete")
            }
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: {
            planManager.startPlan(plan)
        }) {
            Text(activeProgress != nil ? "Restart Plan" : "Start Plan")
        }
        .buttonStyle(ShuttlXPrimaryCTAStyle(maxWidth: .infinity))
        .accessibilityLabel(activeProgress != nil ? "Restart plan" : "Start plan")
        .accessibilityHint("Begins tracking your progress through this training plan")
    }

    // MARK: - Week Card

    private func weekCard(_ week: PlanWeek) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Week \(week.weekNumber)")
                    .font(.headline)
                if let label = week.label {
                    Text("· \(label)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ForEach(week.days.sorted(by: { $0.dayNumber < $1.dayNumber })) { day in
                dayRow(day, weekNumber: week.weekNumber)
            }
        }
        .padding()
        .background(ShuttlXColor.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func dayRow(_ day: PlanDay, weekNumber: Int) -> some View {
        let isCompleted = activeProgress?.completedDays.contains(where: {
            $0.weekNumber == weekNumber && $0.dayNumber == day.dayNumber
        }) ?? false

        return HStack(spacing: 10) {
            // Day label
            Text(dayOfWeekLabel(day.dayNumber))
                .font(.caption.weight(.semibold))
                .frame(width: 30)
                .foregroundStyle(.secondary)

            if day.isRestDay {
                Text("Rest Day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text(day.templateName ?? "Workout")
                    .font(.subheadline)
                    .lineLimit(1)
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ShuttlXColor.positive)
                    .accessibilityLabel("Completed")
            } else if !day.isRestDay {
                // Mark complete button
                Button(action: {
                    if let progress = activeProgress {
                        planManager.markDayCompleted(progressID: progress.id, weekNumber: weekNumber, dayNumber: day.dayNumber)
                    }
                }) {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(activeProgress == nil)
                .accessibilityLabel("Mark as completed")
                .accessibilityHint("Marks this workout day as done")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func dayOfWeekLabel(_ dayNumber: Int) -> String {
        switch dayNumber {
        case 1: return "Mon"
        case 2: return "Tue"
        case 3: return "Wed"
        case 4: return "Thu"
        case 5: return "Fri"
        case 6: return "Sat"
        case 7: return "Sun"
        default: return "D\(dayNumber)"
        }
    }
}

#Preview {
    NavigationStack {
        PlanDetailView(plan: TrainingPlan(
            name: "Couch to 5K",
            planDescription: "A beginner running plan to build endurance over 8 weeks.",
            sportType: .running,
            weeks: [
                PlanWeek(weekNumber: 1, days: [
                    PlanDay(dayNumber: 1, templateName: "Easy Run"),
                    PlanDay(dayNumber: 2),
                    PlanDay(dayNumber: 3, templateName: "Walk/Run"),
                    PlanDay(dayNumber: 4),
                    PlanDay(dayNumber: 5, templateName: "Easy Run"),
                    PlanDay(dayNumber: 6),
                    PlanDay(dayNumber: 7),
                ], label: "Foundation")
            ]
        ))
        .environmentObject(PlanManager())
    }
}
