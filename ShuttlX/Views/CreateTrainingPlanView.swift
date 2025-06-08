//
//  CreateTrainingPlanView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct CreateTrainingPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateTrainingPlanViewModel()
    let onPlanCreated: (TrainingPlan) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Plan Info Section
                    planInfoSection
                    
                    // Plan Configuration
                    planConfigurationSection
                    
                    // Schedule Configuration
                    scheduleConfigurationSection
                    
                    // Workout Templates
                    workoutTemplatesSection
                    
                    // Plan Preview
                    if viewModel.hasValidConfiguration {
                        planPreviewSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Create Training Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let plan = viewModel.createTrainingPlan()
                        onPlanCreated(plan)
                        dismiss()
                    }
                    .disabled(!viewModel.isValidPlan)
                }
            }
        }
    }
    
    // MARK: - Plan Info Section
    private var planInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Plan Details", icon: "info.circle")
            
            VStack(spacing: 12) {
                // Plan Name
                CustomTextField(
                    title: "Plan Name",
                    text: $viewModel.planName,
                    placeholder: "Enter plan name"
                )
                
                // Plan Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    TextField("Describe your training plan...", text: $viewModel.planDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Plan Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    TextField("Add tags (comma separated)", text: $viewModel.tagsText)
                        .textFieldStyle(.roundedBorder)
                    
                    if !viewModel.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.tags, id: \.self) { tag in
                                    TagChip(tag: tag) {
                                        viewModel.removeTag(tag)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Plan Configuration Section
    private var planConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Plan Configuration", icon: "gearshape")
            
            VStack(spacing: 16) {
                // Plan Type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan Type")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Picker("Plan Type", selection: $viewModel.selectedPlanType) {
                        ForEach(TrainingPlanType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Difficulty Level
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty Level")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Picker("Difficulty", selection: $viewModel.selectedDifficulty) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                            HStack {
                                Circle()
                                    .fill(difficulty.color)
                                    .frame(width: 12, height: 12)
                                Text(difficulty.rawValue.capitalized)
                            }
                            .tag(difficulty)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Duration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan Duration")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Stepper(
                            "\(viewModel.totalWeeks) weeks",
                            value: $viewModel.totalWeeks,
                            in: 1...52,
                            step: 1
                        )
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Schedule Configuration Section
    private var scheduleConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Schedule Configuration", icon: "calendar")
            
            VStack(spacing: 16) {
                // Workouts per week
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workouts per Week")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Stepper(
                        "\(viewModel.workoutsPerWeek) workouts",
                        value: $viewModel.workoutsPerWeek,
                        in: 1...7,
                        step: 1
                    )
                }
                
                // Progressive Difficulty
                Toggle("Progressive Difficulty", isOn: $viewModel.isProgressive)
                
                // Workout Duration Range
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workout Duration Range")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    HStack {
                        VStack {
                            Text("Min")
                            Stepper("\(viewModel.minDuration) min", value: $viewModel.minDuration, in: 5...120, step: 5)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Max")
                            Stepper("\(viewModel.maxDuration) min", value: $viewModel.maxDuration, in: 5...120, step: 5)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Workout Templates Section
    private var workoutTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Workout Templates", icon: "doc.text")
            
            VStack(spacing: 12) {
                // Quick Templates
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    QuickTemplateCard(
                        title: "Basic Structure",
                        description: "Simple workout progression",
                        icon: "figure.walk",
                        isSelected: viewModel.selectedTemplate == .basic
                    ) {
                        viewModel.selectedTemplate = .basic
                    }
                    
                    QuickTemplateCard(
                        title: "HIIT Focus",
                        description: "High intensity intervals",
                        icon: "bolt.fill",
                        isSelected: viewModel.selectedTemplate == .hiit
                    ) {
                        viewModel.selectedTemplate = .hiit
                    }
                    
                    QuickTemplateCard(
                        title: "Endurance Build",
                        description: "Progressive endurance",
                        icon: "heart.fill",
                        isSelected: viewModel.selectedTemplate == .endurance
                    ) {
                        viewModel.selectedTemplate = .endurance
                    }
                    
                    QuickTemplateCard(
                        title: "Mixed Training",
                        description: "Variety of exercises",
                        icon: "infinity",
                        isSelected: viewModel.selectedTemplate == .mixed
                    ) {
                        viewModel.selectedTemplate = .mixed
                    }
                }
                
                // Custom Template Option
                Button(action: {
                    viewModel.showingCustomTemplates = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Browse Custom Templates")
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Plan Preview Section
    private var planPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Plan Preview", icon: "eye")
            
            VStack(spacing: 16) {
                // Plan Summary
                HStack {
                    VStack(alignment: .leading) {
                        Text(viewModel.planName.isEmpty ? "New Training Plan" : viewModel.planName)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(viewModel.planDescription.isEmpty ? "Custom training plan" : viewModel.planDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack {
                        DifficultyBadge(difficulty: viewModel.selectedDifficulty)
                        TypeBadge(type: viewModel.selectedPlanType)
                    }
                }
                
                // Plan Stats
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    PreviewStatCard(
                        icon: "calendar",
                        title: "Duration",
                        value: "\(viewModel.totalWeeks) weeks"
                    )
                    
                    PreviewStatCard(
                        icon: "repeat",
                        title: "Frequency",
                        value: "\(viewModel.workoutsPerWeek)/week"
                    )
                    
                    PreviewStatCard(
                        icon: "clock",
                        title: "Session",
                        value: "\(viewModel.minDuration)-\(viewModel.maxDuration) min"
                    )
                }
                
                // Total Workouts
                HStack {
                    Text("Total Workouts:")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(viewModel.totalWorkouts)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
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
                .fontWeight(.medium)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

struct QuickTemplateCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PreviewStatCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
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

#Preview {
    CreateTrainingPlanView { plan in
        print("Created plan: \(plan.name)")
    }
}
