import SwiftUI
#if os(watchOS)
import WatchKit
import ShuttlXShared
#endif

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State var selectedTab = 0
    @State var showingStopConfirmation = false
    @State var showingSummary = false
    @State var showingHealthKitError = false
    @State var savedSummary: WorkoutSummary?
    @State var pausePulse = false
    @State var showingAuthDeniedAlert = false
    /// Tracks whether the high-intensity warning haptic has already fired this threshold crossing.
    @State var highIntensityHapticFired = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(ThemeManager.self) var themeManager

    @State var hrCalculator = HeartRateZoneCalculator.fromSharedDefaults()
    /// Drives the brief DIST flash on every km-split milestone.
    @State var kmSplitFlash = false
    #if os(watchOS)
    let screenHeight = WKInterfaceDevice.current().screenBounds.height
    #else
    let screenHeight: CGFloat = 224
    #endif

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
        ZStack {
            // Background sits behind the TabView as a non-interactive layer.
            // drawingGroup() was previously used here but it prevents dynamic
            // theme switching mid-workout and is unnecessary now that engine
            // objectWillChange forwarding was removed (that was the real source
            // of 3-6x/sec background re-renders).
            Color.clear
                .themedScreenBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            TabView(selection: $selectedTab) {
                // Tab 1: Full-screen stacked metrics
                workoutDisplayTab
                    .tag(0)

                // Tab 2: Controls
                controlsTab
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarHidden(true)
        .alert("Finish Workout", isPresented: $showingStopConfirmation) {
            Button("Save & Finish") {
                let captures = workoutManager.completedCaptures
                let avgHRR1: Double? = {
                    let vals = captures.compactMap { $0.hrr1 }
                    guard !vals.isEmpty else { return nil }
                    return Double(vals.reduce(0, +)) / Double(vals.count)
                }()
                let summary = WorkoutSummary(
                    duration: workoutManager.elapsedTime,
                    distance: workoutManager.totalDistance,
                    avgHeartRate: workoutManager.averageHeartRate,
                    calories: workoutManager.calories,
                    steps: workoutManager.totalSteps,
                    avgPace: workoutManager.currentPace,
                    splitsCount: workoutManager.lastCompletedKm,
                    completedSets: workoutManager.workoutMode == .gymRecovery ? captures.count : nil,
                    averageHRR1: avgHRR1
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
        .alert("Health App Save Failed", isPresented: $showingHealthKitError) {
            Button("OK", role: .cancel) {
                workoutManager.healthKitSaveError = nil
            }
        } message: {
            Text(workoutManager.healthKitSaveError ?? "The workout was saved in ShuttlX but could not be written to the Health app.")
        }
        .onChange(of: workoutManager.healthKitSaveError) { _, newValue in
            showingHealthKitError = newValue != nil
        }
        .alert("Health Access Required", isPresented: Binding(
            get: { showingAuthDeniedAlert },
            set: { showingAuthDeniedAlert = $0 }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("ShuttlX needs Health access to record your workout. Open the Health app or iPhone Settings to grant permission.")
        }
        .onChange(of: workoutManager.authorizationDenied) { _, isDenied in
            if isDenied {
                showingAuthDeniedAlert = true
            }
        }
    }

    // MARK: - Workout Display Tab (Full-Screen Stacked Metrics)

    @ViewBuilder
    private var workoutDisplayTab: some View {
        if isLuminanceReduced {
            aodMinimalView
        } else if workoutManager.workoutMode == .gymRecovery {
            RecoveryWorkoutView()
                .environmentObject(workoutManager)
        } else {
            fullWorkoutDisplayTab
        }
    }

}
