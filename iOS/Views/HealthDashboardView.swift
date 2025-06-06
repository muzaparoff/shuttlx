//
//  HealthDashboardView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import HealthKit

struct HealthDashboardView: View {
    @StateObject private var healthManager = HealthManager()
    @State private var selectedTab = 0
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if healthManager.permissionStatus != .authorized {
                    healthPermissionView
                } else {
                    TabView(selection: $selectedTab) {
                        OverviewTab(healthManager: healthManager)
                            .tabItem {
                                Image(systemName: "heart.circle")
                                Text("Overview")
                            }
                            .tag(0)
                        
                        MetricsTab(healthManager: healthManager)
                            .tabItem {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                Text("Metrics")
                            }
                            .tag(1)
                        
                        RecoveryTab(healthManager: healthManager)
                            .tabItem {
                                Image(systemName: "bed.double")
                                Text("Recovery")
                            }
                            .tag(2)
                        
                        TrendsTab(healthManager: healthManager)
                            .tabItem {
                                Image(systemName: "chart.bar")
                                Text("Trends")
                            }
                            .tag(3)
                    }
                    .accentColor(.blue)
                }
            }
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            if healthManager.permissionStatus == .notDetermined {
                showingPermissionAlert = true
            }
        }
        .alert("Health Access Required", isPresented: $showingPermissionAlert) {
            Button("Grant Access") {
                Task {
                    await healthManager.requestPermissions()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("ShuttlX needs access to your health data to provide heart rate monitoring, workout tracking, and personalized insights.")
        }
    }
    
    // MARK: - Health Permission View
    
    private var healthPermissionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            VStack(spacing: 16) {
                Text("Health Integration")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Connect your health data to unlock advanced features")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HealthFeatureRow(
                    icon: "heart.fill",
                    title: "Real-time Heart Rate",
                    description: "Monitor your heart rate zones during workouts"
                )
                
                HealthFeatureRow(
                    icon: "flame.fill",
                    title: "Calorie Tracking",
                    description: "Accurate calorie burn calculations"
                )
                
                HealthFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Performance Analytics",
                    description: "Track your progress over time"
                )
                
                HealthFeatureRow(
                    icon: "bed.double.fill",
                    title: "Recovery Insights",
                    description: "Optimize your training with recovery data"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            Button(action: {
                Task {
                    await healthManager.requestPermissions()
                }
            }) {
                HStack {
                    Image(systemName: "heart.circle.fill")
                    Text("Connect Health Data")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                currentStatusSection
                heartRateZoneSection
                quickStatsSection
                recentActivitySection
            }
            .padding()
        }
    }
    
    private var currentStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Active")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 16) {
                HealthMetricCard(
                    title: "Heart Rate",
                    value: healthManager.currentHeartRate?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red
                )
                
                HealthMetricCard(
                    title: "Zone",
                    value: healthManager.currentHeartRateZone.displayName.components(separatedBy: " ").first ?? "Zone 1",
                    unit: "",
                    icon: "target",
                    color: Color(healthManager.getCurrentHeartRateZoneColor())
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var heartRateZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Zones")
                .font(.headline)
                .fontWeight(.semibold)
            
            HeartRateZoneChart(
                timeInZones: healthManager.timeInZones,
                currentZone: healthManager.currentHeartRateZone
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "Calories",
                    value: "\(Int(healthManager.activeEnergyBurned))",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Distance",
                    value: String(format: "%.1f", healthManager.distanceCovered / 1000),
                    unit: "km",
                    icon: "location.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Workout Time",
                    value: formatDuration(healthManager.currentHealthMetrics.workoutDuration),
                    icon: "stopwatch.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Avg HR",
                    value: healthManager.currentHealthMetrics.averageHeartRate?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {
                    // Navigate to full activity view
                }
                .foregroundColor(.blue)
            }
            
            if healthManager.workoutStatistics?.totalWorkouts ?? 0 > 0 {
                // Show recent workouts
                ForEach(0..<min(3, healthManager.workoutStatistics?.totalWorkouts ?? 0), id: \.self) { index in
                    RecentWorkoutRow(
                        type: "HIIT Training",
                        duration: "25 min",
                        calories: 234,
                        date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date()
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No recent workouts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Metrics Tab

struct MetricsTab: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                heartRateMetricsSection
                workoutStatsSection
                progressChartsSection
            }
            .padding()
        }
    }
    
    private var heartRateMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(
                    title: "Current",
                    value: healthManager.currentHeartRate?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    unit: "BPM",
                    trend: .stable,
                    color: .red
                )
                
                MetricCard(
                    title: "Max",
                    value: healthManager.currentHealthMetrics.maxHeartRate?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    unit: "BPM",
                    trend: .up,
                    color: .orange
                )
                
                MetricCard(
                    title: "Resting",
                    value: healthManager.recoveryMetrics?.restingHeartRate?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    unit: "BPM",
                    trend: .down,
                    color: .green
                )
                
                MetricCard(
                    title: "HRV",
                    value: healthManager.recoveryMetrics?.heartRateVariability?.formatted(.number.precision(.fractionLength(1))) ?? "--",
                    unit: "ms",
                    trend: .up,
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var workoutStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let stats = healthManager.workoutStatistics {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    StatCard(
                        title: "Total Workouts",
                        value: "\(stats.totalWorkouts)",
                        icon: "figure.run",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Total Time",
                        value: formatHours(stats.totalDuration),
                        icon: "clock.fill",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Total Distance",
                        value: String(format: "%.1f", stats.totalDistance / 1000),
                        unit: "km",
                        icon: "location.fill",
                        color: .purple
                    )
                    
                    StatCard(
                        title: "Calories Burned",
                        value: "\(Int(stats.totalCalories))",
                        icon: "flame.fill",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var progressChartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Charts")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Simple progress chart placeholder
            VStack(spacing: 16) {
                Text("Weekly Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    ForEach(healthManager.workoutStatistics?.weeklyProgress ?? [], id: \.self) { value in
                        Rectangle()
                            .fill(Color.blue.opacity(value / 100))
                            .frame(height: 60 * (value / 100))
                            .cornerRadius(2)
                    }
                }
                .frame(height: 80)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatHours(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Recovery Tab

struct RecoveryTab: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                readinessScoreSection
                sleepQualitySection
                stressLevelSection
                recommendationsSection
            }
            .padding()
        }
        .onAppear {
            Task {
                await healthManager.assessInjuryRisk()
            }
        }
    }
    
    private var readinessScoreSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Readiness Score")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let recovery = healthManager.recoveryMetrics {
                VStack(spacing: 8) {
                    Text("\(Int(recovery.readinessScore))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(readinessColor(recovery.readinessScore))
                    
                    Text(readinessMessage(recovery.readinessScore))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Circular progress indicator
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: recovery.readinessScore / 100)
                            .stroke(readinessColor(recovery.readinessScore), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(), value: recovery.readinessScore)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var sleepQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Quality")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let recovery = healthManager.recoveryMetrics,
               let sleepQuality = recovery.sleepQuality {
                HStack {
                    Image(systemName: "bed.double.fill")
                        .foregroundColor(Color(sleepQuality.color))
                    
                    VStack(alignment: .leading) {
                        Text(sleepQuality.rawValue.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Last night's sleep quality")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("8h 23m")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var stressLevelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stress Level")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let recovery = healthManager.recoveryMetrics {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(Color(recovery.stressLevel.color))
                    
                    VStack(alignment: .leading) {
                        Text(recovery.stressLevel.rawValue.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Based on HRV analysis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color(recovery.stressLevel.color))
                        .frame(width: 12, height: 12)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let recovery = healthManager.recoveryMetrics {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: recovery.recommendation.icon)
                            .foregroundColor(.blue)
                        
                        Text(recovery.recommendation.message)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("Based on your current recovery metrics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBlue).opacity(0.1))
                .cornerRadius(12)
            }
            
            // Injury risk assessment
            if let riskAssessment = healthManager.injuryRiskAssessment {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Injury Risk:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(riskAssessment.overallRisk.rawValue.capitalized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(riskAssessment.overallRisk.color))
                    }
                    
                    Text(riskAssessment.overallRisk.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(riskAssessment.overallRisk.color).opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func readinessColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60...79: return .yellow
        case 40...59: return .orange
        default: return .red
        }
    }
    
    private func readinessMessage(_ score: Double) -> String {
        switch score {
        case 80...100: return "You're ready for intense training!"
        case 60...79: return "Good for moderate training"
        case 40...59: return "Consider light activity today"
        default: return "Focus on recovery today"
        }
    }
}

// MARK: - Trends Tab

struct TrendsTab: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                improvementAreasSection
                streaksSection
                trendsChartsSection
            }
            .padding()
        }
    }
    
    private var improvementAreasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Improvement Areas")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let improvements = healthManager.workoutStatistics?.improvements {
                ForEach(improvements.indices, id: \.self) { index in
                    let improvement = improvements[index]
                    
                    HStack {
                        Image(systemName: improvement.icon)
                            .foregroundColor(Color(improvement.color))
                        
                        VStack(alignment: .leading) {
                            Text(improvement.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(improvement.isImprovement ? "Improved" : "Declined")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(improvement.isImprovement ? "+" : "")\(improvement.percentageChange, specifier: "%.1f")%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(improvement.color))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streaks")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let stats = healthManager.workoutStatistics {
                HStack(spacing: 16) {
                    StreakCard(
                        title: "Current Streak",
                        value: "\(stats.currentStreak)",
                        unit: "days",
                        icon: "flame.fill",
                        color: .orange
                    )
                    
                    StreakCard(
                        title: "Longest Streak",
                        value: "\(stats.longestStreak)",
                        unit: "days",
                        icon: "trophy.fill",
                        color: .yellow
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var trendsChartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Trends")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                Text("Monthly Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Simple trend line placeholder
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(healthManager.workoutStatistics?.monthlyProgress ?? [], id: \.self) { value in
                        Rectangle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 8, height: max(4, 60 * (value / 100)))
                            .cornerRadius(2)
                    }
                }
                .frame(height: 80)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Supporting Views

struct HealthFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct HealthMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .frame(height: 80)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String = ""
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .frame(height: 70)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let trend: TrendDirection
    let color: Color
    
    enum TrendDirection {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .stable: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .frame(height: 70)
    }
}

struct RecentWorkoutRow: View {
    let type: String
    let duration: String
    let calories: Int
    let date: Date
    
    var body: some View {
        HStack {
            Image(systemName: "figure.run")
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(type)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(duration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(calories) cal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StreakCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }
}

struct HeartRateZoneChart: View {
    let timeInZones: [HeartRateZone: TimeInterval]
    let currentZone: HeartRateZone
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(HeartRateZone.allCases.reversed(), id: \.self) { zone in
                HStack {
                    Text(zone.displayName.components(separatedBy: " - ").first ?? "Zone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(zone.color))
                                .frame(width: max(2, geometry.size.width * CGFloat(getZonePercentage(zone))))
                                .opacity(currentZone == zone ? 1.0 : 0.6)
                            
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 12)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
                    
                    Text(formatTime(timeInZones[zone] ?? 0))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
    
    private func getZonePercentage(_ zone: HeartRateZone) -> Double {
        let totalTime = timeInZones.values.reduce(0, +)
        guard totalTime > 0 else { return 0 }
        return (timeInZones[zone] ?? 0) / totalTime
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    HealthDashboardView()
}
