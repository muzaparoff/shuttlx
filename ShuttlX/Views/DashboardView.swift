import SwiftUI
import ShuttlXShared

private let dismissedPartsKey = "timeline.partsBannerDismissed"

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var workoutController: iPhoneWorkoutController
    @ObservedObject var sharedData = PhoneSyncCoordinator.shared
    @ObservedObject private var importer = HealthKitImporter.shared
    @EnvironmentObject var deepLinkRouter: DeepLinkRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var themeManager
    @State private var showingPrograms = false
    @AppStorage(SimpleMode.key, store: SimpleMode.store) private var simpleMode = false
    @State private var confirmStart = false
    @State private var startFailed = false
    @State private var noHeartLimit = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedDay = Date()
    /// The calendar day "today" meant when this view last looked; used to roll `selectedDay` over at midnight.
    @State private var shownDay = Calendar.current.startOfDay(for: Date())
    @State private var dismissedParts = Set(UserDefaults.standard.stringArray(forKey: dismissedPartsKey) ?? [])
    @State private var pickingPartFor: TrainingSession?
    @State private var fixing: FixTarget?
    #if DEBUG
    @State private var seamFired = false
    #endif

    private var daySessions: [TrainingSession] {
        dataManager.effectiveSessions
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDay) }
            .sorted { $0.startDate < $1.startDate }
    }

    private var isLive: Bool { sharedData.isWorkoutActiveOnWatch }
    private var showEmpty: Bool { dataManager.effectiveSessions.isEmpty && !isLive }

    private func consumePendingPrograms() {
        guard deepLinkRouter.showPrograms else { return }
        deepLinkRouter.showPrograms = false
        showingPrograms = true
    }

    private var subtitle: String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        let date = f.string(from: selectedDay)
        if isLive { return "\(date) \u{00B7} workout \(sharedData.liveIsPaused ? "paused" : "running")" }
        let n = daySessions.count
        return "\(date) \u{00B7} \(n) \(n == 1 ? "session" : "sessions")"
    }

    /// Re-read on appear and when the app returns to the foreground (the limit is edited in Settings).
    private func refreshLimitWarning() {
        noHeartLimit = HeartSafetySettings.load().hasNoLimit(age: DeviceManager.shared.userAge)
    }

    private var limitWarning: some View {
        Button { deepLinkRouter.pendingTab = 3 } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ShuttlXColor.ctaWarning)
                    .accessibilityHidden(true)
                Text("No heart limit set. The watch will not warn you.")
                    .font(ShuttlXFont.cardCaption.weight(.semibold))
                    .foregroundStyle(ShuttlXColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text("Set").font(ShuttlXFont.cardCaption.weight(.bold)).foregroundStyle(ShuttlXColor.accentText)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(ShuttlXColor.ctaWarning.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("No heart limit set. The watch will not warn you about a high heart rate.")
        .accessibilityHint("Opens Settings, where you can set a limit")
    }

    private var programsRow: some View {
        Button { showingPrograms = true } label: {
            HStack {
                Label("Programs & plans", systemImage: "calendar.badge.clock")
                    .font(ShuttlXFont.cardSubtitle)
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .timelineCard()
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityHint("Run/Walk, mixed programs and training plans")
    }

    private func stat(_ value: String, _ unit: String?, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(ShuttlXFont.metricLarge.monospacedDigit())
                if let unit { Text(unit).font(ShuttlXFont.cardCaption.weight(.semibold)).foregroundStyle(ShuttlXColor.textSecondary) }
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(ShuttlXFont.microLabel).foregroundStyle(ShuttlXColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value) \(unit ?? "")")
    }

    private var statsRow: some View {
        let km = daySessions.compactMap(\.distance).reduce(0, +)
        let secs = daySessions.reduce(0) { $0 + $1.duration }
        let cal = daySessions.compactMap(\.caloriesBurned).reduce(0, +)
        let minutes = Int(secs / 60)
        return HStack(alignment: .top, spacing: 20) {
            stat(FormattingUtils.formatDistanceValue(km, unit: .current), DistanceUnit.current.symbol, "distance")
            stat(String(format: "%d:%02d", minutes / 60, minutes % 60), nil, "active")
            stat("\(Int(cal))", "cal", "energy")
            Spacer(minLength: 0)
        }
    }

    /// Simple mode: three big tiles for the selected day (time, distance, heart).
    private var simpleTiles: some View {
        let km = daySessions.compactMap(\.distance).reduce(0, +)
        let secs = daySessions.reduce(0) { $0 + $1.duration }
        let hrs = daySessions.compactMap(\.averageHeartRate).filter { $0 > 0 }
        let hr = hrs.isEmpty ? nil : Int(hrs.reduce(0, +) / Double(hrs.count))
        return VStack(spacing: 12) {
            SimpleTile(icon: "clock", label: "Time", value: secs > 0 ? TodayFormat.short(secs) : "\u{2014}")
            SimpleTile(icon: "figure.walk", label: "Distance", value: km > 0 ? FormattingUtils.formatDistance(km, unit: .current) : "\u{2014}")
            SimpleTile(icon: "heart.fill", label: "Heart", value: hr.map { "\($0) bpm" } ?? "\u{2014}")
        }
    }

    private func startCard(showOthers: Bool = true) -> some View {
        TodayStartCard(showOthers: showOthers, onStart: { confirmStart = true }, onOthers: { showingPrograms = true })
    }

    /// Same path as the widget links: ask first, then remote-start on the watch (services.md, "Starting from a URL needs a confirmation").
    private func startOnWatch() {
        if !PhoneSyncCoordinator.shared.startWatchWorkout(mode: "freeRun") { startFailed = true }
    }

    private var bannerSession: TrainingSession? {
        daySessions.first { $0.segments.count >= 2 && !dismissedParts.contains($0.id.uuidString) }
    }

    /// After midnight the day that was "today" is yesterday: move the selection along unless the user picked another day.
    private func rollOverDay() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today != shownDay else { return }
        if Calendar.current.isDate(selectedDay, inSameDayAs: shownDay) { selectedDay = Date() }
        shownDay = today
    }

    private func dismissBanner(_ s: TrainingSession) {
        dismissedParts.insert(s.id.uuidString)
        UserDefaults.standard.set(Array(dismissedParts), forKey: dismissedPartsKey)
    }

    @ViewBuilder
    private var dataContent: some View {
        statsRow
        TodayWeekStrip(sessions: dataManager.effectiveSessions, selected: $selectedDay)
        if let s = bannerSession {
            PartsFoundBanner(session: s, segments: s.segments,
                             onLooksRight: { dismissBanner(s) },
                             onFix: { pickingPartFor = s })
        }
        if daySessions.isEmpty {
            Text("No workouts on this day")
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(ShuttlXColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 12) {
                ForEach(daySessions) { TimelineSessionRow(session: $0) }
            }
        }
    }

    @ViewBuilder
    private var liveContent: some View {
        LiveWorkoutCard(sharedData: sharedData)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
        if sharedData.liveRoutePoints.count >= 2 {
            LiveRouteView(routePoints: sharedData.liveRoutePoints, compact: true)
                .transition(.opacity)
        }
        let earlier = Array(dataManager.effectiveSessions.sorted { $0.startDate > $1.startDate }.prefix(3))
        if !earlier.isEmpty {
            Text("Earlier")
                .font(ShuttlXFont.microLabel).textCase(.uppercase)
                .foregroundStyle(ShuttlXColor.textSecondary)
                .padding(.horizontal, 14).padding(.top, 4)
            ForEach(earlier) { EarlierRow(session: $0) }
        }
    }

    var body: some View {
        let _ = themeManager.current.id   // re-render on theme switch
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if noHeartLimit { limitWarning }
                    if showEmpty {
                        TodayEmptyState(importer: importer)
                            .containerRelativeFrame(.vertical) { h, _ in h * 0.5 }
                        startCard(showOthers: false)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today")
                                .font(ShuttlXFont.metricLarge)
                                .foregroundStyle(ShuttlXColor.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Text(subtitle)
                                .font(ShuttlXFont.cardSubtitle)
                                .foregroundStyle(ShuttlXColor.textSecondary)
                        }
                        if isLive {
                            if simpleMode { LiveWorkoutCard(sharedData: sharedData) } else { liveContent }
                        } else {
                            startCard()
                            if simpleMode { simpleTiles } else { dataContent }
                        }
                        if !simpleMode { programsRow.padding(.top, 8) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .safeAreaInset(edge: .bottom) {
                if showEmpty { programsRow.padding(.horizontal, 16).padding(.bottom, 8) }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingPrograms) { ProgramsTabView() }
            .task { consumePendingPrograms() }
            .alert("Start Run/Walk?", isPresented: $confirmStart) {
                Button("Start") { startOnWatch() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This starts the workout on your Apple Watch.") }
            .alert("Could not reach your watch", isPresented: $startFailed) {
                Button("OK", role: .cancel) {}
            } message: { Text("Check that your Apple Watch is nearby and try again.") }
            .onAppear {
                refreshLimitWarning()
                #if DEBUG
                if let v = ProcessInfo.processInfo.environment["SHUTTLX_SIMPLE_MODE"] { simpleMode = (v == "1") }   // screenshot seam
                #endif
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active { refreshLimitWarning(); rollOverDay() } }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in rollOverDay() }
            #if DEBUG
            // Screenshot seam: SHUTTLX_DEMO_FIX_TODAY=<part number> opens Fix a part on that part of the banner session.
            .task(id: dataManager.effectiveVersion) {
                guard !seamFired, fixing == nil, let n = ProcessInfo.processInfo.environment["SHUTTLX_DEMO_FIX_TODAY"].flatMap(Int.init),
                      let s = bannerSession, s.segments.indices.contains(n - 1) else { return }
                try? await Task.sleep(for: .seconds(1))
                seamFired = true
                fixing = FixTarget(sessionID: s.id, partID: s.segments[n - 1].id)
            }
            #endif
            .onChange(of: deepLinkRouter.showPrograms) { consumePendingPrograms() }
            .confirmationDialog("Fix a part", isPresented: Binding(get: { pickingPartFor != nil }, set: { if !$0 { pickingPartFor = nil } }), titleVisibility: .visible) {
                if let s = pickingPartFor {
                    ForEach(s.segments) { seg in
                        Button("\(TodayFormat.activityName(seg.activityType)) \u{00B7} \(TodayFormat.clock(seg.startDate)) \u{00B7} \(TodayFormat.short(seg.duration))") {
                            fixing = FixTarget(sessionID: s.id, partID: seg.id)
                        }
                    }
                }
            }
            .sheet(item: $fixing) { target in
                FixPartSheet(sessionID: target.sessionID, partID: target.partID,
                             parts: dataManager.effectiveSessions.first { $0.id == target.sessionID }?.segments ?? [])
            }
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: isLive)
            .timelineScreenBackground()
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager())
        .environmentObject(DeepLinkRouter())
        .environmentObject(iPhoneWorkoutController())
        .environment(ThemeManager.shared)
}
