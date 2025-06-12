//
//  EnhancedWorkoutDashboardView.swift
//  ShuttlX
//
//  Enhanced workout dashboard with performance optimizations
//  Created by ShuttlX on 6/9/25.
//

import SwiftUI
import HealthKit

struct EnhancedWorkoutDashboardView: View {
    @EnvironmentObject private var serviceLocator: ServiceLocator
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    @State private var showingWorkoutSelection = false
    @State private var selectedProgram: TrainingProgram?
    @State private var showingPerformanceDetails = false
    
    var body: some View {
        OptimizedScrollView {
            VStack(spacing: 20) {
                // Performance indicator (if needed)
                if performanceService.memoryUsage != .normal {
                    PerformanceIndicatorView()
                        .optimizedForLists()
                }
                
                // Today's Summary Card with enhanced performance
                EnhancedTodaySummaryCard()
                    .optimizedForLists()
                
                // Quick Start Section
                quickStartSection
                    .optimizedForLists()
                
                // Training Programs Preview
                trainingProgramsPreview
                    .optimizedForLists()
                
                // Recent Activity with optimized loading
                if !serviceLocator.healthManager.recentWorkouts.isEmpty {
                    recentActivitySection
                        .optimizedForLists()
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationTitle("Workouts")
        .onOptimizedAppear {
            loadDashboardData()
        }
        .sheet(isPresented: $showingWorkoutSelection) {
            WorkoutSelectionView()
        }
        .sheet(item: $selectedProgram) { program in
            TrainingProgramDetailView(program: program)
        }
    }
    
    // MARK: - Quick Start Section
    private var quickStartSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Start")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickStartButton(
                    title: "5K Training",
                    subtitle: "Beginner friendly",
                    icon: "figure.run",
                    color: .blue
                ) {
                    // Start 5K program
                }
                
                QuickStartButton(
                    title: "HIIT Workout",
                    subtitle: "High intensity",
                    icon: "bolt.fill",
                    color: .orange
                ) {
                    // Start HIIT program
                }
                
                QuickStartButton(
                    title: "Custom Run",
                    subtitle: "Your intervals",
                    icon: "slider.horizontal.3",
                    color: .purple
                ) {
                    showingWorkoutSelection = true
                }
                
                QuickStartButton(
                    title: "Recovery",
                    subtitle: "Active rest",
                    icon: "leaf.fill",
                    color: .green
                ) {
                    // Start recovery program
                }
            }
        }
    }
    
    // MARK: - Training Programs Preview
    private var trainingProgramsPreview: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recommended Programs")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                NavigationLink("See All") {
                    ProgramsView()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            // Use optimized loading for featured programs
            let featuredPrograms = performanceService.loadDataWithPagination(
                data: TrainingProgram.defaultPrograms,
                pageSize: 3
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(featuredPrograms) { program in
                        ProgramPreviewCard(program: program) {
                            selectedProgram = program
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {
                    // Navigate to full history
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 8) {
                // Use optimized list for recent workouts
                let recentWorkouts = performanceService.loadDataWithPagination(
                    data: serviceLocator.healthManager.recentWorkouts,
                    pageSize: 5
                )
                
                ForEach(recentWorkouts.prefix(3), id: \.uuid) { workout in
                    EnhancedWorkoutRow(workout: workout)
                        .optimizedForLists()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadDashboardData() {
        // Use debounced loading to prevent excessive calls
        performanceService.debounceViewUpdate(
            for: performanceService,
            delay: 0.2
        ) {
            // Load data here
        }
    }
}

// MARK: - Enhanced Supporting Views

struct EnhancedTodaySummaryCard: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Activity")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            // Main metrics
            HStack(spacing: 20) {
                EnhancedSummaryMetric(
                    title: "Steps",
                    value: "\(Int(serviceLocator.healthManager.todaySteps))",
                    icon: "figure.walk",
                    color: .blue,
                    target: "10,000"
                )
                
                EnhancedSummaryMetric(
                    title: "Calories",
                    value: "\(Int(serviceLocator.healthManager.todayCalories))",
                    icon: "flame.fill",
                    color: .orange,
                    target: "500"
                )
                
                EnhancedSummaryMetric(
                    title: "Heart Rate",
                    value: serviceLocator.healthManager.currentHeartRate > 0 ? 
                        "\(Int(serviceLocator.healthManager.currentHeartRate))" : "--",
                    icon: "heart.fill",
                    color: .red,
                    target: "70"
                )
            }
            
            // Expanded details
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack {
                        Text("Weekly Goal Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("65%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: 0.65)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This Week")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("3 workouts")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("5 days")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                }
                .optimizedAnimation(.easeInOut(duration: 0.3), value: isExpanded)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct EnhancedSummaryMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let target: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("/ \(target)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickStartButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(color.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProgramPreviewCard: View {
    let program: TrainingProgram
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(program.difficulty.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(program.difficulty.color)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(program.totalDuration)) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "flame")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(program.estimatedCalories)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !program.description.isEmpty {
                        Text(program.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding()
            .frame(width: 240)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EnhancedWorkoutRow: View {
    let workout: HKWorkout
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutActivityType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(workout.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(workout.duration))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                    Text("\(Int(calories)) cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - HKWorkoutActivityType Extension
extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .mixedCardio: return "Mixed Cardio"
        default: return "Workout"
        }
    }
}

#Preview {
    EnhancedWorkoutDashboardView()
        .environmentObject(ServiceLocator.shared)
}
