//
//  APIService.swift
//  ShuttlX
//
//  Backend API integration service for ShuttlX social features
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine

/// Core API service for backend integration
@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    // MARK: - Configuration
    private let baseURL = "https://api.shuttlx.app/v1"
    private let session = URLSession.shared
    private var authToken: String?
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var lastError: APIError?
    
    // MARK: - API Endpoints
    struct Endpoints {
        // Authentication
        static let login = "/auth/login"
        static let register = "/auth/register"
        static let refresh = "/auth/refresh"
        
        // Social Features
        static let feed = "/social/feed"
        static let posts = "/social/posts"
        static let likes = "/social/likes"
        static let comments = "/social/comments"
        static let follows = "/social/follows"
        static let notifications = "/social/notifications"
        
        // Challenges
        static let challenges = "/challenges"
        static let challengeProgress = "/challenges/progress"
        static let joinChallenge = "/challenges/join"
        
        // Teams
        static let teams = "/teams"
        static let teamMembers = "/teams/members"
        static let teamInvites = "/teams/invites"
        
        // Leaderboards
        static let leaderboards = "/leaderboards"
        static let rankings = "/rankings"
        
        // User Profiles
        static let userProfiles = "/users/profiles"
        static let userStats = "/users/stats"
        static let userAchievements = "/users/achievements"
        
        // Workouts
        static let workouts = "/workouts"
        static let workoutSessions = "/workouts/sessions"
        static let syncWorkout = "/sync/workouts"
        
        // Sync endpoints
        static let syncProfile = "/sync/profile"
        static let syncAchievement = "/sync/achievements"
        static let profile = "/profile"
        static let achievements = "/achievements"
        
        // Real-time
        static let websocket = "/ws"
        static let presence = "/presence"
    }
    
    // MARK: - Initialization
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Authentication
    func authenticate(email: String, password: String) async throws -> AuthResponse {
        let request = AuthRequest(email: email, password: password)
        let response: AuthResponse = try await performRequest(
            endpoint: Endpoints.login,
            method: .POST,
            body: request
        )
        
        authToken = response.accessToken
        isConnected = true
        return response
    }
    
    func refreshToken() async throws -> AuthResponse {
        guard let currentToken = authToken else {
            throw APIError.unauthorized
        }
        
        let request = RefreshTokenRequest(refreshToken: currentToken)
        let response: AuthResponse = try await performRequest(
            endpoint: Endpoints.refresh,
            method: .POST,
            body: request
        )
        
        authToken = response.accessToken
        return response
    }
    
    // MARK: - Social API Methods
    
    // Feed Operations
    func getFeed(limit: Int = 20, offset: Int = 0) async throws -> FeedResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.feed)?limit=\(limit)&offset=\(offset)",
            method: .GET
        )
    }
    
    func createPost(_ post: CreatePostRequest) async throws -> FeedPost {
        return try await performRequest(
            endpoint: Endpoints.posts,
            method: .POST,
            body: post
        )
    }
    
    func likePost(postId: String) async throws -> LikeResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.likes)/\(postId)",
            method: .POST
        )
    }
    
    func unlikePost(postId: String) async throws -> LikeResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.likes)/\(postId)",
            method: .DELETE
        )
    }
    
    // Follow Operations
    func followUser(userId: String) async throws -> FollowResponse {
        let request = FollowRequest(userId: userId)
        return try await performRequest(
            endpoint: Endpoints.follows,
            method: .POST,
            body: request
        )
    }
    
    func unfollowUser(userId: String) async throws -> FollowResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.follows)/\(userId)",
            method: .DELETE
        )
    }
    
    func getFollowers(userId: String, limit: Int = 50) async throws -> FollowersResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.follows)/\(userId)/followers?limit=\(limit)",
            method: .GET
        )
    }
    
    func getFollowing(userId: String, limit: Int = 50) async throws -> FollowingResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.follows)/\(userId)/following?limit=\(limit)",
            method: .GET
        )
    }
    
    // Challenge Operations
    func getChallenges(category: String? = nil, limit: Int = 20) async throws -> ChallengesResponse {
        var endpoint = "\(Endpoints.challenges)?limit=\(limit)"
        if let category = category {
            endpoint += "&category=\(category)"
        }
        return try await performRequest(endpoint: endpoint, method: .GET)
    }
    
    func joinChallenge(challengeId: String) async throws -> JoinChallengeResponse {
        let request = JoinChallengeRequest(challengeId: challengeId)
        return try await performRequest(
            endpoint: Endpoints.joinChallenge,
            method: .POST,
            body: request
        )
    }
    
    func updateChallengeProgress(challengeId: String, progress: Double) async throws -> ChallengeProgressResponse {
        let request = UpdateChallengeProgressRequest(challengeId: challengeId, progress: progress)
        return try await performRequest(
            endpoint: Endpoints.challengeProgress,
            method: .PUT,
            body: request
        )
    }
    
    // Team Operations
    func getTeams(category: String? = nil, limit: Int = 20) async throws -> TeamsResponse {
        var endpoint = "\(Endpoints.teams)?limit=\(limit)"
        if let category = category {
            endpoint += "&category=\(category)"
        }
        return try await performRequest(endpoint: endpoint, method: .GET)
    }
    
    func createTeam(_ team: CreateTeamRequest) async throws -> Team {
        return try await performRequest(
            endpoint: Endpoints.teams,
            method: .POST,
            body: team
        )
    }
    
    func joinTeam(teamId: String) async throws -> JoinTeamResponse {
        let request = JoinTeamRequest(teamId: teamId)
        return try await performRequest(
            endpoint: "\(Endpoints.teams)/\(teamId)/join",
            method: .POST,
            body: request
        )
    }
    
    func getTeamMembers(teamId: String) async throws -> TeamMembersResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.teamMembers)/\(teamId)",
            method: .GET
        )
    }
    
    // Leaderboard Operations
    func getLeaderboard(type: String, period: String, limit: Int = 50) async throws -> LeaderboardResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.leaderboards)?type=\(type)&period=\(period)&limit=\(limit)",
            method: .GET
        )
    }
    
    func getUserRanking(userId: String, type: String, period: String) async throws -> UserRankingResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.rankings)/\(userId)?type=\(type)&period=\(period)",
            method: .GET
        )
    }
    
    // User Profile Operations
    func getUserProfile(userId: String) async throws -> UserProfile {
        return try await performRequest(
            endpoint: "\(Endpoints.userProfiles)/\(userId)",
            method: .GET
        )
    }
    
    func updateUserProfile(userId: String, updates: UpdateUserProfileRequest) async throws -> UserProfile {
        return try await performRequest(
            endpoint: "\(Endpoints.userProfiles)/\(userId)",
            method: .PUT,
            body: updates
        )
    }
    
    func getUserStats(userId: String) async throws -> UserStatsResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.userStats)/\(userId)",
            method: .GET
        )
    }
    
    // Workout Operations
    func syncWorkout(_ workout: WorkoutSyncRequest) async throws -> WorkoutSyncResponse {
        return try await performRequest(
            endpoint: Endpoints.workoutSessions,
            method: .POST,
            body: workout
        )
    }
    
    func getWorkoutHistory(userId: String, limit: Int = 20) async throws -> WorkoutHistoryResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.workouts)/\(userId)/history?limit=\(limit)",
            method: .GET
        )
    }
    
    // Notification Operations
    func getNotifications(limit: Int = 50, offset: Int = 0) async throws -> NotificationsResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.notifications)?limit=\(limit)&offset=\(offset)",
            method: .GET
        )
    }
    
    func markNotificationAsRead(notificationId: String) async throws -> NotificationUpdateResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.notifications)/\(notificationId)/read",
            method: .PUT
        )
    }
    
    func markAllNotificationsAsRead() async throws -> NotificationUpdateResponse {
        return try await performRequest(
            endpoint: "\(Endpoints.notifications)/read-all",
            method: .PUT
        )
    }
    
    // MARK: - Generic Request Method
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: (any Codable)? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication header
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body if provided
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.encodingFailed
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                // Try to refresh token and retry
                try await refreshToken()
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            case 429:
                throw APIError.rateLimited
            case 500...599:
                throw APIError.serverError
            default:
                throw APIError.unknownError(httpResponse.statusCode)
            }
            
            // Decode response
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingFailed
            }
            
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        // Monitor network connectivity
        // Implementation would check for internet connectivity
        isConnected = true // Placeholder
    }
}

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - API Error Types
enum APIError: LocalizedError {
    case invalidURL
    case encodingFailed
    case decodingFailed
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError
    case networkError(Error)
    case unknownError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingFailed:
            return "Failed to encode request"
        case .decodingFailed:
            return "Failed to decode response"
        case .invalidResponse:
            return "Invalid response"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limit exceeded"
        case .serverError:
            return "Server error"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknownError(let code):
            return "Unknown error (code: \(code))"
        }
    }
}

// MARK: - Request/Response Models
struct AuthRequest: Codable {
    let email: String
    let password: String
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: UserProfile
    let expiresIn: Int
}

struct CreatePostRequest: Codable {
    let content: String
    let workoutSummary: WorkoutSummary?
    let imageURLs: [String]
    let visibility: String
}

struct LikeResponse: Codable {
    let success: Bool
    let likesCount: Int
}

struct FollowRequest: Codable {
    let userId: String
}

struct FollowResponse: Codable {
    let success: Bool
    let isFollowing: Bool
    let followersCount: Int
    let followingCount: Int
}

struct FollowersResponse: Codable {
    let followers: [UserProfile]
    let totalCount: Int
    let hasMore: Bool
}

struct FollowingResponse: Codable {
    let following: [UserProfile]
    let totalCount: Int
    let hasMore: Bool
}

struct FeedResponse: Codable {
    let posts: [FeedPost]
    let hasMore: Bool
    let nextOffset: Int?
}

struct ChallengesResponse: Codable {
    let challenges: [Challenge]
    let hasMore: Bool
    let totalCount: Int
}

struct JoinChallengeRequest: Codable {
    let challengeId: String
}

struct JoinChallengeResponse: Codable {
    let success: Bool
    let challengeProgress: ChallengeProgress
}

struct UpdateChallengeProgressRequest: Codable {
    let challengeId: String
    let progress: Double
}

struct ChallengeProgressResponse: Codable {
    let success: Bool
    let progress: ChallengeProgress
    let isCompleted: Bool
    let rewards: [Reward]?
}

struct TeamsResponse: Codable {
    let teams: [Team]
    let hasMore: Bool
    let totalCount: Int
}

struct CreateTeamRequest: Codable {
    let name: String
    let description: String
    let isPublic: Bool
    let maxMembers: Int
}

struct JoinTeamRequest: Codable {
    let teamId: String
}

struct JoinTeamResponse: Codable {
    let success: Bool
    let membership: TeamMember
}

struct TeamMembersResponse: Codable {
    let members: [TeamMember]
    let totalCount: Int
}

struct LeaderboardResponse: Codable {
    let entries: [LeaderboardEntry]
    let userPosition: LeaderboardPosition?
    let hasMore: Bool
}

struct UserRankingResponse: Codable {
    let position: LeaderboardPosition
    let category: String
    let period: String
}

struct UpdateUserProfileRequest: Codable {
    let displayName: String?
    let bio: String?
    let location: String?
    let isPrivate: Bool?
}

struct UserStatsResponse: Codable {
    let stats: UserStats
    let achievements: [Achievement]
    let badges: [Badge]
}

struct WorkoutSyncRequest: Codable {
    let workoutData: TrainingSession
    let healthMetrics: HealthMetrics?
}

struct WorkoutSyncResponse: Codable {
    let success: Bool
    let workoutId: String
    let achievements: [Achievement]?
    let socialPosts: [FeedPost]?
}

struct WorkoutHistoryResponse: Codable {
    let workouts: [TrainingSession]
    let hasMore: Bool
    let totalCount: Int
}

struct NotificationsResponse: Codable {
    let notifications: [SocialNotification]
    let unreadCount: Int
    let hasMore: Bool
}

struct NotificationUpdateResponse: Codable {
    let success: Bool
    let unreadCount: Int
}

struct UserStats: Codable {
    let totalWorkouts: Int
    let totalDistance: Double
    let totalCalories: Double
    let currentStreak: Int
    let longestStreak: Int
    let averageWorkoutsPerWeek: Double
}

struct Reward: Codable {
    let id: String
    let type: String
    let title: String
    let description: String
    let value: Int
    let iconName: String
}

struct LeaderboardPosition: Codable {
    let rank: Int
    let value: Double
    let change: Int
    let percentile: Double
}
