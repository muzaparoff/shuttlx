import SwiftUI

struct ProgramListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditor = false
    @State private var selectedProgram: TrainingProgram?
    @State private var showingDebugView = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Banner removed - HealthKit permissions handled at first launch
                
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
                            type: .walkRun,
                            intervals: [
                                TrainingInterval(phase: .work, duration: 10, intensity: .moderate),
                                TrainingInterval(phase: .rest, duration: 5, intensity: .low)
                            ],
                            maxPulse: 180,
                            createdDate: Date(),
                            lastModified: Date()
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

#Preview {
    ProgramListView()
        .environmentObject(DataManager())
}
