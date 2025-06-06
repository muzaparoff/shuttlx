//
//  TrainingPlanDetailView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct TrainingPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let plan: TrainingPlan
    let onAction: (PlanAction) -> Void
    
    @State private var selectedWeek: Int = 1
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Plan Header
                    planHeaderSection
                    
                    // Progress Overview
                    progressOverviewSection
                    
                    // Week Selector
                    weekSelectorSection
                    
                    // Weekly Workouts
                    weeklyWorkoutsSection
                    
                    // Plan Stats
                    planStatsSection
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(plan.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Plan") {
                            onAction(.edit)
                        }
                        
                        Button("Delete Plan", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Delete Training Plan", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onAction(.delete)
                }
            } message: {
                Text("Are you sure you want to delete this training plan? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Plan Header Section
    private var planHeaderSection: some View {
        VStack(spacing: 16) {
            // Icon and Basic Info
            VStack(spacing: 12) {
                Image(systemName: plan.type.icon)
                    .font(.system(size: 48))
                    .foregroundColor(plan.difficulty.color)
                
                Text(plan.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(plan.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    DifficultyBadge(difficulty: plan.difficulty)
                    TypeBadge(type: plan.type)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text("\(plan.totalWeeks) weeks")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Progress Overview Section
    private var progressOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Overview")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                // Progress Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Overall Progress")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(plan.completedWeeks)/\(plan.totalWeeks) weeks")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: plan.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                    
                    Text("\(Int(plan.progressPercentage * 100))% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Quick Stats
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ProgressStatCard(
                        icon: "checkmark.circle.fill",
                        title: "Completed",
                        value: "\(getCompletedWorkouts())",
                        color: .green
                    )
                    
                    ProgressStatCard(
                        icon: "clock.fill",
                        title: "Remaining",
                        value: "\(getRemainingWorkouts())",
                        color: .orange
                    )
                    
                    ProgressStatCard(
                        icon: "flame.fill",
                        title: "Total Hours",
                        value: "\(getTotalHours())",
                        color: .red
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Week Selector Section
    private var weekSelectorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Schedule")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(1...plan.totalWeeks, id: \.self) { week in
                        WeekSelectorButton(
                            week: week,
                            isSelected: selectedWeek == week,
                            isCompleted: week <= plan.completedWeeks,
                            isCurrent: week == plan.completedWeeks + 1
                        ) {
                            selectedWeek = week
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Weekly Workouts Section
    private var weeklyWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Week \(selectedWeek) Workouts")
                .font(.title3)
                .fontWeight(.semibold)
            
            let weekWorkouts = getWorkoutsForWeek(selectedWeek)
            
            VStack(spacing: 12) {
                ForEach(Array(weekWorkouts.enumerated()), id: \.offset) { index, workout in
                    WeeklyWorkoutCard(
                        workout: workout,
                        dayNumber: index + 1,
                        isCompleted: workout.isCompleted,
                        isCurrent: !workout.isCompleted && selectedWeek == plan.completedWeeks + 1
                    )
                }
            }
            
            if weekWorkouts.isEmpty {
                Text("No workouts scheduled for this week")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Plan Stats Section
    private var planStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plan Statistics")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    icon: "dumbbell.fill",
                    title: "Total Workouts",
                    value: "\(plan.workouts.count)",
                    color: .blue
                )
                
                StatCard(
                    icon: "clock.fill",
                    title: "Avg Duration",
                    value: "\(getAverageDuration()) min",
                    color: .orange
                )
                
                StatCard(
                    icon: "flame.fill",
                    title: "Est. Calories",
                    value: "\(getTotalCalories())",
                    color: .red
                )
                
                StatCard(
                    icon: "target",
                    title: "Focus Area",
                    value: plan.type.displayName,
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            if !plan.isActive {
                // Start Plan Button
                Button(action: {
                    onAction(.start)
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start This Plan")
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
            } else {
                // Continue Plan Button
                if let nextWorkout = plan.nextWorkout {
                    Button(action: {
                        // Navigate to workout
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            VStack(alignment: .leading) {
                                Text("Continue Plan")
                                    .fontWeight(.semibold)
                                Text("Next: \(nextWorkout.name)")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                } else {
                    // Plan Complete
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Plan Completed!")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getWorkoutsForWeek(_ week: Int) -> [PlannedWorkout] {
        return plan.workouts.filter { $0.week == week }
            .sorted { $0.day < $1.day }
    }
    
    private func getCompletedWorkouts() -> Int {
        return plan.workouts.filter { $0.isCompleted }.count
    }
    
    private func getRemainingWorkouts() -> Int {
        return plan.workouts.filter { !$0.isCompleted }.count
    }
    
    private func getTotalHours() -> Int {
        return plan.workouts.reduce(0) { total, workout in
            total + Int(workout.workout.estimatedDuration / 3600)
        }
    }
    
    private func getAverageDuration() -> Int {
        guard !plan.workouts.isEmpty else { return 0 }
        let totalDuration = plan.workouts.reduce(0) { $0 + $1.workout.estimatedDuration }
        return Int(totalDuration / TimeInterval(plan.workouts.count) / 60)
    }
    
    private func getTotalCalories() -> Int {
        return plan.workouts.reduce(0) { $0 + $1.workout.estimatedCalories }
    }
}

// MARK: - Supporting Views

struct ProgressStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct WeekSelectorButton: View {
    let week: Int
    let isSelected: Bool
    let isCompleted: Bool
    let isCurrent: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("Week")
                    .font(.caption2)
                    .foregroundColor(textColor)
                
                Text("\(week)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(textColor)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if isCurrent {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 60, height: 50)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return .green.opacity(0.1)
        } else if isCurrent {
            return .blue.opacity(0.1)
        } else if isSelected {
            return .blue.opacity(0.2)
        } else {
            return Color(.systemGray6)
        }
    }
    
    private var borderColor: Color {
        if isCompleted {
            return .green
        } else if isCurrent {
            return .blue
        } else if isSelected {
            return .blue
        } else {
            return .clear
        }
    }
    
    private var textColor: Color {
        if isCompleted {
            return .green
        } else if isCurrent {
            return .blue
        } else if isSelected {
            return .blue
        } else {
            return .primary
        }
    }
}

struct WeeklyWorkoutCard: View {
    let workout: PlannedWorkout
    let dayNumber: Int
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Day indicator
            VStack {
                Text("DAY")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(dayNumber)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isCompleted ? .green : isCurrent ? .blue : .primary)
            }
            .frame(width: 40)
            
            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(workout.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(Int(workout.workout.estimatedDuration / 60)) min", systemImage: "clock")
                    Label("\(workout.workout.estimatedCalories) cal", systemImage: "flame")
                    Label(workout.workout.type.displayName, systemImage: workout.workout.type.icon)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            } else if isCurrent {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCompleted ? .green.opacity(0.3) : isCurrent ? .blue.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}

struct TypeBadge: View {
    let type: TrainingPlanType
    
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

#Preview {
    TrainingPlanDetailView(
        plan: TrainingPlan(
            name: "Beginner Shuttle Run Mastery",
            description: "Master the basics of shuttle running with this progressive 6-week plan",
            type: .shuttleRun,
            difficulty: .beginner,
            totalWeeks: 6,
            completedWeeks: 2,
            workouts: [],
            tags: ["beginner", "shuttle"],
            isActive: true,
            createdAt: Date()
        )
    ) { _ in }
}
