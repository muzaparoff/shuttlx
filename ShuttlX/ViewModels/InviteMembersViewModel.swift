import SwiftUI
import Combine
import Contacts

@MainActor
class InviteMembersViewModel: ObservableObject {
    @Published var suggestedUsers: [User] = []
    @Published var recentlyActive: [User] = []
    @Published var searchResults: [User] = []
    @Published var selectedUsers: Set<String> = []
    @Published var selectedContacts: [CNContact] = []
    @Published var isLoading = false
    @Published var inviteLink = ""
    @Published var linkViews = 0
    @Published var linkJoins = 0
    @Published var linkCopied = false
    @Published var errorMessage: String?
    
    private let socialService: SocialService
    private let contactStore = CNContactStore()
    private var cancellables = Set<AnyCancellable>()
    private var searchDebounceTimer: Timer?
    
    init(socialService: SocialService) {
        self.socialService = socialService
    }
    
    func loadSuggestedUsers() {
        Task {
            isLoading = true
            
            do {
                // Load suggested users based on mutual friends, recent activity, etc.
                async let suggested = socialService.getSuggestedUsers()
                async let recentUsers = socialService.getRecentlyActiveUsers()
                
                suggestedUsers = try await suggested
                recentlyActive = try await recentUsers
                
            } catch {
                errorMessage = "Failed to load suggestions: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func searchUsers(query: String) {
        searchDebounceTimer?.invalidate()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                self.isLoading = true
                
                do {
                    self.searchResults = try await self.socialService.searchUsers(query: query)
                } catch {
                    self.errorMessage = "Search failed: \(error.localizedDescription)"
                    self.searchResults = []
                }
                
                self.isLoading = false
            }
        }
    }
    
    func toggleUserSelection(_ user: User) {
        if selectedUsers.contains(user.id) {
            selectedUsers.remove(user.id)
        } else {
            selectedUsers.insert(user.id)
        }
    }
    
    func sendInvitations(to userIDs: [String], for team: Team) async {
        isLoading = true
        
        do {
            for userID in userIDs {
                try await socialService.sendTeamInvitation(
                    teamID: team.id,
                    toUserID: userID,
                    message: "You've been invited to join \(team.name)!"
                )
            }
            
            // Clear selections after successful invitations
            selectedUsers.removeAll()
            
        } catch {
            errorMessage = "Failed to send invitations: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Contacts Integration
    
    func addContacts(_ contacts: [CNContact]) {
        for contact in contacts {
            if !selectedContacts.contains(where: { $0.identifier == contact.identifier }) {
                selectedContacts.append(contact)
            }
        }
    }
    
    func removeContact(_ contact: CNContact) {
        selectedContacts.removeAll { $0.identifier == contact.identifier }
    }
    
    func sendContactInvitations(for team: Team) async {
        isLoading = true
        
        do {
            for contact in selectedContacts {
                // Extract email addresses
                for emailAddress in contact.emailAddresses {
                    let email = emailAddress.value as String
                    try await socialService.sendEmailInvitation(
                        email: email,
                        teamID: team.id,
                        teamName: team.name,
                        inviterName: getCurrentUserName()
                    )
                }
                
                // Extract phone numbers for SMS invitations
                for phoneNumber in contact.phoneNumbers {
                    let phone = phoneNumber.value.stringValue
                    try await socialService.sendSMSInvitation(
                        phoneNumber: phone,
                        teamID: team.id,
                        teamName: team.name,
                        inviterName: getCurrentUserName()
                    )
                }
            }
            
            // Clear selections after successful invitations
            selectedContacts.removeAll()
            
        } catch {
            errorMessage = "Failed to send contact invitations: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Invite Link Management
    
    func loadInviteLink(for team: Team) async {
        do {
            let linkData = try await socialService.getTeamInviteLink(teamID: team.id)
            inviteLink = linkData.url
            linkViews = linkData.views
            linkJoins = linkData.joins
        } catch {
            errorMessage = "Failed to load invite link: \(error.localizedDescription)"
            // Generate a fallback link
            inviteLink = "https://shuttlx.app/invite/\(team.id)"
        }
    }
    
    func regenerateInviteLink(for team: Team) async {
        isLoading = true
        
        do {
            let newLinkData = try await socialService.regenerateTeamInviteLink(teamID: team.id)
            inviteLink = newLinkData.url
            linkViews = 0 // Reset stats for new link
            linkJoins = 0
        } catch {
            errorMessage = "Failed to regenerate invite link: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func showCopiedFeedback() {
        linkCopied = true
        
        // Hide feedback after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.linkCopied = false
        }
    }
    
    func shareInviteLink() {
        let activityViewController = UIActivityViewController(
            activityItems: [
                "Join my team on ShuttlX: \(inviteLink)",
                URL(string: inviteLink)!
            ],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserName() -> String {
        // This would typically come from a user service or app state
        return "ShuttlX User" // Placeholder
    }
}

// MARK: - Supporting Models

struct TeamInviteLinkData {
    let url: String
    let views: Int
    let joins: Int
    let expiresAt: Date
    let isActive: Bool
}

struct UserSearchResult {
    let users: [User]
    let hasMore: Bool
    let nextCursor: String?
}

// MARK: - Extensions for SocialService

extension SocialService {
    func getSuggestedUsers() async throws -> [User] {
        // Implementation for getting suggested users
        // This would typically involve:
        // - Users with mutual friends
        // - Users from similar geographic areas
        // - Users with similar interests/activities
        
        return [] // Placeholder - implement actual logic
    }
    
    func getRecentlyActiveUsers() async throws -> [User] {
        // Implementation for getting recently active users
        // This would return users who have been active recently
        // and might be interested in joining teams
        
        return [] // Placeholder - implement actual logic
    }
    
    func searchUsers(query: String) async throws -> [User] {
        // Implementation for searching users by username, email, or name
        // This would perform a backend search and return matching users
        
        return [] // Placeholder - implement actual logic
    }
    
    func sendTeamInvitation(teamID: String, toUserID: String, message: String) async throws {
        // Implementation for sending team invitation to existing users
        // This would create an invitation record and send a notification
    }
    
    func sendEmailInvitation(email: String, teamID: String, teamName: String, inviterName: String) async throws {
        // Implementation for sending email invitations to non-users
        // This would send an email with a signup link and team invitation
    }
    
    func sendSMSInvitation(phoneNumber: String, teamID: String, teamName: String, inviterName: String) async throws {
        // Implementation for sending SMS invitations
        // This would send a text message with a signup link and team invitation
    }
    
    func getTeamInviteLink(teamID: String) async throws -> TeamInviteLinkData {
        // Implementation for getting existing invite link data
        // This would return the current invite link and its statistics
        
        return TeamInviteLinkData(
            url: "https://shuttlx.app/invite/\(teamID)",
            views: 0,
            joins: 0,
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            isActive: true
        )
    }
    
    func regenerateTeamInviteLink(teamID: String) async throws -> TeamInviteLinkData {
        // Implementation for regenerating invite link
        // This would create a new invite link and invalidate the old one
        
        let newID = UUID().uuidString
        return TeamInviteLinkData(
            url: "https://shuttlx.app/invite/\(newID)",
            views: 0,
            joins: 0,
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            isActive: true
        )
    }
}

// MARK: - User Extensions

extension User {
    var initials: String {
        let components = displayName.components(separatedBy: " ")
        let firstInitial = components.first?.prefix(1) ?? ""
        let lastInitial = components.count > 1 ? components.last?.prefix(1) ?? "" : ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
    
    var mutualFriendsCount: Int? {
        // This would be populated by the backend based on mutual connections
        return nil // Placeholder
    }
}
