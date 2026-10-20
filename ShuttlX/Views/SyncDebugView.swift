import SwiftUI
import WatchConnectivity
import HealthKit
import os

#if DEBUG
struct SyncDebugView: View {
    @StateObject private var syncMonitor = SyncMonitor.shared
    @ObservedObject private var sharedDataManager: PhoneSyncCoordinator = .shared
    @EnvironmentObject private var dataManager: DataManager
    @ObservedObject private var importer = HealthKitImporter.shared
    @State private var healthRows: [HealthRow] = []
    @State private var healthStatus = "Not loaded"

    private struct HealthRow: Identifiable {
        let id: UUID
        let start: Date
        let duration: TimeInterval
        let inApp: Bool
    }

    var body: some View {
        List {
                Section(header: Text("Session Status")) {
                    statusRow(title: "Activation State", value: syncMonitor.activationState)
                    statusRow(title: "Reachable", value: syncMonitor.isReachable ? "Yes" : "No",
                              color: syncMonitor.isReachable ? ShuttlXColor.positive : ShuttlXColor.ctaDestructive)
                    statusRow(title: "Paired", value: syncMonitor.isPaired ? "Yes" : "No",
                              color: syncMonitor.isPaired ? ShuttlXColor.positive : ShuttlXColor.ctaDestructive)
                    statusRow(title: "Watch App Installed", value: syncMonitor.isWatchAppInstalled ? "Yes" : "No",
                              color: syncMonitor.isWatchAppInstalled ? ShuttlXColor.positive : ShuttlXColor.ctaDestructive)
                }

                Section(header: Text("Sync Status")) {
                    statusRow(title: "Last Sync", value: syncMonitor.lastSyncTimeString)
                    statusRow(title: "Connectivity Health", value: "\(syncMonitor.connectivityHealthPercent)%",
                              color: syncMonitor.healthColor)
                    statusRow(title: "Sessions Synced", value: "\(sharedDataManager.syncedSessions.count)")
                    statusRow(title: "Status", value: syncMonitor.syncStatus)
                }

                Section(header: Text("Health vs app (60 days) — \(healthStatus)")) {
                    statusRow(title: "Last import", value: importer.lastImportDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never")
                    statusRow(title: "Last import count", value: "\(importer.lastImportCount)")
                    statusRow(title: "Importer", value: importer.status)
                    Button("Import now") { Task { await importer.importNow() } }
                    Button("Reload from Health") { Task { await loadHealth() } }
                    ForEach(healthRows) { row in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(row.start.formatted(date: .abbreviated, time: .shortened))
                                Text("\(Int(row.duration / 60)) min").font(.footnote)
                            }
                            Spacer()
                            Text(row.inApp ? "In app" : "Missing in app")
                                .foregroundStyle(row.inApp ? ShuttlXColor.positive : ShuttlXColor.ctaDestructive)
                        }
                    }
                }

                Section(header: Text("Phone sync log (last 20)")) {
                    ForEach(Array(sharedDataManager.syncLog.suffix(20).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.footnote)
                    }
                }

                Section(header: Text("Actions")) {
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
            .scrollContentBackground(.hidden)
            .navigationTitle("Sync Debug")
        .themedScreenBackground()
        .task { await loadHealth() }
        .onAppear {
            syncMonitor.startMonitoring()
        }
        .onDisappear {
            syncMonitor.stopMonitoring()
        }
    }

    /// Read-only: lists HKWorkouts from the last 60 days and matches each against
    /// DataManager sessions (external UUID first, else start ±2 min and duration ±5%).
    private func loadHealth() async {
        let log = Logger(subsystem: "com.shuttlx.ShuttlX", category: "SyncDebugView")
        guard HKHealthStore.isHealthDataAvailable() else { healthStatus = "Health unavailable"; return }
        let store = HKHealthStore()
        do {
            try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
        } catch {
            healthStatus = "Auth error: \(error.localizedDescription)"
            log.error("[HKSOT] Health auth failed: \(error.localizedDescription)")
            return
        }
        let since = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let workouts: [HKWorkout] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error { log.error("[HKSOT] HKSampleQuery failed: \(error.localizedDescription)") }
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
        let sessions = dataManager.sessions
        healthRows = workouts.map { w in
            let ext = (w.metadata?[HKMetadataKeyExternalUUID] as? String).flatMap(UUID.init(uuidString:))
            let matched = sessions.contains { s in
                if let ext, s.id == ext { return true }
                return abs(s.startDate.timeIntervalSince(w.startDate)) <= 120
                    && abs(s.duration - w.duration) <= max(w.duration, 1) * 0.05
            }
            return HealthRow(id: w.uuid, start: w.startDate, duration: w.duration, inApp: matched)
        }
        let missing = healthRows.filter { !$0.inApp }.count
        healthStatus = "\(healthRows.count) in Health, \(missing) missing"
        log.info("[HKSOT] Health vs app: \(self.healthStatus)")
    }

    private func statusRow(title: String, value: String, color: Color? = nil) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(color ?? .primary)
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
            return ShuttlXColor.positive
        } else if connectivityHealth > 0.3 {
            return ShuttlXColor.ctaWarning
        } else {
            return ShuttlXColor.ctaDestructive
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

    private init() { }

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

        // Get data from PhoneSyncCoordinator
        connectivityHealth = PhoneSyncCoordinator.shared.connectivityHealth
        lastSyncTime = PhoneSyncCoordinator.shared.lastSyncTime

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

}

#Preview {
    SyncDebugView()
}
#endif
