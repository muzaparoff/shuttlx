//
//  WorkoutBuilderView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct WorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WorkoutBuilderViewModel()
    @State private var showingPreview = false
    @State private var showingTemplates = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Workout Basic Info
                    workoutInfoSection
                    
                    // Intervals Section
                    intervalsSection
                    
                    // Template Actions
                    templateActionsSection
                    
                    // Preview and Save
                    actionButtonsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Create Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveWorkout()
                        dismiss()
                    }
                    .disabled(!viewModel.isValidWorkout)
                }
            }
            .sheet(isPresented: $showingPreview) {
                WorkoutPreviewView(workout: viewModel.buildWorkout())
            }
            .sheet(isPresented: $showingTemplates) {
                WorkoutTemplatesView { template in
                    viewModel.loadTemplate(template)
                    showingTemplates = false
                }
            }
        }
    }
    
    // MARK: - Workout Info Section
    private var workoutInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Workout Details", icon: "info.circle")
            
            VStack(spacing: 12) {
                // Workout Name
                CustomTextField(
                    title: "Workout Name",
                    text: $viewModel.workoutName,
                    placeholder: "Enter workout name"
                )
                
                // Workout Type
                Picker("Workout Type", selection: $viewModel.selectedWorkoutType) {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                
                // Difficulty Level
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty Level")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { level in
                            DifficultyButton(
                                level: level,
                                isSelected: viewModel.selectedDifficulty == level
                            ) {
                                viewModel.selectedDifficulty = level
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Intervals Section
    private var intervalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Intervals", icon: "timer")
            
            VStack(spacing: 12) {
                // Add Interval Button
                Button(action: viewModel.addInterval) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Interval")
                        Spacer()
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                // Intervals List
                ForEach(Array(viewModel.intervals.enumerated()), id: \.offset) { index, interval in
                    IntervalRowView(
                        interval: interval,
                        index: index,
                        onEdit: { editedInterval in
                            viewModel.updateInterval(at: index, with: editedInterval)
                        },
                        onDelete: {
                            viewModel.removeInterval(at: index)
                        },
                        onMoveUp: index > 0 ? {
                            viewModel.moveInterval(from: index, to: index - 1)
                        } : nil,
                        onMoveDown: index < viewModel.intervals.count - 1 ? {
                            viewModel.moveInterval(from: index, to: index + 1)
                        } : nil
                    )
                }
                
                // Workout Summary
                if !viewModel.intervals.isEmpty {
                    WorkoutSummaryCard(
                        totalDuration: viewModel.totalDuration,
                        totalIntervals: viewModel.intervals.count,
                        estimatedCalories: viewModel.estimatedCalories
                    )
                }
            }
        }
    }
    
    // MARK: - Template Actions Section
    private var templateActionsSection: some View {
        VStack(spacing: 12) {
            Button(action: { showingTemplates = true }) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Load from Template")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.primary)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            
            Button(action: viewModel.saveAsTemplate) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save as Template")
                    Spacer()
                }
                .foregroundColor(.blue)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .disabled(!viewModel.isValidWorkout)
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Preview Button
            Button(action: { showingPreview = true }) {
                HStack {
                    Image(systemName: "eye")
                    Text("Preview Workout")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(!viewModel.isValidWorkout)
            
            // Quick Start Button
            Button(action: {
                // Navigate to workout view with this workout
                viewModel.startWorkout()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout Now")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            .disabled(!viewModel.isValidWorkout)
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
        }
    }
}

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct DifficultyButton: View {
    let level: DifficultyLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: level.icon)
                    .font(.title2)
                Text(level.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : level.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? level.color : Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct IntervalRowView: View {
    let interval: WorkoutInterval
    let index: Int
    let onEdit: (WorkoutInterval) -> Void
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    
    @State private var showingEdit = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Interval Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(interval.type.displayName)
                        .font(.headline)
                        .foregroundColor(interval.intensity.color)
                    
                    Spacer()
                    
                    Text(interval.durationText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if !interval.notes.isEmpty {
                    Text(interval.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Controls
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    if let onMoveUp = onMoveUp {
                        Button(action: onMoveUp) {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    if let onMoveDown = onMoveDown {
                        Button(action: onMoveDown) {
                            Image(systemName: "arrow.down")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                HStack(spacing: 4) {
                    Button(action: { showingEdit = true }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingEdit) {
            IntervalEditView(interval: interval) { editedInterval in
                onEdit(editedInterval)
                showingEdit = false
            }
        }
    }
}

struct WorkoutSummaryCard: View {
    let totalDuration: TimeInterval
    let totalIntervals: Int
    let estimatedCalories: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                SummaryItem(
                    icon: "clock",
                    value: formatDuration(totalDuration),
                    label: "Duration"
                )
                
                SummaryItem(
                    icon: "repeat",
                    value: "\(totalIntervals)",
                    label: "Intervals"
                )
                
                SummaryItem(
                    icon: "flame",
                    value: "\(estimatedCalories)",
                    label: "Cal (est.)"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SummaryItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Helper Functions

private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

// MARK: - Enums and Data Models

enum WorkoutType: String, CaseIterable {
    case shuttleRun = "shuttle_run"
    case intervals = "intervals"
    case custom = "custom"
    case hiit = "hiit"
    
    var displayName: String {
        switch self {
        case .shuttleRun: return "Shuttle Run"
        case .intervals: return "Intervals"
        case .custom: return "Custom"
        case .hiit: return "HIIT"
        }
    }
}

enum DifficultyLevel: String, CaseIterable {
    case beginner, intermediate, advanced, expert
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .yellow
        case .advanced: return .orange
        case .expert: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "star"
        case .intermediate: return "star.fill"
        case .advanced: return "star.circle"
        case .expert: return "star.circle.fill"
        }
    }
}

struct WorkoutInterval {
    let id = UUID()
    var type: IntervalType
    var duration: TimeInterval
    var intensity: ExerciseIntensity
    var distance: Double? // For distance-based intervals
    var notes: String
    
    var durationText: String {
        if let distance = distance {
            return "\(Int(distance))m"
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            if minutes > 0 {
                return "\(minutes):\(String(format: "%02d", seconds))"
            } else {
                return "\(seconds)s"
            }
        }
    }
}

struct CustomWorkout {
    let id = UUID()
    var name: String
    var type: WorkoutType
    var difficulty: DifficultyLevel
    var intervals: [WorkoutInterval]
    var estimatedDuration: TimeInterval
    var estimatedCalories: Int
    var notes: String
    var tags: [String]
}

#Preview {
    WorkoutBuilderView()
}
