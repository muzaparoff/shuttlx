import SwiftUI

struct PlanListView: View {
    @EnvironmentObject var planManager: PlanManager
    @State private var showingEditor = false

    var body: some View {
        List {
            // Built-in plans
            if !builtInPlans.isEmpty {
                Section("Built-in Plans") {
                    ForEach(builtInPlans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan)
                        } label: {
                            planRow(plan)
                        }
                    }
                }
            }

            // Custom plans
            if !customPlans.isEmpty {
                Section("My Plans") {
                    ForEach(customPlans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan)
                        } label: {
                            planRow(plan)
                        }
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { customPlans[$0] }
                        toDelete.forEach { planManager.delete($0) }
                    }
                }
            }
        }
        .navigationTitle("Training Plans")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingEditor = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create new training plan")
            }
        }
        .sheet(isPresented: $showingEditor) {
            PlanEditorView { plan in
                planManager.save(plan)
            }
        }
        .themedScreenBackground()
    }

    private var builtInPlans: [TrainingPlan] {
        planManager.plans.filter { $0.isBuiltIn }
    }

    private var customPlans: [TrainingPlan] {
        planManager.plans.filter { !$0.isBuiltIn }
    }

    private func planRow(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: plan.sportType?.systemImage ?? "figure.run")
                    .foregroundStyle(plan.sportType?.themeColor ?? ShuttlXColor.running)
                    .frame(width: 20)
                Text(plan.name)
                    .font(.headline)
            }

            Text(plan.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let desc = plan.planDescription {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Show progress if active
            if let progress = planManager.progresses.first(where: { $0.planID == plan.id && $0.isActive }) {
                let pct = planManager.completionPercentage(for: progress)
                HStack(spacing: 6) {
                    ProgressView(value: pct)
                        .tint(ShuttlXColor.ctaPrimary)
                        .frame(width: 80)
                    Text("\(Int(pct * 100))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ShuttlXColor.positive)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.name), \(plan.summaryText)")
    }
}

#Preview {
    NavigationStack {
        PlanListView()
            .environmentObject(PlanManager())
    }
}
