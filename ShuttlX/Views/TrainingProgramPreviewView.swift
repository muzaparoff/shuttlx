//
//  TrainingProgramPreviewView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import SwiftUI

struct TrainingProgramPreviewView: View {
    let program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Program Overview
                    overviewSection
                    
                    // Interval Breakdown
                    intervalBreakdownSection
                    
                    // Workout Simulation
                    workoutSimulationSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.05), Color.red.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Program Preview")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Program Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [program.difficulty.color.opacity(0.3), program.difficulty.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: program.difficulty.icon)
                    .font(.system(size: 40))
                    .foregroundColor(program.difficulty.color)
            }
            
            // Program Name
            Text(program.name)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Difficulty Badge
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(program.difficulty.color)
                Text(program.difficulty.rawValue.capitalized)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(program.difficulty.color.opacity(0.2))
            .foregroundColor(program.difficulty.color)
            .cornerRadius(20)
            
            // Description
            if !program.description.isEmpty {
                Text(program.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Workout Overview", icon: "info.circle.fill")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    title: "Distance",
                    value: String(format: "%.1f km", program.distance),
                    icon: "figure.run.circle.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Duration",
                    value: "\(Int(program.totalDuration)) min",
                    icon: "clock.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Calories",
                    value: "\(program.estimatedCalories)",
                    icon: "flame.fill",
                    color: .red
                )
                
                StatCard(
                    title: "Heart Rate",
                    value: program.targetHeartRateZone.rawValue.capitalized,
                    icon: "heart.fill",
                    color: program.targetHeartRateZone.color
                )
            }
        }
    }
    
    // MARK: - Interval Breakdown
    private var intervalBreakdownSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Interval Structure", icon: "timer.circle.fill")
            
            VStack(spacing: 12) {
                IntervalCard(
                    title: "Run Phase",
                    duration: program.runInterval,
                    icon: "hare.fill",
                    color: .red,
                    description: "High intensity running"
                )
                
                IntervalCard(
                    title: "Walk Phase",
                    duration: program.walkInterval,
                    icon: "tortoise.fill",
                    color: .blue,
                    description: "Active recovery walking"
                )
            }
            
            // Cycle Information
            CycleInfoCard(program: program)
        }
    }
    
    // MARK: - Workout Simulation
    private var workoutSimulationSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Workout Timeline", icon: "timeline.selection")
            
            WorkoutTimelineView(program: program)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
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
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct IntervalCard: View {
    let title: String
    let duration: Double
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", duration))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text("minutes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct CycleInfoCard: View {
    let program: TrainingProgram
    
    private var totalCycleTime: Double {
        program.runInterval + program.walkInterval
    }
    
    private var estimatedCycles: Int {
        Int(program.totalDuration / totalCycleTime)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .foregroundColor(.orange)
                Text("Cycle Information")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Cycle Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", totalCycleTime)) min")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Estimated Cycles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(estimatedCycles)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct WorkoutTimelineView: View {
    let program: TrainingProgram
    
    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        let cycleTime = program.runInterval + program.walkInterval
        let totalCycles = Int(program.totalDuration / cycleTime)
        
        for cycle in 0..<min(totalCycles, 5) { // Show first 5 cycles
            let startTime = Double(cycle) * cycleTime
            
            // Run phase
            items.append(TimelineItem(
                title: "Run",
                startTime: startTime,
                duration: program.runInterval,
                type: .run
            ))
            
            // Walk phase
            items.append(TimelineItem(
                title: "Walk",
                startTime: startTime + program.runInterval,
                duration: program.walkInterval,
                type: .walk
            ))
        }
        
        if totalCycles > 5 {
            items.append(TimelineItem(
                title: "... +\(totalCycles - 5) more cycles",
                startTime: 5 * cycleTime,
                duration: 0,
                type: .continuation
            ))
        }
        
        return items
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(timelineItems.indices, id: \.self) { index in
                TimelineRow(item: timelineItems[index], isLast: index == timelineItems.count - 1)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TimelineItem {
    let title: String
    let startTime: Double
    let duration: Double
    let type: TimelineItemType
}

enum TimelineItemType {
    case run, walk, continuation
    
    var color: Color {
        switch self {
        case .run: return .red
        case .walk: return .blue
        case .continuation: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .run: return "hare.fill"
        case .walk: return "tortoise.fill"
        case .continuation: return "ellipsis.circle.fill"
        }
    }
}

struct TimelineRow: View {
    let item: TimelineItem
    let isLast: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Circle()
                    .fill(item.type.color)
                    .frame(width: 12, height: 12)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 20)
                }
            }
            
            HStack {
                Image(systemName: item.type.icon)
                    .foregroundColor(item.type.color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if item.type != .continuation {
                        Text("\(String(format: "%.1f", item.startTime)) - \(String(format: "%.1f", item.startTime + item.duration)) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if item.type != .continuation {
                    Text("\(String(format: "%.1f", item.duration)) min")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(item.type.color)
                }
            }
        }
    }
}

#Preview {
    TrainingProgramPreviewView(
        program: TrainingProgram(
            name: "Custom HIIT Program",
            distance: 5.0,
            runInterval: 2.0,
            walkInterval: 1.0,
            totalDuration: 30.0,
            difficulty: .moderate,
            description: "A custom high-intensity interval training program",
            estimatedCalories: 350,
            targetHeartRateZone: .hard,
            isCustom: true
        )
    )
}
