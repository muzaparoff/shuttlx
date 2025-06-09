//
//  WorkoutSelectionView.swift
//  ShuttlX MVP
//
//  Created by ShuttlX on 6/8/25.
//

import SwiftUI
import HealthKit

struct WorkoutSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var serviceLocator: ServiceLocator
    @State private var selectedWorkoutType: SimpleWorkoutType = .running
    
    private let workoutTypes: [SimpleWorkoutType] = [.running, .walking, .cycling, .hiit]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Select Workout")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose your workout type and start training")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Workout Type Selection
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(workoutTypes, id: \.self) { workoutType in
                        WorkoutTypeCard(
                            workoutType: workoutType,
                            isSelected: selectedWorkoutType == workoutType
                        ) {
                            selectedWorkoutType = workoutType
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Start Workout Button
                Button(action: startWorkout) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start \(selectedWorkoutType.displayName)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startWorkout() {
        Task {
            // Start workout on iOS
            await startWorkoutSession()
            
            // Start workout on Watch if connected
            if serviceLocator.watchManager.isWatchConnected {
                serviceLocator.watchManager.sendWorkoutCommand("start")
            }
            
            dismiss()
        }
    }
    
    private func startWorkoutSession() async {
        // Create basic workout configuration
        let configuration = WorkoutConfiguration(
            type: mapToWorkoutType(selectedWorkoutType),
            name: selectedWorkoutType.displayName,
            description: "Quick workout session",
            duration: 0, // Open-ended
            intervals: [],
            restPeriods: [],
            difficulty: .intermediate,
            targetHeartRateZone: nil,
            audioCoaching: AudioCoachingSettings(),
            hapticFeedback: HapticFeedbackSettings()
        )
        
        // Start the workout
        serviceLocator.healthManager.startWorkout(type: .running)
    }
    
    private func mapToWorkoutType(_ simpleType: SimpleWorkoutType) -> WorkoutType {
        switch simpleType {
        case .running: return .runWalk
        case .walking: return .runWalk
        case .cycling: return .runWalk // For now, map to runWalk
        case .hiit: return .hiit
        default: return .runWalk
        }
    }
}

// MARK: - Workout Type Card
struct WorkoutTypeCard: View {
    let workoutType: SimpleWorkoutType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: workoutType.icon)
                    .font(.title)
                    .foregroundColor(isSelected ? .white : .orange)
                
                Text(workoutType.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(workoutType.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(isSelected ? Color.orange : Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Workout Command Helper
// Note: Workout commands are now handled through SimpleWatchManager in ServiceLocator

enum WorkoutCommand: String {
    case start = "start"
    case pause = "pause"
    case resume = "resume"
    case stop = "stop"
}

// MARK: - Preview
struct WorkoutSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutSelectionView()
    }
}
