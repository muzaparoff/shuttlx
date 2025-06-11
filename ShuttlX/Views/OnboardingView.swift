//
//  OnboardingView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import HealthKit

struct OnboardingView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var healthManager: HealthManager
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var currentStep = 0
    
    private let totalSteps = 6
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.orange.opacity(0.1), .red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .tint(.orange)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStep()
                        .tag(0)
                    
                    PersonalInfoStep(
                        firstName: $viewModel.firstName,
                        lastName: $viewModel.lastName,
                        email: $viewModel.email,
                        dateOfBirth: $viewModel.dateOfBirth
                    )
                    .tag(1)
                    
                    PhysicalInfoStep(
                        height: $viewModel.height,
                        weight: $viewModel.weight,
                        fitnessLevel: $viewModel.fitnessLevel
                    )
                    .tag(2)
                    
                    GoalsStep(selectedGoals: $viewModel.selectedGoals)
                        .tag(3)
                    
                    HealthPermissionsStep()
                        .tag(4)
                    
                    FitnessAssessmentStep(viewModel: viewModel)
                        .tag(5)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Navigation Buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep = max(0, currentStep - 1)
                            }
                        }
                        .foregroundColor(.secondary)
                    } else {
                        Spacer()
                    }
                    
                    Spacer()
                    
                    if currentStep < totalSteps - 1 {
                        Button("Next") {
                            withAnimation {
                                currentStep = min(totalSteps - 1, currentStep + 1)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canProceedFromStep(currentStep))
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canCompleteOnboarding())
                    }
                }
                .padding()
            }
        }
    }
    
    private func completeOnboarding() {
        Task {
            await viewModel.createUserProfile()
            await MainActor.run {
                appViewModel.completeOnboarding()
            }
        }
    }
}

// MARK: - Onboarding Steps

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Icon/Logo
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "figure.run")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 16) {
                Text("Welcome to ShuttlX")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Your intelligent shuttle run and interval training companion")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                OnboardingFeatureRow(
                    icon: "brain.head.profile",
                    title: "AI-Powered Coaching",
                    description: "Personalized workouts that adapt to your fitness level"
                )
                
                OnboardingFeatureRow(
                    icon: "applewatch",
                    title: "Apple Watch Integration",
                    description: "Seamless tracking across all your devices"
                )
                
                OnboardingFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Advanced Analytics",
                    description: "Detailed insights into your performance and progress"
                )
                
                OnboardingFeatureRow(
                    icon: "person.2.fill",
                    title: "Social Features",
                    description: "Connect with friends and join challenges"
                )
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PersonalInfoStep: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var email: String
    @Binding var dateOfBirth: Date
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Let's get to know you")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Help us personalize your experience")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    TextField("First Name", text: $firstName)
                        .textFieldStyle(OnboardingTextFieldStyle())
                    
                    TextField("Last Name", text: $lastName)
                        .textFieldStyle(OnboardingTextFieldStyle())
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(OnboardingTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date of Birth")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PhysicalInfoStep: View {
    @Binding var height: Double
    @Binding var weight: Double
    @Binding var fitnessLevel: FitnessLevel
    
    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 70
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            contentSection
            Spacer()
        }
        .padding()
        .onChange(of: heightCm) { _, newValue in
            height = newValue / 100 // Convert to meters
        }
        .onChange(of: weightKg) { _, newValue in
            weight = newValue
        }
        .onAppear {
            heightCm = height * 100 // Convert from meters
            weightKg = weight
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Physical Information")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("This helps us calculate accurate metrics")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var contentSection: some View {
        VStack(spacing: 24) {
            heightSection
            weightSection
            fitnessLevelSection
        }
    }
    
    private var heightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Height")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("\(Int(heightCm)) cm")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            Slider(value: $heightCm, in: 120...220, step: 1)
                .tint(.orange)
        }
    }
    
    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("\(Int(weightKg)) kg")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            Slider(value: $weightKg, in: 30...200, step: 1)
                .tint(.orange)
        }
    }
    
    private var fitnessLevelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Fitness Level")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                ForEach(FitnessLevel.allCases, id: \.self) { level in
                    Button(action: {
                        fitnessLevel = level
                    }) {
                        HStack {
                            Text(level.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(fitnessLevel == level ? .white : .primary)
                            
                            Spacer()
                            
                            if fitnessLevel == level {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(fitnessLevel == level ? Color.orange : Color.clear)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Material.ultraThinMaterial)
                                        .opacity(fitnessLevel == level ? 0 : 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct GoalsStep: View {
    @Binding var selectedGoals: Set<FitnessGoal>
    
    private let availableGoals: [FitnessGoal] = [
        .weightLoss,
        .strengthBuilding,
        .enduranceImprovement,
        .flexibilityMobility,
        .stressRelief,
        .generalFitness
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("What are your goals?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Select all that apply")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(availableGoals, id: \.self) { goal in
                    GoalCard(
                        goal: goal,
                        isSelected: selectedGoals.contains(goal)
                    ) {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct HealthPermissionsStep: View {
    @EnvironmentObject var healthManager: HealthManager
    @State private var hasRequestedPermissions = false
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                Text("Connect to Health")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("ShuttlX integrates with Apple Health to provide personalized recommendations and track your progress")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "heart.fill",
                    title: "Heart Rate Monitoring",
                    description: "Track workout intensity and recovery",
                    color: .red
                )
                
                PermissionCard(
                    icon: "figure.run",
                    title: "Workout Tracking",
                    description: "Save activities and analyze performance",
                    color: .blue
                )
                
                PermissionCard(
                    icon: "flame.fill",
                    title: "Calorie Tracking",
                    description: "Monitor energy expenditure",
                    color: .orange
                )
                
                PermissionCard(
                    icon: "location.fill",
                    title: "Location Services",
                    description: "Track running routes and distances",
                    color: .green
                )
            }
            
            if !hasRequestedPermissions {
                Button("Allow Health Access") {
                    healthManager.requestHealthKitPermissions()
                    hasRequestedPermissions = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text("Permissions Requested")
                            .fontWeight(.medium)
                    }
                    
                    Text("You can change these permissions anytime in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button("Skip for Now") {
                hasRequestedPermissions = true
            }
            .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

struct FitnessAssessmentStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showingAssessment = false
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Fitness Assessment")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Take a quick assessment to personalize your experience")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                AssessmentCard(
                    icon: "timer",
                    title: "Quick Assessment",
                    description: "3-5 minutes",
                    duration: "Beep test simulation"
                )
                
                AssessmentCard(
                    icon: "figure.run",
                    title: "Movement Screen",
                    description: "Basic mobility check",
                    duration: "Follow along exercises"
                )
                
                AssessmentCard(
                    icon: "heart.fill",
                    title: "Heart Rate Baseline",
                    description: "Establish your zones",
                    duration: "Resting measurement"
                )
            }
            
            VStack(spacing: 12) {
                Button("Start Assessment") {
                    showingAssessment = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Skip Assessment") {
                    viewModel.skipAssessment()
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAssessment) {
            FitnessAssessmentView(viewModel: viewModel)
        }
    }
}

// MARK: - Supporting Views

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct GoalCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .orange)
                
                Text(goal.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange : Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Material.ultraThinMaterial)
                            .opacity(isSelected ? 0 : 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .orange : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct AssessmentCard: View {
    let icon: String
    let title: String
    let description: String
    let duration: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(.orange.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(duration)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.ultraThinMaterial)
        )
    }
}

struct OnboardingTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Material.ultraThinMaterial)
            )
    }
}

struct FitnessAssessmentView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Fitness Assessment")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This is a placeholder for the fitness assessment flow")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
                
                Button("Complete Assessment") {
                    viewModel.completeAssessment()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        viewModel.skipAssessment()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

#Preview {
    OnboardingView()
        .environmentObject(AppViewModel())
        .environmentObject(ServiceLocator.shared)
}
