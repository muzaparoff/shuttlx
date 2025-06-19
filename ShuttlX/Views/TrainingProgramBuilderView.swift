//
//  TrainingProgramBuilderView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import SwiftUI

struct TrainingProgramBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TrainingProgramBuilderViewModel()
    @State private var showingPreview = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Program Details
                    programDetailsSection
                    
                    // Intervals Configuration
                    intervalsSection
                    
                    // Difficulty & Target Zone
                    difficultySection
                    
                    // Preview Button
                    previewButton
                    
                    Spacer(minLength: 80)
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
            .navigationTitle("Create Program")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveProgram()
                        dismiss()
                    }
                    .disabled(!viewModel.isFormValid)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            TrainingProgramPreviewView(program: viewModel.buildProgram())
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "stopwatch.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Design Your Training")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Create a custom interval training program tailored to your goals")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Program Details Section
    private var programDetailsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Program Details", icon: "info.circle.fill")
            
            VStack(spacing: 12) {
                FloatingTextField(
                    title: "Program Name",
                    text: $viewModel.programName,
                    placeholder: "My Custom Training"
                )
                
                FloatingTextField(
                    title: "Description",
                    text: $viewModel.description,
                    placeholder: "Describe your training goals...",
                    isMultiline: true
                )
            }
        }
    }
    
    // MARK: - Intervals Section
    private var intervalsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Interval Configuration", icon: "timer.circle.fill")
            
            VStack(spacing: 16) {
                // Distance
                SliderCard(
                    title: "Total Distance",
                    value: $viewModel.distance,
                    range: 1...20,
                    unit: "km",
                    color: .orange,
                    icon: "figure.run.circle.fill"
                )
                
                // Run Interval
                SliderCard(
                    title: "Run Interval",
                    value: $viewModel.runInterval,
                    range: 0.5...5.0,
                    unit: "min",
                    color: .red,
                    icon: "hare.fill",
                    step: 0.5
                )
                
                // Walk Interval
                SliderCard(
                    title: "Walk Interval",
                    value: $viewModel.walkInterval,
                    range: 0.5...5.0,
                    unit: "min",
                    color: .blue,
                    icon: "tortoise.fill",
                    step: 0.5
                )
                
                // Estimated Duration Display
                estimatedDurationCard
            }
        }
    }
    
    // MARK: - Difficulty Section
    private var difficultySection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Intensity Settings", icon: "heart.circle.fill")
            
            VStack(spacing: 16) {
                // Difficulty Selection
                DifficultySelector(selectedDifficulty: $viewModel.difficulty)
                
                // Heart Rate Zone Selection
                HeartRateZoneSelector(selectedZone: $viewModel.targetHeartRateZone)
            }
        }
    }
    
    // MARK: - Estimated Duration Card
    private var estimatedDurationCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("Estimated Duration")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(viewModel.estimatedDuration)) min")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.red)
                Text("Estimated Calories")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(viewModel.estimatedCalories)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Preview Button
    private var previewButton: some View {
        Button(action: {
            showingPreview = true
        }) {
            HStack {
                Image(systemName: "eye.fill")
                Text("Preview Program")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.orange.opacity(0.8), .red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.isFormValid)
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
    }
}

struct FloatingTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isMultiline: Bool
    
    init(title: String, text: Binding<String>, placeholder: String, isMultiline: Bool = false) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.isMultiline = isMultiline
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if isMultiline {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
}

struct SliderCard: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let color: Color
    let icon: String
    let step: Double
    
    init(title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String, color: Color, icon: String, step: Double = 1.0) {
        self.title = title
        self._value = value
        self.range = range
        self.unit = unit
        self.color = color
        self.icon = icon
        self.step = step
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: step < 1 ? "%.1f %@" : "%.0f %@", value, unit))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(color)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DifficultySelector: View {
    @Binding var selectedDifficulty: TrainingDifficulty
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Difficulty Level")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(TrainingDifficulty.allCases, id: \.self) { difficulty in
                    DifficultyButton(
                        difficulty: difficulty,
                        isSelected: selectedDifficulty == difficulty
                    ) {
                        selectedDifficulty = difficulty
                    }
                }
            }
        }
    }
}

struct DifficultyButton: View {
    let difficulty: TrainingDifficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: difficulty.icon)
                    .font(.title2)
                Text(difficulty.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? 
                    LinearGradient(colors: [difficulty.color.opacity(0.3)], startPoint: .top, endPoint: .bottom) :
                    Color.gray.opacity(0.1)
            )
            .foregroundColor(isSelected ? difficulty.color : .secondary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? difficulty.color : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct HeartRateZoneSelector: View {
    @Binding var selectedZone: HeartRateZone
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Heart Rate Zone")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(HeartRateZone.allCases, id: \.self) { zone in
                    HeartRateZoneButton(
                        zone: zone,
                        isSelected: selectedZone == zone
                    ) {
                        selectedZone = zone
                    }
                }
            }
        }
    }
}

struct HeartRateZoneButton: View {
    let zone: HeartRateZone
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundColor(zone.color)
                Text(zone.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(zone.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? 
                    Color.gray.opacity(0.2) :
                    Color.gray.opacity(0.1)
            )
            .foregroundColor(isSelected ? .primary : .secondary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? zone.color : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
    TrainingProgramBuilderView()
}
