import Foundation
import CloudKit
import os.log
import ShuttlXShared

/// Session sync to iCloud was removed (App Store guideline 5.1.3(ii): no health data in iCloud).
/// What remains: Delete Account for users who signed in with an earlier build, so they can still remove
/// the session and template records those builds uploaded.
@MainActor
final class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "CloudKitSync")
    private lazy var container = CKContainer(identifier: "iCloud.com.shuttlx.app")
    private var database: CKDatabase { container.privateCloudDatabase }

    private let sessionsRecordType = "TrainingSession"
    private let templatesRecordType = "WorkoutTemplate"

    private init() {}

    // MARK: - Delete All User Data

    enum DeleteError: LocalizedError {
        case fetchFailed(recordType: String, count: Int, first: Error)
        case deleteFailed(recordType: String, count: Int, first: Error)
        case recordsRemain(recordType: String, count: Int)

        var errorDescription: String? {
            switch self {
            case let .fetchFailed(type, count, first): return "\(count) \(type) record(s) could not be listed: \(first.localizedDescription)"
            case let .deleteFailed(type, count, first): return "\(count) \(type) record(s) could not be deleted: \(first.localizedDescription)"
            case let .recordsRemain(type, count): return "\(count) \(type) record(s) are still in iCloud"
            }
        }
    }

    /// Deletes every session and template record, or throws. Succeeds only when a fresh query finds none left.
    func deleteAllUserData() async throws {
        for type in [sessionsRecordType, templatesRecordType] {
            try await deleteAllRecords(ofType: type)
        }
        logger.info("All CloudKit user data deleted and verified")
    }

    /// Two delete passes at most; each ends with a re-query. Index lag can make the first re-query show leftovers.
    private func deleteAllRecords(ofType type: String) async throws {
        var lastError: Error?
        for pass in 1...2 {
            do {
                let listing = try await listRecordIDs(ofType: type)
                if let first = listing.errors.first {
                    // Delete what we can see, then report the listing failure.
                    try await deleteRecordIDs(listing.ids, type: type)
                    throw DeleteError.fetchFailed(recordType: type, count: listing.errors.count, first: first)
                }
                try await deleteRecordIDs(listing.ids, type: type)
                let remaining = try await listRecordIDs(ofType: type)
                if let first = remaining.errors.first {
                    throw DeleteError.fetchFailed(recordType: type, count: remaining.errors.count, first: first)
                }
                if remaining.ids.isEmpty { return }
                lastError = DeleteError.recordsRemain(recordType: type, count: remaining.ids.count)
                logger.error("CloudKit delete pass \(pass): \(remaining.ids.count) \(type) record(s) remain")
            } catch {
                lastError = error
                logger.error("CloudKit delete pass \(pass) for \(type) failed: \(error.localizedDescription)")
            }
        }
        throw lastError ?? DeleteError.recordsRemain(recordType: type, count: -1)
    }

    /// Every record id of a type. Per-record fetch errors are returned, never dropped.
    private func listRecordIDs(ofType type: String) async throws -> (ids: [CKRecord.ID], errors: [Error]) {
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        var ids: [CKRecord.ID] = []
        var errors: [Error] = []
        func absorb(_ results: [(CKRecord.ID, Result<CKRecord, Error>)]) {
            for (id, result) in results {
                switch result {
                case .success: ids.append(id)
                case .failure(let error): errors.append(error)
                }
            }
        }
        var (results, cursor) = try await database.records(matching: query, desiredKeys: [], resultsLimit: 400)
        absorb(results)
        while let current = cursor {
            (results, cursor) = try await database.records(continuingMatchFrom: current, desiredKeys: [], resultsLimit: 400)
            absorb(results)
        }
        return (ids, errors)
    }

    private final class FailureBox: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [Error] = []
        func add(_ e: Error) { lock.lock(); items.append(e); lock.unlock() }
        var all: [Error] { lock.lock(); defer { lock.unlock() }; return items }
    }

    private func deleteRecordIDs(_ ids: [CKRecord.ID], type: String) async throws {
        for batch in ids.chunked(into: 400) {
            let failures = FailureBox()
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: batch)
            operation.qualityOfService = .userInitiated
            operation.perRecordDeleteBlock = { _, result in
                if case .failure(let error) = result, (error as? CKError)?.code != .unknownItem { failures.add(error) }
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success: continuation.resume()
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }
                database.add(operation)
            }
            if let first = failures.all.first {
                throw DeleteError.deleteFailed(recordType: type, count: failures.all.count, first: first)
            }
        }
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
