import SwiftUI
import ShuttlXShared

struct SessionDetailView: View {
    let session: TrainingSession
    @ObservedObject private var overrides = SegmentOverrideStore.shared
    @State private var fixing: ActivitySegment?

    var body: some View {
        let segments = overrides.applying(to: session.segments)
        ScrollView {
            VStack(spacing: 20) {
                if let route = session.route, !route.isEmpty {
                    RouteMapView(route: route, segments: session.segments, kmSplits: session.kmSplits,
                                 showsHeader: false, height: 320)
                }

                titleBlock
                statTrio

                if !session.segments.isEmpty {
                    ActivityRibbon(segments: segments, height: 16)
                    VStack(spacing: 0) {
                        ForEach(segments) { seg in
                            Button { fixing = seg } label: { SessionPartRow(segment: seg) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens Fix a part")
                        }
                    }
                    .padding(.vertical, 6)
                    .timelineCard()
                }

                // Interval results (if interval workout)
                if let results = session.completedIntervalResults, !results.isEmpty {
                    IntervalResultsView(intervals: results)
                }

                // Metric cards grid
                metricGrid

            }
            .padding()
        }
        .sheet(item: $fixing) { seg in
            FixPartSheet(segment: seg, partNumber: segments.firstIndex { $0.id == seg.id }.map { $0 + 1 }) {
                overrides.set($0, for: seg)
            }
        }
        #if DEBUG
        // Screenshot seam: SHUTTLX_DEMO_FIX=<part number> opens "Fix a part" on that part.
        .task {
            if let raw = ProcessInfo.processInfo.environment["SHUTTLX_DEMO_FIX"], let n = Int(raw),
               segments.indices.contains(n - 1) {
                try? await Task.sleep(for: .seconds(1))
                fixing = segments[n - 1]
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
            stat(session.distance.flatMap { $0 > 0 ? FormattingUtils.formatDistance($0) : nil } ?? "–", "Distance")
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

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if let maxHR = session.maxHeartRate {
                MetricCard(
                    icon: "heart.fill",
                    value: "\(Int(maxHR)) BPM",
                    label: "Max Heart Rate",
                    color: ShuttlXColor.heartRate
                )
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
                    value: FormattingUtils.formatPace(session.duration / distance),
                    label: "Avg Pace",
                    color: ShuttlXColor.pace
                )
            }

            if let effort = session.effortRPE {
                MetricCard(
                    icon: "gauge.with.needle",
                    value: "Effort \(effort)/10",
                    label: "How hard",
                    color: ShuttlXColor.ctaPrimary
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
    }
}


/// "Fix a part" (approved mockup): dimmed bottom sheet, four tiles Run / Walk / Cycle / Rest, and the
/// evidence ShuttlX has for the part. The correction is stored beside the session
/// (SegmentOverrideStore), never in sessions.json. Rest = `DetectedActivity.stationary`.
/// Not built (see wave 2a report): "Merge with next" (needs a sessions.json rewrite) and the scrubber.
struct FixPartSheet: View {
    let segment: ActivitySegment   // already shows the effective type
    var partNumber: Int?
    let onSave: (DetectedActivity) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var choice: DetectedActivity

    private let options: [DetectedActivity] = [.running, .walking, .cycling, .stationary]

    init(segment: ActivitySegment, partNumber: Int? = nil, onSave: @escaping (DetectedActivity) -> Void) {
        self.segment = segment
        self.partNumber = partNumber
        self.onSave = onSave
        _choice = State(initialValue: segment.activityType == .unknown ? .stationary : segment.activityType)
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
        return SpeedActivityClassifier.classify(speed: speedMS, cadence: cadence, window: segment.duration)
    }

    private var chips: [(text: String, spoken: String)] {
        var out: [(String, String)] = []
        if let km = segment.distance, km > 0.05, segment.duration > 0 {
            let p = FormattingUtils.formatPace(segment.duration / km) + "/km"
            out.append(("pace \(p)", "pace \(p)"))
        }
        if let hr = segment.averageHeartRate, hr > 0 {
            out.append(("\u{2665} \(Int(hr.rounded())) bpm", "heart rate \(Int(hr.rounded())) beats per minute"))
        }
        if let c = cadence { out.append(("cadence \(Int(c.rounded())) spm", "cadence \(Int(c.rounded())) steps per minute")) }
        if let v = speedMS {
            let t = String(format: "%.1f km/h", v * 3.6)
            out.append(("speed \(t)", "speed \(t)"))
        }
        return out
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(ShuttlXFont.cardSubtitle)
                    .frame(minWidth: 60, minHeight: 44, alignment: .leading)
                Spacer()
                Text(title)
                    .font(ShuttlXFont.cardTitle.weight(.bold).monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Save") { onSave(choice); dismiss() }
                    .font(ShuttlXFont.cardSubtitle.weight(.bold))
                    .frame(minWidth: 60, minHeight: 44, alignment: .trailing)
            }
            .foregroundStyle(ShuttlXColor.ctaPrimary)

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { tile($0) }
            }

            evidence
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .presentationDetents([.height(340), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(.systemBackground))
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
                    (Text("ShuttlX thinks: \(TodayFormat.activityName(guess.activity))").fontWeight(.bold)
                        .foregroundStyle(ShuttlXColor.textPrimary)
                     + Text(" \u{00B7} \(guess.confidence == .high ? "high" : "low") confidence. Why:"))
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
