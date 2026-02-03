import SwiftUI

struct ProgramListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditor = false
    @State private var selectedProgram: TrainingProgram?
    #if DEBUG
    @State private var showingDebugView = false
    #endif
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
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(program.name), \(program.type.displayName)")
                            .accessibilityValue("\(program.intervals.count) intervals")
                            .accessibilityHint("Double tap to edit this program")
                            .accessibilityAddTraits(.isButton)
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
                                    .foregroundColor(.secondary)
                                    .accessibilityHidden(true)

                                Text("No Training Programs")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .accessibilityAddTraits(.isHeader)

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
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .accessibilityLabel("Create Program")
                                .accessibilityHint("Opens the program editor to create a new training program")
                                .padding(.top, 8)
                            }
                        }
                    }
                )
            }
            .navigationTitle("Training Programs")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingDebugView = true
                    }) {
                        Image(systemName: "ladybug")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Debug")
                    .accessibilityHint("Opens the debug information view")
                }
                #endif
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedProgram = nil
                        isCreatingNewProgram = true
                        showingEditor = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .accessibilityLabel("Create new program")
                    .accessibilityHint("Opens the program editor to create a new training program")
                }
            }
            .sheet(isPresented: $showingEditor) {
                if isCreatingNewProgram {
                    ProgramEditorView(program: nil)
                } else {
                    ProgramEditorView(program: selectedProgram)
                }
            }
            #if DEBUG
            .sheet(isPresented: $showingDebugView) {
                DebugView()
            }
            #endif
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
