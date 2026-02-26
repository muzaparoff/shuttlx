import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var selectedTab = 0
    @State private var showingStopConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Timer + Metrics
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Elapsed time (counts UP)
                ElapsedTimerView()

                Spacer(minLength: 0)

                // 2x2 Metrics grid
                MetricsGridView()
            }
            .tag(0)

            // Tab 2: Controls
            VStack(spacing: 16) {
                Text("Workout Controls")
                    .font(.system(size: 16, weight: .semibold))
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
                        .font(.system(size: 16, weight: .semibold))
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
                        .font(.system(size: 16, weight: .semibold))
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
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Activity Indicator

struct ActivityIndicatorView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: workoutManager.currentActivity.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(workoutManager.currentActivity.color)

                Text(workoutManager.currentActivity.displayName.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(workoutManager.currentActivity.color)
            }
            .frame(maxWidth: .infinity)

            // Segment time
            Text("Segment: \(formatTime(workoutManager.currentSegmentTime))")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workoutManager.currentActivity.displayName), segment time \(formatTimeAccessible(workoutManager.currentSegmentTime))")
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

// MARK: - Elapsed Timer (counts UP)

struct ElapsedTimerView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        VStack(spacing: 4) {
            Text(formatTime(workoutManager.elapsedTime))
                .font(.system(size: 54, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Elapsed time \(formatTimeAccessible(workoutManager.elapsedTime))")
                .accessibilityAddTraits(.updatesFrequently)

            if workoutManager.isPaused {
                Text("PAUSED")
                    .font(.system(size: 14, weight: .bold))
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

// MARK: - Metrics Grid (2x2)

struct MetricsGridView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            MetricView(
                value: workoutManager.heartRate > 0 ? "\(workoutManager.heartRate)" : "--",
                unit: "BPM",
                icon: "heart.fill",
                color: .red
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Heart rate")
            .accessibilityValue(workoutManager.heartRate > 0 ? "\(workoutManager.heartRate) BPM" : "no data")

            MetricView(
                value: "\(workoutManager.calories)",
                unit: "CAL",
                icon: "flame.fill",
                color: .orange
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Calories")
            .accessibilityValue("\(workoutManager.calories)")

            MetricView(
                value: "\(workoutManager.totalSteps)",
                unit: "STEPS",
                icon: "shoeprints.fill",
                color: .blue
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Steps")
            .accessibilityValue("\(workoutManager.totalSteps)")

            MetricView(
                value: String(format: "%.2f", workoutManager.totalDistance),
                unit: "KM",
                icon: "location.fill",
                color: .green
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Distance")
            .accessibilityValue(String(format: "%.2f kilometers", workoutManager.totalDistance))
        }
        .padding(.horizontal)
    }
}

struct MetricView: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)

                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView {
        TrainingView()
            .environmentObject(WatchWorkoutManager())
    }
}
