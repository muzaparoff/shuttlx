import SwiftUI

#if DEBUG
struct DebugView: View {
    @ObservedObject var sharedDataManager = SharedDataManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sync Status")
                    .font(.headline)
                    .padding(.bottom, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Status")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(sharedDataManager.syncStatus)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(getSyncStatusColor())
                }
                .padding(.vertical, 2)

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

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connectivity Health")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(sharedDataManager.connectivityHealth * 100))%")
                        .font(.system(.caption2, design: .monospaced))
                }
                .padding(.vertical, 2)

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent Activity")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(sharedDataManager.syncLog.prefix(3), id: \.self) { logEntry in
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
    }

    private func getSyncStatusColor() -> Color {
        let status = sharedDataManager.syncStatus
        if status.contains("saved") || status.contains("verified") || status.contains("Connected") {
            return .green
        } else if status.contains("failed") || status.contains("error") {
            return .red
        } else if status.contains("Syncing") || status.contains("queued") {
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

#Preview {
    DebugView()
}
#endif
