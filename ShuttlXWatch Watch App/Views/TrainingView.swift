import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 6) {
            if let program = workoutManager.currentProgram,
               let currentInterval = workoutManager.currentInterval {
                CurrentPhaseView(
                    programType: program.type,
                    currentInterval: currentInterval,
                    workLabel: program.type.workPhaseLabel,
                    restLabel: program.type.restPhaseLabel
                )
            }
            
            AppleStyleTimerView()
            MetricsGridView()
            WorkoutControlsView()
        }
        .navigationTitle(workoutManager.currentProgram?.name ?? "Training")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CurrentPhaseView: View {
    let programType: ProgramType
    let currentInterval: TrainingInterval
    let workLabel: String
    let restLabel: String
    
    private var phaseLabel: String {
        currentInterval.phase == .work ? workLabel : restLabel
    }
    
    private var phaseColor: Color {
        currentInterval.phase == .work ? .red : .blue
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(phaseColor)
                .frame(width: 8, height: 8)
            
            Text(phaseLabel.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(phaseColor)
            
            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(currentInterval.intensity.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct AppleStyleTimerView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 4) {
            Text(formatTime(workoutManager.timeRemaining))
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
            
            Text("Interval \(workoutManager.currentIntervalIndex + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval / 60)
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct MetricsGridView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        HStack(spacing: 16) {
            MetricView(
                value: workoutManager.heartRate > 0 ? "\(workoutManager.heartRate)" : "--",
                unit: "BPM",
                icon: "heart.fill",
                color: .red
            )
            
            MetricView(
                value: "\(workoutManager.calories)",
                unit: "CAL",
                icon: "flame.fill",
                color: .orange
            )
        }
    }
}

struct MetricView: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutControlsView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                if workoutManager.isWorkoutActive {
                    workoutManager.pauseWorkout()
                } else {
                    workoutManager.resumeWorkout()
                }
            }) {
                Image(systemName: workoutManager.isWorkoutActive ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(workoutManager.isWorkoutActive ? .orange : .green)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color.gray.opacity(0.3)))
            
            Button(action: {
                workoutManager.stopWorkout()
            }) {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color.gray.opacity(0.3)))
        }
    }
}

#Preview {
    NavigationView {
        TrainingView()
            .environmentObject(WatchWorkoutManager())
    }
}
