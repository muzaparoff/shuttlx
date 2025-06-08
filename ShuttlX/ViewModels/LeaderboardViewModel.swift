import Foundation
import Combine

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var currentUserPosition: LeaderboardPosition?
    @Published var isLoading = false
    @Published var hasMoreEntries = false
    @Published var errorMessage: String?
    
    // Filters
    @Published var locationScope: LocationScope = .global
    @Published var ageGroup: AgeGroup?
    @Published var genderFilter: GenderFilter?
    @Published var friendsOnly = false
    
    private let socialService: SocialService
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 0
    private let pageSize = 20
    
    let currentUserID = getCurrentUserID()
    
    init(socialService: SocialService) {
        self.socialService = socialService
    }
    
    func loadLeaderboard(timeframe: LeaderboardTimeframe, category: LeaderboardCategory) {
        currentPage = 0
        leaderboardEntries.removeAll()
        
        Task {
            isLoading = true
            
            do {
                let result = try await socialService.getLeaderboard(
                    timeframe: timeframe,
                    category: category,
                    filters: createFilters(),
                    page: currentPage,
                    pageSize: pageSize
                )
                
                leaderboardEntries = result.entries
                hasMoreEntries = result.hasMore
                currentUserPosition = result.currentUserPosition
                
            } catch {
                errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func loadMoreEntries() {
        guard !isLoading && hasMoreEntries else { return }
        
        currentPage += 1
        
        Task {
            isLoading = true
            
            do {
                let result = try await socialService.getLeaderboard(
                    timeframe: .weekly, // This should be passed from the current state
                    category: .overall, // This should be passed from the current state
                    filters: createFilters(),
                    page: currentPage,
                    pageSize: pageSize
                )
                
                leaderboardEntries.append(contentsOf: result.entries)
                hasMoreEntries = result.hasMore
                
            } catch {
                errorMessage = "Failed to load more entries: \(error.localizedDescription)"
                currentPage -= 1 // Revert page increment on failure
            }
            
            isLoading = false
        }
    }
    
    func refreshLeaderboard() async {
        // Reset pagination and reload
        currentPage = 0
        
        do {
            let result = try await socialService.getLeaderboard(
                timeframe: .weekly, // This should be passed from the current state
                category: .overall, // This should be passed from the current state
                filters: createFilters(),
                page: currentPage,
                pageSize: pageSize
            )
            
            leaderboardEntries = result.entries
            hasMoreEntries = result.hasMore
            currentUserPosition = result.currentUserPosition
            
        } catch {
            errorMessage = "Failed to refresh leaderboard: \(error.localizedDescription)"
        }
    }
    
    func resetFilters() {
        locationScope = .global
        ageGroup = nil
        genderFilter = nil
        friendsOnly = false
    }
    
    private func createFilters() -> LeaderboardFilters {
        return LeaderboardFilters(
            locationScope: locationScope,
            ageGroup: ageGroup,
            genderFilter: genderFilter,
            friendsOnly: friendsOnly
        )
    }
}

// MARK: - Supporting Models

struct LeaderboardEntry: Identifiable, Codable {
    let id = UUID()
    let userID: String
    let user: User
    let value: Double
    let change: Int? // Position change from previous period
    let streak: Int? // Current streak for consistency metrics
    let lastUpdated: Date
    
    init(userID: String, user: User, value: Double, change: Int? = nil, streak: Int? = nil) {
        self.userID = userID
        self.user = user
        self.value = value
        self.change = change
        self.streak = streak
        self.lastUpdated = Date()
    }
}

struct LeaderboardPosition: Codable {
    let rank: Int
    let value: Double
    let change: Int? // Position change from previous period
    let percentile: Double // What percentile the user is in
    
    init(rank: Int, value: Double, change: Int? = nil, percentile: Double) {
        self.rank = rank
        self.value = value
        self.change = change
        self.percentile = percentile
    }
}

struct LeaderboardResult: Codable {
    let entries: [LeaderboardEntry]
    let currentUserPosition: LeaderboardPosition?
    let hasMore: Bool
    let totalCount: Int
    let lastUpdated: Date
    
    init(entries: [LeaderboardEntry], currentUserPosition: LeaderboardPosition?, hasMore: Bool, totalCount: Int) {
        self.entries = entries
        self.currentUserPosition = currentUserPosition
        self.hasMore = hasMore
        self.totalCount = totalCount
        self.lastUpdated = Date()
    }
}

struct LeaderboardFilters: Codable {
    let locationScope: LocationScope
    let ageGroup: AgeGroup?
    let genderFilter: GenderFilter?
    let friendsOnly: Bool
    
    init(locationScope: LocationScope, ageGroup: AgeGroup?, genderFilter: GenderFilter?, friendsOnly: Bool) {
        self.locationScope = locationScope
        self.ageGroup = ageGroup
        self.genderFilter = genderFilter
        self.friendsOnly = friendsOnly
    }
}

// MARK: - Extensions for SocialService

extension SocialService {
    func getLeaderboard(
        timeframe: LeaderboardTimeframe,
        category: LeaderboardCategory,
        filters: LeaderboardFilters,
        page: Int,
        pageSize: Int
    ) async throws -> LeaderboardResult {
        // Implementation for fetching leaderboard data
        // This would make API calls to get ranked user data
        
        // Placeholder implementation
        let sampleUsers = createSampleUsers()
        let entries = sampleUsers.enumerated().map { index, user in
            LeaderboardEntry(
                userID: user.id,
                user: user,
                value: Double(1000 - index * 50),
                change: [-3, -1, 0, 1, 2, 5].randomElement()
            )
        }
        
        let currentUserPosition = LeaderboardPosition(
            rank: 15,
            value: 750.0,
            change: 3,
            percentile: 85.5
        )
        
        return LeaderboardResult(
            entries: Array(entries.prefix(pageSize)),
            currentUserPosition: currentUserPosition,
            hasMore: entries.count > pageSize,
            totalCount: entries.count
        )
    }
    
    private func createSampleUsers() -> [User] {
        return [
            User(id: "1", username: "runner_champion", email: "runner@example.com", displayName: "Alex Champion", profileImageURL: nil, location: "New York, NY"),
            User(id: "2", username: "speed_demon", email: "speed@example.com", displayName: "Jordan Speed", profileImageURL: nil, location: "Los Angeles, CA"),
            User(id: "3", username: "marathon_master", email: "marathon@example.com", displayName: "Sam Master", profileImageURL: nil, location: "Chicago, IL"),
            User(id: "4", username: "fitness_pro", email: "fitness@example.com", displayName: "Taylor Pro", profileImageURL: nil, location: "Houston, TX"),
            User(id: "5", username: "endurance_expert", email: "endurance@example.com", displayName: "Casey Expert", profileImageURL: nil, location: "Phoenix, AZ"),
            User(id: "6", username: "workout_warrior", email: "warrior@example.com", displayName: "Morgan Warrior", profileImageURL: nil, location: "Philadelphia, PA"),
            User(id: "7", username: "cardio_king", email: "cardio@example.com", displayName: "Riley King", profileImageURL: nil, location: "San Antonio, TX"),
            User(id: "8", username: "strength_star", email: "strength@example.com", displayName: "Avery Star", profileImageURL: nil, location: "San Diego, CA"),
            User(id: "9", username: "athletics_ace", email: "athletics@example.com", displayName: "Quinn Ace", profileImageURL: nil, location: "Dallas, TX"),
            User(id: "10", username: "fitness_legend", email: "legend@example.com", displayName: "Blake Legend", profileImageURL: nil, location: "San Jose, CA")
        ]
    }
}

// MARK: - User Extension

extension User {
    init(id: String, username: String, email: String, displayName: String, profileImageURL: String?, location: String?) {
        self.id = id
        self.username = username
        self.email = email
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.location = location
        self.isVerified = false
        self.createdAt = Date()
        self.preferences = UserPreferences()
        self.statistics = UserStatistics()
        self.achievements = []
        self.friends = []
        self.blockedUsers = []
    }
}

// MARK: - Helper Functions

private func getCurrentUserID() -> String {
    return UserDefaults.standard.string(forKey: "current_user_id") ?? "current_user"
}
