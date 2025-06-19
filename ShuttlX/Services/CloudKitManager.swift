import Foundation
import CloudKit

class CloudKitManager {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - Program Operations
    
    func saveProgram(_ program: TrainingProgram, completion: @escaping (Result<TrainingProgram, Error>) -> Void) {
        let record = program.toCloudKitRecord()
        
        privateDatabase.save(record) { savedRecord, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let savedRecord = savedRecord,
                  var updatedProgram = TrainingProgram(from: savedRecord) else {
                completion(.failure(CloudKitError.recordConversionFailed))
                return
            }
            
            // Preserve the original intervals since CloudKit record doesn't store them directly
            updatedProgram.intervals = program.intervals
            completion(.success(updatedProgram))
        }
    }
    
    func fetchPrograms(completion: @escaping (Result<[TrainingProgram], Error>) -> Void) {
        let query = CKQuery(recordType: "TrainingProgram", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]
        
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let programs = records?.compactMap { TrainingProgram(from: $0) } ?? []
            completion(.success(programs))
        }
    }
    
    func deleteProgram(_ recordID: CKRecord.ID, completion: @escaping (Result<Void, Error>) -> Void) {
        privateDatabase.delete(withRecordID: recordID) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Session Operations
    
    func saveSession(_ session: TrainingSession, completion: @escaping (Result<TrainingSession, Error>) -> Void) {
        let record = session.toCloudKitRecord()
        
        privateDatabase.save(record) { savedRecord, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let savedRecord = savedRecord,
                  var updatedSession = TrainingSession(from: savedRecord) else {
                completion(.failure(CloudKitError.recordConversionFailed))
                return
            }
            
            // Preserve the original completed intervals
            updatedSession.completedIntervals = session.completedIntervals
            completion(.success(updatedSession))
        }
    }
    
    func fetchSessions(completion: @escaping (Result<[TrainingSession], Error>) -> Void) {
        let query = CKQuery(recordType: "TrainingSession", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let sessions = records?.compactMap { TrainingSession(from: $0) } ?? []
            completion(.success(sessions))
        }
    }
    
    func deleteSession(_ recordID: CKRecord.ID, completion: @escaping (Result<Void, Error>) -> Void) {
        privateDatabase.delete(withRecordID: recordID) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus(completion: @escaping (Result<CKAccountStatus, Error>) -> Void) {
        container.accountStatus { status, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(status))
            }
        }
    }
    
    // MARK: - Setup
    
    func setupCloudKit(completion: @escaping (Result<Void, Error>) -> Void) {
        checkAccountStatus { result in
            switch result {
            case .success(let status):
                switch status {
                case .available:
                    completion(.success(()))
                case .noAccount:
                    completion(.failure(CloudKitError.noAccount))
                case .restricted:
                    completion(.failure(CloudKitError.restricted))
                case .couldNotDetermine:
                    completion(.failure(CloudKitError.couldNotDetermine))
                case .temporarilyUnavailable:
                    completion(.failure(CloudKitError.temporarilyUnavailable))
                @unknown default:
                    completion(.failure(CloudKitError.unknownAccountStatus))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - CloudKit Errors

enum CloudKitError: LocalizedError {
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
    case unknownAccountStatus
    case recordConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "No iCloud account is configured. Please sign in to iCloud in Settings."
        case .restricted:
            return "iCloud is restricted on this device."
        case .couldNotDetermine:
            return "Could not determine iCloud account status."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable."
        case .unknownAccountStatus:
            return "Unknown iCloud account status."
        case .recordConversionFailed:
            return "Failed to convert CloudKit record to local model."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .noAccount:
            return "The device is not signed in to an iCloud account."
        case .restricted:
            return "iCloud access has been restricted by parental controls or device management."
        case .couldNotDetermine:
            return "The account status could not be determined due to an unknown error."
        case .temporarilyUnavailable:
            return "iCloud services are temporarily unavailable."
        case .unknownAccountStatus:
            return "An unknown account status was returned by CloudKit."
        case .recordConversionFailed:
            return "The CloudKit record format does not match the expected local model structure."
        }
    }
}
