//
//  ContentView_Simple.swift
//  ShuttlXWatch Watch App
//
//  Simplified version of ContentView for better user experience
//

import SwiftUI
import WatchConnectivity

// MARK: - Simplified ContentView

struct ContentView_Simple: View {
    @State private var programs: [TrainingProgram] = defaultTrainingPrograms
    @State private var customPrograms: [TrainingProgram] = []
    @StateObject private var connectivity = WatchConnectivityManager()
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        NavigationView {
            List {
                // Custom Workouts Section
                if !customPrograms.isEmpty {
                    Section("My Workouts") {
                        ForEach(customPrograms) { program in
                            SimpleWorkoutRow(program: program)
                        }
                    }
                }
                
                // Default Programs Section
                Section("Training Programs") {
                    ForEach(programs) { program in
                        SimpleWorkoutRow(program: program)
                    }
                }
            }
            .navigationTitle("ShuttlX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: requestSync) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .onAppear {
            loadWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TrainingProgramsUpdated"))) { notification in
            if let updatedPrograms = notification.object as? [TrainingProgram] {
                updatePrograms(updatedPrograms)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AllCustomWorkoutsSynced"))) { notification in
            if let customWorkouts = notification.object as? [TrainingProgram] {
                customPrograms = customWorkouts
            }
        }
    }
    
    // MARK: - Simple Workout Row
    private func SimpleWorkoutRow(program: TrainingProgram) -> some View {
        NavigationLink(destination: WorkoutDetailView(program: program)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(program.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if program.isCustom {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                HStack {
                    Text("\(Int(program.totalDuration))min")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(program.difficulty.displayName)
                        .font(.caption)
                        .foregroundColor(program.difficulty.color)
                    
                    Spacer()
                    
                    Text("\(program.estimatedCalories) cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Helper Functions
    private func loadWorkouts() {
        // Load saved custom workouts
        if let data = UserDefaults.standard.data(forKey: "customWorkouts_watch"),
           let saved = try? JSONDecoder().decode([TrainingProgram].self, from: data) {
            customPrograms = saved
        }
        
        // Request sync from iPhone
        requestSync()
    }
    
    private func requestSync() {
        connectivity.requestPrograms()
    }
    
    private func updatePrograms(_ allPrograms: [TrainingProgram]) {
        let defaults = allPrograms.filter { !$0.isCustom }
        let customs = allPrograms.filter { $0.isCustom }
        
        if !defaults.isEmpty {
            programs = defaults
        }
        
        customPrograms = customs
        
        // Save custom workouts
        if let data = try? JSONEncoder().encode(customPrograms) {
            UserDefaults.standard.set(data, forKey: "customWorkouts_watch")
        }
    }
}

// MARK: - Simplified Workout Detail View

struct WorkoutDetailView: View {
    let program: TrainingProgram
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var showingWorkout = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(program.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text(program.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                // Quick Stats
                VStack(spacing: 8) {
                    StatRow(icon: "clock", label: "Duration", value: "\(Int(program.totalDuration)) min")
                    StatRow(icon: "location", label: "Distance", value: String(format: "%.1f km", program.distance))
                    StatRow(icon: "flame", label: "Calories", value: "\(program.estimatedCalories)")
                    StatRow(icon: "heart", label: "Heart Rate", value: program.targetHeartRateZone.displayName)
                }
                
                // Start Button - FIXED: Properly sized for all watch screens
                Button(action: startWorkout) {
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
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingWorkout) {
            SimpleWorkoutView(program: program)
        }
    }
    
    private func startWorkout() {
        workoutManager.startWorkout(from: program)
        showingWorkout = true
    }
    
    // MARK: - Stat Row
    private func StatRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 16)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Simplified Workout View

struct SimpleWorkoutView: View {
    let program: TrainingProgram
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Current Activity
            if let interval = workoutManager.currentInterval {
                VStack(spacing: 8) {
                    Text(interval.type.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(interval.type.color)
                    
                    Text("Interval \(workoutManager.currentIntervalIndex + 1) of \(workoutManager.intervals.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Timer Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(currentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progressValue)
                
                VStack {
                    Text(formattedTime)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick Metrics
            HStack {
                MetricView(value: "\(Int(workoutManager.heartRate))", label: "BPM", color: .red)
                Divider().frame(height: 30)
                MetricView(value: "\(Int(workoutManager.activeCalories))", label: "CAL", color: .orange)
                Divider().frame(height: 30)
                MetricView(value: workoutManager.formattedElapsedTime, label: "TIME", color: .blue)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Controls
            HStack(spacing: 20) {
                Button(action: togglePause) {
                    Image(systemName: workoutManager.isWorkoutPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(workoutManager.isWorkoutPaused ? .green : .orange)
                        .clipShape(Circle())
                }
                
                Button(action: endWorkout) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.red)
                        .clipShape(Circle())
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Computed Properties
    private var progressValue: CGFloat {
        guard let interval = workoutManager.currentInterval, interval.duration > 0 else { return 0 }
        let elapsed = interval.duration - workoutManager.remainingIntervalTime
        return CGFloat(elapsed / interval.duration)
    }
    
    private var currentColor: Color {
        workoutManager.currentInterval?.type.color ?? .gray
    }
    
    private var formattedTime: String {
        let remaining = workoutManager.remainingIntervalTime
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Actions
    private func togglePause() {
        if workoutManager.isWorkoutPaused {
            workoutManager.resumeWorkout()
        } else {
            workoutManager.pauseWorkout()
        }
    }
    
    private func endWorkout() {
        workoutManager.endWorkout()
        dismiss()
    }
    
    // MARK: - Metric View
    private func MetricView(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
