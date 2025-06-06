import SwiftUI
import HealthKit

struct WatchWorkoutView: View {
    @StateObject private var workoutManager = WatchWorkoutManager()
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Main workout display
            WorkoutMetricsView()
                .environmentObject(workoutManager)
                .tag(0)
            
            // Controls
            WorkoutControlsView()
                .environmentObject(workoutManager)
                .tag(1)
            
            // Progress
            WorkoutProgressView()
                .environmentObject(workoutManager)
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle())
        .navigationBarHidden(true)
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

struct WorkoutMetricsView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 8) {
            // Timer
            VStack {
                Text(workoutManager.formattedElapsedTime)
                    .font(.title)
                    .foregroundColor(.primary)
                Text("ELAPSED TIME")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Main metrics
            HStack {
                MetricView(
                    value: "\(Int(workoutManager.heartRate))",
                    unit: "BPM",
                    label: "HEART RATE",
                    color: .red
                )
                
                MetricView(
                    value: "\(Int(workoutManager.activeCalories))",
                    unit: "CAL",
                    label: "CALORIES",
                    color: .orange
                )
            }
            
            // Distance (if available)
            if workoutManager.distance > 0 {
                MetricView(
                    value: String(format: "%.2f", workoutManager.distance),
                    unit: "M",
                    label: "DISTANCE",
                    color: .green
                )
            }
            
            // Current interval info
            if let currentInterval = workoutManager.currentInterval {
                VStack(spacing: 4) {
                    Text(currentInterval.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Interval \(workoutManager.currentIntervalIndex + 1) of \(workoutManager.totalIntervals)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(workoutManager.formattedIntervalTime)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: workoutManager.intervalProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }
}

struct MetricView: View {
    let value: String
    let unit: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct WorkoutControlsView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Primary control button
            Button(action: {
                if workoutManager.isActive {
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                } else {
                    workoutManager.startWorkout(type: .running) // Default type
                }
            }) {
                HStack {
                    Image(systemName: workoutManager.isActive 
                          ? (workoutManager.isPaused ? "play.fill" : "pause.fill")
                          : "play.fill")
                    
                    Text(workoutManager.isActive 
                         ? (workoutManager.isPaused ? "Resume" : "Pause")
                         : "Start")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(workoutManager.isActive 
                           ? (workoutManager.isPaused ? .green : .orange)
                           : .blue)
                .cornerRadius(25)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Secondary controls
            if workoutManager.isActive {
                HStack(spacing: 12) {
                    // Skip interval
                    Button(action: {
                        workoutManager.skipToNextInterval()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(22)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // End workout
                    Button(action: {
                        workoutManager.endWorkout()
                        dismiss()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(22)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Workout selection (when not active)
            if !workoutManager.isActive {
                VStack(spacing: 8) {
                    Text("Select Workout Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        WorkoutTypeButton(
                            icon: "figure.run",
                            title: "Running",
                            type: .running,
                            workoutManager: workoutManager
                        )
                        
                        WorkoutTypeButton(
                            icon: "figure.walk",
                            title: "Walking",
                            type: .walking,
                            workoutManager: workoutManager
                        )
                    }
                }
            }
        }
        .padding()
    }
}

struct WorkoutTypeButton: View {
    let icon: String
    let title: String
    let type: HKWorkoutActivityType
    let workoutManager: WatchWorkoutManager
    
    var body: some View {
        Button(action: {
            workoutManager.startWorkout(type: type)
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WorkoutProgressView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Overall progress
            VStack(spacing: 8) {
                Text("Workout Progress")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                CircularProgressView(
                    progress: workoutManager.overallProgress,
                    color: .blue
                )
                .frame(width: 80, height: 80)
                
                Text("\(Int(workoutManager.overallProgress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Interval breakdown
            if workoutManager.totalIntervals > 0 {
                VStack(spacing: 8) {
                    Text("Intervals")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Completed")
                        Spacer()
                        Text("\(workoutManager.currentIntervalIndex) / \(workoutManager.totalIntervals)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    // Progress bar
                    ProgressView(value: Double(workoutManager.currentIntervalIndex) / Double(workoutManager.totalIntervals))
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                }
            }
            
            // Performance metrics
            VStack(spacing: 6) {
                Text("Performance")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("Avg HR")
                    Spacer()
                    Text("\(Int(workoutManager.averageHeartRate)) BPM")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                HStack {
                    Text("Max HR")
                    Spacer()
                    Text("\(Int(workoutManager.maxHeartRate)) BPM")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                HStack {
                    Text("Pace")
                    Spacer()
                    Text(workoutManager.formattedPace)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    WatchWorkoutView()
        .environmentObject(WatchConnectivityManager())
}
