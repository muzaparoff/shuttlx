import SwiftUI

struct TemplateListView: View {
    @EnvironmentObject var templateManager: TemplateManager
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditor = false
    @State private var editingTemplate: WorkoutTemplate?

    /// Most recent session with no templateID (i.e. a free run)
    private var lastFreeRunSession: TrainingSession? {
        dataManager.sessions
            .filter { $0.templateID == nil }
            .max(by: { $0.startDate < $1.startDate })
    }

    var body: some View {
        NavigationStack {
            templateList
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingEditor = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create new program")
                }
            }
            .sheet(isPresented: $showingEditor) {
                TemplateEditorView { template in
                    templateManager.save(template)
                }
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorView(template: template) { updated in
                    templateManager.save(updated)
                }
            }
        }
    }

    // MARK: - Free Run Card

    private var freeRunCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .foregroundStyle(ShuttlXColor.running)
                    .frame(width: 20)
                Text("Free Run")
                    .font(.headline)
            }

            HStack(spacing: 12) {
                Text("Auto-detects run & walk")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let last = lastFreeRunSession {
                let minutes = Int(last.duration / 60)
                Text("Last: \(minutes)m · \(relativeDate(last.startDate))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Free Run, auto-detects run and walk")
    }

    // MARK: - Template List

    private var templateList: some View {
        List {
            // Section 1: Free Run (non-deletable)
            Section {
                if let session = lastFreeRunSession {
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        freeRunCard
                    }
                } else {
                    freeRunCard
                }
            }

            // Section 2: User-created interval templates (deletable)
            Section {
                ForEach(templateManager.templates) { template in
                    templateRow(template)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingTemplate = template
                        }
                }
                .onDelete { offsets in
                    templateManager.deleteAt(offsets: offsets)
                }
            } header: {
                if !templateManager.templates.isEmpty {
                    Text("Interval Workouts")
                }
            } footer: {
                if templateManager.templates.isEmpty {
                    Text("Tap + to create an interval workout")
                }
            }
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: template.sportType?.systemImage ?? "figure.run")
                    .foregroundStyle(template.sportType?.themeColor ?? ShuttlXColor.running)
                    .frame(width: 20)
                Text(template.name)
                    .font(.headline)
            }

            HStack(spacing: 12) {
                Text(template.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if template.warmup != nil {
                    Text("Warm Up")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ShuttlXColor.stepWarmup.opacity(0.15), in: Capsule())
                        .foregroundStyle(ShuttlXColor.stepWarmup)
                }

                if template.cooldown != nil {
                    Text("Cool Down")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ShuttlXColor.stepCooldown.opacity(0.15), in: Capsule())
                        .foregroundStyle(ShuttlXColor.stepCooldown)
                }
            }

            // Step preview
            HStack(spacing: 4) {
                ForEach(template.intervals) { step in
                    stepBadge(step)
                }
                if template.repeatCount > 1 {
                    Text("\u{00D7}\(template.repeatCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.name), \(template.summaryText)")
    }

    private func stepBadge(_ step: IntervalStep) -> some View {
        Text(formatStepDuration(step.duration))
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(ShuttlXColor.forStepType(step.type).opacity(0.15), in: Capsule())
            .foregroundStyle(ShuttlXColor.forStepType(step.type))
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func formatStepDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if remainingSeconds == 0 {
            return "\(minutes)m"
        }
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}

#Preview {
    TemplateListView()
        .environmentObject(TemplateManager())
        .environmentObject(DataManager())
}
