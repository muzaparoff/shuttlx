//
//  TrainingPlansView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct TrainingPlansView: View {
    @StateObject private var viewModel = TrainingPlansViewModel()
    @State private var showingCreatePlan = false
    @State private var selectedPlan: TrainingPlan?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with stats
                    headerStatsSection
                    
                    // Active Plan Card
                    if let activePlan = viewModel.activePlan {
                        activePlanSection(activePlan)
                    }
                    
                    // Recommended Plans
                    recommendedPlansSection
                    
                    // All Training Plans
                    allPlansSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Training Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create Plan") {
                        showingCreatePlan = true
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .onAppear {
                viewModel.loadTrainingPlans()
            }
            .sheet(isPresented: $showingCreatePlan) {
                CreateTrainingPlanView { plan in
                    viewModel.addTrainingPlan(plan)
                }
            }
            .sheet(item: $selectedPlan) { plan in
                TrainingPlanDetailView(plan: plan) { action in
                    switch action {
                    case .start:
                        viewModel.startPlan(plan)
                    case .edit:
                        break // TODO: Implement editing
                    case .delete:
                        viewModel.deletePlan(plan)
                    }
                    selectedPlan = nil
                }
            }
        }
    }
    
    // MARK: - Header Stats Section
    private var headerStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Progress")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    icon: "target",
                    title: "Plans Completed",
                    value: "\(viewModel.completedPlansCount)",
                    color: .green
                )
                
                StatCard(
                    icon: "clock",
                    title: "Total Training Hours",
                    value: "\(viewModel.totalTrainingHours)h",
                    color: .blue
                )
                
                StatCard(
                    icon: "calendar",
                    title: "Current Streak",
                    value: "\(viewModel.currentStreak) days",
                    color: .orange
                )
                
                StatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Weekly Average",
                    value: "\(viewModel.weeklyAverage)h",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Active Plan Section
    private func activePlanSection(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Plan")
                .font(.title2)
                .fontWeight(.bold)
            
            ActivePlanCard(plan: plan) {
                selectedPlan = plan
            }
        }
    }
    
    // MARK: - Recommended Plans Section
    private var recommendedPlansSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended for You")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.recommendedPlans) { plan in
                        RecommendedPlanCard(plan: plan) {
                            selectedPlan = plan
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - All Plans Section
    private var allPlansSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All Training Plans")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    Button("Sort by Name") { viewModel.sortBy = .name }
                    Button("Sort by Duration") { viewModel.sortBy = .duration }
                    Button("Sort by Difficulty") { viewModel.sortBy = .difficulty }
                    Button("Sort by Recent") { viewModel.sortBy = .recent }
                } label: {
                    HStack {
                        Text("Sort")
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.allPlans) { plan in
                    TrainingPlanRowCard(plan: plan) {
                        selectedPlan = plan
                    }
                }
            }
            
            if viewModel.allPlans.isEmpty {
                EmptyPlansView {
                    showingCreatePlan = true
                }
                .padding(.vertical, 40)
            }
        }
    }
}

// MARK: - Supporting Views

struct ActivePlanCard: View {
    let plan: TrainingPlan
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(plan.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    DifficultyBadge(difficulty: plan.difficulty)
                }
                
                // Progress Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(plan.completedWeeks)/\(plan.totalWeeks) weeks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: Double(plan.completedWeeks), total: Double(plan.totalWeeks))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
                
                // Next Workout
                if let nextWorkout = plan.nextWorkout {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Workout")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(nextWorkout.name)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RecommendedPlanCard: View {
    let plan: TrainingPlan
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: plan.type.icon)
                        .font(.title2)
                        .foregroundColor(plan.difficulty.color)
                    
                    Text(plan.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(plan.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Spacer()
                
                // Stats
                VStack(spacing: 8) {
                    HStack {
                        Label("\(plan.totalWeeks) weeks", systemImage: "calendar")
                        Spacer()
                        DifficultyBadge(difficulty: plan.difficulty)
                    }
                    .font(.caption)
                    
                    Text("Recommended based on your progress")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .frame(width: 200, height: 160)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct TrainingPlanRowCard: View {
    let plan: TrainingPlan
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: plan.type.icon)
                    .font(.title2)
                    .foregroundColor(plan.difficulty.color)
                    .frame(width: 40, height: 40)
                    .background(plan.difficulty.color.opacity(0.1))
                    .cornerRadius(8)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(plan.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label("\(plan.totalWeeks) weeks", systemImage: "calendar")
                        Label(plan.type.displayName, systemImage: plan.type.icon)
                        DifficultyBadge(difficulty: plan.difficulty)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
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

struct EmptyPlansView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Training Plans")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Create your first training plan to start building consistency in your workouts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Create Your First Plan") {
                action()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Models and Enums

struct TrainingPlan: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var type: TrainingPlanType
    var difficulty: DifficultyLevel
    var totalWeeks: Int
    var completedWeeks: Int
    var workouts: [PlannedWorkout]
    var tags: [String]
    var isActive: Bool
    var createdAt: Date
    
    var nextWorkout: PlannedWorkout? {
        workouts.first { !$0.isCompleted }
    }
    
    var progressPercentage: Double {
        guard totalWeeks > 0 else { return 0 }
        return Double(completedWeeks) / Double(totalWeeks)
    }
}

struct PlannedWorkout: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var week: Int
    var day: Int
    var workout: CustomWorkout
    var isCompleted: Bool
    var completedAt: Date?
}

enum TrainingPlanType: String, CaseIterable {
    case shuttleRun = "shuttle_run"
    case endurance = "endurance"
    case strength = "strength"
    case hiit = "hiit"
    case mixed = "mixed"
    
    var displayName: String {
        switch self {
        case .shuttleRun: return "Shuttle Run"
        case .endurance: return "Endurance"
        case .strength: return "Strength"
        case .hiit: return "HIIT"
        case .mixed: return "Mixed Training"
        }
    }
    
    var icon: String {
        switch self {
        case .shuttleRun: return "figure.run"
        case .endurance: return "heart"
        case .strength: return "dumbbell"
        case .hiit: return "bolt.fill"
        case .mixed: return "infinity"
        }
    }
}

enum PlanAction {
    case start
    case edit
    case delete
}

#Preview {
    TrainingPlansView()
}
