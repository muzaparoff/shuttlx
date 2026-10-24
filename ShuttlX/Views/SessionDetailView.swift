import SwiftUI
import Charts
import ShuttlXShared

/// Which part of which session the Fix a part sheet edits.
struct FixTarget: Identifiable {
    let sessionID: UUID
    let partID: UUID
    var id: UUID { partID }
}

struct SessionDetailView: View {
    /// Whatever the caller had; the screen reads the EFFECTIVE copy from `DataManager` so edits show at once.
    let session: TrainingSession
    @EnvironmentObject private var dataManager: DataManager
    @State private var fixing: FixTarget?
    @State private var heartRate: HeartRateSeries?
    @AppStorage(SimpleMode.key, store: SimpleMode.store) private var simpleMode = false

    private var current: TrainingSession {
        dataManager.effectiveSessions.first { $0.id == session.id } ?? session
    }

    var body: some View {
        let session = current
        let segments = session.segments
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 20) {
                if let route = session.route, !route.isEmpty {
                    RouteMapView(route: route, segments: segments, kmSplits: session.kmSplits,
                                 showsHeader: false, height: 320)
                }

                titleBlock
                statTrio

                if !segments.isEmpty {
                    VStack(spacing: 10) {
                        ActivityRibbon(segments: segments, height: 16)
                        if let heartRate {
                            HeartRateLine(series: heartRate, start: session.startDate,
                                          end: session.endDate ?? session.startDate.addingTimeInterval(session.duration))
                        }
                    }
                    VStack(spacing: 0) {
                        ForEach(segments) { seg in
                            // Simple mode hides the Fix a part entry point (corrections already made stay applied).
                            if simpleMode {
                                SessionPartRow(segment: seg, showsChevron: false)
                            } else {
                                Button { fixing = FixTarget(sessionID: session.id, partID: seg.id) } label: { SessionPartRow(segment: seg) }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Opens Fix a part")
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .timelineCard()
                }

                SplitsCard(session: session).id("splitsCard")

                // Interval results (if interval workout)
                if let results = session.completedIntervalResults, !results.isEmpty {
                    IntervalResultsView(intervals: results)
                }

                // Metric cards grid
                metricGrid(session)

            }
            .padding()
        }
        #if DEBUG
        // Screenshot seam: SHUTTLX_SCROLL_SPLITS=1 scrolls to the Splits card.
        .task {
            if ProcessInfo.processInfo.environment["SHUTTLX_SCROLL_SPLITS"] == "1" {
                try? await Task.sleep(for: .seconds(1))
                proxy.scrollTo("splitsCard", anchor: .top)
            }
        }
        #endif
        }
        .task(id: session.id) { heartRate = await SessionHeartRateLoader.load(for: session) }
        .sheet(item: $fixing) { target in
            FixPartSheet(sessionID: target.sessionID, partID: target.partID, parts: segments)
        }
        #if DEBUG
        // Screenshot seam: SHUTTLX_DEMO_FIX=<part number> opens "Fix a part" on that part.
        .task {
            if let raw = ProcessInfo.processInfo.environment["SHUTTLX_DEMO_FIX"], let n = Int(raw),
               segments.indices.contains(n - 1) {
                try? await Task.sleep(for: .seconds(1))
                fixing = FixTarget(sessionID: session.id, partID: segments[n - 1].id)
            }
        }
        #endif
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .timelineScreenBackground()
    }

    // MARK: - Title Block

    private var timeRange: String {
        let day = session.startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let end = session.endDate ?? session.startDate.addingTimeInterval(session.duration)
        return "\(day) \u{00B7} \(TodayFormat.clock(session.startDate))\u{2013}\(TodayFormat.clock(end))"
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.timelineName)
                .font(ShuttlXFont.metricMedium)
                .foregroundStyle(ShuttlXColor.textPrimary)
            Text(timeRange)
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(ShuttlXColor.textSecondary)
            if session.importedFromHealth == true {
                Label("From Health", systemImage: "heart.text.square")
                    .font(ShuttlXFont.cardCaption.weight(.medium))
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Big numbers

    private var statTrio: some View {
        HStack(alignment: .top) {
            stat(session.distance.flatMap { $0 > 0 ? FormattingUtils.formatDistance($0, unit: .current) : nil } ?? "–", "Distance")
            stat(FormattingUtils.formatDuration(session.duration), "Time")
            stat(session.averageHeartRate.map { "\(Int($0))" } ?? "–", "Avg BPM")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(ShuttlXFont.metricMedium.monospacedDigit())
                .foregroundStyle(ShuttlXColor.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: - Metric Grid

    private func metricGrid(_ session: TrainingSession) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if let maxHR = session.maxHeartRate {
                MetricCard(
                    icon: "heart.fill",
                    value: "\(Int(maxHR)) BPM",
                    label: "Max Heart Rate",
                    color: ShuttlXColor.heartRate
                )
            }

            if let paused = session.pausedPeakHeartRate, paused > 0 {
                MetricCard(
                    icon: "pause.circle.fill",
                    value: "\(Int(paused)) BPM",
                    label: "Peak while paused",
                    color: ShuttlXColor.heartRate
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Peak heart rate while paused, \(Int(paused)) beats per minute")
            }

            if let cal = session.caloriesBurned {
                MetricCard(
                    icon: "flame.fill",
                    value: "\(Int(cal))",
                    label: "Calories",
                    color: ShuttlXColor.calories
                )
            }

            if let steps = session.totalSteps {
                MetricCard(
                    icon: "shoeprints.fill",
                    value: "\(steps)",
                    label: "Steps",
                    color: ShuttlXColor.steps
                )
            }

            if let cad = session.averageCadence, cad > 0 {
                MetricCard(
                    icon: "figure.run.motion",
                    value: "\(Int(cad.rounded())) spm",
                    label: "Avg Cadence",
                    color: ShuttlXColor.steps
                )
                // Show max only when it materially differs from average — keeps the grid clean.
                if let maxCad = session.maxCadence, maxCad > 0, abs(Double(maxCad) - cad) >= 2 {
                    MetricCard(
                        icon: "figure.run.motion",
                        value: "\(maxCad) spm",
                        label: "Max Cadence",
                        color: ShuttlXColor.steps
                    )
                }
            } else if let maxCad = session.maxCadence, maxCad > 0 {
                // Edge case: very short session with a max but no average.
                MetricCard(
                    icon: "figure.run.motion",
                    value: "\(maxCad) spm",
                    label: "Max Cadence",
                    color: ShuttlXColor.steps
                )
            }

            if let distance = session.distance, distance > 0 {
                MetricCard(
                    icon: "gauge.with.dots.needle.bottom.50percent",
                    value: FormattingUtils.formatPace(session.duration / distance, unit: .current),
                    label: "Avg Pace (\(DistanceUnit.current.paceSuffix))",
                    color: ShuttlXColor.pace
                )
            }

            if let effort = session.effortRPE {
                MetricCard(
                    icon: "gauge.with.needle",
                    value: "Effort \(effort)/10",
                    label: "How hard",
                    color: ShuttlXColor.accentText
                )
            }
        }
    }

}

#Preview {
    NavigationStack {
        SessionDetailView(session: TrainingSession(
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date(),
            duration: 1800,
            averageHeartRate: 145,
            maxHeartRate: 172,
            caloriesBurned: 280,
            distance: 3.2,
            totalSteps: 4200,
            segments: [
                ActivitySegment(activityType: .walking, startDate: Date().addingTimeInterval(-1800), endDate: Date().addingTimeInterval(-1500), averageHeartRate: 118, estimatedCalories: 38, activeEnergyCalories: 42),
                ActivitySegment(activityType: .running, startDate: Date().addingTimeInterval(-1500), endDate: Date().addingTimeInterval(-900), averageHeartRate: 158, estimatedCalories: 165, activeEnergyCalories: 172),
                ActivitySegment(activityType: .walking, startDate: Date().addingTimeInterval(-900), endDate: Date(), averageHeartRate: 121, estimatedCalories: 55, activeEnergyCalories: 68)
            ],
            route: [
                RoutePoint(latitude: 55.7558, longitude: 37.6173, timestamp: Date().addingTimeInterval(-1800)),
                RoutePoint(latitude: 55.7562, longitude: 37.6183, timestamp: Date().addingTimeInterval(-1600)),
                RoutePoint(latitude: 55.7570, longitude: 37.6200, timestamp: Date().addingTimeInterval(-1400)),
                RoutePoint(latitude: 55.7575, longitude: 37.6195, timestamp: Date().addingTimeInterval(-1100)),
                RoutePoint(latitude: 55.7580, longitude: 37.6185, timestamp: Date().addingTimeInterval(-800)),
                RoutePoint(latitude: 55.7585, longitude: 37.6170, timestamp: Date().addingTimeInterval(-500)),
            ],
            kmSplits: nil
        ))
        .environmentObject(DataManager())
    }
}

/// Heart-rate chart under the ribbon: y axis, the user's limit as a dashed line, the part above it shaded,
/// and (only when a limit is in force) a one-line verdict. Samples come from Health (`SessionHeartRateLoader`).
/// ponytail: the verdict counts the ~150 time buckets (averages), so a short spike inside one bucket is not counted.
private struct HeartRateLine: View {
    let series: HeartRateSeries
    let start: Date
    let end: Date
    /// Resolved limit (own or estimated), nil with effort only / no age.
    private let limit: Int? = {
        #if DEBUG
        // Screenshot seam: SHUTTLX_DEMO_LIMIT=<bpm> stands in for a saved limit (the simulator has none).
        if let raw = ProcessInfo.processInfo.environment["SHUTTLX_DEMO_LIMIT"], let v = Int(raw) { return v }
        #endif
        return HeartSafetySettings.load().effectiveUpperLimit(age: DeviceManager.shared.userAge)
    }()

    private var verdict: String? {
        guard let limit, let pct = LimitVerdict.percentUnder(series.points.map(\.bpm), limit: limit) else { return nil }
        return "Under your limit \(pct)% of the time"
    }

    var body: some View {
        let lim = limit.map(Double.init)
        let lo = min((series.points.map(\.bpm).min() ?? 0) - 5, (lim ?? .infinity) - 10)
        let hi = max(series.peak + 5, (lim ?? 0) + 10)
        VStack(alignment: .leading, spacing: 6) {
            if let verdict, let limit {
                Text(verdict)
                    .font(ShuttlXFont.cardTitle.weight(.bold))
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Text("Limit \(limit) bpm \u{00B7} Peak \(Int(series.peak.rounded()))")
                    .font(ShuttlXFont.cardCaption.monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            Chart {
                if let lim {
                    ForEach(series.points) { p in
                        AreaMark(x: .value("Time", p.date), yStart: .value("Limit", lim),
                                 yEnd: .value("BPM", max(p.bpm, lim)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(ShuttlXColor.ctaWarning.opacity(0.3))
                    }
                    RuleMark(y: .value("Limit", lim))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(ShuttlXColor.ctaWarning)
                }
                ForEach(series.points) { p in
                    LineMark(x: .value("Time", p.date), y: .value("BPM", p.bpm))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(ShuttlXColor.heartRate)
                }
            }
            .chartXScale(domain: min(start, end)...max(start, end))   // start > end must not trap
            .chartYScale(domain: lo...hi)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(ShuttlXColor.textSecondary.opacity(0.2))
                    AxisValueLabel().font(ShuttlXFont.cardCaption.monospacedDigit())
                }
            }
            .frame(height: 140)
            HStack {
                Text(TodayFormat.clock(start))
                Spacer()
                Text("Avg \(Int(series.average.rounded())) \u{00B7} Peak \(Int(series.peak.rounded()))")
                Spacer()
                Text(TodayFormat.clock(end))
            }
            .font(ShuttlXFont.cardCaption.monospacedDigit())
            .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate over the session, average \(Int(series.average.rounded())), peak \(Int(series.peak.rounded())) beats per minute"
                            + (limit.map { ". Limit \($0)." + (verdict.map { " \($0)." } ?? "") } ?? ""))
    }
}


/// "Fix a part" (approved mockup): dimmed bottom sheet, four tiles Run / Walk / Cycle / Rest, and the
/// evidence ShuttlX has for the part, a scrubber over the whole session to split the part, and
/// "Merge with next". Every change is stored beside the session (SegmentOverrideStore), never in
/// sessions.json. Rest = `DetectedActivity.stationary`.
struct FixPartSheet: View {
    let sessionID: UUID
    let partID: UUID
    let parts: [ActivitySegment]   // the session's EFFECTIVE parts, in order
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: DataManager
    @ObservedObject private var store = SegmentOverrideStore.shared
    @State private var confirmingReset = false
    /// nil = no tile chosen (the part is `.unknown`, which is not Rest); Save stays off until one is picked.
    @State private var choice: DetectedActivity?
    /// Where the split handle sits inside the part, 0...1 (mockup: starts in the middle).
    @State private var handle: Double

    private let options: [DetectedActivity] = [.running, .walking, .cycling, .stationary]

    init(sessionID: UUID, partID: UUID, parts: [ActivitySegment]) {
        self.sessionID = sessionID
        self.partID = partID
        self.parts = parts
        let seg = parts.first { $0.id == partID }
        _choice = State(initialValue: seg.flatMap { $0.activityType == .unknown ? nil : $0.activityType })
        var h = 0.5
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["SHUTTLX_DEMO_FIX_HANDLE"], let v = Double(raw) { h = v }
        #endif
        _handle = State(initialValue: h)
    }

    private var index: Int? { parts.firstIndex { $0.id == partID } }
    private var segment: ActivitySegment { index.map { parts[$0] } ?? ActivitySegment(activityType: .unknown, startDate: Date()) }
    private var partNumber: Int? { index.map { $0 + 1 } }
    private var partEnd: Date { segment.endDate ?? segment.startDate.addingTimeInterval(segment.duration) }
    private var canSplit: Bool { segment.duration >= 2 * SegmentEdits.minPart }
    private var canMerge: Bool { index.map { $0 + 1 < parts.count } ?? false }

    /// Handle position clamped so both halves keep at least `minPart`.
    private var splitDate: Date {
        let lo = SegmentEdits.minPart / max(segment.duration, 1)
        let f = min(max(handle, lo), 1 - lo)
        return segment.startDate.addingTimeInterval((segment.duration * f).rounded())
    }

    /// The parts as the user sees them now (tile choice included), so Split / Merge keep it.
    private var partsWithChoice: [ActivitySegment] {
        parts.map { var p = $0; if p.id == partID, let choice { p.activityType = choice }; return p }
    }

    /// Save is on only when the choice differs from the part's current effective type.
    private var canSave: Bool {
        guard let choice else { return false }
        return choice != segment.activityType
    }

    /// Recorded (unedited) segment ids of this session, from sessions.json.
    private var rawSegmentIDs: [UUID] { dataManager.sessions.first { $0.id == sessionID }?.segments.map(\.id) ?? [] }
    private var hasEdits: Bool { store.edits.hasEdits(sessionID: sessionID, rawSegmentIDs: rawSegmentIDs) }

    private func split() {
        SegmentOverrideStore.shared.split(partID: partID, at: splitDate, parts: partsWithChoice, sessionID: sessionID)
        dismiss()
    }

    private func merge() {
        SegmentOverrideStore.shared.merge(partID: partID, parts: partsWithChoice, sessionID: sessionID)
        dismiss()
    }

    private var title: String {
        let end = segment.endDate ?? segment.startDate.addingTimeInterval(segment.duration)
        return (partNumber.map { "Part \($0) \u{00B7} " } ?? "")
            + "\(TodayFormat.clock(segment.startDate))\u{2013}\(TodayFormat.clock(end))"
    }

    // MARK: Evidence (only what the segment data really contains)

    private var speedMS: Double? {
        guard let km = segment.distance, km > 0.02, segment.duration > 0 else { return nil }
        return km * 1000 / segment.duration
    }

    private var cadence: Double? {
        guard let steps = segment.steps, steps > 0, segment.duration > 0 else { return nil }
        return Double(steps) / segment.duration * 60
    }

    private var guess: SpeedActivityClassifier.Result? {
        guard let speedMS else { return nil }
        return SpeedActivityClassifier.classifyForReview(speed: speedMS, cadence: cadence, window: segment.duration)
    }

    private var chips: [(text: String, spoken: String)] {
        var out: [(String, String)] = []
        if let km = segment.distance, km > 0.05, segment.duration > 0 {
            let p = FormattingUtils.formatPaceWithUnit(segment.duration / km, unit: .current)
            out.append(("pace \(p)", "pace \(p)"))
        }
        if let hr = segment.averageHeartRate, hr > 0 {
            out.append(("\u{2665} \(Int(hr.rounded())) bpm", "heart rate \(Int(hr.rounded())) beats per minute"))
        }
        if let c = cadence { out.append(("cadence \(Int(c.rounded())) spm", "cadence \(Int(c.rounded())) steps per minute")) }
        if let v = speedMS {
            let t = FormattingUtils.formatSpeed(metersPerSecond: v, unit: .current)
            out.append(("speed \(t)", "speed \(t)"))
        }
        return out
    }

    // MARK: Body

    @Environment(\.dynamicTypeSize) private var typeSize

    private var rowLayout: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
    }

    var body: some View {
        ScrollView {
        VStack(spacing: 16) {
            // At accessibility sizes the title takes its own line so Cancel / Save keep their width.
            let cancelButton = Button("Cancel") { dismiss() }
                .font(ShuttlXFont.cardSubtitle)
                .frame(minWidth: 60, minHeight: 44, alignment: .leading)
            let saveButton = Button("Save") {
                guard let choice, canSave else { return }
                SegmentOverrideStore.shared.setType(choice, partID: partID, parts: parts, sessionID: sessionID)
                dismiss()
            }
                .font(ShuttlXFont.cardSubtitle.weight(.bold))
                .frame(minWidth: 60, minHeight: 44, alignment: .trailing)
                .disabled(!canSave)
                .accessibilityHint(canSave ? "" : "Choose a different type to save")
            let titleText = Text(title)
                .font(ShuttlXFont.cardTitle.weight(.bold).monospacedDigit())
                .foregroundStyle(ShuttlXColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if typeSize.isAccessibilitySize {
                VStack(spacing: 4) {
                    titleText
                    HStack { cancelButton; Spacer(); saveButton }
                        .foregroundStyle(ShuttlXColor.accentText)
                }
            } else {
                HStack { cancelButton; Spacer(); titleText; Spacer(); saveButton }
                    .foregroundStyle(ShuttlXColor.accentText)
            }

            rowLayout {
                ForEach(options, id: \.self) { tile($0) }
            }

            evidence
            scrubber
            actions
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        }
        .scrollBounceBehavior(.basedOnSize)
        #if DEBUG
        // Screenshot seam: SHUTTLX_DEMO_FIX_ACTION=split|merge runs the action 2 s after the sheet opens.
        .task {
            guard let act = ProcessInfo.processInfo.environment["SHUTTLX_DEMO_FIX_ACTION"] else { return }
            try? await Task.sleep(for: .seconds(2))
            if act == "split" { split() } else if act == "merge" { merge() }
            else if act == "rest" {
                SegmentOverrideStore.shared.setType(.stationary, partID: partID, parts: parts, sessionID: sessionID)
                dismiss()
            }
        }
        #endif
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(440), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(.systemBackground))
    }

    // MARK: Scrubber (whole session on one time axis; the handle moves inside the selected part)

    private var scrubber: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let t0 = parts.first?.startDate ?? segment.startDate
            let t1 = parts.last.flatMap { $0.endDate ?? $0.startDate.addingTimeInterval($0.duration) } ?? partEnd
            let total = max(t1.timeIntervalSince(t0), 1)
            let x: (Date) -> CGFloat = { w * CGFloat($0.timeIntervalSince(t0) / total) }
            let hx = x(splitDate)
            ZStack(alignment: .leading) {
                ForEach(partsWithChoice) { p in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(p.activityType.themeColor.opacity(p.id == partID ? 1 : 0.4))
                        .frame(width: max(2, x(p.endDate ?? p.startDate.addingTimeInterval(p.duration)) - x(p.startDate) - 2), height: 16)
                        .offset(x: x(p.startDate), y: 0)
                }
                if canSplit {
                    Capsule().fill(ShuttlXColor.textPrimary)
                        .frame(width: 4, height: 32)
                        .offset(x: hx - 2)
                }
            }
            .frame(height: 32)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                guard canSplit else { return }
                let secs = Double(g.location.x / w) * total + t0.timeIntervalSince1970
                handle = (secs - segment.startDate.timeIntervalSince1970) / max(segment.duration, 1)
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Split point")
            .accessibilityValue(canSplit ? TodayFormat.clock(splitDate) : "Unavailable, part too short")
            .accessibilityHint("Swipe up or down to move the split point")
            .accessibilityAdjustableAction { dir in
                handle += (dir == .increment ? 0.1 : -0.1)
            }
        }
        .frame(height: 32)
        .padding(.vertical, 4)
        .opacity(canSplit ? 1 : 0.5)
    }

    private var actions: some View {
        VStack(spacing: 8) {
        rowLayout {
            actionButton("Split at \(TodayFormat.clock(splitDate))", enabled: canSplit, action: split)
            actionButton("Merge with next", enabled: canMerge, action: merge)
        }
        Button { confirmingReset = true } label: {
            Text("Reset to detected")
                .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                .foregroundStyle(hasEdits ? ShuttlXColor.ctaDestructive : ShuttlXColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(!hasEdits)
        .accessibilityLabel("Reset to detected")
        .accessibilityHint(hasEdits ? "Removes all your corrections to this workout and restores the parts ShuttlX detected"
                                    : "Unavailable, this workout has no corrections")
        .confirmationDialog("Reset this workout to the parts ShuttlX detected?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset to detected", role: .destructive) {
                store.reset(sessionID: sessionID, rawSegmentIDs: rawSegmentIDs)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your type changes, splits and merges for this workout are removed. The recorded workout is not changed.")
        }
        }
    }

    private func actionButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ShuttlXFont.cardSubtitle.weight(.semibold).monospacedDigit())
                .foregroundStyle(ShuttlXColor.accentText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(ShuttlXColor.ctaPrimary.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private func tile(_ a: DetectedActivity) -> some View {
        let on = choice == a
        return Button { choice = a } label: {
            VStack(spacing: 6) {
                Circle().fill(a.themeColor).frame(width: 28, height: 28)
                Text(TodayFormat.activityName(a))
                    .font(ShuttlXFont.cardCaption.weight(.semibold))
                    .foregroundStyle(ShuttlXColor.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(on ? ShuttlXColor.ctaPrimary : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TodayFormat.activityName(a) + (on ? ", selected" : ""))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder
    private var evidence: some View {
        let items = chips
        if guess != nil || !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if let guess {
                    (guess.confidence == .high
                        ? Text("ShuttlX thinks: \(TodayFormat.activityName(guess.activity))").fontWeight(.bold)
                            .foregroundStyle(ShuttlXColor.textPrimary)
                            + Text(" \u{00B7} high confidence. Why:")
                        : Text("ShuttlX is not sure.").fontWeight(.bold)
                            .foregroundStyle(ShuttlXColor.textPrimary)
                            + Text(" What it measured:"))
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                } else {
                    Text("Measured in this part:")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
                EvidenceFlow(spacing: 6) {
                    ForEach(items, id: \.text) { c in
                        Text(c.text)
                            .font(ShuttlXFont.cardCaption.monospacedDigit())
                            .foregroundStyle(ShuttlXColor.textPrimary)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                            .accessibilityLabel(c.spoken)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        }
    }
}

/// Minimal wrapping row layout for the evidence chips.
private struct EvidenceFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = arrange(bounds.width, subviews)
        for (i, p) in r.origins.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        var origins: [CGPoint] = []
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += s.width + spacing; rowH = max(rowH, s.height); maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowH), origins)
    }
}


/// Splits from the stored `kmSplits` (the watch saves them whether or not a route exists). Km as stored; miles are
/// interpolated from them. Hidden when the session has none (for example an iPhone-only workout).
private struct SplitsCard: View {
    let session: TrainingSession

    var body: some View {
        let unit = DistanceUnit.current
        let rows = FormattingUtils.splitRows(splitTimes: (session.kmSplits ?? []).sorted { $0.kmNumber < $1.kmNumber }.map(\.splitTime),
                                             totalKm: session.distance, totalDuration: session.duration, unit: unit)
        if !rows.isEmpty {
            let full = rows.filter { !$0.isPartial }.map(\.pace)
            let fastest = full.min() ?? rows.map(\.pace).min() ?? 1
            let slowest = full.max() ?? fastest
            VStack(alignment: .leading, spacing: 8) {
                Text("Splits")
                    .font(ShuttlXFont.sectionHeader)
                ForEach(rows, id: \.number) { row in
                    let pace = FormattingUtils.formatPaceWithUnit(row.pace / unit.km, unit: unit)
                    let label = row.isPartial ? String(format: "%.2f", row.distance) : "\(unit.symbol.uppercased()) \(row.number)"
                    HStack(spacing: 10) {
                        Text(row.isPartial ? "\(label) \(unit.symbol)" : label)
                            .font(ShuttlXFont.cardCaption.weight(.semibold))
                            .frame(width: 58, alignment: .leading)
                        Text(FormattingUtils.formatTimer(row.time))
                            .font(ShuttlXFont.cardSubtitle.monospacedDigit())
                            .frame(width: 52, alignment: .leading)
                        GeometryReader { geo in
                            // Faster pace = longer bar, scaled between the slowest and fastest whole split.
                            let span = max(slowest - fastest, 1)
                            let ratio = row.isPartial ? 0.3 : 1 - 0.7 * min(1, max(0, (row.pace - fastest) / span))
                            Capsule().fill(row.isPartial ? ShuttlXColor.textSecondary.opacity(0.35) : ShuttlXColor.running)
                                .frame(width: geo.size.width * ratio, height: 6)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 14)
                        Text(pace)
                            .font(ShuttlXFont.cardCaption.monospacedDigit())
                            .foregroundStyle(ShuttlXColor.textSecondary)
                            .frame(width: 76, alignment: .trailing)
                    }
                    .foregroundStyle(row.isPartial ? ShuttlXColor.textSecondary : ShuttlXColor.textPrimary)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(row.isPartial
                        ? "Last \(String(format: "%.2f", row.distance)) \(unit.name)s, \(FormattingUtils.formatTimeAccessible(row.time)), pace \(FormattingUtils.formatPace(row.pace / unit.km, unit: unit)) per \(unit.name)"
                        : "\(unit.name.capitalized) \(row.number), \(FormattingUtils.formatTimeAccessible(row.time)), pace \(FormattingUtils.formatPace(row.pace / unit.km, unit: unit)) per \(unit.name)")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .timelineCard()
        }
    }
}
