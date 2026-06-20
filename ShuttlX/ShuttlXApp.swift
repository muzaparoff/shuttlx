import SwiftUI
import RevenueCat
import TelemetryDeck

@main
struct ShuttlXApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var themeManager = ThemeManager.shared
    @StateObject private var dataManager = DataManager()
    @StateObject private var sharedDataManager = SharedDataManager.shared
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
            }
            .onOpenURL { url in
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
                default:
                    break
                }
            }
    }
}
