//
//  IntervalWorkoutView.swift
//  ShuttlX
//
//  Created by ShuttlX MVP on 6/9/25.
//

import SwiftUI

// MARK: - Temporary IntervalWorkout (until files added to Xcode target)
struct IntervalWorkout: Identifiable {
    let id = UUID()
    let name: String
    let runDuration: TimeInterval
    let walkDuration: TimeInterval
    let totalIntervals: Int
    
    static let beginner = IntervalWorkout(name: "Beginner", runDuration: 60, walkDuration: 90, totalIntervals: 8)
    static let intermediate = IntervalWorkout(name: "Intermediate", runDuration: 90, walkDuration: 60, totalIntervals: 10)
    static let advanced = IntervalWorkout(name: "Advanced", runDuration: 120, walkDuration: 60, totalIntervals: 12)
}

// MARK: - Temporary IntervalTimerService (until files added to Xcode target)
extension TemporaryIntervalTimer {
    func startWorkout(_ workout: IntervalWorkout) {
        startWorkout()
    }
}

struct IntervalWorkoutView: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    @Environment(\.dismiss) private var dismiss
    
    var intervalTimer: TemporaryIntervalTimer {
        serviceLocator.intervalTimer
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if intervalTimer.isActive {
                    ActiveWorkoutView()
                } else {
                    WorkoutSetupView()
                }
            }
            .navigationTitle("Run-Walk Intervals")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Active Workout View
struct ActiveWorkoutView: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    
    var intervalTimer: IntervalTimerService {
        serviceLocator.intervalTimer
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Current Phase
            VStack(spacing: 10) {
                Text(intervalTimer.currentPhase.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(phaseColor)
                
                Text("Interval \(intervalTimer.completedIntervals + 1)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Timer Display
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerProgress)
                
                VStack {
                    Text(timeString(intervalTimer.remainingTime))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress Info
            VStack(spacing: 8) {
                HStack {
                    Text("Completed Intervals:")
                    Spacer()
                    Text("\(intervalTimer.completedIntervals)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Total Time:")
                    Spacer()
                    Text(timeString(intervalTimer.totalElapsedTime))
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal)
            
            // Control Buttons
            HStack(spacing: 20) {
                if intervalTimer.isPaused {
                    Button("Resume") {
                        intervalTimer.resumeWorkout()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .green))
                } else {
                    Button("Pause") {
                        intervalTimer.pauseWorkout()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .orange))
                }
                
                Button("Stop") {
                    intervalTimer.stopWorkout()
                }
                .buttonStyle(PrimaryButtonStyle(color: .red))
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private var phaseColor: Color {
        switch intervalTimer.currentPhase {
        case .running: return .red
        case .walking: return .blue
        case .completed: return .purple
        }
    }
    
    private var timerProgress: Double {
        guard let workout = intervalTimer.currentWorkout else { return 0 }
        
        let totalTime: TimeInterval
        switch intervalTimer.currentPhase {
        case .running: totalTime = workout.runDuration
        case .walking: totalTime = workout.walkDuration
        case .completed: totalTime = 1
        }
        
        return 1.0 - (intervalTimer.remainingTime / totalTime)
    }
}

// MARK: - Workout Setup View
struct WorkoutSetupView: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    @State private var selectedWorkout: IntervalWorkout = .beginner
    
    private let presetWorkouts = [
        IntervalWorkout.beginner,
        IntervalWorkout.intermediate,
        IntervalWorkout.advanced
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Choose Your Interval Training")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                ForEach(presetWorkouts, id: \.id) { workout in
                    WorkoutPresetCard(
                        workout: workout,
                        isSelected: selectedWorkout.id == workout.id
                    ) {
                        selectedWorkout = workout
                    }
                }
            }
            
            Spacer()
            
            // Training Note
            VStack(spacing: 8) {
                Text("Training Available on Apple Watch")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("Use your Apple Watch to start interval workouts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Supporting Views
struct WorkoutPresetCard: View {
    let workout: IntervalWorkout
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\(Int(workout.runDuration/60))min run / \(Int(workout.walkDuration/60))min walk")
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
                    Label("\(Int(workout.totalDuration/60)) min", systemImage: "clock")
                    Spacer()
                    Label("\(workout.totalIntervals) intervals", systemImage: "repeat")
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
}

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Helper Functions
func timeString(_ timeInterval: TimeInterval) -> String {
    let minutes = Int(timeInterval) / 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

#Preview {
    IntervalWorkoutView()
        .environmentObject(ServiceLocator.shared)
}
