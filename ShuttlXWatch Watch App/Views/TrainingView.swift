import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        // Apple Fitness-style timer design - clean, all measurements fit in one screen
        VStack(spacing: 6) {
            // Main timer display (large, central)
            AppleStyleTimerView()
            
            // Current interval indicator (compact)
            if let currentInterval = workoutManager.currentInterval {
                CurrentIntervalView(interval: currentInterval)
            }
            
            // Metrics in a clean grid layout (heart rate, calories, distance)
            MetricsGridView()
            
            // Control buttons (start/pause, end)
            WorkoutControlsView()
        }
        .navigationTitle(workoutManager.currentProgram?.name ?? "Training")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(workoutManager.isRunning)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Exit") {
                    workoutManager.resetProgram()
                }
                .disabled(workoutManager.isRunning)
            }
        }
    }
}

struct AppleStyleTimerView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 2) {
            // Main elapsed time - large and prominent
            Text(formattedTime(workoutManager.elapsedTime))
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
            
            // Remaining total time - smaller, secondary
            if workoutManager.remainingTime > 0 {
                Text("-\(formattedTime(workoutManager.remainingTime))")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct CurrentIntervalView: View {
    let interval: TrainingInterval
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 4) {
            // Interval type with icon
            HStack(spacing: 4) {
                Image(systemName: interval.type.systemImageName)
                    .foregroundColor(colorForType(interval.type))
                    .font(.system(size: 14, weight: .medium))
                
                Text(interval.type.rawValue.uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorForType(interval.type))
                
                Spacer()
                
                // Interval progress indicator
                Text("\(workoutManager.currentIntervalIndex + 1)/\(workoutManager.currentProgram?.intervalCount ?? 0)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Interval timer
            HStack {
                Text(formattedTime(workoutManager.intervalElapsedTime))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                
                Spacer()
                
                if workoutManager.intervalRemainingTime > 0 {
                    Text("-\(formattedTime(workoutManager.intervalRemainingTime))")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            
            // Progress bar
            ProgressView(value: progressValue, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: colorForType(interval.type)))
                .scaleEffect(y: 0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .opacity(0.8)
        )
    }
    
    private var progressValue: Double {
        guard interval.duration > 0 else { return 0 }
        return min(1.0, workoutManager.intervalElapsedTime / interval.duration)
    }
    
    private func colorForType(_ type: IntervalType) -> Color {
        switch type {
        case .walk:
            return .blue
        case .run:
            return .red
        case .rest:
            return .gray
        }
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct MetricsGridView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Heart Rate
            MetricView(
                value: workoutManager.heartRate > 0 ? String(format: "%.0f", workoutManager.heartRate) : "--",
                unit: "BPM",
                icon: "heart.fill",
                color: .red
            )
            
            // Calories
            MetricView(
                value: workoutManager.caloriesBurned > 0 ? String(format: "%.0f", workoutManager.caloriesBurned) : "--",
                unit: "CAL",
                icon: "flame.fill",
                color: .orange
            )
            
            // Distance
            MetricView(
                value: workoutManager.distance > 0 ? String(format: "%.0f", workoutManager.distance) : "--",
                unit: "M",
                icon: "figure.run",
                color: .green
            )
        }
        .padding(.horizontal, 4)
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
                .font(.system(size: 12))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(unit)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .opacity(0.6)
        )
    }
}

struct WorkoutControlsView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Start/Pause button
            Button(action: {
                workoutManager.toggleWorkout()
            }) {
                Image(systemName: buttonIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(buttonColor)
                    )
            }
            .buttonStyle(.plain)
            
            // End button
            Button(action: {
                workoutManager.endWorkout()
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.red)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!workoutManager.isRunning && !workoutManager.isPaused && workoutManager.elapsedTime == 0)
        }
        .padding(.top, 4)
    }
    
    private var buttonIcon: String {
        if workoutManager.isRunning {
            return "pause.fill"
        } else {
            return "play.fill"
        }
    }
    
    private var buttonColor: Color {
        if workoutManager.isRunning {
            return .orange
        } else {
            return .green
        }
    }
}

#Preview {
    NavigationView {
        TrainingView()
    }
    .environmentObject(WatchWorkoutManager())
}
