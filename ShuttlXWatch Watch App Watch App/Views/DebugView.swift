import SwiftUI

struct DebugView: View {
    // @ObservedObject var sharedDataManager = SharedDataManager.shared
    @State private var programs: [TrainingProgram] = []
    @State private var sessions: [TrainingSession] = []

    var body: some View {
        VStack {
            Text("Debug Info")
                .font(.headline)
                .padding()

            Button("Test App Group") {
                testAppGroupAccess()
            }
            .padding()

            List {
                Section(header: Text("App Status")) {
                    Text("App Group: group.com.shuttlx.shared")
                    Text("Programs: \(programs.count)")
                    Text("Sessions: \(sessions.count)")
                }

                Section(header: Text("Training Programs")) {
                    if programs.isEmpty {
                        Text("No programs loaded")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(programs) { program in
                            Text(program.name)
                        }
                    }
                }
                
                Section(header: Text("Sync Status")) {
                    Text("SharedDataManager temporarily disabled")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear(perform: loadTestData)
    }

    private func loadTestData() {
        // Temporarily disabled complex initialization
        programs = []
        sessions = []
    }
    
    private func testAppGroupAccess() {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared") {
            print("✅ App Group container accessible: \(container)")
        } else {
            print("❌ App Group container not accessible")
        }
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
