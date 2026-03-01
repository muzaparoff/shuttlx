import SwiftUI

struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var intervals: [IntervalStep]
    @State private var repeatCount: Int
    @State private var hasWarmup: Bool
    @State private var warmupDuration: TimeInterval
    @State private var hasCooldown: Bool
    @State private var cooldownDuration: TimeInterval

    private let existingTemplate: WorkoutTemplate?
    private let onSave: (WorkoutTemplate) -> Void

    // Create new
    init(onSave: @escaping (WorkoutTemplate) -> Void) {
        self.existingTemplate = nil
        self.onSave = onSave
        _name = State(initialValue: "")
        _intervals = State(initialValue: [
            IntervalStep(type: .work, duration: 30),
            IntervalStep(type: .rest, duration: 30)
        ])
        _repeatCount = State(initialValue: 4)
        _hasWarmup = State(initialValue: false)
        _warmupDuration = State(initialValue: 300)
        _hasCooldown = State(initialValue: false)
        _cooldownDuration = State(initialValue: 180)
    }

    // Edit existing
    init(template: WorkoutTemplate, onSave: @escaping (WorkoutTemplate) -> Void) {
        self.existingTemplate = template
        self.onSave = onSave
        _name = State(initialValue: template.name)
        _intervals = State(initialValue: template.intervals)
        _repeatCount = State(initialValue: template.repeatCount)
        _hasWarmup = State(initialValue: template.warmup != nil)
        _warmupDuration = State(initialValue: template.warmup?.duration ?? 300)
        _hasCooldown = State(initialValue: template.cooldown != nil)
        _cooldownDuration = State(initialValue: template.cooldown?.duration ?? 180)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !intervals.isEmpty
    }

    private var totalDuration: TimeInterval {
        var total: TimeInterval = 0
        if hasWarmup { total += warmupDuration }
        total += intervals.reduce(0) { $0 + $1.duration } * Double(repeatCount)
        if hasCooldown { total += cooldownDuration }
        return total
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section {
                    TextField("Program Name", text: $name)
                } header: {
                    Text("Name")
                }

                // Warmup
                Section {
                    Toggle("Warm Up", isOn: $hasWarmup.animation())
                    if hasWarmup {
                        DurationPicker(duration: $warmupDuration, label: "Duration")
                    }
                }

                // Intervals
                Section {
                    ForEach($intervals) { $step in
                        IntervalStepRow(step: $step)
                    }
                    .onDelete { offsets in
                        intervals.remove(atOffsets: offsets)
                    }
                    .onMove { from, to in
                        intervals.move(fromOffsets: from, toOffset: to)
                    }

                    Button(action: addInterval) {
                        Label("Add Interval", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Intervals")
                }

                // Repeat
                Section {
                    Stepper("Repeat: \(repeatCount)\u{00D7}", value: $repeatCount, in: 1...50)
                } header: {
                    Text("Repeat Count")
                } footer: {
                    Text("The interval block above will repeat \(repeatCount) time\(repeatCount == 1 ? "" : "s")")
                }

                // Cooldown
                Section {
                    Toggle("Cool Down", isOn: $hasCooldown.animation())
                    if hasCooldown {
                        DurationPicker(duration: $cooldownDuration, label: "Duration")
                    }
                }

                // Summary
                Section {
                    HStack {
                        Text("Total Duration")
                        Spacer()
                        Text(FormattingUtils.formatDuration(totalDuration))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle(existingTemplate == nil ? "New Program" : "Edit Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTemplate() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Actions

    private func addInterval() {
        let lastType = intervals.last?.type ?? .rest
        let newType: IntervalType = lastType == .work ? .rest : .work
        let duration: TimeInterval = newType == .work ? 30 : 30
        intervals.append(IntervalStep(type: newType, duration: duration))
    }

    private func saveTemplate() {
        let template = WorkoutTemplate(
            id: existingTemplate?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            intervals: intervals,
            repeatCount: repeatCount,
            warmup: hasWarmup ? IntervalStep(type: .warmup, duration: warmupDuration) : nil,
            cooldown: hasCooldown ? IntervalStep(type: .cooldown, duration: cooldownDuration) : nil,
            createdDate: existingTemplate?.createdDate ?? Date()
        )
        onSave(template)
        dismiss()
    }
}

// MARK: - Interval Step Row

private struct IntervalStepRow: View {
    @Binding var step: IntervalStep

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Type", selection: $step.type) {
                    Text("Work").tag(IntervalType.work)
                    Text("Rest").tag(IntervalType.rest)
                }
                .pickerStyle(.segmented)
            }

            DurationPicker(duration: $step.duration, label: "Duration")

            TextField("Label (optional)", text: Binding(
                get: { step.label ?? "" },
                set: { step.label = $0.isEmpty ? nil : $0 }
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Duration Picker

private struct DurationPicker: View {
    @Binding var duration: TimeInterval
    let label: String

    private var minutes: Int {
        Int(duration) / 60
    }

    private var seconds: Int {
        Int(duration) % 60
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 2) {
                Picker("Minutes", selection: Binding(
                    get: { minutes },
                    set: { duration = TimeInterval($0 * 60 + seconds) }
                )) {
                    ForEach(0...59, id: \.self) { m in
                        Text("\(m)m").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 100)
                .clipped()

                Picker("Seconds", selection: Binding(
                    get: { seconds },
                    set: { duration = TimeInterval(minutes * 60 + $0) }
                )) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { s in
                        Text("\(s)s").tag(s)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 100)
                .clipped()
            }
        }
    }
}

#Preview {
    TemplateEditorView { template in
        print("Saved: \(template.name)")
    }
}
