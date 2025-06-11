//
//  WorkoutDashboardView.swift
//  ShuttlX MVP
//
//  Created by ShuttlX on 6/8/25.
//

import SwiftUI
import HealthKit

struct WorkoutDashboardView: View {
    @EnvironmentObject private var serviceLocator: ServiceLocator
    @State private var showingWorkoutSelection = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Today's Summary Card
            TodaySummaryCard()
            
            // Training Note
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "applewatch")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Training Available on Apple Watch")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text("Use your Apple Watch to start and control workouts with real-time metrics")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Recent Activity
            if !serviceLocator.healthManager.recentWorkouts.isEmpty {
                recentActivitySection
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingWorkoutSelection) {
            WorkoutSelectionView()
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(serviceLocator.healthManager.recentWorkouts.prefix(3), id: \.uuid) { workout in
                    RecentWorkoutRow(workout: workout)
                }
            }
        }
    }
}

struct TodaySummaryCard: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Today's Activity")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                SummaryMetric(
                    title: "Steps",
                    value: "\(Int(serviceLocator.healthManager.todaySteps))",
                    icon: "figure.walk",
                    color: .blue
                )
                
                SummaryMetric(
                    title: "Heart Rate",
                    value: "\(Int(serviceLocator.healthManager.currentHeartRate))",
                    icon: "heart.fill",
                    color: .red
                )
                
                SummaryMetric(
                    title: "Calories",
                    value: "\(Int(serviceLocator.healthManager.todayCalories))",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SummaryMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecentWorkoutRow: View {
    let workout: HKWorkout
    
    var body: some View {
        HStack {
            Image(systemName: workoutIcon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(workoutDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let distance = workout.totalDistance {
                Text(distanceString(distance))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var workoutIcon: String {
        switch workout.workoutActivityType {
        case .running:
            return "figure.run"
        case .walking:
            return "figure.walk"
        case .cycling:
            return "bicycle"
        case .hiking:
            return "figure.hiking"
        default:
            return "dumbbell.fill"
        }
    }
    
    private var workoutName: String {
        switch workout.workoutActivityType {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .hiking:
            return "Hiking"
        default:
            return "Workout"
        }
    }
    
    private var workoutDuration: String {
        let duration = workout.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func distanceString(_ distance: HKQuantity) -> String {
        let meters = distance.doubleValue(for: .meter())
        let kilometers = meters / 1000
        
        if kilometers >= 1 {
            return String(format: "%.1f km", kilometers)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
}
