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
// SyncStatus enum definition moved to Models/SettingsModels.swift

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
    
    // Convert from local TrainingSession
    init(from session: TrainingSession) {
        self.id = session.id.uuidString
        self.workoutType = session.workoutConfiguration.type.rawValue
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.duration = session.duration
        self.caloriesBurned = session.caloriesBurned ?? 0
        self.totalDistance = session.totalDistance ?? 0
        self.averageHeartRate = session.averageHeartRate ?? 0
        self.maxHeartRate = session.maxHeartRate ?? 0
        self.notes = session.notes ?? ""
        self.deviceInfo = UIDevice.current.model
        
        // For now, set route data to nil since TrainingSession structure needs to be checked
        self.routeData = nil
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
        self.name = profile.displayName
        self.age = nil // SocialModels UserProfile doesn't have age
        self.weight = nil // SocialModels UserProfile doesn't have weight
        self.height = nil // SocialModels UserProfile doesn't have height
        self.fitnessLevel = "beginner" // Default since SocialModels UserProfile doesn't have fitnessLevel
        self.preferredUnits = "metric" // Default since SocialModels UserProfile doesn't have preferences
        self.workoutPreferences = nil // Default since SocialModels UserProfile doesn't have preferences
        self.lastSync = Date()
    }
}

// MARK: - Cloud Achievement Model
struct CloudAchievement: Codable {
    let id: UUID
    let type: String
    let earnedAt: Date
    let progress: Double
    let isNew: Bool
    let title: String
    let description: String
    let iconName: String
    
    init(from achievement: Achievement) {
        self.id = achievement.id
        self.type = achievement.category.rawValue
        self.earnedAt = achievement.unlockedAt ?? Date()
        self.progress = achievement.progressPercentage / 100.0
        self.isNew = false
        self.title = achievement.title
        self.description = achievement.description
        self.iconName = achievement.icon
    }
}

// MARK: - CloudKit Manager
@MainActor
class CloudKitManager: ObservableObject {
    // MARK: - Singleton
    static let shared = CloudKitManager()
    
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
                    print("❌ CloudKit account error: \(error)")
                } else {
                    print("✅ CloudKit account status: \(status)")
                }
            }
        }
    }
    
    func requestPermissions() async -> Bool {
        do {
            let status = try await container.requestApplicationPermission(.userDiscoverability)
            return status == .granted
        } catch {
            errorMessage = "Failed to request CloudKit permissions: \(error.localizedDescription)"
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
            print("❌ CloudKit sync failed: \(error)")
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
    private func saveWorkoutToCloud(_ session: TrainingSession) async throws {
        let cloudSession = CloudWorkoutSession(from: session)
        let record = try createWorkoutRecord(from: cloudSession)
        
        try await privateDatabase.save(record)
        print("✅ Saved workout to CloudKit: \(session.id)")
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
                print("❌ Error fetching workout record: \(error)")
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
                print("❌ Error fetching user profile: \(error)")
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
    
    // MARK: - Achievement Operations
    private func fetchAchievementsFromCloud() async throws -> [CloudAchievement] {
        let query = CKQuery(recordType: RecordType.achievement.recordName, predicate: NSPredicate(value: true))
        let result = try await privateDatabase.records(matching: query)
        
        var achievements: [CloudAchievement] = []
        
        for (_, recordResult) in result.matchResults {
            switch recordResult {
            case .success(let record):
                if let achievement = try? parseAchievementRecord(record) {
                    achievements.append(achievement)
                }
            case .failure(let error):
                print("❌ Error fetching achievement record: \(error)")
            }
        }
        
        return achievements
    }
    
    private func saveAchievementToCloud(_ achievement: CloudAchievement) async throws {
        let record = try createAchievementRecord(from: achievement)
        try await privateDatabase.save(record)
        print("✅ Saved achievement to CloudKit: \(achievement.id)")
    }
    
    private func createAchievementRecord(from achievement: CloudAchievement) throws -> CKRecord {
        let record = CKRecord(recordType: RecordType.achievement.recordName)
        
        record["id"] = achievement.id
        record["title"] = achievement.title
        record["description"] = achievement.description
        record["iconName"] = achievement.iconName
        record["unlockedDate"] = achievement.unlockedDate
        record["progress"] = achievement.progress
        record["isUnlocked"] = achievement.isUnlocked
        record["category"] = achievement.category
        
        return record
    }
    
    private func parseAchievementRecord(_ record: CKRecord) throws -> CloudAchievement {
        guard let id = record["id"] as? String,
              let title = record["title"] as? String,
              let description = record["description"] as? String,
              let iconName = record["iconName"] as? String,
              let progress = record["progress"] as? Double,
              let isUnlocked = record["isUnlocked"] as? Bool,
              let category = record["category"] as? String else {
            throw CloudKitError.invalidRecord
        }
        
        let unlockedDate = record["unlockedDate"] as? Date
        
        return CloudAchievement(
            id: id,
            title: title,
            description: description,
            iconName: iconName,
            unlockedDate: unlockedDate,
            progress: progress,
            isUnlocked: isUnlocked,
            category: category
        )
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
        var locationData: [CLLocation] // Using CLLocation instead of LocationDataPoint
        var notes: String
    }
    
    // UserProfile struct definition is in Models/SocialModels.swift
    
    struct WorkoutPreferences: Codable {
        var defaultWorkoutDuration: TimeInterval
        var preferredIntensity: String
        var enableAudioCoaching: Bool
        var enableHapticFeedback: Bool
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
    
    // MARK: - Local Data Operations (Mock implementations)
    private func getLocalWorkouts() async -> [TrainingSession] {
        // In a real app, this would fetch from Core Data or local storage
        // For now, return empty array
        return []
    }
    
    private func updateLocalWorkouts(_ workouts: [CloudWorkoutSession]) async {
        // In a real app, this would update Core Data or local storage
        print("📱 Updating local workouts with \(workouts.count) items")
    }
    
    private func getLocalUserProfile() async -> UserProfile? {
        // In a real app, this would fetch from local storage
        return nil
    }
    
    private func updateLocalUserProfile(_ profile: CloudUserProfile) async {
        // In a real app, this would update local storage
        print("👤 Updating local user profile")
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
        func syncWorkoutToAPI(_ session: TrainingSession) async throws {
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
        
        // Add missing methods for SocialService
        func createUserProfile(_ profile: UserProfile) async throws -> APIResponse<UserProfile> {
            // Mock implementation - in production this would make actual API calls
            return APIResponse(user: profile)
        }
        
        func updateUserProfile(_ profile: UserProfile) async throws -> APIResponse<UserProfile> {
            // Mock implementation - in production this would make actual API calls
            return APIResponse(user: profile)
        }
        
        func getUserProfile(userId: UUID) async throws -> APIResponse<UserProfile> {
            // Mock implementation - in production this would make actual API calls
            let mockProfile = UserProfile(
                id: userId,
                username: "mockuser",
                displayName: "Mock User",
                email: "mock@example.com",
                joinDate: Date(),
                lastActiveDate: Date(),
                bio: "Mock bio",
                location: "Mock Location",
                avatarURL: nil,
                isPrivate: false,
                level: 1,
                experiencePoints: 0,
                followersCount: 0,
                followingCount: 0,
                postsCount: 0,
                totalWorkouts: 0,
                totalDistance: 0,
                totalCalories: 0,
                badges: [],
                preferences: UserSocialPreferences()
            )
            return APIResponse(user: mockProfile)
        }
        
        func followUser(userId: UUID) async throws -> FollowResponse {
            // Mock implementation
            return FollowResponse(success: true, isFollowing: true, followersCount: 1, followingCount: 1)
        }
        
        func unfollowUser(userId: UUID) async throws -> FollowResponse {
            // Mock implementation
            return FollowResponse(success: true, isFollowing: false, followersCount: 0, followingCount: 0)
        }
        
        func sendNotification(to userId: UUID, type: NotificationType, message: String) async throws {
            // Mock implementation - in production this would send actual notifications
            print("📱 Mock notification sent to \(userId): \(message)")
        }
        
        func blockUser(userId: UUID) async throws {
            // Mock implementation - in production this would block the user
            print("🚫 Mock block user: \(userId)")
        }
        
        func createPost(_ post: FeedPost) async throws -> PostResponse {
            // Mock implementation - in production this would create actual posts
            return PostResponse(post: post)
        }
        
        func likePost(postId: UUID) async throws -> LikeResponse {
            // Mock implementation
            return LikeResponse(success: true, likesCount: 1)
        }
        
        func unlikePost(postId: UUID) async throws -> LikeResponse {
            // Mock implementation
            return LikeResponse(success: true, likesCount: 0)
        }
    }
    
    // MARK: - Additional API Response Models
    
    struct APIResponse<T: Codable>: Codable {
        let user: T
    }
    
    struct PostResponse: Codable {
        let post: FeedPost
    }
    
    struct SendNotificationRequest: Codable {
        let userId: String
        let type: String
        let message: String
    }
    
    struct EmptyResponse: Codable {
        // Empty response for void API calls
    }
    
    // MARK: - APIRequest helper
    struct APIRequest<T: Codable>: Codable {
        let endpoint: String
        let method: HTTPMethod
        let body: T?
        
        init(endpoint: String, method: HTTPMethod, body: T? = nil) {
            self.endpoint = endpoint
            self.method = method
            self.body = body
        }
    }


