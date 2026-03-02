import SwiftUI

struct TemplateListView: View {
    @EnvironmentObject var templateManager: TemplateManager
    @State private var showingEditor = false
    @State private var editingTemplate: WorkoutTemplate?

    var body: some View {
        NavigationStack {
            Group {
                if templateManager.templates.isEmpty {
                    emptyState
                } else {
                    templateList
                }
            }
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

    // MARK: - Template List

    private var templateList: some View {
        List {
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(ShuttlXFont.heroIcon)
                .foregroundStyle(.secondary)

            Text("No Programs Yet")
                .font(.title3.weight(.semibold))

            Text("Create interval workouts to run on your Apple Watch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: { showingEditor = true }) {
                Label("Create Program", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ShuttlXColor.ctaPrimary, in: Capsule())
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helpers

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
}
