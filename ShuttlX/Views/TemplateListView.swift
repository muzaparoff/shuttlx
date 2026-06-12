import SwiftUI

struct TemplateListView: View {
    @EnvironmentObject var templateManager: TemplateManager
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var workoutController: iPhoneWorkoutController
    @State private var showingEditor = false
    @State private var editingTemplate: WorkoutTemplate?

    /// Most recent session with no templateID (i.e. a free run)
    private var lastFreeRunSession: TrainingSession? {
        dataManager.sessions
            .filter { $0.templateID == nil && $0.sessionMode != .gymRecovery }
            .max(by: { $0.startDate < $1.startDate })
    }

    /// Most recent gym recovery session
    private var lastGymRecoverySession: TrainingSession? {
        dataManager.sessions
            .filter { $0.sessionMode == .gymRecovery }
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
            .themedScreenBackground()
        }
    }

    // MARK: - Gym Recovery Card

    private var gymRecoveryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .foregroundStyle(ShuttlXColor.heartRate)
                    .frame(width: 20)
                Text("Gym Recovery")
                    .font(ShuttlXFont.cardTitle)
            }

            Text("HR recovery monitoring between sets")
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(.secondary)

            if let last = lastGymRecoverySession {
                let minutes = Int(last.duration / 60)
                let sets = last.recoveryReport?.sets ?? 0
                Text("Last: \(minutes)m · \(sets) sets · \(relativeDate(last.startDate))")
                    .font(ShuttlXFont.cardCaption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("Start on your Apple Watch")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gym Recovery, heart rate recovery monitoring between sets")
    }

    // MARK: - Free Run Card

    private var freeRunCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .foregroundStyle(ShuttlXColor.running)
                    .frame(width: 20)
                Text("Free Run")
                    .font(ShuttlXFont.cardTitle)
            }

            HStack(spacing: 12) {
                Text("Auto-detects run & walk")
                    .font(ShuttlXFont.cardSubtitle)
                    .foregroundStyle(.secondary)
            }

            if let last = lastFreeRunSession {
                let minutes = Int(last.duration / 60)
                Text("Last: \(minutes)m · \(relativeDate(last.startDate))")
                    .font(ShuttlXFont.cardCaption)
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

            // Section 2: Gym Recovery (non-deletable)
            Section {
                if let session = lastGymRecoverySession {
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        gymRecoveryCard
                    }
                } else {
                    gymRecoveryCard
                }
            }

            // Section 3: User-created interval templates (deletable)
            Section {
                ForEach(templateManager.templates) { template in
                    templateRow(template)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Tap = start the workout on iPhone. Edit moved to the
                            // long-press context menu so the most-common action
                            // (start) is one tap.
                            workoutController.presentInterval(template: template)
                        }
                        .contextMenu {
                            Button {
                                editingTemplate = template
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                if let idx = templateManager.templates.firstIndex(where: { $0.id == template.id }) {
                                    templateManager.deleteAt(offsets: IndexSet(integer: idx))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
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
        .scrollContentBackground(.hidden)
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: template.sportType?.systemImage ?? "figure.run")
                    .foregroundStyle(template.sportType?.themeColor ?? ShuttlXColor.running)
                    .frame(width: 20)
                Text(template.name)
                    .font(ShuttlXFont.cardTitle)
            }

            HStack(spacing: 12) {
                Text(template.summaryText)
                    .font(ShuttlXFont.cardSubtitle)
                    .foregroundStyle(.secondary)

                if template.warmup != nil {
                    Text("Warm Up")
                        .font(ShuttlXFont.cardCaption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ShuttlXColor.stepWarmup.opacity(0.15), in: Capsule())
                        .foregroundStyle(ShuttlXColor.stepWarmup)
                }

                if template.cooldown != nil {
                    Text("Cool Down")
                        .font(ShuttlXFont.cardCaption)
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
                        .font(ShuttlXFont.cardCaption.weight(.bold))
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
