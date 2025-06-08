//
//  WorkoutsView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct WorkoutsView: View {
    @StateObject private var viewModel = WorkoutsViewModel()
    @State private var showingWorkoutBuilder = false
    @State private var selectedWorkoutType: WorkoutType?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Featured Workouts
                    featuredWorkoutsSection
                    
                    // Workout Categories
                    workoutCategoriesSection
                    
                    // Training Plans
                    trainingPlansSection
                    
                    // Custom Workouts
                    customWorkoutsSection
                }
                .padding(.horizontal)
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        showingWorkoutBuilder = true
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $showingWorkoutBuilder) {
            WorkoutBuilderView()
        }
        .sheet(item: $selectedWorkoutType) { workoutType in
            WorkoutConfigurationView(workoutType: workoutType)
        }
        .onAppear {
            viewModel.loadWorkouts()
        }
    }
    
    private var featuredWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured Workouts")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.featuredWorkouts) { workout in
                        FeaturedWorkoutCard(workout: workout) {
                            viewModel.startWorkout(workout)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
    
    private var workoutCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Types")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(WorkoutType.allCases, id: \.self) { workoutType in
                    WorkoutTypeCard(workoutType: workoutType) {
                        selectedWorkoutType = workoutType
                    }
                }
            }
        }
    }
    
    private var trainingPlansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training Plans")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink("View All", destination: TrainingPlansView())
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.trainingPlans.prefix(3)) { plan in
                    TrainingPlanCard(plan: plan) {
                        viewModel.startTrainingPlan(plan)
                    }
                }
            }
        }
    }
    
    private var customWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Workouts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Create New") {
                    showingWorkoutBuilder = true
                }
                .font(.subheadline)
                .foregroundColor(.orange)
            }
            
            if viewModel.customWorkouts.isEmpty {
                EmptyCustomWorkoutsView {
                    showingWorkoutBuilder = true
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.customWorkouts) { workout in
                        CustomWorkoutRow(workout: workout) {
                            viewModel.startWorkout(workout)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct FeaturedWorkoutCard: View {
    let workout: WorkoutConfiguration
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: workout.type.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    DifficultyBadge(difficulty: workout.difficulty)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(workout.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                
                HStack {
                    Label(formatDuration(workout.duration), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Label("\(workout.estimatedCalories) cal", systemImage: "flame")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .frame(width: 280, height: 160)
            .background(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}

struct WorkoutTypeCard: View {
    let workoutType: WorkoutType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: workoutType.icon)
                    .font(.title)
                    .foregroundColor(.orange)
                
                VStack(spacing: 4) {
                    Text(workoutType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(workoutType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TrainingPlanCard: View {
    let plan: TrainingPlan
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack {
                    Image(systemName: plan.icon)
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("\(plan.totalWeeks)w")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(plan.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        DifficultyBadge(difficulty: plan.difficulty)
                        
                        Spacer()
                        
                        Text("\(plan.completedWorkouts)/\(plan.totalWorkouts) completed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomWorkoutRow: View {
    let workout: WorkoutConfiguration
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: workout.type.icon)
                    .font(.title3)
                    .foregroundColor(.orange)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(workout.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDuration(workout.duration))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(workout.estimatedCalories) cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}

struct DifficultyBadge: View {
    let difficulty: Difficulty
    
    var body: some View {
        Text(difficulty.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(difficultyColor)
            )
            .foregroundColor(.white)
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .elite: return .red
        }
    }
}

struct EmptyCustomWorkoutsView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 48))
                .foregroundColor(.orange.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Custom Workouts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Create your first custom workout to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Create Workout") {
                action()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Training Plan Model
struct TrainingPlan: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let difficulty: Difficulty
    let totalWeeks: Int
    let totalWorkouts: Int
    let completedWorkouts: Int
    let icon: String
    
    var progress: Double {
        guard totalWorkouts > 0 else { return 0 }
        return Double(completedWorkouts) / Double(totalWorkouts)
    }
}

// MARK: - Preview
struct WorkoutsView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutsView()
    }
}
