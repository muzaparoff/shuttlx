import Foundation
import Combine
import HealthKit
import WidgetKit
import TelemetryDeck
import os.log
import ShuttlXShared

@MainActor
class DataManager: ObservableObject {
    /// Recorded sessions exactly as stored. Persistence, CloudKit and sync use this; never write `effectiveSessions` back.
    @Published var sessions: [TrainingSession] = [] { didSet { rebuildEffective() } }
    /// `sessions` with the user's "Fix a part" edits applied (types, split, merge, Rest calories zeroed).
    /// Every reader (Today, History, Trends, Analytics, detail) uses this; rebuilt on any change to either input.
    @Published private(set) var effectiveSessions: [TrainingSession] = []
    /// Bumps on every rebuild; cheap `.task(id:)` key for screens that derive from `effectiveSessions`.
    private(set) var effectiveVersion = 0
    @Published var healthKitAuthorized = false
    /// The user switched Health sharing off for ShuttlX: the system sheet can no longer be shown again.
    @Published private(set) var healthAccessDenied = false
    /// Health has not been asked yet for the types the Health import reads (existing users after an update).
    @Published private(set) var healthReadAccessNeeded = false
    /// One-line, user-visible storage problem (unreadable history, skipped records). Settings shows it.
    @Published private(set) var storageNotice: String?
    /// True when sessions.json was unreadable as a whole: it is left untouched and no save runs until the
    /// user chooses to start fresh (`resumeSavingAfterCorruption`). Received sessions wait in the inbox.
    @Published private(set) var savesBlockedByCorruption = false

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "DataManager")

    private var processedSessionIds = Set<UUID>()
    private var cancellables = Set<AnyCancellable>()
    /// Serial queue for sessions.json reads — decode cost grows with history
    /// size and the load runs on every app resume, so it must stay off-main.
    private nonisolated static let storeQueue = DispatchQueue(label: "com.shuttlx.datamanager-store", qos: .utility)
    private let healthStore = HKHealthStore()
    private var cloudSyncDebounceTask: Task<Void, Never>?

    // Save state. This class is the ONLY writer of sessions.json.
    private var hasLoadedOnce = false
    private var isLoading = false
    private var isWriting = false
    private var savePending = false
    /// Bumped by a wipe so a load that was already reading the old file cannot bring the data back.
    private var wipeEpoch = 0

    // MARK: - App Group Properties
    private let sessionsKey = "sessions.json"
    private let archiveKey = "sessions_archive.json"
    /// Active-history cap. Overflow is archived oldest-first — newest workouts are never dropped.
    private let sessionCap = 500
    /// Eviction waits until the list is this far over the cap, then trims back to the cap: the archive file is
    /// re-read and rewritten once per ~50 sessions instead of on every new session.
    private let evictionSlack = 50
    private let appGroupIdentifier = "group.com.shuttlx.shared"

    init() {
        loadSessionsFromAppGroup()
        checkHealthKitAuthorizationStatus()
        PhoneSyncCoordinator.shared.setDataManager(self)
        setupBindings()
        // `$edits` emits before the value lands, so rebuild from the emitted value.
        SegmentOverrideStore.shared.$edits
            .sink { [weak self] in self?.rebuildEffective($0) }
            .store(in: &cancellables)
    }

    private func rebuildEffective(_ given: SegmentEdits? = nil) {
        let edits = given ?? SegmentOverrideStore.shared.edits
        effectiveVersion &+= 1
        // Most users have no edits: share the array instead of mapping every session.
        guard !(edits.types.isEmpty && edits.partitions.isEmpty) else {
            effectiveSessions = sessions
            return
        }
        effectiveSessions = sessions.map { session in
            guard let e = edits.effective(segments: session.segments, calories: session.caloriesBurned, sessionID: session.id)
            else { return session }
            var s = session
            s.segments = e.segments
            s.caloriesBurned = e.calories
            return s
        }
    }

    #if DEBUG
    // MARK: - Demo Mode (screenshot seam, SHUTTLX_DEMO_DATA=1)

    /// When true, the session list is seeded demo data held in memory only:
    /// `saveSessionsToAppGroup`, `loadSessionsFromAppGroup`, and disk-merge
    /// all no-op, so a demo run can never corrupt (or leak into) the real
    /// user's sessions.json in the App Group.
    private(set) var isDemoDataMode = false

    /// Swaps the in-memory session list for the seeded demo sessions and
    /// blocks all further disk persistence. A disk load kicked off by `init`
    /// may still be in flight; `mergeLoadedSessions` checks the flag on the
    /// main actor, so its result is discarded once demo mode is active.
    func activateDemoMode(sessions demoSessions: [TrainingSession]) {
        isDemoDataMode = true
        sessions = demoSessions
        processedSessionIds = Set(demoSessions.map { $0.id })
        logger.info("Demo mode active: seeded \(demoSessions.count) in-memory sessions; disk persistence disabled")
    }
    #endif

    private func setupBindings() {
        // PhoneSyncCoordinator forwards received sessions directly; this only picks up anything it relayed
        // before the DataManager existed. `handleReceivedSessions` dedupes by id.
        PhoneSyncCoordinator.shared.$syncedSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] receivedSessions in
                self?.handleReceivedSessions(receivedSessions)
            }
            .store(in: &cancellables)
    }

    /// True once this session id has been ingested (active list, archive, or dropped by the clear cutoff).
    func hasSession(_ id: UUID) -> Bool { processedSessionIds.contains(id) }

    /// Single entry for every new session (watch, iPhone workout, Health import, iCloud pull, inbox).
    /// One `sessions` assignment per call, so the effective list is rebuilt once per batch.
    func handleReceivedSessions(_ receivedSessions: [TrainingSession]) {
        let cutoff = SessionIngestRules.clearedAt()
        var knownIDs = Set(sessions.map { $0.id })
        var fresh: [TrainingSession] = []
        var droppedIDs = Set<UUID>()
        var replacedAny = false
        for received in receivedSessions {
            var session = received
            let end = session.endDate ?? session.startDate.addingTimeInterval(session.duration)
            let stale = SessionIngestRules.isStale(end: end, clearedAt: cutoff)

            // A watch session replaces its Health-imported copy (same id) and the phone's own placeholder
            // of the same workout. Effort answers carry over.
            var supersededPlaceholder = false
            if !stale, session.importedFromHealth != true {
                let incoming = Self.mergeItem(session, placeholder: false)
                let victims = sessions.filter { SessionMerge.replaces(incoming: incoming, existing: Self.mergeItem($0, placeholder: isPhonePlaceholder($0.id))) }
                if !victims.isEmpty {
                    session.effortRPE = SessionMerge.carriedEffort(incoming: session.effortRPE, replaced: victims.map(\.effortRPE))
                    let ids = Set(victims.map(\.id))
                    supersededPlaceholder = victims.contains { isPhonePlaceholder($0.id) }
                    sessions.removeAll { ids.contains($0.id) }
                    knownIDs.subtract(ids)
                    processedSessionIds.remove(session.id)   // an imported copy shared this id; the watch version may enter
                    replacedAny = true
                    logger.info("Watch session \(session.id) replaced \(victims.count) earlier copy(ies)")
                }
            }

            guard !processedSessionIds.contains(session.id) else { continue }
            processedSessionIds.insert(session.id)

            if stale {
                droppedIDs.insert(session.id)
                continue
            }
            guard knownIDs.insert(session.id).inserted else { continue }

            // An effort answer can beat its session to the phone; apply it now.
            if let rpe = pendingEffort.take(sessionId: session.id.uuidString) {
                session.effortRPE = rpe
                savePendingEffort()
            }
            fresh.append(session)
            // Sessions imported from Apple Health are history, not a workout just finished:
            // only watch/phone-originated sessions send telemetry or count toward the rating prompt.
            // A watch session that replaced the phone's placeholder is the same workout: counted once.
            if session.importedFromHealth != true, !supersededPlaceholder {
                trackWorkoutCompleted(session)
                // A completed workout landing on the iPhone is a "happy moment" —
                // the guarded prompt decides if/when to actually ask for a rating.
                FeedbackPrompt.recordHappyMoment()
            }
        }
        if !droppedIDs.isEmpty {
            logger.info("Ignored \(droppedIDs.count) session(s) from before the last clear")
            acknowledgeInbox(droppedIDs)
        }
        guard !fresh.isEmpty else {
            if replacedAny { saveSessionsToAppGroup() }
            return
        }

        var all = sessions + fresh
        let evicted = Self.evictOldest(from: &all, cap: sessionCap, slack: evictionSlack)
        sessions = all
        if !evicted.isEmpty {
            appendToArchive(evicted)
            logger.warning("Session cap \(self.sessionCap) exceeded — archived \(evicted.count) oldest session(s)")
        }
        saveSessionsToAppGroup()
    }

    // MARK: - Phone placeholders (iPhone workout that the watch recorded too)

    private static let placeholderKey = "phonePlaceholderSessionIDs"

    private static func mergeItem(_ s: TrainingSession, placeholder: Bool) -> SessionMerge.Item {
        SessionMerge.Item(id: s.id, start: s.startDate, end: s.endDate ?? s.startDate.addingTimeInterval(s.duration),
                          importedFromHealth: s.importedFromHealth == true, isPhonePlaceholder: placeholder)
    }

    private func isPhonePlaceholder(_ id: UUID) -> Bool {
        (UserDefaults.standard.stringArray(forKey: Self.placeholderKey) ?? []).contains(id.uuidString)
    }

    /// Remembers that this phone-recorded session is only a stand-in for the watch session (newest 20 kept).
    func markPhonePlaceholder(_ id: UUID) {
        var ids = UserDefaults.standard.stringArray(forKey: Self.placeholderKey) ?? []
        ids.removeAll { $0 == id.uuidString }
        ids.append(id.uuidString)
        UserDefaults.standard.set(Array(ids.suffix(20)), forKey: Self.placeholderKey)
    }

    /// True when a session of the same time range, recorded by the watch (or imported from Health), is already here.
    func watchRecordedAlready(_ phone: TrainingSession) -> Bool {
        let me = Self.mergeItem(phone, placeholder: true)
        return SessionMerge.isCovered(me, by: sessions.map { Self.mergeItem($0, placeholder: isPhonePlaceholder($0.id)) })
    }

    /// The incoming id is not stored yet, or only as a Health import that a watch session may replace.
    func canTakeSession(_ id: UUID) -> Bool {
        guard hasSession(id) else { return true }
        return sessions.first { $0.id == id }?.importedFromHealth == true
    }

    // MARK: - Effort (watch post-workout RPE)

    nonisolated private static let pendingEffortKey = "pendingSessionEffort"
    private lazy var pendingEffort: PendingSessionEffort = {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingEffortKey) else { return PendingSessionEffort() }
        do { return try JSONDecoder().decode(PendingSessionEffort.self, from: data) } catch {
            logger.error("Pending effort unreadable, starting empty: \(error.localizedDescription)")
            return PendingSessionEffort()
        }
    }()

    private func savePendingEffort() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(pendingEffort), forKey: Self.pendingEffortKey) } catch {
            logger.error("Failed to save pending effort: \(error.localizedDescription)")
        }
    }

    /// Effort answer that arrived before this class existed (cold start from a watch message): kept in the same
    /// persisted map; `pendingEffort` loads it lazily and applies it when the session is ingested.
    nonisolated static func queuePendingEffort(sessionId: String, rpe: Int) {
        let defaults = UserDefaults.standard
        var pending = PendingSessionEffort()
        if let data = defaults.data(forKey: pendingEffortKey), let decoded = try? JSONDecoder().decode(PendingSessionEffort.self, from: data) {
            pending = decoded
        }
        pending.add(sessionId: sessionId, rpe: min(max(rpe, 0), 10))
        if let data = try? JSONEncoder().encode(pending) { defaults.set(data, forKey: pendingEffortKey) }
    }

    /// Stores the watch's effort answer on the session. If the session has not arrived yet, the answer waits
    /// in a small persisted map and is applied when the session is ingested. Never leaves the phone.
    func applyEffort(sessionId: String, rpe: Int) {
        let rpe = min(max(rpe, 0), 10)
        if let i = sessions.firstIndex(where: { $0.id.uuidString == sessionId }) {
            sessions[i].effortRPE = rpe
            saveSessionsToAppGroup()
        } else {
            pendingEffort.add(sessionId: sessionId, rpe: rpe)
            savePendingEffort()
            logger.info("Effort for unknown session kept pending")
        }
    }

    /// Keeps the active list at `cap` by removing the OLDEST overflow and returning it for the archive.
    /// Archived ids stay in `processedSessionIds`, so watch re-sends of archived sessions are still
    /// deduplicated and cannot re-enter the active list.
    private static func evictOldest(from all: inout [TrainingSession], cap: Int, slack: Int) -> [TrainingSession] {
        guard all.count > cap + slack else { return [] }
        let evicted = Array(all.sorted { $0.startDate < $1.startDate }.prefix(all.count - cap))
        let evictedIds = Set(evicted.map { $0.id })
        all.removeAll { evictedIds.contains($0.id) }
        return evicted
    }

    private func appendToArchive(_ evicted: [TrainingSession]) {
        guard !evicted.isEmpty, let containerURL = getWorkingContainer() else { return }

        let url = containerURL.appendingPathComponent(archiveKey)
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &coordinatorError) { writeURL in
            do {
                var archived: [TrainingSession] = []
                if FileManager.default.fileExists(atPath: writeURL.path) {
                    let data = try Data(contentsOf: writeURL)
                    let decoded = LenientJSON.decodeArray(TrainingSession.self, from: data)
                    archived = decoded.elements
                    if decoded.skipped > 0 || decoded.wholeFileUndecodable {
                        // Preserve the original bytes before the archive is rewritten.
                        let backup = try StoreFile.backupCorrupt(writeURL)
                        self.logger.error("sessions_archive.json: \(decoded.skipped) unreadable record(s); original kept as \(backup.lastPathComponent)")
                    }
                }
                archived.append(contentsOf: evicted)
                let data = try JSONEncoder().encode(archived)
                try data.write(to: writeURL, options: StoreFile.writeOptions)
            } catch {
                self.logger.error("Failed to archive \(evicted.count) session(s): \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            logger.error("File coordination error archiving sessions: \(coordinatorError.localizedDescription)")
        }
    }

    // MARK: - Analytics

    /// Sends a privacy-safe workout completion event to TelemetryDeck.
    /// No PII is included — only aggregate-safe metadata.
    private func trackWorkoutCompleted(_ session: TrainingSession) {
        TelemetryDeck.signal("workoutCompleted", parameters: [
            "sport": session.sportType?.rawValue ?? "unknown",
            "durationMinutes": String(Int(session.duration / 60)),
            "isInterval": String(session.completedIntervals?.isEmpty == false)
        ])
    }

    // MARK: - HealthKit
    private func checkHealthKitAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // Check a write type — HealthKit reports accurate status for share types
        let status = healthStore.authorizationStatus(for: HKWorkoutType.workoutType())
        healthKitAuthorized = status == .sharingAuthorized
        healthAccessDenied = status == .sharingDenied
    }

    /// Existing users: Health has not been asked yet for the types the Health import reads.
    /// Settings shows a one-time button for it; nothing is requested here.
    func refreshHealthAccessState() async {
        checkHealthKitAuthorizationStatus()
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: Self.requestReadTypes)
            healthReadAccessNeeded = status == .shouldRequest
        } catch {
            logger.error("Health request status failed: \(error.localizedDescription)")
        }
    }

    /// Everything the single Health sheet asks to read: the importer's types, the date of birth (age for the estimated
    /// heart limit) and Apple's VO2max (Trends, read-only). The importer gates on `HealthKitImporter.readTypes` only,
    /// so adding a type here never pauses the import for people who already allowed the older set.
    static var requestReadTypes: Set<HKObjectType> {
        var types = HealthKitImporter.readTypes   // workouts, routes, heart rate, energy, distance, steps
        if let dob = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) { types.insert(dob) }
        if let vo2 = VO2MaxLoader.type { types.insert(vo2) }
        return types
    }

    /// The ONE Health sheet: workout/energy/distance sharing plus everything the Health import and the
    /// age lookup read. Called from onboarding and from Settings -> Health, never at launch.
    func requestHealthKitPermissions() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return
        }

        let typesToRead = Self.requestReadTypes

        let typesToWrite: Set<HKSampleType> = [HKWorkoutType.workoutType(), activeEnergyType, distanceType]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            await refreshHealthAccessState()
            refreshAgeFromHealth()
            await HealthKitImporter.shared.start(dataManager: self)   // inert until onboarding is finished
            await HealthKitImporter.shared.importNow()
        } catch {
            logger.error("HealthKit permission request failed: \(error.localizedDescription)")
        }
    }

    /// Reads the date of birth from Health and stores the age when the user has not typed one.
    /// This used to also freeze the Tanaka max HR into the manual-override key; it no longer does:
    /// `userMaxHeartRate` now holds only a value the user typed.
    func refreshAgeFromHealth() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard DeviceManager.shared.userAge == nil || DeviceManager.shared.userAgeIsFromHealth else { return }
        do {
            let c = try healthStore.dateOfBirthComponents()
            guard let year = c.year,
                  let age = HeartLimits.age(birthYear: year, birthMonth: c.month, birthDay: c.day, now: Date()) else { return }
            if DeviceManager.shared.setAgeFromHealth(age) {
                logger.info("Age \(age, privacy: .private) taken from the Health date of birth")
                PhoneSyncCoordinator.shared.sendHeartSafetyToWatch(HeartSafetySettings.load(), age: age)
            }
        } catch {
            logger.info("Date of birth not available in HealthKit: \(error.localizedDescription)")
        }
    }

    /// One time: an older build saved the Health-derived estimate as if the user had typed it, and nothing
    /// in the UI could set a manual value. Clear it here and on the watch.
    func clearFrozenMaxHRIfNeeded() {
        let key = "maxHRFrozenEstimateCleared.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        HeartRateZoneCalculator.saveMaxHR(0)
        UserDefaults.standard.set(true, forKey: PhoneSyncCoordinator.maxHRResetPendingKey)
        PhoneSyncCoordinator.shared.sendPendingMaxHRResetIfNeeded()
    }

    // MARK: - App Group Storage (this class is the only writer of sessions.json)

    private var canSave: Bool {
        #if DEBUG
        if isDemoDataMode { return false }
        #endif
        return hasLoadedOnce && !savesBlockedByCorruption
    }

    /// Requests a write of the full list. Encoding and the file write run on `storeQueue`; calls that arrive
    /// while a write is running (batch imports, rapid receives) collapse into one more write of the latest list.
    func saveSessionsToAppGroup() {
        savePending = true
        startSave()
    }

    private func startSave() {
        guard savePending, canSave, !isWriting else { return }
        guard let url = Self.workingContainer()?.appendingPathComponent(sessionsKey) else { return }
        savePending = false
        isWriting = true
        let snapshot = sessions
        let handled = processedSessionIds   // inbox entries for these ids are in the snapshot or archived
        let inbox = Self.pendingInbox()
        Self.storeQueue.async { [logger] in
            var ok = false
            var coordinatorError: NSError?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { writeURL in
                do {
                    let data = try JSONEncoder().encode(snapshot)
                    try data.write(to: writeURL, options: StoreFile.writeOptions)
                    ok = true
                } catch {
                    logger.error("Failed to save sessions: \(error.localizedDescription)")
                }
            }
            if let coordinatorError {
                logger.error("File coordination error saving sessions: \(coordinatorError.localizedDescription)")
            }
            if ok { inbox?.remove(ids: handled) }
            Task { @MainActor [weak self] in self?.finishSave(success: ok) }
        }
    }

    private func finishSave(success: Bool) {
        isWriting = false
        if success {
            WidgetCenter.shared.reloadAllTimelines()
            debouncedCloudSync()
        }
        startSave()   // no-op unless another save was requested meanwhile
    }

    private func acknowledgeInbox(_ ids: Set<UUID>) {
        guard !ids.isEmpty, let inbox = Self.pendingInbox() else { return }
        Self.storeQueue.async { inbox.remove(ids: ids) }
    }

    /// Debounce CloudKit sync to avoid firing on every rapid save (e.g. batch imports)
    private func debouncedCloudSync() {
        guard AuthenticationManager.shared.isSignedIn else { return }
        cloudSyncDebounceTask?.cancel()
        cloudSyncDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            guard !Task.isCancelled, let self = self else { return }
            CloudKitSyncManager.shared.performFullSync(dataManager: self)
        }
    }

    /// First call reads sessions.json (per record, off the main thread) and drains the pending inbox;
    /// later calls (app resume) only drain the inbox, because nothing else writes the file.
    func loadSessionsFromAppGroup() {
        #if DEBUG
        guard !isDemoDataMode else { return }
        #endif
        guard !isLoading else { return }
        guard let container = Self.workingContainer() else { hasLoadedOnce = true; return }
        isLoading = true

        let url = container.appendingPathComponent(sessionsKey)
        let readFile = !hasLoadedOnce
        let epoch = wipeEpoch
        let inbox = Self.pendingInbox()
        Self.storeQueue.async { [logger] in
            var file = LenientJSON.Decoded<TrainingSession>()
            var readFailed = false
            var backupName: String?
            if readFile {
                StoreFile.relaxProtection(of: Self.protectedFileURLs(in: container))
                if FileManager.default.fileExists(atPath: url.path) {
                    var coordinatorError: NSError?
                    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
                        do {
                            file = LenientJSON.decodeArray(TrainingSession.self, from: try Data(contentsOf: readURL))
                            if file.wholeFileUndecodable || file.skipped > 0 {
                                backupName = try StoreFile.backupCorrupt(readURL).lastPathComponent
                            }
                        } catch {
                            readFailed = true
                            logger.error("Could not read sessions.json: \(error.localizedDescription)")
                        }
                    }
                    if let coordinatorError {
                        readFailed = true
                        logger.error("File coordination error loading sessions: \(coordinatorError.localizedDescription)")
                    }
                }
            }
            let pending = inbox?.contents() ?? LenientJSON.Decoded<TrainingSession>()
            Task { @MainActor [weak self] in
                self?.finishLoad(epoch: epoch, file: file, readFile: readFile, readFailed: readFailed, backupName: backupName, pending: pending)
            }
        }
    }

    private func finishLoad(epoch: Int, file: LenientJSON.Decoded<TrainingSession>, readFile: Bool, readFailed: Bool,
                            backupName: String?, pending: LenientJSON.Decoded<TrainingSession>) {
        isLoading = false
        #if DEBUG
        guard !isDemoDataMode else { return }
        #endif
        guard epoch == wipeEpoch else { return }   // data was wiped while this read was running
        if readFile && !readFailed {
            if file.wholeFileUndecodable {
                savesBlockedByCorruption = true
                storageNotice = "Your saved workout history could not be read. The file was left untouched and a backup was kept, so nothing new is being saved to it."
                logger.error("CRITICAL: sessions.json undecodable (\(file.skipped) record(s)); saves blocked; backup \(backupName ?? "none")")
            } else if file.skipped > 0 {
                storageNotice = "\(file.skipped) saved workout\(file.skipped == 1 ? "" : "s") could not be read and \(file.skipped == 1 ? "was" : "were") skipped. A copy of the original file was kept."
                logger.error("sessions.json: skipped \(file.skipped) unreadable record(s); backup \(backupName ?? "none")")
            }
            mergeLoadedSessions(file.elements)
            hasLoadedOnce = true
        }
        if pending.skipped > 0 { logger.error("Pending inbox: \(pending.skipped) unreadable entr(ies) set aside") }
        if !pending.elements.isEmpty {
            // Already in the list (inbox entry whose acknowledgement was lost): just clear the entry.
            let alreadyIn = Set(pending.elements.map { $0.id }).intersection(sessions.map { $0.id })
            acknowledgeInbox(alreadyIn)
            logger.info("Draining \(pending.elements.count) pending inbox session(s)")
            handleReceivedSessions(pending.elements)
        }
        startSave()   // runs a save that was requested before the first load finished
    }

    private func mergeLoadedSessions(_ loaded: [TrainingSession]) {
        guard !loaded.isEmpty else { return }
        processedSessionIds.formUnion(loaded.map { $0.id })
        // Sessions received while the read was in flight are already in `sessions`; keep them.
        let existingIds = Set(sessions.map { $0.id })
        var missing = loaded.filter { !existingIds.contains($0.id) }
        guard !missing.isEmpty else { return }
        // A watch session that arrived during the read replaces a phone placeholder that is only now loaded.
        let arrived = sessions.filter { $0.importedFromHealth != true }.map { Self.mergeItem($0, placeholder: false) }
        let victims = SessionMerge.replacedIDs(by: arrived, in: missing.map { Self.mergeItem($0, placeholder: isPhonePlaceholder($0.id)) })
        if !victims.isEmpty {
            missing.removeAll { victims.contains($0.id) }
            logger.info("Dropped \(victims.count) loaded placeholder(s) already replaced by a watch session")
        }
        sessions = existingIds.isEmpty ? loaded : sessions + missing
        logger.info("Loaded \(missing.count) session(s) from disk")
    }

    /// Settings banner action: the user accepts starting a new sessions.json. The unreadable original stays
    /// in `sessions_corrupt_*`. Sessions received meanwhile are written now.
    func resumeSavingAfterCorruption() {
        savesBlockedByCorruption = false
        storageNotice = nil
        startSave()
    }

    func dismissStorageNotice() { if !savesBlockedByCorruption { storageNotice = nil } }

    // MARK: - Wipe

    enum WipeScope {
        /// Clear All Training Sessions: sessions, archive, part edits, pending effort, Health import state.
        case trainingData
        /// Delete Account: also templates, plans, devices, heart limits and medication, body metrics, sync state.
        case everything
    }

    /// Removes local user data. Sessions older than now never come back (clear cutoff), and the watch is
    /// asked to drop its copies. Apple Health and iCloud are not touched here.
    func wipeLocalUserData(_ scope: WipeScope) {
        cloudSyncDebounceTask?.cancel()
        wipeEpoch += 1
        hasLoadedOnce = true
        SessionIngestRules.markCleared()
        processedSessionIds = []
        PhoneSyncCoordinator.shared.clearRelay()
        savePending = false
        sessions = []
        savesBlockedByCorruption = false
        storageNotice = nil
        pendingEffort = PendingSessionEffort()
        SegmentOverrideStore.shared.wipe()

        let std = UserDefaults.standard
        for key in ["pendingSessionEffort", "healthImport.anchor", "healthImport.deferredUUIDs",
                    "healthImport.lastDate", "healthImport.lastCount", "phonePlaceholderSessionIDs"] { std.removeObject(forKey: key) }

        var names = [sessionsKey, archiveKey, "segment_overrides.json", PhoneWorkoutCheckpoint.fileName, "rejected_sessions"]
        var corruptPrefixes = ["sessions_corrupt_", "sessions_archive_corrupt_", "segment_overrides_corrupt_"]
        if scope == .everything {
            names += ["workout_templates.json", "exercise_devices.json", "training_plans.json", "plan_progress.json"]
            corruptPrefixes += ["workout_templates_corrupt_", "exercise_devices_corrupt_",
                                "training_plans_corrupt_", "plan_progress_corrupt_"]
            std.removeObject(forKey: "cloudKitPullSinceDate")
            HeartRateZoneCalculator.saveMaxHR(0)
            MedicineVault.clear()
            let group = UserDefaults(suiteName: appGroupIdentifier)
            for key in ["userWeightKg", "userAge", "userAgeFromHealth", HeartSafetySettings.defaultsKey] { group?.removeObject(forKey: key) }
        }

        if let container = Self.workingContainer() {
            let inbox = Self.pendingInbox()
            // storeQueue is serial: a write already running finishes first, so it cannot recreate the file.
            Self.storeQueue.sync {
                for name in names {
                    let url = container.appendingPathComponent(name)
                    guard FileManager.default.fileExists(atPath: url.path) else { continue }
                    do { try FileManager.default.removeItem(at: url) } catch {
                        self.logger.error("Wipe: could not remove \(name): \(error.localizedDescription)")
                    }
                }
                for url in StoreFile.corruptBackups(in: container, prefixes: corruptPrefixes) {
                    try? FileManager.default.removeItem(at: url)
                }
                inbox?.removeAll()
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        if scope == .everything { NotificationCenter.default.post(name: .localUserDataWiped, object: nil) }
        PhoneSyncCoordinator.shared.sendPurgeToWatch(scope == .everything ? .all : .sessions)
        logger.info("Local user data wiped (\(scope == .everything ? "everything" : "training data"))")
    }

    // MARK: - Container Management

    nonisolated static func workingContainer() -> URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared") {
            return container
        }
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fallback = docs.appendingPathComponent("SharedData")
        do {
            try FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true, attributes: nil)
            return fallback
        } catch {
            return nil
        }
    }

    /// Sessions received but not yet in sessions.json. Also written by PhoneSyncCoordinator, so the
    /// session survives a kill before this class has saved (or when it does not exist yet).
    nonisolated static func pendingInbox() -> SessionInbox<TrainingSession>? {
        workingContainer().map { SessionInbox(directory: $0.appendingPathComponent("pending_sessions", isDirectory: true)) }
    }

    private nonisolated static func protectedFileURLs(in container: URL) -> [URL] {
        ["sessions.json", "sessions_archive.json", "workout_templates.json", "exercise_devices.json",
         "training_plans.json", "plan_progress.json", "segment_overrides.json"].map { container.appendingPathComponent($0) }
    }

    private func getWorkingContainer() -> URL? { Self.workingContainer() }
}

extension Notification.Name {
    /// Posted after Delete Account wiped local data; Template/Plan/Device managers reset their in-memory state.
    static let localUserDataWiped = Notification.Name("com.shuttlx.localUserDataWiped")
}
