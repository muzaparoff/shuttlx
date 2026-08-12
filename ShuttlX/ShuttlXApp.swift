import SwiftUI
import os.log
import ShuttlXShared
import RevenueCat
import TelemetryDeck
import WatchConnectivity

/// Holds deep-link state that must survive a cold launch — the app's
/// `onOpenURL` handler can fire before `ContentView` has mounted, and a
/// plain `@State` + `.onChange` pair on the receiving view never fires in
/// that case (the value is already set by the time `.onChange` starts
/// observing). Consumers (`ContentView`) read the pending values from
/// `.task`/`.onAppear` on mount *and* observe changes, so a value set before
/// or after mount is handled identically.
@MainActor
final class DeepLinkRouter: ObservableObject {
    /// Set by `shuttlx://session/{uuid}`. Cleared only once the matching
    /// session is found and presented — if `DataManager.sessions` hasn't
    /// loaded yet, the id is left in place so it can be retried when
    /// sessions finish loading (never silently dropped).
    @Published var pendingSessionID: UUID?
    /// Set by `shuttlx://dashboard` to select the Training tab.
    @Published var pendingTab: Int?
}

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
    @StateObject private var deepLinkRouter = DeepLinkRouter()
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true

    private let subscriptionManager = SubscriptionManager.shared
    private let deepLinkLog = OSLog(subsystem: "com.shuttlx.ShuttlX", category: "DeepLink")

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
            #if DEBUG
            // Screenshot seam runs are hermetic: no disk reloads, no sync
            // reconciliation, no CloudKit — the seeded demo data must not be
            // disturbed and the real user data must not be touched.
            if screenshotSeamsActive { return }
            #endif
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

    // MARK: - Screenshot seams (marketing captures)
    //
    // Sibling of the SHUTTLX_SNAPSHOT harness above, for the full app UI
    // rather than the timer hero:
    //
    //   SHUTTLX_DEMO_DATA=1   seeds ~12 plausible completed sessions across
    //                         the last 3 weeks IN MEMORY ONLY (DataManager
    //                         demo mode blocks every disk read/write), so
    //                         Training/History/Analytics photograph well
    //                         without touching the real sessions.json.
    //   SHUTTLX_TAB=<name>    selects a tab at launch:
    //                         training|programs|history|analytics|settings.
    //   SHUTTLX_SHOW_PLANS=1  additionally auto-pushes the Training Plans
    //                         list (the four built-in plans) — the seam
    //                         itself lives in ProgramsTabView.
    //   SHUTTLX_HISTORY_MODE=<day|week|month>  pre-selects the History
    //                         period segment — the seam itself lives in
    //                         TrainingHistoryView.
    //
    // Both also bypass onboarding on a fresh install so the tabs are
    // actually reachable. Launch via `SIMCTL_CHILD_SHUTTLX_DEMO_DATA=1
    // SIMCTL_CHILD_SHUTTLX_TAB=history xcrun simctl launch ...`.

    private var demoDataRequested: Bool {
        ProcessInfo.processInfo.environment["SHUTTLX_DEMO_DATA"] == "1"
    }

    private var launchTabRequest: Int? {
        switch ProcessInfo.processInfo.environment["SHUTTLX_TAB"] {
        case "training":  return 0
        case "programs":  return 1
        case "history":   return 2
        case "analytics": return 3
        case "settings":  return 4
        default:          return nil
        }
    }

    private var screenshotSeamsActive: Bool {
        demoDataRequested || launchTabRequest != nil
            || ProcessInfo.processInfo.environment["SHUTTLX_SHOW_PLANS"] == "1"
    }
    #endif

    /// True when the onboarding flow should be shown instead of the tabs.
    /// Screenshot seam runs skip onboarding even on a fresh install.
    private var showOnboarding: Bool {
        #if DEBUG
        return isFirstLaunch && !screenshotSeamsActive
        #else
        return isFirstLaunch
        #endif
    }

    @ViewBuilder
    private var appRoot: some View {
            Group {
                if showOnboarding {
                    OnboardingView(isFirstLaunch: $isFirstLaunch)
                } else {
                    ContentView()
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
            .environmentObject(deepLinkRouter)
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
                // Screenshot seams (see the MARK above): seed demo sessions
                // and/or select a launch tab.
                if demoDataRequested {
                    dataManager.activateDemoMode(sessions: ShuttlXDemoData.makeSessions())
                }
                if let tab = launchTabRequest {
                    deepLinkRouter.pendingTab = tab
                }
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
                os_log(.info, log: deepLinkLog, "onOpenURL fired: %{public}@", url.absoluteString)
                guard url.scheme == "shuttlx" else { return }
                switch url.host {
                case "session":
                    // shuttlx://session/{UUID} — opens session detail
                    if let idString = url.pathComponents.last,
                       let uuid = UUID(uuidString: idString) {
                        os_log(.info, log: deepLinkLog, "session: routing to session %{public}@", idString)
                        deepLinkRouter.pendingSessionID = uuid
                    } else {
                        os_log(.error, log: deepLinkLog, "session: no valid UUID in path — ignored")
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
                case "dashboard":
                    // shuttlx://dashboard — select the Training tab.
                    os_log(.info, log: deepLinkLog, "dashboard: selecting Training tab")
                    deepLinkRouter.pendingTab = 0
                case "start-template":
                    // shuttlx://start-template/{templateUUID} — widget tap.
                    // Resolve the template and remote-start it on the Watch.
                    // If the template can't be resolved, we still opened the
                    // app (the deep link's minimum guarantee) and simply skip
                    // the remote start.
                    if let idString = url.pathComponents.last,
                       let uuid = UUID(uuidString: idString) {
                        if let template = templateManager.templates.first(where: { $0.id == uuid }) {
                            os_log(.info, log: deepLinkLog, "start-template: starting %{public}@", idString)
                            startWatchWorkoutWithRetry(mode: "interval", template: template)
                        } else {
                            os_log(.error, log: deepLinkLog,
                                   "start-template: template %{public}@ not found — opening app only", idString)
                        }
                    } else {
                        os_log(.error, log: deepLinkLog, "start-template: no valid UUID in path — ignored")
                    }
                case "start-freerun":
                    // shuttlx://start-freerun — widget/control tap.
                    os_log(.info, log: deepLinkLog, "start-freerun: starting free run")
                    startWatchWorkoutWithRetry(mode: "freeRun")
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

    /// Remote-starts a Watch workout from a deep link, tolerating cold
    /// launch: `WCSession` may not have finished `activate()` yet when
    /// `onOpenURL` fires this early in app lifecycle, and
    /// `PhoneSyncCoordinator.startWatchWorkout` itself no-ops (with a log)
    /// if the session isn't activated. Rather than silently dropping the
    /// widget tap, poll activation state briefly before giving up.
    private func startWatchWorkoutWithRetry(mode: String, template: WorkoutTemplate? = nil) {
        Task {
            let maxAttempts = 5
            for attempt in 1...maxAttempts {
                if WCSession.default.activationState == .activated {
                    PhoneSyncCoordinator.shared.startWatchWorkout(mode: mode, template: template)
                    return
                }
                os_log(.info, log: deepLinkLog,
                       "startWatchWorkoutWithRetry: WCSession not activated, attempt %d/%d (mode=%{public}@)",
                       attempt, maxAttempts, mode)
                if attempt < maxAttempts {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            os_log(.error, log: deepLinkLog,
                   "startWatchWorkoutWithRetry: WCSession never activated after %d attempts — dropping request (mode=%{public}@)",
                   maxAttempts, mode)
        }
    }
}

#if DEBUG
// MARK: - Demo Data (screenshot seam)

/// Deterministic, plausible completed sessions for marketing screenshots.
/// Seeded only via `SHUTTLX_DEMO_DATA=1` (see the screenshot-seams MARK in
/// `ShuttlXApp`) and held in memory only — `DataManager` demo mode blocks all
/// disk persistence, so the real user's sessions.json is never touched.
enum ShuttlXDemoData {
    /// ~12 completed run/walk sessions spread across the last 3 weeks with
    /// varied durations (20–45 min), distances, and heart rates. All values
    /// are deterministic so re-captures produce identical screenshots.
    static func makeSessions(now: Date = Date()) -> [TrainingSession] {
        // (daysAgo, startHour, minutes, avgHR, runMin, walkMin, displayName?)
        //
        // Deliberately periodized: the last 7 days are a light recovery week
        // and the two weeks before are heavy, so AnalyticsEngine's
        // form = fitness − fatigue comes out clearly positive and the
        // Recovery Status card photographs as "Fresh", not "Needs rest".
        let specs: [(days: Int, hour: Int, minutes: Int, avgHR: Double, run: Int, walk: Int, name: String?)] = [
            (1,  8, 34, 143, 5, 2, "Run 5 / Walk 2"),
            (5, 18, 24, 139, 3, 3, "Easy Run/Walk"),
            (8,  9, 38, 150, 6, 2, nil),
            (9, 17, 30, 146, 5, 2, "Run 5 / Walk 2"),
            (11, 8, 42, 149, 8, 3, nil),
            (12, 12, 28, 155, 4, 1, "HIIT Intervals"),
            (14, 18, 26, 141, 3, 2, "Run 3 / Walk 2"),
            (15, 7, 45, 148, 8, 3, nil),
            (16, 12, 34, 152, 5, 2, "Run 5 / Walk 2"),
            (18, 9, 35, 151, 6, 2, "Tempo Intervals"),
            (19, 17, 29, 144, 4, 2, nil),
            (20, 8, 40, 147, 6, 3, "Run 6 / Walk 3"),
        ]

        let calendar = Calendar.current
        return specs.enumerated().map { index, spec in
            let day = calendar.date(byAdding: .day, value: -spec.days, to: now) ?? now
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = spec.hour
            comps.minute = (12 + index * 7) % 50
            let start = calendar.date(from: comps) ?? day
            let duration = TimeInterval(spec.minutes * 60)
            let end = start.addingTimeInterval(duration)

            // Pace scales gently with intensity: harder sessions are faster.
            let paceSecPerKm = 430.0 - (spec.avgHR - 135.0) * 4.0   // ~5'40"–6'50"/km
            let distanceKm = ((duration / paceSecPerKm) * 100).rounded() / 100

            // Alternate run/walk segments through the whole session.
            var segments: [ActivitySegment] = []
            var cursor = start
            var isRun = true
            while cursor < end {
                let segEnd = min(cursor.addingTimeInterval(TimeInterval((isRun ? spec.run : spec.walk) * 60)), end)
                let segDuration = segEnd.timeIntervalSince(cursor)
                segments.append(ActivitySegment(
                    activityType: isRun ? .running : .walking,
                    startDate: cursor,
                    endDate: segEnd,
                    steps: Int((isRun ? 168.0 : 118.0) * segDuration / 60),
                    distance: distanceKm * (segDuration / duration) * (isRun ? 1.15 : 0.8)
                ))
                cursor = segEnd
                isRun.toggle()
            }

            var session = TrainingSession(
                startDate: start,
                endDate: end,
                duration: duration,
                averageHeartRate: spec.avgHR,
                maxHeartRate: spec.avgHR + 21,
                caloriesBurned: (duration / 60 * 10.4).rounded(),
                distance: distanceKm,
                totalSteps: segments.compactMap { $0.steps }.reduce(0, +),
                segments: segments,
                kmSplits: splits(distanceKm: distanceKm, paceSecPerKm: paceSecPerKm),
                averageCadence: 158 + Double(index % 5) * 3,
                maxCadence: 176 + (index % 4) * 2
            )
            session.sportType = .running
            session.programName = spec.name
            return session
        }
    }

    private static func splits(distanceKm: Double, paceSecPerKm: Double) -> [KmSplitData]? {
        let fullKms = Int(distanceKm)
        guard fullKms >= 1 else { return nil }
        var cumulative: TimeInterval = 0
        return (1...fullKms).map { km in
            // Small deterministic wobble so the splits chart isn't flat.
            let split = paceSecPerKm + Double((km * 13) % 7) * 4.0 - 12.0
            cumulative += split
            return KmSplitData(kmNumber: km, splitTime: split, cumulativeTime: cumulative)
        }
    }
}
#endif
