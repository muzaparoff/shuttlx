//
//  StatsView.swift
//  ShuttlX MVP
//
//  Created by ShuttlX on 6/8/25.
//

import SwiftUI
import HealthKit

struct StatsView: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    @State private var selectedTimeframe: TimeFrame = .week
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Timeframe Picker
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        Text("Week").tag(TimeFrame.week)
                        Text("Month").tag(TimeFrame.month)
                        Text("Year").tag(TimeFrame.year)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Health Stats Cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        HealthStatCard(
                            title: "Heart Rate",
                            value: serviceLocator.healthManager.currentHeartRate > 0 ? "\(Int(serviceLocator.healthManager.currentHeartRate))" : "--",
                            unit: "BPM",
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        HealthStatCard(
                            title: "Active Energy",
                            value: "\(Int(serviceLocator.healthManager.todayCalories))",
                            unit: "CAL",
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        HealthStatCard(
                            title: "Distance",
                            value: String(format: "%.1f", serviceLocator.healthManager.todayDistance / 1000),
                            unit: "KM",
                            icon: "location.fill",
                            color: .green
                        )
                        
                        HealthStatCard(
                            title: "Workouts",
                            value: "0", // Simplified for MVP
                            unit: "TOTAL",
                            icon: "figure.run",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    // Heart Rate Zones
                    HeartRateZonesCard()
                        .padding(.horizontal)
                    
                    // Recent Workouts
                    RecentWorkoutsCard()
                        .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Statistics")
        }
    }
}

// MARK: - Health Stat Card
struct HealthStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Heart Rate Zones Card
struct HeartRateZonesCard: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Heart Rate Zones")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(Array(HeartRateZone.allCases.enumerated()), id: \.offset) { index, zone in
                    HStack {
                        Circle()
                            .fill(Color(zone.color))
                            .frame(width: 12, height: 12)
                        
                        Text(zone.displayName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("0:00") // TODO: Get actual time in zone
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Recent Workouts Card
struct RecentWorkoutsCard: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Workouts")
                .font(.headline)
                .fontWeight(.semibold)
            
            if true { // Simplified for MVP - no workout history in SimpleHealthManager
                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start your first workout to see it here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    // Simplified for MVP - no workout history available
                    Text("No recent workouts")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Workout Row View
struct WorkoutRowView: View {
    let workout: TrainingSession
    
    var body: some View {
        HStack {
            Image(systemName: "figure.run")
                .foregroundColor(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(workout.startTime, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(workout.duration))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(Int(workout.calories)) cal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Types
enum TimeFrame: CaseIterable {
    case week, month, year
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

// MARK: - Preview
struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}
