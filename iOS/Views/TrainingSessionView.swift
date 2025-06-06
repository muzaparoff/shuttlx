//
//  TrainingSessionView.swift
//  ShuttlX
//
//  Comprehensive workout execution interface with real-time tracking
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import CoreLocation
import HealthKit
import AVFoundation

struct TrainingSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TrainingSessionViewModel
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var audioCoachingManager = AudioCoachingManager.shared
    @StateObject private var settingsService = SettingsService.shared
    
    @State private var showingPauseMenu = false
    @State private var showingEndWorkoutAlert = false
    @State private var showingHeartRateAlert = false
    
    init(workout: WorkoutConfiguration) {
        _viewModel = StateObject(wrappedValue: TrainingSessionViewModel(workout: workout))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [
                        viewModel.currentIntensityColor.opacity(0.1),
                        viewModel.currentIntensityColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with workout info
                    headerSection
                    
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Current interval display
                            currentIntervalSection
                            
                            // Real-time metrics
                            metricsSection
                            
                            // Heart rate monitoring
                            heartRateSection
                            
                            // Progress timeline
                            progressTimelineSection
                            
                            // Coaching insights
                            coachingSection
                        }
                        .padding()
                    }
                    
                    // Control buttons
                    controlsSection
                        .background(.ultraThinMaterial)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.startWorkout()
            healthManager.startWorkoutSession(for: viewModel.workout.type)
        }
        .onDisappear {
            viewModel.pauseWorkout()
            healthManager.endWorkoutSession()
        }
        .sheet(isPresented: $showingPauseMenu) {
            PauseMenuView(viewModel: viewModel)
        }
        .alert("Heart Rate Alert", isPresented: $showingHeartRateAlert) {
            Button("Continue") { }
            Button("Pause Workout") {
                viewModel.pauseWorkout()
            }
        } message: {
            Text(viewModel.heartRateAlertMessage)
        }
        .alert("End Workout", isPresented: $showingEndWorkoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Workout", role: .destructive) {
                endWorkout()
            }
        } message: {
            Text("Are you sure you want to end this workout? Your progress will be saved.")
        }
        .onChange(of: viewModel.heartRateAlert) { alert in
            if alert != nil {
                showingHeartRateAlert = true
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { showingPauseMenu = true }) {
                    Image(systemName: "pause.circle.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(viewModel.workout.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(viewModel.currentPhase)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingEndWorkoutAlert = true }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
            
            // Workout progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(viewModel.currentIntensityColor)
                        .frame(width: geometry.size.width * viewModel.overallProgress, height: 4)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Current Interval Section
    private var currentIntervalSection: some View {
        VStack(spacing: 16) {
            // Interval type and number
            HStack {
                Text("\(viewModel.currentIntervalIndex + 1) of \(viewModel.workout.intervals.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(viewModel.currentInterval?.type.displayName ?? "")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.currentIntensityColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(viewModel.currentIntensityColor.opacity(0.1))
                    )
            }
            
            // Main timer display
            VStack(spacing: 8) {
                Text(viewModel.formattedCurrentIntervalTime)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.currentIntensityColor)
                    .monospacedDigit()
                
                if let nextInterval = viewModel.nextInterval {
                    HStack {
                        Text("Next:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(nextInterval.type.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("(\(viewModel.formatDuration(nextInterval.duration)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Current interval progress
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Circle()
                        .stroke(
                            viewModel.currentIntensityColor.opacity(0.2),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                    
                    Circle()
                        .trim(from: 0, to: viewModel.currentIntervalProgress)
                        .stroke(
                            viewModel.currentIntensityColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: viewModel.currentIntervalProgress)
                }
            }
            .frame(height: 120)
            
            // Instructions
            if let instructions = viewModel.currentInterval?.instructions, !instructions.isEmpty {
                Text(instructions)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Metrics Section
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-time Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(
                    title: "Total Time",
                    value: viewModel.formattedTotalTime,
                    icon: "clock.fill",
                    color: .blue
                )
                
                MetricCard(
                    title: "Calories",
                    value: "\(viewModel.caloriesBurned)",
                    icon: "flame.fill",
                    color: .orange
                )
                
                if let distance = viewModel.distanceCovered {
                    MetricCard(
                        title: "Distance",
                        value: String(format: "%.1f%@", distance, settingsService.settings.user.units.distanceUnit),
                        icon: "location.fill",
                        color: .green
                    )
                }
                
                if let pace = viewModel.averagePace {
                    MetricCard(
                        title: "Avg Pace",
                        value: viewModel.formatPace(pace),
                        icon: "speedometer",
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Heart Rate Section
    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Heart Rate")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let zone = viewModel.currentHeartRateZone {
                    Text(zone.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(zone.color)
                        )
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(viewModel.currentHeartRate)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(viewModel.averageHeartRate)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Text("BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(viewModel.maxHeartRate)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Heart rate graph
            HeartRateGraphView(heartRateData: viewModel.heartRateData)
                .frame(height: 80)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Progress Timeline Section
    private var progressTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Timeline")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.workout.intervals.enumerated()), id: \.offset) { index, interval in
                        IntervalTimelineCard(
                            interval: interval,
                            isActive: index == viewModel.currentIntervalIndex,
                            isCompleted: index < viewModel.currentIntervalIndex,
                            progress: index == viewModel.currentIntervalIndex ? viewModel.currentIntervalProgress : 0
                        )
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Coaching Section
    private var coachingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Coach")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let tip = viewModel.currentCoachingTip {
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tip.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(tip.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(.blue.opacity(0.1))
                .cornerRadius(12)
            } else {
                Text("Keep going! You're doing great!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(.quaternary)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        HStack(spacing: 20) {
            // Previous interval (if available)
            if viewModel.canGoToPreviousInterval {
                Button(action: viewModel.goToPreviousInterval) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .frame(width: 60, height: 60)
                .background(.quaternary)
                .cornerRadius(30)
            }
            
            Spacer()
            
            // Play/Pause button
            Button(action: {
                if viewModel.isWorkoutActive {
                    viewModel.pauseWorkout()
                } else {
                    viewModel.resumeWorkout()
                }
            }) {
                Image(systemName: viewModel.isWorkoutActive ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .frame(width: 80, height: 80)
            .background(viewModel.currentIntensityColor)
            .cornerRadius(40)
            
            Spacer()
            
            // Next interval (if available)
            if viewModel.canGoToNextInterval {
                Button(action: viewModel.goToNextInterval) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .frame(width: 60, height: 60)
                .background(.quaternary)
                .cornerRadius(30)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
    
    // MARK: - Actions
    private func endWorkout() {
        viewModel.endWorkout()
        healthManager.endWorkoutSession()
        dismiss()
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
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
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.quaternary)
        .cornerRadius(12)
    }
}

struct IntervalTimelineCard: View {
    let interval: WorkoutInterval
    let isActive: Bool
    let isCompleted: Bool
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            // Interval type indicator
            Circle()
                .fill(intervalColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .opacity(isActive ? 1 : 0)
                )
            
            // Duration
            Text(formatDuration(interval.duration))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isActive ? .primary : .secondary)
            
            // Type
            Text(interval.type.rawValue.capitalized)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 60)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? intervalColor.opacity(0.1) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(intervalColor, lineWidth: isActive ? 2 : 0)
        )
    }
    
    private var intervalColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return interval.intensity.color
        } else {
            return .secondary
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        } else {
            return "\(seconds)s"
        }
    }
}

struct HeartRateGraphView: View {
    let heartRateData: [HeartRateDataPoint]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !heartRateData.isEmpty else { return }
                
                let maxHR = heartRateData.map(\.value).max() ?? 200
                let minHR = heartRateData.map(\.value).min() ?? 60
                let range = maxHR - minHR
                
                let stepX = geometry.size.width / CGFloat(max(heartRateData.count - 1, 1))
                
                for (index, dataPoint) in heartRateData.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height - (CGFloat(dataPoint.value - minHR) / CGFloat(range)) * geometry.size.height
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(.red, lineWidth: 2)
        }
    }
}

struct PauseMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TrainingSessionViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.orange)
                    
                    Text("Workout Paused")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Take a breather and resume when ready")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    Button("Resume Workout") {
                        viewModel.resumeWorkout()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("End Workout") {
                        viewModel.endWorkout()
                        dismiss()
                    }
                    .foregroundColor(.red)
                    
                    Button("Settings") {
                        // Navigate to workout settings
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Paused")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension WorkoutInterval.IntervalType {
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .rest: return "Rest"
        case .warmup: return "Warm Up"
        case .cooldown: return "Cool Down"
        }
    }
}

extension Intensity {
    var color: Color {
        switch self {
        case .veryLight: return .gray
        case .light: return .green
        case .moderate: return .blue
        case .vigorous: return .orange
        case .maximal: return .red
        }
    }
}

#Preview {
    TrainingSessionView(workout: WorkoutConfiguration(
        type: .shuttleRun,
        name: "Sample Workout",
        description: "Sample description",
        duration: 1800,
        intervals: [
            WorkoutInterval(
                type: .warmup,
                duration: 300,
                intensity: .light,
                distance: nil,
                targetPace: nil,
                instructions: "Light warm-up"
            )
        ],
        restPeriods: [],
        difficulty: .intermediate,
        targetHeartRateZone: .zone3,
        audioCoaching: AudioCoachingSettings(
            enabled: true,
            voiceType: .female,
            encouragementLevel: .moderate,
            techniqueTips: true,
            intervalAnnouncements: true,
            heartRateAnnouncements: false,
            paceGuidance: true
        ),
        hapticFeedback: HapticFeedbackSettings(
            enabled: true,
            intervalTransitions: true,
            heartRateAlerts: true,
            paceAlerts: true,
            motivationalTaps: false,
            intensity: .medium
        )
    ))
}
