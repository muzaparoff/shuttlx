//
//  WorkoutSelectionView.swift
//  ShuttlX
//
//  Created by ShuttlX MVP on 6/9/25.
//

import SwiftUI
import HealthKit

struct WorkoutSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var serviceLocator: ServiceLocator
    @State private var selectedWorkout: String = "Beginner"
    
    private let presetWorkouts = [
        "Beginner",
        "Intermediate", 
        "Advanced"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Run-Walk Intervals")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose your interval training level")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Workout Options
                VStack(spacing: 16) {
                    ForEach(presetWorkouts, id: \.self) { workout in
                        WorkoutCard(
                            workout: workout,
                            isSelected: selectedWorkout == workout
                        ) {
                            selectedWorkout = workout
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Training Note
                VStack(spacing: 8) {
                    Text("Training Available on Apple Watch")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Use your Apple Watch to start and control workouts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startWorkout() {
        // Start the selected workout
        serviceLocator.healthManager.startWorkout(type: .running)
        dismiss()
    }
}

struct WorkoutCard: View {
    let workout: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(getWorkoutDescription(workout))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                
                HStack {
                    Label("\(getWorkoutDuration(workout)) min", systemImage: "clock")
                    Spacer()
                    Label("\(getWorkoutIntervals(workout)) intervals", systemImage: "repeat")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getWorkoutDescription(_ workout: String) -> String {
        switch workout {
        case "Beginner": return "2min run / 3min walk"
        case "Intermediate": return "3min run / 2min walk"
        case "Advanced": return "5min run / 1min walk"
        default: return "Custom workout"
        }
    }
    
    private func getWorkoutDuration(_ workout: String) -> Int {
        switch workout {
        case "Beginner": return 25  // 5 intervals of 5 minutes each
        case "Intermediate": return 25  // 5 intervals of 5 minutes each
        case "Advanced": return 30  // 5 intervals of 6 minutes each
        default: return 20
        }
    }
    
    private func getWorkoutIntervals(_ workout: String) -> Int {
        switch workout {
        case "Beginner": return 5
        case "Intermediate": return 5
        case "Advanced": return 5
        default: return 4
        }
    }
}

#Preview {
    WorkoutSelectionView()
        .environmentObject(ServiceLocator.shared)
}
