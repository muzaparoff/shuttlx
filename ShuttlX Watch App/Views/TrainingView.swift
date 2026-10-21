import SwiftUI
#if os(watchOS)
import WatchKit
import ShuttlXShared
#endif

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State var selectedTab = 0
    @State var showingStopConfirmation = false
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
    /// Full height of a free-run page: from the tag line to the screen bottom. The
    /// running page pins itself to it; a stack shorter than the TabView floated to
    /// the centre (no HR: no zone word or bar).
    @State var pageHeight: CGFloat?
    #if os(watchOS)
    let screenHeight = WKInterfaceDevice.current().screenBounds.height
    let screenWidth = WKInterfaceDevice.current().screenBounds.width
    #else
    let screenHeight: CGFloat = 224
    let screenWidth: CGFloat = 198
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

            // Free run: running page -> (swipe left) distance/pace/calories -> controls.
            // Interval + gym recovery: their own main page -> controls.
            TabView(selection: $selectedTab) {
                workoutDisplayTab
                    .tag(0)

                if isFreeRunLayout {
                    freeRunMetricsPage
                        .tag(1)
                    controlsTab
                        .tag(2)
                } else {
                    controlsTab
                        .tag(1)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The TabView sits inside the safe area (40mm: y40-178 of 197) and centres
            // each page. A page this tall, centred there, ends at the screen bottom —
            // where the page-dot inset is measured from.
            .onGeometryChange(for: CGFloat.self, of: { 2 * (screenHeight - $0.frame(in: .global).midY) }) {
                pageHeight = $0
            }
            // VoiceOver must not reach the workout behind a prompt card.
            .accessibilityHidden(overlayShowing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Long-workout safety prompt sits above both tabs and swallows touches.
        // An overlay (not fullScreenCover) so no system close button can dismiss
        // it without an answer.
        .overlay {
            if workoutManager.safetyPromptVisible {
                SafetyPromptView(
                    onContinue: { workoutManager.continueAfterSafetyPrompt() },
                    onEndAndSave: { workoutManager.finishAndSave() }
                )
            } else if let unusual = workoutManager.unusualHeartRate {
                UnusualHeartRateView(
                    bpm: unusual.bpm, rise: unusual.rise,
                    onOK: { workoutManager.dismissUnusualHeartRate() },
                    onPause: {
                        workoutManager.pauseWorkout()
                        workoutManager.dismissUnusualHeartRate()
                    }
                )
            } else if workoutManager.isPaused, workoutManager.autoPauseReason != nil {
                AutoPausedView(
                    seconds: WatchSyncCoordinator.shared.heartSafety.noMotionSeconds,
                    onResume: { workoutManager.resumeWorkout() },
                    onEndAndSave: { workoutManager.finishAndSave() }
                )
            }
        }
        // HR haptic for the "Ease off" banner — on the root so every layout gets it.
        .onChange(of: workoutManager.heartRate) { _, newHR in
            let isHigh = isHighHR(newHR)
            if isHigh && !highIntensityHapticFired {
                highIntensityHapticFired = true
                #if os(watchOS)
                WKInterfaceDevice.current().play(.notification)
                #endif
            } else if !isHigh {
                highIntensityHapticFired = false
            }
        }
        .onChange(of: workoutManager.lastCompletedKm) { _, _ in
            guard !reduceMotion else { return }
            kmSplitFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                kmSplitFlash = false
            }
        }
        #if DEBUG
        .onAppear {
            if let tab = ProcessInfo.processInfo.environment["SHUTTLX_SNAPSHOT_TAB"].flatMap(Int.init) {
                selectedTab = tab
            }
        }
        #endif
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
        // A Health save failure is shown on WorkoutSummaryView ("Not saved to
        // Health"): it is reported after the summary has replaced this view.
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
        } else if isFreeRunLayout {
            runningPage
        } else {
            fullWorkoutDisplayTab
        }
    }

    var isFreeRunLayout: Bool { workoutManager.workoutMode == .freeRun }

    /// Same conditions as the `.overlay` above.
    private var overlayShowing: Bool {
        workoutManager.safetyPromptVisible || workoutManager.unusualHeartRate != nil
            || (workoutManager.isPaused && workoutManager.autoPauseReason != nil)
    }

}
