import SwiftUI

struct ProgramListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditor = false
    @State private var selectedProgram: TrainingProgram?
    @State private var showingDebugView = false
    @State private var isCreatingNewProgram = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Banner removed - HealthKit permissions handled at first launch
                
                List {
                    ForEach(dataManager.programs) { program in
                        ProgramRowView(program: program)
                            .onTapGesture {
                                selectedProgram = program
                                isCreatingNewProgram = false
                                showingEditor = true
                            }
                    }
                    .onDelete(perform: deletePrograms)
                }
                .listStyle(InsetGroupedListStyle())
                .overlay(
                    Group {
                        if dataManager.programs.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("No Training Programs")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text("Create your first training program to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Button(action: {
                                    selectedProgram = nil
                                    isCreatingNewProgram = true
                                    showingEditor = true
                                }) {
                                    Label("Create Program", systemImage: "plus")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                )
            }
            .navigationTitle("Training Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingDebugView = true
                    }) {
                        Image(systemName: "ladybug")
                            .foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedProgram = nil
                        isCreatingNewProgram = true
                        showingEditor = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                if isCreatingNewProgram {
                    ProgramEditorView(program: nil)
                } else {
                    ProgramEditorView(program: selectedProgram)
                }
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
