import SwiftUI
import ShuttlXShared

struct ProgramsTabView: View {
    @EnvironmentObject var planManager: PlanManager
    @EnvironmentObject var templateManager: TemplateManager
    @EnvironmentObject var workoutController: iPhoneWorkoutController
    @ObservedObject var sharedData = PhoneSyncCoordinator.shared

    var body: some View {
        NavigationStack {
            List {
                // Quick Start — all iPhone-launchable workout modes in one place.
                // Hidden while a watch workout is active so users can't double-
                // launch a session on both devices.
                if !sharedData.isWorkoutActiveOnWatch {
                    Section {
                        startRow(
                            title: "Free Run",
                            subtitle: "Open-ended · HR · GPS",
                            systemImage: "figure.run.circle.fill",
                            color: ShuttlXColor.running,
                            action: { workoutController.presentFreeRun() }
                        )
                        startRow(
                            title: "Gym Recovery",
                            subtitle: "HR recovery between sets · cardiac rehab",
                            systemImage: "heart.circle.fill",
                            color: ShuttlXColor.heartRate,
                            action: { workoutController.presentGymRecovery() }
                        )
                    } header: {
                        Text("Quick Start")
                    }
                }

                // All interval templates as one-tap-to-start rows. Long-press
                // gives Edit / Delete via context menu; "Manage Workouts" link
                // below opens the full editor list.
                if !templateManager.templates.isEmpty && !sharedData.isWorkoutActiveOnWatch {
                    Section {
                        ForEach(templateManager.templates) { template in
                            templateStartRow(template)
                        }
                    } header: {
                        Text("Interval Programs")
                    }
                }

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
                                    .font(ShuttlXFont.cardTitle)
                                Text("\(planManager.plans.count) plan\(planManager.plans.count == 1 ? "" : "s")")
                                    .font(ShuttlXFont.cardCaption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(ShuttlXColor.ctaPrimary)
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
                                    .font(ShuttlXFont.cardTitle)
                                Text("\(templateManager.templates.count) workout\(templateManager.templates.count == 1 ? "" : "s")")
                                    .font(ShuttlXFont.cardCaption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "timer")
                                .foregroundStyle(ShuttlXColor.walking)
                        }
                    }
                    .accessibilityLabel("Interval Workouts, \(templateManager.templates.count) workouts")
                    .accessibilityHint("View and manage interval workout templates")
                }
            }
            .scrollContentBackground(.hidden)
            .themedScreenBackground()
            .navigationTitle("Programs")
        }
    }

    private func startRow(title: String, subtitle: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ShuttlXFont.cardTitle)
                        .foregroundStyle(ShuttlXColor.textPrimary)
                    Text(subtitle)
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(color)
            }
            .padding(.vertical, 4)
        }
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Starts the workout on your iPhone")
    }

    private func templateStartRow(_ template: WorkoutTemplate) -> some View {
        let sportColor = template.sportType?.themeColor ?? ShuttlXColor.running
        return Button {
            workoutController.presentInterval(template: template)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: template.sportType?.systemImage ?? "flame.fill")
                    .font(.title2)
                    .foregroundStyle(sportColor)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(ShuttlXFont.cardTitle)
                        .foregroundStyle(ShuttlXColor.textPrimary)
                    Text(template.summaryText)
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(sportColor)
            }
            .padding(.vertical, 4)
        }
        .accessibilityLabel("Start \(template.name)")
        .accessibilityHint(template.summaryText)
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
                        .font(ShuttlXFont.cardTitle)
                }

                // Progress bar
                let pct = planManager.completionPercentage(for: progress)
                ProgressView(value: pct)
                    .tint(ShuttlXColor.ctaPrimary)

                HStack {
                    Text("\(Int(pct * 100))% complete")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let next = planManager.nextWorkout(for: progress) {
                        Text("Week \(next.week), Day \(next.day)")
                            .font(ShuttlXFont.cardCaption)
                            .foregroundStyle(ShuttlXColor.ctaPrimary)
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
