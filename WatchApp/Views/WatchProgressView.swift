import SwiftUI

struct WatchProgressView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @State private var selectedTimeframe: TimeFrame = .week
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 365
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    Text("Progress")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Track your fitness journey")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Time frame selector
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue)
                            .tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                // Quick stats
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(
                        title: "Workouts",
                        value: "\(getWorkoutCount())",
                        icon: "figure.run",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Duration",
                        value: formatTotalDuration(),
                        icon: "clock",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Calories",
                        value: "\(getTotalCalories())",
                        icon: "flame",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "Distance",
                        value: "\(String(format: "%.1f", getTotalDistance()))km",
                        icon: "location",
                        color: .purple
                    )
                }
                
                // Activity rings (if available)
                if workoutManager.hasActivityData {
                    ActivityRingsView()
                        .environmentObject(workoutManager)
                }
                
                // Recent achievements
                RecentAchievementsView()
                
                // Weekly chart
                WeeklyProgressChart(timeframe: selectedTimeframe)
                
                // Heart rate zones
                HeartRateZonesView()
                    .environmentObject(workoutManager)
            }
            .padding()
        }
    }
    
    private func getWorkoutCount() -> Int {
        // This would fetch from HealthKit or local storage
        // For now, return mock data
        switch selectedTimeframe {
        case .week: return 5
        case .month: return 18
        case .year: return 156
        }
    }
    
    private func formatTotalDuration() -> String {
        let minutes = getTotalMinutes()
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            return "\(hours)h"
        }
    }
    
    private func getTotalMinutes() -> Int {
        switch selectedTimeframe {
        case .week: return 180
        case .month: return 640
        case .year: return 4200
        }
    }
    
    private func getTotalCalories() -> Int {
        switch selectedTimeframe {
        case .week: return 1250
        case .month: return 4800
        case .year: return 38500
        }
    }
    
    private func getTotalDistance() -> Double {
        switch selectedTimeframe {
        case .week: return 15.2
        case .month: return 58.7
        case .year: return 486.3
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ActivityRingsView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Today's Activity")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ZStack {
                // Move ring (outer)
                Circle()
                    .stroke(Color.red.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: workoutManager.moveProgress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                // Exercise ring (middle)
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: workoutManager.exerciseProgress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                // Stand ring (inner)
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 6)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: workoutManager.standProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
            }
            .animation(.easeInOut(duration: 0.5), value: workoutManager.moveProgress)
            .animation(.easeInOut(duration: 0.5), value: workoutManager.exerciseProgress)
            .animation(.easeInOut(duration: 0.5), value: workoutManager.standProgress)
            
            HStack(spacing: 16) {
                ActivityRingLegend(color: .red, title: "Move", value: Int(workoutManager.moveProgress * 100))
                ActivityRingLegend(color: .green, title: "Exercise", value: Int(workoutManager.exerciseProgress * 100))
                ActivityRingLegend(color: .blue, title: "Stand", value: Int(workoutManager.standProgress * 100))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ActivityRingLegend: View {
    let color: Color
    let title: String
    let value: Int
    
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text("\(value)%")
                .font(.caption2)
                .fontWeight(.medium)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct RecentAchievementsView: View {
    let recentAchievements = [
        ("trophy.fill", "First 5K", .yellow),
        ("flame.fill", "Calorie Crusher", .orange),
        ("clock.fill", "Consistency King", .blue)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Achievements")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentAchievements.indices, id: \.self) { index in
                        let achievement = recentAchievements[index]
                        
                        VStack(spacing: 4) {
                            Image(systemName: achievement.0)
                                .font(.title2)
                                .foregroundColor(achievement.2)
                                .frame(width: 40, height: 40)
                                .background(achievement.2.opacity(0.2))
                                .cornerRadius(20)
                            
                            Text(achievement.1)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .frame(width: 60)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeeklyProgressChart: View {
    let timeframe: WatchProgressView.TimeFrame
    
    private var chartData: [Double] {
        // Mock data for demonstration
        switch timeframe {
        case .week:
            return [30, 45, 20, 60, 35, 50, 40]
        case .month:
            return Array(0..<30).map { _ in Double.random(in: 20...80) }
        case .year:
            return Array(0..<12).map { _ in Double.random(in: 100...600) }
        }
    }
    
    private var maxValue: Double {
        chartData.max() ?? 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity Trend")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(chartData.indices, id: \.self) { index in
                    let value = chartData[index]
                    let height = (value / maxValue) * 60
                    
                    Rectangle()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 8, height: max(2, height))
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.5).delay(Double(index) * 0.1), value: height)
                }
            }
            .frame(height: 60)
            
            Text("Minutes of activity")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HeartRateZonesView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    private let zones = [
        ("Zone 1", "Active Recovery", 0.6, Color.blue),
        ("Zone 2", "Aerobic Base", 0.7, Color.green),
        ("Zone 3", "Aerobic", 0.8, Color.yellow),
        ("Zone 4", "Threshold", 0.9, Color.orange),
        ("Zone 5", "VO2 Max", 1.0, Color.red)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate Zones")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 6) {
                ForEach(zones.indices, id: \.self) { index in
                    let zone = zones[index]
                    let progress = getZoneProgress(for: index)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.0)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text(zone.1)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: zone.3))
                            .frame(width: 40)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getZoneProgress(for zone: Int) -> Double {
        // Mock data - would calculate from actual workout data
        let mockData = [0.2, 0.4, 0.3, 0.1, 0.05]
        return mockData[zone]
    }
}

#Preview {
    WatchProgressView()
        .environmentObject(WatchWorkoutManager())
        .environmentObject(WatchConnectivityManager())
}
