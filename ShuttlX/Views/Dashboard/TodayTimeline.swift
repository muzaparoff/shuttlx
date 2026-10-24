import SwiftUI
import MapKit
import os.log
import ShuttlXShared

// Building blocks of the Today timeline (approved mockup, 2026-10).

// MARK: - Session helpers

extension TrainingSession {
    /// Parts to draw: the segments (already effective when the session comes from `DataManager.effectiveSessions`),
    /// or one synthetic part for the whole session.
    func displaySegments() -> [ActivitySegment] {
        if !segments.isEmpty { return segments }
        let activity: DetectedActivity = sportType == .cycling ? .cycling : sportType == .walking ? .walking : .running
        return [ActivitySegment(activityType: activity, startDate: startDate,
                                endDate: endDate ?? startDate.addingTimeInterval(duration))]
    }

    /// "Morning" / "Afternoon" / "Evening" by start hour ("Evening ride" for cycling).
    var timelineName: String {
        let h = Calendar.current.component(.hour, from: startDate)
        let part = h < 5 ? "Night" : h < 12 ? "Morning" : h < 17 ? "Afternoon" : h < 22 ? "Evening" : "Night"
        return sportType == .cycling ? part + " ride" : part
    }
}

enum TodayFormat {
    static func short(_ s: TimeInterval) -> String {
        let m = Int((s / 60).rounded())
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }

    static func clock(_ d: Date) -> String {
        // Follows the system 12/24-hour setting.
        d.formatted(date: .omitted, time: .shortened)
    }

    static func activityName(_ a: DetectedActivity) -> String {
        switch a {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycle"
        case .stationary, .unknown: return "Rest"
        }
    }

    /// "Run + Walk": distinct activities, longest first.
    static func activitySummary(_ segs: [ActivitySegment]) -> String {
        var totals: [DetectedActivity: TimeInterval] = [:]
        for s in segs { totals[s.activityType, default: 0] += s.duration }
        return totals.sorted { $0.value > $1.value }.map { activityName($0.key) }.joined(separator: " + ")
    }

    static func dominantActivity(_ segs: [ActivitySegment]) -> DetectedActivity? {
        var totals: [DetectedActivity: TimeInterval] = [:]
        for s in segs { totals[s.activityType, default: 0] += s.duration }
        return totals.max { $0.value < $1.value }?.key
    }

    static func dominantColor(_ segs: [ActivitySegment]) -> Color? {
        var totals: [DetectedActivity: TimeInterval] = [:]
        for s in segs { totals[s.activityType, default: 0] += s.duration }
        return totals.max { $0.value < $1.value }?.key.themeColor
    }

    static func meta(_ session: TrainingSession, _ segs: [ActivitySegment]) -> String {
        var parts: [String] = []
        if let km = session.distance, km > 0 { parts.append(FormattingUtils.formatDistance(km, unit: .current)) }
        if let hr = session.averageHeartRate, hr > 0 { parts.append("\(Int(hr)) bpm") }
        parts.append(activitySummary(segs))
        return parts.joined(separator: " · ")
    }
}

// MARK: - Week strip

struct TodayWeekStrip: View {
    let sessions: [TrainingSession]
    @Binding var selected: Date

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2   // Monday, as in the mockup
        return c
    }

    private var days: [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        HStack {
            ForEach(days, id: \.self) { day in
                let daySessions = sessions.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
                let segs = daySessions.flatMap { $0.displaySegments() }
                let isSelected = calendar.isDate(day, inSameDayAs: selected)
                Button { selected = day } label: {
                    VStack(spacing: 4) {
                        Text(calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day) - 1])
                            .font(ShuttlXFont.microLabel)
                            .foregroundStyle(ShuttlXColor.textSecondary)
                        Circle()
                            .fill(TodayFormat.dominantColor(segs) ?? Color(.tertiarySystemFill))
                            .frame(width: 20, height: 20)
                            .overlay {   // glyph so Run / Walk is never told by colour alone
                                if let a = TodayFormat.dominantActivity(segs) {
                                    Image(systemName: a.systemImage).font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(ShuttlXColor.iconOnCTA).accessibilityHidden(true)
                                }
                            }
                            .overlay(Circle().strokeBorder(ShuttlXColor.textPrimary, lineWidth: 1.5).padding(-4).opacity(isSelected ? 1 : 0))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day()) + ", \(daySessions.count) sessions" + (isSelected ? ", selected" : ""))
            }
        }
    }
}

// MARK: - "Found N parts" banner

struct PartsFoundBanner: View {
    let session: TrainingSession
    let segments: [ActivitySegment]
    let onLooksRight: () -> Void
    let onFix: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ShuttlX found \(segments.count) parts in \(session.timelineName)")
                .font(ShuttlXFont.cardSubtitle.weight(.bold))
                .foregroundStyle(ShuttlXColor.textPrimary)
            Text(segments.map { "\(TodayFormat.activityName($0.activityType)) \(TodayFormat.short($0.duration))" }
                .joined(separator: " \u{00B7} ") + ". Right?")
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textPrimary.opacity(0.7))
            let looksRight = Button("Looks right", action: onLooksRight)
                .font(ShuttlXFont.cardCaption.weight(.semibold))
                .foregroundStyle(ShuttlXColor.iconOnCTA)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .background(ShuttlXColor.ctaPrimary, in: Capsule())
            let fix = Button("Fix a part", action: onFix)
                .font(ShuttlXFont.cardCaption.weight(.semibold))
                .foregroundStyle(ShuttlXColor.accentText)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .background(ShuttlXColor.ctaPrimary.opacity(0.12), in: Capsule())
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { looksRight; fix }
                VStack(alignment: .leading, spacing: 8) { looksRight; fix }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(ShuttlXColor.ctaPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Timeline row

struct TimelineSessionRow: View {
    let session: TrainingSession

    var body: some View {
        let segs = session.displaySegments()
        let total = max(1, segs.reduce(0) { $0 + max(0, $1.duration) })
        HStack(alignment: .top, spacing: 8) {
            Text(TodayFormat.clock(session.startDate))
                .font(ShuttlXFont.microLabel.monospacedDigit())
                .foregroundStyle(ShuttlXColor.textSecondary)
                .frame(width: 36, alignment: .trailing)
                .padding(.top, 12)
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(stops: railStops(segs, total: total), startPoint: .top, endPoint: .bottom))
                .frame(width: 4)
                .padding(.top, 4)
            NavigationLink(destination: SessionDetailView(session: session)) {
                card(segs)
            }
            .buttonStyle(PressScaleButtonStyle())
        }
    }

    private func railStops(_ segs: [ActivitySegment], total: TimeInterval) -> [Gradient.Stop] {
        var stops: [Gradient.Stop] = []
        var at = 0.0
        for s in segs {
            let next = at + max(0, s.duration) / total
            stops.append(.init(color: s.activityType.themeColor, location: at))
            stops.append(.init(color: s.activityType.themeColor, location: next))
            at = next
        }
        return stops
    }

    private func card(_ segs: [ActivitySegment]) -> some View {
        let meta = TodayFormat.meta(session, segs)
        return VStack(spacing: 0) {
            if let route = session.route, route.count >= 2 {
                RouteThumbnail(session: session, segments: segs)
                    .frame(height: 82)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.timelineName)
                        .font(ShuttlXFont.cardTitle.weight(.bold))
                        .foregroundStyle(ShuttlXColor.textPrimary)
                    Spacer(minLength: 8)
                    Text(TodayFormat.short(session.duration))
                        .font(ShuttlXFont.cardCaption.monospacedDigit())
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
                ActivityRibbon(segments: segs, height: 14)
                Text(meta)
                    .font(ShuttlXFont.cardCaption.monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            .padding(.init(top: 10, leading: 13, bottom: 12, trailing: 13))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .timelineCard(radius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.timelineName), \(TodayFormat.short(session.duration)), \(meta)")
        .accessibilityHint("Opens session details")
    }
}

// MARK: - Route thumbnail (MKMapSnapshotter, cached)

struct RouteThumbnail: View {
    let session: TrainingSession
    let segments: [ActivitySegment]
    var size: CGSize = RouteSnapshotCache.wide
    @Environment(\.colorScheme) private var scheme
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(.tertiarySystemFill)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .task(id: "\(session.id)-\(scheme == .dark)-\(size.width)-\(segments.map(\.activityType.rawValue))") {
            image = await RouteSnapshotCache.image(for: session, segments: segments, dark: scheme == .dark, size: size)
        }
        .accessibilityHidden(true)
    }
}

@MainActor
enum RouteSnapshotCache {
    private static let cache = NSCache<NSString, UIImage>()
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "RouteSnapshot")
    static let wide = CGSize(width: 300, height: 82)
    static let square = CGSize(width: 92, height: 92)

    static func image(for session: TrainingSession, segments: [ActivitySegment], dark: Bool,
                      size: CGSize = wide) async -> UIImage? {
        let key = "\(session.id)-\(dark)-\(size.width)-\(segments.map(\.activityType.rawValue))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let route = session.route, route.count >= 2 else { return nil }
        // Thumbnails don't need more than ~150 points.
        let step = max(1, route.count / 150)
        let pts = route.enumerated().filter { $0.offset % step == 0 || $0.offset == route.count - 1 }.map(\.element)
        let coords = pts.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        var rect = MKMapRect.null
        for c in coords { rect = rect.union(MKMapRect(origin: MKMapPoint(c), size: MKMapSize(width: 0, height: 0))) }
        let aspect = size.width / size.height
        let w = max(rect.width * 1.3, rect.height * 1.3 * aspect, 3000)
        let h = w / aspect
        let fitted = MKMapRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)

        let options = MKMapSnapshotter.Options()
        options.mapRect = fitted
        options.size = size
        options.scale = 3
        options.traitCollection = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        options.showsBuildings = false

        var base: UIImage?
        var toPoint: (CLLocationCoordinate2D) -> CGPoint = { c in
            let p = MKMapPoint(c)
            return CGPoint(x: (p.x - fitted.minX) / fitted.width * size.width,
                           y: (p.y - fitted.minY) / fitted.height * size.height)
        }
        do {
            let snap = try await MKMapSnapshotter(options: options).start()
            base = snap.image
            toPoint = { snap.point(for: $0) }
        } catch {
            logger.error("Snapshot failed, drawing route on plain tile: \(error.localizedDescription)")
        }

        let result = UIGraphicsImageRenderer(size: size).image { ctx in
            if let base { base.draw(in: CGRect(origin: .zero, size: size)) }
            else { UIColor.tertiarySystemFill.setFill(); ctx.fill(CGRect(origin: .zero, size: size)) }
            func color(at t: Date) -> UIColor {
                let seg = segments.first { t >= $0.startDate && t <= ($0.endDate ?? .distantFuture) } ?? segments.last
                return UIColor(seg?.activityType.themeColor ?? ShuttlXColor.running)
            }
            let cg = ctx.cgContext
            cg.setLineCap(.round); cg.setLineJoin(.round)
            for pass in 0..<2 {   // white casing, then colour
                cg.setLineWidth(pass == 0 ? 6 : 3.5)
                for i in 1..<coords.count {
                    (pass == 0 ? UIColor.white.withAlphaComponent(0.85) : color(at: pts[i].timestamp)).setStroke()
                    cg.move(to: toPoint(coords[i - 1])); cg.addLine(to: toPoint(coords[i])); cg.strokePath()
                }
            }
        }
        cache.setObject(result, forKey: key)
        return result
    }
}

// MARK: - Start card (D3, both modes)

/// "Next up" card: one obvious way to start. Also used by the empty state (`showOthers: false`, the Programs row is already there).
struct TodayStartCard: View {
    var showOthers = true
    let onStart: () -> Void
    let onOthers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next up").font(ShuttlXFont.microLabel).textCase(.uppercase)
                .foregroundStyle(ShuttlXColor.textSecondary)
            Label {
                Text("Run/Walk").font(ShuttlXFont.metricMedium).foregroundStyle(ShuttlXColor.textPrimary)
            } icon: {
                Image(systemName: "figure.run").foregroundStyle(ShuttlXColor.accentText)
            }
            Text("Your watch finds Run and Walk itself").font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textSecondary)
            Button(action: onStart) {
                Label("Start on Apple Watch", systemImage: "play.fill")
                    .font(ShuttlXFont.cardTitle.weight(.bold))
                    .foregroundStyle(ShuttlXColor.iconOnCTA)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(ShuttlXColor.ctaPrimary, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityHint("Asks to confirm, then starts a Run/Walk workout on your Apple Watch")
            if showOthers {
                Button(action: onOthers) {
                    Text("Other workouts")
                        .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                        .foregroundStyle(ShuttlXColor.accentText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Programs, interval workouts and plans")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .timelineCard(radius: 20)
    }
}

// MARK: - Simple mode tiles

/// Label left, number right (stacks at large text) so a big number never clips.
struct SimpleTile: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = ShuttlXColor.textPrimary

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Label(label, systemImage: icon).font(ShuttlXFont.cardTitle).foregroundStyle(ShuttlXColor.textSecondary)
                Spacer(minLength: 8)
                Text(value).font(ShuttlXFont.metricLarge.monospacedDigit()).foregroundStyle(ShuttlXColor.textPrimary).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Label(label, systemImage: icon).font(ShuttlXFont.cardTitle).foregroundStyle(ShuttlXColor.textSecondary)
                Text(value).font(ShuttlXFont.metricLarge.monospacedDigit()).foregroundStyle(ShuttlXColor.textPrimary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .timelineCard(radius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

// MARK: - Empty state / import progress

struct TodayEmptyState: View {
    @ObservedObject var importer: HealthKitImporter

    var body: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(ShuttlXColor.ctaPrimary.opacity(0.14))
                .frame(width: 84, height: 84)
                .overlay(Image(systemName: "clock").font(ShuttlXFont.metricLarge).foregroundStyle(ShuttlXColor.accentText))
                .accessibilityHidden(true)
            Text("Start a workout on your watch")
                .font(ShuttlXFont.metricMedium)
                .multilineTextAlignment(.center)
                .foregroundStyle(ShuttlXColor.textPrimary)
            Text("It appears here with the route and the Run / Walk parts. Your past ShuttlX workouts come from Apple Health.")
                .font(ShuttlXFont.cardSubtitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(ShuttlXColor.textSecondary)
            if let p = importer.progress {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Reading Apple Health").font(ShuttlXFont.cardTitle.weight(.bold))
                        Spacer()
                        Text("\(p.done) of \(p.total)").font(ShuttlXFont.cardCaption.monospacedDigit())
                            .foregroundStyle(ShuttlXColor.textSecondary)
                    }
                    ProgressView(value: Double(p.done), total: Double(max(1, p.total)))
                        .tint(ShuttlXColor.ctaPrimary)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .timelineCard()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Reading Apple Health, \(p.done) of \(p.total)")
            }
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - "Earlier" row (shown while a workout is live)

struct EarlierRow: View {
    let session: TrainingSession

    var body: some View {
        let segs = session.displaySegments()
        var sub = [session.startDate.formatted(.relative(presentation: .named, unitsStyle: .wide)).prefix(1).uppercased() + session.startDate.formatted(.relative(presentation: .named, unitsStyle: .wide)).dropFirst(), TodayFormat.short(session.duration)]
        if let km = session.distance, km > 0 { sub.append(FormattingUtils.formatDistance(km, unit: .current)) }
        return NavigationLink(destination: SessionDetailView(session: session)) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.timelineName).font(ShuttlXFont.cardTitle.weight(.bold)).foregroundStyle(ShuttlXColor.textPrimary)
                    Text(sub.joined(separator: " \u{00B7} ")).font(ShuttlXFont.cardCaption.monospacedDigit()).foregroundStyle(ShuttlXColor.textSecondary)
                }
                Spacer()
                ActivityRibbon(segments: segs, height: 8).frame(width: 44)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .timelineCard()
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
