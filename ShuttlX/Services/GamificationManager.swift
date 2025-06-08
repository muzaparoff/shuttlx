import Foundation
import Combine

@MainActor
class GamificationManager: ObservableObject {
    static let shared = GamificationManager()
    
    @Published var currentLevel: Int = 1
    @Published var currentXP: Int = 0
    @Published var xpToNextLevel: Int = 100
    @Published var totalXP: Int = 0
    @Published var streak: Int = 0
    @Published var badges: [Badge] = []
    @Published var achievements: [Achievement] = []
    @Published var dailyChallenges: [DailyChallenge] = []
    @Published var weeklyGoals: [WeeklyGoal] = []
    @Published var recentRewards: [Reward] = []
    @Published var multiplierActive: Bool = false
    @Published var multiplierEndTime: Date?
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private var socialService: SocialService?
    
    // XP Values
    private let xpValues: [String: Int] = [
        "workout_completed": 50,
        "personal_record": 100,
        "streak_milestone": 150,
        "challenge_completed": 200,
        "social_interaction": 25,
        "goal_achieved": 300,
        "badge_earned": 500,
        "friend_referred": 1000,
        "consistency_bonus": 75
    ]
    
    private init() {
        loadUserProgress()
        setupNotifications()
    }
    
    // MARK: - Configuration
    
    func configure(socialService: SocialService) {
        self.socialService = socialService
    }
    
    // MARK: - XP and Level Management
    
    func awardXP(for action: String, amount: Int? = nil) {
        let baseAmount = amount ?? xpValues[action] ?? 0
        let finalAmount = multiplierActive ? Int(Double(baseAmount) * 1.5) : baseAmount
        
        currentXP += finalAmount
        totalXP += finalAmount
        
        // Check for level up
        checkLevelUp()
        
        // Save progress
        saveUserProgress()
        
        // Create reward for UI feedback
        let reward = Reward(
            type: .xp,
            title: "+\(finalAmount) XP",
            description: getActionDescription(action),
            value: finalAmount,
            isMultiplier: multiplierActive
        )
        
        recentRewards.append(reward)
        
        // Remove reward after display time
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.recentRewards.removeAll { $0.id == reward.id }
        }
        
        // Check for achievements
        checkAchievements(action: action, amount: finalAmount)
        
        // Post notification for haptic feedback
        NotificationCenter.default.post(name: .xpAwarded, object: reward)
    }
    
    private func checkLevelUp() {
        while currentXP >= xpToNextLevel {
            currentXP -= xpToNextLevel
            currentLevel += 1
            xpToNextLevel = calculateXPForLevel(currentLevel + 1)
            
            // Award level up rewards
            awardLevelUpRewards()
            
            // Post notification
            NotificationCenter.default.post(name: .levelUp, object: currentLevel)
        }
    }
    
    private func calculateXPForLevel(_ level: Int) -> Int {
        // Exponential curve: base 100 XP, increases by 50% each level
        return Int(100 * pow(1.5, Double(level - 1)))
    }
    
    private func awardLevelUpRewards() {
        let reward = Reward(
            type: .levelUp,
            title: "Level \(currentLevel)!",
            description: "You've reached a new level!",
            value: currentLevel
        )
        
        recentRewards.append(reward)
        
        // Award level-specific rewards
        switch currentLevel {
        case 5:
            awardBadge(.earlyAchiever)
        case 10:
            awardBadge(.dedicated)
        case 25:
            awardBadge(.committed)
        case 50:
            awardBadge(.expert)
        case 100:
            awardBadge(.master)
        default:
            break
        }
    }
    
    // MARK: - Streak Management
    
    func updateStreak(completed: Bool) {
        if completed {
            streak += 1
            
            // Award streak milestones
            if streak % 7 == 0 {
                awardXP(for: "streak_milestone")
                awardBadge(.weekWarrior)
            }
            
            if streak % 30 == 0 {
                awardBadge(.monthlyChampion)
            }
            
            if streak >= 100 {
                awardBadge(.centurion)
            }
            
        } else {
            // Break streak but don't reset immediately
            // Allow grace period for missed days
            if streak > 0 {
                streak = 0
                
                let reward = Reward(
                    type: .streakLost,
                    title: "Streak Lost",
                    description: "Your streak has been reset. Start a new one!",
                    value: 0
                )
                
                recentRewards.append(reward)
            }
        }
        
        saveUserProgress()
    }
    
    // MARK: - Badge System
    
    func awardBadge(_ badgeType: BadgeType) {
        guard !badges.contains(where: { $0.type == badgeType }) else { return }
        
        let badge = Badge(
            type: badgeType,
            earnedAt: Date(),
            isNew: true
        )
        
        badges.append(badge)
        
        let reward = Reward(
            type: .badge,
            title: "New Badge!",
            description: badgeType.description,
            value: badgeType.xpValue
        )
        
        recentRewards.append(reward)
        awardXP(for: "badge_earned", amount: badgeType.xpValue)
        
        // Post notification
        NotificationCenter.default.post(name: .badgeEarned, object: badge)
        
        saveUserProgress()
    }
    
    func markBadgeAsSeen(_ badge: Badge) {
        if let index = badges.firstIndex(where: { $0.id == badge.id }) {
            badges[index].isNew = false
            saveUserProgress()
        }
    }
    
    // MARK: - Achievement System
    
    private func checkAchievements(action: String, amount: Int) {
        for achievementType in AchievementType.allCases {
            if !achievements.contains(where: { $0.type == achievementType }) {
                if shouldAwardAchievement(achievementType, action: action, amount: amount) {
                    awardAchievement(achievementType)
                }
            }
        }
    }
    
    private func shouldAwardAchievement(_ type: AchievementType, action: String, amount: Int) -> Bool {
        switch type {
        case .firstWorkout:
            return action == "workout_completed" && getTotalWorkouts() == 1
        case .hundredWorkouts:
            return action == "workout_completed" && getTotalWorkouts() >= 100
        case .socialButterfly:
            return action == "social_interaction" && getTotalSocialInteractions() >= 50
        case .goalGetter:
            return action == "goal_achieved" && getTotalGoalsAchieved() >= 10
        case .weekendWarrior:
            return isWeekend() && action == "workout_completed"
        case .earlyBird:
            return isEarlyMorning() && action == "workout_completed"
        case .nightOwl:
            return isLateNight() && action == "workout_completed"
        case .consistencyKing:
            return streak >= 30
        case .challengeChampion:
            return getTotalChallengesCompleted() >= 5
        case .teamPlayer:
            return getTotalTeamWorkouts() >= 25
        }
    }
    
    private func awardAchievement(_ type: AchievementType) {
        let achievement = Achievement(
            type: type,
            earnedAt: Date(),
            progress: 1.0,
            isNew: true
        )
        
        achievements.append(achievement)
        
        let reward = Reward(
            type: .achievement,
            title: "Achievement Unlocked!",
            description: type.description,
            value: type.xpValue
        )
        
        recentRewards.append(reward)
        awardXP(for: "badge_earned", amount: type.xpValue)
        
        // Post notification
        NotificationCenter.default.post(name: .achievementEarned, object: achievement)
        
        saveUserProgress()
    }
    
    // MARK: - Daily Challenges
    
    func loadDailyChallenges() {
        Task {
            do {
                dailyChallenges = try await socialService.getDailyChallenges()
            } catch {
                print("Failed to load daily challenges: \(error)")
            }
        }
    }
    
    func completeDailyChallenge(_ challenge: DailyChallenge) {
        if let index = dailyChallenges.firstIndex(where: { $0.id == challenge.id }) {
            dailyChallenges[index].isCompleted = true
            dailyChallenges[index].completedAt = Date()
            
            awardXP(for: "challenge_completed", amount: challenge.xpReward)
            
            let reward = Reward(
                type: .challenge,
                title: "Challenge Complete!",
                description: challenge.title,
                value: challenge.xpReward
            )
            
            recentRewards.append(reward)
        }
    }
    
    // MARK: - Weekly Goals
    
    func loadWeeklyGoals() {
        Task {
            do {
                weeklyGoals = try await socialService.getWeeklyGoals()
            } catch {
                print("Failed to load weekly goals: \(error)")
            }
        }
    }
    
    func updateWeeklyGoalProgress(_ goal: WeeklyGoal, progress: Double) {
        if let index = weeklyGoals.firstIndex(where: { $0.id == goal.id }) {
            weeklyGoals[index].progress = min(progress, 1.0)
            
            if weeklyGoals[index].progress >= 1.0 && !weeklyGoals[index].isCompleted {
                weeklyGoals[index].isCompleted = true
                weeklyGoals[index].completedAt = Date()
                
                awardXP(for: "goal_achieved", amount: goal.xpReward)
                
                let reward = Reward(
                    type: .goal,
                    title: "Goal Achieved!",
                    description: goal.title,
                    value: goal.xpReward
                )
                
                recentRewards.append(reward)
            }
        }
    }
    
    // MARK: - Multipliers
    
    func activateXPMultiplier(duration: TimeInterval) {
        multiplierActive = true
        multiplierEndTime = Date().addingTimeInterval(duration)
        
        let reward = Reward(
            type: .multiplier,
            title: "XP Boost Active!",
            description: "1.5x XP for the next \(Int(duration/60)) minutes",
            value: 0,
            isMultiplier: true
        )
        
        recentRewards.append(reward)
        
        // Schedule multiplier end
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.multiplierActive = false
            self.multiplierEndTime = nil
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveUserProgress() {
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(GamificationData(
            currentLevel: currentLevel,
            currentXP: currentXP,
            totalXP: totalXP,
            streak: streak,
            badges: badges,
            achievements: achievements
        )) {
            userDefaults.set(encoded, forKey: "gamification_data")
        }
    }
    
    private func loadUserProgress() {
        guard let data = userDefaults.data(forKey: "gamification_data"),
              let decoded = try? JSONDecoder().decode(GamificationData.self, from: data) else {
            return
        }
        
        currentLevel = decoded.currentLevel
        currentXP = decoded.currentXP
        totalXP = decoded.totalXP
        streak = decoded.streak
        badges = decoded.badges
        achievements = decoded.achievements
        xpToNextLevel = calculateXPForLevel(currentLevel + 1)
    }
    
    private func setupNotifications() {
        // Setup local notifications for daily challenges and streaks
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.loadDailyChallenges()
            self.loadWeeklyGoals()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getActionDescription(_ action: String) -> String {
        switch action {
        case "workout_completed": return "Workout completed"
        case "personal_record": return "Personal record achieved"
        case "streak_milestone": return "Streak milestone reached"
        case "challenge_completed": return "Challenge completed"
        case "social_interaction": return "Social interaction"
        case "goal_achieved": return "Goal achieved"
        case "badge_earned": return "Badge earned"
        case "friend_referred": return "Friend referred"
        case "consistency_bonus": return "Consistency bonus"
        default: return "Action completed"
        }
    }
    
    // These would be implemented with actual data sources
    private func getTotalWorkouts() -> Int { return 0 }
    private func getTotalSocialInteractions() -> Int { return 0 }
    private func getTotalGoalsAchieved() -> Int { return 0 }
    private func getTotalChallengesCompleted() -> Int { return 0 }
    private func getTotalTeamWorkouts() -> Int { return 0 }
    private func isWeekend() -> Bool { return [1, 7].contains(Calendar.current.component(.weekday, from: Date())) }
    private func isEarlyMorning() -> Bool { return Calendar.current.component(.hour, from: Date()) < 7 }
    private func isLateNight() -> Bool { return Calendar.current.component(.hour, from: Date()) > 22 }
}

// MARK: - Supporting Models

struct GamificationData: Codable {
    let currentLevel: Int
    let currentXP: Int
    let totalXP: Int
    let streak: Int
    let badges: [Badge]
    let achievements: [Achievement]
}

struct Badge: Identifiable, Codable {
    let id = UUID()
    let type: BadgeType
    let earnedAt: Date
    var isNew: Bool
    
    var title: String { type.title }
    var description: String { type.description }
    var iconName: String { type.iconName }
    var color: String { type.color }
}

enum BadgeType: String, CaseIterable, Codable {
    case earlyAchiever = "early_achiever"
    case dedicated = "dedicated"
    case committed = "committed"
    case expert = "expert"
    case master = "master"
    case weekWarrior = "week_warrior"
    case monthlyChampion = "monthly_champion"
    case centurion = "centurion"
    case socialButterfly = "social_butterfly"
    case teamPlayer = "team_player"
    case challengeChaser = "challenge_chaser"
    case goalGetter = "goal_getter"
    case consistencyKing = "consistency_king"
    case earlyBird = "early_bird"
    case nightOwl = "night_owl"
    
    var title: String {
        switch self {
        case .earlyAchiever: return "Early Achiever"
        case .dedicated: return "Dedicated"
        case .committed: return "Committed"
        case .expert: return "Expert"
        case .master: return "Master"
        case .weekWarrior: return "Week Warrior"
        case .monthlyChampion: return "Monthly Champion"
        case .centurion: return "Centurion"
        case .socialButterfly: return "Social Butterfly"
        case .teamPlayer: return "Team Player"
        case .challengeChaser: return "Challenge Chaser"
        case .goalGetter: return "Goal Getter"
        case .consistencyKing: return "Consistency King"
        case .earlyBird: return "Early Bird"
        case .nightOwl: return "Night Owl"
        }
    }
    
    var description: String {
        switch self {
        case .earlyAchiever: return "Reached level 5"
        case .dedicated: return "Reached level 10"
        case .committed: return "Reached level 25"
        case .expert: return "Reached level 50"
        case .master: return "Reached level 100"
        case .weekWarrior: return "Maintained a 7-day streak"
        case .monthlyChampion: return "Maintained a 30-day streak"
        case .centurion: return "Maintained a 100-day streak"
        case .socialButterfly: return "Made 50 social interactions"
        case .teamPlayer: return "Completed 25 team workouts"
        case .challengeChaser: return "Completed 10 challenges"
        case .goalGetter: return "Achieved 10 goals"
        case .consistencyKing: return "Maintained a 30-day consistency streak"
        case .earlyBird: return "Completed 10 early morning workouts"
        case .nightOwl: return "Completed 10 late night workouts"
        }
    }
    
    var iconName: String {
        switch self {
        case .earlyAchiever: return "star.fill"
        case .dedicated: return "heart.fill"
        case .committed: return "flame.fill"
        case .expert: return "crown.fill"
        case .master: return "sparkles"
        case .weekWarrior: return "calendar"
        case .monthlyChampion: return "calendar.badge.plus"
        case .centurion: return "calendar.badge.exclamationmark"
        case .socialButterfly: return "person.2.fill"
        case .teamPlayer: return "person.3.fill"
        case .challengeChaser: return "flag.2.crossed.fill"
        case .goalGetter: return "target"
        case .consistencyKing: return "checkmark.seal.fill"
        case .earlyBird: return "sun.max.fill"
        case .nightOwl: return "moon.fill"
        }
    }
    
    var color: String {
        switch self {
        case .earlyAchiever: return "blue"
        case .dedicated: return "red"
        case .committed: return "orange"
        case .expert: return "purple"
        case .master: return "yellow"
        case .weekWarrior: return "green"
        case .monthlyChampion: return "teal"
        case .centurion: return "indigo"
        case .socialButterfly: return "pink"
        case .teamPlayer: return "cyan"
        case .challengeChaser: return "mint"
        case .goalGetter: return "brown"
        case .consistencyKing: return "gray"
        case .earlyBird: return "yellow"
        case .nightOwl: return "purple"
        }
    }
    
    var xpValue: Int {
        switch self {
        case .earlyAchiever, .weekWarrior: return 100
        case .dedicated, .monthlyChampion: return 250
        case .committed, .socialButterfly, .teamPlayer: return 500
        case .expert, .challengeChaser, .goalGetter: return 750
        case .master, .centurion, .consistencyKing: return 1000
        case .earlyBird, .nightOwl: return 150
        }
    }
}

struct Achievement: Identifiable, Codable {
    let id = UUID()
    let type: AchievementType
    let earnedAt: Date
    var progress: Double
    var isNew: Bool
    
    var title: String { type.title }
    var description: String { type.description }
    var iconName: String { type.iconName }
}

enum AchievementType: String, CaseIterable, Codable {
    case firstWorkout = "first_workout"
    case hundredWorkouts = "hundred_workouts"
    case socialButterfly = "social_butterfly_achievement"
    case goalGetter = "goal_getter_achievement"
    case weekendWarrior = "weekend_warrior"
    case earlyBird = "early_bird_achievement"
    case nightOwl = "night_owl_achievement"
    case consistencyKing = "consistency_king_achievement"
    case challengeChampion = "challenge_champion"
    case teamPlayer = "team_player_achievement"
    
    var title: String {
        switch self {
        case .firstWorkout: return "First Step"
        case .hundredWorkouts: return "Century Club"
        case .socialButterfly: return "Social Butterfly"
        case .goalGetter: return "Goal Getter"
        case .weekendWarrior: return "Weekend Warrior"
        case .earlyBird: return "Early Bird"
        case .nightOwl: return "Night Owl"
        case .consistencyKing: return "Consistency King"
        case .challengeChampion: return "Challenge Champion"
        case .teamPlayer: return "Team Player"
        }
    }
    
    var description: String {
        switch self {
        case .firstWorkout: return "Complete your first workout"
        case .hundredWorkouts: return "Complete 100 workouts"
        case .socialButterfly: return "Make 50 social interactions"
        case .goalGetter: return "Achieve 10 goals"
        case .weekendWarrior: return "Work out on weekends"
        case .earlyBird: return "Work out before 7 AM"
        case .nightOwl: return "Work out after 10 PM"
        case .consistencyKing: return "Maintain a 30-day streak"
        case .challengeChampion: return "Complete 5 challenges"
        case .teamPlayer: return "Complete 25 team workouts"
        }
    }
    
    var iconName: String {
        switch self {
        case .firstWorkout: return "figure.walk"
        case .hundredWorkouts: return "100.square.fill"
        case .socialButterfly: return "person.2.wave.2.fill"
        case .goalGetter: return "target"
        case .weekendWarrior: return "calendar.badge.clock"
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .consistencyKing: return "checkmark.seal.fill"
        case .challengeChampion: return "trophy.fill"
        case .teamPlayer: return "person.3.sequence.fill"
        }
    }
    
    var xpValue: Int {
        switch self {
        case .firstWorkout: return 50
        case .hundredWorkouts: return 1000
        case .socialButterfly: return 300
        case .goalGetter: return 500
        case .weekendWarrior: return 200
        case .earlyBird, .nightOwl: return 150
        case .consistencyKing: return 750
        case .challengeChampion: return 600
        case .teamPlayer: return 400
        }
    }
}

struct DailyChallenge: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let target: Double
    let unit: String
    let xpReward: Int
    let category: ChallengeCategory
    var progress: Double = 0
    var isCompleted: Bool = false
    var completedAt: Date?
    let expiresAt: Date
    
    enum ChallengeCategory: String, CaseIterable, Codable {
        case distance = "distance"
        case duration = "duration"
        case calories = "calories"
        case social = "social"
        case consistency = "consistency"
        
        var iconName: String {
            switch self {
            case .distance: return "location.fill"
            case .duration: return "clock.fill"
            case .calories: return "flame.fill"
            case .social: return "person.2.fill"
            case .consistency: return "calendar"
            }
        }
    }
}

struct WeeklyGoal: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let target: Double
    let unit: String
    let xpReward: Int
    let category: GoalCategory
    var progress: Double = 0
    var isCompleted: Bool = false
    var completedAt: Date?
    let weekStartDate: Date
    let weekEndDate: Date
    
    enum GoalCategory: String, CaseIterable, Codable {
        case workouts = "workouts"
        case distance = "distance"
        case duration = "duration"
        case calories = "calories"
        case social = "social"
        
        var iconName: String {
            switch self {
            case .workouts: return "figure.run"
            case .distance: return "location.fill"
            case .duration: return "clock.fill"
            case .calories: return "flame.fill"
            case .social: return "person.2.fill"
            }
        }
    }
}

struct Reward: Identifiable {
    let id = UUID()
    let type: RewardType
    let title: String
    let description: String
    let value: Int
    var isMultiplier: Bool = false
    let timestamp = Date()
    
    enum RewardType {
        case xp
        case badge
        case achievement
        case levelUp
        case challenge
        case goal
        case multiplier
        case streakLost
        
        var iconName: String {
            switch self {
            case .xp: return "star.fill"
            case .badge: return "rosette"
            case .achievement: return "trophy.fill"
            case .levelUp: return "arrow.up.circle.fill"
            case .challenge: return "flag.2.crossed.fill"
            case .goal: return "target"
            case .multiplier: return "bolt.fill"
            case .streakLost: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .xp: return "blue"
            case .badge: return "purple"
            case .achievement: return "yellow"
            case .levelUp: return "green"
            case .challenge: return "orange"
            case .goal: return "teal"
            case .multiplier: return "cyan"
            case .streakLost: return "red"
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let xpAwarded = Notification.Name("xpAwarded")
    static let levelUp = Notification.Name("levelUp")
    static let badgeEarned = Notification.Name("badgeEarned")
    static let achievementEarned = Notification.Name("achievementEarned")
}
