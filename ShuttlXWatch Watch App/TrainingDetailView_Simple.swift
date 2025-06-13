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

// MARK: - Apple Fitness-Style Workout View (Tabbed Design)

struct WorkoutView_Simple: View {
    let program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Main Timer View (Clean Apple Fitness Style)
            TimerView()
                .tag(0)
            
            // Tab 2: Controls & Metrics
            ControlsView()
                .tag(1)
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .automatic))
        .navigationBarHidden(true)
        .onAppear {
            print("📱 [DEBUG] Apple Fitness-style WorkoutView appeared, workout active: \(workoutManager.isWorkoutActive)")
        }
    }
    
    // MARK: - Tab 1: Clean Timer View (Apple Fitness Style)
    
    @ViewBuilder
    private func TimerView() -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Activity Status with Color Indicator
            VStack(spacing: 8) {
                Circle()
                    .fill(activityColor)
                    .frame(width: 12, height: 12)
                
                Text(activityText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // Main Timer Display - Large and Prominent
            Text(workoutManager.formattedRemainingTime)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(activityColor)
                .monospacedDigit()
                .minimumScaleFactor(0.8)
                .onReceive(workoutManager.objectWillChange) { _ in
                    print("🔄 [TIMER-UI] Timer UI updated: \(workoutManager.formattedRemainingTime)")
                    print("   - remainingIntervalTime: \(workoutManager.remainingIntervalTime)")
                    print("   - isWorkoutActive: \(workoutManager.isWorkoutActive)")
                    print("   - currentInterval: \(workoutManager.currentInterval?.name ?? "nil")")
                }
            
            // Interval Progress
            Text("Interval \(workoutManager.currentIntervalIndex + 1) of \(workoutManager.intervals.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Simple swipe indicator
            Text("← Swipe for controls")
                .font(.caption2)
                .foregroundColor(.secondary)
                .opacity(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    // MARK: - Tab 2: Controls & Metrics
    
    @ViewBuilder
    private func ControlsView() -> some View {
        VStack(spacing: 16) {
            // Compact Metrics (2x2 Grid)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                QuickMetric(value: "\(Int(workoutManager.heartRate))", label: "HR", unit: "BPM", color: .red)
                QuickMetric(value: "\(Int(workoutManager.activeCalories))", label: "CAL", unit: "", color: .orange)
                QuickMetric(value: workoutManager.formattedElapsedTime, label: "TIME", unit: "", color: .blue)
                
                // Dynamic pace/speed metric
                if workoutManager.distance > 0 && workoutManager.elapsedTime > 0 {
                    let pace = workoutManager.elapsedTime / 60 / workoutManager.distance
                    QuickMetric(value: String(format: "%.1f", pace), label: "PACE", unit: "min/km", color: .green)
                } else {
                    QuickMetric(value: "0.0", label: "PACE", unit: "min/km", color: .green)
                }
            }
            
            Spacer()
            
            // Control Buttons - Vertical Stack for Better Watch UX
            VStack(spacing: 12) {
                // Pause/Resume Button - Primary Action
                Button(action: {
                    if workoutManager.isWorkoutPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                }) {
                    HStack {
                        Image(systemName: workoutManager.isWorkoutPaused ? "play.fill" : "pause.fill")
                            .font(.title3)
                        Text(workoutManager.isWorkoutPaused ? "Resume" : "Pause")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(workoutManager.isWorkoutPaused ? .green : .orange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Secondary Actions Row
                HStack(spacing: 12) {
                    // Skip Interval
                    Button(action: {
                        workoutManager.skipToNextInterval()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // End Workout
                    Button(action: {
                        workoutManager.endWorkout()
                        dismiss()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Simple swipe indicator
            Text("Swipe for timer →")
                .font(.caption2)
                .foregroundColor(.secondary)
                .opacity(0.6)
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var activityText: String {
        guard let currentInterval = workoutManager.currentInterval else {
            return "Ready"
        }
        
        switch currentInterval.type {
        case .warmup:
            return "Warm Up"
        case .work:
            return "🏃‍♂️ Run"
        case .rest:
            return "🚶‍♂️ Walk"
        case .cooldown:
            return "Cool Down"
        }
    }
    
    private var activityColor: Color {
        guard let currentInterval = workoutManager.currentInterval else {
            return .gray
        }
        
        switch currentInterval.type {
        case .warmup:
            return .yellow
        case .work:
            return .red
        case .rest:
            return .blue
        case .cooldown:
            return .green
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
