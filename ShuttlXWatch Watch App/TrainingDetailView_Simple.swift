//
//  TrainingDetailView_Simple.swift
//  ShuttlXWatch Watch App
//
//  Created by ShuttlX on 6/13/25.
//

import SwiftUI

// MARK: - Simplified Training Detail View - Fits on Watch Screen

struct TrainingDetailView_Simple: View {
    let program: TrainingProgram
    @State private var isWorkoutActive = false
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Spacer()
            
            // Program Name Only - Minimal Display
            Text(program.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
            
            // Centered Start Training Button - Optimized for all watch screens
            Button(action: {
                print("🚀 [START-WORKOUT-BUTTON] User pressed Start Training button")
                print("🚀 [START-WORKOUT-BUTTON] Program: \(program.name)")
                print("🚀 [START-WORKOUT-BUTTON] Current workoutManager.isWorkoutActive: \(workoutManager.isWorkoutActive)")
                
                // Start the workout through the manager
                workoutManager.startWorkout(from: program)
                
                // Set local state after workout manager is called
                isWorkoutActive = true
                
                print("🚀 [START-WORKOUT-BUTTON] After calling startWorkout:")
                print("   - workoutManager.isWorkoutActive: \(workoutManager.isWorkoutActive)")
                print("   - isWorkoutActive: \(isWorkoutActive)")
                print("   - workoutManager.remainingIntervalTime: \(workoutManager.remainingIntervalTime)")
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Start Training")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44) // Fixed height for consistent watch screen fitting
                .background(Color.orange)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding()
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isWorkoutActive) {
            WorkoutView_Simple(program: program)
        }
    }
}

// MARK: - Apple Fitness-Style Workout View (Enhanced Design)

struct WorkoutView_Simple: View {
    let program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Beautiful Timer View (Each data on separate line)
            EnhancedTimerView()
                .tag(0)
            
            // Tab 2: Controls Only (Clean Apple Fitness Style)
            ControlsOnlyView()
                .tag(1)
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .never))
        .navigationBarHidden(true)
        .onAppear {
            print("📱 [WORKOUT-VIEW] Enhanced WorkoutView appeared")
            print("   - Workout active: \(workoutManager.isWorkoutActive)")
            print("   - Remaining time: \(workoutManager.remainingIntervalTime)")
            print("   - Current interval: \(workoutManager.currentInterval?.name ?? "nil")")
        }
    }
    
    // MARK: - Tab 1: Enhanced Timer View (Beautiful Layout)
    
    @ViewBuilder
    private func EnhancedTimerView() -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Current Activity & Main Timer
                VStack(spacing: 12) {
                    // Activity Status with large color indicator
                    HStack {
                        Circle()
                            .fill(activityColor)
                            .frame(width: 16, height: 16)
                        
                        Text(activityText)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(activityColor)
                    }
                    
                    // Main Countdown Timer - Large and Beautiful
                    Text(workoutManager.formattedRemainingTime)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(activityColor)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .onReceive(workoutManager.objectWillChange) { _ in
                            print("🔄 [TIMER-UI] Timer updated: \(workoutManager.formattedRemainingTime)")
                        }
                }
                .padding(.top, 8)
                
                Divider()
                    .opacity(0.3)
                
                // Each data on separate line - Beautiful design
                VStack(spacing: 14) {
                    
                    // Overall Workout Timer
                    DataRow(
                        icon: "stopwatch",
                        label: "Total Time",
                        value: workoutManager.formattedElapsedTime,
                        color: .blue
                    )
                    
                    // Average Pace per Kilometer
                    DataRow(
                        icon: "speedometer",
                        label: "Avg Pace",
                        value: workoutManager.formattedPace,
                        color: .green
                    )
                    
                    // Active Calories
                    DataRow(
                        icon: "flame.fill",
                        label: "Active Calories",
                        value: "\(Int(workoutManager.activeCalories))",
                        color: .orange
                    )
                    
                    // Heart Rate
                    DataRow(
                        icon: "heart.fill",
                        label: "Heart Rate",
                        value: "\(Int(workoutManager.heartRate)) BPM",
                        color: .red
                    )
                    
                    // Interval Progress
                    DataRow(
                        icon: "list.number",
                        label: "Interval",
                        value: "\(workoutManager.currentIntervalIndex + 1) of \(workoutManager.intervals.count)",
                        color: .purple
                    )
                }
                .padding(.horizontal, 4)
                
                Spacer()
                
                // Swipe hint
                Text("← Swipe for controls")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(0.7)
                    .padding(.bottom, 8)
            }
            .padding()
        }
        .background(Color.black)
    }
    
    // MARK: - Tab 2: Controls Only (Apple Fitness Style)
    
    @ViewBuilder
    private func ControlsOnlyView() -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Primary Control - Pause/Resume
            Button(action: {
                if workoutManager.isWorkoutPaused {
                    workoutManager.resumeWorkout()
                } else {
                    workoutManager.pauseWorkout()
                }
            }) {
                VStack(spacing: 8) {
                    Image(systemName: workoutManager.isWorkoutPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 32, weight: .bold))
                    Text(workoutManager.isWorkoutPaused ? "Resume" : "Pause")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(width: 100, height: 100)
                .background(workoutManager.isWorkoutPaused ? .green : .orange)
                .foregroundColor(.white)
                .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Secondary Controls Row
            HStack(spacing: 20) {
                // Skip Interval
                Button(action: {
                    workoutManager.skipToNextInterval()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                        Text("Skip")
                            .font(.caption)
                    }
                    .frame(width: 60, height: 60)
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                // End Workout
                Button(action: {
                    workoutManager.endWorkout()
                    dismiss()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                        Text("End")
                            .font(.caption)
                    }
                    .frame(width: 60, height: 60)
                    .background(.red)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            // Swipe hint
            Text("Swipe for timer →")
                .font(.caption2)
                .foregroundColor(.secondary)
                .opacity(0.7)
        }
        .padding()
        .background(Color.black)
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func DataRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            // Label
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Value
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var activityText: String {
        guard let currentInterval = workoutManager.currentInterval else {
            return "Ready"
        }
        
        switch currentInterval.type {
        case .run:
            return "🏃‍♂️ Run"
        case .walk:
            return "🚶‍♂️ Walk"
        }
    }
    
    private var activityColor: Color {
        guard let currentInterval = workoutManager.currentInterval else {
            return .gray
        }
        
        switch currentInterval.type {
        case .run:
            return .red
        case .walk:
            return .blue
        }
    }
}

// MARK: - Quick Metric View

struct QuickMetric: View {
    let value: String
    let label: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
