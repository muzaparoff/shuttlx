//
//  TrainingProgramDetailView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import SwiftUI

struct TrainingProgramDetailView: View {
    let program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    @StateObject private var programManager = TrainingProgramManager.shared
    @State private var showingDeleteAlert = false
    @State private var showingWorkoutView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    heroSection
                    
                    // Quick Stats
                    quickStatsSection
                    
                    // Detailed Breakdown
                    detailedBreakdownSection
                    
                    // Workout Preview
                    workoutPreviewSection
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(
                LinearGradient(
                    colors: [program.difficulty.color.opacity(0.1), program.difficulty.color.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle(program.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                if program.isCustom {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Edit Program", systemImage: "pencil") {
                                // TODO: Implement edit functionality
                            }
                            
                            Button("Delete Program", systemImage: "trash", role: .destructive) {
                                showingDeleteAlert = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .alert("Delete Program", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                programManager.deleteCustomProgram(program)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(program.name)'? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $showingWorkoutView) {
            WorkoutExecutionView(program: program)
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
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
                    .frame(width: 100, height: 100)
                
                Image(systemName: program.difficulty.icon)
                    .font(.system(size: 50))
                    .foregroundColor(program.difficulty.color)
            }
            
            // Program Info
            VStack(spacing: 8) {
                HStack {
                    Text(program.difficulty.rawValue.capitalized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(program.difficulty.color.opacity(0.2))
                        .foregroundColor(program.difficulty.color)
                        .cornerRadius(12)
                    
                    Text(program.targetHeartRateZone.rawValue.capitalized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(program.targetHeartRateZone.color.opacity(0.2))
                        .foregroundColor(program.targetHeartRateZone.color)
                        .cornerRadius(12)
                    
                    if program.isCustom {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            Text("Custom")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                    }
                }
                
                if !program.description.isEmpty {
                    Text(program.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        VStack(spacing: 16) {
            Text("Quick Overview")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                QuickStatCard(
                    title: "Distance",
                    value: "\(String(format: "%.1f", program.distance)) km",
                    icon: "figure.run.circle.fill",
                    color: .orange
                )
                
                QuickStatCard(
                    title: "Duration",
                    value: "\(Int(program.totalDuration)) min",
                    icon: "clock.fill",
                    color: .blue
                )
                
                QuickStatCard(
                    title: "Calories",
                    value: "\(program.estimatedCalories)",
                    icon: "flame.fill",
                    color: .red
                )
                
                QuickStatCard(
                    title: "Intensity",
                    value: program.targetHeartRateZone.displayName,
                    icon: "heart.fill",
                    color: program.targetHeartRateZone.color
                )
            }
        }
    }
    
    // MARK: - Detailed Breakdown Section
    private var detailedBreakdownSection: some View {
        VStack(spacing: 16) {
            Text("Interval Structure")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                DetailedIntervalCard(
                    title: "Run Phase",
                    duration: program.runInterval,
                    icon: "hare.fill",
                    color: .red,
                    description: "High intensity running",
                    heartRateZone: "80-90% HRmax"
                )
                
                DetailedIntervalCard(
                    title: "Walk Phase",
                    duration: program.walkInterval,
                    icon: "tortoise.fill",
                    color: .blue,
                    description: "Active recovery walking",
                    heartRateZone: "60-70% HRmax"
                )
            }
            
            // Cycle Information
            DetailedCycleCard(program: program)
        }
    }
    
    // MARK: - Workout Preview Section
    private var workoutPreviewSection: some View {
        VStack(spacing: 16) {
            Text("Workout Timeline")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            WorkoutTimelinePreview(program: program)
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Removed "Start Workout" button - training is now watchOS only
            Text("Training Available on Apple Watch")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            
            // Send to Watch Button
            Button(action: {
                // TODO: Implement Watch sync
            }) {
                HStack {
                    Image(systemName: "applewatch")
                    Text("Send to Apple Watch")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Supporting Views

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
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
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
    }
}

struct DetailedIntervalCard: View {
    let title: String
    let duration: Double
    let icon: String
    let color: Color
    let description: String
    let heartRateZone: String
    
    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.2))
                    .cornerRadius(25)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Target: \(heartRateZone)")
                    .font(.caption)
                    .foregroundColor(color)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
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
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
    }
}

struct DetailedCycleCard: View {
    let program: TrainingProgram
    
    private var totalCycleTime: Double {
        program.runInterval + program.walkInterval
    }
    
    private var estimatedCycles: Int {
        Int(program.totalDuration / totalCycleTime)
    }
    
    private var totalRunTime: Double {
        Double(estimatedCycles) * program.runInterval
    }
    
    private var totalWalkTime: Double {
        Double(estimatedCycles) * program.walkInterval
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .foregroundColor(.orange)
                Text("Cycle Breakdown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Total Cycles")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(estimatedCycles)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Cycle Duration")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", totalCycleTime)) min")
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                HStack {
                    Text("Total Run Time")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", totalRunTime)) min")
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("Total Walk Time")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", totalWalkTime)) min")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
    }
}

struct WorkoutTimelinePreview: View {
    let program: TrainingProgram
    
    private var previewItems: [TimelinePreviewItem] {
        var items: [TimelinePreviewItem] = []
        let cycleTime = program.runInterval + program.walkInterval
        let totalCycles = Int(program.totalDuration / cycleTime)
        let showCycles = min(totalCycles, 4) // Show first 4 cycles
        
        for cycle in 0..<showCycles {
            let startTime = Double(cycle) * cycleTime
            
            items.append(TimelinePreviewItem(
                phase: "Run",
                startTime: startTime,
                duration: program.runInterval,
                type: .run
            ))
            
            items.append(TimelinePreviewItem(
                phase: "Walk",
                startTime: startTime + program.runInterval,
                duration: program.walkInterval,
                type: .walk
            ))
        }
        
        if totalCycles > 4 {
            items.append(TimelinePreviewItem(
                phase: "... +\(totalCycles - 4) more cycles",
                startTime: 0,
                duration: 0,
                type: .continuation
            ))
        }
        
        return items
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(previewItems.indices, id: \.self) { index in
                TimelinePreviewRow(
                    item: previewItems[index],
                    isLast: index == previewItems.count - 1
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
    }
}

struct TimelinePreviewItem {
    let phase: String
    let startTime: Double
    let duration: Double
    let type: TimelinePreviewType
}

enum TimelinePreviewType {
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

struct TimelinePreviewRow: View {
    let item: TimelinePreviewItem
    let isLast: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Circle()
                    .fill(item.type.color)
                    .frame(width: 10, height: 10)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 30)
                }
            }
            
            HStack {
                Image(systemName: item.type.icon)
                    .foregroundColor(item.type.color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.phase)
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

// MARK: - Workout Execution View Placeholder
struct WorkoutExecutionView: View {
    let program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Workout Execution")
                    .font(.title)
                Text("Program: \(program.name)")
                    .font(.headline)
                
                Button("End Workout") {
                    dismiss()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .navigationTitle("Workout")
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

#Preview {
    TrainingProgramDetailView(
        program: TrainingProgram(
            name: "Custom HIIT Program",
            distance: 5.0,
            runInterval: 2.0,
            walkInterval: 1.0,
            difficulty: .intermediate,
            description: "A custom high-intensity interval training program designed for intermediate runners",
            estimatedCalories: 350,
            targetHeartRateZone: .zone4,
            isCustom: true
        )
    )
}
