
import SwiftUI

struct DebugView: View {
    @ObservedObject var sharedDataManager = SharedDataManager.shared
    @State private var programs: [TrainingProgram] = []
    @State private var sessions: [TrainingSession] = []

    var body: some View {
        VStack {
            Text("Debug Info")
                .font(.largeTitle)
                .padding()

            Button("Refresh Data") {
                refreshData()
            }
            .padding()

            List {
                Section(header: Text("Training Programs (App Group)")) {
                    if programs.isEmpty {
                        Text("No programs found.")
                    } else {
                        ForEach(programs) { program in
                            Text(program.name)
                        }
                    }
                }

                Section(header: Text("Training Sessions (App Group)")) {
                    if sessions.isEmpty {
                        Text("No sessions found.")
                    } else {
                        ForEach(sessions) { session in
                            Text("Session at \(session.date, formatter: itemFormatter)")
                        }
                    }
                }
                
                Section(header: Text("Sync Log")) {
                    ForEach(sharedDataManager.syncLog, id: \.self) { log in
                        Text(log)
                    }
                }
            }
        }
        .onAppear(perform: refreshData)
    }

    private func refreshData() {
        programs = sharedDataManager.loadProgramsFromAppGroup()
        sessions = sharedDataManager.loadSessionsFromAppGroup()
    }
    
    private var itemFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView()
    }
}
