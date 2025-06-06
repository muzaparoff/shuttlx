//
//  ChallengeDetailViewModel.swift
//  ShuttlX
//
//  ViewModel for challenge detail management and real-time updates
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine

@MainActor
class ChallengeDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var challenge: Challenge?
    @Published var isUserParticipating = false
    @Published var progressDetails: ChallengeProgressDetails?
    @Published var userChallengeProgress: UserChallengeProgress?
    @Published var topParticipants: [ChallengeParticipant] = []
    @Published var recentActivity: [ChallengeActivity] = []
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let socialService: SocialService
    private var cancellables = Set<AnyCancellable>()
    private var challengeId: UUID?
    
    // MARK: - Initialization
    init(socialService: SocialService) {
        self.socialService = socialService
        setupObservers()
    }
    
    // MARK: - Public Methods
    func loadChallengeData(challengeId: UUID) {
        self.challengeId = challengeId
        isLoading = true
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadChallengeDetails(challengeId) }
                group.addTask { await self.loadProgressDetails(challengeId) }
                group.addTask { await self.loadTopParticipants(challengeId) }
                group.addTask { await self.loadRecentActivity(challengeId) }
                group.addTask { await self.checkUserParticipation(challengeId) }
            }
            
            isLoading = false
        }
    }
    
    func joinChallenge(_ challenge: Challenge) async {
        guard let currentUser = socialService.currentUserProfile else { return }
        
        isLoading = true
        
        do {
            // Join challenge via social service
            await socialService.joinChallenge(challenge.id)
            
            // Update local state
            isUserParticipating = true
            
            // Create user progress tracking
            userChallengeProgress = UserChallengeProgress(
                challengeId: challenge.id,
                userId: currentUser.id,
                totalProgress: 0.0,
                completedSessions: 0,
                streak: 0,
                dailyProgress: Array(repeating: 0.0, count: challengeDurationInDays(challenge)),
                lastUpdateDate: Date()
            )
            
            // Reload data to reflect changes
            await loadChallengeData(challengeId: challenge.id)
            
        } catch {
            errorMessage = "Failed to join challenge: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func leaveChallenge(_ challenge: Challenge) async {
        isLoading = true
        
        do {
            // Leave challenge via social service
            await socialService.leaveChallenge(challenge.id)
            
            // Update local state
            isUserParticipating = false
            userChallengeProgress = nil
            
            // Reload data to reflect changes
            await loadChallengeData(challengeId: challenge.id)
            
        } catch {
            errorMessage = "Failed to leave challenge: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateProgress(sessions: Int, progress: Double) async {
        guard var userProgress = userChallengeProgress else { return }
        
        // Update user progress
        userProgress.completedSessions = sessions
        userProgress.totalProgress = progress
        userProgress.lastUpdateDate = Date()
        
        // Update daily progress
        let today = Calendar.current.startOfDay(for: Date())
        if let challengeStart = challenge?.startDate,
           let dayIndex = Calendar.current.dateComponents([.day], from: challengeStart, to: today).day,
           dayIndex >= 0 && dayIndex < userProgress.dailyProgress.count {
            userProgress.dailyProgress[dayIndex] = progress
        }
        
        // Update streak
        userProgress.streak = calculateCurrentStreak(userProgress.dailyProgress)
        
        self.userChallengeProgress = userProgress
        
        // Sync with backend
        await socialService.updateChallengeProgress(
            challengeId: userProgress.challengeId,
            progress: progress,
            sessions: sessions
        )
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Listen for real-time challenge updates
        socialService.$challenges
            .sink { [weak self] challenges in
                if let challengeId = self?.challengeId,
                   let updatedChallenge = challenges.first(where: { $0.id == challengeId }) {
                    self?.challenge = updatedChallenge
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadChallengeDetails(_ challengeId: UUID) async {
        challenge = await socialService.getChallengeDetails(challengeId)
    }
    
    private func loadProgressDetails(_ challengeId: UUID) async {
        // Simulate loading progress details
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        progressDetails = ChallengeProgressDetails(
            userProgress: Double.random(in: 0.3...0.9),
            userRank: Int.random(in: 1...50),
            averageProgress: Double.random(in: 0.4...0.7),
            topProgress: Double.random(in: 0.8...1.0),
            totalParticipants: Int.random(in: 50...200),
            completionRate: Double.random(in: 0.6...0.9)
        )
    }
    
    private func loadTopParticipants(_ challengeId: UUID) async {
        topParticipants = await socialService.getChallengeLeaderboard(challengeId)
    }
    
    private func loadRecentActivity(_ challengeId: UUID) async {
        recentActivity = await socialService.getChallengeActivity(challengeId)
    }
    
    private func checkUserParticipation(_ challengeId: UUID) async {
        isUserParticipating = await socialService.isUserParticipatingInChallenge(challengeId)
        
        if isUserParticipating {
            userChallengeProgress = await socialService.getUserChallengeProgress(challengeId)
        }
    }
    
    private func challengeDurationInDays(_ challenge: Challenge) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: challenge.startDate, to: challenge.endDate).day ?? 1
    }
    
    private func calculateCurrentStreak(_ dailyProgress: [Double]) -> Int {
        var streak = 0
        
        // Count backwards from today to find current streak
        for progress in dailyProgress.reversed() {
            if progress > 0 {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
}

// MARK: - Supporting Models

struct ChallengeProgressDetails {
    let userProgress: Double
    let userRank: Int
    let averageProgress: Double
    let topProgress: Double
    let totalParticipants: Int
    let completionRate: Double
}

struct UserChallengeProgress {
    let challengeId: UUID
    let userId: UUID
    var totalProgress: Double
    var completedSessions: Int
    var streak: Int
    var dailyProgress: [Double]
    var lastUpdateDate: Date
}

struct ChallengeParticipant {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarURL: String?
    let progress: Double
    let completedSessions: Int
    let joinDate: Date
    
    var progressText: String {
        if completedSessions == 1 {
            return "1 session"
        } else {
            return "\(completedSessions) sessions"
        }
    }
}

struct ChallengeActivity {
    let id: UUID
    let userId: UUID
    let username: String
    let type: ActivityType
    let message: String
    let timestamp: Date
    
    enum ActivityType {
        case joined, completed, milestone, achievement
    }
    
    var iconName: String {
        switch type {
        case .joined: return "person.badge.plus"
        case .completed: return "checkmark.circle.fill"
        case .milestone: return "flag.fill"
        case .achievement: return "trophy.fill"
        }
    }
}
