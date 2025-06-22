import SwiftUI

struct ProgramListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditor = false
    @State private var selectedProgram: TrainingProgram?
    @State private var showingDebugView = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.programs) { program in
                    ProgramRowView(program: program)
                        .onTapGesture {
                            selectedProgram = program
                            showingEditor = true
                        }
                }
                .onDelete(perform: deletePrograms)
            }
            .navigationTitle("Training Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingDebugView = true
                    }) {
                        Image(systemName: "ladybug")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Test Program") {
                        let newProgram = TrainingProgram(
                            name: "Test Program \(Int.random(in: 1...100))",
                            type: .beepTest,
                            intervals: [
                                TrainingInterval(phase: .work, duration: 10),
                                TrainingInterval(phase: .rest, duration: 5)
                            ]
                        )
                        dataManager.addProgram(newProgram)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                ProgramEditorView(program: selectedProgram)
            }
            .sheet(isPresented: $showingDebugView) {
                DebugView()
            }
        }
    }
    
    private func deletePrograms(offsets: IndexSet) {
        for index in offsets {
            dataManager.deleteProgram(dataManager.programs[index])
        }
    }
}

struct ProgramRowView: View {
    let program: TrainingProgram
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(program.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(program.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            HStack {
                Label("\(program.intervals.count) intervals", systemImage: "list.number")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(formatDuration(program.totalDuration), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Mini interval visualization
            HStack(spacing: 2) {
                ForEach(Array(program.intervals.prefix(10).enumerated()), id: \.offset) { _, interval in
                    Rectangle()
                        .fill(interval.phase == .work ? Color.red : Color.blue)
                        .frame(width: 4, height: 8)
                }
                
                if program.intervals.count > 10 {
                    Text("...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(Int(seconds))s"
        }
    }
}

#Preview {
    ProgramListView()
        .environmentObject(DataManager())
}
