import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var selectedTab = 0
    @State private var showingStopConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Timer + Metrics
            VStack(spacing: 6) {
                Spacer(minLength: 0)

                // Elapsed time (counts UP)
                ElapsedTimerView()

                Spacer(minLength: 0)

                // Vertical metrics
                WorkoutMetricsView()
            }
            .tag(0)

            // Tab 2: Controls
            VStack(spacing: 16) {
                Text("Workout Controls")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                VStack(spacing: 20) {
                    // Pause / Resume
                    Button(action: {
                        if workoutManager.isPaused {
                            workoutManager.resumeWorkout()
                        } else {
                            workoutManager.pauseWorkout()
                        }
                    }) {
                        HStack {
                            Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                            Text(workoutManager.isPaused ? "Resume" : "Pause")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(workoutManager.isPaused ? .green : .orange)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                        )
                    }
                    .accessibilityLabel(workoutManager.isPaused ? "Resume workout" : "Pause workout")

                    // Stop
                    Button(action: {
                        showingStopConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("End Training")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                        )
                    }
                    .accessibilityLabel("End Training")
                    .accessibilityHint("Ends the workout and saves the session")
                }
                .padding(.horizontal)

                Spacer()
            }
            .tag(1)
        }
        .navigationBarHidden(true)
        .tabViewStyle(PageTabViewStyle())
        .alert("End Training", isPresented: $showingStopConfirmation) {
            Button(role: .destructive) {
                workoutManager.saveWorkoutData()
                workoutManager.stopWorkout()
            } label: {
                Text("End & Save")
            }
            Button(role: .cancel) {} label: {
                Text("Cancel")
            }
        } message: {
            Text("Save this training session?")
        }
    }
}

// MARK: - Workout Metrics (Vertical Stack)

struct WorkoutMetricsView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    private let metricFont = Font.system(.title2, design: .rounded).weight(.bold)

    var body: some View {
        VStack(spacing: 4) {
            // Line 1: Split count + Distance
            Text(splitDistanceText)
                .font(metricFont)
                .monospacedDigit()
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Split \(workoutManager.lastCompletedKm), distance \(accessibleDistance)")

            // Line 2: Heart Rate
            Text(heartRateText)
                .font(metricFont)
                .monospacedDigit()
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(workoutManager.heartRate > 0 ? "\(workoutManager.heartRate) beats per minute" : "Heart rate no data")
                .accessibilityAddTraits(.updatesFrequently)

            // Line 3: Average Pace
            Text(paceText)
                .font(metricFont)
                .monospacedDigit()
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(accessiblePace)
        }
        .padding(.horizontal, 8)
    }

    private var splitDistanceText: String {
        let km = workoutManager.lastCompletedKm
        let dist = workoutManager.totalDistance
        let distStr: String
        if dist < 1.0 {
            distStr = "\(Int(dist * 1000)) m"
        } else {
            distStr = String(format: "%.2f km", dist)
        }
        return "\(km) / \(distStr)"
    }

    private var accessibleDistance: String {
        let dist = workoutManager.totalDistance
        if dist < 1.0 {
            return "\(Int(dist * 1000)) meters"
        } else {
            return String(format: "%.2f kilometers", dist)
        }
    }

    private var heartRateText: String {
        workoutManager.heartRate > 0 ? "\(workoutManager.heartRate) BPM" : "-- BPM"
    }

    private var paceText: String {
        guard let pace = workoutManager.currentPace else {
            return "-- Av.Pace"
        }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d'%02d\" Av.Pace", minutes, seconds)
    }

    private var accessiblePace: String {
        guard let pace = workoutManager.currentPace else {
            return "Average pace no data"
        }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return "Average pace \(minutes) minutes \(seconds) seconds per kilometer"
    }
}

// MARK: - Elapsed Timer (counts UP)

struct ElapsedTimerView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        VStack(spacing: 4) {
            Text(formatTime(workoutManager.elapsedTime))
                .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Elapsed time \(formatTimeAccessible(workoutManager.elapsedTime))")
                .accessibilityAddTraits(.updatesFrequently)

            if workoutManager.isPaused {
                Text("PAUSED")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 8)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval / 60)
        let s = Int(interval.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", m, s)
    }

    private func formatTimeAccessible(_ interval: TimeInterval) -> String {
        let m = Int(interval / 60)
        let s = Int(interval.truncatingRemainder(dividingBy: 60))
        return m > 0 ? "\(m) minutes \(s) seconds" : "\(s) seconds"
    }
}

#Preview {
    NavigationStack {
        TrainingView()
            .environmentObject(WatchWorkoutManager())
    }
}
