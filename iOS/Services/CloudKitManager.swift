//
//  CloudKitManager.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CloudKit
import Combine
import UIKit

// MARK: - CloudKit Record Types
enum RecordType: String {
    case workout = "Workout"
    case workoutSession = "WorkoutSession"
    case userProfile = "UserProfile"
    case achievement = "Achievement"
    case formAnalysis = "FormAnalysis"
    case route = "Route"
    
    var recordName: String {
        return rawValue
    }
}

// MARK: - Sync Status
enum SyncStatus {
    case idle
    case syncing
    case success
    case failed(Error)
    
    var isLoading: Bool {
        if case .syncing = self { return true }
        return false
    }
}

// MARK: - CloudKit Models
struct CloudWorkoutSession: Codable {
    let id: String
    let workoutType: String
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let caloriesBurned: Double
    let totalDistance: Double
    let averageHeartRate: Double
    let maxHeartRate: Double
    let routeData: Data?
    let notes: String
    let deviceInfo: String
    
    // Convert from local WorkoutSession
    init(from session: WorkoutSession) {
        self.id = session.id.uuidString
        self.workoutType = session.workoutType.rawValue
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.duration = session.actualDuration
        self.caloriesBurned = session.caloriesBurned
        self.totalDistance = session.totalDistance
        self.averageHeartRate = session.averageHeartRate
        self.maxHeartRate = session.maxHeartRate
        self.notes = session.notes
        self.deviceInfo = UIDevice.current.model
        
        // Encode route data
        if !session.locationData.isEmpty {
            self.routeData = try? JSONEncoder().encode(session.locationData)
        } else {
            self.routeData = nil
        }
    }
}

struct CloudUserProfile: Codable {
    let id: String
    let name: String
    let age: Int?
    let weight: Double?
    let height: Double?
    let fitnessLevel: String
    let preferredUnits: String
    let workoutPreferences: Data?
    let lastSync: Date
    
    init(from profile: UserProfile) {
        self.id = profile.id.uuidString
        self.name = profile.name
        self.age = profile.age
        self.weight = profile.weight
        self.height = profile.height
        self.fitnessLevel = profile.fitnessLevel.rawValue
        self.preferredUnits = profile.preferredUnits.rawValue
        self.workoutPreferences = try? JSONEncoder().encode(profile.workoutPreferences)
        self.lastSync = Date()
    }
}

// MARK: - CloudKit Manager
@MainActor
class CloudKitManager: ObservableObject {
    // MARK: - Published Properties
    @Published var syncStatus: SyncStatus = .idle
    @Published var isCloudKitEnabled: Bool = false
    @Published var lastSyncDate: Date?
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()
    private var apiService: APIService?
    
    // MARK: - Initialization
    init() {
        self.container = CKContainer(identifier: "iCloud.com.shuttlx.app") // Update with your container ID
        self.privateDatabase = container.privateCloudDatabase
        self.publicDatabase = container.publicCloudDatabase
        
        checkAccountStatus()
        loadLastSyncDate()
    }
    
    // MARK: - Configuration
    func configure(apiService: APIService) {
        self.apiService = apiService
    }
    
    // MARK: - Account Management
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.accountStatus = status
                self?.isCloudKitEnabled = status == .available
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("❌ CloudKit account error: \\(error)")
                } else {
                    print("✅ CloudKit account status: \\(status)")
                }
            }
        }
    }
    
    func requestPermissions() async -> Bool {
        do {
            let status = try await container.requestApplicationPermission(.userDiscoverability)
            return status == .granted
        } catch {
            errorMessage = "Failed to request CloudKit permissions: \\(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Sync Operations
    func syncAllData() async {
        guard isCloudKitEnabled else {
            errorMessage = "CloudKit is not available"
            return
        }
        
        syncStatus = .syncing
        
        do {
            // Sync workouts
            try await syncWorkouts()
            
            // Sync user profile
            try await syncUserProfile()
            
            // Sync achievements
            try await syncAchievements()
            
            lastSyncDate = Date()
            saveLastSyncDate()
            syncStatus = .success
            
            print("✅ CloudKit sync completed successfully")
            
        } catch {
            syncStatus = .failed(error)
            errorMessage = error.localizedDescription
            print("❌ CloudKit sync failed: \\(error)")
        }
    }
    
    func syncWorkouts() async throws {
        // Get local workouts that need syncing
        let localWorkouts = await getLocalWorkouts()
        
        for workout in localWorkouts {
            try await saveWorkoutToCloud(workout)
        }
        
        // Fetch remote workouts and update local database
        let remoteWorkouts = try await fetchWorkoutsFromCloud()
        await updateLocalWorkouts(remoteWorkouts)
    }
    
    func syncUserProfile() async throws {
        // Get local user profile
        if let localProfile = await getLocalUserProfile() {
            try await saveUserProfileToCloud(localProfile)
        }
        
        // Fetch remote profile and update local
        if let remoteProfile = try await fetchUserProfileFromCloud() {
            await updateLocalUserProfile(remoteProfile)
        }
    }
    
    func syncAchievements() async throws {
        // Implementation for syncing achievements
        print("🏆 Syncing achievements...")
    }
    
    // MARK: - Workout Operations
    private func saveWorkoutToCloud(_ session: WorkoutSession) async throws {
        let cloudSession = CloudWorkoutSession(from: session)
        let record = try createWorkoutRecord(from: cloudSession)
        
        try await privateDatabase.save(record)
        print("✅ Saved workout to CloudKit: \\(session.id)")
    }
    
    private func fetchWorkoutsFromCloud() async throws -> [CloudWorkoutSession] {
        let query = CKQuery(recordType: RecordType.workoutSession.recordName, predicate: NSPredicate(value: true))
        let result = try await privateDatabase.records(matching: query)
        
        var workouts: [CloudWorkoutSession] = []
        
        for (_, recordResult) in result.matchResults {
            switch recordResult {
            case .success(let record):
                if let workout = try? parseWorkoutRecord(record) {
                    workouts.append(workout)
                }
            case .failure(let error):
                print("❌ Error fetching workout record: \\(error)")
            }
        }
        
        return workouts
    }
    
    private func createWorkoutRecord(from session: CloudWorkoutSession) throws -> CKRecord {
        let record = CKRecord(recordType: RecordType.workoutSession.recordName)
        
        record["id"] = session.id
        record["workoutType"] = session.workoutType
        record["startTime"] = session.startTime
        record["endTime"] = session.endTime
        record["duration"] = session.duration
        record["caloriesBurned"] = session.caloriesBurned
        record["totalDistance"] = session.totalDistance
        record["averageHeartRate"] = session.averageHeartRate
        record["maxHeartRate"] = session.maxHeartRate
        record["notes"] = session.notes
        record["deviceInfo"] = session.deviceInfo
        
        if let routeData = session.routeData {
            record["routeData"] = routeData
        }
        
        return record
    }
    
    private func parseWorkoutRecord(_ record: CKRecord) throws -> CloudWorkoutSession {
        guard let id = record["id"] as? String,
              let workoutType = record["workoutType"] as? String,
              let startTime = record["startTime"] as? Date,
              let duration = record["duration"] as? Double,
              let caloriesBurned = record["caloriesBurned"] as? Double,
              let totalDistance = record["totalDistance"] as? Double,
              let averageHeartRate = record["averageHeartRate"] as? Double,
              let maxHeartRate = record["maxHeartRate"] as? Double,
              let notes = record["notes"] as? String,
              let deviceInfo = record["deviceInfo"] as? String else {
            throw CloudKitError.invalidRecord
        }
        
        let endTime = record["endTime"] as? Date
        let routeData = record["routeData"] as? Data
        
        return CloudWorkoutSession(
            id: id,
            workoutType: workoutType,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            caloriesBurned: caloriesBurned,
            totalDistance: totalDistance,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            routeData: routeData,
            notes: notes,
            deviceInfo: deviceInfo
        )
    }
    
    // MARK: - User Profile Operations
    private func saveUserProfileToCloud(_ profile: UserProfile) async throws {
        let cloudProfile = CloudUserProfile(from: profile)
        let record = try createUserProfileRecord(from: cloudProfile)
        
        try await privateDatabase.save(record)
        print("✅ Saved user profile to CloudKit")
    }
    
    private func fetchUserProfileFromCloud() async throws -> CloudUserProfile? {
        let query = CKQuery(recordType: RecordType.userProfile.recordName, predicate: NSPredicate(value: true))
        let result = try await privateDatabase.records(matching: query)
        
        for (_, recordResult) in result.matchResults {
            switch recordResult {
            case .success(let record):
                return try? parseUserProfileRecord(record)
            case .failure(let error):
                print("❌ Error fetching user profile: \\(error)")
            }
        }
        
        return nil
    }
    
    private func createUserProfileRecord(from profile: CloudUserProfile) throws -> CKRecord {
        let record = CKRecord(recordType: RecordType.userProfile.recordName)
        
        record["id"] = profile.id
        record["name"] = profile.name
        record["age"] = profile.age
        record["weight"] = profile.weight
        record["height"] = profile.height
        record["fitnessLevel"] = profile.fitnessLevel
        record["preferredUnits"] = profile.preferredUnits
        record["lastSync"] = profile.lastSync
        
        if let workoutPreferences = profile.workoutPreferences {
            record["workoutPreferences"] = workoutPreferences
        }
        
        return record
    }
    
    private func parseUserProfileRecord(_ record: CKRecord) throws -> CloudUserProfile {
        guard let id = record["id"] as? String,
              let name = record["name"] as? String,
              let fitnessLevel = record["fitnessLevel"] as? String,
              let preferredUnits = record["preferredUnits"] as? String,
              let lastSync = record["lastSync"] as? Date else {
            throw CloudKitError.invalidRecord
        }
        
        let age = record["age"] as? Int
        let weight = record["weight"] as? Double
        let height = record["height"] as? Double
        let workoutPreferences = record["workoutPreferences"] as? Data
        
        return CloudUserProfile(
            id: id,
            name: name,
            age: age,
            weight: weight,
            height: height,
            fitnessLevel: fitnessLevel,
            preferredUnits: preferredUnits,
            workoutPreferences: workoutPreferences,
            lastSync: lastSync
        )
    }
    
    // MARK: - Background Sync
    func enableBackgroundSync() {
        // Subscribe to remote notifications for real-time sync
        let subscription = CKQuerySubscription(
            recordType: RecordType.workoutSession.recordName,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        Task {
            do {
                try await privateDatabase.save(subscription)
                print("✅ CloudKit background sync enabled")
            } catch {
                print("❌ Failed to enable background sync: \\(error)")
            }
        }
    }
    
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return
        }
        
        switch notification.notificationType {
        case .query:
            // Handle query notification - trigger sync
            await syncAllData()
        case .database, .readNotification:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Local Data Operations (Mock implementations)
    private func getLocalWorkouts() async -> [WorkoutSession] {
        // In a real app, this would fetch from Core Data or local storage
        return []
    }
    
    private func updateLocalWorkouts(_ workouts: [CloudWorkoutSession]) async {
        // In a real app, this would update Core Data or local storage
        print("📱 Updating local workouts with \\(workouts.count) items")
    }
    
    private func getLocalUserProfile() async -> UserProfile? {
        // In a real app, this would fetch from local storage
        return nil
    }
    
    private func updateLocalUserProfile(_ profile: CloudUserProfile) async {
        // In a real app, this would update local storage
        print("👤 Updating local user profile")
    }
    
    // MARK: - Utility Methods
    private func saveLastSyncDate() {
        if let lastSyncDate = lastSyncDate {
            UserDefaults.standard.set(lastSyncDate, forKey: "CloudKitLastSync")
        }
    }
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "CloudKitLastSync") as? Date
    }
    
    func clearSyncData() {
        lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: "CloudKitLastSync")
        errorMessage = nil
        syncStatus = .idle
    }
}

// MARK: - CloudKit Errors
enum CloudKitError: Error, LocalizedError {
    case invalidRecord
    case syncFailed
    case accountUnavailable
    case quotaExceeded
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            return "Invalid record format"
        case .syncFailed:
            return "Sync operation failed"
        case .accountUnavailable:
            return "iCloud account not available"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .networkUnavailable:
            return "Network connection required"
        }
    }
}

// MARK: - Mock Models for CloudKit Integration
struct WorkoutSession {
    let id: UUID
    let workoutType: SimpleWorkoutType
    let startTime: Date
    var endTime: Date?
    var actualDuration: TimeInterval
    var caloriesBurned: Double
    var totalDistance: Double
    var averageHeartRate: Double
    var maxHeartRate: Double
    var locationData: [LocationDataPoint]
    var notes: String
}

struct UserProfile {
    let id: UUID
    let name: String
    let age: Int?
    let weight: Double?
    let height: Double?
    let fitnessLevel: FitnessLevel
    let preferredUnits: UnitSystem
    let workoutPreferences: WorkoutPreferences
    
    enum FitnessLevel: String, CaseIterable {
        case beginner, intermediate, advanced
    }
    
    enum UnitSystem: String, CaseIterable {
        case metric, imperial
    }
}

struct WorkoutPreferences: Codable {
    var defaultWorkoutDuration: TimeInterval
    var preferredIntensity: String
    var enableAudioCoaching: Bool
    var enableHapticFeedback: Bool
}

struct LocationDataPoint {
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let speed: Double
}

// MARK: - CloudKit Extensions
extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
}

extension LocationDataPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, coordinate, altitude, speed
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(speed, forKey: .speed)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        coordinate = try container.decode(CLLocationCoordinate2D.self, forKey: .coordinate)
        altitude = try container.decode(Double.self, forKey: .altitude)
        speed = try container.decode(Double.self, forKey: .speed)
    }
}

// MARK: - API Synchronization
    
    /// Sync data between CloudKit and the backend API
    func syncWithAPI() async {
        guard let apiService = apiService else {
            errorMessage = "API service not configured"
            return
        }
        
        syncStatus = .syncing
        
        do {
            // Push local CloudKit data to API
            try await pushDataToAPI()
            
            // Pull data from API to CloudKit
            try await pullDataFromAPI()
            
            lastSyncDate = Date()
            saveLastSyncDate()
            syncStatus = .success
            
            print("✅ API sync completed successfully")
            
        } catch {
            syncStatus = .failed(error)
            errorMessage = error.localizedDescription
            print("❌ API sync failed: \(error)")
        }
    }
    
    private func pushDataToAPI() async throws {
        guard let apiService = apiService else { return }
        
        // Push workout sessions to API
        let localWorkouts = try await fetchWorkoutsFromCloud()
        for workout in localWorkouts {
            try await apiService.syncWorkoutSession(workout)
        }
        
        // Push user profile to API
        if let userProfile = try await fetchUserProfileFromCloud() {
            try await apiService.syncUserProfile(userProfile)
        }
        
        // Push achievements to API
        let achievements = try await fetchAchievementsFromCloud()
        for achievement in achievements {
            try await apiService.syncAchievement(achievement)
        }
    }
    
    private func pullDataFromAPI() async throws {
        guard let apiService = apiService else { return }
        
        // Pull workout sessions from API
        let remoteWorkouts = try await apiService.fetchWorkoutSessions()
        for workout in remoteWorkouts {
            try await saveWorkoutToCloud(workout)
        }
        
        // Pull user profile from API
        if let remoteProfile = try await apiService.fetchUserProfile() {
            try await saveUserProfileToCloud(remoteProfile)
        }
        
        // Pull achievements from API
        let remoteAchievements = try await apiService.fetchAchievements()
        for achievement in remoteAchievements {
            try await saveAchievementToCloud(achievement)
        }
    }
    
    /// Enable automatic sync between CloudKit and API
    func enableAutoSync() {
        // Set up periodic sync every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task {
                await self?.syncWithAPI()
            }
        }
    }
    
    /// Sync specific workout session to API
    func syncWorkoutToAPI(_ session: WorkoutSession) async throws {
        guard let apiService = apiService else { return }
        
        let cloudSession = CloudWorkoutSession(from: session)
        try await apiService.syncWorkoutSession(cloudSession)
        
        // Also save to CloudKit for local backup
        try await saveWorkoutToCloud(cloudSession)
    }
    
    /// Sync user profile changes to API
    func syncUserProfileToAPI(_ profile: UserProfile) async throws {
        guard let apiService = apiService else { return }
        
        let cloudProfile = CloudUserProfile(from: profile)
        try await apiService.syncUserProfile(cloudProfile)
        
        // Also save to CloudKit for local backup
        try await saveUserProfileToCloud(cloudProfile)
    }
}

// MARK: - API Service Extensions

extension APIService {
    // Add workout session sync methods
    func syncWorkoutSession(_ session: CloudWorkoutSession) async throws {
        let request = APIRequest(
            endpoint: Endpoints.syncWorkout,
            method: .POST,
            body: session
        )
        let _: EmptyResponse = try await performRequest(request)
    }
    
    func fetchWorkoutSessions() async throws -> [CloudWorkoutSession] {
        let request = APIRequest(
            endpoint: Endpoints.workouts,
            method: .GET
        )
        let response: [CloudWorkoutSession] = try await performRequest(request)
        return response
    }
    
    func syncUserProfile(_ profile: CloudUserProfile) async throws {
        let request = APIRequest(
            endpoint: Endpoints.syncProfile,
            method: .POST,
            body: profile
        )
        let _: EmptyResponse = try await performRequest(request)
    }
    
    func fetchUserProfile() async throws -> CloudUserProfile? {
        let request = APIRequest(
            endpoint: Endpoints.profile,
            method: .GET
        )
        let response: CloudUserProfile? = try await performRequest(request)
        return response
    }
    
    func syncAchievement(_ achievement: CloudAchievement) async throws {
        let request = APIRequest(
            endpoint: Endpoints.syncAchievement,
            method: .POST,
            body: achievement
        )
        let _: EmptyResponse = try await performRequest(request)
    }
    
    func fetchAchievements() async throws -> [CloudAchievement] {
        let request = APIRequest(
            endpoint: Endpoints.achievements,
            method: .GET
        )
        let response: [CloudAchievement] = try await performRequest(request)
        return response
    }
}

// MARK: - Additional Cloud Models

struct CloudAchievement: Codable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let unlockedDate: Date?
    let progress: Double
    let isUnlocked: Bool
    let category: String
}
