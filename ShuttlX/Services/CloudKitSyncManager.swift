import Foundation
import CloudKit
import os.log

@MainActor
class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "CloudKitSync")
    private lazy var container = CKContainer(identifier: "iCloud.com.shuttlx.app")
    private var database: CKDatabase { container.privateCloudDatabase }

    private let sessionsRecordType = "TrainingSession"
    private let templatesRecordType = "WorkoutTemplate"

    // MARK: - H7: Change token for incremental pull
    // Stored separately from the UI-facing `lastSyncDate` so it survives across cold launches.
    private let pullTokenKey = "cloudKitPullSinceDate"

    /// Date of the last successful pull. Used as `modifiedAfter` predicate on the next pull.
    /// On first launch (nil) the pull fetches all records — same behaviour as before.
    private var pullSinceDate: Date? {
        get {
            let ti = UserDefaults.standard.double(forKey: pullTokenKey)
            guard ti > 0 else { return nil }
            return Date(timeIntervalSinceReferenceDate: ti)
        }
        set {
            if let d = newValue {
                UserDefaults.standard.set(d.timeIntervalSinceReferenceDate, forKey: pullTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pullTokenKey)
            }
        }
    }

    private init() {}

    // MARK: - Full Sync

    func performFullSync(dataManager: DataManager, completion: (() -> Void)? = nil) {
        guard !isSyncing else {
            completion?()
            return
        }
        guard AuthenticationManager.shared.isSignedIn else {
            completion?()
            return
        }

        isSyncing = true
        syncError = nil

        Task {
            do {
                let remoteSessions = try await pullSessions()
                let localSessions = dataManager.sessions

                // Merge: newest wins by modifiedDate, fallback to startDate
                let merged = mergeSessions(local: localSessions, remote: remoteSessions)

                // Update local if we got new remote sessions
                let localIDs = Set(localSessions.map { $0.id })
                let newFromRemote = merged.filter { !localIDs.contains($0.id) }
                if !newFromRemote.isEmpty {
                    dataManager.handleReceivedSessions(newFromRemote)
                }

                // Push local-only sessions to cloud
                let remoteIDs = Set(remoteSessions.map { $0.id })
                let localOnly = localSessions.filter { !remoteIDs.contains($0.id) }
                if !localOnly.isEmpty {
                    try await pushSessions(localOnly)
                }

                lastSyncDate = Date()
            } catch {
                syncError = error.localizedDescription
                logger.error("CloudKit sync failed: \(error.localizedDescription)")
            }

            isSyncing = false
            completion?()
        }
    }

    // MARK: - Migrate Local Data

    func migrateLocalData(dataManager: DataManager) {
        guard AuthenticationManager.shared.isSignedIn else { return }

        Task {
            do {
                try await pushSessions(dataManager.sessions)
                lastSyncDate = Date()
            } catch {
                logger.error("CloudKit migration failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Push (H8: fetch-before-write via ifServerRecordUnchanged + conflict retry)

    private func pushSessions(_ sessions: [TrainingSession]) async throws {
        guard !sessions.isEmpty else { return }

        let records = sessions.compactMap { makeRecord(from: $0) }

        // CloudKit batch limit is 400 records per operation
        for batch in records.chunked(into: 400) {
            try await pushRecordBatch(batch, sessions: sessions)
        }

        // Clean up temp files created for CKAsset encoding
        cleanupTempFiles(for: sessions.map { $0.id })
    }

    /// Push a batch of records using `.ifServerRecordUnchanged` policy.
    /// If a record conflicts (server has a newer version), we apply our local data
    /// onto the server record and retry — sessions are append-only so local wins.
    private func pushRecordBatch(_ records: [CKRecord], sessions: [TrainingSession]) async throws {
        // Build a lookup so we can re-apply local data onto conflicting server records
        let sessionByRecordName: [String: TrainingSession] = Dictionary(
            uniqueKeysWithValues: sessions.compactMap { session -> (String, TrainingSession)? in
                return (session.id.uuidString, session)
            }
        )

        var retryRecords: [CKRecord] = []

        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        // H8: Use ifServerRecordUnchanged so we don't silently overwrite concurrent edits.
        operation.savePolicy = .ifServerRecordUnchanged
        operation.qualityOfService = .userInitiated

        operation.perRecordSaveBlock = { [weak self] recordID, result in
            guard let self else { return }
            if case .failure(let error) = result {
                let ckError = error as? CKError
                if ckError?.code == .serverRecordChanged,
                   let serverRecord = ckError?.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
                   let session = sessionByRecordName[recordID.recordName] {
                    // Server has a different version. Sessions are append-only — local data is
                    // authoritative for completed workouts, so overwrite server record fields
                    // with our data and queue for retry. The server record already carries the
                    // correct `recordChangeTag`, so the retry will succeed.
                    self.applySession(session, to: serverRecord)
                    retryRecords.append(serverRecord)
                    self.logger.info("CloudKit conflict on \(recordID.recordName) — queued for retry with server record")
                } else {
                    self.logger.error("CloudKit save failed for \(recordID.recordName): \(error.localizedDescription)")
                }
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }

        // Retry conflicting records (now carrying the server's recordChangeTag)
        if !retryRecords.isEmpty {
            logger.info("Retrying \(retryRecords.count) conflicting CloudKit records")
            let retryOp = CKModifyRecordsOperation(recordsToSave: retryRecords, recordIDsToDelete: nil)
            retryOp.savePolicy = .ifServerRecordUnchanged
            retryOp.qualityOfService = .userInitiated

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                retryOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                database.add(retryOp)
            }
        }
    }

    /// Apply all fields from a local TrainingSession onto an existing CKRecord (for conflict retry).
    private func applySession(_ session: TrainingSession, to record: CKRecord) {
        record["uuid"] = session.id.uuidString
        record["startDate"] = session.startDate
        record["duration"] = session.duration
        record["modifiedDate"] = session.modifiedDate ?? session.startDate

        do {
            let data = try JSONEncoder().encode(session)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(session.id.uuidString)-retry.json")
            try data.write(to: tempURL, options: [.atomic, .completeFileProtection])
            record["jsonData"] = CKAsset(fileURL: tempURL)
        } catch {
            logger.error("Failed to encode session \(session.id) for retry: \(error.localizedDescription)")
        }
    }

    func pushTemplates(_ templates: [WorkoutTemplate]) async throws {
        guard !templates.isEmpty else { return }

        let records = templates.compactMap { makeRecord(from: $0) }

        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }

        // Clean up temp files created for CKAsset encoding
        cleanupTempFiles(for: templates.map { $0.id })
    }

    // MARK: - Pull (H7: incremental via modifiedDate predicate)

    private func pullSessions() async throws -> [TrainingSession] {
        // H7: Only fetch records modified after our last successful pull.
        // On the very first sync (pullSinceDate == nil) we fetch everything, same as before.
        let predicate: NSPredicate
        if let since = pullSinceDate {
            predicate = NSPredicate(format: "modifiedDate > %@", since as CVarArg)
            logger.info("CloudKit incremental pull: changes since \(since)")
        } else {
            predicate = NSPredicate(value: true)
            logger.info("CloudKit full pull: no previous token")
        }

        // Capture the time just before the query so we don't miss records created
        // during the fetch window.
        let fetchStartedAt = Date()

        let query = CKQuery(recordType: sessionsRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]

        var allResults: [TrainingSession] = []
        var cursor: CKQueryOperation.Cursor?

        // Initial fetch
        let (results, nextCursor) = try await database.records(matching: query, resultsLimit: 200)
        allResults.append(contentsOf: results.compactMap { decodeSession(from: $0.1) })
        cursor = nextCursor

        // Page through all results
        while let currentCursor = cursor {
            let (pageResults, pageCursor) = try await database.records(continuingMatchFrom: currentCursor, resultsLimit: 200)
            allResults.append(contentsOf: pageResults.compactMap { decodeSession(from: $0.1) })
            cursor = pageCursor
        }

        // Persist the token only after a fully successful fetch
        pullSinceDate = fetchStartedAt

        return allResults
    }

    // MARK: - Record Conversion

    private func makeRecord(from session: TrainingSession) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: session.id.uuidString)
        let record = CKRecord(recordType: sessionsRecordType, recordID: recordID)

        record["uuid"] = session.id.uuidString
        record["startDate"] = session.startDate
        record["duration"] = session.duration
        record["modifiedDate"] = session.modifiedDate ?? session.startDate

        do {
            let data = try JSONEncoder().encode(session)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(session.id.uuidString).json")
            try data.write(to: tempURL, options: [.atomic, .completeFileProtection])
            record["jsonData"] = CKAsset(fileURL: tempURL)
        } catch {
            logger.error("Failed to encode session \(session.id): \(error.localizedDescription)")
            return nil
        }

        return record
    }

    private func makeRecord(from template: WorkoutTemplate) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: template.id.uuidString)
        let record = CKRecord(recordType: templatesRecordType, recordID: recordID)

        record["uuid"] = template.id.uuidString
        record["name"] = template.name
        record["createdDate"] = template.createdDate
        record["modifiedDate"] = template.modifiedDate ?? template.createdDate

        do {
            let data = try JSONEncoder().encode(template)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(template.id.uuidString).json")
            try data.write(to: tempURL, options: [.atomic, .completeFileProtection])
            record["jsonData"] = CKAsset(fileURL: tempURL)
        } catch {
            logger.error("Failed to encode template \(template.id): \(error.localizedDescription)")
            return nil
        }

        return record
    }

    private func decodeSession(from result: Result<CKRecord, Error>) -> TrainingSession? {
        guard case .success(let record) = result else {
            if case .failure(let error) = result {
                logger.error("CloudKit record fetch failed: \(error.localizedDescription)")
            }
            return nil
        }
        guard let asset = record["jsonData"] as? CKAsset,
              let fileURL = asset.fileURL else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(TrainingSession.self, from: data)
        } catch {
            logger.error("Failed to decode session from CloudKit record \(record.recordID.recordName): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Delete All User Data

    func deleteAllUserData() async throws {
        // Delete all sessions
        let sessionsQuery = CKQuery(recordType: sessionsRecordType, predicate: NSPredicate(value: true))
        try await deleteAllRecords(matching: sessionsQuery)

        // Delete all templates
        let templatesQuery = CKQuery(recordType: templatesRecordType, predicate: NSPredicate(value: true))
        try await deleteAllRecords(matching: templatesQuery)

        lastSyncDate = nil
        pullSinceDate = nil
        logger.info("All CloudKit user data deleted")
    }

    private func deleteAllRecords(matching query: CKQuery) async throws {
        var cursor: CKQueryOperation.Cursor?

        let (results, nextCursor) = try await database.records(matching: query, resultsLimit: 400)
        let ids = results.compactMap { try? $0.1.get().recordID }
        if !ids.isEmpty {
            try await deleteRecordBatch(ids)
        }
        cursor = nextCursor

        while let currentCursor = cursor {
            let (pageResults, pageCursor) = try await database.records(continuingMatchFrom: currentCursor, resultsLimit: 400)
            let pageIDs = pageResults.compactMap { try? $0.1.get().recordID }
            if !pageIDs.isEmpty {
                try await deleteRecordBatch(pageIDs)
            }
            cursor = pageCursor
        }
    }

    private func deleteRecordBatch(_ recordIDs: [CKRecord.ID]) async throws {
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        operation.qualityOfService = .userInitiated

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    // MARK: - Temp File Cleanup

    private func cleanupTempFiles(for ids: [UUID]) {
        let tempDir = FileManager.default.temporaryDirectory
        for id in ids {
            let tempURL = tempDir.appendingPathComponent("\(id.uuidString).json")
            try? FileManager.default.removeItem(at: tempURL)
            // Also clean up any retry temp files
            let retryURL = tempDir.appendingPathComponent("\(id.uuidString)-retry.json")
            try? FileManager.default.removeItem(at: retryURL)
        }
    }

    // MARK: - Merge

    private func mergeSessions(local: [TrainingSession], remote: [TrainingSession]) -> [TrainingSession] {
        var merged = [UUID: TrainingSession]()

        for session in local {
            merged[session.id] = session
        }

        for session in remote {
            if let existing = merged[session.id] {
                // Newest modifiedDate wins
                let existingDate = existing.modifiedDate ?? existing.startDate
                let remoteDate = session.modifiedDate ?? session.startDate
                if remoteDate > existingDate {
                    merged[session.id] = session
                }
            } else {
                merged[session.id] = session
            }
        }

        return Array(merged.values)
    }
}

// MARK: - Array Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
