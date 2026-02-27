import SwiftUI

#if DEBUG
struct DebugView: View {
    @ObservedObject var sharedDataManager = SharedDataManager.shared
    @EnvironmentObject var dataManager: DataManager
    @State private var sessions: [TrainingSession] = []
    @State private var showingCleanupAlert = false
    @State private var cleanupMessage = ""
    @State private var showMessage = false

    var body: some View {
        NavigationStack {
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
                        .alert("Clear All Sessions", isPresented: $showingCleanupAlert) {
                            Button("Clear All", role: .destructive) {
                                sharedDataManager.purgeAllSessionsFromStorage()
                                cleanupMessage = "All sessions cleared!"
                                showMessage = true

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    dataManager.sessions = []
                                    refreshData()
                                }
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                            Text("This will delete all saved training sessions. This action cannot be undone.")
                        }
                    }

                    Section {
                        if sessions.isEmpty {
                            Text("No sessions found.")
                        } else {
                            ForEach(sessions) { session in
                                VStack(alignment: .leading) {
                                    Text("Session at \(session.startDate, formatter: itemFormatter)")
                                    if !session.segments.isEmpty {
                                        Text("\(session.segments.count) segments")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
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
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 3)
                            .transition(.move(edge: .top))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showMessage = false
                                }
                            }
                    }
                }
            )
        }
        .onAppear(perform: refreshData)
    }

    private func refreshData() {
        sessions = sharedDataManager.loadSessionsFromAppGroup()
    }

    private var itemFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }
}

#Preview {
    DebugView()
}
#endif
