import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var selectedTab = 0
    @State private var showingSaveConfirmation = false
    @State private var showingErrorMessage = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode // Added for redundant dismissal
    @State private var shouldDismiss = false // Flag to trigger dismissal

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Main Timer View
            VStack(spacing: 0) {
                // Current interval indicator at the top with clear visibility
                if let program = workoutManager.currentProgram,
                   let currentInterval = workoutManager.currentInterval {

                    // Phase indicator (Run/Walk) at the very top
                    CurrentPhaseView(
                        programType: program.type,
                        currentInterval: currentInterval,
                        workLabel: program.type.workPhaseLabel,
                        restLabel: program.type.restPhaseLabel
                    )
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }

                Spacer(minLength: 0)

                // Large Apple-style timer with consistent monospaced digits
                AppleStyleTimerView()

                Spacer(minLength: 0)

                // Metrics grid with consistent styling
                MetricsGridView()

                // Emergency exit button for when other dismiss methods fail
                if shouldDismiss {
                    Button("Return to Home") {
                        forceDismiss()
                    }
                    .foregroundColor(.accentColor)
                    .padding(.bottom, 5)
                    .accessibilityLabel("Return to Home")
                    .accessibilityHint("Ends the current workout and returns to the program list")
                }
            }
            .tag(0)

            // Tab 2: Full Controls View
            VStack(spacing: 16) {
                Text("Workout Controls")
                    .font(.system(size: 16, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                // Main control buttons with clear labels
                VStack(spacing: 20) {
                    Button(action: {
                        if workoutManager.isWorkoutActive {
                            workoutManager.pauseWorkout()
                        } else {
                            workoutManager.resumeWorkout()
                        }
                    }) {
                        HStack {
                            Image(systemName: workoutManager.isWorkoutActive ? "pause.fill" : "play.fill")
                            Text(workoutManager.isWorkoutActive ? "Pause" : "Resume")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(workoutManager.isWorkoutActive ? .orange : .green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                        )
                    }
                    .accessibilityLabel(workoutManager.isWorkoutActive ? "Pause workout" : "Resume workout")
                    .accessibilityHint(workoutManager.isWorkoutActive ? "Pauses the current workout" : "Resumes the paused workout")

                    Button(action: {
                        showingSaveConfirmation = true
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
                    .accessibilityHint("Ends the workout and prompts to save")

                    // Emergency exit button when all other dismissal methods fail
                    if shouldDismiss {
                        Button("Return to Home") {
                            forceDismiss()
                        }
                        .foregroundColor(.accentColor)
                        .accessibilityLabel("Return to Home")
                        .accessibilityHint("Force returns to the program list")
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Training progress information
                if let program = workoutManager.currentProgram {
                    VStack(spacing: 8) {
                        Text("Program: \(program.name)")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        // Use program.intervals.count instead of totalIntervals
                        Text("Interval \(workoutManager.currentIntervalIndex + 1)/\(program.intervals.count)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Program \(program.name), interval \(workoutManager.currentIntervalIndex + 1) of \(program.intervals.count)")
                }
            }
            .tag(1)
        }
        .navigationTitle(workoutManager.currentProgram?.name ?? "Training")
        .navigationBarTitleDisplayMode(.inline)
        .tabViewStyle(PageTabViewStyle())
        .alert("End Training", isPresented: $showingSaveConfirmation) {
            Button(role: .destructive, action: {
                // Save data first (this always works even without HealthKit)
                workoutManager.saveWorkoutData()

                // End the workout (does not throw)
                workoutManager.stopWorkout()

                // Use multiple dismiss techniques to ensure we exit
                forceDismiss()
            }) {
                Text("End & Save")
            }

            Button(role: .cancel, action: {
                // Just dismiss without saving
                forceDismiss()
            }) {
                Text("Cancel")
            }
        } message: {
            Text("Do you want to save this training session?")
        }
        .alert("Error", isPresented: $showingErrorMessage) {
            Button("OK") {
                // Always dismiss view after error
                forceDismiss()
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Enable emergency exit after a delay if something goes wrong
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                shouldDismiss = true
            }
        }
    }

    // Force dismissal using multiple techniques to ensure it works
    private func forceDismiss() {
        // First try the SwiftUI dismissal
        dismiss()

        // Also try presentation mode dismissal as fallback
        presentationMode.wrappedValue.dismiss()

        // Add a small delay and try again in case the first attempt doesn't work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
            presentationMode.wrappedValue.dismiss()

            // Set state variables that might prevent dismissal
            workoutManager.isWorkoutActive = false

            // Try one more time after another delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct CurrentPhaseView: View {
    let programType: ProgramType
    let currentInterval: TrainingInterval
    let workLabel: String
    let restLabel: String
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    private var phaseLabel: String {
        currentInterval.phase == .work ? workLabel : restLabel
    }

    private var phaseColor: Color {
        currentInterval.phase == .work ? .green : .orange
    }

    private var phaseIcon: String {
        currentInterval.phase == .work ? "figure.run" : "figure.walk"
    }

    var body: some View {
        VStack(spacing: 2) {
            // Phase indicator with icon and label
            HStack(spacing: 6) {
                Image(systemName: phaseIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(phaseColor)

                Text(phaseLabel.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(phaseColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)

            // Intensity and elapsed time info
            HStack {
                Text(currentInterval.intensity.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                // Show elapsed workout time using the new public property
                Text("Total: \(formatElapsedTime(workoutManager.elapsedWorkoutTime))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phaseLabel) phase, \(currentInterval.intensity.rawValue) intensity, total time \(formatElapsedTime(workoutManager.elapsedWorkoutTime))")
    }

    private func formatElapsedTime(_ elapsed: TimeInterval) -> String {
        let minutes = Int(elapsed / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct AppleStyleTimerView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        ZStack {
            // Circular progress ring - background
            Circle()
                .stroke(lineWidth: 12)
                .opacity(0.3)
                .foregroundColor(Color.secondary)

            // Progress indicator - fills as time counts down
            Circle()
                .trim(from: 0.0, to: progressFraction)
                .stroke(style: StrokeStyle(
                    lineWidth: 12,
                    lineCap: .round
                ))
                .foregroundColor(ringColor)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear(duration: 0.3), value: progressFraction)

            // Timer and interval information
            VStack(spacing: 4) {
                // Large, bold digital timer in the center
                Text(formatTime(workoutManager.timeRemaining))
                    .font(.system(size: 54, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Time remaining \(formatTimeAccessible(workoutManager.timeRemaining))")
                    .accessibilityAddTraits(.updatesFrequently)

                // Interval information below timer
                if let program = workoutManager.currentProgram {
                    VStack(spacing: 2) {
                        // Current interval number
                        Text("Interval \(workoutManager.currentIntervalIndex + 1)/\(program.intervals.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Interval \(workoutManager.currentIntervalIndex + 1) of \(program.intervals.count)")

                        // Next interval preview if available
                        if workoutManager.currentIntervalIndex + 1 < program.intervals.count {
                            let nextInterval = program.intervals[workoutManager.currentIntervalIndex + 1]
                            let nextPhaseLabel = nextInterval.phase == .work ?
                                program.type.workPhaseLabel : program.type.restPhaseLabel

                            HStack(spacing: 4) {
                                Image(systemName: nextInterval.phase == .work ? "figure.run" : "figure.walk")
                                    .font(.system(size: 10))

                                Text("Next: \(nextPhaseLabel) \(formatTime(nextInterval.duration))")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Next interval: \(nextPhaseLabel), \(formatTimeAccessible(nextInterval.duration))")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .contain)
    }

    // Calculate progress fraction for the ring (0.0 to 1.0)
    private var progressFraction: CGFloat {
        guard let currentInterval = workoutManager.currentInterval else { return 0 }
        let totalDuration = currentInterval.duration
        let remaining = workoutManager.timeRemaining

        // Ensure we don't divide by zero
        guard totalDuration > 0 else { return 0 }

        // Calculate how much of the interval has completed (0.0 - 1.0)
        return CGFloat(1.0 - (remaining / totalDuration))
    }

    // Dynamic color based on current phase
    private var ringColor: Color {
        guard let currentInterval = workoutManager.currentInterval else { return .accentColor }
        return currentInterval.phase == .work ? .green : .orange
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval / 60)
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatTimeAccessible(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval / 60)
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        if minutes > 0 {
            return "\(minutes) minutes \(seconds) seconds"
        } else {
            return "\(seconds) seconds"
        }
    }
}

struct MetricsGridView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        HStack(spacing: 12) {
            MetricView(
                value: workoutManager.heartRate > 0 ? "\(workoutManager.heartRate)" : "--",
                unit: "BPM",
                icon: "heart.fill",
                color: .red
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Heart rate")
            .accessibilityValue(workoutManager.heartRate > 0 ? "\(workoutManager.heartRate) beats per minute" : "no data")

            MetricView(
                value: "\(workoutManager.calories)",
                unit: "CAL",
                icon: "flame.fill",
                color: .orange
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Calories burned")
            .accessibilityValue("\(workoutManager.calories) calories")
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

// Note: We're removing the old WorkoutControlsView since its functionality is now integrated directly in the tabs

#Preview {
    NavigationView {
        TrainingView()
            .environmentObject(WatchWorkoutManager())
    }
}
