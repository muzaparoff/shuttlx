//
//  TeamDetailViewModel.swift
//  ShuttlX
//
//  ViewModel for comprehensive team management and real-time collaboration
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class TeamDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var teamMembers: [TeamMember] = []
    @Published var teamChallenges: [Challenge] = []
    @Published var teamWorkouts: [TeamWorkout] = []
    @Published var chatMessages: [ChatMessage] = []
    @Published var teamStats: TeamStatistics = TeamStatistics.empty
    @Published var recentActivities: [TeamActivity] = []
    @Published var upcomingEvents: [TeamEvent] = []
    @Published var topPerformers: [TeamMember] = []
    @Published var errorMessage: String?
    
    // Real-time states
    @Published var unreadMessages: Int = 0
    @Published var activeMembers: Int = 0
    @Published var newMessage: String = ""
    @Published var isTyping: Bool = false
    @Published var currentUserRole: TeamRole = .member
    
    // MARK: - Private Properties
    private let socialService: SocialService
    private var cancellables = Set<AnyCancellable>()
    private var teamId: UUID?
    private var currentUserId: UUID?
    
    // MARK: - Initialization
    init(socialService: SocialService) {
        self.socialService = socialService
        setupObservers()
        currentUserId = socialService.currentUserProfile?.id
    }
    
    // MARK: - Public Methods
    func loadTeamData(teamId: UUID) {
        self.teamId = teamId
        isLoading = true
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadTeamMembers(teamId) }
                group.addTask { await self.loadTeamChallenges(teamId) }
                group.addTask { await self.loadTeamWorkouts(teamId) }
                group.addTask { await self.loadChatMessages(teamId) }
                group.addTask { await self.loadTeamStats(teamId) }
                group.addTask { await self.loadRecentActivities(teamId) }
                group.addTask { await self.loadUpcomingEvents(teamId) }
                group.addTask { await self.loadTopPerformers(teamId) }
                group.addTask { await self.checkCurrentUserRole(teamId) }
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Team Management Actions
    func updateMemberRole(_ member: TeamMember, role: TeamRole) async {
        guard currentUserRole == .admin || currentUserRole == .owner else {
            errorMessage = "You don't have permission to change member roles."
            return
        }
        
        do {
            await socialService.updateTeamMemberRole(
                teamId: member.teamId,
                userId: member.userId,
                newRole: role
            )
            
            // Update local state
            if let index = teamMembers.firstIndex(where: { $0.id == member.id }) {
                teamMembers[index].role = role
            }
            
            // Add activity record
            let activity = TeamActivity(
                id: UUID().uuidString,
                teamId: member.teamId.uuidString,
                userId: currentUserId?.uuidString ?? "",
                user: socialService.currentUserProfile ?? UserProfile.sample,
                type: .roleChanged,
                description: "\(member.displayName) was promoted to \(role.displayName)",
                metadata: ["newRole": role.rawValue],
                timestamp: Date()
            )
            recentActivities.insert(activity, at: 0)
            
        } catch {
            errorMessage = "Failed to update member role: \(error.localizedDescription)"
        }
    }
    
    func removeMember(_ member: TeamMember) async {
        guard currentUserRole == .admin || currentUserRole == .owner else {
            errorMessage = "You don't have permission to remove members."
            return
        }
        
        guard member.role != .owner else {
            errorMessage = "Cannot remove the team owner."
            return
        }
        
        do {
            await socialService.removeTeamMember(
                teamId: member.teamId,
                userId: member.userId
            )
            
            // Update local state
            teamMembers.removeAll { $0.id == member.id }
            teamStats.memberCount -= 1
            
            // Add activity record
            let activity = TeamActivity(
                id: UUID().uuidString,
                teamId: member.teamId.uuidString,
                userId: currentUserId?.uuidString ?? "",
                user: socialService.currentUserProfile ?? UserProfile.sample,
                type: .memberLeft,
                description: "\(member.displayName) was removed from the team",
                metadata: [:],
                timestamp: Date()
            )
            recentActivities.insert(activity, at: 0)
            
        } catch {
            errorMessage = "Failed to remove member: \(error.localizedDescription)"
        }
    }
    
    func inviteMembers(_ emails: [String]) async {
        guard currentUserRole == .admin || currentUserRole == .owner || currentUserRole == .moderator else {
            errorMessage = "You don't have permission to invite members."
            return
        }
        
        do {
            for email in emails {
                await socialService.inviteToTeam(
                    teamId: teamId!,
                    email: email
                )
            }
            
            // Add activity record
            let activity = TeamActivity(
                id: UUID().uuidString,
                teamId: teamId?.uuidString ?? "",
                userId: currentUserId?.uuidString ?? "",
                user: socialService.currentUserProfile ?? UserProfile.sample,
                type: .membersInvited,
                description: "Invited \(emails.count) new members",
                metadata: ["count": "\(emails.count)"],
                timestamp: Date()
            )
            recentActivities.insert(activity, at: 0)
            
        } catch {
            errorMessage = "Failed to send invitations: \(error.localizedDescription)"
        }
    }
    
    func leaveTeam(_ team: Team) async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            await socialService.leaveTeam(teamId: team.id)
            
            // Add activity record
            let activity = TeamActivity(
                id: UUID().uuidString,
                teamId: team.id.uuidString,
                userId: currentUserId.uuidString,
                user: socialService.currentUserProfile ?? UserProfile.sample,
                type: .memberLeft,
                description: "Left the team",
                metadata: [:],
                timestamp: Date()
            )
            recentActivities.insert(activity, at: 0)
            
        } catch {
            errorMessage = "Failed to leave team: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Chat Functions
    func sendMessage(_ content: String, to teamId: UUID) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let currentUser = socialService.currentUserProfile else { return }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            senderId: currentUser.id.uuidString,
            senderName: currentUser.displayName,
            senderAvatarURL: currentUser.avatarURL,
            content: content,
            timestamp: Date(),
            type: .text,
            isRead: false
        )
        
        // Add to local state immediately
        chatMessages.append(message)
        
        // Send to backend
        do {
            await socialService.sendTeamMessage(
                teamId: teamId,
                content: content
            )
        } catch {
            // Remove from local state if failed
            chatMessages.removeAll { $0.id == message.id }
            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }
    
    func markMessagesAsRead() async {
        guard let teamId = teamId else { return }
        
        do {
            await socialService.markTeamMessagesAsRead(teamId: teamId)
            unreadMessages = 0
            
            // Update local messages
            for index in chatMessages.indices {
                chatMessages[index].isRead = true
            }
        } catch {
            errorMessage = "Failed to mark messages as read: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Team Event Management
    func createEvent(title: String, description: String, date: Date) async {
        guard currentUserRole == .admin || currentUserRole == .owner || currentUserRole == .moderator else {
            errorMessage = "You don't have permission to create events."
            return
        }
        
        let event = TeamEvent(
            id: UUID().uuidString,
            teamId: teamId?.uuidString ?? "",
            title: title,
            description: description,
            date: date,
            creatorId: currentUserId?.uuidString ?? "",
            participantCount: 0,
            maxParticipants: nil,
            type: .workout
        )
        
        do {
            await socialService.createTeamEvent(event)
            upcomingEvents.append(event)
            upcomingEvents.sort { $0.date < $1.date }
            
            // Add activity record
            let activity = TeamActivity(
                id: UUID().uuidString,
                teamId: teamId?.uuidString ?? "",
                userId: currentUserId?.uuidString ?? "",
                user: socialService.currentUserProfile ?? UserProfile.sample,
                type: .eventCreated,
                description: "Created event: \(title)",
                metadata: ["eventTitle": title],
                timestamp: Date()
            )
            recentActivities.insert(activity, at: 0)
            
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Statistics Updates
    func refreshStats() async {
        guard let teamId = teamId else { return }
        await loadTeamStats(teamId)
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Listen for real-time team updates
        socialService.$teams
            .sink { [weak self] teams in
                if let teamId = self?.teamId,
                   let updatedTeam = teams.first(where: { $0.id == teamId }) {
                    // Update team data when changes occur
                    Task {
                        await self?.refreshStats()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for new messages
        socialService.$teamMessages
            .sink { [weak self] messages in
                if let teamId = self?.teamId {
                    let teamMessages = messages.filter { $0.teamId == teamId.uuidString }
                    self?.chatMessages = teamMessages.sorted { $0.timestamp < $1.timestamp }
                    self?.unreadMessages = teamMessages.filter { !$0.isRead }.count
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadTeamMembers(_ teamId: UUID) async {
        do {
            let members = await socialService.getTeamMembers(teamId: teamId)
            teamMembers = members
            activeMembers = members.filter { $0.isActive }.count
        } catch {
            print("Failed to load team members: \(error)")
        }
    }
    
    private func loadTeamChallenges(_ teamId: UUID) async {
        do {
            teamChallenges = await socialService.getTeamChallenges(teamId: teamId)
        } catch {
            print("Failed to load team challenges: \(error)")
        }
    }
    
    private func loadTeamWorkouts(_ teamId: UUID) async {
        do {
            teamWorkouts = await socialService.getTeamWorkouts(teamId: teamId)
        } catch {
            print("Failed to load team workouts: \(error)")
        }
    }
    
    private func loadChatMessages(_ teamId: UUID) async {
        do {
            let messages = await socialService.getTeamMessages(teamId: teamId)
            chatMessages = messages.sorted { $0.timestamp < $1.timestamp }
            unreadMessages = messages.filter { !$0.isRead }.count
        } catch {
            print("Failed to load chat messages: \(error)")
        }
    }
    
    private func loadTeamStats(_ teamId: UUID) async {
        do {
            teamStats = await socialService.getTeamStatistics(teamId: teamId)
        } catch {
            print("Failed to load team stats: \(error)")
        }
    }
    
    private func loadRecentActivities(_ teamId: UUID) async {
        do {
            recentActivities = await socialService.getTeamActivities(teamId: teamId)
        } catch {
            print("Failed to load recent activities: \(error)")
        }
    }
    
    private func loadUpcomingEvents(_ teamId: UUID) async {
        do {
            upcomingEvents = await socialService.getTeamEvents(teamId: teamId)
                .filter { $0.date > Date() }
                .sorted { $0.date < $1.date }
        } catch {
            print("Failed to load upcoming events: \(error)")
        }
    }
    
    private func loadTopPerformers(_ teamId: UUID) async {
        do {
            topPerformers = await socialService.getTeamTopPerformers(teamId: teamId)
        } catch {
            print("Failed to load top performers: \(error)")
        }
    }
    
    private func checkCurrentUserRole(_ teamId: UUID) async {
        guard let currentUserId = currentUserId else { return }
        
        if let member = teamMembers.first(where: { $0.userId == currentUserId }) {
            currentUserRole = member.role
        }
    }
}

// MARK: - Supporting Models

struct TeamStatistics {
    let memberCount: Int
    let totalWorkouts: Int
    let totalDistance: Double
    let totalCalories: Double
    let averageWeeklyWorkouts: Double
    let activeChallenges: Int
    let weeklyActiveMembers: Int
    let monthlyGrowthRate: Double
    
    static let empty = TeamStatistics(
        memberCount: 0,
        totalWorkouts: 0,
        totalDistance: 0,
        totalCalories: 0,
        averageWeeklyWorkouts: 0,
        activeChallenges: 0,
        weeklyActiveMembers: 0,
        monthlyGrowthRate: 0
    )
}

struct TeamWorkout {
    let id: String
    let teamId: String
    let userId: String
    let userName: String
    let userAvatarURL: String?
    let workoutType: String
    let duration: TimeInterval
    let caloriesBurned: Double
    let distance: Double?
    let averageHeartRate: Double?
    let timestamp: Date
    let isShared: Bool
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let senderId: String
    let senderName: String
    let senderAvatarURL: String?
    let content: String
    let timestamp: Date
    let type: MessageType
    var isRead: Bool
    
    enum MessageType: String, Codable {
        case text, image, workout, achievement, system
    }
}

struct TeamEvent: Identifiable, Codable {
    let id: String
    let teamId: String
    let title: String
    let description: String
    let date: Date
    let creatorId: String
    var participantCount: Int
    let maxParticipants: Int?
    let type: EventType
    
    enum EventType: String, Codable, CaseIterable {
        case workout, challenge, social, competition
        
        var displayName: String {
            switch self {
            case .workout: return "Workout"
            case .challenge: return "Challenge"
            case .social: return "Social"
            case .competition: return "Competition"
            }
        }
        
        var iconName: String {
            switch self {
            case .workout: return "figure.run"
            case .challenge: return "target"
            case .social: return "person.3.fill"
            case .competition: return "trophy.fill"
            }
        }
    }
}

// MARK: - Extensions

extension TeamActivity {
    enum TeamActivityType: String, Codable {
        case memberJoined = "member_joined"
        case memberLeft = "member_left"
        case roleChanged = "role_changed"
        case membersInvited = "members_invited"
        case challengeCompleted = "challenge_completed"
        case eventCreated = "event_created"
        case workoutShared = "workout_shared"
        case achievementUnlocked = "achievement_unlocked"
        
        var iconName: String {
            switch self {
            case .memberJoined: return "person.badge.plus"
            case .memberLeft: return "person.badge.minus"
            case .roleChanged: return "person.badge.key"
            case .membersInvited: return "envelope.badge.plus"
            case .challengeCompleted: return "checkmark.circle.fill"
            case .eventCreated: return "calendar.badge.plus"
            case .workoutShared: return "square.and.arrow.up"
            case .achievementUnlocked: return "trophy.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .memberJoined, .membersInvited: return .green
            case .memberLeft: return .red
            case .roleChanged: return .blue
            case .challengeCompleted, .achievementUnlocked: return .yellow
            case .eventCreated: return .purple
            case .workoutShared: return .orange
            }
        }
    }
}
