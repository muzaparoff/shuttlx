//
//  DashboardView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var healthManager: HealthManager
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header with user greeting
                    headerSection
                    
                    // Quick Action Cards
                    quickActionsSection
                    
                    // Today's Stats
                    todaysStatsSection
                    
                    // Recent Activity
                    recentActivitySection
                    
                    // Achievements Preview
                    achievementsSection
                    
                    // Weather & Recommendations
                    recommendationsSection
                }
                .padding(.horizontal)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshData()
            }
        }
        .onAppear {
            viewModel.loadDashboardData()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    if let user = appViewModel.currentUser {
                        Text(user.firstName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                }
                
                Spacer()
                
                // Profile Picture / Health Status
                VStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "heart.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        )
                    
                    if let heartRate = healthManager.currentHeartRate {
                        Text("\(Int(heartRate))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Readiness Score
            if let readinessScore = viewModel.readinessScore {
                ReadinessScoreView(score: readinessScore)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(WorkoutType.allCases.prefix(4), id: \.self) { workoutType in
                    QuickActionCard(workoutType: workoutType) {
                        viewModel.startQuickWorkout(workoutType)
                    }
                }
            }
        }
    }
    
    private var todaysStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                StatCard(
                    title: "Workouts",
                    value: "\(viewModel.todaysWorkouts)",
                    icon: "figure.run",
                    color: .blue
                )
                
                StatCard(
                    title: "Calories",
                    value: "\(viewModel.todaysCalories)",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Duration",
                    value: viewModel.todaysDurationText,
                    icon: "clock.fill",
                    color: .green
                )
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink("See All", destination: AnalyticsView())
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.recentWorkouts.prefix(3)) { workout in
                    RecentWorkoutRow(workout: workout)
                }
            }
        }
    }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink("View All", destination: AchievementsView())
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.recentAchievements) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                if let weather = viewModel.currentWeather {
                    WeatherRecommendationCard(weather: weather)
                }
                
                ForEach(viewModel.personalizedRecommendations) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                }
            }
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
}

// MARK: - Supporting Views
struct QuickActionCard: View {
    let workoutType: WorkoutType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: workoutType.icon)
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text(workoutType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct ReadinessScoreView: View {
    let score: Double
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.tertiary, lineWidth: 4)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(score))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Readiness Score")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(readinessDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private var readinessDescription: String {
        switch score {
        case 80...100: return "Ready for intense training"
        case 60..<80: return "Good for moderate training"
        case 40..<60: return "Consider light exercise"
        default: return "Focus on recovery"
        }
    }
}

struct RecentWorkoutRow: View {
    let workout: TrainingSession
    
    var body: some View {
        HStack {
            Image(systemName: workout.workoutConfiguration.type.icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.workoutConfiguration.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(workout.startTime, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(workout.duration))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let calories = workout.caloriesBurned {
                    Text("\(Int(calories)) cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(achievement.isUnlocked ? .yellow : .gray)
            
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
        }
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(achievement.isUnlocked ? .ultraThinMaterial : .quaternary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.isUnlocked ? .yellow : .clear, lineWidth: 2)
        )
    }
}

struct WeatherRecommendationCard: View {
    let weather: WeatherConditions
    
    var body: some View {
        HStack {
            Image(systemName: weatherIcon)
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Weather Update")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(Int(weather.temperature))°C • \(weather.condition)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(weatherRecommendation)
                .font(.caption)
                .foregroundColor(.blue)
                .multilineTextAlignment(.trailing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var weatherIcon: String {
        switch weather.condition.lowercased() {
        case let condition where condition.contains("rain"):
            return "cloud.rain.fill"
        case let condition where condition.contains("cloud"):
            return "cloud.fill"
        case let condition where condition.contains("sun"):
            return "sun.max.fill"
        default:
            return "cloud.sun.fill"
        }
    }
    
    private var weatherRecommendation: String {
        if weather.temperature < 10 {
            return "Perfect for\nintense training"
        } else if weather.temperature > 25 {
            return "Stay hydrated\nand take breaks"
        } else {
            return "Great conditions\nfor outdoor workout"
        }
    }
}

struct RecommendationCard: View {
    let recommendation: PersonalizedRecommendation
    
    var body: some View {
        HStack {
            Image(systemName: recommendation.icon)
                .font(.title3)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(AppViewModel())
            .environmentObject(HealthManager())
    }
}
