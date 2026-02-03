import SwiftUI
import WatchConnectivity

#if DEBUG
struct SyncDebugView: View {
    @StateObject private var syncMonitor = SyncMonitor.shared
    @ObservedObject private var sharedDataManager: SharedDataManager = .shared

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Session Status")) {
                    statusRow(title: "Activation State", value: syncMonitor.activationState)
                    statusRow(title: "Reachable", value: syncMonitor.isReachable ? "Yes" : "No",
                              color: syncMonitor.isReachable ? .green : .red)
                    statusRow(title: "Paired", value: syncMonitor.isPaired ? "Yes" : "No",
                              color: syncMonitor.isPaired ? .green : .red)
                    statusRow(title: "Watch App Installed", value: syncMonitor.isWatchAppInstalled ? "Yes" : "No",
                              color: syncMonitor.isWatchAppInstalled ? .green : .red)
                }

                Section(header: Text("Sync Status")) {
                    statusRow(title: "Last Sync", value: syncMonitor.lastSyncTimeString)
                    statusRow(title: "Connectivity Health", value: "\(syncMonitor.connectivityHealthPercent)%",
                              color: syncMonitor.healthColor)
                    statusRow(title: "Sessions Synced", value: "\(sharedDataManager.syncedSessions.count)")
                    statusRow(title: "Status", value: syncMonitor.syncStatus)
                }

                Section(header: Text("Actions")) {
                    Button("Force Sync Now") {
                        SharedDataManager.shared.syncProgramsToWatch(DataManager().programs)
                    }

                    Button("Clear Logs") {
                        syncMonitor.clearLogs()
                    }
                }

                Section(header: Text("Logs")) {
                    ForEach(syncMonitor.logs, id: \.self) { log in
                        Text(log)
                            .font(.footnote)
                            .lineLimit(nil)
                    }
                }
            }
            .navigationTitle("Sync Debug")
        }
        .onAppear {
            syncMonitor.startMonitoring()
        }
        .onDisappear {
            syncMonitor.stopMonitoring()
        }
    }

    private func statusRow(title: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(color)
        }
    }
}

@MainActor
class SyncMonitor: ObservableObject {
    static let shared = SyncMonitor()

    @Published var activationState: String = "Unknown"
    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var connectivityHealth: Double = 0
    @Published var lastSyncTime: Date?
    @Published var syncStatus: String = "Unknown"
    @Published var logs: [String] = []

    private var timer: Timer?

    var connectivityHealthPercent: Int {
        return Int(connectivityHealth * 100)
    }

    var healthColor: Color {
        if connectivityHealth > 0.7 {
            return .green
        } else if connectivityHealth > 0.3 {
            return .yellow
        } else {
            return .red
        }
    }

    var lastSyncTimeString: String {
        if let lastSync = lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            return formatter.localizedString(for: lastSync, relativeTo: Date())
        } else {
            return "Never"
        }
    }

    private init() {
        // Set up notification observers
        NotificationCenter.default.addObserver(self, selector: #selector(handleWatchSessionStatus(_:)),
                                              name: NSNotification.Name("WatchSessionStatus"), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handleWatchSyncStatus(_:)),
                                              name: NSNotification.Name("WatchSyncStatus"), object: nil)
    }

    func startMonitoring() {
        updateStatus()

        // Set up a timer to refresh status
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func clearLogs() {
        logs = []
    }

    private func updateStatus() {
        let session = WCSession.default

        // Update session state
        switch session.activationState {
        case .activated:
            activationState = "Activated"
        case .inactive:
            activationState = "Inactive"
        case .notActivated:
            activationState = "Not Activated"
        @unknown default:
            activationState = "Unknown"
        }

        isReachable = session.isReachable
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled

        // Get data from SharedDataManager
        connectivityHealth = SharedDataManager.shared.connectivityHealth
        lastSyncTime = SharedDataManager.shared.lastSyncTime

        // Add to log if there are changes
        let statusString = "State: \(activationState), Reachable: \(isReachable), Health: \(connectivityHealthPercent)%"
        if logs.isEmpty || logs.last != statusString {
            addLog(statusString)
        }
    }

    func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"

        // Add new log and limit size
        DispatchQueue.main.async {
            self.logs.append(logEntry)
            if self.logs.count > 50 {
                self.logs.removeFirst(self.logs.count - 50)
            }
        }
    }

    @objc private func handleWatchSessionStatus(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let status = userInfo["status"] as? String else {
            return
        }

        addLog("Session: \(status)")

        // Update UI based on status
        DispatchQueue.main.async {
            switch status {
            case "activated":
                self.addLog("Session activated successfully")
            case "activationFailed":
                if let error = userInfo["error"] as? String {
                    self.addLog("Activation failed: \(error)")
                }
            case "reachabilityChanged":
                if let isReachable = userInfo["isReachable"] as? Bool {
                    self.isReachable = isReachable
                    self.addLog("Reachability changed to \(isReachable ? "reachable" : "unreachable")")
                }
            case "watchStateChanged":
                if let isPaired = userInfo["isPaired"] as? Bool {
                    self.isPaired = isPaired
                }
                if let isWatchAppInstalled = userInfo["isWatchAppInstalled"] as? Bool {
                    self.isWatchAppInstalled = isWatchAppInstalled
                }
                self.addLog("Watch state: paired=\(self.isPaired), installed=\(self.isWatchAppInstalled)")
            default:
                break
            }
        }
    }

    @objc private func handleWatchSyncStatus(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let status = userInfo["status"] as? String else {
            return
        }

        addLog("Sync: \(status)")

        // Update UI based on sync status
        DispatchQueue.main.async {
            switch status {
            case "syncAttempted":
                self.syncStatus = "Sync attempted"
            case "syncSuccessful":
                self.syncStatus = "Sync successful"
                self.lastSyncTime = Date()
            case "watchNotAvailable":
                self.syncStatus = "Watch not available"
            case "activationFailed":
                self.syncStatus = "Activation failed"
            case "retrying":
                if let attempt = userInfo["attempt"] as? Int {
                    self.syncStatus = "Retrying (attempt \(attempt))"
                }
            case "retriesExhausted":
                self.syncStatus = "Failed after retries"
            default:
                self.syncStatus = status
            }
        }
    }
}

struct SyncDebugView_Previews: PreviewProvider {
    static var previews: some View {
        SyncDebugView()
    }
}
#endif
