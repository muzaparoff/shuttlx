import SwiftUI
import os.log
import RevenueCat
import TelemetryDeck

@main
struct ShuttlXApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var themeManager = ThemeManager.shared
    @StateObject private var dataManager = DataManager()
    @StateObject private var sharedDataManager = PhoneSyncCoordinator.shared
    @StateObject private var templateManager = TemplateManager()
    @StateObject private var planManager = PlanManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var cloudKitSync = CloudKitSyncManager.shared
    @StateObject private var workoutController = iPhoneWorkoutController()
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @State private var deepLinkSessionID: UUID?

    private let subscriptionManager = SubscriptionManager.shared

    init() {
        subscriptionManager.configure()

        let telemetryConfig = TelemetryDeck.Config(appID: "2323535F-7F18-45F3-ACA2-215164CD22BC")
        TelemetryDeck.initialize(config: telemetryConfig)
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let snapshot = ProcessInfo.processInfo.environment["SHUTTLX_SNAPSHOT"] {
                snapshotRoot(theme: snapshot)
            } else {
                appRoot
            }
            #else
            appRoot
            #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                dataManager.loadSessionsFromAppGroup()
                sharedDataManager.reconcileWithDataManager()
                sharedDataManager.reconcileSessionIDs()
                if authManager.isSignedIn {
                    cloudKitSync.performFullSync(dataManager: dataManager)
                }
                Task {
                    await subscriptionManager.refreshEntitlementStatus()
                }
                // ActivityKit only allows STARTING a Live Activity while the
                // app is foreground ("Target is not foreground" otherwise —
                // verified 2026-07-25). If a Watch workout is running and the
                // Live Activity couldn't start earlier (workout began while
                // this app was backgrounded), start it now. Conversely, if
                // nothing is running anywhere, sweep up any orphaned activity.
                if sharedDataManager.isWorkoutActiveOnWatch {
                    LiveActivityManager.shared.startActivity(
                        activityType: sharedDataManager.liveCurrentActivity
                    )
                } else if !workoutController.isActive {
                    LiveActivityManager.shared.cleanupStaleActivities()
                }
            }
        }
    }

    #if DEBUG
    /// Snapshot harness: renders a single theme's workout timer hero at true
    /// device size with representative mock data, so `simctl io screenshot`
    /// captures the genuine SwiftUI output. Activated only via the
    /// `SHUTTLX_SNAPSHOT=<themeID>` launch environment variable.
    @ViewBuilder
    private func snapshotRoot(theme: String) -> some View {
        let controller = workoutController
        iPhoneWorkoutTimerView(controller: controller)
            .environment(themeManager)
            .environmentObject(dataManager)
            .task {
                themeManager.selectTheme(theme)
                controller.applyPreviewSnapshot()
            }
    }
    #endif

    @ViewBuilder
    private var appRoot: some View {
            Group {
                if isFirstLaunch {
                    OnboardingView(isFirstLaunch: $isFirstLaunch)
                } else {
                    ContentView(deepLinkSessionID: $deepLinkSessionID)
                }
            }
            .environment(themeManager)
            .environmentObject(dataManager)
            .environmentObject(sharedDataManager)
            .environmentObject(templateManager)
            .environmentObject(planManager)
            .environmentObject(authManager)
            .environmentObject(cloudKitSync)
            .environmentObject(workoutController)
            // Present the iPhone workout timer over whatever's on screen when
            // any entry-point view calls `controller.presentFreeRun()` /
            // `presentInterval(template:)` / `presentGymRecovery()`. The
            // controller's tearDown() flips this back to false on Finish /
            // Cancel, dismissing the cover.
            .fullScreenCover(isPresented: $workoutController.isPresentingTimer) {
                iPhoneWorkoutTimerView(controller: workoutController)
                    .environment(themeManager)
                    .environmentObject(dataManager)
            }
            .task {
                // Wire the controller's DataManager dependency once at startup.
                // The controller saves finished sessions via
                // DataManager.handleReceivedSessions(_:) — same store the
                // watch writes to.
                workoutController.dataManager = dataManager
                // Mirror watch stops back to the iPhone: when the user stops
                // on the Watch, the paired iPhone workout stops and saves too.
                PhoneSyncCoordinator.shared.onRemoteWorkoutStopped = { [weak workoutController] in
                    workoutController?.remoteStop()
                }
                #if DEBUG
                // Test hooks (simulator automation): SHUTTLX_AUTOSTART_WATCH
                // remote-starts a free run on the Watch after N seconds;
                // SHUTTLX_AUTOSTOP_WATCH stops it after N seconds — both drive
                // the exact code paths the UI buttons use.
                if let raw = ProcessInfo.processInfo.environment["SHUTTLX_AUTOSTART_WATCH"],
                   let secs = Double(raw) {
                    try? await Task.sleep(for: .seconds(secs))
                    PhoneSyncCoordinator.shared.startWatchWorkout(mode: "freeRun")
                }
                if let raw = ProcessInfo.processInfo.environment["SHUTTLX_AUTOSTOP_WATCH"],
                   let secs = Double(raw) {
                    try? await Task.sleep(for: .seconds(secs))
                    sharedDataManager.stopWatchWorkout()
                    sharedDataManager.clearLiveWorkoutState()
                }
                #endif
            }
            .onOpenURL { url in
                os_log(.info, log: OSLog(subsystem: "com.shuttlx.ShuttlX", category: "DeepLink"),
                       "onOpenURL fired: %{public}@", url.absoluteString)
                guard url.scheme == "shuttlx" else { return }
                switch url.host {
                case "session":
                    // shuttlx://session/{UUID} — opens session detail
                    if let idString = url.pathComponents.last,
                       let uuid = UUID(uuidString: idString) {
                        deepLinkSessionID = uuid
                    }
                case "workout":
                    // shuttlx://workout/active — Live Activity tap. If an
                    // iPhone-driven workout is running, raise the timer cover.
                    // If the watch is driving the workout, the app just comes
                    // to the foreground (the user can read the LiveWorkoutCard
                    // on the dashboard). In neither case do we start a new
                    // workout — the deep link is observational only.
                    if workoutController.isActive {
                        workoutController.isPresentingTimer = true
                    }
                #if DEBUG
                case "debug-stop-watch":
                    // Test hook: drives the exact same code path as the
                    // LiveWorkoutCard "End Workout" confirmation button, so the
                    // remote-stop flow can be exercised from simctl openurl.
                    sharedDataManager.stopWatchWorkout()
                    sharedDataManager.clearLiveWorkoutState()
                case "debug-start-watch":
                    // Test hook: remote-starts a free run on the Watch.
                    PhoneSyncCoordinator.shared.startWatchWorkout(mode: "freeRun")
                #endif
                default:
                    break
                }
            }
    }
}
