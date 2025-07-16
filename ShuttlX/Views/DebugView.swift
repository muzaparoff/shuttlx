import SwiftUI

struct DebugView: View {
    @ObservedObject var sharedDataManager = SharedDataManager.shared
    @EnvironmentObject var dataManager: DataManager
    @State private var programs: [TrainingProgram] = []
    @State private var sessions: [TrainingSession] = []
    @State private var showingCleanupAlert = false
    @State private var cleanupMessage = ""
    @State private var showMessage = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Maintenance Actions")) {
                        Button(action: {
                            showingCleanupAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("Clear All Training Sessions")
                                    .foregroundColor(.red)
                            }
                        }
                        .alert(isPresented: $showingCleanupAlert) {
                            Alert(
                                title: Text("Clear All Sessions"),
                                message: Text("This will delete all saved training sessions. This action cannot be undone."),
                                primaryButton: .destructive(Text("Clear All")) {
                                    // Clear all sessions
                                    sharedDataManager.purgeAllSessionsFromStorage()
                                    cleanupMessage = "All sessions cleared!"
                                    showMessage = true
                                    
                                    // Force DataManager to reload
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        dataManager.sessions = []
                                        refreshData()
                                    }
                                },
                                secondaryButton: .cancel()
                            )
                        }
                        
                        Button(action: {
                            sharedDataManager.forceSyncNow()
                            cleanupMessage = "Force sync triggered!"
                            showMessage = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.blue)
                                Text("Force Sync Now")
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Section(header: Text("Training Programs (App Group)")) {
                        if programs.isEmpty {
                            Text("No programs found.")
                        } else {
                            ForEach(programs) { program in
                                Text(program.name)
                            }
                        }
                    }

                    Section {
                        if sessions.isEmpty {
                            Text("No sessions found.")
                        } else {
                            ForEach(sessions) { session in
                                Text("Session at \(session.startDate, formatter: itemFormatter)")
                            }
                        }
                    } header: {
                        Text("Training Sessions (App Group)")
                    }
                    
                    Section(header: Text("Sync Status")) {
                        Text(sharedDataManager.checkConnectivity())
                            .font(.system(.footnote, design: .monospaced))
                    }
                    
                    Section(header: Text("Sync Log")) {
                        ForEach(sharedDataManager.syncLog, id: \.self) { log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
                .refreshable {
                    refreshData()
                }
            }
            .navigationTitle("Debug Panel")
            .toolbar {
                Button("Refresh") {
                    refreshData()
                }
            }
            .overlay(
                Group {
                    if showMessage {
                        Text(cleanupMessage)
                            .padding()
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 3)
                            .transition(.move(edge: .top))
                            .onAppear {
                                // Hide message after a few seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showMessage = false
                                }
                            }
                    }
                }
            )
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SessionStorageStatus"))) { notification in
                if let status = notification.userInfo?["status"] as? String, status == "purged" {
                    cleanupMessage = "All sessions successfully purged!"
                    showMessage = true
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
