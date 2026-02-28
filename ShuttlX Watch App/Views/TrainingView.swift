import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var selectedTab = 0
    @State private var showingStopConfirmation = false
    @State private var showingSummary = false
    @State private var savedSummary: WorkoutSummary?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if showingSummary, let summary = savedSummary {
            WorkoutSummaryView(summary: summary) {
                showingSummary = false
                savedSummary = nil
            }
        } else {
            workoutTabView
        }
    }

    private var workoutTabView: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Timer + Metrics
            VStack(spacing: 6) {
                Spacer(minLength: 0)
                ElapsedTimerView()
                Spacer(minLength: 0)
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

                    // Finish
                    Button(action: {
                        showingStopConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "flag.checkered")
                            Text("Finish")
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
                    .accessibilityLabel("Finish workout")
                    .accessibilityHint("Saves the workout and shows your summary")
                }
                .padding(.horizontal)

                Spacer()
            }
            .tag(1)
        }
        .navigationBarHidden(true)
        .tabViewStyle(PageTabViewStyle())
        .alert("Finish Workout", isPresented: $showingStopConfirmation) {
            Button("Save & Finish") {
                let summary = WorkoutSummary(
                    duration: workoutManager.elapsedTime,
                    distance: workoutManager.totalDistance,
                    avgHeartRate: workoutManager.heartRate,
                    calories: workoutManager.calories,
                    steps: workoutManager.totalSteps,
                    avgPace: workoutManager.currentPace,
                    splitsCount: workoutManager.lastCompletedKm
                )
                workoutManager.saveWorkoutData()
                workoutManager.stopWorkout()
                savedSummary = summary
                showingSummary = true
            }
            Button("Discard", role: .destructive) {
                workoutManager.stopWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this training session?")
        }
    }
}

// MARK: - Workout Summary Data

struct WorkoutSummary {
    let duration: TimeInterval
    let distance: Double
    let avgHeartRate: Int
    let calories: Int
    let steps: Int
    let avgPace: TimeInterval?
    let splitsCount: Int
}

// MARK: - Post-Workout Summary Screen

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)

                Text("Workout Complete")
                    .font(.headline)

                Text(FormattingUtils.formatTimer(summary.duration))
                    .font(.system(.title, design: .monospaced).weight(.bold))
                    .foregroundColor(.primary)

                Divider().padding(.horizontal)

                // Metrics grid
                VStack(spacing: 8) {
                    if summary.distance > 0 {
                        summaryRow(icon: "location.fill", color: .green,
                                   label: "Distance", value: FormattingUtils.formatDistance(summary.distance))
                    }

                    if summary.avgHeartRate > 0 {
                        summaryRow(icon: "heart.fill", color: .red,
                                   label: "Avg Heart Rate", value: "\(summary.avgHeartRate) BPM")
                    }

                    if summary.calories > 0 {
                        summaryRow(icon: "flame.fill", color: .orange,
                                   label: "Calories", value: "\(summary.calories) kcal")
                    }

                    if let pace = summary.avgPace, pace > 0, pace < 3600 {
                        summaryRow(icon: "gauge.with.dots.needle.33percent", color: .purple,
                                   label: "Avg Pace", value: FormattingUtils.formatPace(pace))
                    }

                    if summary.steps > 0 {
                        summaryRow(icon: "shoeprints.fill", color: .blue,
                                   label: "Steps", value: "\(summary.steps)")
                    }

                    if summary.splitsCount > 0 {
                        summaryRow(icon: "flag.fill", color: .green,
                                   label: "Km Splits", value: "\(summary.splitsCount)")
                    }
                }
                .padding(.horizontal)

                Button(action: onDismiss) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
    }

    private func summaryRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Workout Metrics (Vertical Stack with Icons)

struct WorkoutMetricsView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        VStack(spacing: 6) {
            // Distance
            metricRow(
                icon: "location.fill",
                color: .green,
                text: splitDistanceText,
                accessibilityLabel: "Split \(workoutManager.lastCompletedKm), distance \(accessibleDistance)"
            )

            // Heart Rate with zone
            metricRow(
                icon: "heart.fill",
                color: heartRateColor,
                text: heartRateText,
                accessibilityLabel: workoutManager.heartRate > 0
                    ? "\(workoutManager.heartRate) beats per minute, \(heartRateZoneName)"
                    : "Heart rate no data"
            )
            .accessibilityAddTraits(.updatesFrequently)

            // Pace
            metricRow(
                icon: "gauge.with.dots.needle.33percent",
                color: .purple,
                text: paceText,
                accessibilityLabel: accessiblePace
            )
        }
        .padding(.horizontal, 4)
    }

    private func metricRow(icon: String, color: Color, text: String, accessibilityLabel: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            Text(text)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Heart Rate Zone

    private var heartRateZone: Int {
        let hr = workoutManager.heartRate
        if hr <= 0 { return 0 }
        if hr < 104 { return 1 }
        if hr < 125 { return 2 }
        if hr < 146 { return 3 }
        if hr < 167 { return 4 }
        return 5
    }

    private var heartRateZoneName: String {
        switch heartRateZone {
        case 1: return "Zone 1 Easy"
        case 2: return "Zone 2 Fat Burn"
        case 3: return "Zone 3 Cardio"
        case 4: return "Zone 4 Hard"
        case 5: return "Zone 5 Peak"
        default: return ""
        }
    }

    private var heartRateColor: Color {
        switch heartRateZone {
        case 1: return .blue
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .red
        }
    }

    private var heartRateText: String {
        guard workoutManager.heartRate > 0 else { return "-- BPM" }
        return "Z\(heartRateZone) \(workoutManager.heartRate) BPM"
    }

    // MARK: - Distance & Pace

    private var splitDistanceText: String {
        let km = workoutManager.lastCompletedKm
        let dist = workoutManager.totalDistance
        let distStr = FormattingUtils.formatDistance(dist)
        return "\(km) / \(distStr)"
    }

    private var accessibleDistance: String {
        let dist = workoutManager.totalDistance
        if dist < 1.0 {
            return "\(Int(dist * 1000)) meters"
        }
        return String(format: "%.2f kilometers", dist)
    }

    private var paceText: String {
        guard let pace = workoutManager.currentPace else { return "-- Av.Pace" }
        return "\(FormattingUtils.formatPace(pace)) Av.Pace"
    }

    private var accessiblePace: String {
        guard let pace = workoutManager.currentPace else { return "Average pace no data" }
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
            Text(FormattingUtils.formatTimer(workoutManager.elapsedTime))
                .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Elapsed time \(FormattingUtils.formatTimeAccessible(workoutManager.elapsedTime))")
                .accessibilityAddTraits(.updatesFrequently)

            if workoutManager.isPaused {
                Text("PAUSED")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    NavigationStack {
        TrainingView()
            .environmentObject(WatchWorkoutManager())
    }
}
