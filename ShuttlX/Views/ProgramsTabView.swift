import SwiftUI

struct ProgramsTabView: View {
    @EnvironmentObject var planManager: PlanManager
    @EnvironmentObject var templateManager: TemplateManager

    var body: some View {
        NavigationStack {
            List {
                // Active plan
                if let active = planManager.activePlan() {
                    Section {
                        activePlanRow(plan: active.plan, progress: active.progress)
                    } header: {
                        Text("Active Plan")
                    }
                }

                // Training Plans
                Section {
                    NavigationLink {
                        PlanListView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Training Plans")
                                    .font(.headline)
                                Text("\(planManager.plans.count) plan\(planManager.plans.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.green)
                        }
                    }
                    .accessibilityLabel("Training Plans, \(planManager.plans.count) plans")
                    .accessibilityHint("View and manage training plans")
                }

                // Interval Workouts
                Section {
                    NavigationLink {
                        TemplateListView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Interval Workouts")
                                    .font(.headline)
                                Text("\(templateManager.templates.count) workout\(templateManager.templates.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "timer")
                                .foregroundStyle(.orange)
                        }
                    }
                    .accessibilityLabel("Interval Workouts, \(templateManager.templates.count) workouts")
                    .accessibilityHint("View and manage interval workout templates")
                }
            }
            .navigationTitle("Programs")
        }
    }

    private func activePlanRow(plan: TrainingPlan, progress: PlanProgress) -> some View {
        NavigationLink {
            PlanDetailView(plan: plan)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let sport = plan.sportType {
                        Image(systemName: sport.systemImage)
                            .foregroundStyle(sport.themeColor)
                    }
                    Text(plan.name)
                        .font(.headline)
                }

                // Progress bar
                let pct = planManager.completionPercentage(for: progress)
                ProgressView(value: pct)
                    .tint(.green)

                HStack {
                    Text("\(Int(pct * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let next = planManager.nextWorkout(for: progress) {
                        Text("Week \(next.week), Day \(next.day)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.name), \(Int(planManager.completionPercentage(for: progress) * 100)) percent complete")
    }
}

#Preview {
    ProgramsTabView()
        .environmentObject(PlanManager())
        .environmentObject(TemplateManager())
}
