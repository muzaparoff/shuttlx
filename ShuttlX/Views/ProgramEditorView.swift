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
                    
                    Picker("Training Type", selection: $program.type) {
                        ForEach(ProgramType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: program.type) { oldValue, newType in
                        if program.intervals.isEmpty {
                            program.intervals = newType.defaultIntervals
                        }
                    }
                    
                    Stepper("Max Pulse: \(program.maxPulse)", value: $program.maxPulse, in: 100...220)
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
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
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
                        
                        HStack {
                            Picker("Phase", selection: $newIntervalPhase) {
                                Text(program.type.workPhaseLabel).tag(IntervalPhase.work)
                                Text(program.type.restPhaseLabel).tag(IntervalPhase.rest)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        HStack {
                            Text("Intensity:")
                            Picker("Intensity", selection: $newIntervalIntensity) {
                                ForEach(TrainingIntensity.allCases, id: \.self) { intensity in
                                    Text(intensity.rawValue).tag(intensity)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        HStack {
                            Text("Duration:")
                            Stepper("\(formatDuration(newIntervalDuration))", 
                                   value: $newIntervalDuration, 
                                   in: 10...3600, 
                                   step: 10)
                        }
                        
                        Button("Add Interval") {
                            addCustomInterval()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
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
                    
                    HStack {
                        Text("Work Intervals")
                        Spacer()
                        Text("\(program.workIntervals.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Rest Intervals")
                        Spacer()
                        Text("\(program.restIntervals.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(program.name.isEmpty ? "New Program" : program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProgram()
                    }
                    .disabled(program.name.isEmpty || program.intervals.isEmpty)
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
                    .fill(interval.phase == .work ? Color.red : Color.blue)
                    .frame(width: 12, height: 12)
                
                Image(systemName: interval.phase.systemImage)
                    .font(.caption2)
                    .foregroundColor(interval.phase == .work ? .red : .blue)
            }
            
            // Interval details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(phaseLabel)
                        .font(.headline)
                        .foregroundColor(interval.phase == .work ? .red : .blue)
                    
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
                    .fill(interval.phase == .work ? Color.red.opacity(0.3) : Color.blue.opacity(0.3))
                    .frame(width: max(4, min(40, interval.duration / 10)), height: 4)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
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
