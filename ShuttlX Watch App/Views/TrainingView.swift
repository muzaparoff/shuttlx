import SwiftUI
#if os(watchOS)
import WatchKit
import ShuttlXShared
#endif

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State var selectedTab = 0
    @State var showingStopConfirmation = false
    @State var showingHealthKitError = false
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
        // Summary is now shown by ContentView when workoutManager.pendingSummary != nil,
        // which is set BEFORE stopWorkout() (so isWorkoutActive is already false when
        // ContentView reads it — S-1 fix). TrainingView only ever shows the workout UI.
        workoutTabView
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
                // S-1 fix: build summary and set pendingSummary BEFORE stopWorkout().
                // stopWorkout() zeros all @Published state (elapsedTime, HR, distance…)
                // and sets isWorkoutActive = false, which causes ContentView to swap out
                // TrainingView. pendingSummary being non-nil tells ContentView to show
                // WorkoutSummaryView instead of StartTrainingView.
                workoutManager.saveWorkoutData()
                workoutManager.pendingSummary = workoutManager.buildCurrentSummary()
                workoutManager.stopWorkout()
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
