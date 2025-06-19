import SwiftUI

struct ProgramEditorView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var program: TrainingProgram
    @State private var newIntervalType = IntervalType.walk
    @State private var newIntervalDuration: Double = 60
    
    init(program: TrainingProgram?) {
        _program = State(initialValue: program ?? TrainingProgram(
            name: "",
            intervals: [],
            maxPulse: 180
        ))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Program Details") {
                    TextField("Program Name", text: $program.name)
                        .textFieldStyle(.roundedBorder)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maximum Heart Rate")
                            .font(.headline)
                        
                        HStack {
                            Slider(value: Binding(
                                get: { Double(program.maxPulse) },
                                set: { program.maxPulse = Int($0) }
                            ), in: 100...220, step: 1) {
                                Text("Max HR")
                            }
                            
                            Text("\(program.maxPulse) bpm")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                
                Section {
                    ForEach(program.intervals.indices, id: \.self) { index in
                        IntervalRowView(
                            interval: program.intervals[index],
                            intervalNumber: index + 1
                        )
                    }
                    .onDelete(perform: deleteInterval)
                    .onMove(perform: moveInterval)
                    
                    AddIntervalView(
                        intervalType: $newIntervalType,
                        duration: $newIntervalDuration,
                        onAdd: addInterval
                    )
                } header: {
                    HStack {
                        Text("Intervals (\(program.intervals.count))")
                        Spacer()
                        if !program.intervals.isEmpty {
                            Text("Total: \(program.formattedTotalDuration)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !program.intervals.isEmpty {
                    Section("Preview") {
                        IntervalPreviewView(intervals: program.intervals)
                    }
                }
            }
            .navigationTitle(program.name.isEmpty ? "New Program" : program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
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
    
    private func addInterval() {
        let interval = TrainingInterval(
            type: newIntervalType,
            duration: newIntervalDuration,
            targetPace: nil
        )
        program.intervals.append(interval)
        
        // Reset to defaults for next interval
        newIntervalType = .walk
        newIntervalDuration = 60
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
        dismiss()
    }
}

struct IntervalRowView: View {
    let interval: TrainingInterval
    let intervalNumber: Int
    
    var body: some View {
        HStack {
            // Interval number and type icon
            HStack(spacing: 8) {
                Text("\(intervalNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                Image(systemName: interval.type.systemImageName)
                    .foregroundColor(colorForType(interval.type))
                    .frame(width: 20)
                
                Text(interval.type.rawValue)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Duration
            Text(interval.formattedDuration)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func colorForType(_ type: IntervalType) -> Color {
        switch type {
        case .walk:
            return .blue
        case .run:
            return .red
        case .rest:
            return .gray
        }
    }
}

struct AddIntervalView: View {
    @Binding var intervalType: IntervalType
    @Binding var duration: Double
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Add Interval")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Type picker
                Picker("Type", selection: $intervalType) {
                    ForEach(IntervalType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.systemImageName)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                
                // Duration picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration: \(formatDuration(duration))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("30s") { duration = 30 }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        
                        Button("1m") { duration = 60 }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        
                        Button("2m") { duration = 120 }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        
                        Button("5m") { duration = 300 }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        
                        Spacer()
                    }
                    
                    Slider(value: $duration, in: 10...600, step: 10) {
                        Text("Duration")
                    }
                }
                
                Button("Add Interval", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

struct IntervalPreviewView: View {
    let intervals: [TrainingInterval]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(intervals.indices, id: \.self) { index in
                    Rectangle()
                        .fill(colorForType(intervals[index].type))
                        .frame(width: max(4, CGFloat(intervals[index].duration / 60) * 2), height: 20)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Walk: \(intervals.filter { $0.type == .walk }.count)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("Run: \(intervals.filter { $0.type == .run }.count)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total: \(formatTotalDuration())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(intervals.count) intervals")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func colorForType(_ type: IntervalType) -> Color {
        switch type {
        case .walk:
            return .blue
        case .run:
            return .red
        case .rest:
            return .gray
        }
    }
    
    private func formatTotalDuration() -> String {
        let totalSeconds = intervals.reduce(0) { $0 + $1.duration }
        let minutes = Int(totalSeconds / 60)
        return "\(minutes) min"
    }
}

#Preview {
    ProgramEditorView(program: nil)
        .environmentObject(DataManager())
}
