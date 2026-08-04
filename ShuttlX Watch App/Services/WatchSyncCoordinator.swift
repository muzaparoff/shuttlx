import Foundation
import WatchConnectivity
import WidgetKit
import os.log
import ShuttlXShared

@MainActor
class WatchSyncCoordinator: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSyncCoordinator()
    @Published var syncStatus: String = "Not synced"
    @Published var isConnected: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncLog: [String] = []
    @Published var connectivityHealth: Double = 1.0
    @Published var workoutTemplates: [WorkoutTemplate] = []
    @Published var isPro: Bool = false

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "WatchSyncCoordinator")

    /// Back-reference to the workout manager for handling remote control commands
    /// from iPhone (pause/resume/stop). Weak to avoid a retain cycle.
    weak var workoutManager: WatchWorkoutManager?

    func setWorkoutManager(_ manager: WatchWorkoutManager) {
        workoutManager = manager
    }
    private nonisolated static let appGroupIdentifier = "group.com.shuttlx.shared"

    private var pendingSessions: [TrainingSession] = []
    private var consecutiveFailures = 0
    private var backgroundSyncTimer: Timer?
    private let pendingSessionsFileName = "pending_sync_sessions.json"
    private var lastFullResendTime: Date?
    /// Sessions with a WatchConnectivity transfer the daemon has NOT reported as
    /// finished yet. Without this, every retry tick (15s) plus every 1/3/8s burst
    /// re-enqueued a fresh copy of the same payload into wcd's outbox, so a cold
    /// launch with a few pending sessions produced a transfer storm that saturates
    /// the WC daemon and, through it, the main actor. Populated on enqueue, cleared
    /// in the didFinish callbacks (success AND failure — a failure simply lets the
    /// next retry tick resend), and reconciled from the daemon's own outstanding
    /// queues at activation so a relaunch doesn't double-queue what it already holds.
    private var inFlightSessionIDs: Set<UUID> = []
    // Gates scheduleFinishRetryBurst — without this, each pending session in a
    // retry cycle would schedule another 3 retries (1s/3s/8s), creating an
    // O(3^k × N) closure explosion that can kill the watch extension under
    // memory pressure.
    private var isBurstScheduled = false

    // MARK: - Initialization

    private override init() {
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            logger.info("WCSession activated")
        }

        Task { @MainActor [weak self] in
            await self?.loadPendingSessionsAndTemplates()
        }
        setupBackgroundTasks()
    }

    deinit {
        backgroundSyncTimer?.invalidate()
    }

    // MARK: - Background Tasks

    private func setupBackgroundTasks() {
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.retryPendingSessions()
                self.updateConnectivityHealth()
            }
        }
    }

    private func retryPendingSessions() {
        guard !pendingSessions.isEmpty else { return }

        logger.info("Retrying \(self.pendingSessions.count) pending sessions")

        // Send each session — they stay in pendingSessions until
        // removePendingSession is called from didFinish handlers
        for session in pendingSessions {
            sendSessionToiOS(session)
        }
    }

    /// Rebuilds `inFlightSessionIDs` from the transfers the WatchConnectivity daemon
    /// is still holding. The daemon's queues survive an app relaunch; our in-memory
    /// set does not — without this, the first retry tick after a cold launch would
    /// enqueue a duplicate of every transfer already waiting to go out.
    /// Only valid once the session is activated.
    private func reconcileInFlightTransfers() {
        guard WCSession.default.activationState == .activated else { return }
        var adopted = Set<UUID>()
        for transfer in WCSession.default.outstandingFileTransfers {
            if let id = transfer.file.metadata?["sessionID"] as? String,
               let uuid = UUID(uuidString: id) {
                adopted.insert(uuid)
            }
        }
        for transfer in WCSession.default.outstandingUserInfoTransfers {
            guard (transfer.userInfo["action"] as? String) == "saveSession" else { continue }
            if let id = transfer.userInfo["sessionID"] as? String,
               let uuid = UUID(uuidString: id) {
                adopted.insert(uuid)
            }
        }
        guard !adopted.isEmpty else { return }
        inFlightSessionIDs.formUnion(adopted)
        logger.info("Adopted \(adopted.count) outstanding WC transfer(s) from the daemon")
    }

    private func updateConnectivityHealth() {
        var healthScore = 1.0

        if WCSession.default.activationState != .activated {
            healthScore -= 0.5
        }
        if !WCSession.default.isReachable {
            healthScore -= 0.3
        }
        healthScore -= min(0.5, Double(consecutiveFailures) * 0.1)

        if let lastSync = lastSyncTime {
            if Date().timeIntervalSince(lastSync) > 300 {
                healthScore -= 0.2
            }
        } else {
            healthScore -= 0.2
        }

        healthScore = max(0, min(1, healthScore))

        if healthScore != connectivityHealth {
            connectivityHealth = healthScore
        }
    }

    // MARK: - Session Send Routing (pure, testable)

    /// Channel a session payload must travel on. `transferFile` has no practical
    /// size cap; the dictionary channels are hard-capped by WatchConnectivity.
    enum SessionSendChannel: Equatable {
        /// transferUserInfo + sendMessage — only for payloads provably under the cap.
        case dualChannel
        /// transferFile (+ a lightweight lastSessionID tap) — the only channel that
        /// can carry a long GPS workout.
        case fileTransfer
    }

    /// WatchConnectivity rejects any `sendMessage` / `transferUserInfo` dictionary
    /// larger than this with WCError.payloadTooLarge. Applies to BOTH channels —
    /// the pre-2026-07 code assumed transferUserInfo allowed 200 KB, which created
    /// a 65.5 KB–200 KB dead zone where the only channel attempted was guaranteed
    /// to fail (an 80-minute GPS run lands squarely in it). See
    /// docs/incidents/ + scratchpad measurement: 600 route points = 174,892 B base64.
    nonisolated static let wcDictionaryCapBytes = 65_536

    /// Bytes reserved for the other dictionary keys ("action", "sessionID",
    /// "timestamp") plus WCSession's own plist framing. Generous on purpose —
    /// overshooting only sends a borderline session via file transfer, which is
    /// always correct; undershooting loses the workout.
    nonisolated static let wcDictionaryOverheadBytes = 5_536

    /// Largest base64 body we will put inside a WC dictionary (60,000 B).
    nonisolated static let maxInlinePayloadBytes = wcDictionaryCapBytes - wcDictionaryOverheadBytes

    /// Exact base64 length for `n` raw bytes — `((n + 2) / 3) * 4`, padding included.
    /// Replaces the old `Double(n) * 1.34` estimate, which was both inexact and
    /// compared against the wrong ceiling.
    nonisolated static func base64Length(forRawBytes n: Int) -> Int {
        ((n + 2) / 3) * 4
    }

    /// Routing decision for an encoded session. Pure — depends only on byte count,
    /// so every entry point (fresh save, retryPendingSessions, sendAllStoredSessions,
    /// requestAllSessions overflow, payloadTooLarge escalation) gets the same answer.
    nonisolated static func channel(forRawJSONBytes n: Int) -> SessionSendChannel {
        base64Length(forRawBytes: n) > maxInlinePayloadBytes ? .fileTransfer : .dualChannel
    }

    // MARK: - Session Sending

    func sendSessionToiOS(_ session: TrainingSession) {
        // Anti-stacking guard: a transfer for this session is still sitting in the
        // WC daemon's outbox. Re-sending it now would add a duplicate payload to a
        // queue that is already backed up — the exact behaviour that turned a cold
        // launch into a multi-minute sync storm. The session stays in
        // `pendingSessions`, so the next retry tick after didFinish resends it.
        guard !inFlightSessionIDs.contains(session.id) else {
            logger.info("Send skipped for session \(session.id) — transfer still in flight")
            return
        }
        logger.info("Sending training session to iOS...")
        // Claim the session NOW, synchronously on the main actor — not after the
        // encode. The encode below takes 150–500ms for a GPS session, and the retry
        // tick / burst fire on that same timescale; claiming late leaves a window
        // where two sends both pass the guard.
        inFlightSessionIDs.insert(session.id)
        // App Group write is already on sessionStoreQueue (background).
        saveSessionToAppGroup(session)

        // JSON encoding can take 150–500ms for large GPS sessions — must not run
        // on @MainActor. Encode on a utility thread, hop back to main only for
        // the WCSession dispatch calls that require it.
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            do {
                let sessionData = try JSONEncoder().encode(session)
                // Exact base64 size — no allocation of the string needed.
                let payloadSize = Self.base64Length(forRawBytes: sessionData.count)
                let channel = Self.channel(forRawJSONBytes: sessionData.count)
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    // Field-evidence hook: this line identifies the payload size and the
                    // channel actually chosen. Grep "Session payload:" in a watch sysdiagnose.
                    self.logger.info("Session payload: \(payloadSize) bytes base64 (\(sessionData.count) B raw, \(session.route?.count ?? 0) route points) → \(channel == .fileTransfer ? "transferFile" : "userInfo+message")")
                    switch channel {
                    case .fileTransfer:
                        self.sendSessionViaFileTransfer(session, sessionData: sessionData)
                    case .dualChannel:
                        let base64 = sessionData.base64EncodedString()
                        self.sendSessionViaUserInfo(session, sessionData: sessionData)
                        self.sendSessionViaMessage(session, base64: base64)
                    }
                    // lastSessionID tap-on-shoulder is sent only for file-transfer sessions.
                    // For the dual-channel path the full session payload travels the same
                    // FIFO channel and carries the ID itself — the tap is redundant there,
                    // and placing it here (called from 8+ retry/burst sites) would flood
                    // the persistent transferUserInfo queue during offline periods.
                    // See sendSessionViaFileTransfer for where the tap is actually queued.
                    self.scheduleFinishRetryBurst()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.logger.error("Failed to encode session: \(error.localizedDescription)")
                    // Nothing was enqueued — release the claim so the retry tick
                    // can try again.
                    self.inFlightSessionIDs.remove(session.id)
                    self.queuePendingSession(session)
                }
            }
        }
    }

    private func scheduleFinishRetryBurst() {
        // Single-flight: if a burst is already in flight, don't queue another.
        // Otherwise a chain of sendSessionToiOS calls from retryPendingSessions
        // would compound bursts exponentially.
        guard !isBurstScheduled else { return }
        isBurstScheduled = true
        let delays: [TimeInterval] = [1, 3, 8]
        for (index, delay) in delays.enumerated() {
            let isLast = index == delays.count - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.retryPendingSessions()
                if isLast { self?.isBurstScheduled = false }
            }
        }
    }

    private func sendSessionViaFileTransfer(_ session: TrainingSession, sessionData: Data) {
        // File write of large data (>200KB) must not run on main — it can take 50–200ms.
        // queuePendingSession happens immediately on main (fast), file write is background.
        queuePendingSession(session)
        // Mark in-flight synchronously (before the background write) so a retry
        // tick landing during the write can't enqueue a second transfer.
        inFlightSessionIDs.insert(session.id)
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "session_\(session.id.uuidString).json"
        let fileURL = tempDir.appendingPathComponent(fileName)
        let logger = self.logger
        Task.detached(priority: .utility) { [weak self] in
            do {
                try sessionData.write(to: fileURL, options: [.atomic, .completeFileProtection])
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    let metadata: [String: Any] = [
                        "action": "saveSession",
                        "sessionID": session.id.uuidString,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                    WCSession.default.transferFile(fileURL, metadata: metadata)
                    // S-5: transferFile and transferUserInfo are independent channels with
                    // no ordering guarantee — iOS may not learn the session ID from the
                    // file metadata alone before the dedup window closes. Send a lightweight
                    // tap-on-shoulder so the phone can request a pull if it's missing the ID.
                    // This is the only site that queues this transfer; all other paths (userInfo,
                    // message) carry the session ID inline in the same ordered channel.
                    WCSession.default.transferUserInfo([
                        "action": "lastSessionID",
                        "sessionID": session.id.uuidString,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                    self.logger.info("Session queued via transferFile (\(sessionData.count) bytes)")
                    self.updateSyncStatus("Large session queued for file transfer")
                }
            } catch {
                logger.error("Failed to write temp file for transfer: \(error.localizedDescription)")
                // No transfer was enqueued, so no didFinish will ever arrive —
                // release the in-flight marker or this session is stuck forever.
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.inFlightSessionIDs.remove(session.id)
                }
            }
        }
    }

    /// True when WatchConnectivity rejected the payload for exceeding the dictionary
    /// cap. This is permanent for a given payload — retrying the same channel with the
    /// same bytes can never succeed, so callers must switch channels, not re-queue.
    /// Checked via both the bridged WCError and the raw NSError domain/code so a
    /// bridging change can't silently disable the escalation.
    nonisolated static func isPayloadTooLarge(_ error: Error) -> Bool {
        if let wcError = error as? WCError, wcError.code == .payloadTooLarge { return true }
        let nsError = error as NSError
        return nsError.domain == WCErrorDomain && nsError.code == WCError.Code.payloadTooLarge.rawValue
    }

    /// Re-encode off the main actor and hand the session to the uncapped file channel.
    /// Used when a dictionary-channel transfer came back as payloadTooLarge.
    private func escalateToFileTransfer(_ session: TrainingSession) {
        // Same reasoning as sendSessionToiOS: claim before the async re-encode so a
        // retry tick can't slip a duplicate through the window.
        inFlightSessionIDs.insert(session.id)
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            do {
                let sessionData = try JSONEncoder().encode(session)
                await MainActor.run { [weak self] in
                    self?.sendSessionViaFileTransfer(session, sessionData: sessionData)
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.logger.error("Failed to re-encode session for file-transfer escalation: \(error.localizedDescription)")
                    self.inFlightSessionIDs.remove(session.id)
                    self.queuePendingSession(session)
                }
            }
        }
    }

    private func sendSessionViaUserInfo(_ session: TrainingSession, sessionData: Data) {
        let userInfo: [String: Any] = [
            "action": "saveSession",
            "sessionData": sessionData.base64EncodedString(),
            "timestamp": Date().timeIntervalSince1970,
            "sessionID": session.id.uuidString
        ]

        inFlightSessionIDs.insert(session.id)
        WCSession.default.transferUserInfo(userInfo)
        logger.info("Session queued via transferUserInfo")
        updateSyncStatus("Session queued for background sync")
    }

    private func sendSessionViaMessage(_ session: TrainingSession, base64: String) {
        guard WCSession.default.isReachable else {
            queuePendingSession(session)
            return
        }
        let message: [String: Any] = [
            "action": "saveSession",
            "sessionData": base64,
            "timestamp": Date().timeIntervalSince1970
        ]
        WCSession.default.sendMessage(message, replyHandler: { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.info("Session sent via sendMessage")
                self.updateSyncStatus("Session saved to iPhone")
                self.consecutiveFailures = 0
                self.lastSyncTime = Date()
                self.removePendingSession(session.id)
                self.updateConnectivityHealth()
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.error("sendMessage failed: \(error.localizedDescription)")
                self.consecutiveFailures += 1
                self.queuePendingSession(session)
                self.updateConnectivityHealth()
            }
        })
    }

    private func queuePendingSession(_ session: TrainingSession) {
        if !pendingSessions.contains(where: { $0.id == session.id }) {
            pendingSessions.append(session)
            savePendingSessionsToDisk()
            logger.warning("Session queued to disk for retry")
            updateSyncStatus("Session queued for sync")
        }
    }

    // MARK: - Pending Sessions Persistence

    private func removePendingSession(_ id: UUID) {
        pendingSessions.removeAll { $0.id == id }
        savePendingSessionsToDisk()
    }

    private func savePendingSessionsToDisk() {
        guard let containerURL = Self.getWorkingContainer() else { return }
        // Capture value types on @MainActor; encode + write on background.
        let sessions = pendingSessions
        let url = containerURL.appendingPathComponent(pendingSessionsFileName)
        let logger = self.logger
        Task.detached(priority: .utility) {
            do {
                if sessions.isEmpty {
                    try? FileManager.default.removeItem(at: url)
                } else {
                    let data = try JSONEncoder().encode(sessions)
                    try data.write(to: url, options: [.atomic, .completeFileProtection])
                }
            } catch {
                logger.error("Failed to save pending sessions: \(error.localizedDescription)")
            }
        }
    }

    /// Loads pending sessions + templates off the main thread. Called once at startup.
    /// Both files are read concurrently on a background task; results are assigned
    /// on @MainActor after the await.
    private func loadPendingSessionsAndTemplates() async {
        guard let containerURL = Self.getWorkingContainer() else {
            loadFallbackTemplates()
            return
        }
        let pendingURL = containerURL.appendingPathComponent(pendingSessionsFileName)
        let templatesURL = containerURL.appendingPathComponent("workout_templates.json")

        let (pending, templates) = await Task.detached(priority: .utility) {
            var pending: [TrainingSession] = []
            var templates: [WorkoutTemplate] = []
            if FileManager.default.fileExists(atPath: pendingURL.path),
               let data = try? Data(contentsOf: pendingURL),
               let loaded = try? JSONDecoder().decode([TrainingSession].self, from: data) {
                pending = loaded
            }
            if FileManager.default.fileExists(atPath: templatesURL.path),
               let data = try? Data(contentsOf: templatesURL),
               let loaded = try? JSONDecoder().decode([WorkoutTemplate].self, from: data) {
                templates = loaded
            }
            return (pending, templates)
        }.value

        if !pending.isEmpty {
            pendingSessions = pending
            logger.info("Loaded \(pending.count) pending session(s) from disk")
        }
        if templates.isEmpty {
            loadFallbackTemplates()
        } else {
            workoutTemplates = templates
            logger.info("Loaded \(templates.count) template(s) from disk")
        }
    }

    // MARK: - App Group Storage

    /// Serial background queue for sessions.json read-append-write. The full
    /// decode + re-encode of workout history must never run on the main actor —
    /// at workout stop it stalls the UI for a time that grows with history
    /// (freeze root-cause H2).
    private nonisolated static let sessionStoreQueue = DispatchQueue(label: "com.shuttlx.watch-session-store", qos: .utility)

    private func saveSessionToAppGroup(_ session: TrainingSession) {
        guard let containerURL = Self.getWorkingContainer() else {
            logger.error("Failed to get App Group container URL")
            return
        }
        let logger = self.logger
        Self.sessionStoreQueue.async {
            Self.appendSessionToStore(session, containerURL: containerURL, logger: logger)
        }
    }

    private nonisolated static func appendSessionToStore(_ session: TrainingSession, containerURL: URL, logger: Logger) {
        let sessionsURL = containerURL.appendingPathComponent("sessions.json")
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        // Set only when a genuinely new session lands on disk. Every retry path
        // funnels through here, so reloading timelines unconditionally fired
        // widget-extension IPC dozens of times per sync cycle for no change at all.
        var didInsert = false

        // Read-then-write under a single write coordination to prevent races
        coordinator.coordinate(writingItemAt: sessionsURL, options: .forReplacing, error: &coordinatorError) { writeURL in
            var sessions: [TrainingSession] = []

            // Read existing sessions if the file exists (using the coordinator-provided URL)
            if FileManager.default.fileExists(atPath: writeURL.path) {
                do {
                    let data = try Data(contentsOf: writeURL)
                    sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
                } catch {
                    logger.error("CRITICAL: Failed to decode sessions.json on watch: \(error.localizedDescription)")
                    // Preserve corrupt file — don't overwrite workout history
                    let backupURL = writeURL.deletingLastPathComponent()
                        .appendingPathComponent("sessions_corrupt_\(Int(Date().timeIntervalSince1970)).json")
                    try? FileManager.default.copyItem(at: writeURL, to: backupURL)
                    logger.error("Backed up corrupt sessions.json to \(backupURL.lastPathComponent)")
                    Self.purgeOldCorruptBackups(in: writeURL.deletingLastPathComponent(), logger: logger)
                    // Continue with empty array — better to have one session than lose all
                }
            }

            guard !sessions.contains(where: { $0.id == session.id }) else { return }
            sessions.append(session)

            do {
                let data = try JSONEncoder().encode(sessions)
                try data.write(to: writeURL, options: [.atomic, .completeFileProtection])
                didInsert = true
                logger.info("Session saved to App Group")
            } catch {
                logger.error("Failed to save session to App Group: \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            logger.error("File coordination error saving session to App Group: \(coordinatorError.localizedDescription)")
        } else if didInsert {
            // Called outside the coordinator block — IPC to widget extension
            // must not hold the file coordination lock. Only fired when the store
            // actually changed (dedup hit / encode failure ⇒ nothing to reload).
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isConnected = (activationState == .activated)

            if let error = error {
                self.logger.error("WCSession activation failed: \(error.localizedDescription)")
                self.updateSyncStatus("Connection failed")
                self.consecutiveFailures += 1
            } else if activationState == .activated {
                self.logger.info("WCSession activated")
                self.updateSyncStatus("Connected to iPhone")
                self.consecutiveFailures = 0

                // Adopt whatever the WC daemon still holds from the previous launch
                // so we don't enqueue a second copy of it below.
                self.reconcileInFlightTransfers()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    Task { @MainActor in
                        // NOTE: sendAllStoredSessions() used to run here, re-sending
                        // EVERY session from the last 24h on every single cold launch.
                        // That is the cold-launch sync storm: dozens of redundant
                        // transfers saturating wcd (and, through the main-actor
                        // delegate hops, the display tick) for minutes. Reconciliation
                        // is already covered by the phone-side "requestAllSessions"
                        // pull and "reconcileSessions" diff, both of which only move
                        // sessions the phone is actually missing.
                        self?.retryPendingSessions()
                    }
                }
            }

            self.updateConnectivityHealth()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isConnected = session.isReachable || session.activationState == .activated
            if session.isReachable {
                self.updateSyncStatus("iPhone became reachable")
                self.retryPendingSessions()

                // Throttle full resend to once per 60 seconds to prevent burst transfers
                // during Bluetooth reconnect flicker in active workouts
                let now = Date()
                if self.lastFullResendTime.map({ now.timeIntervalSince($0) > 60 }) ?? true {
                    await self.sendAllStoredSessions()
                    self.lastFullResendTime = now
                }
            } else {
                self.updateSyncStatus("iPhone not reachable")
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let action = message["action"] as? String {
                switch action {
                case "ping":
                    self.logger.info("Ping received from iPhone")
                    self.updateSyncStatus("Connection verified")
                    self.consecutiveFailures = 0
                case "workoutControl":
                    let command = message["command"] as? String ?? ""
                    switch command {
                    case "pause":  self.workoutManager?.pauseWorkout()
                    case "resume": self.workoutManager?.resumeWorkout()
                    case "stop":
                        // Remote stop MUST call saveWorkoutData() before stopWorkout().
                        // The watch-side stop button always calls save → stop in sequence.
                        // A bare stopWorkout() here would discard all session data because
                        // stopWorkout() only tears down state — it never calls save itself.
                        if let wm = self.workoutManager, wm.isWorkoutActive {
                            wm.saveWorkoutData()
                            wm.pendingSummary = wm.buildCurrentSummary()
                            wm.stopWorkout()
                        }
                    case "start":
                        self.handleRemoteStart(message: message)
                    default: break
                    }
                case "syncTheme", "syncTemplates", "syncMaxHR":
                    self.handleIncomingPayload(message)
                default:
                    break
                }
            }
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Reply to lightweight pings synchronously — WC times out replies that
        // come back too late (~5s undocumented), and if the main actor is busy
        // (heavy JSON decode of 50+ sessions, etc.) the deferred Task could miss
        // the window. Heavier branches stay inside the Task because they need
        // main-actor state.
        if let action = message["action"] as? String, action == "ping" {
            replyHandler(["status": "alive", "timestamp": Date().timeIntervalSince1970])
            Task { @MainActor [weak self] in
                self?.updateSyncStatus("Connection verified")
                self?.consecutiveFailures = 0
                self?.updateConnectivityHealth()
            }
            return
        }

        // Session-bulk requests never touch the main actor for their heavy work:
        // reading sessions.json and JSON-encoding every session (GPS routes
        // included) costs hundreds of ms and used to run inside a @MainActor Task,
        // stalling the 1 Hz display tick. WCSession's reply/transfer APIs are
        // thread-safe, so only the @Published status mutations hop back to main.
        if let action = message["action"] as? String, action == "requestAllSessions" {
            Task.detached(priority: .utility) { [weak self] in
                guard let self = self else {
                    replyHandler(["status": "empty", "count": 0])
                    return
                }
                await self.handleRequestAllSessions(replyHandler: replyHandler)
            }
            return
        }

        if let action = message["action"] as? String, action == "reconcileSessions" {
            let knownIDs = Set((message["knownSessionIDs"] as? [String]) ?? [])
            Task.detached(priority: .utility) { [weak self] in
                guard let self = self else {
                    replyHandler(["status": "in_sync", "missingCount": 0])
                    return
                }
                await self.handleReconcileSessions(knownIDs: knownIDs, replyHandler: replyHandler)
            }
            return
        }

        Task { @MainActor in
            if let action = message["action"] as? String {
                switch action {
                case "ping":
                    // Already handled above; unreachable but keeps the switch exhaustive.
                    replyHandler(["status": "alive", "timestamp": Date().timeIntervalSince1970])
                    self.updateSyncStatus("Connection verified")
                    self.consecutiveFailures = 0
                case "workoutControl":
                    let command = message["command"] as? String ?? ""
                    switch command {
                    case "pause":  self.workoutManager?.pauseWorkout()
                    case "resume": self.workoutManager?.resumeWorkout()
                    case "stop":
                        if let wm = self.workoutManager, wm.isWorkoutActive {
                            wm.saveWorkoutData()
                            wm.pendingSummary = wm.buildCurrentSummary()
                            wm.stopWorkout()
                        }
                    case "start":
                        self.handleRemoteStart(message: message)
                    default: break
                    }
                    replyHandler(["status": "ok"])
                case "syncTheme", "syncTemplates", "syncMaxHR":
                    self.handleIncomingPayload(message)
                    replyHandler(["status": "received"])
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
            // Release the in-flight marker first — on BOTH success and failure.
            // On failure the session stays in pendingSessions, so the next retry
            // tick resends it; keeping the marker set would strand it forever.
            // Only "saveSession" transfers own the marker: the lightweight
            // "lastSessionID" tap carries the same sessionID but must not release
            // the marker held by an in-flight file transfer.
            if (userInfoTransfer.userInfo["action"] as? String) == "saveSession",
               let sessionID = userInfoTransfer.userInfo["sessionID"] as? String,
               let uuid = UUID(uuidString: sessionID) {
                self.inFlightSessionIDs.remove(uuid)
            }
            if let error = error {
                self.logger.error("UserInfo transfer failed: \(error.localizedDescription)")
                self.consecutiveFailures += 1
                if let sessionID = userInfoTransfer.userInfo["sessionID"] as? String,
                   let uuid = UUID(uuidString: sessionID) {
                    let allSessions = await self.loadAllLocalSessions()
                    if let session = allSessions.first(where: { $0.id == uuid }) {
                        if Self.isPayloadTooLarge(error) {
                            // PERMANENT error — re-queueing for an identical retry would
                            // loop forever (every 15s, never delivering). Escalate to the
                            // uncapped file channel instead. This is the self-healing net
                            // for any payload that slips past the size routing above.
                            self.logger.error("UserInfo transfer rejected as payloadTooLarge — escalating session \(uuid) to file transfer")
                            self.escalateToFileTransfer(session)
                        } else {
                            // Transient (unreachable phone, etc.) — normal retry path.
                            self.queuePendingSession(session)
                        }
                    }
                }
            } else {
                self.logger.info("UserInfo transfer completed")
                self.consecutiveFailures = 0
                self.lastSyncTime = Date()

                // Remove from pending if it was a session transfer
                if let sessionID = userInfoTransfer.userInfo["sessionID"] as? String,
                   let uuid = UUID(uuidString: sessionID) {
                    self.removePendingSession(uuid)
                }
            }
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in
            // Release the in-flight marker on both success and failure (see the
            // userInfo didFinish above for the rationale).
            if let sessionID = fileTransfer.file.metadata?["sessionID"] as? String,
               let uuid = UUID(uuidString: sessionID) {
                self.inFlightSessionIDs.remove(uuid)
            }
            if let error = error {
                self.logger.error("File transfer failed: \(error.localizedDescription)")
                self.consecutiveFailures += 1
                if let sessionID = fileTransfer.file.metadata?["sessionID"] as? String,
                   let uuid = UUID(uuidString: sessionID) {
                    let allSessions = await self.loadAllLocalSessions()
                    if let session = allSessions.first(where: { $0.id == uuid }) {
                        self.queuePendingSession(session)
                    }
                }
            } else {
                self.logger.info("File transfer completed successfully")
                self.consecutiveFailures = 0
                self.lastSyncTime = Date()
                if let sessionID = fileTransfer.file.metadata?["sessionID"] as? String,
                   let uuid = UUID(uuidString: sessionID) {
                    self.removePendingSession(uuid)
                }
            }
            // Clean up temp file
            try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
            self.updateConnectivityHealth()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            // Workout controls arrive here via the transferUserInfo fallback channel.
            // They must NOT be processed from didReceiveApplicationContext — applicationContext
            // is last-write-wins and would replay a stale stop command on every reconnect.
            if let action = userInfo["action"] as? String, action == "workoutControl",
               let command = userInfo["command"] as? String {
                self.dispatchWorkoutControl(command: command, sentAt: userInfo["sentAt"] as? TimeInterval, message: userInfo)
                return  // dedicated payload — no other keys to process
            }
            self.handleIncomingPayload(userInfo)
        }
    }

    /// Dispatches a remote workout control command received via the guaranteed
    /// `transferUserInfo` channel. Guards against stale delivery: transferUserInfo is
    /// FIFO-queued and can arrive minutes later — a stop meant for a prior workout must
    /// not kill the next one.
    private func dispatchWorkoutControl(command: String, sentAt: TimeInterval?, message: [String: Any] = [:]) {
        // Discard if the command is older than 2 minutes — it's almost certainly stale.
        if let sentAt = sentAt, Date().timeIntervalSince1970 - sentAt > 120 {
            logger.warning("workoutControl '\(command)' via transferUserInfo discarded — stale (\(Int(Date().timeIntervalSince1970 - sentAt))s old)")
            return
        }
        logger.info("workoutControl '\(command)' dispatched via transferUserInfo fallback")
        switch command {
        case "pause":
            workoutManager?.pauseWorkout()
        case "resume":
            workoutManager?.resumeWorkout()
        case "stop":
            if let wm = workoutManager, wm.isWorkoutActive {
                wm.saveWorkoutData()
                wm.pendingSummary = wm.buildCurrentSummary()
                wm.stopWorkout()
            }
        case "start":
            // Stale window for start is tighter than stop — a late-arriving start
            // from transferUserInfo is almost certainly from a previous session.
            if let sentAt, Date().timeIntervalSince1970 - sentAt > 30 {
                logger.warning("workoutControl 'start' via transferUserInfo discarded — stale (\(Int(Date().timeIntervalSince1970 - sentAt))s old)")
            } else {
                handleRemoteStart(message: message)
            }
        default:
            logger.warning("workoutControl '\(command)' via transferUserInfo — unrecognised command")
        }
    }

    /// Starts a watch-side workout in response to a remote-start command from iPhone.
    /// Decodes the mode and optional template data from the message payload.
    private func handleRemoteStart(message: [String: Any]) {
        guard let wm = workoutManager, !wm.isWorkoutActive, !wm.isStarting else {
            logger.info("handleRemoteStart ignored — workout already active or starting")
            return
        }
        let mode = message["mode"] as? String ?? "freeRun"
        logger.info("Remote start received — mode=\(mode)")
        switch mode {
        case "interval":
            if let data = message["templateData"] as? Data,
               let template = try? JSONDecoder().decode(WorkoutTemplate.self, from: data) {
                wm.startIntervalWorkout(template: template)
            } else {
                logger.warning("Remote start 'interval' missing/invalid templateData — falling back to freeRun")
                wm.startWorkout()
            }
        case "gymRecovery":
            wm.startGymRecoveryWorkout()
        default:
            wm.startWorkout()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handleIncomingPayload(applicationContext)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.isConnected = false
            self.updateConnectivityHealth()
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.isConnected = false
            WCSession.default.activate()
            self.updateConnectivityHealth()
        }
    }
    #endif

    // MARK: - Bulk Session Sync

    /// Send all locally stored sessions to iPhone via size-aware routing
    func sendAllStoredSessions() async {
        let allSessions = await loadAllLocalSessions()
        guard !allSessions.isEmpty else { return }

        // Only resend sessions from the last 24 hours (not the entire history)
        let cutoff = Date().addingTimeInterval(-86400)
        let recentSessions = allSessions.filter { $0.startDate > cutoff }

        // Include older pending sessions that never delivered
        let pendingIDs = Set(pendingSessions.map { $0.id })
        let olderPending = allSessions.filter { pendingIDs.contains($0.id) && $0.startDate <= cutoff }

        let sessionsToSend = recentSessions + olderPending
        guard !sessionsToSend.isEmpty else { return }

        logger.info("Sending \(sessionsToSend.count) of \(allSessions.count) stored session(s) to iPhone")

        for session in sessionsToSend {
            sendSessionToiOS(session)
        }
        updateSyncStatus("Sent \(sessionsToSend.count) session(s) to iPhone")
    }

    /// Reads sessions.json off the main thread. NSFileCoordinator.coordinate is
    /// blocking — calling it on @MainActor causes visible freezes when iPhone
    /// reconnects during or after a workout.
    private func loadAllLocalSessions() async -> [TrainingSession] {
        let logger = self.logger
        return await Task.detached(priority: .utility) {
            Self.loadSessionsFromStore(logger: logger)
        }.value
    }

    /// Synchronous, nonisolated read of sessions.json. MUST be called off the main
    /// actor (NSFileCoordinator.coordinate blocks). Shared by the @MainActor
    /// `loadAllLocalSessions()` wrapper and the off-main WC request handlers.
    private nonisolated static func loadSessionsFromStore(logger: Logger) -> [TrainingSession] {
        guard let containerURL = getWorkingContainer() else { return [] }
        let url = containerURL.appendingPathComponent("sessions.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        var result: [TrainingSession] = []
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            do {
                let data = try Data(contentsOf: readURL)
                result = try JSONDecoder().decode([TrainingSession].self, from: data)
            } catch {
                logger.error("CRITICAL: Failed to decode sessions.json on watch: \(error.localizedDescription)")
                let backupURL = url.deletingLastPathComponent()
                    .appendingPathComponent("sessions_corrupt_\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.copyItem(at: readURL, to: backupURL)
                logger.error("Backed up corrupt sessions.json to \(backupURL.lastPathComponent)")
                purgeOldCorruptBackups(in: url.deletingLastPathComponent(), logger: logger)
            }
        }
        if let coordinatorError {
            logger.error("File coordination error loading sessions on watch: \(coordinatorError.localizedDescription)")
        }
        return result
    }

    // MARK: - Bulk Session Requests (executed off the main actor)

    /// Packs a "requestAllSessions" reply: inline sessions up to a CUMULATIVE byte
    /// budget; anything that doesn't fit is returned in `routed` for
    /// `sendSessionToiOS`, which applies the authoritative size routing
    /// (dual-channel vs file). sendMessage replies are capped at ~65KB for the whole
    /// dictionary and base64 inflates by 4/3, so 36KB of raw JSON keeps the reply
    /// safely under the ceiling no matter how many sessions are stored.
    /// NOTE: no separate per-session ceiling here — the cumulative budget already
    /// diverts every oversized session, and a second, larger threshold is exactly
    /// what created the old 65KB–200KB dead zone.
    /// Pure + nonisolated: every JSONEncoder pass (GPS routes included) runs off main.
    nonisolated static func planSessionsReply(_ sessions: [TrainingSession],
                                              inlineBudget: Int = 36_000)
    -> (reply: [String: Any], routed: [TrainingSession]) {
        var inlineSessions: [TrainingSession] = []
        var routed: [TrainingSession] = []
        var inlineBytes = 0
        let encoder = JSONEncoder()
        for s in sessions {
            let size = (try? encoder.encode(s))?.count ?? 0
            if inlineBytes + size > inlineBudget {
                routed.append(s)
            } else {
                inlineSessions.append(s)
                inlineBytes += size
            }
        }
        if let encoded = try? encoder.encode(inlineSessions) {
            return ([
                "status": "ok",
                "count": sessions.count,
                "sessionsData": encoded.base64EncodedString(),
                "oversizedCount": routed.count
            ], routed)
        }
        // Encoding failed — fall back to individual routing for everything.
        return (["status": "ok", "count": sessions.count, "oversizedCount": sessions.count],
                inlineSessions + routed)
    }

    /// Off-main handler for the iPhone's "requestAllSessions" pull.
    private nonisolated func handleRequestAllSessions(replyHandler: @escaping ([String: Any]) -> Void) async {
        let sessions = Self.loadSessionsFromStore(logger: logger)
        guard !sessions.isEmpty else {
            replyHandler(["status": "empty", "count": 0])
            await MainActor.run { self.updateConnectivityHealth() }
            return
        }
        let plan = Self.planSessionsReply(sessions)
        replyHandler(plan.reply)
        await MainActor.run {
            for s in plan.routed { self.sendSessionToiOS(s) }
            self.updateSyncStatus("Sent \(sessions.count) session(s) to iPhone (requested)")
            self.updateConnectivityHealth()
        }
    }

    /// Off-main handler for the iPhone's "reconcileSessions" diff.
    private nonisolated func handleReconcileSessions(knownIDs: Set<String>,
                                                     replyHandler: @escaping ([String: Any]) -> Void) async {
        let allSessions = Self.loadSessionsFromStore(logger: logger)
        let missingSessions = allSessions.filter { !knownIDs.contains($0.id.uuidString) }
        guard !missingSessions.isEmpty else {
            replyHandler(["status": "in_sync", "missingCount": 0])
            await MainActor.run { self.updateConnectivityHealth() }
            return
        }
        replyHandler(["status": "resending", "missingCount": missingSessions.count])
        await MainActor.run {
            self.logger.info("iPhone missing \(missingSessions.count) session(s) — resending")
            for session in missingSessions {
                self.sendSessionToiOS(session)
            }
            self.updateConnectivityHealth()
        }
    }

    // MARK: - Template Sync

    private func handleIncomingPayload(_ payload: [String: Any]) {
        // Process subscription status if present
        if let proStatus = payload["isPro"] as? Bool {
            isPro = proStatus
            logger.info("Subscription status synced from iPhone: \(proStatus ? "Pro" : "Free")")
        }

        // Process theme if present (regardless of action key — applicationContext
        // merges both theme and template data with a single action key)
        if let themeID = payload["themeID"] as? String {
            ThemeManager.shared.selectTheme(themeID)
            logger.info("Theme synced from iPhone: \(themeID)")
        }

        // Process max HR override if present
        if let maxHR = payload["maxHR"] as? Double {
            if maxHR > 0 {
                HeartRateZoneCalculator.saveMaxHR(maxHR)
                logger.info("Max HR synced from iPhone: \(Int(maxHR)) BPM")
            } else {
                // 0 means "clear manual override"
                HeartRateZoneCalculator.saveMaxHR(0)
                logger.info("Max HR override cleared by iPhone")
            }
        }

        // Process templates if present
        if let base64 = payload["templatesData"] as? String,
           let data = Data(base64Encoded: base64) {
            do {
                let templates = try JSONDecoder().decode([WorkoutTemplate].self, from: data)
                workoutTemplates = templates
                saveTemplatesToDisk(templates)
                logger.info("Received \(templates.count) template(s) from iPhone")
                updateSyncStatus("Synced \(templates.count) program(s)")
            } catch {
                logger.error("Failed to decode templates: \(error.localizedDescription)")
            }
        }
    }

    private func saveTemplatesToDisk(_ templates: [WorkoutTemplate]) {
        guard let containerURL = Self.getWorkingContainer() else { return }
        let url = containerURL.appendingPathComponent("workout_templates.json")
        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            logger.error("Failed to save templates to disk: \(error.localizedDescription)")
        }
    }

    /// Provides a default interval template when no iPhone-synced templates are available
    private func loadFallbackTemplates() {
        guard workoutTemplates.isEmpty else { return }
        workoutTemplates = [
            WorkoutTemplate(
                name: "Quick Intervals",
                intervals: [
                    IntervalStep(type: .work, duration: 60, label: "Run"),
                    IntervalStep(type: .rest, duration: 30, label: "Walk")
                ],
                repeatCount: 5,
                warmup: IntervalStep(type: .warmup, duration: 120, label: "Warm Up"),
                cooldown: IntervalStep(type: .cooldown, duration: 120, label: "Cool Down")
            )
        ]
        logger.info("Loaded fallback template (no iPhone sync available)")
    }

    // MARK: - Helpers

    private nonisolated static func purgeOldCorruptBackups(in directory: URL, logger: Logger) {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for file in files where file.lastPathComponent.hasPrefix("sessions_corrupt_") {
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantFuture
            if created < cutoff {
                try? FileManager.default.removeItem(at: file)
                logger.info("Removed stale corrupt backup: \(file.lastPathComponent)")
            }
        }
    }

    /// nonisolated so the off-main session loaders can resolve the container
    /// without a main-actor hop (it only reads a static constant).
    private nonisolated static func getWorkingContainer() -> URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return container
        }
        // Fallback for simulator or missing entitlement
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fallback = docsURL.appendingPathComponent("SharedData")
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    private func updateSyncStatus(_ status: String) {
        syncStatus = status
        let timestamp = DateFormatter.shortDateTime.string(from: Date())
        syncLog.insert("[\(timestamp)] \(status)", at: 0)
        if syncLog.count > 20 {
            syncLog = Array(syncLog.prefix(20))
        }
        logger.info("Sync status: \(status)")
    }

    // MARK: - Debug

    func checkConnectivity() -> String {
        let session = WCSession.default
        return """
        Activation State: \(session.activationState.rawValue)
        Reachable: \(session.isReachable)
        Connectivity Health: \(Int(connectivityHealth * 100))%
        Pending Sessions: \(pendingSessions.count)
        Consecutive Failures: \(consecutiveFailures)
        """
    }

    func forceSyncNow() {
        retryPendingSessions()

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                ["action": "ping", "timestamp": Date().timeIntervalSince1970],
                replyHandler: { [weak self] _ in
                    Task { @MainActor in
                        self?.updateSyncStatus("Connection verified")
                        self?.consecutiveFailures = 0
                        self?.updateConnectivityHealth()
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
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}
