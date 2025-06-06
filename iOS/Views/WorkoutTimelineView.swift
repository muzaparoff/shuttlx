//
//  WorkoutTimelineView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct WorkoutTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    let workout: CustomWorkout
    @State private var selectedInterval: WorkoutInterval?
    @State private var showingIntervalDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Workout Header
                    headerSection
                    
                    // Timeline Visualization
                    timelineVisualization
                    
                    // Intervals List
                    intervalsListSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workout Timeline")
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
        .sheet(item: $selectedInterval) { interval in
            IntervalDetailView(interval: interval)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 12) {
                        Label(formatDuration(workout.estimatedDuration), systemImage: "clock")
                        Label("\(workout.estimatedCalories) cal", systemImage: "flame")
                        Label("\(workout.intervals.count) intervals", systemImage: "repeat")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    DifficultyBadge(difficulty: workout.difficulty)
                    TypeBadge(type: workout.type)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Timeline Visualization
    private var timelineVisualization: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visual Timeline")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(workout.intervals.enumerated()), id: \.offset) { index, interval in
                        TimelineSegment(
                            interval: interval,
                            index: index,
                            totalDuration: workout.estimatedDuration,
                            onTap: {
                                selectedInterval = interval
                                showingIntervalDetail = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Timeline Legend
            timelineLegend
        }
    }
    
    // MARK: - Timeline Legend
    private var timelineLegend: some View {
        VStack(spacing: 8) {
            Text("Legend")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(IntervalType.allCases, id: \.self) { type in
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(type.color)
                            .frame(width: 12, height: 12)
                            .cornerRadius(2)
                        
                        Text(type.displayName)
                            .font(.caption2)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Intervals List Section
    private var intervalsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interval Breakdown")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(workout.intervals.enumerated()), id: \.offset) { index, interval in
                    IntervalDetailCard(
                        interval: interval,
                        index: index,
                        cumulativeTime: getCumulativeTime(upTo: index)
                    ) {
                        selectedInterval = interval
                        showingIntervalDetail = true
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getCumulativeTime(upTo index: Int) -> TimeInterval {
        return workout.intervals.prefix(index).reduce(0) { $0 + $1.duration }
    }
    
    private func startWorkout() {
        // Navigate to workout view with this workout
        dismiss()
    }
}

// MARK: - Supporting Views

struct TimelineSegment: View {
    let interval: WorkoutInterval
    let index: Int
    let totalDuration: TimeInterval
    let onTap: () -> Void
    
    private var segmentWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 32 // Account for padding
        let proportion = interval.duration / totalDuration
        return max(8, screenWidth * proportion) // Minimum width of 8 points
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Rectangle()
                    .fill(interval.type.color)
                    .frame(width: segmentWidth, height: 24)
                    .cornerRadius(4)
                    .overlay(
                        Rectangle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                            .cornerRadius(4)
                    )
                
                if segmentWidth > 30 { // Only show text if segment is wide enough
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct IntervalDetailCard: View {
    let interval: WorkoutInterval
    let index: Int
    let cumulativeTime: TimeInterval
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Interval Number and Icon
                VStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Image(systemName: interval.type.icon)
                        .font(.title3)
                        .foregroundColor(interval.intensity.color)
                }
                .frame(width: 40)
                
                // Interval Details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(interval.type.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(interval.durationText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        IntensityIndicator(intensity: interval.intensity)
                        
                        Spacer()
                        
                        Text("At \(formatDuration(cumulativeTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !interval.notes.isEmpty {
                        Text(interval.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct IntensityIndicator: View {
    let intensity: ExerciseIntensity
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(intensity.color)
                .frame(width: 8, height: 8)
            
            Text(intensity.displayName)
                .font(.caption)
                .foregroundColor(intensity.color)
        }
    }
}

struct IntervalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let interval: WorkoutInterval
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: interval.type.icon)
                        .font(.system(size: 48))
                        .foregroundColor(interval.intensity.color)
                    
                    Text(interval.type.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(interval.durationText)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Details
                VStack(spacing: 16) {
                    DetailRow(
                        icon: "clock",
                        title: "Duration",
                        value: interval.durationText
                    )
                    
                    DetailRow(
                        icon: "flame",
                        title: "Intensity",
                        value: interval.intensity.displayName,
                        valueColor: interval.intensity.color
                    )
                    
                    if let distance = interval.distance {
                        DetailRow(
                            icon: "ruler",
                            title: "Distance",
                            value: "\(Int(distance))m"
                        )
                    }
                    
                    if !interval.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(.blue)
                                Text("Notes")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            Text(interval.notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Interval Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Extensions

extension IntervalType {
    var color: Color {
        switch self {
        case .warmup: return .green
        case .work: return .red
        case .rest: return .blue
        case .cooldown: return .purple
        }
    }
}

extension WorkoutInterval: Identifiable {}

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
    WorkoutTimelineView(workout: CustomWorkout(
        name: "Sample HIIT Workout",
        type: .hiit,
        difficulty: .intermediate,
        intervals: [
            WorkoutInterval(type: .warmup, duration: 300, intensity: .low, distance: nil, notes: "Light warmup"),
            WorkoutInterval(type: .work, duration: 45, intensity: .veryHigh, distance: nil, notes: "High intensity work"),
            WorkoutInterval(type: .rest, duration: 15, intensity: .low, distance: nil, notes: "Active rest"),
            WorkoutInterval(type: .work, duration: 45, intensity: .veryHigh, distance: nil, notes: "High intensity work"),
            WorkoutInterval(type: .rest, duration: 15, intensity: .low, distance: nil, notes: "Active rest"),
            WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Cool down")
        ],
        estimatedDuration: 720,
        estimatedCalories: 150,
        notes: "Sample workout",
        tags: ["hiit"]
    ))
}
