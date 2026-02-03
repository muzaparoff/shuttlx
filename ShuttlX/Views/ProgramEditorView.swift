import SwiftUI

struct ProgramEditorView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode

    @State private var program: TrainingProgram
    @State private var newIntervalPhase = IntervalPhase.work
    @State private var newIntervalIntensity = TrainingIntensity.moderate
    @State private var newIntervalDuration: Double = 60

    init(program: TrainingProgram?) {
        if let existingProgram = program {
            _program = State(initialValue: existingProgram)
        } else {
            _program = State(initialValue: TrainingProgram(
                name: "",
                type: .walkRun,
                intervals: [],
                maxPulse: 180,
                createdDate: Date(),
                lastModified: Date()
            ))
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Program Details") {
                    TextField("Program Name", text: $program.name)
                        .accessibilityLabel("Program Name")
                        .accessibilityHint("Enter a name for this training program")

                    Picker("Training Type", selection: $program.type) {
                        ForEach(ProgramType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .accessibilityLabel("Training Type")
                    .accessibilityValue(program.type.displayName)
                    .accessibilityHint("Select the type of training")
                    .onChange(of: program.type) { oldValue, newType in
                        if program.intervals.isEmpty {
                            program.intervals = newType.defaultIntervals
                        }
                    }

                    Stepper("Max Pulse: \(program.maxPulse)", value: $program.maxPulse, in: 100...220)
                        .accessibilityLabel("Maximum Pulse")
                        .accessibilityValue("\(program.maxPulse) beats per minute")
                        .accessibilityHint("Adjust the maximum target heart rate")
                }

                Section(header: Text("Intervals"), footer: Text(program.type.description)) {
                    ForEach(Array(program.intervals.enumerated()), id: \.offset) { index, interval in
                        IntervalRowView(
                            interval: interval,
                            workLabel: program.type.workPhaseLabel,
                            restLabel: program.type.restPhaseLabel
                        )
                    }
                    .onDelete(perform: deleteInterval)
                    .onMove(perform: moveInterval)

                    // Quick Add Buttons - Flexible Interval Builder
                    if program.type == .walkRun {
                        VStack(spacing: 12) {
                            Text("Quick Add")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .accessibilityAddTraits(.isHeader)

                            HStack(spacing: 16) {
                                // Add Work Interval (Run)
                                Button(action: {
                                    addWorkInterval()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "bolt.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                        Text(program.type.workPhaseLabel)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 80, height: 60)
                                    .background(Color.red)
                                    .cornerRadius(12)
                                }
                                .accessibilityLabel("Add \(program.type.workPhaseLabel) interval")
                                .accessibilityHint("Adds a 1 minute work interval")

                                // Add Rest Interval (Walk)
                                Button(action: {
                                    addRestInterval()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "pause.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                        Text(program.type.restPhaseLabel)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 80, height: 60)
                                    .background(Color.accentColor)
                                    .cornerRadius(12)
                                }
                                .accessibilityLabel("Add \(program.type.restPhaseLabel) interval")
                                .accessibilityHint("Adds a 1 minute rest interval")
                            }

                            Text("Tap to add with default duration (1 min). Edit duration after adding.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 8)
                    }

                    // Custom Interval Builder
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Custom Interval")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)

                        HStack {
                            Picker("Phase", selection: $newIntervalPhase) {
                                Text(program.type.workPhaseLabel).tag(IntervalPhase.work)
                                Text(program.type.restPhaseLabel).tag(IntervalPhase.rest)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .accessibilityLabel("Interval Phase")
                            .accessibilityValue(newIntervalPhase == .work ? program.type.workPhaseLabel : program.type.restPhaseLabel)
                        }

                        HStack {
                            Text("Intensity:")
                            Picker("Intensity", selection: $newIntervalIntensity) {
                                ForEach(TrainingIntensity.allCases, id: \.self) { intensity in
                                    Text(intensity.rawValue).tag(intensity)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .accessibilityLabel("Intensity")
                            .accessibilityValue(newIntervalIntensity.rawValue)
                        }

                        HStack {
                            Text("Duration:")
                            Stepper("\(formatDuration(newIntervalDuration))",
                                   value: $newIntervalDuration,
                                   in: 10...3600,
                                   step: 10)
                                .accessibilityLabel("Duration")
                                .accessibilityValue(formatDuration(newIntervalDuration))
                                .accessibilityHint("Adjust interval duration in 10 second increments")
                        }

                        Button("Add Interval") {
                            addCustomInterval()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Adds the custom interval to the program")
                    }
                    .padding(.vertical, 8)
                }

                Section("Program Summary") {
                    HStack {
                        Text("Total Duration")
                        Spacer()
                        Text(formatDuration(program.totalDuration))
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Total Duration")
                    .accessibilityValue(formatDuration(program.totalDuration))

                    HStack {
                        Text("Work Intervals")
                        Spacer()
                        Text("\(program.workIntervals.count)")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Work Intervals")
                    .accessibilityValue("\(program.workIntervals.count)")

                    HStack {
                        Text("Rest Intervals")
                        Spacer()
                        Text("\(program.restIntervals.count)")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Rest Intervals")
                    .accessibilityValue("\(program.restIntervals.count)")
                }
            }
            .navigationTitle(program.name.isEmpty ? "New Program" : program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .accessibilityHint("Discards changes and closes the editor")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProgram()
                    }
                    .disabled(program.name.isEmpty || program.intervals.isEmpty)
                    .accessibilityLabel("Save")
                    .accessibilityHint(program.name.isEmpty ? "Enter a program name first" : program.intervals.isEmpty ? "Add at least one interval first" : "Saves the training program")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func addWorkInterval() {
        let interval = TrainingInterval(
            phase: .work,
            duration: 60, // Default 1 minute, user can edit
            intensity: .moderate
        )
        program.intervals.append(interval)
    }

    private func addRestInterval() {
        let interval = TrainingInterval(
            phase: .rest,
            duration: 60, // Default 1 minute, user can edit
            intensity: .low
        )
        program.intervals.append(interval)
    }

    private func addCustomInterval() {
        let interval = TrainingInterval(
            phase: newIntervalPhase,
            duration: newIntervalDuration,
            intensity: newIntervalIntensity
        )
        program.intervals.append(interval)
    }

    private func deleteInterval(offsets: IndexSet) {
        program.intervals.remove(atOffsets: offsets)
    }

    private func moveInterval(from source: IndexSet, to destination: Int) {
        program.intervals.move(fromOffsets: source, toOffset: destination)
    }

    private func saveProgram() {
        program.lastModified = Date()
        dataManager.saveProgram(program)
        presentationMode.wrappedValue.dismiss()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

struct IntervalRowView: View {
    let interval: TrainingInterval
    let workLabel: String
    let restLabel: String

    var phaseLabel: String {
        interval.phase == .work ? workLabel : restLabel
    }

    var body: some View {
        HStack(spacing: 12) {
            // Phase indicator with icon
            VStack {
                Circle()
                    .fill(interval.phase == .work ? Color.red : Color.accentColor)
                    .frame(width: 12, height: 12)

                Image(systemName: interval.phase.systemImage)
                    .font(.caption2)
                    .foregroundColor(interval.phase == .work ? .red : .accentColor)
            }
            .accessibilityHidden(true)

            // Interval details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(phaseLabel)
                        .font(.headline)
                        .foregroundColor(interval.phase == .work ? .red : .accentColor)

                    Spacer()

                    Text(formatDuration(interval.duration))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Text("\(interval.intensity.rawValue) intensity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Visual duration bar
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(interval.phase == .work ? Color.red.opacity(0.3) : Color.accentColor.opacity(0.3))
                    .frame(width: max(4, min(40, interval.duration / 10)), height: 4)
                Spacer()
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phaseLabel) interval, \(formatDuration(interval.duration)), \(interval.intensity.rawValue) intensity")
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

#Preview {
    ProgramEditorView(program: nil)
        .environmentObject(DataManager())
}
