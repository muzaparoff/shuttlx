import SwiftUI
import ShuttlXShared

private let dismissedPartsKey = "timeline.partsBannerDismissed"

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var workoutController: iPhoneWorkoutController
    @ObservedObject var sharedData = PhoneSyncCoordinator.shared
    @ObservedObject private var importer = HealthKitImporter.shared
    @ObservedObject private var overrides = SegmentOverrideStore.shared
    @EnvironmentObject var deepLinkRouter: DeepLinkRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var themeManager
    @State private var showingPrograms = false
    @State private var selectedDay = Date()
    @State private var dismissedParts = Set(UserDefaults.standard.stringArray(forKey: dismissedPartsKey) ?? [])
    @State private var pickingPartFor: TrainingSession?
    @State private var fixing: ActivitySegment?

    private var daySessions: [TrainingSession] {
        dataManager.sessions
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDay) }
            .sorted { $0.startDate < $1.startDate }
    }

    private var isLive: Bool { sharedData.isWorkoutActiveOnWatch }
    private var showEmpty: Bool { dataManager.sessions.isEmpty && !isLive }

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
        .accessibilityHint("Interval workouts and training plans")
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
            stat(String(format: "%.1f", km), "km", "distance")
            stat(String(format: "%d:%02d", minutes / 60, minutes % 60), nil, "active")
            stat("\(Int(cal))", "cal", "energy")
            Spacer(minLength: 0)
        }
    }

    private var bannerSession: TrainingSession? {
        daySessions.first { $0.segments.count >= 2 && !dismissedParts.contains($0.id.uuidString) }
    }

    private func dismissBanner(_ s: TrainingSession) {
        dismissedParts.insert(s.id.uuidString)
        UserDefaults.standard.set(Array(dismissedParts), forKey: dismissedPartsKey)
    }

    @ViewBuilder
    private var dataContent: some View {
        statsRow
        TodayWeekStrip(sessions: dataManager.sessions, selected: $selectedDay)
        if let s = bannerSession {
            let segs = overrides.applying(to: s.segments)
            PartsFoundBanner(session: s, segments: segs,
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
        let earlier = Array(dataManager.sessions.sorted { $0.startDate > $1.startDate }.prefix(3))
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
                    if showEmpty {
                        TodayEmptyState(importer: importer)
                            .containerRelativeFrame(.vertical) { h, _ in h * 0.7 }
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
                        if isLive { liveContent } else { dataContent }
                        programsRow.padding(.top, 8)
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
            .onChange(of: deepLinkRouter.showPrograms) { consumePendingPrograms() }
            .confirmationDialog("Fix a part", isPresented: Binding(get: { pickingPartFor != nil }, set: { if !$0 { pickingPartFor = nil } }), titleVisibility: .visible) {
                if let s = pickingPartFor {
                    ForEach(overrides.applying(to: s.segments)) { seg in
                        Button("\(TodayFormat.activityName(seg.activityType)) \u{00B7} \(TodayFormat.clock(seg.startDate)) \u{00B7} \(TodayFormat.short(seg.duration))") { fixing = seg }
                    }
                }
            }
            .sheet(item: $fixing) { seg in
                // The dialog clears `pickingPartFor` when it dismisses, so find the part's session by id.
                let parts = dataManager.sessions.first { $0.segments.contains { $0.id == seg.id } }?.segments ?? []
                FixPartSheet(segment: seg, partNumber: parts.firstIndex { $0.id == seg.id }.map { $0 + 1 }) {
                    overrides.set($0, for: seg)
                }
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
