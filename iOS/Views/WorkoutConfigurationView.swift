//
//  WorkoutConfigurationView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct WorkoutConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WorkoutConfigurationViewModel()
    let workoutType: WorkoutType
    
    init(workoutType: WorkoutType = .shuttleRun) {
        self.workoutType = workoutType
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Quick Setup Options
                    quickSetupSection
                    
                    // Detailed Configuration
                    if viewModel.showDetailedConfig {
                        detailedConfigSection
                    }
                    
                    // Start Button
                    startButtonSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Configure Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Advanced") {
                        // Navigate to WorkoutBuilderView
                        viewModel.showAdvancedBuilder = true
                    }
                }
            }
            .onAppear {
                viewModel.configure(for: workoutType)
            }
            .sheet(isPresented: $viewModel.showAdvancedBuilder) {
                WorkoutBuilderView()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Workout Type Icon and Title
            VStack(spacing: 12) {
                Image(systemName: workoutType.icon)
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text(workoutType.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(workoutType.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Quick Setup Section
    private var quickSetupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Setup")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                // Duration Selection
                DurationPickerCard(
                    title: "Workout Duration",
                    icon: "clock",
                    selectedDuration: $viewModel.selectedDuration,
                    options: viewModel.durationOptions
                )
                
                // Intensity Selection
                IntensityPickerCard(
                    title: "Intensity Level",
                    icon: "flame",
                    selectedIntensity: $viewModel.selectedIntensity
                )
                
                // Difficulty Selection
                DifficultyPickerCard(
                    title: "Difficulty",
                    icon: "star.circle",
                    selectedDifficulty: $viewModel.selectedDifficulty
                )
            }
        }
    }
    
    // MARK: - Detailed Configuration Section
    private var detailedConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Detailed Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        viewModel.showDetailedConfig.toggle()
                    }
                }) {
                    Image(systemName: "chevron.up")
                        .rotationEffect(.degrees(viewModel.showDetailedConfig ? 0 : 180))
                }
            }
            
            if workoutType == .shuttleRun {
                shuttleRunDetailedConfig
            } else if workoutType == .hiit {
                hiitDetailedConfig
            } else {
                generalDetailedConfig
            }
        }
    }
    
    // MARK: - Shuttle Run Detailed Config
    private var shuttleRunDetailedConfig: some View {
        VStack(spacing: 16) {
            // Distance Selection
            ConfigCard(title: "Shuttle Distance", icon: "ruler") {
                Picker("Distance", selection: $viewModel.shuttleDistance) {
                    ForEach([10, 15, 20, 25, 30], id: \.self) { distance in
                        Text("\(distance)m").tag(distance)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Number of Rounds
            ConfigCard(title: "Number of Rounds", icon: "repeat") {
                Stepper(value: $viewModel.numberOfRounds, in: 3...20) {
                    Text("\(viewModel.numberOfRounds) rounds")
                        .font(.headline)
                }
            }
            
            // Rest Between Rounds
            ConfigCard(title: "Rest Between Rounds", icon: "pause") {
                Picker("Rest", selection: $viewModel.restBetweenRounds) {
                    ForEach([30, 45, 60, 90, 120], id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 80)
            }
        }
    }
    
    // MARK: - HIIT Detailed Config
    private var hiitDetailedConfig: some View {
        VStack(spacing: 16) {
            // Work Duration
            ConfigCard(title: "Work Duration", icon: "timer") {
                Picker("Work", selection: $viewModel.workDuration) {
                    ForEach([20, 30, 45, 60], id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Rest Duration
            ConfigCard(title: "Rest Duration", icon: "pause.circle") {
                Picker("Rest", selection: $viewModel.restDuration) {
                    ForEach([10, 15, 20, 30], id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Number of Cycles
            ConfigCard(title: "Number of Cycles", icon: "repeat") {
                Stepper(value: $viewModel.numberOfCycles, in: 4...16) {
                    Text("\(viewModel.numberOfCycles) cycles")
                        .font(.headline)
                }
            }
        }
    }
    
    // MARK: - General Detailed Config
    private var generalDetailedConfig: some View {
        VStack(spacing: 16) {
            ConfigCard(title: "Warmup Duration", icon: "thermometer.sun") {
                Picker("Warmup", selection: $viewModel.warmupDuration) {
                    ForEach([0, 3, 5, 8, 10], id: \.self) { minutes in
                        Text(minutes == 0 ? "None" : "\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            ConfigCard(title: "Cooldown Duration", icon: "snowflake") {
                Picker("Cooldown", selection: $viewModel.cooldownDuration) {
                    ForEach([0, 3, 5, 8, 10], id: \.self) { minutes in
                        Text(minutes == 0 ? "None" : "\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // MARK: - Start Button Section
    private var startButtonSection: some View {
        VStack(spacing: 16) {
            // Show Advanced Options Toggle
            Button(action: {
                withAnimation {
                    viewModel.showDetailedConfig.toggle()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.showDetailedConfig ? "chevron.up" : "chevron.down")
                    Text(viewModel.showDetailedConfig ? "Hide Advanced Options" : "Show Advanced Options")
                }
                .foregroundColor(.blue)
            }
            
            // Workout Summary
            WorkoutPreviewCard(
                duration: viewModel.estimatedDuration,
                intensity: viewModel.selectedIntensity,
                difficulty: viewModel.selectedDifficulty,
                type: workoutType
            )
            
            // Start Workout Button
            Button(action: {
                viewModel.startWorkout()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Supporting Views

struct DurationPickerCard: View {
    let title: String
    let icon: String
    @Binding var selectedDuration: Int
    let options: [Int]
    
    var body: some View {
        ConfigCard(title: title, icon: icon) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(options, id: \.self) { duration in
                    Button(action: { selectedDuration = duration }) {
                        Text("\(duration) min")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedDuration == duration ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedDuration == duration ? Color.blue : Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct IntensityPickerCard: View {
    let title: String
    let icon: String
    @Binding var selectedIntensity: ExerciseIntensity
    
    var body: some View {
        ConfigCard(title: title, icon: icon) {
            VStack(spacing: 8) {
                ForEach(ExerciseIntensity.allCases, id: \.self) { intensity in
                    Button(action: { selectedIntensity = intensity }) {
                        HStack {
                            Circle()
                                .fill(intensity.color)
                                .frame(width: 16, height: 16)
                            
                            Text(intensity.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if selectedIntensity == intensity {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedIntensity == intensity ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct DifficultyPickerCard: View {
    let title: String
    let icon: String
    @Binding var selectedDifficulty: DifficultyLevel
    
    var body: some View {
        ConfigCard(title: title, icon: icon) {
            HStack(spacing: 12) {
                ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                    Button(action: { selectedDifficulty = difficulty }) {
                        VStack(spacing: 4) {
                            Image(systemName: difficulty.icon)
                                .font(.title2)
                            Text(difficulty.rawValue.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedDifficulty == difficulty ? .white : difficulty.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedDifficulty == difficulty ? difficulty.color : Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct ConfigCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct WorkoutPreviewCard: View {
    let duration: Int
    let intensity: ExerciseIntensity
    let difficulty: DifficultyLevel
    let type: WorkoutType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Preview")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                PreviewItem(
                    icon: "clock",
                    value: "\(duration) min",
                    label: "Duration"
                )
                
                PreviewItem(
                    icon: "flame",
                    value: intensity.displayName,
                    label: "Intensity",
                    color: intensity.color
                )
                
                PreviewItem(
                    icon: difficulty.icon,
                    value: difficulty.rawValue.capitalized,
                    label: "Difficulty",
                    color: difficulty.color
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PreviewItem: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .blue
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Extensions

extension WorkoutType {
    var icon: String {
        switch self {
        case .shuttleRun: return "figure.run"
        case .intervals: return "timer"
        case .custom: return "slider.horizontal.3"
        case .hiit: return "bolt.fill"
        }
    }
    
    var description: String {
        switch self {
        case .shuttleRun:
            return "Build explosive speed and agility with shuttle runs"
        case .intervals:
            return "Structured intervals for endurance and speed"
        case .custom:
            return "Create your own custom workout routine"
        case .hiit:
            return "High-intensity intervals for maximum results"
        }
    }
}

extension ExerciseIntensity {
    static var allCases: [ExerciseIntensity] {
        [.low, .moderate, .high, .veryHigh, .maximum]
    }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        case .maximum: return "Maximum"
        }
    }
}

#Preview {
    WorkoutConfigurationView(workoutType: .shuttleRun)
}
