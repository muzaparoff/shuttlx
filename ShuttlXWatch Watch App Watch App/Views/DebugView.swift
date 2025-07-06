import SwiftUI

struct DebugView: View {
    @ObservedObject var sharedDataManager = SharedDataManager.shared
    @State private var sessions: [TrainingSession] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sync Status")
                    .font(.headline)
                    .padding(.bottom, 2)
                
                // Current Sync Status
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Status")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(sharedDataManager.syncStatus)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(getSyncStatusColor())
                }
                .padding(.vertical, 2)
                
                // Connection Status
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack {
                        Circle()
                            .fill(sharedDataManager.isConnected ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(sharedDataManager.isConnected ? "Connected" : "Disconnected")
                            .font(.system(.caption2))
                    }
                }
                .padding(.vertical, 2)
                
                // Last Sync Time
                if let lastSync = sharedDataManager.lastSyncTime {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Sync")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatSyncTime(lastSync))
                            .font(.system(.caption2))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                
                Divider()
                
                // App Group Status
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Group")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("group.com.shuttlx.shared")
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, 2)
                
                Divider()
                
                // Programs Status
                VStack(alignment: .leading, spacing: 2) {
                    Text("Programs (\(sharedDataManager.syncedPrograms.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !sharedDataManager.syncedPrograms.isEmpty {
                        ForEach(sharedDataManager.syncedPrograms.prefix(2), id: \.id) { program in
                            Text("• \(program.name)")
                                .font(.system(.caption2))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        if sharedDataManager.syncedPrograms.count > 2 {
                            Text("... +\(sharedDataManager.syncedPrograms.count - 2) more")
                                .font(.system(.caption2))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No programs available")
                            .font(.system(.caption2))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
                
                Divider()
                
                // Recent Sync Log
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent Activity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(sharedDataManager.syncLog.prefix(2), id: \.self) { logEntry in
                        Text(logEntry)
                            .font(.system(.caption2))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundColor(.secondary)
                    }
                    
                    if sharedDataManager.syncLog.isEmpty {
                        Text("No recent activity")
                            .font(.system(.caption2))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .onAppear {
            // Auto-load programs when view appears
            sharedDataManager.loadPrograms()
        }
    }
    
    private func getSyncStatusColor() -> Color {
        let status = sharedDataManager.syncStatus
        if status.contains("✅") {
            return .green
        } else if status.contains("❌") {
            return .red
        } else if status.contains("🔄") || status.contains("Syncing") {
            return .blue
        } else {
            return .primary
        }
    }
    
    private func formatSyncTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView()
    }
}
