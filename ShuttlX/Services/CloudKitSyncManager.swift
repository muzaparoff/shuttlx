import Foundation
import CloudKit

@MainActor
class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private lazy var container = CKContainer(identifier: "iCloud.com.shuttlx.app")
    private var database: CKDatabase { container.privateCloudDatabase }

    private let sessionsRecordType = "TrainingSession"
    private let templatesRecordType = "WorkoutTemplate"

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
                print("CloudKit sync failed: \(error)")
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
                print("CloudKit migration failed: \(error)")
            }
        }
    }

    // MARK: - Push

    private func pushSessions(_ sessions: [TrainingSession]) async throws {
        guard !sessions.isEmpty else { return }

        let records = sessions.compactMap { makeRecord(from: $0) }

        // CloudKit batch limit is 400 records per operation
        for batch in records.chunked(into: 400) {
            let operation = CKModifyRecordsOperation(recordsToSave: batch, recordIDsToDelete: nil)
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
    }

    // MARK: - Pull

    private func pullSessions() async throws -> [TrainingSession] {
        let query = CKQuery(recordType: sessionsRecordType, predicate: NSPredicate(value: true))
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

        // Store full session as JSON asset for complete fidelity
        guard let data = try? JSONEncoder().encode(session) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(session.id.uuidString).json")
        do {
            try data.write(to: tempURL)
            record["jsonData"] = CKAsset(fileURL: tempURL)
        } catch {
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

        guard let data = try? JSONEncoder().encode(template) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(template.id.uuidString).json")
        do {
            try data.write(to: tempURL)
            record["jsonData"] = CKAsset(fileURL: tempURL)
        } catch {
            return nil
        }

        return record
    }

    private func decodeSession(from result: Result<CKRecord, Error>) -> TrainingSession? {
        guard case .success(let record) = result else { return nil }
        guard let asset = record["jsonData"] as? CKAsset,
              let fileURL = asset.fileURL else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(TrainingSession.self, from: data)
        } catch {
            return nil
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
