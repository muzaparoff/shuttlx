//
//  WorkoutPreviewView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct WorkoutPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let workout: CustomWorkout
    @State private var showingTimelineView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Workout Stats
                    statsSection
                    
                    // Intervals Timeline
                    timelimeSection
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workout Preview")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start") {
                        startWorkout()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Workout Icon and Title
            VStack(spacing: 12) {
                Image(systemName: workout.type.icon)
                    .font(.system(size: 48))
                    .foregroundColor(workout.difficulty.color)
                
                Text(workout.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    DifficultyBadge(difficulty: workout.difficulty)
                    TypeBadge(type: workout.type)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Summary")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    icon: "clock",
                    title: "Duration",
                    value: formatDuration(workout.estimatedDuration),
                    color: .blue
                )
                
                StatCard(
                    icon: "flame",
                    title: "Est. Calories",
                    value: "\(workout.estimatedCalories)",
                    color: .orange
                )
                
                StatCard(
                    icon: "repeat",
                    title: "Intervals",
                    value: "\(workout.intervals.count)",
                    color: .green
                )
                
                StatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Intensity",
                    value: averageIntensity,
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Timeline Section
    private var timelimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Workout Timeline")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showingTimelineView = true }) {
                    HStack {
                        Text("View Full Timeline")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Compact Timeline View
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(workout.intervals.enumerated()), id: \.offset) { index, interval in
                        TimelineIntervalCard(
                            interval: interval,
                            index: index,
                            totalIntervals: workout.intervals.count
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingTimelineView) {
            WorkoutTimelineView(workout: workout)
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary Action - Start Workout
            Button(action: startWorkout) {
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
            
            // Secondary Actions
            HStack(spacing: 12) {
                // Save Workout
                Button(action: saveWorkout) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Share Workout
                Button(action: shareWorkout) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // Notes Section
            if !workout.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(workout.notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            // Tags
            if !workout.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(workout.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var averageIntensity: String {
        let intensities = workout.intervals.map { interval in
            switch interval.intensity {
            case .low: return 1
            case .moderate: return 2
            case .high: return 3
            case .veryHigh: return 4
            case .maximum: return 5
            }
        }
        
        let average = Double(intensities.reduce(0, +)) / Double(intensities.count)
        
        switch average {
        case 0..<1.5: return "Low"
        case 1.5..<2.5: return "Moderate"
        case 2.5..<3.5: return "High"
        case 3.5..<4.5: return "Very High"
        default: return "Maximum"
        }
    }
    
    // MARK: - Actions
    private func startWorkout() {
        // Navigate to workout view with this workout
        print("Starting workout: \(workout.name)")
        dismiss()
    }
    
    private func saveWorkout() {
        // Save workout to local storage
        print("Saving workout: \(workout.name)")
    }
    
    private func shareWorkout() {
        // Share workout details
        print("Sharing workout: \(workout.name)")
    }
}

// MARK: - Supporting Views

struct DifficultyBadge: View {
    let difficulty: DifficultyLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: difficulty.icon)
            Text(difficulty.rawValue.capitalized)
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(difficulty.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(difficulty.color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct TypeBadge: View {
    let type: WorkoutType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
            Text(type.displayName)
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct TimelineIntervalCard: View {
    let interval: WorkoutInterval
    let index: Int
    let totalIntervals: Int
    
    var body: some View {
        VStack(spacing: 6) {
            // Interval Type Icon
            Image(systemName: interval.type.icon)
                .font(.title3)
                .foregroundColor(interval.intensity.color)
            
            // Duration
            Text(interval.durationText)
                .font(.caption)
                .fontWeight(.bold)
            
            // Type
            Text(interval.type.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 60, height: 80)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(interval.intensity.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(interval.intensity.color, lineWidth: 1)
                )
        )
    }
}

// MARK: - Helper Functions

private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    
    if minutes > 0 {
        return "\(minutes):\(String(format: "%02d", seconds))"
    } else {
        return "\(seconds)s"
    }
}

#Preview {
    WorkoutPreviewView(workout: CustomWorkout(
        name: "Sample HIIT Workout",
        type: .hiit,
        difficulty: .intermediate,
        intervals: [
            WorkoutInterval(type: .warmup, duration: 300, intensity: .low, distance: nil, notes: "Warmup"),
            WorkoutInterval(type: .work, duration: 45, intensity: .veryHigh, distance: nil, notes: "High intensity"),
            WorkoutInterval(type: .rest, duration: 15, intensity: .low, distance: nil, notes: "Rest"),
            WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Cooldown")
        ],
        estimatedDuration: 720,
        estimatedCalories: 150,
        notes: "Sample HIIT workout for testing",
        tags: ["hiit", "cardio", "test"]
    ))
}
