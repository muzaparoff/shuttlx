//
//  ShuttlXWatchApp.swift
//  ShuttlX Watch App
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import HealthKit
import WorkoutKit

@main
struct ShuttlXWatchApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager()
    @StateObject private var connectivityManager = WatchConnectivityManager()
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(workoutManager)
                .environmentObject(connectivityManager)
                .onAppear {
                    workoutManager.requestHealthKitPermissions()
                }
        }
    }
}

struct WatchContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Workout Tab
            WatchWorkoutView()
                .tag(0)
            
            // Progress Tab
            WatchProgressView()
                .tag(1)
            
            // Settings Tab
            WatchSettingsView()
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle())
    }
}

// MARK: - Watch Workout View
struct WatchWorkoutView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var showingWorkoutTypes = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                Text("ShuttlX")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                if workoutManager.isWorkoutActive {
                    // Active Workout View
                    ActiveWorkoutView()
                } else {
                    // Start Workout View
                    StartWorkoutView(showingWorkoutTypes: $showingWorkoutTypes)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingWorkoutTypes) {
            WorkoutTypeSelectionView()
        }
    }
}

// MARK: - Active Workout View
struct ActiveWorkoutView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var showingControls = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Workout Status
            Text(workoutManager.currentWorkoutType?.rawValue ?? "Workout")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Timer
            Text(workoutManager.formattedElapsedTime)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .monospacedDigit()
            
            // Key Metrics
            VStack(spacing: 12) {
                if let heartRate = workoutManager.currentHeartRate {
                    MetricRow(title: "Heart Rate", value: "\(Int(heartRate))", unit: "BPM", color: .red)
                }
                
                if let calories = workoutManager.caloriesBurned {
                    MetricRow(title: "Calories", value: "\(Int(calories))", unit: "CAL", color: .orange)
                }
                
                if let distance = workoutManager.totalDistance {
                    MetricRow(title: "Distance", value: String(format: "%.2f", distance), unit: "KM", color: .blue)
                }
            }
            
            // Control Buttons
            HStack(spacing: 20) {
                Button(action: {
                    if workoutManager.isWorkoutPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                }) {
                    Image(systemName: workoutManager.isWorkoutPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(workoutManager.isWorkoutPaused ? Color.green : Color.orange)
                        .clipShape(Circle())
                }
                
                Button(action: {
                    workoutManager.endWorkout()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
            .padding(.top)
        }
    }
}

// MARK: - Start Workout View
struct StartWorkoutView: View {
    @Binding var showingWorkoutTypes: Bool
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Ready to Train?")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showingWorkoutTypes = true
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.orange)
                .cornerRadius(22)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Quick Start Options
            VStack(spacing: 8) {
                Text("Quick Start")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    QuickStartButton(title: "Shuttle Run", icon: "figure.run", workoutType: .shuttleRun)
                    QuickStartButton(title: "Interval", icon: "timer", workoutType: .intervalTraining)
                }
            }
        }
    }
}

// MARK: - Quick Start Button
struct QuickStartButton: View {
    let title: String
    let icon: String
    let workoutType: WatchWorkoutType
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        Button(action: {
            workoutManager.startWorkout(type: workoutType)
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(.orange)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Workout Type Selection View
struct WorkoutTypeSelectionView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Select Workout")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                ForEach(WatchWorkoutType.allCases, id: \.self) { workoutType in
                    Button(action: {
                        workoutManager.startWorkout(type: workoutType)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: workoutType.icon)
                                .font(.title3)
                                .foregroundColor(workoutType.color)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workoutType.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(workoutType.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

// MARK: - Metric Row
struct MetricRow: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Watch Progress View
struct WatchProgressView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Progress")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Today's Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        ProgressStat(title: "Workouts", value: "2", color: .orange)
                        Spacer()
                        ProgressStat(title: "Calories", value: "245", color: .red)
                        Spacer()
                        ProgressStat(title: "Minutes", value: "45", color: .blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Weekly Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("This Week")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        ProgressStat(title: "Workouts", value: "8", color: .orange)
                        Spacer()
                        ProgressStat(title: "Total Time", value: "4.5h", color: .blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
    }
}

struct ProgressStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Watch Settings View
struct WatchSettingsView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Connection Status
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("iPhone Connection")
                            .font(.headline)
                        Spacer()
                        Circle()
                            .fill(connectivityManager.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(connectivityManager.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Settings Options
                VStack(spacing: 8) {
                    SettingsButton(title: "Notifications", icon: "bell")
                    SettingsButton(title: "Health Permissions", icon: "heart")
                    SettingsButton(title: "About", icon: "info.circle")
                }
            }
            .padding()
        }
    }
}

struct SettingsButton: View {
    let title: String
    let icon: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                    .frame(width: 20)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Watch Workout Types
enum WatchWorkoutType: String, CaseIterable {
    case shuttleRun = "Shuttle Run"
    case intervalTraining = "Interval Training"
    case endurance = "Endurance Run"
    case strength = "Strength Training"
    case flexibility = "Flexibility"
    
    var icon: String {
        switch self {
        case .shuttleRun: return "figure.run"
        case .intervalTraining: return "timer"
        case .endurance: return "heart.fill"
        case .strength: return "dumbbell.fill"
        case .flexibility: return "figure.flexibility"
        }
    }
    
    var color: Color {
        switch self {
        case .shuttleRun: return .orange
        case .intervalTraining: return .blue
        case .endurance: return .red
        case .strength: return .purple
        case .flexibility: return .green
        }
    }
    
    var description: String {
        switch self {
        case .shuttleRun: return "Quick direction changes"
        case .intervalTraining: return "High intensity intervals"
        case .endurance: return "Steady pace running"
        case .strength: return "Resistance training"
        case .flexibility: return "Stretching and mobility"
        }
    }
    
    var healthKitWorkoutType: HKWorkoutActivityType {
        switch self {
        case .shuttleRun, .intervalTraining: return .functionalStrengthTraining
        case .endurance: return .running
        case .strength: return .traditionalStrengthTraining
        case .flexibility: return .flexibility
        }
    }
}
