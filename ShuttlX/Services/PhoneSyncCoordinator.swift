import WatchConnectivity
import Foundation
import Combine
import WidgetKit
import os.log
import ShuttlXShared

@MainActor
class PhoneSyncCoordinator: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneSyncCoordinator()

    @Published var syncedSessions: [TrainingSession] = []
    @Published var syncLog: [String] = []
    @Published var connectivityHealth: Double = 1.0
    @Published var lastSyncTime: Date?

    // Live workout state from Watch
    @Published var isWorkoutActiveOnWatch = false
    @Published var liveElapsedTime: TimeInterval = 0
    @Published var liveHeartRate: Int = 0
    @Published var liveDistance: Double = 0
    @Published var liveCalories: Int = 0
    @Published var liveSteps: Int = 0
    @Published var liveCurrentActivity: String = "unknown"
    @Published var liveWorkoutName: String = ""
    @Published var liveIsPaused: Bool = false
    @Published var livePace: TimeInterval = 0
    @Published var liveRoutePoints: [RoutePoint] = []
    @Published var liveMetricsLastUpdated: Date? = nil

    private var liveMetricsTimeoutTimer: Timer?
    private var consecutiveFailures: Int = 0
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "PhoneSyncCoordinator")

    private let sessionsKey = "sessions.json"
    private let appGroupIdentifier = "group.com.shuttlx.shared"
    private var sharedContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private var fallbackContainer: URL? {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docsURL.appendingPathComponent("SharedData")
    }

    private var lastPingTime: Date?
    private var backgroundSyncTimer: Timer?
    private weak var dataManager: DataManager?
    private var pendingForDataManager: [TrainingSession] = []

    private var session: WCSession {
        return WCSession.default
    }

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        loadSessionsFromSharedStorage()
        setupBackgroundTasks()
        LiveActivityManager.shared.cleanupStaleActivities()
    }

    deinit {
        backgroundSyncTimer?.invalidate()
    }

    // MARK: - Background Tasks

    private func setupBackgroundTasks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.performBackgroundSync()
                }
            }
        }
    }

    private func performBackgroundSync() {
        checkForNewSessions()
        pingWatchIfNeeded()
        updateConnectivityHealth()
    }

    private func checkForNewSessions() {
        guard let dataManager = dataManager else {
            log("Warning: dataManager is nil during reconcile")
            return
        }

        // Check if PhoneSyncCoordinator has sessions that DataManager is missing
        let dmSessionIds = Set(dataManager.sessions.map { $0.id })
        let missingSessions = syncedSessions.filter { !dmSessionIds.contains($0.id) }

        if !missingSessions.isEmpty {
            log("Found \(missingSessions.count) session(s) missing from DataManager — forwarding")
            dataManager.handleReceivedSessions(missingSessions)
        }
    }

    private func pingWatchIfNeeded() {
        if let lastPing = lastPingTime, Date().timeIntervalSince(lastPing) < 300 {
            return
        }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                ["action": "ping", "timestamp": Date().timeIntervalSince1970],
                replyHandler: { [weak self] reply in
                    Task { @MainActor in
                        guard let self = self else { return }
                        if let status = reply["status"] as? String, status == "alive" {
                            self.lastPingTime = Date()
                            self.consecutiveFailures = 0
                            self.updateConnectivityHealth()
                        }
                    }
                },
                errorHandler: { [weak self] error in
                    Task { @MainActor in
                        self?.consecutiveFailures += 1
                        self?.updateConnectivityHealth()
                    }
                }
            )
        }
    }

    private func updateConnectivityHealth() {
        var healthScore = 1.0

        if WCSession.default.activationState != .activated { healthScore -= 0.5 }
        if !WCSession.default.isReachable { healthScore -= 0.3 }
        if !WCSession.default.isPaired { healthScore -= 0.7 }
        if !WCSession.default.isWatchAppInstalled { healthScore -= 0.6 }
        healthScore -= min(0.5, Double(consecutiveFailures) * 0.1)

        if let lastSync = lastSyncTime {
            if Date().timeIntervalSince(lastSync) > 300 { healthScore -= 0.2 }
        } else {
            healthScore -= 0.2
        }

        healthScore = max(0, min(1, healthScore))

        if healthScore != connectivityHealth {
            connectivityHealth = healthScore
        }
    }

    // MARK: - DataManager Integration

    func setDataManager(_ dataManager: DataManager) {
        self.dataManager = dataManager
        if !pendingForDataManager.isEmpty {
            log("Flushing \(pendingForDataManager.count) buffered session(s) to DataManager")
            dataManager.handleReceivedSessions(pendingForDataManager)
            pendingForDataManager.removeAll()
        }
    }

    // MARK: - Session Handling

    func handleReceivedSession(_ session: TrainingSession) {
        if !syncedSessions.contains(where: { $0.id == session.id }) {
            syncedSessions.append(session)
            // Persist immediately so sessions survive app termination before DataManager saves
            saveSessionsToSharedStorage(syncedSessions)
            log("New session received and saved: \(session.id)")
            consecutiveFailures = 0
            lastSyncTime = Date()
            updateConnectivityHealth()

            // Forward to DataManager which saves to App Group + reloads widgets
            if let dataManager = dataManager {
                dataManager.handleReceivedSessions([session])
            } else {
                log("Warning: dataManager nil — buffering session \(session.id)")
                pendingForDataManager.append(session)
            }
        }
    }

    // MARK: - Live Workout Metrics

    func handleLiveMetrics(_ message: [String: Any]) {
        let wasActive = isWorkoutActiveOnWatch
        isWorkoutActiveOnWatch = true
        liveMetricsLastUpdated = Date()

        liveElapsedTime = message["elapsedTime"] as? TimeInterval ?? 0
        liveHeartRate = message["heartRate"] as? Int ?? 0
        liveDistance = message["distance"] as? Double ?? 0
        liveCalories = message["calories"] as? Int ?? 0
        liveSteps = message["steps"] as? Int ?? 0
        liveCurrentActivity = message["currentActivity"] as? String ?? "unknown"
        liveWorkoutName = message["workoutName"] as? String ?? liveCurrentActivity
        liveIsPaused = message["isPaused"] as? Bool ?? false
        livePace = message["pace"] as? TimeInterval ?? 0

        // Accumulate live route points for real-time map
        if let lat = message["latitude"] as? Double, let lon = message["longitude"] as? Double {
            let point = RoutePoint(latitude: lat, longitude: lon, timestamp: Date())
            // Avoid duplicates (same location within ~5m)
            if let last = liveRoutePoints.last {
                let dLat = abs(lat - last.latitude)
                let dLon = abs(lon - last.longitude)
                if dLat > 0.00005 || dLon > 0.00005 {
                    liveRoutePoints.append(point)
                }
            } else {
                liveRoutePoints.append(point)
            }
        }

        // Explicitly start the Live Activity on the first metric update
        // (i.e. when isWorkoutActiveOnWatch transitions from false to true).
        // If startActivity() fails, the retry flag inside LiveActivityManager
        // will cause updateActivity() to retry on subsequent metric updates.
        if !wasActive {
            log("Workout started on Watch — starting Live Activity")
            LiveActivityManager.shared.startActivity(activityType: liveWorkoutName)
        }

        LiveActivityManager.shared.updateActivity(
            elapsedTime: liveElapsedTime,
            heartRate: liveHeartRate,
            distance: liveDistance,
            calories: liveCalories,
            currentActivity: liveCurrentActivity,
            isPaused: liveIsPaused,
            pace: livePace
        )

        // When paused the watch stops broadcasting — don't time out the live
        // state so the card stays visible. Resume will restart the timeout.
        liveMetricsTimeoutTimer?.invalidate()
        if !liveIsPaused {
            liveMetricsTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.clearLiveWorkoutState()
                }
            }
        }
    }

    // MARK: - Watch Workout Control

    func pauseWatchWorkout() { sendWorkoutControl("pause") }
    func resumeWatchWorkout() { sendWorkoutControl("resume") }
    func stopWatchWorkout() { sendWorkoutControl("stop") }

    /// Sends a pause/resume/stop command to the Watch on two channels:
    ///
    ///  1. `sendMessage` — real-time, but **silently drops the command** if the
    ///     Watch isn't reachable at that instant (screen off / wrist-down / app
    ///     backgrounded while the HealthKit workout session keeps running in the
    ///     background — a very common state during an active workout). Before
    ///     this fix there was no fallback here, so a user-initiated Stop could
    ///     vanish entirely: the confirmation dialog dismissed, the user believed
    ///     the workout had ended, but the Watch never received anything and kept
    ///     broadcasting live metrics — which is exactly why the elapsed timer on
    ///     the LiveWorkoutCard kept counting up after "End Workout".
    ///  2. `transferUserInfo` — OS-queued, guaranteed delivery once the Watch is
    ///     reachable again. Mirrors the same dual-channel pattern already used
    ///     for the Watch → iPhone `workoutStopped` notification
    ///     (`LiveMetricsBroadcaster.notifyWorkoutStopped()`) and required by
    ///     `.claude/rules/services.md` ("Always check isReachable before
    ///     sendMessage, fall back to transferUserInfo").
    ///
    /// Sending on both channels is safe: `stopWorkout()`/`pauseWorkout()`/
    /// `resumeWorkout()` on the Watch are all guarded (`guard isWorkoutActive`,
    /// etc.), so a duplicate delivery is a harmless no-op.
    private func sendWorkoutControl(_ command: String) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else {
            log("workoutControl '\(command)' skipped — WCSession not activated")
            return
        }

        // sentAt lets the Watch discard stale deliveries (transferUserInfo is FIFO-queued
        // and can arrive minutes later — a stop from a prior workout must not kill the next one).
        let message: [String: Any] = ["action": "workoutControl", "command": command,
                                      "sentAt": Date().timeIntervalSince1970]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.log("workoutControl '\(command)' delivered via sendMessage")
                }
            }, errorHandler: { [weak self] error in
                Task { @MainActor in
                    self?.log("workoutControl '\(command)' sendMessage failed: \(error.localizedDescription) — relying on transferUserInfo")
                }
            })
        } else {
            log("workoutControl '\(command)' — Watch not reachable, relying on transferUserInfo")
        }

        // Guaranteed fallback — always queued regardless of reachability so a
        // dropped sendMessage (or a Watch that goes unreachable mid-flight)
        // still delivers the command once connectivity is restored.
        WCSession.default.transferUserInfo(message)
    }

    func clearLiveWorkoutState() {
        let wasActive = isWorkoutActiveOnWatch
        LiveActivityManager.shared.endActivity()
        isWorkoutActiveOnWatch = false
        liveElapsedTime = 0
        liveHeartRate = 0
        liveDistance = 0
        liveCalories = 0
        liveSteps = 0
        liveCurrentActivity = "unknown"
        liveWorkoutName = ""
        liveIsPaused = false
        livePace = 0
        liveRoutePoints = []
        liveMetricsLastUpdated = nil
        liveMetricsTimeoutTimer?.invalidate()
        liveMetricsTimeoutTimer = nil
        if wasActive {
            log("Live workout state cleared — Live Activity ended")
        }
    }

    // MARK: - Session Storage

    /// Serial background queue for sessions.json writes — encoding the full
    /// history must never block the main actor (stall grows with history size).
    private nonisolated static let sessionStoreQueue = DispatchQueue(label: "com.shuttlx.phone-session-store", qos: .utility)

    private func saveSessionsToSharedStorage(_ sessions: [TrainingSession]) {
        guard let containerURL = getWorkingContainer() else { return }

        let url = containerURL.appendingPathComponent(sessionsKey)
        Self.sessionStoreQueue.async { [weak self] in
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { writeURL in
                do {
                    let data = try JSONEncoder().encode(sessions)
                    try data.write(to: writeURL, options: [.atomic, .completeFileProtection])
                } catch {
                    Task { @MainActor [weak self] in
                        self?.log("Failed to save sessions: \(error.localizedDescription)")
                    }
                }
            }
            if let coordinatorError {
                Task { @MainActor [weak self] in
                    self?.log("File coordination error saving sessions: \(coordinatorError.localizedDescription)")
                }
            }
        }
    }

    private func loadSessionsFromSharedStorage(completion: (() -> Void)? = nil) {
        readSessionsFromDisk { [weak self] sessions in
            if let self, !sessions.isEmpty {
                self.syncedSessions = sessions
            }
            completion?()
        }
    }

    /// Reads + decodes sessions.json on the store queue — decode cost grows with
    /// history size (GPS-heavy histories reach several MB) and this runs on every
    /// app resume. Completion is delivered on the main actor.
    private func readSessionsFromDisk(_ completion: @escaping ([TrainingSession]) -> Void) {
        guard let containerURL = getWorkingContainer() else { completion([]); return }

        let url = containerURL.appendingPathComponent(sessionsKey)
        guard FileManager.default.fileExists(atPath: url.path) else { completion([]); return }

        Self.sessionStoreQueue.async { [weak self] in
            var result: [TrainingSession] = []
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    result = try JSONDecoder().decode([TrainingSession].self, from: data)
                } catch {
                    // Preserve corrupt file for potential recovery — never silently drop history
                    let backupURL = url.deletingLastPathComponent()
                        .appendingPathComponent("sessions_corrupt_\(Int(Date().timeIntervalSince1970)).json")
                    try? FileManager.default.copyItem(at: readURL, to: backupURL)
                    Task { @MainActor [weak self] in
                        self?.log("CRITICAL: Failed to decode sessions.json: \(error.localizedDescription)")
                        self?.log("Backed up corrupt sessions.json to \(backupURL.lastPathComponent)")
                        self?.purgeOldCorruptBackups(in: url.deletingLastPathComponent())
                    }
                }
            }
            if let coordinatorError {
                Task { @MainActor [weak self] in
                    self?.log("File coordination error loading sessions: \(coordinatorError.localizedDescription)")
                }
            }
            Task { @MainActor in completion(result) }
        }
    }

    func loadSessionsFromAppGroup() -> [TrainingSession] {
        guard let containerURL = getWorkingContainer() else { return [] }

        let url = containerURL.appendingPathComponent(sessionsKey)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        var result: [TrainingSession] = []
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            do {
                let data = try Data(contentsOf: readURL)
                result = try JSONDecoder().decode([TrainingSession].self, from: data)
            } catch {
                self.log("CRITICAL: Failed to decode sessions.json: \(error.localizedDescription)")
                // Preserve corrupt file for potential recovery — never silently drop history
                let backupURL = url.deletingLastPathComponent()
                    .appendingPathComponent("sessions_corrupt_\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.copyItem(at: readURL, to: backupURL)
                self.log("Backed up corrupt sessions.json to \(backupURL.lastPathComponent)")
                self.purgeOldCorruptBackups(in: url.deletingLastPathComponent())
            }
        }
        if let coordinatorError {
            log("File coordination error loading sessions: \(coordinatorError.localizedDescription)")
        }
        return result
    }

    private func purgeOldCorruptBackups(in directory: URL) {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for file in files where file.lastPathComponent.hasPrefix("sessions_corrupt_") {
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantFuture
            if created < cutoff {
                try? FileManager.default.removeItem(at: file)
                log("Removed stale corrupt backup: \(file.lastPathComponent)")
            }
        }
    }

    // MARK: - Public Debug

    func purgeAllSessionsFromStorage() {
        syncedSessions = []

        if let containerURL = getWorkingContainer() {
            let sessionsURL = containerURL.appendingPathComponent(sessionsKey)
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            coordinator.coordinate(writingItemAt: sessionsURL, options: .forReplacing, error: &coordinatorError) { writeURL in
                do {
                    let data = try JSONEncoder().encode([TrainingSession]())
                    try data.write(to: writeURL, options: [.atomic, .completeFileProtection])
                } catch {
                    self.logger.error("Failed to purge sessions: \(error.localizedDescription)")
                }
            }
            if let coordinatorError {
                logger.error("File coordination error purging sessions: \(coordinatorError.localizedDescription)")
            }
        }
    }

    func checkConnectivity() -> String {
        let session = WCSession.default
        return """
        Activation State: \(session.activationState.rawValue)
        Reachable: \(session.isReachable)
        Paired: \(session.isPaired)
        App Installed: \(session.isWatchAppInstalled)
        Connectivity Health: \(Int(connectivityHealth * 100))%
        Sessions Synced: \(syncedSessions.count)
        Last Sync: \(lastSyncTime?.description ?? "Never")
        Consecutive Failures: \(consecutiveFailures)
        """
    }

    func clearAndReloadSessions() {
        let allSessions = Set(loadSessionsFromAppGroup())
        syncedSessions = Array(allSessions)
    }

    /// Request all sessions from Watch via sendMessage with automatic retries.
    /// Always attempts sendMessage regardless of isReachable — the property can lag behind
    /// actual connectivity, and sendMessage's errorHandler is the reliable failure path.
    func requestSessionsFromWatch(completion: @escaping (Int) -> Void) {
        log("Requesting sessions from Watch (reachable: \(WCSession.default.isReachable))")
        attemptSessionRequest(retriesLeft: 3, completion: completion)
    }

    private func attemptSessionRequest(retriesLeft: Int, completion: @escaping (Int) -> Void) {
        WCSession.default.sendMessage(
            ["action": "requestAllSessions"],
            replyHandler: { [weak self] reply in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.handleSessionRequestReply(reply, completion: completion)
                }
            },
            errorHandler: { [weak self] error in
                Task { @MainActor in
                    guard let self = self else {
                        completion(0)
                        return
                    }
                    self.log("Sync attempt failed: \(error.localizedDescription)")

                    if retriesLeft > 0 {
                        self.log("Retrying in 1.5s (\(retriesLeft) attempts left)…")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                            self?.attemptSessionRequest(retriesLeft: retriesLeft - 1, completion: completion)
                        }
                    } else {
                        self.log("All sync attempts failed")
                        self.consecutiveFailures += 1
                        self.updateConnectivityHealth()
                        completion(0)
                    }
                }
            }
        )
    }

    private func handleSessionRequestReply(_ reply: [String: Any], completion: @escaping (Int) -> Void) {
        let oversizedCount = reply["oversizedCount"] as? Int ?? 0

        if let sessionsDataString = reply["sessionsData"] as? String,
           let sessionsData = Data(base64Encoded: sessionsDataString) {
            do {
                let sessions = try JSONDecoder().decode([TrainingSession].self, from: sessionsData)
                var newCount = 0
                for session in sessions {
                    if !syncedSessions.contains(where: { $0.id == session.id }) {
                        syncedSessions.append(session)
                        newCount += 1
                    }
                }
                if newCount > 0 {
                    dataManager?.handleReceivedSessions(sessions)
                    log("Pulled \(newCount) new session(s) from Watch")
                }
                if oversizedCount > 0 {
                    log("\(oversizedCount) large session(s) arriving via background transfer")
                }
                consecutiveFailures = 0
                lastSyncTime = Date()
                updateConnectivityHealth()
                completion(newCount)
            } catch {
                log("Failed to decode sessions from Watch: \(error.localizedDescription)")
                completion(0)
            }
        } else if let count = reply["count"] as? Int, count > 0 {
            log("Watch sending \(count) session(s) via background transfer")
            completion(0)
        } else {
            completion(0)
        }
    }

    /// Called when app comes to foreground — reconcile any missing sessions
    func reconcileWithDataManager() {
        // Reload from disk first — picks up sessions saved while app was
        // backgrounded. The read is async (off-main decode); the reconcile
        // steps must run only after it has applied to syncedSessions.
        loadSessionsFromSharedStorage { [weak self] in
            guard let self else { return }
            self.checkForNewSessions()

            // Always attempt pull — sendMessage's errorHandler handles unreachable case,
            // isReachable can be stale
            self.requestSessionsFromWatch { [weak self] count in
                if count > 0 {
                    self?.log("Reconciliation pulled \(count) session(s)")
                }
            }
        }
    }

    /// Sends known session IDs to Watch so Watch can re-send any missing ones
    func reconcileSessionIDs() {
        guard let dataManager = dataManager else { return }
        let knownIDs = dataManager.sessions.map { $0.id.uuidString }

        let message: [String: Any] = [
            "action": "reconcileSessions",
            "knownSessionIDs": knownIDs
        ]

        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor in
                guard let self = self else { return }
                if let missingCount = reply["missingCount"] as? Int, missingCount > 0 {
                    self.log("Watch found \(missingCount) session(s) missing from iPhone — resending")
                }
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.log("Session reconciliation failed: \(error.localizedDescription)")
            }
        })
    }

    // MARK: - Template Sync

    func sendTemplatesToWatch(_ templates: [WorkoutTemplate]) {
        guard WCSession.isSupported() else { return }

        do {
            let data = try JSONEncoder().encode(templates)

            // Update combined applicationContext (preserves theme + templates together)
            updateCombinedApplicationContext(merging: [
                "action": "syncTemplates",
                "templatesData": data.base64EncodedString(),
                "timestamp": Date().timeIntervalSince1970
            ])
            log("Templates sent via applicationContext (\(templates.count))")

            // Also transfer via userInfo for guaranteed delivery
            let payload: [String: Any] = [
                "action": "syncTemplates",
                "templatesData": data.base64EncodedString(),
                "timestamp": Date().timeIntervalSince1970
            ]
            session.transferUserInfo(payload)
            log("Templates queued via transferUserInfo (\(templates.count))")
        } catch {
            log("Failed to send templates: \(error.localizedDescription)")
        }
    }

    // MARK: - Theme Sync

    func sendThemeToWatch(_ themeID: String) {
        guard WCSession.isSupported(), session.isPaired else { return }
        let payload: [String: Any] = [
            "action": "syncTheme",
            "themeID": themeID
        ]

        // Immediate delivery when watch app is running
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { [weak self] error in
                self?.log("Theme sendMessage failed: \(error.localizedDescription)")
            })
            log("Theme sent to Watch via sendMessage: \(themeID)")
        }

        // Update combined applicationContext (preserves theme + templates together)
        updateCombinedApplicationContext(merging: [
            "action": "syncTheme",
            "themeID": themeID
        ])
        log("Theme sent to Watch via applicationContext: \(themeID)")
    }

    // MARK: - Max HR Sync

    /// Syncs the user's max HR override to the Watch so it uses the same zone boundaries.
    /// Pass 0 to clear a manual override (Watch will fall back to Tanaka formula or HealthKit age).
    func sendMaxHRToWatch(_ maxHR: Double) {
        guard WCSession.isSupported(), session.isPaired else { return }
        let payload: [String: Any] = [
            "action": "syncMaxHR",
            "maxHR": maxHR
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { [weak self] error in
                self?.log("Max HR sendMessage failed: \(error.localizedDescription)")
            })
        }

        updateCombinedApplicationContext(merging: payload)
        log("Max HR sent to Watch: \(maxHR == 0 ? "cleared" : "\(Int(maxHR)) BPM")")
    }

    // MARK: - Subscription Sync

    /// Syncs the user's Pro subscription status to Watch so it can gate features locally.
    func sendSubscriptionStatusToWatch(_ isPro: Bool) {
        guard WCSession.isSupported(), session.isPaired else { return }
        updateCombinedApplicationContext(merging: ["isPro": isPro])
        log("Subscription status sent to Watch: \(isPro ? "Pro" : "Free")")
    }

    // MARK: - Combined Application Context

    /// Merges new keys into the existing applicationContext to prevent overwrites.
    /// Templates and themes coexist in the same context dictionary.
    private func updateCombinedApplicationContext(merging newKeys: [String: Any]) {
        do {
            var context = session.applicationContext
            for (key, value) in newKeys {
                context[key] = value
            }
            try session.updateApplicationContext(context)
        } catch {
            log("Failed to update applicationContext: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private func log(_ message: String) {
        logger.info("\(message)")
        syncLog.append("[\(Self.logDateFormatter.string(from: Date()))] \(message)")
        if syncLog.count > 100 {
            syncLog.removeFirst()
        }
    }

    private func getWorkingContainer() -> URL? {
        if let container = sharedContainer {
            return container
        }

        guard let fallback = fallbackContainer else { return nil }
        do {
            try FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback
        } catch {
            return nil
        }
    }
}

// MARK: - WCSessionDelegate
extension PhoneSyncCoordinator {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.log("WC Session activation failed: \(error.localizedDescription)")
                self.consecutiveFailures += 1
            } else {
                self.log("WC Session activated: \(activationState.rawValue)")
                self.consecutiveFailures = 0

                // After activation, try pulling sessions if Watch is reachable,
                // then reconcile to catch any sessions that overflowed the inline
                // byte budget and were routed via transferUserInfo.
                if session.isReachable {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.requestSessionsFromWatch { count in
                            if count > 0 {
                                self?.log("Post-activation sync pulled \(count) session(s)")
                            }
                            self?.reconcileSessionIDs()
                        }
                    }
                }
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.log("Watch reachability changed: \(session.isReachable)")
            self.updateConnectivityHealth()

            // When Watch becomes reachable, pull any new sessions then reconcile
            // to catch sessions the watch has that iOS is missing.
            if session.isReachable {
                self.log("Watch became reachable — auto-pulling sessions")
                self.requestSessionsFromWatch { [weak self] count in
                    if count > 0 {
                        self?.log("Auto-sync pulled \(count) session(s)")
                    }
                    self?.reconcileSessionIDs()
                }
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.updateConnectivityHealth()
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            session.activate()
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            if let action = userInfo["action"] as? String {
                switch action {
                case "saveSession":
                    if let sessionDataString = userInfo["sessionData"] as? String,
                       let sessionData = Data(base64Encoded: sessionDataString) {
                        do {
                            let trainingSession = try JSONDecoder().decode(TrainingSession.self, from: sessionData)
                            self.handleReceivedSession(trainingSession)
                            self.log("Session received from watch via userInfo")
                        } catch {
                            self.log("Failed to decode session from userInfo: \(error.localizedDescription)")
                            self.consecutiveFailures += 1
                        }
                    } else {
                        self.log("Missing or invalid sessionData in userInfo")
                        self.consecutiveFailures += 1
                    }
                case "workoutStarted":
                    if let activityType = userInfo["activityType"] as? String {
                        self.isWorkoutActiveOnWatch = true
                        self.liveCurrentActivity = activityType
                        LiveActivityManager.shared.startActivity(activityType: activityType)
                        self.log("Workout started on Watch (via transferUserInfo) — Live Activity started")
                    }
                case "workoutStopped":
                    self.clearLiveWorkoutState()
                    self.log("Workout stopped on Watch (via transferUserInfo)")
                default:
                    break
                }
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let action = message["action"] as? String {
                switch action {
                case "saveSession":
                    if let sessionDataString = message["sessionData"] as? String,
                       let sessionData = Data(base64Encoded: sessionDataString) {
                        do {
                            let trainingSession = try JSONDecoder().decode(TrainingSession.self, from: sessionData)
                            self.handleReceivedSession(trainingSession)
                            self.consecutiveFailures = 0
                        } catch {
                            self.log("Failed to decode session from message: \(error.localizedDescription)")
                            self.consecutiveFailures += 1
                        }
                    } else {
                        self.log("Missing or invalid sessionData in message")
                        self.consecutiveFailures += 1
                    }
                case "liveMetrics":
                    self.handleLiveMetrics(message)
                case "workoutStopped":
                    self.clearLiveWorkoutState()
                case "ping":
                    self.consecutiveFailures = 0
                default:
                    break
                }
            }
            self.updateConnectivityHealth()
        }
    }

    // applicationContext is the resilient channel for "latest snapshot" data:
    // it's OS-queued and delivered when the iPhone next wakes, even if we were
    // suspended/locked. The watch mirrors live metrics here (and a "lastSessionID"
    // tap-on-shoulder after Finish) so we recover from sendMessage drops.
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            guard let action = applicationContext["action"] as? String else { return }
            switch action {
            case "liveMetrics":
                self.handleLiveMetrics(applicationContext)
            case "lastSessionID":
                if let idString = applicationContext["sessionID"] as? String,
                   let id = UUID(uuidString: idString),
                   !self.syncedSessions.contains(where: { $0.id == id }) {
                    self.log("lastSessionID \(idString) not in synced list — requesting from watch")
                    self.requestSessionsFromWatch { _ in }
                }
            default:
                break
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            if let action = message["action"] as? String {
                switch action {
                case "saveSession":
                    if let sessionDataString = message["sessionData"] as? String,
                       let sessionData = Data(base64Encoded: sessionDataString) {
                        do {
                            let trainingSession = try JSONDecoder().decode(TrainingSession.self, from: sessionData)
                            self.handleReceivedSession(trainingSession)
                            self.consecutiveFailures = 0
                            replyHandler(["status": "saved", "timestamp": Date().timeIntervalSince1970])
                        } catch {
                            self.log("Failed to decode session from message(reply): \(error.localizedDescription)")
                            self.consecutiveFailures += 1
                            replyHandler(["error": "Failed to decode session"])
                        }
                    } else {
                        self.log("Missing or invalid sessionData in message(reply)")
                        replyHandler(["error": "Missing sessionData"])
                    }
                case "liveMetrics":
                    self.handleLiveMetrics(message)
                    replyHandler(["status": "received"])
                case "workoutStopped":
                    self.clearLiveWorkoutState()
                    replyHandler(["status": "received"])
                case "ping":
                    replyHandler(["status": "alive", "timestamp": Date().timeIntervalSince1970])
                    self.consecutiveFailures = 0
                default:
                    replyHandler(["error": "Unknown action"])
                }
            } else {
                replyHandler(["error": "No action"])
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.consecutiveFailures += 1
                self.log("UserInfo transfer failed: \(error.localizedDescription)")
            } else {
                self.consecutiveFailures = 0
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // MUST read file data synchronously — fileURL is only valid during this callback
        let fileData: Data?
        let metadata = file.metadata
        do {
            fileData = try Data(contentsOf: file.fileURL)
        } catch {
            fileData = nil
        }

        Task { @MainActor in
            guard let data = fileData else {
                self.log("Failed to read file transfer data — file may have been cleaned up")
                self.consecutiveFailures += 1
                self.updateConnectivityHealth()
                return
            }
            guard let metadata = metadata,
                  let action = metadata["action"] as? String,
                  action == "saveSession" else {
                self.log("Received file with unknown metadata")
                return
            }
            do {
                let trainingSession = try JSONDecoder().decode(TrainingSession.self, from: data)
                self.handleReceivedSession(trainingSession)
                self.log("Session received via file transfer (\(data.count) bytes)")
            } catch {
                self.log("Failed to decode session from file: \(error.localizedDescription)")
                self.consecutiveFailures += 1
            }
            self.updateConnectivityHealth()
        }
    }
}
