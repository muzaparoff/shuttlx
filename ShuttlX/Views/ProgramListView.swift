import SwiftUI

struct ProgramListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditor = false
    @State private var selectedProgram: TrainingProgram?
    
    var body: some View {
        NavigationView {
            Group {
                if dataManager.programs.isEmpty {
                    EmptyProgramsView {
                        selectedProgram = nil
                        showingEditor = true
                    }
                } else {
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
                }
            }
            .navigationTitle("Training Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        selectedProgram = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                ProgramEditorView(program: selectedProgram)
            }
            .refreshable {
                dataManager.loadFromCloudKit()
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(program.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(program.formattedTotalDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(program.intervalCount)", systemImage: "timer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("\(program.maxPulse) bpm", systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Interval preview
            HStack(spacing: 2) {
                ForEach(program.intervals.prefix(8)) { interval in
                    Rectangle()
                        .fill(interval.type == .run ? Color.red : interval.type == .walk ? Color.blue : Color.gray)
                        .frame(width: 4, height: 12)
                }
                
                if program.intervals.count > 8 {
                    Text("...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct EmptyProgramsView: View {
    let onCreateProgram: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Training Programs")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first walk-run training program to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Create Program", action: onCreateProgram)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// Extension for TrainingProgram to add formatting
extension TrainingProgram {
    var formattedTotalDuration: String {
        let minutes = Int(totalDuration / 60)
        return "\(minutes) min"
    }
}

#Preview {
    NavigationView {
        ProgramListView()
    }
    .environmentObject(DataManager())
}
